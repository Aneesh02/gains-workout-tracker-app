import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';
import 'exercise_picker_screen.dart';

// ── Colour for each muscle group ─────────────────────────────────────────
Color _muscleColor(String muscle) {
  const map = {
    'Chest': Color(0xFF4A9EFF),
    'Back': Color(0xFF7B61FF),
    'Shoulders': Color(0xFFFF9F43),
    'Arms': Color(0xFFFF6B6B),
    'Legs': Color(0xFF26DE81),
    'Core': Color(0xFFFECA57),
    'Full Body': Color(0xFF45B7D1),
    'Cardio': Color(0xFFFF8C94),
  };
  return map[muscle] ?? AppColors.blue;
}

class WorkoutTabScreen extends StatelessWidget {
  const WorkoutTabScreen({super.key});

  void _startEmpty(BuildContext context) {
    context.read<WorkoutProvider>().startWorkout();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()));
  }

  void _startFromTemplate(BuildContext context, WorkoutTemplate template) {
    context.read<WorkoutProvider>().startWorkoutFromTemplate(template);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()));
  }

  Future<void> _createTemplate(BuildContext context) async {
    // Step 1: get a name
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('New Template', style: TextStyle(color: AppColors.textPrimary)),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Next', style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    // Step 2: pick exercises (returnMode — picker returns List<Exercise>)
    if (!context.mounted) return;
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExercisePickerScreen(returnMode: true),
      ),
    );
    if (picked == null || picked.isEmpty) return;

    // Step 3: save
    if (!context.mounted) return;
    context.read<WorkoutProvider>().saveTemplateFromExercises(name, picked);
  }

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<WorkoutProvider>().templates;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.background,
          expandedHeight: 80,
          flexibleSpace: const FlexibleSpaceBar(
            titlePadding: EdgeInsets.only(left: 16, bottom: 12),
            title: Text('Workout',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardSection(provider: context.watch<WorkoutProvider>()),
                const SizedBox(height: 24),
                const Text('Quick start',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startEmpty(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('START AN EMPTY WORKOUT',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 28),
                Row(children: [
                  const Text('Templates',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.textSecondary),
                    onPressed: () => _createTemplate(context),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('My Templates (${templates.length})',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (templates.isEmpty)
                  _EmptyTemplatesHint(onTap: () => _createTemplate(context))
                else
                  ...templates.map((t) => _TemplateCard(
                        template: t,
                        onStart: () => _startFromTemplate(context, t),
                        onDelete: () =>
                            context.read<WorkoutProvider>().deleteTemplate(t.id),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyTemplatesHint extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyTemplatesHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.surface, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Tap to create',
                style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('a new template',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.blue, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onStart,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(template.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete Template',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text('Delete "${template.name}"?',
                style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onStart,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${template.exercises.length} exercise${template.exercises.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      if (template.exercises.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          template.exerciseSummary,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Start',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashboard section ─────────────────────────────────────────────────────

class _DashboardSection extends StatelessWidget {
  final WorkoutProvider provider;

  const _DashboardSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.history.isEmpty) return const SizedBox.shrink();

    final streak = provider.getCurrentStreakWeeks();
    final bestStreak = provider.getBestStreakWeeks();
    final consistency = provider.getConsistencyScore();
    final nudges = provider.getMuscleNudges();
    final weeklySets = provider.getWeeklyMuscleSets();
    final milestones = provider.getPendingMilestones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Milestone banners
        ...milestones.map((m) => _MilestoneBanner(
              milestone: m,
              onDismiss: () => provider.dismissMilestone(m.key),
            )),
        if (milestones.isNotEmpty) const SizedBox(height: 12),

        // Streak + Consistency row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StreakCard(streak: streak, bestStreak: bestStreak),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ConsistencyCard(score: consistency),
            ),
          ],
        ),

        // Nudge card (below, full width)
        if (nudges.isNotEmpty) ...[
          const SizedBox(height: 10),
          _NudgeCard(nudges: nudges),
        ],

        // Last-7-days muscle breakdown
        const SizedBox(height: 12),
        _MuscleBreakdownCard(weeklySets: weeklySets),
      ],
    );
  }
}

class _MilestoneBanner extends StatelessWidget {
  final PendingMilestone milestone;
  final VoidCallback onDismiss;

  const _MilestoneBanner({required this.milestone, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(milestone.label,
                style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                color: Colors.amber, size: 18),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final int bestStreak;

  const _StreakCard({required this.streak, required this.bestStreak});

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
          Row(
            children: [
              Text(
                streak > 0 ? '🔥' : '💤',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Text('week streak',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (bestStreak > streak) ...[
            const SizedBox(height: 4),
            Text('Best: $bestStreak wks',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  final int score;

  const _ConsistencyCard({required this.score});

  Color get _color {
    if (score >= 80) return const Color(0xFF26DE81);
    if (score >= 50) return const Color(0xFFFF9F43);
    return AppColors.red;
  }

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
          Row(
            children: [
              Icon(Icons.track_changes_outlined, color: _color, size: 20),
              const SizedBox(width: 6),
              Text(
                '$score%',
                style: TextStyle(
                    color: _color,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Text('consistency',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          const Text('last 12 wks',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final List<MuscleNudge> nudges;

  const _NudgeCard({required this.nudges});

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
          const Text('Due for training',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...nudges.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _muscleColor(n.muscleGroup),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(n.muscleGroup,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                    ),
                    Text('${n.daysSince}d ago',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MuscleBreakdownCard extends StatelessWidget {
  final Map<String, int> weeklySets;

  const _MuscleBreakdownCard({required this.weeklySets});

  @override
  Widget build(BuildContext context) {
    final sorted = weeklySets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxSets = sorted.isEmpty ? 1 : sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 days',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            const Text('No workouts in the last 7 days',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12))
          else
            ...sorted.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(e.key,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.value / maxSets,
                            backgroundColor: AppColors.background,
                            color: _muscleColor(e.key),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 28,
                        child: Text('${e.value}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

