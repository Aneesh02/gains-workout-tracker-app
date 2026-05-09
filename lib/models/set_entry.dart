enum SetType { normal, warmUp, dropSet, failure }

class SetEntry {
  static int _nextId = 0;

  final int id;
  SetType setType;
  int setNumber;
  String weightInput;
  String repsInput;
  double? rpe;
  bool completed;
  double? previousWeight;
  int? previousReps;
  double? previousRpe;
  String kmInput;
  String timeInput;
  double? previousKm;
  String? previousTime;

  SetEntry({
    required this.setNumber,
    this.setType = SetType.normal,
    this.weightInput = '',
    this.repsInput = '',
    this.rpe,
    this.completed = false,
    this.previousWeight,
    this.previousReps,
    this.previousRpe,
    this.kmInput = '',
    this.timeInput = '',
    this.previousKm,
    this.previousTime,
  }) : id = _nextId++;

  double? get weight =>
      weightInput.isEmpty ? null : double.tryParse(weightInput);

  int? get reps => repsInput.isEmpty ? null : int.tryParse(repsInput);

  String get previousLabel {
    if (previousWeight != null && previousReps != null) {
      final w = previousWeight! % 1 == 0
          ? previousWeight!.toInt().toString()
          : previousWeight!.toString();
      final label = '$w kg × $previousReps';
      if (previousRpe != null) return '$label @ $previousRpe';
      return label;
    }
    return '—';
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'setType': setType.index,
        'weightInput': weightInput,
        'repsInput': repsInput,
        'rpe': rpe,
        'completed': completed,
        'kmInput': kmInput,
        'timeInput': timeInput,
      };

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        setNumber: j['setNumber'] as int,
        setType: SetType.values[j['setType'] as int? ?? 0],
        weightInput: j['weightInput'] as String? ?? '',
        repsInput: j['repsInput'] as String? ?? '',
        rpe: (j['rpe'] as num?)?.toDouble(),
        completed: j['completed'] as bool? ?? false,
        kmInput: j['kmInput'] as String? ?? '',
        timeInput: j['timeInput'] as String? ?? '',
      );

  String get previousCardioLabel {
    if (previousKm == null && previousTime == null) return '—';
    final parts = <String>[];
    if (previousKm != null) {
      final km = previousKm! % 1 == 0
          ? previousKm!.toInt().toString()
          : previousKm!.toString();
      parts.add('$km km');
    }
    if (previousTime != null && previousTime!.isNotEmpty) {
      final secs = int.tryParse(previousTime!) ?? 0;
      final m = secs ~/ 60;
      final s = secs % 60;
      parts.add('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }
}
