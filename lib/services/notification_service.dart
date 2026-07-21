import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/services.dart';
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

// Called when notification action fires while the app is backgrounded/killed.
// Runs in a SEPARATE isolate — can't call main-isolate callbacks directly.
// Sends the action ID through an IsolateNameServer port to the main isolate.
@pragma('vm:entry-point')
void _bgNotifResponse(NotificationResponse response) {
  final port = IsolateNameServer.lookupPortByName('gains_notif_port');
  if (port != null && response.actionId != null) {
    port.send(response.actionId!);
  }
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'gains_reminders';

  static const _idMorning = 0;
  static const _idPrimary = 1;
  static const _idEvening = 2;
  static const _idWorkout = 3;
  static const _workoutChannelId = 'gains_workout';
  static const _actionCompleteSet = 'complete_set';
  static const _actionEndRest = 'end_rest';
  static const _portName = 'gains_notif_port';
  static ReceivePort? _port;

  // Registered by ActiveWorkoutScreen.
  static VoidCallback? onCompleteSet;
  static VoidCallback? onEndRest;

  // Called when action fires while app is in foreground.
  static void _onNotifResponse(NotificationResponse response) {
    if (response.actionId == _actionCompleteSet) {
      onCompleteSet?.call();
    } else if (response.actionId == _actionEndRest) {
      onEndRest?.call();
    }
  }

  // Opens a ReceivePort on the main isolate so _bgNotifResponse (background
  // isolate) can forward action IDs back here to invoke the callbacks.
  static void _setupPort() {
    _port?.close();
    IsolateNameServer.removePortNameMapping(_portName);
    _port = ReceivePort();
    IsolateNameServer.registerPortWithName(_port!.sendPort, _portName);
    _port!.listen((message) {
      if (message == _actionCompleteSet) onCompleteSet?.call();
      if (message == _actionEndRest) onEndRest?.call();
    });
  }

  static Future<void> init() async {
    _setupPort();
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotifResponse,
      onDidReceiveBackgroundNotificationResponse: _bgNotifResponse,
    );
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
    String? setDetail,
  }) async {
    final body = setDetail != null
        ? '$setsCompleted / $totalSets sets · $setDetail'
        : '$setsCompleted / $totalSets sets completed';
    await _plugin.show(
      _idWorkout,
      exerciseName,
      body,
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
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  static Future<void> updateWorkoutResting({
    required int remainingSeconds,
    String exerciseName = '',
  }) async {
    final endTime = DateTime.now()
        .add(Duration(seconds: remainingSeconds))
        .millisecondsSinceEpoch;
    final title = exerciseName.isNotEmpty ? 'Resting · $exerciseName' : 'Resting';
    await _plugin.show(
      _idWorkout,
      title,
      'Rest timer running',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          'Active Workout',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          usesChronometer: true,
          chronometerCountDown: true,
          when: endTime,
          showWhen: true,
          visibility: NotificationVisibility.public,
          actions: const [
            AndroidNotificationAction(
              _actionEndRest,
              'End Rest',
              showsUserInterface: false,
              cancelNotification: false,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> updateWorkoutRestDone({
    required String exerciseName,
    required int setsCompleted,
    required int totalSets,
    String? nextSetDetail,
  }) async {
    final restEndedAt = DateTime.now().millisecondsSinceEpoch;
    final body = nextSetDetail ?? 'Set ${setsCompleted + 1} / $totalSets';
    await _plugin.show(
      _idWorkout,
      exerciseName,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          'Active Workout',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
          usesChronometer: true,
          chronometerCountDown: false,
          when: restEndedAt,
          showWhen: true,
          actions: const [
            AndroidNotificationAction(
              _actionCompleteSet,
              'Complete Set',
              showsUserInterface: false,
              cancelNotification: false,
            ),
          ],
        ),
      ),
    );
  }

  // Shows the upcoming set with a "Complete Set" action — no chronometer.
  // Used when rest ends early (End Rest tapped), rest = 0, or workout first opens.
  static Future<void> showNextSetDue({
    required String exerciseName,
    required int setsCompleted,
    required int totalSets,
    String? nextSetDetail,
  }) async {
    final body = nextSetDetail ?? 'Set ${setsCompleted + 1} / $totalSets';
    await _plugin.show(
      _idWorkout,
      exerciseName,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          'Active Workout',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
          showWhen: false,
          actions: const [
            AndroidNotificationAction(
              _actionCompleteSet,
              'Complete Set',
              showsUserInterface: false,
              cancelNotification: false,
            ),
          ],
        ),
      ),
    );
  }

  // ── Background rest alarm (fires even if app is backgrounded/killed) ────────

  static Future<void> scheduleRestDone(int remainingSeconds) async {
    try {
      const ch = MethodChannel('com.gains.app/battery');
      final epochMs = DateTime.now()
          .add(Duration(seconds: remainingSeconds))
          .millisecondsSinceEpoch;
      await ch.invokeMethod('scheduleRestDone', {'epochMs': epochMs});
    } catch (_) {}
  }

  static Future<void> cancelRestDone() async {
    try {
      const ch = MethodChannel('com.gains.app/battery');
      await ch.invokeMethod('cancelRestDone');
    } catch (_) {}
  }

  static Future<void> cancelWorkoutNotification() async {
    await _plugin.cancel(_idWorkout);
  }

  // Plays the rest bell via native MediaPlayer with audio-focus ducking.
  // Works whether the app is foregrounded, backgrounded, or killed.
  static Future<void> playBell() async {
    try {
      const ch = MethodChannel('com.gains.app/battery');
      await ch.invokeMethod('playBell');
    } catch (_) {}
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    if (granted) await android?.requestExactAlarmsPermission();
    // Ask to be excluded from battery optimization so scheduled alarms fire
    // reliably on Samsung and other aggressive OEMs.
    try {
      const channel = MethodChannel('com.gains.app/battery');
      await channel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (_) {}
    return granted;
  }

  /// Call on app open AND immediately after a workout is finished.
  /// Returns null on full success, or an error string if any slot failed.
  static Future<String?> reschedule(
      WorkoutProvider provider, GymSettings settings) async {
    // Cancel only reminder slots — never touch the active workout notification
    await cancelReminders();
    if (!settings.remindersEnabled) return null;

    final trained = provider.workedOutToday(settings.dayStartHour);

    final errors = <String>[];
    final eA = await _scheduleSlotA(provider, settings);
    if (eA != null) errors.add('Morning: $eA');
    final eB = await _scheduleSlotB(provider, settings, trained: trained);
    if (eB != null) errors.add('Midday: $eB');
    final eC = await _scheduleSlotC(provider, settings, trained: trained);
    if (eC != null) errors.add('Evening: $eC');
    return errors.isEmpty ? null : errors.join('; ');
  }

  static Future<void> cancelReminders() async {
    const ch = MethodChannel('com.gains.app/battery');
    for (final id in [_idMorning, _idPrimary, _idEvening]) {
      try { await ch.invokeMethod('cancelReminder', {'id': id}); } catch (_) {}
    }
  }

  // ── Slot A — Morning pre-workout (9 AM) ──────────────────────────────────

  static Future<String?> _scheduleSlotA(
      WorkoutProvider provider, GymSettings settings) async {
    final content = _morningContent(provider);
    return _schedule(_idMorning, settings.morningHour, settings.morningMinute,
        content.title, content.body);
  }

  static bool _hitWeeklyTarget(WorkoutProvider p) =>
      _sessionsNeededThisWeek(p) <= 0;

  static ({String title, String body}) _morningContent(WorkoutProvider p) {
    final now = DateTime.now();
    final nudges = p.getMuscleNudges();
    final streak = p.getCurrentStreakWeeks();
    final needed = _sessionsNeededThisWeek(p);
    final daysLeft = _daysLeftInWeek(p.weekStartDay);

    // Weekly target already hit — show motivational recap
    if (_hitWeeklyTarget(p)) {
      final sessionCount = p.weeklyTargetDays + (0 - needed).abs();
      final nextMuscle = nudges.isNotEmpty ? _capFirst(nudges.first.muscleGroup) : null;
      if (nextMuscle != null) {
        return (
          title: "Weekly target done 🎯",
          body: "$sessionCount sessions in the bag this week. "
              "Extra session today? $nextMuscle is overdue.",
        );
      }
      return (
        title: "Weekly target done 🎯",
        body: "You hit your goal for the week. "
            "Rest, recover, or train for fun — you've earned it.",
      );
    }

    // Streak at risk — surface first, high urgency
    if (streak > 0 && needed > 0 && daysLeft <= 2) {
      final plural = needed == 1 ? 'session' : 'sessions';
      return (
        title: "Streak at risk 🔥",
        body: "$streak-week streak needs $needed more $plural in $daysLeft day${daysLeft == 1 ? '' : 's'}. "
            "Don't let it slip now.",
      );
    }

    // Muscle-specific nudge
    if (nudges.isNotEmpty) {
      final muscle = _capFirst(nudges.first.muscleGroup);
      final days = nudges.first.daysSince;
      return (
        title: "$muscle day?",
        body: "It's been $days days since you trained $muscle. "
            "Today's a great time to get it in.",
      );
    }

    // Streak motivation — best day of week
    final patterns = p.getTrainingPatterns();
    final todayName = _weekdayName(now.weekday);
    if (patterns.topDay != null && patterns.topDay == todayName) {
      return (
        title: "Your best training day",
        body: "Your data says $todayName is your strongest day. "
            "Don't let it go to waste.",
      );
    }

    // Active streak — keep momentum
    if (streak > 0) {
      return (
        title: "$streak week${streak > 1 ? 's' : ''} strong",
        body: "Your streak is alive. Plan today's session now before the day gets busy.",
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
    return defaults[now.day % defaults.length];
  }

  // ── Slot B — Primary time (user-configured) ───────────────────────────────

  static Future<String?> _scheduleSlotB(
      WorkoutProvider provider, GymSettings settings,
      {required bool trained}) async {
    final content = _middayProteinContent(provider, trained: trained);
    return _schedule(_idPrimary, settings.reminderHour, settings.reminderMinute,
        content.title, content.body);
  }

  static ({String title, String body}) _middayProteinContent(
      WorkoutProvider p, {required bool trained}) {
    final now = DateTime.now();

    // Weekly target already hit — recap + next-week nudge
    if (_hitWeeklyTarget(p)) {
      final streak = p.getCurrentStreakWeeks();
      final opts = [
        (
          title: "Week target nailed 🔥",
          body: "You hit your sessions goal for the week. "
              "${streak > 0 ? '$streak-week streak intact. ' : ''}"
              "Keep the protein up — your muscles are rebuilding right now.",
        ),
        (
          title: "Consistency is the cheat code",
          body: "Another week target done. "
              "Start thinking about next week's sessions now — "
              "plan tonight, execute tomorrow.",
        ),
        (
          title: "Goal done. Recovery mode.",
          body: "Weekly target hit. Protein, water, and sleep are your job now. "
              "Don't skip the recovery just because the workout is done.",
        ),
      ];
      return opts[now.day % opts.length];
    }

    // Trained today — recovery protein nudge
    if (trained) {
      final opts = [
        (
          title: "Post-workout protein?",
          body: "You trained today — did you get your protein in? "
              "Muscle repair starts now. Hit that target.",
        ),
        (
          title: "Fuel the recovery",
          body: "Great session today. Have you had your protein yet? "
              "Aim for 30–40g this meal to kickstart recovery.",
        ),
        (
          title: "Protein check ✓",
          body: "You put in the work — now feed the muscle. "
              "Chicken, eggs, paneer, whey — whatever it takes.",
        ),
        (
          title: "Recovery window open",
          body: "Did you eat protein after your session? "
              "Don't let a good workout go to waste.",
        ),
      ];
      return opts[now.day % opts.length];
    }

    // Rest day — general protein nudge
    final opts = [
      (
        title: "Protein check — did you?",
        body: "Have you hit your protein today? "
            "Even on rest days, muscles need fuel to rebuild.",
      ),
      (
        title: "Mid-day fuel",
        body: "Quick check — how's your protein intake looking today? "
            "Aim for at least 0.8–1g per kg of bodyweight.",
      ),
      (
        title: "Had protein today?",
        body: "Lunch time. Make sure there's a solid protein source on your plate — "
            "eggs, chicken, dal, paneer, or a shake.",
      ),
      (
        title: "Don't skip the protein",
        body: "Rest day or not, your muscles are still recovering. "
            "Keep the protein consistent.",
      ),
      (
        title: "Protein > everything",
        body: "Calories can wait — protein cannot. "
            "Did you get a solid source in this meal?",
      ),
    ];
    return opts[now.day % opts.length];
  }

  // ignore: unused_element
  static ({String title, String body}) _postWorkoutPrimaryContent(
      WorkoutProvider p) {
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

  static Future<String?> _scheduleSlotC(
      WorkoutProvider provider, GymSettings settings,
      {required bool trained}) async {
    final content = _eveningContent(provider, trained: trained);
    return _schedule(_idEvening, settings.eveningHour, settings.eveningMinute,
        content.title, content.body);
  }

  static ({String title, String body}) _eveningContent(
      WorkoutProvider p, {required bool trained}) {
    final now = DateTime.now();
    final nudges = p.getMuscleNudges();
    final streak = p.getCurrentStreakWeeks();
    final nextMuscle = nudges.isNotEmpty ? _capFirst(nudges.first.muscleGroup) : null;
    final daysSince = nudges.isNotEmpty ? nudges.first.daysSince : 0;

    // Weekly target hit — recap + next-week planning
    if (_hitWeeklyTarget(p)) {
      if (nextMuscle != null) {
        return (
          title: "Week done. Plan next week.",
          body: "${streak > 0 ? '$streak-week streak secured. ' : ''}"
              "Sleep well tonight — sleep is when the gains happen. "
              "Tomorrow: consider $nextMuscle ($daysSince days overdue).",
        );
      }
      return (
        title: "Week complete. Recover right.",
        body: "${streak > 0 ? '$streak-week streak locked in. ' : ''}"
            "Protein, water, 7–8 hrs sleep. "
            "Take 5 min now to plan next week so you start strong.",
      );
    }

    if (trained) {
      // Trained today — celebrate streak + sleep/recovery + tomorrow's target
      if (streak > 0 && nextMuscle != null) {
        return (
          title: "$streak week${streak > 1 ? 's' : ''} and counting 💪",
          body: "Great session. Let your muscles recover tonight — "
              "7–8 hrs of sleep does more than any supplement. "
              "Tomorrow: $nextMuscle ($daysSince days).",
        );
      }
      if (streak > 0) {
        return (
          title: "Streak secured",
          body: "$streak week${streak > 1 ? 's' : ''} strong. "
              "Sleep is when the gains happen — don't cut it short tonight.",
        );
      }
      if (nextMuscle != null) {
        return (
          title: "Recovery time",
          body: "Good work today. Relax the muscles you trained, "
              "eat your protein, and sleep well. Tomorrow: $nextMuscle.",
        );
      }
      final opts = [
        (
          title: "Sleep = gains",
          body: "Your muscles grow while you sleep, not while you lift. "
              "Get 7–8 hours tonight and let the work pay off."
        ),
        (
          title: "Recovery mode on",
          body: "Protein ✓ Water ✓ Now sleep. "
              "Deep sleep is when growth hormone peaks — protect it."
        ),
        (
          title: "Wind down right",
          body: "Great session today. Dim the lights, put the phone down, "
              "and let your body do the repair work it needs tonight."
        ),
      ];
      return opts[now.day % opts.length];
    } else {
      // Rest day — streak danger check, tomorrow's plan, sleep nudge
      final needed = _sessionsNeededThisWeek(p);
      final daysLeft = _daysLeftInWeek(p.weekStartDay);
      if (streak > 0 && needed > 0 && daysLeft <= 1) {
        final plural = needed == 1 ? 'session' : 'sessions';
        return (
          title: "Last chance for the streak",
          body: "Need $needed more $plural to keep your $streak-week streak. "
              "Tomorrow is your window — make it count.",
        );
      }
      if (nextMuscle != null) {
        return (
          title: "Tomorrow's target: $nextMuscle",
          body: "$nextMuscle hasn't been trained in $daysSince days. "
              "Plan it now, sleep well, and show up ready.",
        );
      }
      final opts = [
        (
          title: "Rest well tonight",
          body: "Sleep is training. 7–8 hours of quality sleep improves "
              "strength, recovery, and focus. Make it a priority."
        ),
        (
          title: "Plan tomorrow",
          body: "Take 2 minutes now to decide what you're training tomorrow. "
              "People who plan train 40% more consistently."
        ),
        (
          title: "Good sleep = better lifts",
          body: "Poor sleep tanks testosterone and recovery. "
              "Tonight matters. Wind down and get your 7–8 hours."
        ),
      ];
      return opts[now.day % opts.length];
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

  /// Immediately shows a test notification to verify the pipeline works.
  static Future<String?> sendTestNow() async {
    try {
      await _plugin.show(
        99,
        'GAINS reminder test',
        'Notifications are working!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, 'Training Reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static int _nextEpochMs(int hour, int minute) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t.millisecondsSinceEpoch;
  }

  static Future<String?> _schedule(
      int id, int hour, int minute, String title, String body) async {
    try {
      const ch = MethodChannel('com.gains.app/battery');
      await ch.invokeMethod('scheduleReminder', {
        'id': id,
        'epochMs': _nextEpochMs(hour, minute),
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
