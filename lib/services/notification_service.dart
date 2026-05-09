import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../providers/workout_provider.dart';
import '../models/gym_settings.dart';

/// Three daily notification slots — all context-aware.
///
/// Slot A (ID 0): Morning, 9:00 AM — pre-workout focus; skipped if already trained.
/// Slot B (ID 1): User-configured time — pre-workout nudge OR post-workout celebration.
/// Slot C (ID 2): Evening, 8:30 PM — post-workout recovery only; skipped if not trained.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'gains_reminders';

  static const _idMorning = 0;
  static const _idPrimary = 1;
  static const _idEvening = 2;

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Call on app open AND immediately after a workout is finished.
  static Future<void> reschedule(
      WorkoutProvider provider, GymSettings settings) async {
    await _plugin.cancelAll();
    if (!settings.remindersEnabled) return;

    final trained = provider.workedOutToday(settings.dayStartHour);

    if (!trained) {
      // Pre-workout: morning focus + primary nudge
      await _scheduleSlotA(provider);
      await _scheduleSlotB(provider, settings, trained: false);
    } else {
      // Post-workout: primary celebration + evening recovery
      await _scheduleSlotB(provider, settings, trained: true);
      await _scheduleSlotC(provider);
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Slot A — Morning pre-workout (9 AM) ──────────────────────────────────

  static Future<void> _scheduleSlotA(WorkoutProvider provider) async {
    final content = _morningContent(provider);
    await _schedule(_idMorning, 9, 0, content.title, content.body);
  }

  static ({String title, String body}) _morningContent(WorkoutProvider p) {
    // Muscle-specific focus
    final nudges = p.getMuscleNudges();
    if (nudges.isNotEmpty) {
      final muscle = _capFirst(nudges.first.muscleGroup);
      final days = nudges.first.daysSince;
      return (
        title: "$muscle day?",
        body: "It's been $days days since you trained $muscle. "
            "Today's a great time to get it in.",
      );
    }

    // Streak pattern — best day of week
    final patterns = p.getTrainingPatterns();
    final todayName = _weekdayName(DateTime.now().weekday);
    if (patterns.topDay != null && patterns.topDay == todayName) {
      return (
        title: "Your best training day",
        body: "Your data says $todayName is your strongest day. "
            "Don't let it go to waste.",
      );
    }

    // Generic morning
    final defaults = [
      (title: "Good morning", body: "What are you training today?"),
      (
        title: "Rise and grind",
        body: "Set your intention for today's session before the day gets busy."
      ),
      (
        title: "Morning check-in",
        body: "Plan your workout now — people who plan train more consistently."
      ),
    ];
    return defaults[DateTime.now().day % defaults.length];
  }

  // ── Slot B — Primary time (user-configured) ───────────────────────────────

  static Future<void> _scheduleSlotB(
      WorkoutProvider provider, GymSettings settings,
      {required bool trained}) async {
    final content = trained
        ? _postWorkoutPrimaryContent(provider)
        : _preWorkoutPrimaryContent(provider);
    await _schedule(
        _idPrimary, settings.reminderHour, settings.reminderMinute,
        content.title, content.body);
  }

  static ({String title, String body}) _preWorkoutPrimaryContent(
      WorkoutProvider p) {
    final history = p.history;
    if (history.isEmpty) {
      return (
        title: "Log your first session",
        body: "Open Gains and start tracking. Every journey starts somewhere."
      );
    }

    final now = DateTime.now();
    final daysSinceLast =
        now.difference(history.first.startTime).inDays;

    // Long gap — comeback nudge
    if (daysSinceLast >= 5) {
      return (
        title: "Long time no lift",
        body: "$daysSinceLast days since your last session. "
            "Even something light gets you back on track.",
      );
    }

    // Streak at risk
    final streak = p.getCurrentStreakWeeks();
    if (streak > 0) {
      final needed = _sessionsNeededThisWeek(p);
      final daysLeft = _daysLeftInWeek(p.weekStartDay);
      if (needed > 0 && daysLeft <= 2) {
        final plural = needed == 1 ? 'workout' : 'workouts';
        return (
          title: "Streak alert",
          body: "Your $streak-week streak needs $needed more $plural "
              "before the week ends. Let's go.",
        );
      }
    }

    // Streak motivation — keep it alive with minimal effort
    if (streak > 1 && daysSinceLast >= 2) {
      return (
        title: "$streak weeks strong",
        body: "Even 20 minutes of cardio keeps your streak alive. "
            "Don't let it slip now.",
      );
    }

    // Push/pull imbalance
    final pushPull = p.getPushPullRatio();
    if (pushPull > 2.5) {
      return (
        title: "Balance check",
        body: "${pushPull.toStringAsFixed(1)}:1 push-to-pull ratio this month. "
            "Some rows or pull-downs wouldn't hurt.",
      );
    }

    // Volume dip
    final spike = p.getWeeklyVolumeSpike();
    if (spike != null && spike < -20) {
      return (
        title: "Volume is down",
        body: "Weekly volume is down ${spike.abs().round()}% vs last month. "
            "Push a bit harder today.",
      );
    }

    // Default — rotate
    final opts = [
      (
        title: "Time to train",
        body: "You've got time. Open Gains and get after it."
      ),
      (
        title: "Consistency wins",
        body: "One more session this week keeps the momentum going."
      ),
      (
        title: "Show up today",
        body: "You don't have to be perfect — just be present."
      ),
    ];
    return opts[now.day % opts.length];
  }

  static ({String title, String body}) _postWorkoutPrimaryContent(
      WorkoutProvider p) {
    final nudges = p.getMuscleNudges();
    final streak = p.getCurrentStreakWeeks();

    if (nudges.isNotEmpty) {
      final muscle = _capFirst(nudges.first.muscleGroup);
      final days = nudges.first.daysSince;
      if (streak > 0) {
        return (
          title: "Solid session!",
          body: "$streak-week streak is safe. Tomorrow: $muscle hasn't been "
              "trained in $days days — make it the focus.",
        );
      }
      return (
        title: "Great work today",
        body: "Rest up and fuel well. Tomorrow's target: $muscle "
            "($days days since last trained).",
      );
    }

    if (streak > 0) {
      return (
        title: "Streak secured",
        body: "${streak}-week streak is intact. Rest well tonight "
            "and let's keep it going tomorrow.",
      );
    }

    final opts = [
      (
        title: "Good session!",
        body: "That's another one in the books. Rest up and hit it again tomorrow."
      ),
      (
        title: "Nice work",
        body: "Recovery starts now — protein, water, sleep. "
            "You earned it today."
      ),
      (
        title: "Session logged",
        body: "Consistent beats intense. See you again tomorrow."
      ),
    ];
    return opts[DateTime.now().day % opts.length];
  }

  // ── Slot C — Evening recovery (8:30 PM, post-workout only) ───────────────

  static Future<void> _scheduleSlotC(WorkoutProvider provider) async {
    final content = _eveningRecoveryContent(provider);
    await _schedule(_idEvening, 20, 30, content.title, content.body);
  }

  static ({String title, String body}) _eveningRecoveryContent(
      WorkoutProvider p) {
    final nudges = p.getMuscleNudges();
    final streak = p.getCurrentStreakWeeks();

    // Tomorrow's target muscle
    if (nudges.isNotEmpty) {
      final muscle = _capFirst(nudges.first.muscleGroup);
      return (
        title: "Recovery mode",
        body: "Sleep is gains. Eat your protein tonight. "
            "Tomorrow: $muscle is waiting — it's been ${nudges.first.daysSince} days.",
      );
    }

    final opts = [
      (
        title: "Recovery time",
        body: "Good session. 7–8 hours of sleep will do more for your gains "
            "than any supplement."
      ),
      (
        title: "Fuel up",
        body: "Protein before bed. Your muscles are rebuilding right now. "
            "Don't skip the recovery.",
      ),
      if (streak > 0)
        (
          title: "Streak intact",
          body: "$streak week${streak > 1 ? 's' : ''} down. "
              "Rest well — the streak continues tomorrow.",
        ),
    ];
    return opts[DateTime.now().day % opts.length];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _sessionsNeededThisWeek(WorkoutProvider provider) {
    final weekStartDay = provider.weekStartDay;
    final now = DateTime.now();
    final daysFromStart = (now.weekday - weekStartDay + 7) % 7;
    final weekStart = DateTime(now.year, now.month, now.day - daysFromStart);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final done = provider.history
        .where((s) =>
            !s.startTime.isBefore(weekStart) && s.startTime.isBefore(weekEnd))
        .length;
    final needed = provider.weeklyTargetDays - done;
    return needed < 0 ? 0 : needed;
  }

  static int _daysLeftInWeek(int weekStartDay) {
    final daysFromStart = (DateTime.now().weekday - weekStartDay + 7) % 7;
    return 6 - daysFromStart;
  }

  static String _weekdayName(int weekday) {
    const names = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return names[weekday];
  }

  static String _capFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Scheduling ────────────────────────────────────────────────────────────

  static Future<void> _schedule(
      int id, int hour, int minute, String title, String body) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Training Reminders',
          channelDescription: 'Smart daily training nudges from Gains',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
