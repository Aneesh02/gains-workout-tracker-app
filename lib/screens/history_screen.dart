import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/workout_provider.dart';
import '../models/exercise.dart';
import '../models/workout_exercise.dart';
import '../models/workout_session.dart';
import '../theme/app_theme.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Map<String, List<WorkoutSession>> _grouped(List<WorkoutSession> sessions) {
    final Map<String, List<WorkoutSession>> out = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final s in sessions) {
      final day = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      final diff = today.difference(day).inDays;
      final String key;
      if (diff == 0) {
        key = 'Today';
      } else if (diff == 1) {
        key = 'Yesterday';
      } else {
        key = DateFormat('EEE, d MMM yyyy').format(s.startTime);
      }
      out.putIfAbsent(key, () => []).add(s);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WorkoutProvider>().history;
    final grouped = _grouped(history);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.background,
          expandedHeight: 80,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: EdgeInsets.only(left: 16, bottom: 12),
            title: Text('History',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        if (history.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center_outlined,
                        color: AppColors.textSecondary, size: 52),
                    const SizedBox(height: 16),
                    const Text(
                      'No workouts yet',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Log your first session from the Workout tab, or load sample data to explore all features.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<WorkoutProvider>().seedMockData(),
                      icon: const Icon(Icons.dataset_outlined, size: 18),
                      label: const Text('Load sample data'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '10 sample sessions · all features unlocked',
                      style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final entry = grouped.entries.toList()[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              '${entry.value.length} workout${entry.value.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    ...entry.value.map((s) => _DismissibleCard(session: s)),
                  ],
                );
              },
              childCount: grouped.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class _DismissibleCard extends StatelessWidget {
  final WorkoutSession session;
  const _DismissibleCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete workout?',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text(session.name,
                style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: TextStyle(color: Colors.red.shade400)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) =>
          context.read<WorkoutProvider>().deleteWorkout(session.id),
      child: _WorkoutCard(session: session),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutSession session;

  const _WorkoutCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => WorkoutDetailScreen(session: session)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(session.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ),
              if (session.personalRecords.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text('${session.personalRecords.length} PR',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
            const SizedBox(height: 2),
            Text(_fmtDate(session.startTime),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            if (session.exercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(
                    child: Text('Sets',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13))),
                SizedBox(width: 16),
                Expanded(
                    child: Text('Best set',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13))),
              ]),
              const SizedBox(height: 4),
              ...session.exercises.map((ex) {
                final done = ex.sets.where((s) => s.completed).length;
                final bestLabel = _bestSetLabel(ex);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: [
                    Expanded(
                        child: Text('$done × ${ex.exerciseName}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(bestLabel,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13))),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _stat(Icons.access_time, session.formattedDuration),
              const SizedBox(width: 16),
              _stat(Icons.fitness_center, '${session.totalVolume} kg'),
              const SizedBox(width: 16),
              _stat(Icons.check_circle_outline,
                  '${session.completedSets} sets'),
            ]),
            ],
          ),       // Column
          ),       // inner Padding
        ),         // InkWell
      ),           // Material
    );             // outer Padding
  }

  String _bestSetLabel(WorkoutExercise ex) {
    final done = ex.sets.where((s) => s.completed).toList();
    if (done.isEmpty) return '—';
    if (ex.exerciseType == ExerciseType.cardio) {
      // best = highest km; fallback to longest time
      final withKm = done.where((s) => s.kmInput.isNotEmpty).toList();
      if (withKm.isNotEmpty) {
        final best = withKm.reduce((a, b) =>
            (double.tryParse(a.kmInput) ?? 0) >=
                    (double.tryParse(b.kmInput) ?? 0)
                ? a
                : b);
        final km = double.tryParse(best.kmInput);
        if (km != null) {
          final label = km % 1 == 0 ? '${km.toInt()} km' : '$km km';
          return best.timeInput.isNotEmpty
              ? '$label, ${_fmtTime(best.timeInput)}'
              : label;
        }
      }
      final withTime = done.where((s) => s.timeInput.isNotEmpty).toList();
      if (withTime.isNotEmpty) {
        final best = withTime.reduce((a, b) =>
            (int.tryParse(a.timeInput) ?? 0) >= (int.tryParse(b.timeInput) ?? 0)
                ? a
                : b);
        return _fmtTime(best.timeInput);
      }
      return '—';
    } else {
      final withData =
          done.where((s) => s.weight != null && s.reps != null).toList();
      if (withData.isEmpty) return '—';
      final best = withData.reduce((a, b) =>
          (a.weight! * a.reps!) >= (b.weight! * b.reps!) ? a : b);
      final label = '${_fmtW(best.weight!)} kg × ${best.reps}';
      return best.rpe != null ? '$label @ ${best.rpe}' : label;
    }
  }

  String _fmtTime(String input) {
    final secs = int.tryParse(input) ?? 0;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _stat(IconData icon, String label) {
    return Row(children: [
      Icon(icon, color: AppColors.textSecondary, size: 14),
      const SizedBox(width: 4),
      Text(label,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]);
  }

  String _fmtDate(DateTime dt) {
    return DateFormat('EEE, d MMM yyyy · h:mm a').format(dt);
  }

  String _fmtW(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toString();
}
