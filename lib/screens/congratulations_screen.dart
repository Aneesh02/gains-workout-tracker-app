import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/insights.dart';
import '../providers/workout_provider.dart';
import '../services/sound_service.dart';
import '../models/exercise.dart';
import '../models/workout_exercise.dart';
import '../models/workout_session.dart';
import '../theme/app_theme.dart';

class CongratsScreen extends StatefulWidget {
  final WorkoutSession session;
  final int totalWorkouts;
  final PostWorkoutInsights? insights;
  final Future<String?>? obsidianExport;
  final Future<String?>? githubSync;

  const CongratsScreen({
    super.key,
    required this.session,
    required this.totalWorkouts,
    this.insights,
    this.obsidianExport,
    this.githubSync,
  });

  @override
  State<CongratsScreen> createState() => _CongratsScreenState();
}

class _CongratsScreenState extends State<CongratsScreen> {
  WorkoutSession get session => widget.session;
  int get totalWorkouts => widget.totalWorkouts;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (session.personalRecords.isNotEmpty) {
        SoundService().workoutFinishPR();
      } else {
        SoundService().workoutFinish();
      }
    });
    widget.obsidianExport?.then((err) {
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Obsidian export failed: $err',
                style: const TextStyle(fontSize: 12)),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    widget.githubSync?.then((err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null ? 'Synced to GitHub ✓' : 'GitHub sync failed: $err',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: err == null ? const Color(0xFF2E7D32) : AppColors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  String _shareText() {
    final buf = StringBuffer();
    buf.writeln('🏋️ ${session.name} — Workout #$totalWorkouts');
    buf.writeln('⏱ ${session.formattedDuration} · 💪 ${session.totalVolume} kg');
    if (session.personalRecords.isNotEmpty) {
      buf.writeln('🏆 PRs: ${session.personalRecords.join(', ')}');
    }
    buf.write('via Strong Clone');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: AppColors.textSecondary),
            onPressed: () => Share.share(_shareText()),
          ),
        ],
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text('⭐⭐⭐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Congratulations!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Workout #$totalWorkouts completed!',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
                '${session.formattedDuration} · ${session.totalVolume} kg total',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            // PRs
            if (session.personalRecords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${session.personalRecords.length} New Personal Record${session.personalRecords.length > 1 ? 's' : ''}!',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ...session.personalRecords.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('🏆 $name',
                            style: const TextStyle(
                                color: Colors.amber, fontSize: 13)),
                      )),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            // Stats row
            Row(children: [
              _statBox(Icons.access_time, session.formattedDuration, 'Time'),
              const SizedBox(width: 10),
              _statBox(Icons.fitness_center, '${session.totalVolume} kg',
                  'Volume'),
              const SizedBox(width: 10),
              _statBox(Icons.check_circle_outline,
                  '${session.completedSets}', 'Sets'),
            ]),
            const SizedBox(height: 20),
            // Exercise summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(session.startTime),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  if (session.exercises.isNotEmpty) ...[
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 6),
                    ...session.exercises.map((ex) {
                      final done =
                          ex.sets.where((s) => s.completed).length;
                      final bestLabel = _bestSetLabel(ex);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(
                              child: Text('$done × ${ex.exerciseName}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Text(bestLabel,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13))),
                        ]),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _saveAsTemplate(context),
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Save as Template'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (widget.insights != null) ...[
              const SizedBox(height: 24),
              _InsightsSection(insights: widget.insights!),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate(BuildContext context) async {
    final nameController = TextEditingController(text: session.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Save as Template',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Template name',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.blue)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child:
                const Text('Save', style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    context.read<WorkoutProvider>().saveTemplate(name, session.exercises);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "$name" saved'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.blue, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ]),
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

  String _bestSetLabel(WorkoutExercise ex) {
    final done = ex.sets.where((s) => s.completed).toList();
    if (done.isEmpty) return '—';
    if (ex.exerciseType == ExerciseType.cardio) {
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
            (int.tryParse(a.timeInput) ?? 0) >=
                    (int.tryParse(b.timeInput) ?? 0)
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
}

// ── Post-workout insights section ─────────────────────────────────────────

class _InsightsSection extends StatelessWidget {
  final PostWorkoutInsights insights;

  const _InsightsSection({required this.insights});

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: AppColors.blue, size: 18),
              SizedBox(width: 8),
              Text('Session Insights',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),

          // Volume comparison
          _insightRow(
            label: 'Volume',
            value: '${insights.thisVolume.toInt()} kg',
            detail: insights.volumeChangePercent != null
                ? _pctLabel(insights.volumeChangePercent!, 'vs avg')
                : 'First session with these exercises',
            detailColor: insights.volumeChangePercent == null
                ? AppColors.textSecondary
                : insights.volumeChangePercent! >= 0
                    ? AppColors.checkGreen
                    : Colors.orange,
          ),
          const SizedBox(height: 10),

          // Duration comparison
          _insightRow(
            label: 'Duration',
            value: _fmtDuration(insights.thisDuration),
            detail: insights.avgDuration != null
                ? 'avg ${_fmtDuration(insights.avgDuration!)}'
                : null,
          ),
          const SizedBox(height: 10),

          // Set completion
          _insightRow(
            label: 'Sets completed',
            value: '${insights.thisCompletedSets}',
            detail:
                '${(insights.setCompletionRate * 100).toStringAsFixed(0)}% completion rate',
            detailColor: insights.setCompletionRate >= 1.0
                ? AppColors.checkGreen
                : insights.setCompletionRate >= 0.8
                    ? AppColors.textSecondary
                    : Colors.orange,
          ),

          if (insights.exerciseInsights.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            const Text('Exercise Breakdown',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...insights.exerciseInsights.map((ex) => _ExerciseInsightRow(insight: ex)),
          ],
        ],
      ),
    );
  }

  String _pctLabel(double pct, String suffix) {
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}% $suffix';
  }

  Widget _insightRow({
    required String label,
    required String value,
    String? detail,
    Color? detailColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        if (detail != null) ...[
          const SizedBox(width: 8),
          Text(detail,
              style: TextStyle(
                  color: detailColor ?? AppColors.textSecondary,
                  fontSize: 12)),
        ],
      ],
    );
  }
}

class _ExerciseInsightRow extends StatelessWidget {
  final ExerciseInsight insight;

  const _ExerciseInsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (insight.direction) {
      InsightDirection.up => (Icons.arrow_upward, AppColors.checkGreen),
      InsightDirection.down => (Icons.arrow_downward, Colors.orange),
      InsightDirection.same => (Icons.remove, AppColors.textSecondary),
      InsightDirection.first => (Icons.star_outline, AppColors.blue),
    };

    final subtitle = switch (insight.direction) {
      InsightDirection.first => 'First time',
      InsightDirection.same => insight.lastSession ?? '',
      _ => insight.lastSession != null
          ? 'prev: ${insight.lastSession}'
          : '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.exerciseName,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          if (insight.thisSession != null)
            Text(insight.thisSession!,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
