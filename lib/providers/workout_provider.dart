import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier, compute;
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../models/gym_settings.dart';
import '../models/insights.dart';
import '../models/pr_record.dart';
import '../models/workout_exercise.dart';
import '../models/workout_session.dart';
import '../models/set_entry.dart';
import '../models/workout_template.dart';
import '../data/exercise_data.dart';
import '../models/sync_state.dart';
import '../services/csv_import_service.dart';
import '../services/sound_service.dart';
import '../services/github_sync_service.dart';
import '../services/metrics_markdown_service.dart';
import '../services/workout_markdown_service.dart';

// ── Analytics data classes ────────────────────────────────────────────────

class ExerciseHistoryEntry {
  final DateTime date;
  final double e1rm;
  final double weight;
  final int reps;
  final int setsCompleted;
  final int volume;
  final double? bestKm;
  final String? bestTime;

  const ExerciseHistoryEntry({
    required this.date,
    required this.e1rm,
    required this.weight,
    required this.reps,
    required this.setsCompleted,
    required this.volume,
    this.bestKm,
    this.bestTime,
  });
}

class WeeklyVolumeEntry {
  final DateTime weekStart;
  final int volume;
  final int sessions;
  final int minutes;

  const WeeklyVolumeEntry({
    required this.weekStart,
    required this.volume,
    required this.sessions,
    required this.minutes,
  });
}

class MuscleNudge {
  final String muscleGroup;
  final int daysSince;

  const MuscleNudge({required this.muscleGroup, required this.daysSince});
}

class PendingMilestone {
  final String key;
  final String label;

  const PendingMilestone({required this.key, required this.label});
}

class SyncSummary {
  final int pushed;
  final int skipped;
  final int failed;
  final int archived;
  final bool metricsUpdated;
  final List<String> errors;

  const SyncSummary({
    required this.pushed,
    required this.skipped,
    required this.failed,
    this.archived = 0,
    required this.metricsUpdated,
    required this.errors,
  });

  bool get hasErrors => failed > 0 || !metricsUpdated;

  String get label {
    if (pushed == 0 && failed == 0 && archived == 0 && metricsUpdated) return 'Already up to date';
    final parts = <String>[];
    if (pushed > 0) parts.add('$pushed synced');
    if (skipped > 0) parts.add('$skipped unchanged');
    if (archived > 0) parts.add('$archived archived');
    if (failed > 0) parts.add('$failed failed');
    if (metricsUpdated) parts.add('metrics ✓');
    return parts.join(' · ');
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

class WorkoutProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final Box _box;
  final Box _syncBox;

  WorkoutSession? _activeWorkout;
  final List<WorkoutSession> _history = [];
  final List<Exercise> _exercises = List.from(defaultExercises);
  final List<Exercise> _customExercises = [];
  final Map<String, PrRecord> _prRecords = {};
  final List<WorkoutTemplate> _templates = [];
  final Map<String, int> _exerciseRestSeconds = {};
  final Set<String> _seenMilestones = {};
  int _weeklyTargetDays = 3;
  int _weekStartDay = 1; // 1 = Monday, 7 = Sunday
  GymSettings _gymSettings = GymSettings.defaults;
  final Map<String, SessionSyncRecord> _syncRecords = {};
  Timer? _saveDebounce;

  WorkoutSession? get activeWorkout => _activeWorkout;
  List<WorkoutSession> get history => List.unmodifiable(_history);
  List<Exercise> get exercises => List.unmodifiable(_exercises);
  bool get hasActiveWorkout => _activeWorkout != null;
  Map<String, PrRecord> get personalRecords => Map.unmodifiable(_prRecords);
  List<WorkoutTemplate> get templates => List.unmodifiable(_templates);
  int get weeklyTargetDays => _weeklyTargetDays;
  int get weekStartDay => _weekStartDay;
  GymSettings get gymSettings => _gymSettings;

  bool workedOutToday(int dayStartHour) {
    if (_history.isEmpty) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, dayStartHour);
    return _history.any((s) => s.startTime.isAfter(todayStart));
  }
  Map<String, SessionSyncRecord> get syncRecords => Map.unmodifiable(_syncRecords);

  WorkoutProvider(this._box, this._syncBox) {
    _load();
    _loadSyncRecords();
  }

