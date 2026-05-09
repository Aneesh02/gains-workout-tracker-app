import 'set_entry.dart';
import 'exercise.dart';

class WorkoutExercise {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final ExerciseType exerciseType;
  PlateLoadingType plateLoadingType;
  List<SetEntry> sets;
  int restSeconds;
  String notes;

  WorkoutExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    this.exerciseType = ExerciseType.weight,
    this.plateLoadingType = PlateLoadingType.none,
    List<SetEntry>? sets,
    int? restSeconds,
    this.notes = '',
  })  : restSeconds =
            restSeconds ?? (exerciseType == ExerciseType.cardio ? 120 : 90),
        sets = sets ?? [SetEntry(setNumber: 1)];

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'exerciseType': exerciseType.index,
        'plateLoadingType': plateLoadingType.index,
        'sets': sets.map((s) => s.toJson()).toList(),
        'restSeconds': restSeconds,
        'notes': notes,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> j) => WorkoutExercise(
        exerciseId: j['exerciseId'] as String,
        exerciseName: j['exerciseName'] as String,
        muscleGroup: j['muscleGroup'] as String,
        exerciseType: ExerciseType.values[j['exerciseType'] as int? ?? 0],
        plateLoadingType: PlateLoadingType.values[j['plateLoadingType'] as int? ?? 0],
        sets: (j['sets'] as List).map((s) => SetEntry.fromJson(s as Map<String, dynamic>)).toList(),
        restSeconds: j['restSeconds'] as int?,
        notes: j['notes'] as String? ?? '',
      );

  String get restLabel {
    final m = restSeconds ~/ 60;
    final s = restSeconds % 60;
    if (m > 0 && s > 0) return '$m:${s.toString().padLeft(2, '0')}';
    if (m > 0) return '$m:00';
    return '0:${s.toString().padLeft(2, '0')}';
  }
}
