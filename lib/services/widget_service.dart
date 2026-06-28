import 'package:home_widget/home_widget.dart';
import '../models/workout_session.dart';
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

      // Per-day grid data (Monday=0 … Sunday=6)
      final dayData = _getDayData(provider);
      for (int i = 0; i < 7; i++) {
        await HomeWidget.saveWidgetData('gains.day$i', dayData[i]);
      }

      await HomeWidget.updateWidget(
        androidName: _androidName,
        qualifiedAndroidName: '$_appGroupId.$_androidName',
      );
      await HomeWidget.updateWidget(
        androidName: 'GainsWidgetSmallProvider',
        qualifiedAndroidName: '$_appGroupId.GainsWidgetSmallProvider',
      );
    } catch (_) {}
  }

  // Returns 7 strings indexed Monday=0 … Sunday=6.
  // Format: "<state>|<detail>"
  //   state 1 = trained (orange)
  //   state 2 = today, not yet trained (blue)
  //   state 0 = past rest day (gray)
  //   state 3 = future (dim)
  static List<String> _getDayData(WorkoutProvider provider) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    // weekday: Mon=1 … Sun=7, map to Mon=0 … Sun=6
    final todayIdx = now.weekday - 1;
    final weekMonday = todayDate.subtract(Duration(days: todayIdx));

    final data = List<String>.filled(7, '3|');

    for (int i = 0; i < 7; i++) {
      final day = weekMonday.add(Duration(days: i));

      if (day.isAfter(todayDate)) {
        data[i] = '3|'; // future
        continue;
      }

      // Find sessions on this calendar day
      final sessions = provider.history.where((s) {
        final d = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        return d == day;
      }).toList();

      if (sessions.isNotEmpty) {
        // Trained — show first session duration
        final detail = _durationStr(sessions.first);
        data[i] = '1|$detail';
      } else if (day == todayDate) {
        data[i] = '2|'; // today, not trained yet
      } else {
        data[i] = '0|'; // past rest day
      }
    }

    return data;
  }

  static String _durationStr(WorkoutSession session) {
    final end = session.endTime ?? DateTime.now();
    final mins = end.difference(session.startTime).inMinutes;
    if (mins <= 0) return '';
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '${h}h' : '${h}h${m}m';
    }
    return '${mins}m';
  }

  static int _sessionsThisWeek(WorkoutProvider provider) {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - DateTime.monday + 7) % 7;
    final weekStart = DateTime(now.year, now.month, now.day - daysFromMonday);
    return provider.history
        .where((s) => !s.startTime.isBefore(weekStart))
        .length;
  }

  static int _volumeThisWeek(WorkoutProvider provider) {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - DateTime.monday + 7) % 7;
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
