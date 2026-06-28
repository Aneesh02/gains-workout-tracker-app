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
  List<double> plates;
  String obsidianVaultPath;
  String githubOwner;
  String githubRepo;
  String githubBranch;
  String githubUsername;

  // Day & Time
  int dayStartHour;
  bool remindersEnabled;
  int morningHour;
  int morningMinute;
  int reminderHour;
  int reminderMinute;
  int eveningHour;
  int eveningMinute;

  // App behaviour
  bool soundsEnabled;
  bool keepScreenOn;

  GymSettings({
    required this.bars,
    required this.plates,
    this.obsidianVaultPath = '',
    this.githubOwner = '',
    this.githubRepo = '',
    this.githubBranch = 'main',
    this.githubUsername = '',
    this.dayStartHour = 4,
    this.remindersEnabled = false,
    this.morningHour = 9,
    this.morningMinute = 0,
    this.reminderHour = 18,
    this.reminderMinute = 0,
    this.eveningHour = 21,
    this.eveningMinute = 0,
    this.soundsEnabled = true,
    this.keepScreenOn = true,
  });

  GymSettings copyWith({
    List<GymBar>? bars,
    List<double>? plates,
    String? obsidianVaultPath,
    String? githubOwner,
    String? githubRepo,
    String? githubBranch,
    String? githubUsername,
    int? dayStartHour,
    bool? remindersEnabled,
    int? morningHour,
    int? morningMinute,
    int? reminderHour,
    int? reminderMinute,
    int? eveningHour,
    int? eveningMinute,
    bool? soundsEnabled,
    bool? keepScreenOn,
  }) =>
      GymSettings(
        bars: bars ?? this.bars,
        plates: plates ?? this.plates,
        obsidianVaultPath: obsidianVaultPath ?? this.obsidianVaultPath,
        githubOwner: githubOwner ?? this.githubOwner,
        githubRepo: githubRepo ?? this.githubRepo,
        githubBranch: githubBranch ?? this.githubBranch,
        githubUsername: githubUsername ?? this.githubUsername,
        dayStartHour: dayStartHour ?? this.dayStartHour,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        morningHour: morningHour ?? this.morningHour,
        morningMinute: morningMinute ?? this.morningMinute,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        eveningHour: eveningHour ?? this.eveningHour,
        eveningMinute: eveningMinute ?? this.eveningMinute,
        soundsEnabled: soundsEnabled ?? this.soundsEnabled,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
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
        'dayStartHour': dayStartHour,
        'remindersEnabled': remindersEnabled,
        'morningHour': morningHour,
        'morningMinute': morningMinute,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'eveningHour': eveningHour,
        'eveningMinute': eveningMinute,
        'soundsEnabled': soundsEnabled,
        'keepScreenOn': keepScreenOn,
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
        dayStartHour: j['dayStartHour'] as int? ?? 4,
        remindersEnabled: j['remindersEnabled'] as bool? ?? false,
        morningHour: j['morningHour'] as int? ?? 9,
        morningMinute: j['morningMinute'] as int? ?? 0,
        reminderHour: j['reminderHour'] as int? ?? 18,
        reminderMinute: j['reminderMinute'] as int? ?? 0,
        eveningHour: j['eveningHour'] as int? ?? 21,
        eveningMinute: j['eveningMinute'] as int? ?? 0,
        soundsEnabled: j['soundsEnabled'] as bool? ?? true,
        keepScreenOn: j['keepScreenOn'] as bool? ?? true,
      );
}
