import 'package:home_widget/home_widget.dart';
import '../providers/workout_provider.dart';

class WidgetService {
  static const _appGroupId = 'com.gains.app';
  static const _androidName = 'GainsWidgetProvider';

  static void update(WorkoutProvider provider) {
    _pushAndUpdate(provider);
  }

  static Future<void> _pushAndUpdate(WorkoutProvider provider) async {
    try {
      final streak = provider.getCurrentStreakWeeks();
      final weeklyCount = _sessionsThisWeek(provider);
      final weeklyTarget = provider.weeklyTargetDays;
      final volumeKg = _volumeThisWeek(provider);
      final volumeStr = volumeKg > 0
          ? '${_formatNum(volumeKg)} kg'
          : '—';

      await HomeWidget.saveWidgetData('gains.streak', streak);
      await HomeWidget.saveWidgetData('gains.weeklyCount', weeklyCount);
      await HomeWidget.saveWidgetData('gains.weeklyTarget', weeklyTarget);
      await HomeWidget.saveWidgetData('gains.weeklyVolume', volumeStr);

      await HomeWidget.updateWidget(
        androidName: _androidName,
        qualifiedAndroidName: '$_appGroupId.$_androidName',
      );
    } catch (_) {}
  }

  static int _sessionsThisWeek(WorkoutProvider provider) {
    final now = DateTime.now();
    final weekday = now.weekday;
    final daysFromMonday = (weekday - DateTime.monday + 7) % 7;
    final weekStart = DateTime(now.year, now.month, now.day - daysFromMonday);
    return provider.history
        .where((s) => !s.startTime.isBefore(weekStart))
        .length;
  }

  static int _volumeThisWeek(WorkoutProvider provider) {
    final now = DateTime.now();
    final weekday = now.weekday;
    final daysFromMonday = (weekday - DateTime.monday + 7) % 7;
    final weekStart = DateTime(now.year, now.month, now.day - daysFromMonday);
    int vol = 0;
    for (final s in provider.history.where((s) => !s.startTime.isBefore(weekStart))) {
      vol += s.totalVolume;
    }
    return vol;
  }

  static String _formatNum(int n) {
    if (n >= 1000) {
      final k = n / 1000.0;
      return k % 1 == 0 ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}