  void _load() {
    final historyJson = _box.get('history') as String?;
    if (historyJson != null) {
      final list = jsonDecode(historyJson) as List;
      _history.addAll(
          list.map((j) => WorkoutSession.fromJson(j as Map<String, dynamic>)));
    }

    final prJson = _box.get('prVolumes') as String?;
    if (prJson != null) {
      final map = jsonDecode(prJson) as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is Map) {
          _prRecords[k] = PrRecord.fromJson(v as Map<String, dynamic>);
        } else {
          // Backward compat: old format stored just the e1rm double
          _prRecords[k] = PrRecord(
            e1rm: (v as num).toDouble(),
            weight: 0,
            reps: 0,
            date: DateTime(2000),
          );
        }
      });
    }

    final customJson = _box.get('customExercises') as String?;
    if (customJson != null) {
      final list = jsonDecode(customJson) as List;
      _customExercises.addAll(
          list.map((j) => Exercise.fromJson(j as Map<String, dynamic>)));
      _exercises.addAll(_customExercises);
    }

    final timesJson = _box.get('timesPerformed') as String?;
    if (timesJson != null) {
      final map = jsonDecode(timesJson) as Map<String, dynamic>;
      for (final e in _exercises) {
        if (map.containsKey(e.id)) e.timesPerformed = map[e.id] as int;
      }
    }

    final templatesJson = _box.get('templates') as String?;
    if (templatesJson != null) {
      final list = jsonDecode(templatesJson) as List;
      _templates.addAll(list
          .map((j) => WorkoutTemplate.fromJson(j as Map<String, dynamic>)));
    }

    final restJson = _box.get('exerciseRestSeconds') as String?;
    if (restJson != null) {
      final map = jsonDecode(restJson) as Map<String, dynamic>;
      _exerciseRestSeconds
          .addAll(map.map((k, v) => MapEntry(k, (v as num).toInt())));
    }

    final activeJson = _box.get('activeWorkout') as String?;
    if (activeJson != null) {
      _activeWorkout = WorkoutSession.fromJson(
          jsonDecode(activeJson) as Map<String, dynamic>);
      // Re-apply current plate loading types; old saves defaulted to none.
      for (final ex in _activeWorkout!.exercises) {
        final match =
            _exercises.where((e) => e.id == ex.exerciseId).firstOrNull;
        if (match != null) ex.plateLoadingType = match.plateLoadingType;
      }
    }

    final milestonesJson = _box.get('seenMilestones') as String?;
    if (milestonesJson != null) {
      final list = jsonDecode(milestonesJson) as List;
      _seenMilestones.addAll(list.cast<String>());
    }

    _weeklyTargetDays = (_box.get('weeklyTargetDays') as int?) ?? 3;
    _weekStartDay = (_box.get('weekStartDay') as int?) ?? 1;

    final gymJson = _box.get('gymSettings') as String?;
    if (gymJson != null) {
      try {
        _gymSettings = GymSettings.fromJson(jsonDecode(gymJson) as Map<String, dynamic>);
      } catch (_) {
        _gymSettings = GymSettings.defaults;
      }
    }

    if (_box.get('defaultTemplatesSeeded') == null) {
      _seedDefaultTemplates();
    }
  }

  void _debouncedSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _save);
  }

  void _flushSave() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _save();
  }

  void _saveCustomExercises() {
    _box.put('customExercises',
        jsonEncode(_customExercises.map((e) => e.toJson()).toList()));
  }

  void _save() {
    _box.put('history', jsonEncode(_history.map((s) => s.toJson()).toList()));
    _box.put('prVolumes', jsonEncode({
      for (final e in _prRecords.entries) e.key: e.value.toJson(),
    }));
    _box.put('timesPerformed', jsonEncode({
      for (final e in _exercises) e.id: e.timesPerformed,
    }));
    _box.put('templates', jsonEncode(_templates.map((t) => t.toJson()).toList()));
    _box.put('exerciseRestSeconds', jsonEncode(_exerciseRestSeconds));
    _box.put('seenMilestones', jsonEncode(_seenMilestones.toList()));
    if (_activeWorkout != null) {
      _box.put('activeWorkout', jsonEncode(_activeWorkout!.toJson()));
    } else {
      _box.delete('activeWorkout');
    }
  }

  // ── Custom exercise CRUD ─────────────────────────────────────────────────

  void createCustomExercise({
    required String name,
    required String muscleGroup,
    ExerciseType type = ExerciseType.weight,
    List<String> tags = const [],
    PlateLoadingType plateLoadingType = PlateLoadingType.none,
  }) {
    final ex = Exercise(
      id: 'custom_${_uuid.v4()}',
      name: name.trim(),
      muscleGroup: muscleGroup,
      type: type,
      tags: List.from(tags),
      plateLoadingType: plateLoadingType,
      isCustom: true,
    );
    _customExercises.add(ex);
    _exercises.add(ex);
    _saveCustomExercises();
    notifyListeners();
  }

  void updateCustomExercise(Exercise updated) {
    final ci = _customExercises.indexWhere((e) => e.id == updated.id);
    final ei = _exercises.indexWhere((e) => e.id == updated.id);
    if (ci == -1) return;
    _customExercises[ci] = updated;
    if (ei != -1) _exercises[ei] = updated;
    _saveCustomExercises();
    notifyListeners();
  }

  void deleteCustomExercise(String id) {
    _customExercises.removeWhere((e) => e.id == id);
    _exercises.removeWhere((e) => e.id == id);
    _saveCustomExercises();
    notifyListeners();
  }

  int customExerciseSessionCount(String id) =>
      _history.where((s) => s.exercises.any((e) => e.exerciseId == id)).length;

  // ── Rest timer ───────────────────────────────────────────────────────────

  int _restFor(String exerciseId, ExerciseType type) {
    if (_exerciseRestSeconds.containsKey(exerciseId)) {
      return _exerciseRestSeconds[exerciseId]!;
    }
    return type == ExerciseType.cardio ? 120 : 90;
  }

  void _populatePreviousValues(WorkoutExercise we) {
    for (final session in _history) {
      final match =
          session.exercises.where((e) => e.exerciseId == we.exerciseId).firstOrNull;
      if (match != null) {
        // Group previous sets by type so warmup and working sets each get
        // their own matching previous values independently.
        final Map<SetType, List<SetEntry>> prevByType = {};
        for (final s in match.sets) {
          prevByType.putIfAbsent(s.setType, () => []).add(s);
        }
        final Map<SetType, int> typeIdx = {};
        for (final s in we.sets) {
          final idx = typeIdx[s.setType] ?? 0;
          typeIdx[s.setType] = idx + 1;
          final prevList = prevByType[s.setType] ?? [];
          if (idx < prevList.length) {
            final prev = prevList[idx];
            s.previousWeight = prev.weight;
            s.previousReps = prev.reps;
            s.previousRpe = prev.rpe;
            s.previousKm =
                prev.kmInput.isNotEmpty ? double.tryParse(prev.kmInput) : null;
            s.previousTime =
                prev.timeInput.isNotEmpty ? prev.timeInput : null;
          }
        }
        break;
      }
    }
  }

  static String _autoName() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Morning Workout';
    if (h >= 12 && h < 17) return 'Afternoon Workout';
    if (h >= 17 && h < 21) return 'Evening Workout';
    return 'Night Workout';
  }

  // ── Workout lifecycle ─────────────────────────────────────────────────────

  void startWorkout({String? name}) {
    _activeWorkout = WorkoutSession(
      id: _uuid.v4(),
      name: name ?? _autoName(),
      startTime: DateTime.now(),
    );
    _save();
    notifyListeners();
  }

  void startWorkoutFromTemplate(WorkoutTemplate template) {
    _activeWorkout = WorkoutSession(
      id: _uuid.v4(),
      name: template.name,
      startTime: DateTime.now(),
    );
    for (final te in template.exercises) {
      final exMatch = _exercises.where((e) => e.id == te.exerciseId).firstOrNull;
      final we = WorkoutExercise(
        exerciseId: te.exerciseId,
        exerciseName: te.exerciseName,
        muscleGroup: te.muscleGroup,
        exerciseType: te.exerciseType,
        plateLoadingType: exMatch?.plateLoadingType ?? PlateLoadingType.none,
        restSeconds: _restFor(te.exerciseId, te.exerciseType),
        sets: List.generate(te.setCount, (i) => SetEntry(setNumber: i + 1)),
      );
      _populatePreviousValues(we);
      _activeWorkout!.exercises.add(we);
    }
    _save();
    notifyListeners();
  }

  void addExercise(Exercise exercise) {
    final we = WorkoutExercise(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      exerciseType: exercise.type,
      plateLoadingType: exercise.plateLoadingType,
      restSeconds: _restFor(exercise.id, exercise.type),
    );
    _populatePreviousValues(we);
    _activeWorkout?.exercises.add(we);
    _save();
    notifyListeners();
  }

  void addExercises(List<Exercise> exercises) {
    for (final exercise in exercises) {
      final we = WorkoutExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        muscleGroup: exercise.muscleGroup,
        exerciseType: exercise.type,
        plateLoadingType: exercise.plateLoadingType,
        restSeconds: _restFor(exercise.id, exercise.type),
      );
      _populatePreviousValues(we);
      _activeWorkout?.exercises.add(we);
    }
    _save();
    notifyListeners();
  }

  void removeExercise(int exerciseIndex) {
    _activeWorkout?.exercises.removeAt(exerciseIndex);
    _save();
    notifyListeners();
  }

  void replaceExercise(int exerciseIndex, Exercise exercise) {
    if (_activeWorkout == null) return;
    final we = WorkoutExercise(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      exerciseType: exercise.type,
      restSeconds: _restFor(exercise.id, exercise.type),
    );
    _populatePreviousValues(we);
    _activeWorkout!.exercises[exerciseIndex] = we;
    _save();
    notifyListeners();
  }

  void updateRestSeconds(int exerciseIndex, int seconds) {
    final ex = _activeWorkout?.exercises[exerciseIndex];
    if (ex != null) {
      ex.restSeconds = seconds;
      _exerciseRestSeconds[ex.exerciseId] = seconds;
      _save();
      notifyListeners();
    }
  }

  void addSet(int exerciseIndex) {
    final ex = _activeWorkout?.exercises[exerciseIndex];
    if (ex == null) return;
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    final newIndex = ex.sets.length;
    final newSet = SetEntry(
      setNumber: newIndex + 1,
      weightInput: last?.weightInput ?? '',
      repsInput: last?.repsInput ?? '',
      kmInput: last?.kmInput ?? '',
      timeInput: last?.timeInput ?? '',
    );
    for (final session in _history) {
      final match = session.exercises
          .where((e) => e.exerciseId == ex.exerciseId)
          .firstOrNull;
      if (match != null) {
        // Type-aware: count how many sets of the same type already exist in the
        // current exercise — that index maps to the same-typed set in history.
        final sameTypeCount = ex.sets
            .where((s) => s.setType == newSet.setType)
            .length; // sets already in ex before this new one
        final prevOfType = match.sets
            .where((s) => s.setType == newSet.setType)
            .toList();
        if (sameTypeCount < prevOfType.length) {
          final prev = prevOfType[sameTypeCount];
          newSet.previousWeight = prev.weight;
          newSet.previousReps = prev.reps;
          newSet.previousRpe = prev.rpe;
          newSet.previousKm =
              prev.kmInput.isNotEmpty ? double.tryParse(prev.kmInput) : null;
          newSet.previousTime =
              prev.timeInput.isNotEmpty ? prev.timeInput : null;
        }
        break;
      }
    }
    ex.sets.add(newSet);
    _save();
    notifyListeners();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    final ex = _activeWorkout?.exercises[exerciseIndex];
    if (ex == null || ex.sets.length <= 1) return;
    ex.sets.removeAt(setIndex);
    for (int i = 0; i < ex.sets.length; i++) {
      ex.sets[i].setNumber = i + 1;
    }
    _save();
    notifyListeners();
  }

  // Input-only updates: no notifyListeners (keyboard setState handles display),
  // debounced save to avoid disk I/O on every keystroke.
  void updateSetWeight(int exerciseIndex, int setIndex, String value) {
    _activeWorkout?.exercises[exerciseIndex].sets[setIndex].weightInput = value;
    _debouncedSave();
  }

  void updateSetReps(int exerciseIndex, int setIndex, String value) {
    _activeWorkout?.exercises[exerciseIndex].sets[setIndex].repsInput = value;
    _debouncedSave();
  }

  void updateSetKm(int exerciseIndex, int setIndex, String value) {
    _activeWorkout?.exercises[exerciseIndex].sets[setIndex].kmInput = value;
    _debouncedSave();
  }

  void updateSetTime(int exerciseIndex, int setIndex, String value) {
    _activeWorkout?.exercises[exerciseIndex].sets[setIndex].timeInput = value;
    _debouncedSave();
  }

  void toggleSetComplete(int exerciseIndex, int setIndex) {
    final set = _activeWorkout?.exercises[exerciseIndex].sets[setIndex];
    if (set != null) {
      set.completed = !set.completed;
      _save();
      notifyListeners();
    }
  }

  void updateSetRpe(int exerciseIndex, int setIndex, double? rpe) {
    final set = _activeWorkout?.exercises[exerciseIndex].sets[setIndex];
    if (set != null) {
      set.rpe = rpe;
      _save();
      notifyListeners();
    }
  }

  void updateSetType(int exerciseIndex, int setIndex, SetType setType) {
    final ex = _activeWorkout?.exercises[exerciseIndex];
    final set = ex?.sets[setIndex];
    if (set == null || ex == null) return;
    set.setType = setType;
    // Refresh previous values now that the type has changed.
    set.previousWeight = null;
    set.previousReps = null;
    set.previousRpe = null;
    set.previousKm = null;
    set.previousTime = null;
    for (final session in _history) {
      final match =
          session.exercises.where((e) => e.exerciseId == ex.exerciseId).firstOrNull;
      if (match != null) {
        final typeIdx = ex.sets
            .sublist(0, setIndex)
            .where((s) => s.setType == setType)
            .length;
        final prevOfType =
            match.sets.where((s) => s.setType == setType).toList();
        if (typeIdx < prevOfType.length) {
          final prev = prevOfType[typeIdx];
          set.previousWeight = prev.weight;
          set.previousReps = prev.reps;
          set.previousRpe = prev.rpe;
          set.previousKm =
              prev.kmInput.isNotEmpty ? double.tryParse(prev.kmInput) : null;
          set.previousTime =
              prev.timeInput.isNotEmpty ? prev.timeInput : null;
        }
        break;
      }
    }
    _save();
    notifyListeners();
  }

  void renameWorkout(String name) {
    _activeWorkout?.name = name;
    _save();
    notifyListeners();
  }

  void updateExerciseNote(int exerciseIndex, String note) {
    final ex = _activeWorkout?.exercises[exerciseIndex];
    if (ex != null) {
      ex.notes = note;
      _save();
      notifyListeners();
    }
  }

  void updateWorkoutNote(String note) {
    if (_activeWorkout != null) {
      _activeWorkout!.notes = note;
      _save();
      notifyListeners();
    }
  }

  void updateHistoryWorkoutNote(String sessionId, String note) {
    final session = _history.firstWhere((s) => s.id == sessionId,
        orElse: () => WorkoutSession(id: '', name: '', startTime: DateTime.now()));
    if (session.id.isEmpty) return;
    session.notes = note;
    _save();
    notifyListeners();
  }

  int get incompleteSetsCount {
    if (_activeWorkout == null) return 0;
    return _activeWorkout!.exercises
        .expand((ex) => ex.sets)
        .where((s) => !s.completed)
        .length;
  }

  WorkoutSession? finishWorkout() {
    if (_activeWorkout == null) return null;
    _saveDebounce?.cancel();
    _activeWorkout!.endTime = DateTime.now();
    final List<String> newPRs = [];
    for (final ex in _activeWorkout!.exercises) {
      final found = _exercises.firstWhere(
        (e) => e.id == ex.exerciseId,
        orElse: () => Exercise(id: '', name: '', muscleGroup: ''),
      );
      if (found.id.isNotEmpty) found.timesPerformed++;

      if (ex.exerciseType == ExerciseType.cardio) {
        for (final set in ex.sets.where(
            (s) => s.completed && s.kmInput.isNotEmpty)) {
          final km = double.tryParse(set.kmInput);
          if (km == null) continue;
          final existing = _prRecords[ex.exerciseId];
          if (existing == null || !existing.isCardio || km > existing.km!) {
            _prRecords[ex.exerciseId] = PrRecord(
              e1rm: 0,
              weight: 0,
              reps: 0,
              date: _activeWorkout!.endTime!,
              km: km,
            );
            if (!newPRs.contains(ex.exerciseName)) newPRs.add(ex.exerciseName);
          }
        }
      } else {
        for (final set in ex.sets.where((s) =>
            s.completed &&
            s.setType != SetType.warmUp &&
            s.weight != null &&
            s.reps != null)) {
          final e1rm = set.weight! * (1 + set.reps! / 30.0);
          final existing = _prRecords[ex.exerciseId];
          if (existing == null || existing.isCardio || e1rm > existing.e1rm) {
            _prRecords[ex.exerciseId] = PrRecord(
              e1rm: e1rm,
              weight: set.weight!,
              reps: set.reps!,
              date: _activeWorkout!.endTime!,
            );
            if (!newPRs.contains(ex.exerciseName)) newPRs.add(ex.exerciseName);
          }
        }
      }
    }
    _activeWorkout!.personalRecords = newPRs;
    _history.insert(0, _activeWorkout!);
    final finished = _activeWorkout;
    _activeWorkout = null;
    _save();
    notifyListeners();
    return finished;
  }

  void cancelWorkout() {
    _saveDebounce?.cancel();
    _activeWorkout = null;
    _save();
    notifyListeners();
  }

  void deleteWorkout(String id) {
    final record = _syncRecords[id];
    _history.removeWhere((s) => s.id == id);
    _save();
    notifyListeners();
    if (record != null) _archiveSessionBackground(record);
  }

  /// Imports parsed sessions from a Strong CSV export.
  /// Skips sessions whose startTime already exists in history (within 60 s).
  /// Returns the number of sessions actually added.
  int importFromStrong(List<WorkoutSession> sessions) {
    final existingTimes = _history.map((s) => s.startTime).toList();
    final newSessions = sessions.where((s) => !existingTimes.any(
      (t) => t.difference(s.startTime).inSeconds.abs() < 60,
    )).toList();

    if (newSessions.isEmpty) return 0;

    // Process oldest-first so PRs accumulate correctly over time.
    newSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final session in newSessions) {
      for (final ex in session.exercises) {
        final found = _exercises.firstWhere(
          (e) => e.id == ex.exerciseId,
          orElse: () => Exercise(id: '', name: '', muscleGroup: ''),
        );
        if (found.id.isNotEmpty) found.timesPerformed++;

        if (ex.exerciseType == ExerciseType.cardio) {
          for (final set in ex.sets.where((s) => s.completed && s.kmInput.isNotEmpty)) {
            final km = double.tryParse(set.kmInput);
            if (km == null) continue;
            final existing = _prRecords[ex.exerciseId];
            if (existing == null || !existing.isCardio || km > existing.km!) {
              _prRecords[ex.exerciseId] = PrRecord(
                e1rm: 0, weight: 0, reps: 0,
                date: session.endTime ?? session.startTime,
                km: km,
              );
              if (!session.personalRecords.contains(ex.exerciseName)) {
                session.personalRecords.add(ex.exerciseName);
              }
            }
          }
        } else {
          for (final set in ex.sets.where((s) =>
              s.completed && s.weight != null && s.reps != null)) {
            final e1rm = set.weight! * (1 + set.reps! / 30.0);
            final existing = _prRecords[ex.exerciseId];
            if (existing == null || existing.isCardio || e1rm > existing.e1rm) {
              _prRecords[ex.exerciseId] = PrRecord(
                e1rm: e1rm,
                weight: set.weight!,
                reps: set.reps!,
                date: session.endTime ?? session.startTime,
              );
              if (!session.personalRecords.contains(ex.exerciseName)) {
                session.personalRecords.add(ex.exerciseName);
              }
            }
          }
        }
      }
    }

    _history.addAll(newSessions);
    _history.sort((a, b) => b.startTime.compareTo(a.startTime));
    _save();
    notifyListeners();
    for (final session in newSessions) {
      _syncSessionBackground(session);
    }
    return newSessions.length;
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  void saveTemplate(String name, List<WorkoutExercise> exercises) {
    _templates.add(WorkoutTemplate(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      exercises: exercises
          .map((e) => TemplateExercise(
                exerciseId: e.exerciseId,
                exerciseName: e.exerciseName,
                muscleGroup: e.muscleGroup,
                exerciseType: e.exerciseType,
                setCount: e.sets.length,
                restSeconds: e.restSeconds,
              ))
          .toList(),
    ));
    _save();
    notifyListeners();
  }

  void saveTemplateFromExercises(String name, List<Exercise> exercises) {
    _templates.add(WorkoutTemplate(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      exercises: exercises
          .map((e) => TemplateExercise(
                exerciseId: e.id,
                exerciseName: e.name,
                muscleGroup: e.muscleGroup,
                exerciseType: e.type,
                setCount: 3,
                restSeconds: e.type == ExerciseType.cardio ? 120 : 90,
              ))
          .toList(),
    ));
    _save();
    notifyListeners();
  }

  void deleteTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  void _seedDefaultTemplates() {
    final now = DateTime.now();
    int order = 0;

    WorkoutTemplate mkTemplate(String name, List<TemplateExercise> exs) =>
        WorkoutTemplate(
          id: _uuid.v4(),
          name: name,
          createdAt: now.subtract(Duration(seconds: order++ * 5)),
          exercises: exs,
        );

    TemplateExercise mkEx(String id, String name, String muscle,
            {int sets = 3, int rest = 90}) =>
        TemplateExercise(
            exerciseId: id,
            exerciseName: name,
            muscleGroup: muscle,
            setCount: sets,
            restSeconds: rest);

    _templates.addAll([
      mkTemplate('StrongLifts 5×5 – Workout A', [
        mkEx('squat_barbell', 'Squat (Barbell)', 'Legs', sets: 5, rest: 180),
        mkEx('bench_press_barbell', 'Bench Press (Barbell)', 'Chest', sets: 5, rest: 180),
        mkEx('barbell_row', 'Bent Over Row (Barbell)', 'Back', sets: 5, rest: 180),
      ]),
      mkTemplate('StrongLifts 5×5 – Workout B', [
        mkEx('squat_barbell', 'Squat (Barbell)', 'Legs', sets: 5, rest: 180),
        mkEx('overhead_press_barbell', 'Overhead Press (Barbell)', 'Shoulders', sets: 5, rest: 180),
        mkEx('deadlift', 'Deadlift (Barbell)', 'Back', sets: 1, rest: 240),
      ]),
      mkTemplate('PPL – Push', [
        mkEx('bench_press_barbell', 'Bench Press (Barbell)', 'Chest', sets: 4, rest: 150),
        mkEx('incline_bench_press_dumbbell', 'Incline Bench Press (Dumbbell)', 'Chest', sets: 3, rest: 90),
        mkEx('overhead_press_barbell', 'Overhead Press (Barbell)', 'Shoulders', sets: 3, rest: 120),
        mkEx('lateral_raise_dumbbell', 'Lateral Raise (Dumbbell)', 'Shoulders', sets: 4, rest: 60),
        mkEx('triceps_pushdown_cable', 'Triceps Pushdown (Cable - Straight Bar)', 'Arms', sets: 3, rest: 60),
        mkEx('skull_crusher', 'Skullcrusher (Barbell)', 'Arms', sets: 3, rest: 60),
      ]),
      mkTemplate('PPL – Pull', [
        mkEx('deadlift', 'Deadlift (Barbell)', 'Back', sets: 3, rest: 180),
        mkEx('barbell_row', 'Bent Over Row (Barbell)', 'Back', sets: 4, rest: 120),
        mkEx('lat_pulldown', 'Lat Pulldown (Cable)', 'Back', sets: 3, rest: 90),
        mkEx('face_pull', 'Face Pull (Cable)', 'Back', sets: 3, rest: 60),
        mkEx('bicep_curl_barbell', 'Bicep Curl (Barbell)', 'Arms', sets: 3, rest: 60),
        mkEx('hammer_curl', 'Hammer Curl (Dumbbell)', 'Arms', sets: 3, rest: 60),
      ]),
      mkTemplate('PPL – Legs', [
        mkEx('squat_barbell', 'Squat (Barbell)', 'Legs', sets: 4, rest: 150),
        mkEx('romanian_deadlift', 'Romanian Deadlift (Barbell)', 'Legs', sets: 3, rest: 120),
        mkEx('leg_press', 'Leg Press', 'Legs', sets: 3, rest: 90),
        mkEx('leg_extension', 'Leg Extension (Machine)', 'Legs', sets: 3, rest: 60),
        mkEx('leg_curl_machine', 'Lying Leg Curl (Machine)', 'Legs', sets: 3, rest: 60),
        mkEx('calf_raise_machine', 'Standing Calf Raise (Machine)', 'Legs', sets: 4, rest: 60),
      ]),
      mkTemplate('Upper Body', [
        mkEx('bench_press_barbell', 'Bench Press (Barbell)', 'Chest', sets: 4, rest: 120),
        mkEx('barbell_row', 'Bent Over Row (Barbell)', 'Back', sets: 4, rest: 120),
        mkEx('overhead_press_barbell', 'Overhead Press (Barbell)', 'Shoulders', sets: 3, rest: 90),
        mkEx('lat_pulldown', 'Lat Pulldown (Cable)', 'Back', sets: 3, rest: 90),
        mkEx('bicep_curl_barbell', 'Bicep Curl (Barbell)', 'Arms', sets: 3, rest: 60),
        mkEx('triceps_pushdown_cable', 'Triceps Pushdown (Cable - Straight Bar)', 'Arms', sets: 3, rest: 60),
      ]),
      mkTemplate('Lower Body', [
        mkEx('squat_barbell', 'Squat (Barbell)', 'Legs', sets: 4, rest: 150),
        mkEx('romanian_deadlift', 'Romanian Deadlift (Barbell)', 'Legs', sets: 3, rest: 120),
        mkEx('leg_press', 'Leg Press', 'Legs', sets: 3, rest: 90),
        mkEx('leg_extension', 'Leg Extension (Machine)', 'Legs', sets: 3, rest: 60),
        mkEx('leg_curl_machine', 'Lying Leg Curl (Machine)', 'Legs', sets: 3, rest: 60),
        mkEx('hip_thrust_barbell', 'Hip Thrust (Barbell)', 'Legs', sets: 3, rest: 90),
      ]),
      mkTemplate('Full Body', [
        mkEx('squat_barbell', 'Squat (Barbell)', 'Legs', sets: 3, rest: 150),
        mkEx('bench_press_barbell', 'Bench Press (Barbell)', 'Chest', sets: 3, rest: 120),
        mkEx('barbell_row', 'Bent Over Row (Barbell)', 'Back', sets: 3, rest: 120),
        mkEx('overhead_press_barbell', 'Overhead Press (Barbell)', 'Shoulders', sets: 3, rest: 90),
        mkEx('deadlift', 'Deadlift (Barbell)', 'Back', sets: 1, rest: 240),
      ]),
    ]);

    _box.put('defaultTemplatesSeeded', true);
    _save();
  }

  // ── Milestones ────────────────────────────────────────────────────────────

  static const _milestoneWorkoutCounts = [1, 10, 25, 50, 100, 250, 500];

  List<PendingMilestone> getPendingMilestones() {
    final total = _history.length;
    final pending = <PendingMilestone>[];
    for (final count in _milestoneWorkoutCounts) {
      if (total >= count) {
        final key = 'workout_$count';
        if (!_seenMilestones.contains(key)) {
          pending.add(PendingMilestone(
            key: key,
            label: count == 1
                ? 'First workout completed!'
                : '$count workouts completed!',
          ));
        }
      }
    }
    return pending;
  }

  void dismissMilestone(String key) {
    _seenMilestones.add(key);
    _box.put('seenMilestones', jsonEncode(_seenMilestones.toList()));
    notifyListeners();
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void setWeeklyTargetDays(int days) {
    _weeklyTargetDays = days.clamp(1, 7);
    _box.put('weeklyTargetDays', _weeklyTargetDays);
    notifyListeners();
  }

  void setWeekStartDay(int day) {
    // 1 = Monday, 7 = Sunday
    _weekStartDay = day;
    _box.put('weekStartDay', _weekStartDay);
    notifyListeners();
  }

  void updateGymSettings(GymSettings settings) {
    _gymSettings = settings;
    _box.put('gymSettings', jsonEncode(settings.toJson()));
    SoundService.enabled = settings.soundsEnabled;
    notifyListeners();
  }

  // ── Sync state ────────────────────────────────────────────────────────────

  void _loadSyncRecords() {
    for (final key in _syncBox.keys) {
      final raw = _syncBox.get(key);
      if (raw is String) {
        try {
          _syncRecords[key as String] =
              SessionSyncRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    }
  }

  void saveSyncRecord(SessionSyncRecord record) {
    _syncRecords[record.sessionId] = record;
    _syncBox.put(record.sessionId, jsonEncode(record.toJson()));
  }

  SessionSyncRecord? getSyncRecord(String sessionId) => _syncRecords[sessionId];

  // Fire-and-forget: push a session + metrics to GitHub.
  void _syncSessionBackground(WorkoutSession session) {
    final s = _gymSettings;
    if (s.githubOwner.isEmpty || s.githubRepo.isEmpty) return;
    unawaited(_pushSessionAndMetrics(session, s));
  }

  Future<void> _pushSessionAndMetrics(WorkoutSession session, GymSettings s) async {
    final svc = GitHubSyncService();
    await svc.pushSession(
      session: session,
      owner: s.githubOwner,
      repo: s.githubRepo,
      branch: s.githubBranch,
      existingRecord: _syncRecords[session.id],
      onSaved: saveSyncRecord,
    );
    await svc.pushMetrics(
      owner: s.githubOwner,
      repo: s.githubRepo,
      branch: s.githubBranch,
      content: MetricsMarkdownService.buildNote(this),
    );
  }

  // Fire-and-forget: archive a deleted session on GitHub and refresh metrics.
  void _archiveSessionBackground(SessionSyncRecord record) {
    final s = _gymSettings;
    if (s.githubOwner.isEmpty || s.githubRepo.isEmpty) return;
    unawaited(_archiveAndUpdateMetrics(record, s));
  }

  Future<void> _archiveAndUpdateMetrics(SessionSyncRecord record, GymSettings s) async {
    final svc = GitHubSyncService();
    final error = await svc.archiveWorkout(
      owner: s.githubOwner,
      repo: s.githubRepo,
      branch: s.githubBranch,
      sourcePath: record.filePath,
    );
    if (error == null) {
      _syncRecords.remove(record.sessionId);
      _syncBox.delete(record.sessionId);
    }
    await svc.pushMetrics(
      owner: s.githubOwner,
      repo: s.githubRepo,
      branch: s.githubBranch,
      content: MetricsMarkdownService.buildNote(this),
    );
  }

  void saveHistorySession(WorkoutSession updated) {
    final idx = _history.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return;
    _history[idx] = updated;
    _save();
    notifyListeners();
    _syncSessionBackground(updated);
  }

  /// Pushes all new/changed sessions and refreshes the metrics snapshot.
  Future<SyncSummary> syncToGitHub() async {
    final settings = _gymSettings;
    if (settings.githubOwner.isEmpty || settings.githubRepo.isEmpty) {
      return const SyncSummary(
        pushed: 0,
        skipped: 0,
        failed: 0,
        metricsUpdated: false,
        errors: ['GitHub not configured'],
      );
    }

    final svc = GitHubSyncService();
    int pushed = 0, skipped = 0, failed = 0, archived = 0;
    final errors = <String>[];

    for (final session in _history) {
      final existing = _syncRecords[session.id];
      final hash = WorkoutMarkdownService.sessionHash(session);

      if (existing != null && existing.sessionHash == hash &&
          existing.filePath == WorkoutMarkdownService.sessionFilePath(session)) {
        skipped++;
        continue;
      }

      final error = await svc.pushSession(
        session: session,
        owner: settings.githubOwner,
        repo: settings.githubRepo,
        branch: settings.githubBranch,
        existingRecord: existing,
        onSaved: saveSyncRecord,
      );

      if (error == null) {
        pushed++;
      } else {
        failed++;
        errors.add('${session.name}: $error');
      }
    }

    // Archive GitHub files for sessions deleted from history
    final activeIds = _history.map((s) => s.id).toSet();
    final orphaned = _syncRecords.values
        .where((r) => !activeIds.contains(r.sessionId))
        .toList();
    for (final record in orphaned) {
      final error = await svc.archiveWorkout(
        owner: settings.githubOwner,
        repo: settings.githubRepo,
        branch: settings.githubBranch,
        sourcePath: record.filePath,
      );
      if (error == null) {
        archived++;
        _syncRecords.remove(record.sessionId);
        _syncBox.delete(record.sessionId);
      } else {
        failed++;
        errors.add('Archive ${record.filePath}: $error');
      }
    }

    final metricsContent = MetricsMarkdownService.buildNote(this);
    final metricsError = await svc.pushMetrics(
      owner: settings.githubOwner,
      repo: settings.githubRepo,
      branch: settings.githubBranch,
      content: metricsContent,
    );
    if (metricsError != null) errors.add('Metrics: $metricsError');

    return SyncSummary(
      pushed: pushed,
      skipped: skipped,
      failed: failed,
      archived: archived,
      metricsUpdated: metricsError == null,
      errors: errors,
    );
  }

  // ── Analytics helpers ─────────────────────────────────────────────────────

  DateTime _startOfWeek(DateTime date) {
    final daysFromStart = (date.weekday - _weekStartDay + 7) % 7;
    return DateTime(date.year, date.month, date.day - daysFromStart);
  }

  int getCurrentStreakWeeks() {
    if (_history.isEmpty) return 0;
    int streak = 0;
    DateTime weekStart = _startOfWeek(DateTime.now());
    while (true) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = _history.where((s) =>
          !s.startTime.isBefore(weekStart) && s.startTime.isBefore(weekEnd)).length;
      if (count < _weeklyTargetDays) break;
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    return streak;
  }

  int getBestStreakWeeks() {
    if (_history.isEmpty) return 0;
    // Walk every week from the earliest workout to now
    final earliest = _startOfWeek(_history.last.startTime); // history newest-first
    final latest = _startOfWeek(DateTime.now());
    int best = 0, current = 0;
    DateTime ws = earliest;
    while (!ws.isAfter(latest)) {
      final we = ws.add(const Duration(days: 7));
      final count = _history.where((s) =>
          !s.startTime.isBefore(ws) && s.startTime.isBefore(we)).length;
      if (count >= _weeklyTargetDays) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
      ws = ws.add(const Duration(days: 7));
    }
    return best;
  }

  Map<String, int> getWeeklyMuscleSets() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final result = <String, int>{};
    for (final session in _history) {
      if (session.startTime.isAfter(weekAgo)) {
        for (final ex in session.exercises) {
          final completed = ex.sets.where((s) => s.completed).length;
          if (completed > 0) {
            result[ex.muscleGroup] = (result[ex.muscleGroup] ?? 0) + completed;
          }
        }
      }
    }
    return result;
  }

  Map<String, DateTime> getMuscleLastTrained() {
    final result = <String, DateTime>{};
    for (final session in _history) {
      for (final ex in session.exercises) {
        result.putIfAbsent(ex.muscleGroup, () => session.startTime);
      }
    }
    return result;
  }

  List<MuscleNudge> getMuscleNudges() {
    final allMuscles = <String>{};
    for (final s in _history) {
      for (final ex in s.exercises) allMuscles.add(ex.muscleGroup);
    }
    if (allMuscles.isEmpty) return [];

    final lastTrained = getMuscleLastTrained();
    final now = DateTime.now();

    final muscleAvgFreq = <String, double>{};
    for (final muscle in allMuscles) {
      final dates = <DateTime>[];
      for (final s in _history) {
        if (s.exercises.any((ex) => ex.muscleGroup == muscle)) {
          dates.add(s.startTime);
        }
      }
      dates.sort();
      muscleAvgFreq[muscle] = dates.length >= 2
          ? dates.last.difference(dates.first).inDays / (dates.length - 1)
          : 7.0;
    }

    final nudges = <MuscleNudge>[];
    for (final muscle in allMuscles) {
      final last = lastTrained[muscle];
      if (last == null) continue;
      final daysSince = now.difference(last).inDays;
      final freq = muscleAvgFreq[muscle] ?? 7.0;
      if (daysSince > freq * 1.3) {
        nudges.add(MuscleNudge(muscleGroup: muscle, daysSince: daysSince));
      }
    }

    nudges.sort((a, b) => b.daysSince.compareTo(a.daysSince));
    return nudges.take(2).toList();
  }

  // ── All-time stats ────────────────────────────────────────────────────────

  ({int totalWorkouts, int totalSets, int totalVolume, int totalMinutes, int totalPRs})
      getAllTimeStats() {
    int sets = 0, volume = 0, minutes = 0;
    for (final s in _history) {
      sets += s.completedSets;
      volume += s.totalVolume;
      minutes += s.duration.inMinutes;
    }
    return (
      totalWorkouts: _history.length,
      totalSets: sets,
      totalVolume: volume,
      totalMinutes: minutes,
      totalPRs: _prRecords.length,
    );
  }

  Map<String, int> getMuscleGroupSetsAllTime() {
    final result = <String, int>{};
    for (final s in _history) {
      for (final ex in s.exercises) {
        final completed = ex.sets.where((s) => s.completed).length;
        if (completed > 0) {
          result[ex.muscleGroup] = (result[ex.muscleGroup] ?? 0) + completed;
        }
      }
    }
    return result;
  }

  List<WeeklyVolumeEntry> getVolumeByWeek({int weeks = 12}) {
    final result = <WeeklyVolumeEntry>[];
    final now = DateTime.now();
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = _startOfWeek(now.subtract(Duration(days: i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final inWeek = _history
          .where((s) =>
              !s.startTime.isBefore(weekStart) && s.startTime.isBefore(weekEnd))
          .toList();
      int vol = 0, mins = 0;
      for (final s in inWeek) {
        vol += s.totalVolume;
        mins += s.duration.inMinutes;
      }
      result.add(WeeklyVolumeEntry(
        weekStart: weekStart,
        volume: vol,
        sessions: inWeek.length,
        minutes: mins,
      ));
    }
    return result;
  }

  List<Exercise> getMostTrainedExercises({int limit = 10}) {
    final sorted = [..._exercises]
      ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
    return sorted.where((e) => e.timesPerformed > 0).take(limit).toList();
  }

  ({String? topDay, String? topTimeOfDay, Duration avgDuration})
      getTrainingPatterns() {
    if (_history.isEmpty) {
      return (topDay: null, topTimeOfDay: null, avgDuration: Duration.zero);
    }
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final dayCounts = <int, int>{};
    final timeCounts = <String, int>{};
    int totalMins = 0;
    for (final s in _history) {
      dayCounts[s.startTime.weekday] =
          (dayCounts[s.startTime.weekday] ?? 0) + 1;
      final h = s.startTime.hour;
      final tod = h >= 5 && h < 12
          ? 'Morning'
          : h >= 12 && h < 17
              ? 'Afternoon'
              : h >= 17 && h < 21
                  ? 'Evening'
                  : 'Night';
      timeCounts[tod] = (timeCounts[tod] ?? 0) + 1;
      totalMins += s.duration.inMinutes;
    }
    final topDayNum =
        dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final topTod =
        timeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return (
      topDay: days[topDayNum - 1],
      topTimeOfDay: topTod,
      avgDuration: Duration(minutes: totalMins ~/ _history.length),
    );
  }

  List<
      ({
        String exerciseId,
        String exerciseName,
        String muscleGroup,
        PrRecord pr
      })> getAllTimePRs() {
    final result = <({
      String exerciseId,
      String exerciseName,
      String muscleGroup,
      PrRecord pr
    })>[];
    for (final entry in _prRecords.entries) {
      final ex = _exercises.firstWhere(
        (e) => e.id == entry.key,
        orElse: () =>
            Exercise(id: entry.key, name: entry.key, muscleGroup: 'Other'),
      );
      result.add((
        exerciseId: entry.key,
        exerciseName: ex.name,
        muscleGroup: ex.muscleGroup,
        pr: entry.value,
      ));
    }
    result.sort((a, b) => a.muscleGroup.compareTo(b.muscleGroup));
    return result;
  }

  // ── Exercise history for chart ─────────────────────────────────────────────

  List<ExerciseHistoryEntry> getExerciseHistory(String exerciseId) {
    final result = <ExerciseHistoryEntry>[];
    for (final session in _history.reversed) {
      final match = session.exercises
          .where((e) => e.exerciseId == exerciseId)
          .firstOrNull;
      if (match == null) continue;

      if (match.exerciseType == ExerciseType.cardio) {
        final cardioSets = match.sets
            .where((s) => s.completed && s.kmInput.isNotEmpty)
            .toList();
        if (cardioSets.isEmpty) continue;
        final best = cardioSets.reduce((a, b) =>
            (double.tryParse(a.kmInput) ?? 0) >=
                    (double.tryParse(b.kmInput) ?? 0)
                ? a
                : b);
        result.add(ExerciseHistoryEntry(
          date: session.startTime,
          e1rm: 0,
          weight: 0,
          reps: 0,
          setsCompleted: cardioSets.length,
          volume: 0,
          bestKm: double.tryParse(best.kmInput),
          bestTime: best.timeInput.isNotEmpty ? best.timeInput : null,
        ));
      } else {
        final weightSets = match.sets
            .where((s) => s.completed && s.weight != null && s.reps != null)
            .toList();
        if (weightSets.isEmpty) continue;
        double bestE1rm = 0, bestWeight = 0;
        int bestReps = 0, volSum = 0;
        for (final s in weightSets) {
          final e = s.weight! * (1 + s.reps! / 30.0);
          volSum += (s.weight! * s.reps!).round();
          if (e > bestE1rm) {
            bestE1rm = e;
            bestWeight = s.weight!;
            bestReps = s.reps!;
          }
        }
        result.add(ExerciseHistoryEntry(
          date: session.startTime,
          e1rm: bestE1rm,
          weight: bestWeight,
          reps: bestReps,
          setsCompleted: weightSets.length,
          volume: volSum,
        ));
      }
    }
    return result;
  }

  // ── Post-workout insights ──────────────────────────────────────────────────

  PostWorkoutInsights getPostWorkoutInsights(WorkoutSession session) {
    // Session is at history[0]; previous sessions start from index 1
    final prevSessions = _history.skip(1).toList();

    final thisVolume = session.totalVolume.toDouble();
    double? avgVolume;
    double? volumeChangePercent;

    final sessionExIds = session.exercises.map((e) => e.exerciseId).toSet();
    final relevantPrev = prevSessions
        .where((s) =>
            s.exercises.any((ex) => sessionExIds.contains(ex.exerciseId)))
        .take(8)
        .toList();

    if (relevantPrev.isNotEmpty) {
      avgVolume =
          relevantPrev.fold(0.0, (sum, s) => sum + s.totalVolume) /
              relevantPrev.length;
      if (avgVolume > 0) {
        volumeChangePercent = ((thisVolume - avgVolume) / avgVolume) * 100;
      }
    }

    Duration? avgDuration;
    if (prevSessions.isNotEmpty) {
      final recent = prevSessions.take(8).toList();
      final totalMins =
          recent.fold(0, (sum, s) => sum + s.duration.inMinutes);
      avgDuration = Duration(minutes: totalMins ~/ recent.length);
    }

    final totalAdded =
        session.exercises.fold(0, (sum, ex) => sum + ex.sets.length);
    final completionRate =
        totalAdded > 0 ? session.completedSets / totalAdded : 1.0;

    final exerciseInsights = <ExerciseInsight>[];
    for (final ex in session.exercises) {
      final thisSets = ex.sets
          .where((s) => s.completed && s.weight != null && s.reps != null)
          .toList();
      if (thisSets.isEmpty) continue;

      final thisBest = thisSets.reduce(
          (a, b) => (a.weight! * a.reps!) >= (b.weight! * b.reps!) ? a : b);
      final thisLabel = '${_fmtW(thisBest.weight!)} kg × ${thisBest.reps}';

      WorkoutExercise? prevEx;
      for (final s in prevSessions) {
        prevEx =
            s.exercises.where((e) => e.exerciseId == ex.exerciseId).firstOrNull;
        if (prevEx != null) break;
      }

      if (prevEx == null) {
        exerciseInsights.add(ExerciseInsight(
          exerciseName: ex.exerciseName,
          thisSession: thisLabel,
          direction: InsightDirection.first,
        ));
        continue;
      }

      final prevSets = prevEx.sets
          .where((s) => s.completed && s.weight != null && s.reps != null)
          .toList();
      if (prevSets.isEmpty) {
        exerciseInsights.add(ExerciseInsight(
          exerciseName: ex.exerciseName,
          thisSession: thisLabel,
          direction: InsightDirection.first,
        ));
        continue;
      }

      final prevBest = prevSets.reduce(
          (a, b) => (a.weight! * a.reps!) >= (b.weight! * b.reps!) ? a : b);
      final prevLabel = '${_fmtW(prevBest.weight!)} kg × ${prevBest.reps}';

      final thisVol = thisBest.weight! * thisBest.reps!;
      final prevVol = prevBest.weight! * prevBest.reps!;

      exerciseInsights.add(ExerciseInsight(
        exerciseName: ex.exerciseName,
        thisSession: thisLabel,
        lastSession: prevLabel,
        direction: thisVol > prevVol
            ? InsightDirection.up
            : thisVol < prevVol
                ? InsightDirection.down
                : InsightDirection.same,
      ));
    }

    return PostWorkoutInsights(
      thisVolume: thisVolume,
      avgVolume: avgVolume,
      volumeChangePercent: volumeChangePercent,
      thisDuration: session.duration,
      avgDuration: avgDuration,
      thisCompletedSets: session.completedSets,
      setCompletionRate: completionRate,
      exerciseInsights: exerciseInsights,
    );
  }

  static String _fmtW(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toString();

  // ── Metrics ───────────────────────────────────────────────────────────────

  /// Percentage of last [weeks] weeks where sessions >= weeklyTargetDays (0–100)
  int getConsistencyScore({int weeks = 12}) {
    if (_history.isEmpty) return 0;
    int success = 0;
    final now = DateTime.now();
    for (int i = 0; i < weeks; i++) {
      final ws = _startOfWeek(now.subtract(Duration(days: i * 7)));
      final we = ws.add(const Duration(days: 7));
      final count = _history
          .where((s) => !s.startTime.isBefore(ws) && s.startTime.isBefore(we))
          .length;
      if (count >= _weeklyTargetDays) success++;
    }
    return (success / weeks * 100).round();
  }

  /// Avg sessions/week: last 4 weeks vs previous 4 weeks
  ({double recent, double previous}) getFrequencyTrend() {
    final now = DateTime.now();
    int recent = 0, prev = 0;
    for (int i = 0; i < 4; i++) {
      final ws = _startOfWeek(now.subtract(Duration(days: i * 7)));
      final we = ws.add(const Duration(days: 7));
      recent += _history
          .where((s) => !s.startTime.isBefore(ws) && s.startTime.isBefore(we))
          .length;
    }
    for (int i = 4; i < 8; i++) {
      final ws = _startOfWeek(now.subtract(Duration(days: i * 7)));
      final we = ws.add(const Duration(days: 7));
      prev += _history
          .where((s) => !s.startTime.isBefore(ws) && s.startTime.isBefore(we))
          .length;
    }
    return (recent: recent / 4.0, previous: prev / 4.0);
  }

  /// Longest gap (days) between any two consecutive workouts
  int getLongestGapDays() {
    if (_history.length < 2) return 0;
    final sorted = [..._history]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    int max = 0;
    for (int i = 1; i < sorted.length; i++) {
      final gap =
          sorted[i].startTime.difference(sorted[i - 1].startTime).inDays;
      if (gap > max) max = gap;
    }
    return max;
  }

  /// Push-to-pull set ratio (last 30 days). Returns 1.0 if no data.
  double getPushPullRatio() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    int push = 0, pull = 0;
    for (final s in _history.where((s) => s.startTime.isAfter(cutoff))) {
      for (final ex in s.exercises) {
        final completed = ex.sets.where((s) => s.completed).length;
        final mg = ex.muscleGroup;
        final nm = ex.exerciseName.toLowerCase();
        final isPush = mg == 'Chest' ||
            mg == 'Shoulders' ||
            nm.contains('tricep') ||
            nm.contains('push') ||
            nm.contains('press');
        final isPull = mg == 'Back' ||
            nm.contains('bicep') ||
            nm.contains('row') ||
            nm.contains('pull') ||
            nm.contains('curl');
        if (isPush) push += completed;
        if (isPull) pull += completed;
      }
    }
    if (pull == 0) return push > 0 ? 99.0 : 1.0;
    return push / pull;
  }

  /// % change last week volume vs 4-week avg. Null if not enough data.
  double? getWeeklyVolumeSpike() {
    final data = getVolumeByWeek(weeks: 5);
    if (data.length < 5) return null;
    final lastWeek = data.last.volume;
    final avg4 = data.take(4).fold(0, (s, e) => s + e.volume) / 4.0;
    if (avg4 == 0) return null;
    return (lastWeek - avg4) / avg4 * 100;
  }

  /// Muscles trained historically but not in the last [days] days
  List<String> getNeglectedMuscles({int days = 14}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final everTrained = <String>{};
    final recentlyTrained = <String>{};
    for (final s in _history) {
      for (final ex in s.exercises) {
        everTrained.add(ex.muscleGroup);
        if (s.startTime.isAfter(cutoff)) recentlyTrained.add(ex.muscleGroup);
      }
    }
    return (everTrained.difference(recentlyTrained)).toList()..sort();
  }

  /// Unique exercises performed in the last [days] days
  int getExerciseVarietyScore({int days = 28}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final ids = <String>{};
    for (final s in _history.where((s) => s.startTime.isAfter(cutoff))) {
      for (final ex in s.exercises) {
        ids.add(ex.exerciseId);
      }
    }
    return ids.length;
  }

  /// Exercises done before [olderThan] days ago but not since
  List<String> getRetiredExercises({int olderThan = 45}) {
    final cutoff = DateTime.now().subtract(Duration(days: olderThan));
    final recent = <String>{};
    final old = <String, String>{};
    for (final s in _history) {
      for (final ex in s.exercises) {
        if (s.startTime.isAfter(cutoff)) {
          recent.add(ex.exerciseId);
        } else {
          old[ex.exerciseId] = ex.exerciseName;
        }
      }
    }
    final retired = old.keys.where((id) => !recent.contains(id)).toList();
    return retired.map((id) => old[id]!).toSet().toList()..sort();
  }

  /// Avg set completion rate across last 8 sessions (0.0–1.0)
  double getAvgSetCompletionRate() {
    final recent = _history.take(8).toList();
    if (recent.isEmpty) return 1.0;
    double total = 0;
    for (final s in recent) {
      final all = s.exercises.fold(0, (sum, ex) => sum + ex.sets.length);
      if (all > 0) total += s.completedSets / all;
    }
    return total / recent.length;
  }

  /// Avg sets per hour (session density) across last 8 sessions
  double getAvgSessionDensity() {
    final recent = _history.take(8).toList();
    if (recent.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (final s in recent) {
      final hours = s.duration.inMinutes / 60.0;
      if (hours > 0) {
        total += s.completedSets / hours;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  /// PRs set: last 8 weeks vs previous 8 weeks
  ({int recent, int previous}) getPRVelocity() {
    final now = DateTime.now();
    final cut8 = now.subtract(const Duration(days: 56));
    final cut16 = now.subtract(const Duration(days: 112));
    int recent = 0, prev = 0;
    for (final pr in _prRecords.values) {
      if (pr.date.isAfter(cut8)) {
        recent++;
      } else if (pr.date.isAfter(cut16)) {
        prev++;
      }
    }
    return (recent: recent, previous: prev);
  }

  /// Exercises with no e1RM improvement (< 1%) across their last 4 sessions
  List<String> getPlateauFlags() {
    final flags = <String>[];
    for (final ex in _exercises.where((e) => e.timesPerformed >= 4)) {
      final hist = getExerciseHistory(ex.id);
      if (hist.length < 4) continue;
      final last4 = hist.reversed.take(4).toList();
      if (last4.any((h) => h.e1rm == 0)) continue;
      final best = last4.map((h) => h.e1rm).reduce((a, b) => a > b ? a : b);
      final oldest = last4.last.e1rm;
      if (oldest > 0 && (best - oldest) / oldest < 0.01) {
        flags.add(ex.name);
      }
    }
    return flags;
  }

  // ── Mock data seed ────────────────────────────────────────────────────────

  void seedMockData() {
    const uuid = Uuid();
    final now = DateTime.now();

    DateTime ago(int days, {int hour = 10, int minute = 0}) =>
        DateTime(now.year, now.month, now.day - days, hour, minute);

    // Look up an exercise by partial name, fall back to an inline placeholder.
    WorkoutExercise mockEx(String search, String fallbackName,
        String fallbackMuscle, List<SetEntry> sets) {
      Exercise found;
      try {
        found = _exercises.firstWhere(
          (e) => e.name.toLowerCase().contains(search.toLowerCase()),
        );
      } catch (_) {
        found = Exercise(
            id: 'mock_${search.hashCode}',
            name: fallbackName,
            muscleGroup: fallbackMuscle);
      }
      return WorkoutExercise(
        exerciseId: found.id,
        exerciseName: found.name,
        muscleGroup: found.muscleGroup.isEmpty ? fallbackMuscle : found.muscleGroup,
        sets: sets,
      );
    }

    SetEntry s(double w, int r, {double? rpe, int num = 1}) => SetEntry(
          setNumber: num,
          weightInput: w % 1 == 0 ? w.toInt().toString() : w.toString(),
          repsInput: r.toString(),
          rpe: rpe,
          completed: true,
        );

    final sessions = <WorkoutSession>[
      WorkoutSession(
        id: uuid.v4(), name: 'Push Day',
        startTime: ago(35), endTime: ago(35, hour: 11, minute: 10),
        exercises: [
          mockEx('Bench Press', 'Bench Press (Barbell)', 'Chest',
              [s(60, 10, num: 1), s(70, 8, num: 2), s(75, 6, rpe: 8, num: 3)]),
          mockEx('Overhead Press', 'Overhead Press (Barbell)', 'Shoulders',
              [s(40, 10, num: 1), s(45, 8, num: 2), s(47.5, 6, num: 3)]),
          mockEx('Tricep Pushdown', 'Tricep Pushdown (Cable)', 'Arms',
              [s(25, 12, num: 1), s(27.5, 12, num: 2), s(30, 10, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Pull Day',
        startTime: ago(33), endTime: ago(33, hour: 11, minute: 5),
        exercises: [
          mockEx('Barbell Row', 'Barbell Row', 'Back',
              [s(60, 10, num: 1), s(65, 8, num: 2), s(70, 6, num: 3)]),
          mockEx('Lat Pulldown', 'Lat Pulldown (Cable)', 'Back',
              [s(55, 12, num: 1), s(60, 10, num: 2), s(65, 8, num: 3)]),
          mockEx('Bicep Curl', 'Bicep Curl (Barbell)', 'Arms',
              [s(30, 12, num: 1), s(32.5, 10, num: 2), s(35, 8, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Leg Day',
        startTime: ago(31), endTime: ago(31, hour: 11, minute: 20),
        exercises: [
          mockEx('Squat', 'Squat (Barbell)', 'Legs',
              [s(80, 10, num: 1), s(90, 8, num: 2), s(100, 6, rpe: 8, num: 3)]),
          mockEx('Leg Press', 'Leg Press', 'Legs',
              [s(120, 12, num: 1), s(140, 10, num: 2), s(160, 8, num: 3)]),
          mockEx('Romanian Deadlift', 'Romanian Deadlift (Barbell)', 'Legs',
              [s(60, 10, num: 1), s(65, 10, num: 2), s(70, 8, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Push Day',
        startTime: ago(28), endTime: ago(28, hour: 11, minute: 15),
        exercises: [
          mockEx('Bench Press', 'Bench Press (Barbell)', 'Chest',
              [s(62.5, 10, num: 1), s(72.5, 8, num: 2), s(77.5, 6, rpe: 8, num: 3)]),
          mockEx('Overhead Press', 'Overhead Press (Barbell)', 'Shoulders',
              [s(42.5, 10, num: 1), s(47.5, 8, num: 2), s(50, 5, num: 3)]),
          mockEx('Incline Bench Press', 'Bench Press (Barbell)', 'Chest',
              [s(55, 10, num: 1), s(60, 8, num: 2), s(65, 6, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Pull Day',
        startTime: ago(25), endTime: ago(25, hour: 11, minute: 0),
        exercises: [
          mockEx('Barbell Row', 'Barbell Row', 'Back',
              [s(62.5, 10, num: 1), s(67.5, 8, num: 2), s(72.5, 6, num: 3)]),
          mockEx('Lat Pulldown', 'Lat Pulldown (Cable)', 'Back',
              [s(60, 12, num: 1), s(65, 10, num: 2), s(70, 8, num: 3)]),
          mockEx('Bicep Curl', 'Bicep Curl (Barbell)', 'Arms',
              [s(32.5, 12, num: 1), s(35, 10, num: 2), s(37.5, 8, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Upper Body',
        startTime: ago(21), endTime: ago(21, hour: 11, minute: 30),
        exercises: [
          mockEx('Bench Press', 'Bench Press (Barbell)', 'Chest',
              [s(65, 10, num: 1), s(75, 8, num: 2), s(80, 6, rpe: 9, num: 3)]),
          mockEx('Barbell Row', 'Barbell Row', 'Back',
              [s(65, 10, num: 1), s(70, 8, num: 2), s(75, 6, num: 3)]),
          mockEx('Overhead Press', 'Overhead Press (Barbell)', 'Shoulders',
              [s(45, 10, num: 1), s(50, 8, num: 2), s(52.5, 5, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Leg Day',
        startTime: ago(17), endTime: ago(17, hour: 11, minute: 25),
        exercises: [
          mockEx('Squat', 'Squat (Barbell)', 'Legs',
              [s(85, 10, num: 1), s(95, 8, num: 2), s(105, 6, rpe: 9, num: 3)]),
          mockEx('Deadlift', 'Deadlift (Barbell)', 'Back',
              [s(100, 5, num: 1), s(110, 5, num: 2), s(120, 3, rpe: 9, num: 3)]),
          mockEx('Leg Press', 'Leg Press', 'Legs',
              [s(140, 12, num: 1), s(160, 10, num: 2), s(180, 8, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Push Day',
        startTime: ago(14), endTime: ago(14, hour: 11, minute: 10),
        exercises: [
          mockEx('Bench Press', 'Bench Press (Barbell)', 'Chest',
              [s(67.5, 10, num: 1), s(77.5, 8, num: 2), s(82.5, 5, rpe: 9, num: 3)]),
          mockEx('Overhead Press', 'Overhead Press (Barbell)', 'Shoulders',
              [s(45, 10, num: 1), s(50, 8, num: 2), s(55, 5, num: 3)]),
          mockEx('Tricep Pushdown', 'Tricep Pushdown (Cable)', 'Arms',
              [s(30, 12, num: 1), s(32.5, 12, num: 2), s(35, 10, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Pull Day',
        startTime: ago(10), endTime: ago(10, hour: 11, minute: 5),
        exercises: [
          mockEx('Barbell Row', 'Barbell Row', 'Back',
              [s(67.5, 10, num: 1), s(72.5, 8, num: 2), s(77.5, 5, rpe: 9, num: 3)]),
          mockEx('Lat Pulldown', 'Lat Pulldown (Cable)', 'Back',
              [s(65, 12, num: 1), s(70, 10, num: 2), s(75, 8, num: 3)]),
          mockEx('Bicep Curl', 'Bicep Curl (Barbell)', 'Arms',
              [s(35, 12, num: 1), s(37.5, 10, num: 2), s(40, 8, num: 3)]),
        ],
      ),
      WorkoutSession(
        id: uuid.v4(), name: 'Leg Day',
        startTime: ago(5), endTime: ago(5, hour: 11, minute: 35),
        exercises: [
          mockEx('Squat', 'Squat (Barbell)', 'Legs',
              [s(87.5, 10, num: 1), s(97.5, 8, num: 2), s(107.5, 5, rpe: 9, num: 3)]),
          mockEx('Romanian Deadlift', 'Romanian Deadlift (Barbell)', 'Legs',
              [s(65, 10, num: 1), s(70, 10, num: 2), s(75, 8, num: 3)]),
          mockEx('Leg Press', 'Leg Press', 'Legs',
              [s(150, 12, num: 1), s(170, 10, num: 2), s(190, 8, num: 3)]),
        ],
      ),
    ];

    _history.clear();
    _prRecords.clear();
    for (final e in _exercises) e.timesPerformed = 0;

    for (final session in sessions) {
      for (final ex in session.exercises) {
        final found = _exercises.firstWhere(
          (e) => e.id == ex.exerciseId,
          orElse: () => Exercise(id: '', name: '', muscleGroup: ''),
        );
        if (found.id.isNotEmpty) found.timesPerformed++;
        for (final set
            in ex.sets.where((s) => s.completed && s.weight != null && s.reps != null)) {
          final e1rm = set.weight! * (1 + set.reps! / 30.0);
          final existing = _prRecords[ex.exerciseId];
          if (existing == null || e1rm > existing.e1rm) {
            _prRecords[ex.exerciseId] = PrRecord(
              e1rm: e1rm,
              weight: set.weight!,
              reps: set.reps!,
              date: session.startTime,
            );
          }
        }
      }
      _history.add(session);
    }

    _history.sort((a, b) => b.startTime.compareTo(a.startTime));
    _save();
    notifyListeners();
  }

  // ── Reset all workout data ────────────────────────────────────────────────

  void resetAllData() {
    _history.clear();
    _prRecords.clear();
    _templates.clear();
    _seenMilestones.clear();
    _exerciseRestSeconds.clear();
    for (final e in _exercises) e.timesPerformed = 0;
    _box.delete('history');
    _box.delete('prVolumes');
    _box.delete('timesPerformed');
    _box.delete('templates');
    _box.delete('seenMilestones');
    _box.delete('exerciseRestSeconds');
    _box.delete('historySeedDone_v2');
    notifyListeners();
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  int importFromCsv(String csvContent) {
    final sessions = CsvImportService.parse(csvContent);
    final existingTimes = _history.map((s) => s.startTime).toSet();

    int count = 0;
    for (final session in sessions) {
      if (existingTimes.contains(session.startTime)) continue;

      for (final ex in session.exercises) {
        final found = _exercises.firstWhere(
          (e) => e.id == ex.exerciseId,
          orElse: () => Exercise(id: '', name: '', muscleGroup: ''),
        );
        if (found.id.isNotEmpty) found.timesPerformed++;

        for (final set in ex.sets
            .where((s) => s.completed && s.weight != null && s.reps != null)) {
          final e1rm = set.weight! * (1 + set.reps! / 30.0);
          final existing = _prRecords[ex.exerciseId];
          if (existing == null || e1rm > existing.e1rm) {
            _prRecords[ex.exerciseId] = PrRecord(
              e1rm: e1rm,
              weight: set.weight!,
              reps: set.reps!,
              date: session.startTime,
            );
          }
        }
      }

      _history.add(session);
      count++;
    }

    if (count > 0) {
      _history.sort((a, b) => b.startTime.compareTo(a.startTime));
      _save();
      notifyListeners();
    }
    return count;
  }
}
