class PrRecord {
  final double e1rm;
  final double weight;
  final int reps;
  final DateTime date;
  final double? km; // non-null for cardio PRs (best distance)

  bool get isCardio => km != null;

  const PrRecord({
    required this.e1rm,
    required this.weight,
    required this.reps,
    required this.date,
    this.km,
  });

  Map<String, dynamic> toJson() => {
        'e1rm': e1rm,
        'weight': weight,
        'reps': reps,
        'date': date.toIso8601String(),
        if (km != null) 'km': km,
      };

  factory PrRecord.fromJson(Map<String, dynamic> j) => PrRecord(
        e1rm: (j['e1rm'] as num).toDouble(),
        weight: (j['weight'] as num).toDouble(),
        reps: (j['reps'] as num).toInt(),
        date: DateTime.parse(j['date'] as String),
        km: (j['km'] as num?)?.toDouble(),
      );
}
