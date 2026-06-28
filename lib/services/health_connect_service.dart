import 'package:health/health.dart';
import '../models/workout_session.dart';

class HealthConnectService {
  static final _health = Health();

  static const _writeTypes = [
    HealthDataType.WORKOUT,
  ];

  static const _writePermissions = [
    HealthDataAccess.WRITE,
  ];

  static Future<void> configure() async {
    await _health.configure();
  }

  /// Returns true if WRITE_EXERCISE is already granted.
  static Future<bool> hasPermission() async {
    try {
      final result = await _health.hasPermissions(
        _writeTypes,
        permissions: _writePermissions,
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Health Connect permission dialog. Returns true if granted.
  static Future<bool> requestPermission() async {
    try {
      return await _health.requestAuthorization(
        _writeTypes,
        permissions: _writePermissions,
      );
    } catch (_) {
      return false;
    }
  }

  /// Writes a completed session to Health Connect.
  /// Returns null on success, error message on failure.
  static Future<String?> writeSession(WorkoutSession session) async {
    final end = session.endTime;
    if (end == null) return 'Session has no end time';

    try {
      final activityType = _activityType(session);
      final ok = await _health.writeWorkoutData(
        activityType: activityType,
        start: session.startTime,
        end: end,
        title: session.name,
      );
      return ok ? null : 'Health Connect write returned false';
    } catch (e) {
      return e.toString();
    }
  }

  static HealthWorkoutActivityType _activityType(WorkoutSession session) {
    final muscles = session.exercises
        .map((e) => e.muscleGroup.toLowerCase())
        .toSet();

    if (muscles.contains('cardio')) {
      final hasWeights = session.exercises.any(
        (e) => e.muscleGroup.toLowerCase() != 'cardio',
      );
      if (!hasWeights) return HealthWorkoutActivityType.RUNNING;
    }

    return HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING;
  }
}
