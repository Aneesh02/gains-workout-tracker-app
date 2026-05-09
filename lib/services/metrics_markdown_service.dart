import '../providers/workout_provider.dart';

class MetricsMarkdownService {
  static const filePath = 'metrics-snapshot.md';

  static String buildNote(WorkoutProvider p) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final consistency = p.getConsistencyScore();
    final streak = p.getCurrentStreakWeeks();
    final bestStreak = p.getBestStreakWeeks();
    final gap = p.getLongestGapDays();
    final freq = p.getFrequencyTrend();
    final spike = p.getWeeklyVolumeSpike();
    final pushPull = p.getPushPullRatio();
    final neglected = p.getNeglectedMuscles();
    final variety = p.getExerciseVarietyScore();
    final completion = p.getAvgSetCompletionRate();
    final density = p.getAvgSessionDensity();
    final prVel = p.getPRVelocity();
    final plateaus = p.getPlateauFlags();
    final stats = p.getAllTimeStats();

    final freqTrend = freq.recent > freq.previous
        ? '↑'
        : freq.recent < freq.previous
            ? '↓'
            : '→';

    final prTrend = prVel.recent > prVel.previous
        ? '↑'
        : prVel.recent < prVel.previous
            ? '↓'
            : '→';

    final buf = StringBuffer();

    buf.writeln('---');
    buf.writeln('generated_at: ${dateStr}T$timeStr');
    buf.writeln('type: metrics-snapshot');
    buf.writeln('consistency_pct: $consistency');
    buf.writeln('current_streak_weeks: $streak');
    buf.writeln('best_streak_weeks: $bestStreak');
    buf.writeln('freq_recent: ${freq.recent.toStringAsFixed(1)}');
    buf.writeln('freq_previous: ${freq.previous.toStringAsFixed(1)}');
    buf.writeln('push_pull_ratio: ${pushPull.toStringAsFixed(2)}');
    buf.writeln('avg_completion_rate: ${(completion * 100).toStringAsFixed(0)}');
    buf.writeln('avg_density_sets_per_hr: ${density.toStringAsFixed(1)}');
    buf.writeln('pr_velocity_recent: ${prVel.recent}');
    buf.writeln('pr_velocity_previous: ${prVel.previous}');
    buf.writeln('tags: [metrics]');
    buf.writeln('---');
    buf.writeln();

    buf.writeln('# Workout Metrics Snapshot');
    buf.writeln();
    buf.writeln('_Generated $dateStr at ${timeStr}_');
    buf.writeln();

    // ── All-time totals ───────────────────────────────────────────────────
    buf.writeln('## All-Time');
    buf.writeln();
    buf.writeln('| Metric | Value |');
    buf.writeln('|--------|-------|');
    buf.writeln('| Total workouts | ${stats.totalWorkouts} |');
    buf.writeln('| Total sets | ${stats.totalSets} |');
    buf.writeln('| Total volume | ${_fmtVolume(stats.totalVolume)} |');
    buf.writeln('| Total time | ${_fmtMinutes(stats.totalMinutes)} |');
    buf.writeln('| Total PRs set | ${stats.totalPRs} |');
    buf.writeln();

    // ── Consistency & frequency ───────────────────────────────────────────
    buf.writeln('## Consistency & Frequency');
    buf.writeln();
    buf.writeln('| Metric | Value |');
    buf.writeln('|--------|-------|');
    buf.writeln('| Consistency (last 12 wks) | $consistency% |');
    buf.writeln('| Current streak | $streak weeks |');
    buf.writeln('| Best streak | $bestStreak weeks |');
    buf.writeln(
        '| Sessions/week (last 4) | ${freq.recent.toStringAsFixed(1)} $freqTrend |');
    buf.writeln(
        '| Sessions/week (prev 4) | ${freq.previous.toStringAsFixed(1)} |');
    buf.writeln('| Longest gap ever | $gap days |');
    buf.writeln();

    // ── Volume & intensity ────────────────────────────────────────────────
    buf.writeln('## Volume & Intensity');
    buf.writeln();
    buf.writeln('| Metric | Value |');
    buf.writeln('|--------|-------|');
    if (spike != null) {
      final spikeStr =
          '${spike >= 0 ? '+' : ''}${spike.toStringAsFixed(0)}%';
      buf.writeln('| Weekly volume vs 4-wk avg | $spikeStr |');
    }
    buf.writeln('| Push/pull ratio | ${pushPull.toStringAsFixed(2)} |');
    buf.writeln(
        '| Avg set completion | ${(completion * 100).toStringAsFixed(0)}% |');
    buf.writeln(
        '| Avg session density | ${density.toStringAsFixed(1)} sets/hr |');
    buf.writeln(
        '| Exercise variety (28 days) | $variety unique exercises |');
    buf.writeln();

    // ── Progress ──────────────────────────────────────────────────────────
    buf.writeln('## Progress');
    buf.writeln();
    buf.writeln('| Metric | Value |');
    buf.writeln('|--------|-------|');
    buf.writeln('| PRs last 8 wks | ${prVel.recent} $prTrend |');
    buf.writeln('| PRs prev 8 wks | ${prVel.previous} |');
    buf.writeln();

    if (plateaus.isNotEmpty) {
      buf.writeln('### Plateau Flags');
      buf.writeln();
      for (final ex in plateaus) {
        buf.writeln('- $ex');
      }
      buf.writeln();
    }

    // ── Neglected muscles ─────────────────────────────────────────────────
    if (neglected.isNotEmpty) {
      buf.writeln('## Neglected Muscles (14+ days)');
      buf.writeln();
      for (final m in neglected) {
        buf.writeln('- $m');
      }
      buf.writeln();
    }

    return buf.toString();
  }

  static String _fmtVolume(int kg) {
    if (kg >= 1000000) return '${(kg / 1000000).toStringAsFixed(1)}M kg';
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}k kg';
    return '$kg kg';
  }

  static String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}
