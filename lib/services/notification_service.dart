import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../providers/workout_provider.dart';
import '../models/gym_settings.dart';

/// Three daily notification slots — all fire every day, all context-aware.
///
/// Slot A (ID 0): Morning (default 9:00 AM) — what to train today.
/// Slot B (ID 1): Midday (user-configured) — pre-workout nudge OR post-workout celebration.
/// Slot C (ID 2): Evening (default 9:00 PM) — tomorrow's plan OR recovery if trained today.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'gains_reminders';

  static const _idMorning = 0;
  static const _idPrimary = 1;
  static const _idEvening = 2;
  static const _idWorkout = 3;
  static const _workoutChannelId = 'gains_workout';

  static Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Training Reminders',
      description: 'Smart daily training nudges from Gains',
      importance: Importance.defaultImportance,
    ));
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _workoutChannelId,
      'Active Workout',
      description: 'Shown while a workout is in progress',
      importance: Importance.low,
    ));
  }

  // ── Active workout notification ───────────────────────────────────────────

  static Future<void> showWorkoutNotification({
    required String exerciseName,
    required int setsCompleted,
    required int totalSets,
  }) async {
    await _plugin.show(
      _idWorkout,
      exerciseName,
      '$setsCompleted / $totalSets sets completed',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          'Active Workout',
          channelDescription: 'Shown while a workout is in progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          usesChronometer: false,
        ),
      ),
    );
  }

  static Future<void> updateWorkoutResting({
    required int remainingSeconds,
  }) async {
    final endTime = DateTime.now()
        .add(Duration(seconds: remainingSeconds))
        .millisecondsSinceEpoch;
    await _plugin.show(
      _idWorkout,
      'Resting',
      remainingSeconds > 0 ? 'Rest timer running' : 'Rest done — start your set',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          'Active Workout',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          usesChronometer: remainingSeconds > 0,
          chronometerCountDown: true,
          when: remainingSeconds > 0 ? endTime : null,
          showWhen: remainingSeconds > 0,
        ),
      ),
    );
  }

  static Future<void> updateWorkoutRestDone({
    required String exerciseName,
    required int setsCompleted,
    required int totalSets,
  }) async {
    await _plugin.show(
      _idWorkout,
      'Rest done — start your set',
      '$exerciseName · $setsCompleted / $totalSets sets',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          'Active Workout',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> cancelWorkoutNotification() async {
    await _plugin.cancel(_idWorkout);
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    if (granted) await android?.requestExactAlarmsPermission();
    return granted;
  }

  /// Call on app open AND immediately after a workout is finished.
  static Future<void> reschedule(
      WorkoutProvider provider, GymSettings settings) async {
    // Cancel only reminder slots — never touch the active workout notification
    await _plugin.cancel(_idMorning);
    await _plugin.cancel(_idPrimary);
    await _plugin.cancel(_idEvening);
    if (!settings.remindersEnabled) return;

    final trained = provider.workedOutToday(settings.dayStartHour);

    await _scheduleSlotA(provider, settings);
    await _scheduleSlotB(provider, settings, trained: trained);
    await _scheduleSlotC(provider, settings, trained: trained);
  }

  static Future<void> cancelReminders() async {
    await _plugin.cancel(_idMorning);
    await _plugin.cancel(_idPrimary);
    await _plugin.cancel(_idEvening);
  }

  // ── Slot A — Morning pre-workout (9 AM) ──────────────────────────────────

  static Future<void> _scheduleSlotA(
      WorkoutProvider provider, GymSettings settings) async {
    final content = _morningContent(provider);
    await _schedule(
        _idMorning, settings.morningHour, settings.morningMinute,
        content.title, content.body);
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

  // ── Slot C — Evening plan (user-configured, every day) ───────────────────

  static Future<void> _scheduleSlotC(
      WorkoutProvider provider, GymSettings settings,
      {required bool trained}) async {
    final content = _eveningContent(provider, trained: trained);
    await _schedule(
        _idEvening, settings.eveningHour, settings.eveningMinute,
        content.title, content.body);
  }

  static ({String title, String body}) _eveningContent(
      WorkoutProvider p, {required bool trained}) {
    final nudges = p.getMuscleNudges();
    final streak = p.getCurrentStreakWeeks();
    final nextMuscle = nudges.isNotEmpty ? _capFirst(nudges.first.muscleGroup) : null;
    final daysSince = nudges.isNotEmpty ? nudges.first.daysSince : 0;

    if (trained) {
      // Trained today — recovery + tomorrow's plan
      if (nextMuscle != null) {
        return (
          title: "Good session today",
          body: "Rest up and fuel well. Tomorrow: $nextMuscle "
              "hasn't been trained in $daysSince days — make it the focus.",
        );
      }
      if (streak > 0) {
        return (
          title: "Streak intact",
          body: "$streak week${streak > 1 ? 's' : ''} strong. "
              "Sleep well — let's keep it going tomorrow.",
        );
      }
      final opts = [
        (title: "Recovery mode", body: "Protein, water, sleep. Your muscles are rebuilding right now."),
        (title: "Good session", body: "7–8 hours tonight will do more for your gains than any supplement."),
        (title: "Session done", body: "Consistent beats intense. Rest up and hit it again tomorrow."),
      ];
      return opts[DateTime.now().day % opts.length];
    } else {
      // Rest day — tomorrow's plan
      if (nextMuscle != null) {
        return (
          title: "Tomorrow's plan",
          body: "$nextMuscle hasn't been trained in $daysSince days. "
              "Make it tomorrow's focus.",
        );
      }
      if (streak > 0) {
        final needed = _sessionsNeededThisWeek(p);
        if (needed > 0) {
          final plural = needed == 1 ? 'session' : 'sessions';
          return (
            title: "Plan tomorrow",
            body: "$needed more $plural needed to keep your $streak-week streak. "
                "Schedule it tonight.",
          );
        }
      }
      final opts = [
        (title: "Plan tomorrow", body: "Take 2 minutes tonight to decide what you're training tomorrow. It makes a difference."),
        (title: "Tomorrow's session", body: "What muscle group needs work? Plan it now so you show up ready."),
        (title: "Rest day check-in", body: "Feeling recovered? Lock in tomorrow's workout before you sleep."),
      ];
      return opts[DateTime.now().day % opts.length];
    }
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
    // ignore: avoid_print
    print('[NotificationService] scheduling id=$id "$title" at $scheduled (now=$now)');

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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
