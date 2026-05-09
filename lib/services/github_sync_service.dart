import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/sync_state.dart';
import '../models/workout_session.dart';
import 'workout_markdown_service.dart';

class GitHubSyncService {
  static const _tokenKey = 'github_pat';
  static const _baseUrl = 'https://api.github.com';

  final FlutterSecureStorage _storage;

  GitHubSyncService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<void> savePat(String token) =>
      _storage.write(key: _tokenKey, value: token.trim());

  Future<String?> getPat() => _storage.read(key: _tokenKey);

  Future<void> deletePat() => _storage.delete(key: _tokenKey);

  Future<bool> hasPat() async {
    final t = await getPat();
    return t != null && t.isNotEmpty;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  static const _metricsKey = 'github_metrics_sha';

  Future<void> saveMetricsSha(String sha) =>
      _storage.write(key: _metricsKey, value: sha);

  Future<String?> getMetricsSha() => _storage.read(key: _metricsKey);

  /// Pushes the metrics snapshot note. Always overwrites the file.
  /// Returns null on success, error message on failure.
  Future<String?> pushMetrics({
    required String owner,
    required String repo,
    required String branch,
    required String content,
  }) async {
    try {
      const path = 'metrics-snapshot.md';
      // Always fetch live SHA — cached value can be stale if file changed externally.
      final existingSha = await getFileSha(
          owner: owner, repo: repo, branch: branch, path: path);
      final newSha = await putFile(
        owner: owner,
        repo: repo,
        branch: branch,
        path: path,
        content: content,
        existingSha: existingSha,
        commitMessage: 'metrics: update snapshot',
      );
      await saveMetricsSha(newSha);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> testConnection(String owner, String repo) async {
    final token = await getPat();
    if (token == null || token.isEmpty) return 'No token configured';
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/repos/$owner/$repo'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return null;
      if (res.statusCode == 401) return 'Invalid token';
      if (res.statusCode == 404) return 'Repo not found or no access';
      return 'HTTP ${res.statusCode}';
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns the current SHA of a file, or null if the file does not exist.
  Future<String?> getFileSha({
    required String owner,
    required String repo,
    required String branch,
    required String path,
  }) async {
    final token = await getPat();
    if (token == null || token.isEmpty) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path?ref=$branch'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['sha'] as String?;
      }
      return null; // 404 = file does not exist yet
    } catch (_) {
      return null;
    }
  }

  /// Moves [sourcePath] to archive/[filename] and deletes the original.
  /// Returns null on success, error message on failure.
  Future<String?> archiveWorkout({
    required String owner,
    required String repo,
    required String branch,
    required String sourcePath,
  }) async {
    try {
      final token = await getPat();
      if (token == null || token.isEmpty) throw Exception('No token configured');

      // Fetch current content + SHA
      final getRes = await http
          .get(
            Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$sourcePath?ref=$branch'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (getRes.statusCode == 404) return null; // already gone
      if (getRes.statusCode != 200) {
        throw Exception('GET failed (${getRes.statusCode})');
      }

      final data = jsonDecode(getRes.body) as Map<String, dynamic>;
      final currentSha = data['sha'] as String;
      // GitHub wraps base64 at 60 chars — strip newlines before decoding
      final cleanB64 = (data['content'] as String).replaceAll('\n', '');
      final rawContent = utf8.decode(base64.decode(cleanB64));

      // PUT to archive/filename
      final filename = sourcePath.split('/').last;
      final archivePath = 'archive/$filename';
      final existingArchiveSha = await getFileSha(
          owner: owner, repo: repo, branch: branch, path: archivePath);
      await putFile(
        owner: owner,
        repo: repo,
        branch: branch,
        path: archivePath,
        content: rawContent,
        existingSha: existingArchiveSha,
        commitMessage: 'archive: $filename',
      );

      // DELETE original
      final deleteRes = await http
          .delete(
            Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$sourcePath'),
            headers: {
              ..._headers(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': 'archive: remove $sourcePath',
              'sha': currentSha,
              'branch': branch,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (deleteRes.statusCode != 200) {
        throw Exception('DELETE failed (${deleteRes.statusCode}): ${deleteRes.body}');
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Pushes a workout session to GitHub as a markdown note.
  /// Returns null on success, or an error message on failure.
  /// Calls [onSaved] with the new sync record if the push succeeds.
  Future<String?> pushSession({
    required WorkoutSession session,
    required String owner,
    required String repo,
    required String branch,
    SessionSyncRecord? existingRecord,
    required void Function(SessionSyncRecord) onSaved,
  }) async {
    try {
      final hash = WorkoutMarkdownService.sessionHash(session);

      // Skip if nothing changed since last sync
      if (existingRecord != null && existingRecord.sessionHash == hash) {
        return null;
      }

      final filePath = WorkoutMarkdownService.sessionFilePath(session);
      final content = WorkoutMarkdownService.buildNote(session);

      // Determine existingSha for the PUT.
      String? existingSha;
      if (existingRecord != null && existingRecord.filePath != filePath) {
        // Workout was renamed — archive the old file and create a fresh one
        // at the new path (no prior SHA needed).
        await archiveWorkout(
          owner: owner,
          repo: repo,
          branch: branch,
          sourcePath: existingRecord.filePath,
        );
        // Check if a file already exists at the new path too (edge case)
        existingSha = await getFileSha(
            owner: owner, repo: repo, branch: branch, path: filePath);
      } else {
        // Always fetch the live SHA — covers both updates and first-time pushes
        // where the file may already exist on GitHub (avoids 422).
        existingSha = await getFileSha(
            owner: owner, repo: repo, branch: branch, path: filePath);
      }

      final newSha = await putFile(
        owner: owner,
        repo: repo,
        branch: branch,
        path: filePath,
        content: content,
        existingSha: existingSha,
        commitMessage: 'workout: ${session.name}',
      );

      onSaved(SessionSyncRecord(
        sessionId: session.id,
        filePath: filePath,
        githubSha: newSha,
        sessionHash: hash,
        syncedAt: DateTime.now(),
      ));

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Creates or updates a file. Returns the new GitHub SHA.
  /// Pass [existingSha] for updates; omit for new files.
  /// Throws on error.
  Future<String> putFile({
    required String owner,
    required String repo,
    required String branch,
    required String path,
    required String content,
    String? existingSha,
    String? commitMessage,
  }) async {
    final token = await getPat();
    if (token == null || token.isEmpty) throw Exception('No token configured');

    final body = jsonEncode({
      'message': commitMessage ?? 'sync: $path',
      'content': base64.encode(utf8.encode(content)),
      'branch': branch,
      if (existingSha != null) 'sha': existingSha,
    });

    final res = await http
        .put(
          Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path'),
          headers: {
            ..._headers(token),
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['content'] as Map<String, dynamic>)['sha'] as String;
    }
    throw Exception('GitHub PUT failed (${res.statusCode}): ${res.body}');
  }
}
