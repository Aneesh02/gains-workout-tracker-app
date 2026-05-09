class SessionSyncRecord {
  final String sessionId;
  final String filePath;    // relative path in repo, e.g. "workouts/2026-04-27-evening-workout.md"
  final String githubSha;  // current SHA on GitHub — required for updates
  final String sessionHash; // SHA256 of session JSON — used to detect edits
  final DateTime syncedAt;

  SessionSyncRecord({
    required this.sessionId,
    required this.filePath,
    required this.githubSha,
    required this.sessionHash,
    required this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'filePath': filePath,
        'githubSha': githubSha,
        'sessionHash': sessionHash,
        'syncedAt': syncedAt.toIso8601String(),
      };

  factory SessionSyncRecord.fromJson(Map<String, dynamic> j) => SessionSyncRecord(
        sessionId: j['sessionId'] as String,
        filePath: j['filePath'] as String,
        githubSha: j['githubSha'] as String,
        sessionHash: j['sessionHash'] as String,
        syncedAt: DateTime.parse(j['syncedAt'] as String),
      );
}
