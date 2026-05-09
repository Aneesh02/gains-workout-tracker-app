import 'exercise.dart';

class TemplateExercise {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final ExerciseType exerciseType;
  final int setCount;
  final int restSeconds;

  TemplateExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    this.exerciseType = ExerciseType.weight,
    this.setCount = 3,
    this.restSeconds = 90,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'exerciseType': exerciseType.index,
        'setCount': setCount,
        'restSeconds': restSeconds,
      };

  factory TemplateExercise.fromJson(Map<String, dynamic> j) => TemplateExercise(
        exerciseId: j['exerciseId'] as String,
        exerciseName: j['exerciseName'] as String,
        muscleGroup: j['muscleGroup'] as String,
        exerciseType: ExerciseType.values[j['exerciseType'] as int? ?? 0],
        setCount: j['setCount'] as int? ?? 3,
        restSeconds: j['restSeconds'] as int? ?? 90,
      );
}

class WorkoutTemplate {
  final String id;
  String name;
  final DateTime createdAt;
  List<TemplateExercise> exercises;

  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        exercises: (j['exercises'] as List)
            .map((e) => TemplateExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get exerciseSummary {
    if (exercises.isEmpty) return 'No exercises';
    final names = exercises.take(3).map((e) => e.exerciseName).join(', ');
    return exercises.length > 3 ? '$names...' : names;
  }
}
