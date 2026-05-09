import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/exercise.dart';
import '../models/gym_settings.dart';
import '../models/pr_record.dart';
import '../models/workout_session.dart';
import '../providers/workout_provider.dart';
import '../services/csv_export_service.dart';
import '../services/csv_import_service.dart';
import '../services/github_sync_service.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'github_connect_screen.dart';

// Muscle group colour — same palette as workout tab
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _cachedLen = -1;
  int _cachedWeekStartDay = -1;

  // Cached expensive computations — only recomputed when history changes
  var _stats = (totalWorkouts: 0, totalSets: 0, totalVolume: 0, totalMinutes: 0, totalPRs: 0);
  var _consistency = 0;
  var _muscleAllTime = <String, int>{};
  var _mostTrained = <Exercise>[];
  var _patterns = (topDay: null as String?, topTimeOfDay: null as String?, avgDuration: Duration.zero);
  var _prs = <({String exerciseId, String exerciseName, String muscleGroup, PrRecord pr})>[];
  var _trainedDays = <DateTime>{};
  DateTime? _earliestDate;

  void _recompute(WorkoutProvider p) {
    _stats = p.getAllTimeStats();
    _consistency = p.getConsistencyScore();
    _muscleAllTime = p.getMuscleGroupSetsAllTime();
    _mostTrained = p.getMostTrainedExercises();
    _patterns = p.getTrainingPatterns();
    _prs = p.getAllTimePRs();
    _trainedDays = p.history
        .map((s) => DateTime(s.startTime.year, s.startTime.month, s.startTime.day))
        .toSet();
    _earliestDate = p.history.isNotEmpty ? p.history.last.startTime : null;
    _cachedLen = p.history.length;
    _cachedWeekStartDay = p.weekStartDay;
  }

  @override
  Widget build(BuildContext context) {
    // Only watch the fields that should trigger a UI refresh
    final provider = context.watch<WorkoutProvider>();

    // Only recompute if history or week start setting changed
    if (provider.history.length != _cachedLen ||
        provider.weekStartDay != _cachedWeekStartDay) {
      _recompute(provider);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            expandedHeight: 80,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 16, bottom: 12),
              title: Text('Profile',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          if (provider.history.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline,
                          color: AppColors.textSecondary, size: 56),
                      SizedBox(height: 16),
                      Text('No workouts yet',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Complete your first workout to see your stats here.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AllTimeStatsGrid(stats: _stats, consistencyScore: _consistency),
                      const SizedBox(height: 20),
                      _sectionTitle('Workouts per Week'),
                      const SizedBox(height: 10),
                      _WorkoutsPerWeekChart(
                        trainedDays: _trainedDays,
                        earliestDate: _earliestDate,
                        weeklyTarget: provider.weeklyTargetDays,
                        weekStartDay: provider.weekStartDay,
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('Muscle Group Breakdown'),
                      const SizedBox(height: 10),
                      _MuscleBreakdown(muscleSetMap: _muscleAllTime),
                      const SizedBox(height: 20),
                      _sectionTitle('Training Patterns'),
                      const SizedBox(height: 10),
                      _TrainingPatterns(patterns: _patterns),
                      const SizedBox(height: 20),
                      _sectionTitle('Most Trained Exercises'),
                      const SizedBox(height: 10),
                      _MostTrainedList(exercises: _mostTrained),
                      if (_prs.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionTitle('Personal Records'),
                        const SizedBox(height: 10),
                        _PRList(prs: _prs, provider: provider),
                      ],
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

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold));
}

// ── All-time stats grid ───────────────────────────────────────────────────

class _AllTimeStatsGrid extends StatelessWidget {
  final ({
    int totalWorkouts,
    int totalSets,
    int totalVolume,
    int totalMinutes,
    int totalPRs
  }) stats;
  final int consistencyScore;

  const _AllTimeStatsGrid({required this.stats, required this.consistencyScore});

  String _fmtVolume(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M kg';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k kg';
    return '$v kg';
  }

  String _fmtTime(int mins) {
    final h = mins ~/ 60;
    if (h >= 100) return '${h}h';
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _statCell(Icons.fitness_center_outlined, '${stats.totalWorkouts}',
            'Workouts'),
        _statCell(Icons.check_circle_outline, '${stats.totalSets}', 'Sets'),
        _statCell(
            Icons.scale_outlined, _fmtVolume(stats.totalVolume), 'Volume'),
        _statCell(Icons.access_time_outlined, _fmtTime(stats.totalMinutes),
            'Time'),
        _statCell(Icons.emoji_events_outlined, '${stats.totalPRs}', 'PRs'),
        _statCell(
            Icons.track_changes_outlined,
            '$consistencyScore%',
            'Consistency',
            subtitle: 'Last 18 wks'),
      ],
    );
  }

  Widget _statCell(IconData icon, String value, String label,
      {String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10),
              textAlign: TextAlign.center),
          if (subtitle != null)
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 9),
                textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Workouts-per-week stacked squares chart ───────────────────────────────

