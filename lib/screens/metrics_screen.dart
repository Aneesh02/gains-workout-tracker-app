import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WorkoutProvider>();

    if (p.history.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insights, color: AppColors.textSecondary, size: 56),
                SizedBox(height: 16),
                Text('No data yet',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Complete workouts to unlock insights.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final consistency = p.getConsistencyScore();
    final streak = p.getCurrentStreakWeeks();
    final bestStreak = p.getBestStreakWeeks();
    final gap = p.getLongestGapDays();
    final freqTrend = p.getFrequencyTrend();

    final prVel = p.getPRVelocity();
    final plateaus = p.getPlateauFlags();

    final spike = p.getWeeklyVolumeSpike();
    final pushPull = p.getPushPullRatio();

    final completion = p.getAvgSetCompletionRate();
    final density = p.getAvgSessionDensity();

    final neglected = p.getNeglectedMuscles();
    final variety = p.getExerciseVarietyScore();
    final retired = p.getRetiredExercises();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            expandedHeight: 80,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 16, bottom: 12),
              title: Text('Metrics',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: 'Consistency',
                      icon: Icons.calendar_today_outlined,
                      info: const [
                        _InfoItem(
                          metric: 'Consistency Score',
                          what: 'The percentage of the last 12 weeks where you hit your weekly session target. It only counts weeks you actually trained enough — weeks you missed entirely don\'t count as "hits".',
                          low: 'Below 50% means your training is too irregular to build momentum. Muscle and strength gains compound with consistency — sporadic training loses much of its effect.',
                          fix: 'Lower your weekly target if it\'s unrealistic. 2 solid sessions per week beats 5 sessions one week and 0 the next. Protect your non-negotiable training days.',
                        ),
                        _InfoItem(
                          metric: 'Streak',
                          what: 'Consecutive weeks where you hit your training target. A week only counts if you completed at least your target number of sessions in that calendar week (Mon–Sun, or Sun–Sat depending on your setting).',
                          low: 'A streak of 0 means you missed your target last week. Your best streak shows what you\'re capable of.',
                          fix: 'Streaks are motivational, not essential — but they do reflect habit strength. Aim to beat your previous streak one week at a time.',
                        ),
                        _InfoItem(
                          metric: 'Frequency Trend',
                          what: 'Compares how many sessions per week you averaged in the last 4 weeks versus the 4 weeks before that. Shows whether your training frequency is increasing, stable, or dropping off.',
                          low: 'If recent is lower than previous, your training frequency is declining — could be life getting in the way, fatigue, or motivation dip.',
                          fix: 'Identify what changed in the last 4 weeks. If it\'s fatigue, a short deload or active rest may help. If it\'s scheduling, block workout time in your calendar.',
                        ),
                        _InfoItem(
                          metric: 'Longest Gap',
                          what: 'The single longest stretch (in days) between any two consecutive workouts across your entire history. Flagged red above 14 days.',
                          low: 'Gaps over 7–10 days mean noticeable detraining for most lifters — strength and work capacity start to decline.',
                          fix: 'Even a short 20-minute session beats a rest day. When life is busy, keep one minimum-effort session per week to maintain the habit.',
                        ),
                      ],
                      children: [
                        _BigScoreCard(
                          value: '$consistency%',
                          label: 'Consistency Score',
                          subtitle: 'Target weeks hit in last 12 weeks',
                          color: _consistencyColor(consistency),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.local_fire_department_outlined,
                                  value: '$streak wk',
                                  label: 'Current streak',
                                  iconColor: AppColors.orange)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.emoji_events_outlined,
                                  value: '$bestStreak wk',
                                  label: 'Best streak',
                                  iconColor: Colors.amber)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.trending_up,
                                  value: _fmtFreq(freqTrend.recent),
                                  label: 'Recent (4 wk avg)',
                                  iconColor: freqTrend.recent >=
                                          freqTrend.previous
                                      ? AppColors.green
                                      : AppColors.red)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.history,
                                  value: _fmtFreq(freqTrend.previous),
                                  label: 'Prev (4 wk avg)',
                                  iconColor: AppColors.textSecondary)),
                        ]),
                        if (gap > 0) ...[
                          const SizedBox(height: 10),
                          _MetricRow(
                            icon: Icons.hourglass_bottom_outlined,
                            label: 'Longest gap between workouts',
                            value: '$gap days',
                            valueColor:
                                gap > 14 ? AppColors.red : AppColors.textPrimary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    _Section(
                      title: 'Progress',
                      icon: Icons.trending_up,
                      info: const [
                        _InfoItem(
                          metric: 'PR Velocity',
                          what: 'How many personal records (new e1RM bests) you set in the last 8 weeks, compared to the 8 weeks before. A PR here means any exercise where you beat your previous best estimated 1-rep max.',
                          low: 'Declining velocity doesn\'t mean you\'re failing — it\'s natural for PRs to slow as you get more advanced. But a sudden drop can signal fatigue, poor recovery, or stale programming.',
                          fix: 'If velocity has been low for 4+ weeks, consider a deload week, then come back with slightly different rep ranges or exercise variations.',
                        ),
                        _InfoItem(
                          metric: 'Plateau Alert',
                          what: 'Flags exercises where your estimated 1-rep max (e1RM = weight × (1 + reps÷30)) has improved by less than 1% across your last 4 sessions. A plateau means your performance on that exercise has stalled.',
                          low: 'Plateaus are normal and expected — you can\'t PR every session forever. But if the same exercises are flagged repeatedly, something needs to change.',
                          fix: 'Options to break a plateau: (1) Deload — go 20–30% lighter for a week to let your body reset. (2) Change rep range — if you\'ve been doing 5s, try 8–12 reps. (3) Add volume — one extra set per session. (4) Swap variation — e.g. swap Bench Press for Incline or Dumbbell Press for a few weeks.',
                        ),
                      ],
                      children: [
                        Row(children: [
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.bolt,
                                  value: '${prVel.recent}',
                                  label: 'PRs last 8 wks',
                                  iconColor: AppColors.blue)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.bolt_outlined,
                                  value: '${prVel.previous}',
                                  label: 'PRs prev 8 wks',
                                  iconColor: AppColors.textSecondary)),
                        ]),
                        if (plateaus.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _TagCard(
                            icon: Icons.pause_circle_outline,
                            title: 'Plateau alert',
                            subtitle: 'No e1RM gain in last 4 sessions',
                            tags: plateaus,
                            tagColor: AppColors.orange,
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          _MetricRow(
                            icon: Icons.check_circle_outline,
                            label: 'Plateau detection',
                            value: 'All good',
                            valueColor: AppColors.green,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    _Section(
                      title: 'Volume & Balance',
                      icon: Icons.balance_outlined,
                      info: const [
                        _InfoItem(
                          metric: 'Weekly Volume Spike',
                          what: 'Compares this week\'s total completed sets against your 4-week rolling average. A positive spike means you trained more than usual; negative means less.',
                          low: 'A spike above +20% significantly increases injury risk — tendons and connective tissue adapt slower than muscles. A sudden volume jump is one of the most common causes of overuse injury.',
                          fix: 'If you see a big spike, reduce volume slightly next week and let the adaptation catch up. The "10% rule" is a useful guideline: don\'t increase total weekly volume by more than 10% per week.',
                        ),
                        _InfoItem(
                          metric: 'Push / Pull Ratio',
                          what: 'Total push sets (chest, shoulders, triceps) divided by pull sets (back, biceps) in the last 30 days. A ratio of 1.0 means perfectly balanced. Above 1.0 means more pushing than pulling.',
                          low: 'A ratio above 1.5 means you\'re doing significantly more pushing than pulling. This is one of the most common causes of shoulder impingement and poor posture — internally rotated shoulders, rounded upper back.',
                          fix: 'Most people benefit from a slight pull-bias (ratio 0.8–1.0). Add more rows, face pulls, lat pulldowns, or rear delt work. Pull exercises are often undervalued because they\'re less visible than a big bench.',
                        ),
                      ],
                      children: [
                        if (spike != null) ...[
                          _MetricRow(
                            icon: Icons.show_chart,
                            label: 'Weekly volume vs 4-week avg',
                            value: spike >= 0
                                ? '+${spike.toStringAsFixed(0)}%'
                                : '${spike.toStringAsFixed(0)}%',
                            valueColor: spike > 20
                                ? AppColors.red
                                : spike > 0
                                    ? AppColors.green
                                    : AppColors.textSecondary,
                            hint: spike > 20
                                ? 'High spike — risk of overtraining'
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                        _MetricRow(
                          icon: Icons.swap_horiz,
                          label: 'Push ÷ pull ratio (last 30 days)',
                          value: pushPull >= 99
                              ? 'Push only'
                              : pushPull.toStringAsFixed(2),
                          valueColor: (pushPull > 1.5 || pushPull < 0.67)
                              ? AppColors.orange
                              : AppColors.green,
                          hint: pushPull > 1.5
                              ? 'More push than pull — consider adding rows/curls'
                              : pushPull < 0.67
                                  ? 'More pull than push'
                                  : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _Section(
                      title: 'Session Quality',
                      icon: Icons.stars_outlined,
                      info: const [
                        _InfoItem(
                          metric: 'Avg Set Completion',
                          what: 'The percentage of sets you actually complete (mark as done) across your last 8 sessions. Incomplete sets are ones you added but never checked off.',
                          low: 'Below 80% usually means you\'re planning more than you can execute — either adding too many sets, running out of time, or losing focus mid-session.',
                          fix: 'Trim your workout to what you can realistically finish. It\'s better to do 12 sets at full effort than 20 sets where you abandon the last 6. Alternatively, reduce rest times or drop an exercise rather than leaving sets incomplete.',
                        ),
                        _InfoItem(
                          metric: 'Sets / Hour (Density)',
                          what: 'How many sets you complete per hour, averaged across your last 8 sessions. Higher density means you\'re spending less time resting and more time training.',
                          low: 'Very low density (under 6–8 sets/hour) might mean very long rest periods, lots of distractions, or slow transition between exercises.',
                          fix: 'Track your rest times deliberately. If you\'re resting 4+ minutes between working sets, consider whether that\'s necessary. For hypertrophy, 60–120 seconds is typically optimal. Density is also a useful self-comparison metric — if it drops over weeks, fatigue or motivation may be building.',
                        ),
                      ],
                      children: [
                        Row(children: [
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.check_box_outlined,
                                  value:
                                      '${(completion * 100).toStringAsFixed(0)}%',
                                  label: 'Avg set completion',
                                  iconColor: completion >= 0.9
                                      ? AppColors.green
                                      : AppColors.orange)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MetricTile(
                                  icon: Icons.speed_outlined,
                                  value: density > 0
                                      ? '${density.toStringAsFixed(1)}'
                                      : '—',
                                  label: 'Sets/hour',
                                  iconColor: AppColors.blue)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _Section(
                      title: 'Variety & Balance',
                      icon: Icons.grid_view_outlined,
                      info: const [
                        _InfoItem(
                          metric: 'Unique Exercises (28 days)',
                          what: 'How many different exercises you\'ve performed in the last 28 days. More variety means you\'re hitting muscles from different angles and developing more complete strength.',
                          low: 'A score below 8 suggests you might be doing the same handful of exercises repeatedly. This isn\'t necessarily bad — strength programs often prescribe limited movement patterns — but it can lead to movement gaps over time.',
                          fix: 'You don\'t need to reinvent your training, but adding 1–2 new exercises per month helps fill gaps. Swap a variation in (e.g. Bulgarian Split Squat instead of regular Squat) or add an accessory movement you\'ve been skipping.',
                        ),
                        _InfoItem(
                          metric: 'Neglected Muscles',
                          what: 'Muscle groups you\'ve trained at some point historically but haven\'t touched in 14+ days. Based on your actual workout history — it only flags muscles you\'ve trained before, not ones you\'ve never done.',
                          low: 'Consistently neglecting a muscle group leads to imbalances. Core and rear delts are the most commonly neglected — often left out because they don\'t feel as "productive" as big compound lifts.',
                          fix: 'Add the flagged muscle group to your next session, even if it\'s just one accessory exercise. It doesn\'t need a dedicated day — a few sets of core at the end of a push day is enough to maintain it.',
                        ),
                        _InfoItem(
                          metric: 'Retired Exercises',
                          what: 'Exercises you used to do but haven\'t performed in 45+ days. Sometimes intentional (you switched programs), sometimes forgotten.',
                          low: 'No urgency here — this is more of a reminder than a warning. Some exercises get retired for good reason (injury, equipment change). Others drift away without you noticing.',
                          fix: 'Scan the list and ask: did I stop this intentionally, or did it just disappear? If it\'s the latter, consider adding it back. Old favourites often feel like PRs waiting to happen after a long break.',
                        ),
                      ],
                      children: [
                        _MetricRow(
                          icon: Icons.shuffle,
                          label: 'Unique exercises (last 28 days)',
                          value: '$variety',
                          valueColor: variety >= 8
                              ? AppColors.green
                              : AppColors.orange,
                        ),
                        if (neglected.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _TagCard(
                            icon: Icons.warning_amber_outlined,
                            title: 'Neglected muscles (14+ days)',
                            subtitle: 'You haven\'t trained these recently',
                            tags: neglected,
                            tagColor: AppColors.orange,
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          _MetricRow(
                            icon: Icons.check_circle_outline,
                            label: 'Muscle coverage',
                            value: 'All trained recently',
                            valueColor: AppColors.green,
                          ),
                        ],
                        if (retired.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _TagCard(
                            icon: Icons.archive_outlined,
                            title: 'Retired exercises (45+ days)',
                            subtitle: 'Used to do, haven\'t since',
                            tags: retired.take(6).toList(),
                            tagColor: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Color _consistencyColor(int score) {
    if (score >= 80) return AppColors.green;
    if (score >= 50) return AppColors.orange;
    return AppColors.red;
  }

  String _fmtFreq(double v) => '${v.toStringAsFixed(1)}/wk';
}

// ── Widgets ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final List<_InfoItem>? info;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            if (info != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => _showInfoSheet(context, title, info!),
                child: const Icon(Icons.info_outline,
                    color: AppColors.textSecondary, size: 18),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  static void _showInfoSheet(
      BuildContext context, String title, List<_InfoItem> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: items
                    .map((item) => _InfoItemWidget(item: item))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final String metric;
  final String what;
  final String? low;
  final String? fix;

  const _InfoItem({
    required this.metric,
    required this.what,
    this.low,
    this.fix,
  });
}

class _InfoItemWidget extends StatelessWidget {
  final _InfoItem item;

  const _InfoItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.metric,
              style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(item.what,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, height: 1.5)),
          if (item.low != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.orange, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.low!,
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                          height: 1.5)),
                ),
              ],
            ),
          ],
          if (item.fix != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.green, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.fix!,
                      style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          height: 1.5)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: AppColors.divider, height: 1),
        ],
      ),
    );
  }
}

class _BigScoreCard extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final Color color;

  const _BigScoreCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final String? hint;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tags;
  final Color tagColor;

  const _TagCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: tagColor, size: 16),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: tagColor.withOpacity(0.35), width: 1),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              color: tagColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
