import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';

enum _ChartMetric { e1rm, maxWeight, volume }

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  _ChartMetric _metric = _ChartMetric.e1rm;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final history = provider.getExerciseHistory(widget.exercise.id);
    final pr = provider.personalRecords[widget.exercise.id];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          widget.exercise.name,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: history.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatsRow(
                    exercise: widget.exercise, history: history, pr: pr),
                const SizedBox(height: 16),
                _TrendCallout(history: history),
                const SizedBox(height: 16),
                _ChartCard(
                  history: history,
                  metric: _metric,
                  isCardio: widget.exercise.type == ExerciseType.cardio,
                  onMetricChanged: (m) => setState(() => _metric = m),
                ),
                const SizedBox(height: 16),
                _RecentSessionsTable(
                    history: history,
                    isCardio: widget.exercise.type == ExerciseType.cardio),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, color: AppColors.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text(
              widget.exercise.name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'No history yet. Complete a workout with this exercise to see your progress.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Exercise exercise;
  final List<ExerciseHistoryEntry> history;
  final dynamic pr;

  const _StatsRow(
      {required this.exercise, required this.history, required this.pr});

  @override
  Widget build(BuildContext context) {
    final lastDate = history.isNotEmpty ? history.last.date : null;
    final daysSince =
        lastDate != null ? DateTime.now().difference(lastDate).inDays : null;
    final avgSets = history.isNotEmpty
        ? (history.fold(0, (s, e) => s + e.setsCompleted) / history.length)
            .toStringAsFixed(1)
        : '—';

    String pbLabel = '—';
    if (pr != null) {
      if (pr.isCardio && pr.km != null) {
        final km = pr.km! % 1 == 0
            ? pr.km!.toInt().toString()
            : pr.km!.toString();
        pbLabel = '$km km';
      } else if (pr.weight > 0) {
        final w = pr.weight % 1 == 0
            ? pr.weight.toInt().toString()
            : pr.weight.toString();
        pbLabel = '$w kg × ${pr.reps}';
      }
    }

    return Row(
      children: [
        _stat('Personal Best', pbLabel),
        _stat('Sessions', '${history.length}'),
        _stat('Avg Sets', avgSets),
        _stat(
          'Last Trained',
          daysSince == null
              ? '—'
              : daysSince == 0
                  ? 'Today'
                  : daysSince == 1
                      ? 'Yesterday'
                      : '${daysSince}d ago',
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Trend callout ─────────────────────────────────────────────────────────

class _TrendCallout extends StatelessWidget {
  final List<ExerciseHistoryEntry> history;

  const _TrendCallout({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 3) return const SizedBox.shrink();

    final recent = history.reversed.take(4).toList();
    final values = recent.map((e) => e.e1rm > 0 ? e.e1rm : e.bestKm ?? 0).toList();

    String label;
    Color color;
    IconData icon;

    final first = values.last;
    final last = values.first;
    final diff = last - first;

    if (diff > first * 0.02) {
      label = 'Trending up over last ${recent.length} sessions';
      color = AppColors.checkGreen;
      icon = Icons.trending_up;
    } else if (diff < -(first * 0.02)) {
      label = 'Declining over last ${recent.length} sessions';
      color = Colors.orange;
      icon = Icons.trending_down;
    } else {
      label = 'Plateaued over last ${recent.length} sessions';
      color = AppColors.textSecondary;
      icon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Chart card ────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final List<ExerciseHistoryEntry> history;
  final _ChartMetric metric;
  final bool isCardio;
  final ValueChanged<_ChartMetric> onMetricChanged;

  const _ChartCard({
    required this.history,
    required this.metric,
    required this.isCardio,
    required this.onMetricChanged,
  });

  double _value(ExerciseHistoryEntry e) {
    if (isCardio) return e.bestKm ?? 0;
    switch (metric) {
      case _ChartMetric.e1rm:
        return e.e1rm;
      case _ChartMetric.maxWeight:
        return e.weight;
      case _ChartMetric.volume:
        return e.volume.toDouble();
    }
  }

  String _yLabel(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _value(e.value));
    }).toList();

    final maxY = spots.isEmpty
        ? 10.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.15;
    final minY = spots.isEmpty
        ? 0.0
        : (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.9)
            .clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCardio)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _metricChip('e1RM', _ChartMetric.e1rm),
                  const SizedBox(width: 8),
                  _metricChip('Max Weight', _ChartMetric.maxWeight),
                  const SizedBox(width: 8),
                  _metricChip('Volume', _ChartMetric.volume),
                ],
              ),
            ),
          if (!isCardio) const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: spots.length > 2,
                    color: AppColors.blue,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.blue,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.background,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.blue.withOpacity(0.08),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (value, _) => Text(
                        _yLabel(value),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= history.length) {
                          return const SizedBox.shrink();
                        }
                        // Show first, last, and ~2 in between
                        final step =
                            ((history.length - 1) / 3).ceil().clamp(1, 999);
                        if (idx != 0 &&
                            idx != history.length - 1 &&
                            idx % step != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('d/M').format(history[idx].date),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final idx = spot.x.toInt();
                      if (idx < 0 || idx >= history.length) return null;
                      final e = history[idx];
                      final date = DateFormat('d MMM').format(e.date);
                      String detail;
                      if (isCardio) {
                        detail = e.bestKm != null
                            ? '${e.bestKm!.toStringAsFixed(1)} km'
                            : '—';
                      } else {
                        switch (metric) {
                          case _ChartMetric.e1rm:
                            detail =
                                '${e.e1rm.toStringAsFixed(1)} kg e1RM\n${e.weight.toInt()}×${e.reps}';
                          case _ChartMetric.maxWeight:
                            detail = '${e.weight.toInt()} kg × ${e.reps}';
                          case _ChartMetric.volume:
                            detail = '${e.volume} kg volume';
                        }
                      }
                      return LineTooltipItem(
                        '$date\n$detail',
                        const TextStyle(
                            color: AppColors.textPrimary, fontSize: 11),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, _ChartMetric m) {
    final selected = metric == m;
    return GestureDetector(
      onTap: () => onMetricChanged(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.blue : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Recent sessions table ─────────────────────────────────────────────────

class _RecentSessionsTable extends StatelessWidget {
  final List<ExerciseHistoryEntry> history;
  final bool isCardio;

  const _RecentSessionsTable(
      {required this.history, required this.isCardio});

  String _fmtTime(String? t) {
    if (t == null || t.isEmpty) return '—';
    final secs = int.tryParse(t) ?? 0;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recent = history.reversed.take(10).toList().reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('Recent Sessions',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(
                    width: 70,
                    child: Text('Date',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text(isCardio ? 'Best Distance' : 'Best Set',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                const SizedBox(
                    width: 40,
                    child: Text('Sets',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...recent.map((e) {
            final dateStr = DateFormat('d MMM').format(e.date);
            String best;
            if (isCardio) {
              best = e.bestKm != null
                  ? '${e.bestKm!.toStringAsFixed(1)} km'
                  : '—';
              if (e.bestTime != null) best += '  ${_fmtTime(e.bestTime)}';
            } else {
              final w = e.weight % 1 == 0
                  ? e.weight.toInt().toString()
                  : e.weight.toString();
              best = e.weight > 0 ? '$w kg × ${e.reps}' : '—';
            }
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(dateStr,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(best,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${e.setsCompleted}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
