enum ExerciseType { weight, cardio }

enum PlateLoadingType {
  none,          // dumbbells, cables, bodyweight, stack machines
  barbellBoth,   // bar + plates × 2 (standard barbell)
  barbellSingle, // bar + plates × 1 (T-bar row — one end loaded)
  machineBoth,   // plates × 2, no bar (leg press, hack squat)
  machineSingle, // plates × 1, no bar (single-side plate machine)
}

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final ExerciseType type;
  final List<String> tags;
  final PlateLoadingType plateLoadingType;
  final bool isCustom;
  int timesPerformed;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.type = ExerciseType.weight,
    this.tags = const [],
    this.plateLoadingType = PlateLoadingType.none,
    this.isCustom = false,
    this.timesPerformed = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'type': type.name,
    'tags': tags,
    'plateLoadingType': plateLoadingType.name,
    'isCustom': isCustom,
    'timesPerformed': timesPerformed,
  };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    muscleGroup: j['muscleGroup'] as String,
    type: ExerciseType.values.firstWhere(
      (e) => e.name == j['type'],
      orElse: () => ExerciseType.weight,
    ),
    tags: (j['tags'] as List?)?.cast<String>() ?? [],
    plateLoadingType: PlateLoadingType.values.firstWhere(
      (e) => e.name == j['plateLoadingType'],
      orElse: () => PlateLoadingType.none,
    ),
    isCustom: j['isCustom'] as bool? ?? false,
    timesPerformed: j['timesPerformed'] as int? ?? 0,
  );

  Exercise copyWith({
    String? name,
    String? muscleGroup,
    ExerciseType? type,
    List<String>? tags,
    PlateLoadingType? plateLoadingType,
  }) => Exercise(
    id: id,
    name: name ?? this.name,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    type: type ?? this.type,
    tags: tags ?? this.tags,
    plateLoadingType: plateLoadingType ?? this.plateLoadingType,
    isCustom: isCustom,
    timesPerformed: timesPerformed,
  );
}
