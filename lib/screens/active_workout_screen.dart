import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/github_sync_service.dart';
import '../services/metrics_markdown_service.dart';
import '../services/notification_service.dart';
import '../services/obsidian_export_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/sound_service.dart';
import '../providers/workout_provider.dart';
import '../models/workout_exercise.dart';
import '../models/set_entry.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_keyboard.dart';
import 'exercise_picker_screen.dart';
import 'congratulations_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

// Holds rest timer state without rebuilding the whole screen.
class _RestInfo {
  final int remaining;
  final int total;
  final int exIdx;
  final int setIdx;
  const _RestInfo(
      {required this.remaining,
      required this.total,
      required this.exIdx,
      required this.setIdx});
  _RestInfo tick() => _RestInfo(
      remaining: remaining - 1, total: total, exIdx: exIdx, setIdx: setIdx);
  _RestInfo adjust(int delta) => _RestInfo(
      remaining: (remaining + delta).clamp(0, 99999),
      total: total,
      exIdx: exIdx,
      setIdx: setIdx);
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late Timer _timer;
  final _keyboard = KeyboardController();
  final _scroll = ScrollController();
  final _restNotifier = ValueNotifier<_RestInfo?>(null);
  bool _restNotified = false;

  @override
  void initState() {
    super.initState();
    final keepOn = context.read<WorkoutProvider>().gymSettings.keepScreenOn;
    if (keepOn) WakelockPlus.enable();
    // Timer only touches ValueNotifier — no setState, no full rebuilds.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final info = _restNotifier.value;
      if (info != null && info.remaining > 0) {
        final next = info.tick();
        _restNotifier.value = next;
        if (next.remaining == 0 && !_restNotified) {
          _restNotified = true;
          HapticFeedback.heavyImpact();
          HapticFeedback.vibrate();
          SoundService().restOver();
        }
      }
    });
    _keyboard.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _restNotifier.dispose();
    _scroll.dispose();
    _keyboard.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onValueChanged(String value, bool isWeight) {
    final p = context.read<WorkoutProvider>();
    if (_keyboard.activeExerciseIndex == null ||
        _keyboard.activeSetIndex == null) {
      return;
    }
    final exIdx = _keyboard.activeExerciseIndex!;
    final setIdx = _keyboard.activeSetIndex!;
    final workout = p.activeWorkout;
    if (workout == null) return;
    final isCardio =
        workout.exercises[exIdx].exerciseType == ExerciseType.cardio;
    if (isCardio) {
      if (isWeight) {
        p.updateSetKm(exIdx, setIdx, value);
      } else {
        p.updateSetTime(exIdx, setIdx, value);
      }
    } else {
      if (isWeight) {
        p.updateSetWeight(exIdx, setIdx, value);
      } else {
        p.updateSetReps(exIdx, setIdx, value);
      }
    }
  }

  void _onNext() {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return;
    final exIdx = _keyboard.activeExerciseIndex!;
    final setIdx = _keyboard.activeSetIndex!;
    final isWeight = _keyboard.isWeightField;
    final ex = workout.exercises[exIdx];
    final isCardio = ex.exerciseType == ExerciseType.cardio;

    if (isWeight) {
      if (!isCardio) {
        // KG → REPS
        _keyboard.activate(
          exerciseIndex: exIdx,
          setIndex: setIdx,
          isWeight: false,
          initialValue: ex.sets[setIdx].repsInput,
          incrementStep: 1.0,
        );
      } else {
        // KM → TIME
        _keyboard.activate(
          exerciseIndex: exIdx,
          setIndex: setIdx,
          isWeight: false,
          initialValue: ex.sets[setIdx].timeInput,
          incrementStep: 10.0,
          timeField: true,
        );
      }
    } else {
      // REPS or TIME → next set
      _moveToNextEntry(exIdx, setIdx, workout);
    }
  }

  void _moveToNextEntry(int exIdx, int setIdx, dynamic workout) {
    final ex = workout.exercises[exIdx];
    final isCardio = ex.exerciseType == ExerciseType.cardio;
    if (setIdx < ex.sets.length - 1) {
      final next = ex.sets[setIdx + 1];
      _keyboard.activate(
        exerciseIndex: exIdx,
        setIndex: setIdx + 1,
        isWeight: true,
        initialValue: isCardio ? next.kmInput : next.weightInput,
        incrementStep: isCardio ? 0.5 : 2.5,
      );
    } else if (exIdx < workout.exercises.length - 1) {
      final nextEx = workout.exercises[exIdx + 1];
      final isNextCardio = nextEx.exerciseType == ExerciseType.cardio;
      _keyboard.activate(
        exerciseIndex: exIdx + 1,
        setIndex: 0,
        isWeight: true,
        initialValue: isNextCardio ? nextEx.sets[0].kmInput : nextEx.sets[0].weightInput,
        incrementStep: isNextCardio ? 0.5 : 2.5,
      );
    } else {
      _keyboard.dismiss();
    }
  }

  void _toggleComplete(int exIdx, int setIdx) {
    final p = context.read<WorkoutProvider>();
    final workout = p.activeWorkout;
    if (workout == null) return;
    final ex = workout.exercises[exIdx];
    final set = ex.sets[setIdx];
    final wasCompleted = set.completed;

    if (!wasCompleted) {
      final isCardio = ex.exerciseType == ExerciseType.cardio;
      if (isCardio) {
        if (set.kmInput.isEmpty && set.timeInput.isEmpty) return;
      } else {
        final wEmpty = set.weightInput.isEmpty;
        final rEmpty = set.repsInput.isEmpty;
        if (wEmpty || rEmpty) {
          // Auto-fill from previous if both fields are empty and prev exists
          if (wEmpty && rEmpty &&
              set.previousWeight != null &&
              set.previousReps != null) {
            p.updateSetWeight(exIdx, setIdx, _fmtW(set.previousWeight!));
            p.updateSetReps(exIdx, setIdx, '${set.previousReps}');
          } else {
            return;
          }
        }
      }
    }

    p.toggleSetComplete(exIdx, setIdx);
    if (!wasCompleted) {
      HapticFeedback.mediumImpact();
      SoundService().setComplete();
      _restNotified = false;
      _restNotifier.value = _RestInfo(
        remaining: ex.restSeconds,
        total: ex.restSeconds,
        exIdx: exIdx,
        setIdx: setIdx,
      );
    } else {
      final info = _restNotifier.value;
      if (info != null && info.exIdx == exIdx && info.setIdx == setIdx) {
        _restNotified = false;
        _restNotifier.value = null;
      }
    }
  }

  void _showExerciseMenu(BuildContext context, int exIdx, WorkoutExercise ex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            _menuTile(Icons.timer_outlined, 'Edit Rest Timer',
                '${ex.restSeconds ~/ 60}m ${ex.restSeconds % 60}s', () {
              Navigator.pop(context);
              _showRestTimerDialog(exIdx, ex.restSeconds);
            }),
            _menuTile(
                Icons.sticky_note_2_outlined,
                ex.notes.isEmpty ? 'Add Note' : 'Edit Note',
                ex.notes.isEmpty ? '' : ex.notes,
                () {
              Navigator.pop(context);
              _showNoteDialog(exIdx, ex.notes);
            }),
            _menuTile(Icons.swap_horiz, 'Replace Exercise', '', () {
              Navigator.pop(context);
              final workout = context.read<WorkoutProvider>().activeWorkout;
              final addedIds = workout?.exercises
                  .map((e) => e.exerciseId)
                  .toSet() ?? <String>{};
              addedIds.remove(ex.exerciseId); // allow replacing with self
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ExercisePickerScreen(
                        replaceIndex: exIdx,
                        alreadyAddedIds: addedIds)),
              );
            }),
            _menuTile(Icons.delete_outline, 'Delete Exercise', '',
                () {
              Navigator.pop(context);
              context.read<WorkoutProvider>().removeExercise(exIdx);
              if (_restNotifier.value?.exIdx == exIdx) {
                _restNotifier.value = null;
              }
            }, color: AppColors.red),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, String subtitle,
      VoidCallback onTap, {Color? color}) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(title, style: TextStyle(color: c)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
          : null,
      onTap: onTap,
    );
  }

  void _showNoteDialog(int exIdx, String currentNote) {
    _keyboard.dismiss();
    final ctrl = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Exercise Note',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'e.g. grip cue, pain point, form note…',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.blue)),
          ),
        ),
        actions: [
          if (currentNote.isNotEmpty)
            TextButton(
                onPressed: () {
                  context.read<WorkoutProvider>().updateExerciseNote(exIdx, '');
                  Navigator.pop(ctx);
                },
                child: const Text('Clear',
                    style: TextStyle(color: AppColors.red))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                context
                    .read<WorkoutProvider>()
                    .updateExerciseNote(exIdx, ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.blue))),
        ],
      ),
    );
  }

  void _showRestTimerDialog(int exIdx, int currentSeconds) {
    int selected = currentSeconds;
    final options = [30, 60, 90, 120, 150, 180, 240, 300];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rest Timer',
            style: TextStyle(color: AppColors.textPrimary)),
        content: StatefulBuilder(builder: (ctx, setS) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((s) {
              final m = s ~/ 60;
              final sec = s % 60;
              final label = sec == 0 ? '${m}m' : '${m}m ${sec}s';
              return RadioListTile<int>(
                value: s,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                title: Text(label,
                    style: const TextStyle(color: AppColors.textPrimary)),
                activeColor: AppColors.blue,
              );
            }).toList(),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                context.read<WorkoutProvider>().updateRestSeconds(exIdx, selected);
                Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.blue))),
        ],
      ),
    );
  }

  void _finish() {
    final p = context.read<WorkoutProvider>();
    final incomplete = p.incompleteSetsCount;
    if (incomplete > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Incomplete Sets',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
              'You have $incomplete incomplete set${incomplete > 1 ? 's' : ''}. What would you like to do?',
              style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keep Editing',
                    style: TextStyle(color: AppColors.blue))),
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _doFinish();
                },
                child: const Text('Finish Anyway',
                    style: TextStyle(color: AppColors.red))),
          ],
        ),
      );
    } else {
      _doFinish();
    }
  }

  void _doFinish() {
    _keyboard.dismiss();
    final p = context.read<WorkoutProvider>();
    final session = p.finishWorkout();
    final totalWorkouts = p.history.length;
    if (session == null || !mounted) return;

    // Both exports run in background after navigation — never block the UI
    final settings = p.gymSettings;

    // Reschedule notifications — switches pre-workout slots to post-workout content.
    NotificationService.reschedule(p, settings);

    final Future<String?> obsidianFuture = settings.obsidianVaultPath.isNotEmpty
        ? ObsidianExportService.exportToVault(session, settings.obsidianVaultPath)
        : Future.value(null);

    final Future<String?> githubFuture =
        settings.githubOwner.isNotEmpty && settings.githubRepo.isNotEmpty
            ? () async {
                final svc = GitHubSyncService();
                final sessionError = await svc.pushSession(
                  session: session,
                  owner: settings.githubOwner,
                  repo: settings.githubRepo,
                  branch: settings.githubBranch,
                  existingRecord: p.getSyncRecord(session.id),
                  onSaved: p.saveSyncRecord,
                );
                // Push metrics after the session note — errors are secondary
                await svc.pushMetrics(
                  owner: settings.githubOwner,
                  repo: settings.githubRepo,
                  branch: settings.githubBranch,
                  content: MetricsMarkdownService.buildNote(p),
                );
                return sessionError;
              }()
            : Future.value(null);

    final insights = p.getPostWorkoutInsights(session);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => CongratsScreen(
              session: session,
              totalWorkouts: totalWorkouts,
              insights: insights,
              obsidianExport: obsidianFuture,
              githubSync: githubFuture)),
    );
  }

  void _cancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Workout?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This workout will not be saved.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Keep Going', style: TextStyle(color: AppColors.blue)),
          ),
          TextButton(
            onPressed: () {
              context.read<WorkoutProvider>().cancelWorkout();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Cancel Workout',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  String _fmtRestTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtTimeDisplay(String input) {
    if (input.isEmpty) return '';
    final secs = int.tryParse(input) ?? 0;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>().activeWorkout;
    if (workout == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(workout),
            Expanded(
              child: ListView(
                controller: _scroll,
                children: [
                  _workoutHeader(workout),
                  for (int exIdx = 0;
                      exIdx < workout.exercises.length;
                      exIdx++)
                    RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _exerciseWidgets(
                            exIdx, workout.exercises[exIdx]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _actionBtn('ADD EXERCISE', AppColors.blue, () {
                    _keyboard.dismiss();
                    final addedIds = workout.exercises
                        .map((e) => e.exerciseId)
                        .toSet();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExercisePickerScreen(
                              alreadyAddedIds: addedIds)),
                    );
                  }),
                  _actionBtn(
                      workout.notes.isEmpty ? 'ADD NOTE' : 'EDIT NOTE',
                      AppColors.blue.withValues(alpha: 0.7),
                      () => _showWorkoutNoteDialog(workout.notes)),
                  _actionBtn('CANCEL WORKOUT', AppColors.red, _cancel),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            if (_keyboard.isVisible)
              CustomKeyboard(
                controller: _keyboard,
                onValueChanged: _onValueChanged,
                onNext: _onNext,
                onDismiss: _keyboard.dismiss,
                gymSettings: context.read<WorkoutProvider>().gymSettings,
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(dynamic workout) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_more, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: ValueListenableBuilder<_RestInfo?>(
                valueListenable: _restNotifier,
                builder: (_, info, __) {
                  if (info != null && info.remaining > 0) {
                    return _restTimerPill(info.remaining);
                  }
                  return _ElapsedCounter(startTime: workout.startTime);
                },
              ),
            ),
          ),
          TextButton(
            onPressed: _finish,
            child: const Text('FINISH',
                style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _restTimerPill(int seconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(_fmtRestTime(seconds),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _workoutHeader(dynamic workout) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showRenameDialog(workout.name),
                child: Text(workout.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            GestureDetector(
              onTap: () => _showRenameDialog(workout.name),
              child: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary, size: 18),
            ),
          ]),
          const SizedBox(height: 2),
          _ElapsedCounter(startTime: workout.startTime),
          if (workout.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showWorkoutNoteDialog(workout.notes),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      color: AppColors.textSecondary, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(workout.notes,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showWorkoutNoteDialog(String currentNote) {
    _keyboard.dismiss();
    final ctrl = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Workout Note',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'e.g. felt great, sore shoulder, PR day…',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.blue)),
          ),
        ),
        actions: [
          if (currentNote.isNotEmpty)
            TextButton(
                onPressed: () {
                  context.read<WorkoutProvider>().updateWorkoutNote('');
                  Navigator.pop(ctx);
                },
                child: const Text('Clear',
                    style: TextStyle(color: AppColors.red))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                context
                    .read<WorkoutProvider>()
                    .updateWorkoutNote(ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.blue))),
        ],
      ),
    );
  }

  void _showRenameDialog(String currentName) {
    _keyboard.dismiss();
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename Workout',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Workout name',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.blue)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  context.read<WorkoutProvider>().renameWorkout(name);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.blue))),
        ],
      ),
    );
  }

  List<Widget> _exerciseWidgets(int exIdx, WorkoutExercise ex) {
    final isCardio = ex.exerciseType == ExerciseType.cardio;
    return [
      // Exercise name + menu
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(children: [
          Expanded(
            child: Text(ex.exerciseName,
                style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz,
                color: AppColors.textSecondary, size: 20),
            onPressed: () => _showExerciseMenu(context, exIdx, ex),
          ),
        ]),
      ),
      // Exercise note (shown if non-empty, tappable to edit)
      if (ex.notes.isNotEmpty)
        GestureDetector(
          onTap: () => _showNoteDialog(exIdx, ex.notes),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined,
                    color: AppColors.textSecondary, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(ex.notes,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
        ),
      // Column headers
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          const SizedBox(width: 32, child: Text('SET', style: _hdr)),
          const SizedBox(width: 120, child: Text('PREVIOUS', style: _hdr)),
          Expanded(
              flex: 2,
              child: Center(child: Text(isCardio ? 'KM' : 'KG', style: _hdr))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text(isCardio ? 'TIME' : 'REPS', style: _hdr))),
          if (!isCardio)
            const SizedBox(
                width: 36, child: Center(child: Text('RPE', style: _hdr))),
          const SizedBox(
              width: 36,
              child: Center(
                  child: Icon(Icons.check,
                      color: AppColors.textSecondary, size: 16))),
        ]),
      ),
      // One swipe-to-delete row per set — direct ListView children
      for (int setIdx = 0; setIdx < ex.sets.length; setIdx++) ...[
        _setRow(exIdx, setIdx, ex.sets[setIdx], isCardio, ex.sets.length,
            ex.plateLoadingType, _typeNumber(ex.sets, setIdx)),
        ValueListenableBuilder<_RestInfo?>(
          valueListenable: _restNotifier,
          builder: (_, info, __) {
            if (info == null || info.exIdx != exIdx || info.setIdx != setIdx) {
              return const SizedBox.shrink();
            }
            return _restBar(info.remaining, info.total);
          },
        ),
      ],
      // Add set button + divider
      TextButton(
        onPressed: () => context.read<WorkoutProvider>().addSet(exIdx),
        child: Text('ADD SET (${ex.restLabel})',
            style: const TextStyle(color: AppColors.blue, fontSize: 14)),
      ),
      const Divider(color: AppColors.divider, height: 1),
    ];
  }

  Widget _restBar(int remaining, int total) {
    if (remaining == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Center(
          child: Text('Rest over — start next set',
              style: TextStyle(
                  color: AppColors.checkGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }
    final progress = (total > 0 ? remaining / total : 0.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _restAdjBtn('-30', () {
            final info = _restNotifier.value;
            if (info != null) _restNotifier.value = info.adjust(-30);
          }),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return SizedBox(
                height: 32,
                child: Stack(
                  children: [
                    Container(
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: Center(
                        child: Text(
                          _fmtRestTime(remaining),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          _restAdjBtn('+30', () {
            final info = _restNotifier.value;
            if (info != null) _restNotifier.value = info.adjust(30);
          }),
        ],
      ),
    );
  }

  Widget _restAdjBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: AppColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  int _typeNumber(List<SetEntry> sets, int setIdx) {
    final type = sets[setIdx].setType;
    int count = 0;
    for (int i = 0; i <= setIdx; i++) {
      if (sets[i].setType == type) count++;
    }
    return count;
  }

  Widget _setRow(
      int exIdx, int setIdx, SetEntry set, bool isCardio, int totalSets,
      PlateLoadingType plateLoadingType, int typeNumber) {
    final field1Active = _keyboard.isVisible &&
        _keyboard.activeExerciseIndex == exIdx &&
        _keyboard.activeSetIndex == setIdx &&
        _keyboard.isWeightField;
    final field2Active = _keyboard.isVisible &&
        _keyboard.activeExerciseIndex == exIdx &&
        _keyboard.activeSetIndex == setIdx &&
        !_keyboard.isWeightField;

    final field1Value = field1Active
        ? _keyboard.input
        : (isCardio ? set.kmInput : set.weightInput);
    final field2Value = field2Active
        ? (isCardio ? _keyboard.timeDisplay : _keyboard.input)
        : (isCardio ? _fmtTimeDisplay(set.timeInput) : set.repsInput);

    final hint1 = isCardio
        ? (set.previousKm != null ? _fmtW(set.previousKm!) : null)
        : (set.previousWeight != null ? _fmtW(set.previousWeight!) : null);
    final hint2 = isCardio
        ? (set.previousTime != null && set.previousTime!.isNotEmpty
            ? _fmtTimeDisplay(set.previousTime!)
            : null)
        : (set.previousReps != null ? '${set.previousReps}' : null);

    return _SwipeToDelete(
      key: ValueKey(set.id),
      enabled: totalSets > 1,
      onDeleted: () {
        context.read<WorkoutProvider>().removeSet(exIdx, setIdx);
        SoundService().swipeDelete();
      },
      child: Container(
        color: set.completed ? AppColors.completedGreen : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          GestureDetector(
            onTap: () => _showSetTypeMenu(exIdx, setIdx, set),
            child: SizedBox(
              width: 32,
              child: _setTypeLabel(set, typeNumber),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
                isCardio ? set.previousCardioLabel : set.previousLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: _inputField(
              value: field1Value,
              hint: hint1,
              isActive: field1Active,
              onTap: () => _keyboard.activate(
                exerciseIndex: exIdx,
                setIndex: setIdx,
                isWeight: true,
                initialValue: isCardio ? set.kmInput : set.weightInput,
                incrementStep: isCardio ? 0.5 : 2.5,
                plateLoadingType:
                    isCardio ? PlateLoadingType.none : plateLoadingType,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _inputField(
              value: field2Value,
              hint: hint2,
              isActive: field2Active,
              onTap: () => _keyboard.activate(
                exerciseIndex: exIdx,
                setIndex: setIdx,
                isWeight: false,
                initialValue: isCardio ? set.timeInput : set.repsInput,
                incrementStep: isCardio ? 10.0 : 1.0,
                timeField: isCardio,
              ),
            ),
          ),
          if (!isCardio)
            SizedBox(
              width: 36,
              child: GestureDetector(
                onTap: () => _showRpePicker(exIdx, setIdx, set.rpe),
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: set.rpe != null
                        ? AppColors.blue.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    set.rpe != null
                        ? (set.rpe! % 1 == 0
                            ? set.rpe!.toInt().toString()
                            : set.rpe!.toString())
                        : '—',
                    style: TextStyle(
                      color: set.rpe != null
                          ? AppColors.blue
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: set.rpe != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 36,
            child: GestureDetector(
              onTap: () => _toggleComplete(exIdx, setIdx),
              child: Container(
                height: 36,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: set.completed
                      ? AppColors.checkGreen
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.check,
                    color: set.completed
                        ? Colors.white
                        : AppColors.textSecondary,
                    size: 18),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _setTypeLabel(SetEntry set, int typeNumber) {
    String label;
    Color color;
    switch (set.setType) {
      case SetType.warmUp:
        label = 'W$typeNumber';
        color = Colors.amber;
        break;
      case SetType.dropSet:
        label = 'D$typeNumber';
        color = AppColors.blue;
        break;
      case SetType.failure:
        label = 'F$typeNumber';
        color = AppColors.red;
        break;
      case SetType.normal:
        label = '$typeNumber';
        color = Colors.white;
        break;
    }
    return Text(label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 12));
  }

  void _showRpePicker(int exIdx, int setIdx, double? currentRpe) {
    final rpeOptions = [for (double v = 6.0; v <= 10.0; v += 0.5) v];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RPE',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  if (currentRpe != null)
                    TextButton(
                      onPressed: () {
                        context.read<WorkoutProvider>().updateSetRpe(exIdx, setIdx, null);
                        Navigator.pop(context);
                      },
                      child: const Text('Clear',
                          style: TextStyle(color: AppColors.red, fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: rpeOptions.map((v) {
                    final label = v % 1 == 0 ? v.toInt().toString() : v.toString();
                    final selected = currentRpe == v;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          context.read<WorkoutProvider>().updateSetRpe(exIdx, setIdx, v);
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 52,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.blue : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppColors.blue : AppColors.divider,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(label,
                              style: TextStyle(
                                color: selected ? Colors.white : AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetTypeMenu(int exIdx, int setIdx, SetEntry set) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ...SetType.values.map((type) {
              final isSelected = set.setType == type;
              return ListTile(
                title: Text(_setTypeName(type),
                    style: TextStyle(
                        color: isSelected
                            ? AppColors.blue
                            : AppColors.textPrimary)),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.blue)
                    : null,
                onTap: () {
                  context
                      .read<WorkoutProvider>()
                      .updateSetType(exIdx, setIdx, type);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _setTypeName(SetType type) {
    switch (type) {
      case SetType.normal:
        return 'Normal Set';
      case SetType.warmUp:
        return 'Warm Up (W)';
      case SetType.dropSet:
        return 'Drop Set (D)';
      case SetType.failure:
        return 'Failure (F)';
    }
  }

  String _fmtW(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toString();

  Widget _inputField({
    required String value,
    required bool isActive,
    required VoidCallback onTap,
    String? hint,
  }) {
    final showHint = value.isEmpty && !isActive && hint != null && hint.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceVariant : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border:
              isActive ? Border.all(color: AppColors.blue, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          showHint ? hint : value,
          style: TextStyle(
            color: showHint
                ? AppColors.textSecondary.withValues(alpha: 0.4)
                : value.isEmpty
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextButton(
        onPressed: onTap,
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// Isolated 1-second counter — only this widget rebuilds every second.
class _ElapsedCounter extends StatefulWidget {
  final DateTime startTime;
  const _ElapsedCounter({required this.startTime});

  @override
  State<_ElapsedCounter> createState() => _ElapsedCounterState();
}

class _ElapsedCounterState extends State<_ElapsedCounter> {
  late Timer _t;

  String get _label {
    final d = DateTime.now().difference(widget.startTime);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        _label,
        style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13),
      );
}

const _hdr = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

class _SwipeToDelete extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback onDeleted;

  const _SwipeToDelete({
    super.key,
    required this.child,
    required this.enabled,
    required this.onDeleted,
  });

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  late AnimationController _ctrl;
  Animation<double>? _anim;

  static const _deleteThreshold = 80.0;
  static const _deleteVelocity = 400.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    setState(() => _offset = (_offset + d.delta.dx).clamp(-400.0, 0.0));
  }

  void _onEnd(DragEndDetails d) {
    if (!widget.enabled || _offset == 0) return;
    final velocity = d.velocity.pixelsPerSecond.dx;
    if (_offset < -_deleteThreshold || velocity < -_deleteVelocity) {
      _flyOut();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _ctrl.stop();
    _anim = Tween<double>(begin: _offset, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    )..addListener(() {
        if (mounted) setState(() => _offset = _anim!.value);
      });
    _ctrl.forward(from: 0);
  }

  void _flyOut() {
    _ctrl.stop();
    _anim = Tween<double>(begin: _offset, end: -600.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    )..addListener(() {
        if (mounted) setState(() => _offset = _anim!.value);
      });
    _ctrl.forward(from: 0).then((_) {
      if (mounted) widget.onDeleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (_offset < -8)
            Positioned.fill(
              child: Container(
                color: AppColors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 22),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
