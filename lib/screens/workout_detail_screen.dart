import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/workout_exercise.dart';
import '../models/set_entry.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import 'edit_workout_screen.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutDetailScreen({super.key, required this.session});

  String _shareText() {
    final buf = StringBuffer();
    buf.writeln('🏋️ ${session.name}');
    buf.writeln(DateFormat('EEE, d MMM yyyy').format(session.startTime));
    buf.writeln('⏱ ${session.formattedDuration} · 💪 ${session.totalVolume} kg · ✅ ${session.completedSets} sets');
    if (session.personalRecords.isNotEmpty) {
      buf.writeln('🏆 PRs: ${session.personalRecords.join(', ')}');
    }
    if (session.notes.isNotEmpty) {
      buf.writeln('📝 ${session.notes}');
    }
    buf.writeln();
    for (final ex in session.exercises) {
      buf.writeln(ex.exerciseName);
      for (final set in ex.sets.where((s) => s.completed)) {
        if (set.weight != null && set.reps != null) {
          final w = set.weight! % 1 == 0
              ? set.weight!.toInt().toString()
              : set.weight!.toString();
          final rpe = set.rpe != null ? ' @ ${set.rpe}' : '';
          buf.writeln('  Set ${set.setNumber}: $w kg × ${set.reps}$rpe');
        }
      }
      buf.writeln();
    }
    buf.write('via Strong Clone');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(session.name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary),
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        EditWorkoutScreen(session: session)),
              );
              // Pop back to history so the updated session is visible
              if (saved == true && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: AppColors.textSecondary),
            onPressed: () => Share.share(_shareText()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header stats
          Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(session.startTime),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            _statBox(Icons.access_time, session.formattedDuration, 'Duration'),
            const SizedBox(width: 12),
            _statBox(Icons.fitness_center, '${session.totalVolume} kg', 'Volume'),
            const SizedBox(width: 12),
            _statBox(Icons.check_circle_outline,
                '${session.completedSets}', 'Sets'),
          ]),
          if (session.personalRecords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${session.personalRecords.length} Personal Record${session.personalRecords.length > 1 ? 's' : ''}: ${session.personalRecords.join(', ')}',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],
          // Notes section
          if (session.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showNoteDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined,
                        color: AppColors.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(session.notes,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic)),
                    ),
                    const Icon(Icons.edit_outlined,
                        color: AppColors.textSecondary, size: 14),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showNoteDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: AppColors.textSecondary, size: 16),
                  SizedBox(width: 8),
                  Text('Add workout note',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Exercises
          ...session.exercises.map((ex) => _ExerciseDetail(ex: ex)),
        ],
      ),
    );
  }

  void _showNoteDialog(BuildContext context) {
    final ctrl = TextEditingController(text: session.notes);
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
          if (session.notes.isNotEmpty)
            TextButton(
                onPressed: () {
                  context.read<WorkoutProvider>().updateHistoryWorkoutNote(session.id, '');
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
                context.read<WorkoutProvider>()
                    .updateHistoryWorkoutNote(session.id, ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppColors.blue))),
        ],
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _ExerciseDetail extends StatelessWidget {
  final WorkoutExercise ex;

  const _ExerciseDetail({required this.ex});

  @override
  Widget build(BuildContext context) {
    final isCardio = ex.exerciseType == ExerciseType.cardio;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ex.exerciseName,
              style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          if (ex.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined,
                    color: AppColors.textSecondary, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(ex.notes,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            const SizedBox(
                width: 36,
                child: Text('SET', style: _colHdr)),
            const SizedBox(width: 8),
            Expanded(child: Text(isCardio ? 'KM' : 'WEIGHT', style: _colHdr)),
            Expanded(child: Text(isCardio ? 'TIME' : 'REPS', style: _colHdr)),
            if (!isCardio)
              const SizedBox(
                  width: 40,
                  child: Text('RPE',
                      textAlign: TextAlign.center, style: _colHdr)),
            const SizedBox(width: 16),
          ]),
          const SizedBox(height: 6),
          ...ex.sets.map<Widget>((SetEntry set) {
            final done = set.completed;
            final col = done ? AppColors.textPrimary : AppColors.textSecondary;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: done
                  ? const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: AppColors.divider, width: 0.5)))
                  : null,
              child: Row(children: [
                SizedBox(
                  width: 36,
                  child: Text('${set.setNumber}',
                      style: TextStyle(
                          color: done
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(width: 8),
                if (isCardio) ...[
                  Expanded(
                      child: Text(
                          set.kmInput.isNotEmpty ? '${set.kmInput} km' : '—',
                          style: TextStyle(color: col, fontSize: 14))),
                  Expanded(
                      child: Text(
                          set.timeInput.isNotEmpty
                              ? _fmtTime(set.timeInput)
                              : '—',
                          style: TextStyle(color: col, fontSize: 14))),
                ] else ...[
                  Expanded(
                      child: Text(
                          set.weight != null
                              ? '${_fmtW(set.weight!)} kg'
                              : '—',
                          style: TextStyle(color: col, fontSize: 14))),
                  Expanded(
                      child: Text(
                          set.reps != null ? '${set.reps}' : '—',
                          style: TextStyle(color: col, fontSize: 14))),
                  SizedBox(
                    width: 40,
                    child: Text(
                        set.rpe != null ? '${set.rpe}' : '—',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: col, fontSize: 14)),
                  ),
                ],
                if (done)
                  const Icon(Icons.check_circle,
                      color: AppColors.checkGreen, size: 16)
                else
                  const SizedBox(width: 16),
              ]),
            );
          }),
        ],
      ),
    );
  }

  String _fmtW(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toString();

  String _fmtTime(String input) {
    final secs = int.tryParse(input) ?? 0;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

const _colHdr = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 11,
  fontWeight: FontWeight.w600,
);
