import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../data/exercise_data.dart';
import '../models/exercise.dart';
import '../models/set_entry.dart';
import '../models/workout_exercise.dart';
import '../models/workout_session.dart';

/// Top-level function so Flutter's `compute` can run it in a background isolate.
List<Map<String, dynamic>> parseCsvBackground(String csv) =>
    CsvImportService.parse(csv).map((s) => s.toJson()).toList();

class CsvImportService {
  static const _uuid = Uuid();

  // Build a name→Exercise lookup once from the default list.
  static final Map<String, Exercise> _byName = {
    for (final e in defaultExercises) e.name: e,
  };

  /// Parses a Strong-format semicolon-delimited CSV and returns a list of
  /// WorkoutSession objects sorted newest-first.
  static List<WorkoutSession> parse(String csvContent) {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.length < 2) return [];

    // rows[i] = list of 13 fields (skip header line 0)
    final rows = lines
        .skip(1)
        .where((l) => l.trim().isNotEmpty)
        .map(_parseLine)
        .where((r) => r.length >= 11)
        .toList();

    // Group rows by workout number (col 0) preserving insertion order
    final Map<String, List<List<String>>> byWorkout = {};
    for (final row in rows) {
      byWorkout.putIfAbsent(row[0], () => []).add(row);
    }

    final sessions = <WorkoutSession>[];

    for (final workoutRows in byWorkout.values) {
      final first = workoutRows.first;
      final startTime = DateTime.tryParse(first[1]) ?? DateTime.now();
      final durationSec = int.tryParse(first[3]) ?? 0;
      final workoutName = first[2].isEmpty ? 'Imported Workout' : first[2];

      // Group rows by exercise name (preserving order of first appearance).
      // Skip metadata rows: Set Order is "Rest Timer", "Note", or any non-integer.
      final Map<String, List<List<String>>> byExercise = {};
      for (final row in workoutRows) {
        if (int.tryParse(row[5]) == null) continue;
        byExercise.putIfAbsent(row[4], () => []).add(row);
      }

      final exercises = <WorkoutExercise>[];

      for (final exEntry in byExercise.entries) {
        final exName = exEntry.key;
        if (exName.isEmpty) continue;

        final setRows = List<List<String>>.from(exEntry.value)
          ..sort((a, b) =>
              (int.tryParse(a[5]) ?? 0).compareTo(int.tryParse(b[5]) ?? 0));

        final known = _byName[exName];
        // Infer type from data if exercise not in our list
        final hasCardioData = setRows.any((r) =>
            (r.length > 9 && r[9].isNotEmpty) ||
            (r.length > 10 && r[10].isNotEmpty));
        final exerciseType =
            known?.type ?? (hasCardioData ? ExerciseType.cardio : ExerciseType.weight);
        final exerciseId = known?.id ??
            exName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        final muscleGroup = known?.muscleGroup ?? 'Other';

        final sets = <SetEntry>[];
        for (int i = 0; i < setRows.length; i++) {
          final r = setRows[i];
          final weightStr = _normalizeNum(r[6]);
          final repsStr = r[7];
          final rpeStr = r[8];
          final distanceStr = r.length > 9 ? r[9] : '';
          final secondsStr = r.length > 10 ? r[10] : '';

          // Distance: CSV stores meters → convert to km
          String kmInput = '';
          if (distanceStr.isNotEmpty) {
            final meters = double.tryParse(distanceStr);
            if (meters != null) {
              final km = meters / 1000.0;
              kmInput = km % 1 == 0 ? km.toInt().toString() : km.toStringAsFixed(2);
            }
          }

          // Time: CSV stores fractional seconds → store as integer seconds string
          String timeInput = '';
          if (secondsStr.isNotEmpty) {
            final secs = double.tryParse(secondsStr);
            if (secs != null) timeInput = secs.toInt().toString();
          }

          sets.add(SetEntry(
            setNumber: i + 1,
            weightInput: weightStr,
            repsInput: repsStr,
            rpe: rpeStr.isNotEmpty ? double.tryParse(rpeStr) : null,
            completed: true,
            kmInput: kmInput,
            timeInput: timeInput,
          ));
        }

        exercises.add(WorkoutExercise(
          exerciseId: exerciseId,
          exerciseName: exName,
          muscleGroup: muscleGroup,
          exerciseType: exerciseType,
          sets: sets,
        ));
      }

      sessions.add(WorkoutSession(
        id: _uuid.v4(),
        name: workoutName,
        startTime: startTime,
        endTime: startTime.add(Duration(seconds: durationSec)),
        exercises: exercises,
      ));
    }

    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  // Each line is: "val1";"val2";...;"valN"
  // Strip the outer quotes then split on ";"
  static List<String> _parseLine(String line) {
    var s = line;
    if (s.startsWith('"')) s = s.substring(1);
    if (s.endsWith('"')) s = s.substring(0, s.length - 1);
    return s.split('";"');
  }

  // Normalise "10.0" → "10", "10.5" → "10.5", "" → ""
  static String _normalizeNum(String s) {
    if (s.isEmpty) return s;
    final d = double.tryParse(s);
    if (d == null) return s;
    return d % 1 == 0 ? d.toInt().toString() : d.toString();
  }
}
