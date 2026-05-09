class GymBar {
  String name;
  double weight; // kg

  GymBar({required this.name, required this.weight});

  Map<String, dynamic> toJson() => {'name': name, 'weight': weight};

  factory GymBar.fromJson(Map<String, dynamic> j) =>
      GymBar(name: j['name'] as String, weight: (j['weight'] as num).toDouble());
}

class GymSettings {
  List<GymBar> bars;
  List<double> plates; // available plate weights (kg)
  String obsidianVaultPath;
  String githubOwner;
  String githubRepo;
  String githubBranch;
  String githubUsername;

  GymSettings({
    required this.bars,
    required this.plates,
    this.obsidianVaultPath = '',
    this.githubOwner = '',
    this.githubRepo = '',
    this.githubBranch = 'main',
    this.githubUsername = '',
  });

  GymSettings copyWith({
    List<GymBar>? bars,
    List<double>? plates,
    String? obsidianVaultPath,
    String? githubOwner,
    String? githubRepo,
    String? githubBranch,
    String? githubUsername,
  }) =>
      GymSettings(
        bars: bars ?? this.bars,
        plates: plates ?? this.plates,
        obsidianVaultPath: obsidianVaultPath ?? this.obsidianVaultPath,
        githubOwner: githubOwner ?? this.githubOwner,
        githubRepo: githubRepo ?? this.githubRepo,
        githubBranch: githubBranch ?? this.githubBranch,
        githubUsername: githubUsername ?? this.githubUsername,
      );

  static GymSettings get defaults => GymSettings(
        bars: [
          GymBar(name: 'Olympic Bar', weight: 20),
          GymBar(name: "Women's Bar", weight: 15),
          GymBar(name: 'EZ Bar', weight: 10),
          GymBar(name: 'Trap Bar', weight: 25),
          GymBar(name: 'Safety Bar', weight: 25),
          GymBar(name: 'Swiss Bar', weight: 15),
        ],
        plates: [25, 20, 15, 10, 5, 2.5, 1.25, 0.5],
      );

  Map<String, dynamic> toJson() => {
        'bars': bars.map((b) => b.toJson()).toList(),
        'plates': plates,
        'obsidianVaultPath': obsidianVaultPath,
        'githubOwner': githubOwner,
        'githubRepo': githubRepo,
        'githubBranch': githubBranch,
        'githubUsername': githubUsername,
      };

  factory GymSettings.fromJson(Map<String, dynamic> j) => GymSettings(
        bars: (j['bars'] as List)
            .map((b) => GymBar.fromJson(b as Map<String, dynamic>))
            .toList(),
        plates: (j['plates'] as List).map((p) => (p as num).toDouble()).toList(),
        obsidianVaultPath: j['obsidianVaultPath'] as String? ?? '',
        githubOwner: j['githubOwner'] as String? ?? '',
        githubRepo: j['githubRepo'] as String? ?? '',
        githubBranch: j['githubBranch'] as String? ?? 'main',
        githubUsername: j['githubUsername'] as String? ?? '',
      );
}
