enum InsightDirection { up, down, same, first }

class ExerciseInsight {
  final String exerciseName;
  final String? thisSession;
  final String? lastSession;
  final InsightDirection direction;

  const ExerciseInsight({
    required this.exerciseName,
    this.thisSession,
    this.lastSession,
    required this.direction,
  });
}

class PostWorkoutInsights {
  final double thisVolume;
  final double? avgVolume;
  final double? volumeChangePercent;
  final Duration thisDuration;
  final Duration? avgDuration;
  final int thisCompletedSets;
  final double setCompletionRate;
  final List<ExerciseInsight> exerciseInsights;

  const PostWorkoutInsights({
    required this.thisVolume,
    this.avgVolume,
    this.volumeChangePercent,
    required this.thisDuration,
    this.avgDuration,
    required this.thisCompletedSets,
    required this.setCompletionRate,
    required this.exerciseInsights,
  });
}
