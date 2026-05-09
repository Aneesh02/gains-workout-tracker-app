import 'workout_exercise.dart';

class WorkoutSession {
  final String id;
  String name;
  String notes;
  final DateTime startTime;
  DateTime? endTime;
  List<WorkoutExercise> exercises;
  List<String> personalRecords;

  WorkoutSession({
    required this.id,
    required this.name,
    this.notes = '',
    required this.startTime,
    this.endTime,
    List<WorkoutExercise>? exercises,
    List<String>? personalRecords,
  })  : exercises = exercises ?? [],
        personalRecords = personalRecords ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'personalRecords': personalRecords,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as String,
        name: j['name'] as String,
        notes: j['notes'] as String? ?? '',
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: j['endTime'] != null ? DateTime.parse(j['endTime'] as String) : null,
        exercises: (j['exercises'] as List)
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        personalRecords: List<String>.from(j['personalRecords'] as List? ?? []),
      );

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get formattedDuration {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get elapsedLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int get totalVolume {
    int volume = 0;
    for (final ex in exercises) {
      for (final set in ex.sets) {
        if (set.completed && set.weight != null && set.reps != null) {
          volume += (set.weight! * set.reps!).round();
        }
      }
    }
    return volume;
  }

  int get completedSets {
    return exercises.fold(
        0, (sum, ex) => sum + ex.sets.where((s) => s.completed).length);
  }
}