class _WorkoutsPerWeekChart extends StatefulWidget {
  final Set<DateTime> trainedDays;
  final DateTime? earliestDate;
  final int weeklyTarget;
  final int weekStartDay;

  const _WorkoutsPerWeekChart({
    required this.trainedDays,
    required this.earliestDate,
    required this.weeklyTarget,
    required this.weekStartDay,
  });

  @override
  State<_WorkoutsPerWeekChart> createState() => _WorkoutsPerWeekChartState();
}

class _WorkoutsPerWeekChartState extends State<_WorkoutsPerWeekChart> {
  static const _defaultWeeks = 18;
  static const double _sq = 14;
  static const double _gap = 3;
  static const int _days = 7;
  static const double _chartH = _days * _sq + (_days - 1) * _gap;
  static const double _labelH = 16;
  static const double _itemH = _chartH + _gap + _labelH;
  static const _dayLabels = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};

  final _scroll = ScrollController();
  bool _showAll = false;
  List<DateTime> _allWeeks = [];
  int _cachedTrainedCount = -1;
  int _cachedWeekStartDay = -1;

  @override
  void initState() {
    super.initState();
    _buildWeeks();
  }

  @override
  void didUpdateWidget(_WorkoutsPerWeekChart old) {
    super.didUpdateWidget(old);
    if (widget.trainedDays.length != _cachedTrainedCount ||
        widget.weekStartDay != _cachedWeekStartDay) {
      _buildWeeks();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime d) {
    final offset = (d.weekday - widget.weekStartDay + 7) % 7;
    return DateTime(d.year, d.month, d.day - offset);
  }

  void _buildWeeks() {
    if (widget.earliestDate == null) {
      _allWeeks = [];
    } else {
      final earliest = _startOfWeek(widget.earliestDate!);
      final current = _startOfWeek(DateTime.now());
      final weeks = <DateTime>[];
      var w = earliest;
      while (!w.isAfter(current)) {
        weeks.add(w);
        w = w.add(const Duration(days: 7));
      }
      _allWeeks = weeks;
    }
    _cachedTrainedCount = widget.trainedDays.length;
    _cachedWeekStartDay = widget.weekStartDay;
  }

  void _toggleShowAll() {
    setState(() => _showAll = !_showAll);
    if (!_showAll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _showAll
        ? _allWeeks
        : _allWeeks.sublist(max(0, _allWeeks.length - _defaultWeeks));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _itemH,
            child: weeks.isEmpty
                ? const Center(
                    child: Text('No data yet',
                        style: TextStyle(color: AppColors.textSecondary)))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed left axis — day labels
                      SizedBox(
                        width: _sq,
                        height: _chartH,
                        child: Column(
                          children: List.generate(_days, (i) {
                            final dayOffset = _days - 1 - i;
                            final dayNum =
                                (widget.weekStartDay - 1 + dayOffset) % 7 + 1;
                            return Expanded(
                              child: Center(
                                child: Text(_dayLabels[dayNum] ?? '',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600)),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ListView.separated(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          itemCount: weeks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: _gap),
                          itemBuilder: (_, idx) {
                            final weekStart = weeks[idx];
                            final trained = List.generate(_days, (d) {
                              final day = weekStart.add(Duration(days: d));
                              return widget.trainedDays.contains(
                                  DateTime(day.year, day.month, day.day));
                            });
                            final metTarget =
                                trained.where((t) => t).length >=
                                    widget.weeklyTarget;
                            final activeColor = metTarget
                                ? AppColors.blue
                                : const Color(0xFFFF9F43);

                            return SizedBox(
                              width: _sq,
                              height: _itemH,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: _chartH,
                                    child: Column(
                                      children: List.generate(_days, (i) {
                                        final dayOffset = _days - 1 - i;
                                        final didTrain = trained[dayOffset];
                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                                bottom:
                                                    i < _days - 1 ? _gap : 0),
                                            child: Container(
                                              width: _sq,
                                              decoration: BoxDecoration(
                                                color: didTrain
                                                    ? activeColor
                                                    : AppColors.divider
                                                        .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    height: _labelH,
                                    child: idx % 4 == 0 ||
                                            idx == weeks.length - 1
                                        ? FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              DateFormat('d/M')
                                                  .format(weekStart),
                                              style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 7),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _dot(AppColors.blue),
            const SizedBox(width: 4),
            const Text('Target met',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(width: 12),
            _dot(const Color(0xFFFF9F43)),
            const SizedBox(width: 4),
            const Text('Below target',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const Spacer(),
            Text(
                'Target: ${widget.weeklyTarget} day${widget.weeklyTarget == 1 ? '' : 's'}/wk',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ]),
          if (_allWeeks.length > _defaultWeeks) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _toggleShowAll,
              child: Text(
                _showAll
                    ? 'Show last 18 weeks'
                    : 'Show all history (${_allWeeks.length} weeks)',
                style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      );
}

// ── Settings screen ───────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Settings',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Training'),
          _SettingsCard(provider: provider),
          const SizedBox(height: 24),
          _sectionHeader('Gym Equipment'),
          _actionTile(
            context,
            Icons.fitness_center_outlined,
            'Plates & Bars',
            'Configure available plates and bars in your gym',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => GymEquipmentScreen(provider: provider)),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Day & Time'),
          _dayStartsTile(context, provider),
          _remindersTile(context, provider),
          const SizedBox(height: 24),
          _sectionHeader('App'),
          _switchTile(
            context,
            Icons.volume_up_outlined,
            'Sounds',
            'Checkmark, rest timer, and finish sounds',
            provider.gymSettings.soundsEnabled,
            (val) => provider.updateGymSettings(
                provider.gymSettings.copyWith(soundsEnabled: val)),
          ),
          _switchTile(
            context,
            Icons.screen_lock_portrait_outlined,
            'Keep screen on',
            'Prevents sleep during active workouts',
            provider.gymSettings.keepScreenOn,
            (val) => provider.updateGymSettings(
                provider.gymSettings.copyWith(keepScreenOn: val)),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Support'),
          _actionTile(
            context,
            Icons.bug_report_outlined,
            'Report a bug',
            'Opens an email to the developer',
            () => _launchBugReport(context),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Integrations — Phase 2'),
          _comingSoonTile(
            Icons.psychology_outlined,
            'Claude AI',
            'Guided sessions & live hints',
          ),
          _comingSoonTile(
            Icons.favorite_border_outlined,
            'Health data',
            'Connect sleep, HRV & recovery metrics',
          ),
          const SizedBox(height: 24),
          _sectionHeader('Obsidian'),
          _obsidianTile(context, provider),
          const SizedBox(height: 24),
          _sectionHeader('GitHub Sync'),
          _GitHubSyncSection(provider: provider),
          const SizedBox(height: 24),
          _sectionHeader('Data'),
          _ExportTile(provider: provider),
          _ImportTile(provider: provider),
          _comingSoonTile(
            Icons.cloud_outlined,
            'Sync to cloud',
            'Firebase backup — Phase 3',
          ),
          _ResetDataTile(provider: provider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _obsidianTile(BuildContext context, WorkoutProvider provider) {
    final path = provider.gymSettings.obsidianVaultPath;
    final hasPath = path.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: const Icon(Icons.book_outlined, color: AppColors.blue, size: 22),
        title: const Text('Vault Path',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(
          hasPath ? path : 'Tap to configure',
          style: TextStyle(
              color: hasPath ? AppColors.textSecondary : AppColors.blue,
              fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.edit_outlined,
            color: AppColors.textSecondary, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _editObsidianPath(context, provider),
      ),
    );
  }

  void _editObsidianPath(BuildContext context, WorkoutProvider provider) {
    final ctrl =
        TextEditingController(text: provider.gymSettings.obsidianVaultPath);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Obsidian Vault Path',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the full path to the folder where workout notes should be saved.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'e.g. /storage/emulated/0/Obsidian/Gym',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: '/storage/emulated/0/Obsidian/Gym',
                hintStyle: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.blue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newPath = ctrl.text.trim();
              provider.updateGymSettings(
                provider.gymSettings.copyWith(obsidianVaultPath: newPath),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Day starts at ──────────────────────────────────────────────────────────

  Widget _dayStartsTile(BuildContext context, WorkoutProvider provider) {
    final h = provider.gymSettings.dayStartHour;
    final label = h == 0
        ? 'Midnight'
        : h < 12
            ? '$h:00 AM'
            : h == 12
                ? '12:00 PM'
                : '${h - 12}:00 PM';
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: const Icon(Icons.wb_twilight_outlined,
            color: AppColors.blue, size: 22),
        title: const Text('Day starts at',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text('Used for training nudges · currently $label',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing:
            const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _showDayStartPicker(context, provider),
      ),
    );
  }

  void _showDayStartPicker(BuildContext context, WorkoutProvider provider) {
    final options = [0, 1, 2, 3, 4, 5, 6];
    final labels = ['Midnight (12:00 AM)', '1:00 AM', '2:00 AM', '3:00 AM', '4:00 AM', '5:00 AM', '6:00 AM'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Day starts at',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  'Workouts before this hour count as the previous day.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              ...List.generate(options.length, (i) {
                final selected = provider.gymSettings.dayStartHour == options[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[i],
                      style: TextStyle(
                          color: selected
                              ? AppColors.blue
                              : AppColors.textPrimary,
                          fontSize: 14)),
                  trailing: selected
                      ? const Icon(Icons.check, color: AppColors.blue, size: 18)
                      : null,
                  onTap: () {
                    provider.updateGymSettings(provider.gymSettings
                        .copyWith(dayStartHour: options[i]));
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  Widget _remindersTile(BuildContext context, WorkoutProvider provider) {
    final s = provider.gymSettings;
    final enabled = s.remindersEnabled;
    final h = s.reminderHour;
    final m = s.reminderMinute;
    final amPm = h < 12 ? 'AM' : 'PM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    final timeLabel = '$displayH:${m.toString().padLeft(2, '0')} $amPm';
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: Icon(
          enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_outlined,
          color: enabled ? AppColors.blue : AppColors.textSecondary,
          size: 22,
        ),
        title: const Text('Reminders',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(
          enabled ? 'Daily nudge at $timeLabel' : 'Off',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Switch(
          value: enabled,
          activeColor: AppColors.blue,
          onChanged: (val) async {
            if (val) {
              final granted = await NotificationService.requestPermission();
              if (!granted) return;
            }
            final newSettings = provider.gymSettings.copyWith(remindersEnabled: val);
            provider.updateGymSettings(newSettings);
            NotificationService.reschedule(provider, newSettings);
          },
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: enabled
            ? () => _showReminderTimePicker(context, provider)
            : null,
      ),
    );
  }

  Future<void> _showReminderTimePicker(
      BuildContext context, WorkoutProvider provider) async {
    final s = provider.gymSettings;
    final initial = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.blue,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final newSettings = provider.gymSettings
        .copyWith(reminderHour: picked.hour, reminderMinute: picked.minute);
    provider.updateGymSettings(newSettings);
    NotificationService.reschedule(provider, newSettings);
  }

  // ── Generic tiles ─────────────────────────────────────────────────────────

  Widget _switchTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: Icon(icon, color: AppColors.blue, size: 22),
        title: Text(title,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        trailing: Switch(
          value: value,
          activeColor: AppColors.blue,
          onChanged: onChanged,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Future<void> _launchBugReport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'aneeshtickoo2002@gmail.com',
      query: 'subject=Gains Bug Report&body=Describe the bug here...',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open email app'),
            backgroundColor: AppColors.surface),
      );
    }
  }

  Widget _actionTile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: Icon(icon, color: AppColors.blue, size: 22),
        title: Text(title,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );

  Widget _comingSoonTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('Soon',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

// ── GitHub Sync section ───────────────────────────────────────────────────────

class _GitHubSyncSection extends StatefulWidget {
  final WorkoutProvider provider;
  const _GitHubSyncSection({required this.provider});

  @override
  State<_GitHubSyncSection> createState() => _GitHubSyncSectionState();
}

class _GitHubSyncSectionState extends State<_GitHubSyncSection> {
  final _svc = GitHubSyncService();
  bool _hasToken = false;
  bool _syncing = false;
  String? _syncResult;

  WorkoutProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    _svc.hasPat().then((v) {
      if (mounted) setState(() => _hasToken = v);
    });
  }

  bool get _isConnected {
    final s = _p.gymSettings;
    return _hasToken && s.githubOwner.isNotEmpty && s.githubRepo.isNotEmpty;
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Disconnect GitHub',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove your access token and repo settings. Your GitHub data is not deleted.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _svc.deletePat();
    if (mounted) {
      _p.updateGymSettings(_p.gymSettings.copyWith(
        githubOwner: '',
        githubRepo: '',
        githubUsername: '',
      ));
      setState(() => _hasToken = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _p.gymSettings;

    if (!_isConnected) {
      return Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: const BoxDecoration(color: AppColors.surface),
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined,
              color: AppColors.textSecondary, size: 22),
          title: const Text('Connect GitHub',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: const Text('Sign in to sync workouts as markdown',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 20),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => const GitHubConnectScreen()),
            );
            if (result == true && mounted) {
              setState(() => _hasToken = true);
            }
          },
        ),
      );
    }

    return Column(children: [
      // Connected status
      Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: const BoxDecoration(color: AppColors.surface),
        child: ListTile(
          leading: const Icon(Icons.check_circle,
              color: AppColors.checkGreen, size: 22),
          title: Text(
            s.githubUsername.isNotEmpty
                ? '@${s.githubUsername}'
                : s.githubOwner,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${s.githubOwner}/${s.githubRepo}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const GitHubConnectScreen()),
              );
              if (result == true && mounted) setState(() {});
            },
            child: const Text('Change',
                style: TextStyle(color: AppColors.blue, fontSize: 13)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
      // Sync now
      Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: const BoxDecoration(color: AppColors.surface),
        child: ListTile(
          leading: _syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.blue),
                )
              : Icon(
                  Icons.sync,
                  color: _syncResult == null
                      ? AppColors.blue
                      : _syncResult!.contains('failed')
                          ? AppColors.red
                          : AppColors.checkGreen,
                  size: 22,
                ),
          title: const Text('Sync Now',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text(
            _syncing
                ? 'Syncing…'
                : _syncResult ?? 'Push all changes to GitHub',
            style: TextStyle(
                color: _syncResult != null &&
                        _syncResult!.contains('failed')
                    ? AppColors.red
                    : AppColors.textSecondary,
                fontSize: 12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: _syncing ? null : () => _runSync(context),
        ),
      ),
      // Disconnect
      Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: const BoxDecoration(color: AppColors.surface),
        child: ListTile(
          leading: const Icon(Icons.link_off_outlined,
              color: AppColors.red, size: 22),
          title: const Text('Disconnect',
              style: TextStyle(color: AppColors.red, fontSize: 14)),
          subtitle: const Text('Remove token and repo settings',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: _disconnect,
        ),
      ),
    ]);
  }

  Future<void> _runSync(BuildContext context) async {
    setState(() {
      _syncing = true;
      _syncResult = null;
    });
    final result = await _p.syncToGitHub();
    if (mounted) {
      setState(() {
        _syncing = false;
        _syncResult = result.label;
      });
      if (result.errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errors.first,
                style: const TextStyle(fontSize: 12)),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

// ── CSV Export tile ──────────────────────────────────────────────────────────

class _ExportTile extends StatefulWidget {
  final WorkoutProvider provider;
  const _ExportTile({required this.provider});

  @override
  State<_ExportTile> createState() => _ExportTileState();
}

class _ExportTileState extends State<_ExportTile> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: _exporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.blue),
              )
            : const Icon(Icons.upload_outlined,
                color: AppColors.blue, size: 22),
        title: const Text('Export Workouts',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(
          '${widget.provider.history.length} sessions · CSV format',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: _exporting ? null : _export,
      ),
    );
  }

  Future<void> _export() async {
    if (widget.provider.history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workouts to export')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      await CsvExportService.exportAndShare(widget.provider.history);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ── CSV import tile ───────────────────────────────────────────────────────────

class _ImportTile extends StatefulWidget {
  final WorkoutProvider provider;
  const _ImportTile({required this.provider});

  @override
  State<_ImportTile> createState() => _ImportTileState();
}

class _ImportTileState extends State<_ImportTile> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.blue),
              )
            : const Icon(Icons.download_outlined,
                color: AppColors.blue, size: 22),
        title: const Text('Import data from CSV',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: const Text(
          'Import workout history from a CSV file',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: _importing ? null : _import,
      ),
    );
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importing = true);
    try {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final jsonList = await compute(parseCsvBackground, content);
      final sessions =
          jsonList.map((j) => WorkoutSession.fromJson(j)).toList();
      final added = widget.provider.importFromStrong(sessions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(added == 0
              ? 'Nothing new — all sessions already imported'
              : 'Imported $added workout${added == 1 ? '' : 's'} from Strong'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

// ── Reset all data tile ───────────────────────────────────────────────────────

class _ResetDataTile extends StatelessWidget {
  final WorkoutProvider provider;
  const _ResetDataTile({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListTile(
        leading: const Icon(Icons.delete_sweep_outlined,
            color: AppColors.red, size: 22),
        title: const Text('Reset all data',
            style: TextStyle(color: AppColors.red, fontSize: 14)),
        subtitle: const Text('Delete all workouts, PRs and history',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _confirm(context),
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset all data?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete all your workouts, personal records, and history. Your settings and GitHub connection are kept.\n\nThis cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.resetAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All workout data has been reset.'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
            child: const Text('Reset',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Training settings card ─────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final WorkoutProvider provider;

  const _SettingsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Training Settings',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly target',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('Days/week needed to count a streak',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                onPressed: provider.weeklyTargetDays > 1
                    ? () => provider
                        .setWeeklyTargetDays(provider.weeklyTargetDays - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.blue,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '${provider.weeklyTargetDays}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: provider.weeklyTargetDays < 7
                    ? () => provider
                        .setWeeklyTargetDays(provider.weeklyTargetDays + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.blue,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Week starts on',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
              ),
              _chip(context, 'Mon', 1),
              const SizedBox(width: 8),
              _chip(context, 'Sun', 7),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int day) {
    final selected = provider.weekStartDay == day;
    return GestureDetector(
      onTap: () => provider.setWeekStartDay(day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.blue : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ── Muscle group breakdown ─────────────────────────────────────────────────

class _MuscleBreakdown extends StatelessWidget {
  final Map<String, int> muscleSetMap;

  const _MuscleBreakdown({required this.muscleSetMap});

  @override
  Widget build(BuildContext context) {
    final sorted = muscleSetMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxSets = sorted.isEmpty ? 1 : sorted.first.value;
    final total = sorted.fold(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: sorted.map((e) {
          final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(e.key,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / maxSets,
                      backgroundColor: AppColors.background,
                      color: _muscleColor(e.key),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  child: Text('${e.value} ($pct%)',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Training patterns ─────────────────────────────────────────────────────

class _TrainingPatterns extends StatelessWidget {
  final ({String? topDay, String? topTimeOfDay, Duration avgDuration})
      patterns;

  const _TrainingPatterns({required this.patterns});

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _patternTile(Icons.calendar_today_outlined,
              patterns.topDay ?? '—', 'Top day'),
          _patternTile(Icons.wb_sunny_outlined,
              patterns.topTimeOfDay ?? '—', 'Typical time'),
          _patternTile(Icons.timer_outlined,
              _fmtDur(patterns.avgDuration), 'Avg duration'),
        ],
      ),
    );
  }

  Widget _patternTile(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Most trained exercises ─────────────────────────────────────────────────

class _MostTrainedList extends StatelessWidget {
  final List<dynamic> exercises;

  const _MostTrainedList({required this.exercises});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: exercises.asMap().entries.map((entry) {
          final ex = entry.value;
          final isLast = entry.key == exercises.length - 1;
          return Column(
            children: [
              InkWell(
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(12))
                    : BorderRadius.zero,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ExerciseDetailScreen(exercise: ex)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _muscleColor(ex.muscleGroup)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(ex.muscleGroup[0],
                              style: TextStyle(
                                  color: _muscleColor(ex.muscleGroup),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(ex.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14)),
                      ),
                      Text('${ex.timesPerformed}×',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary, size: 16),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── PR list ───────────────────────────────────────────────────────────────

class _PRList extends StatelessWidget {
  final List<
      ({
        String exerciseId,
        String exerciseName,
        String muscleGroup,
        PrRecord pr
      })> prs;
  final WorkoutProvider provider;

  const _PRList({required this.prs, required this.provider});

  String _fmtW(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toString();

  @override
  Widget build(BuildContext context) {
    // Group by muscle group
    final grouped = <String,
        List<({String exerciseId, String exerciseName, String muscleGroup, PrRecord pr})>>{};
    for (final pr in prs) {
      grouped.putIfAbsent(pr.muscleGroup, () => []).add(pr);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(entry.key,
                  style: TextStyle(
                      color: _muscleColor(entry.key),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: entry.value.asMap().entries.map((e) {
                  final item = e.value;
                  final isLast = e.key == entry.value.length - 1;
                  final hasDetails = item.pr.isCardio
                      ? item.pr.km != null
                      : item.pr.weight > 0 && item.pr.reps > 0;
                  final ex = provider.exercises.firstWhere(
                    (ex) => ex.id == item.exerciseId,
                    orElse: () => provider.exercises.first,
                  );
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ExerciseDetailScreen(exercise: ex)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(item.exerciseName,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14)),
                              ),
                              if (hasDetails)
                                Text(
                                  item.pr.isCardio
                                      ? '${_fmtW(item.pr.km!)} km'
                                      : '${_fmtW(item.pr.weight)} kg × ${item.pr.reps}',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                )
                              else
                                Text(
                                  item.pr.e1rm.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textSecondary, size: 16),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            indent: 16,
                            color: AppColors.divider),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Gym Equipment Screen ──────────────────────────────────────────────────

class GymEquipmentScreen extends StatefulWidget {
  final WorkoutProvider provider;

  const GymEquipmentScreen({super.key, required this.provider});

  @override
  State<GymEquipmentScreen> createState() => _GymEquipmentScreenState();
}

class _GymEquipmentScreenState extends State<GymEquipmentScreen> {
  late GymSettings _settings;

  // Standard plate sizes for quick-toggle
  static const _allPlates = [50.0, 25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 0.5, 0.25];

  @override
  void initState() {
    super.initState();
    final s = widget.provider.gymSettings;
    _settings = GymSettings(
      bars: List.from(s.bars.map((b) => GymBar(name: b.name, weight: b.weight))),
      plates: List.from(s.plates),
    );
  }

  void _save() {
    widget.provider.updateGymSettings(_settings);
  }

  void _togglePlate(double kg) {
    setState(() {
      if (_settings.plates.contains(kg)) {
        _settings.plates.remove(kg);
      } else {
        _settings.plates.add(kg);
        _settings.plates.sort((a, b) => b.compareTo(a));
      }
    });
    _save();
  }

  void _addCustomPlate() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add custom plate',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Weight (kg)',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: AppColors.textSecondary),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final kg = double.tryParse(controller.text);
              if (kg != null && kg > 0 && !_settings.plates.contains(kg)) {
                setState(() {
                  _settings.plates.add(kg);
                  _settings.plates.sort((a, b) => b.compareTo(a));
                });
                _save();
              }
              Navigator.pop(ctx);
            },
            child:
                const Text('Add', style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
  }

  void _addBar() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add bar',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Bar name',
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Weight (kg)',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                suffixText: 'kg',
                suffixStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final kg = double.tryParse(weightCtrl.text);
              if (name.isNotEmpty && kg != null && kg > 0) {
                setState(() =>
                    _settings.bars.add(GymBar(name: name, weight: kg)));
                _save();
              }
              Navigator.pop(ctx);
            },
            child:
                const Text('Add', style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
  }

  void _removeBar(int idx) {
    setState(() => _settings.bars.removeAt(idx));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Plates & Bars',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Plates ──────────────────────────────────────────────────────
          _sectionHeader('Available Plates'),
          const SizedBox(height: 4),
          const Text(
            'Tap to toggle plates available in your gym. '
            'These appear in the plate calculator when entering weight.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._allPlates.map((kg) {
                final active = _settings.plates.contains(kg);
                final color = _plateColor(kg);
                return GestureDetector(
                  onTap: () => _togglePlate(kg),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: active ? color : AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? color : AppColors.divider,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _fmtKg(kg),
                          style: TextStyle(
                            color: active
                                ? _plateTextColor(kg)
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'kg',
                          style: TextStyle(
                            color: active
                                ? _plateTextColor(kg).withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: _addCustomPlate,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add,
                      color: AppColors.textSecondary, size: 22),
                ),
              ),
              // Custom plates not in the standard list
              ..._settings.plates
                  .where((kg) => !_allPlates.contains(kg))
                  .map((kg) {
                return GestureDetector(
                  onTap: () => _togglePlate(kg),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _plateColor(kg),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _fmtKg(kg),
                      style: TextStyle(
                        color: _plateTextColor(kg),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 32),

          // ── Bars ─────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _sectionHeader('Available Bars')),
              TextButton.icon(
                onPressed: _addBar,
                icon: const Icon(Icons.add, size: 16, color: AppColors.blue),
                label: const Text('Add bar',
                    style: TextStyle(color: AppColors.blue, fontSize: 13)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Bars appear in the plate calculator. '
            'Select the bar you are using to include its weight in the total.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_settings.bars.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No bars added.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _settings.bars.asMap().entries.map((e) {
                  final i = e.key;
                  final bar = e.value;
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.straighten,
                            color: AppColors.textSecondary, size: 20),
                        title: Text(bar.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14)),
                        subtitle: Text('${_fmtKg(bar.weight)} kg',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.red, size: 20),
                          onPressed: () => _removeBar(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      ),
                      if (i < _settings.bars.length - 1)
                        const Divider(
                            height: 1, indent: 16, color: AppColors.divider),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );

  Color _plateColor(double kg) {
    if (kg >= 25) return const Color(0xFFD32F2F);
    if (kg >= 20) return const Color(0xFF1565C0);
    if (kg >= 15) return const Color(0xFFF57F17);
    if (kg >= 10) return const Color(0xFF2E7D32);
    if (kg >= 5) return const Color(0xFFE0E0E0);
    if (kg >= 2.5) return const Color(0xFFC62828);
    return const Color(0xFF90A4AE);
  }

  Color _plateTextColor(double kg) =>
      kg >= 5 ? Colors.black87 : Colors.white;

  String _fmtKg(double kg) {
    if (kg % 1 == 0) return kg.toInt().toString();
    return kg.toString();
  }
}
