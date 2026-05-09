import 'dart:io';
import '../models/workout_session.dart';
import 'workout_markdown_service.dart';

class ObsidianExportService {
  /// Writes a workout note to [vaultPath] on the local filesystem.
  /// Returns null on success, or an error message on failure.
  static Future<String?> exportToVault(
      WorkoutSession session, String vaultPath) async {
    if (vaultPath.isEmpty) return null;
    try {
      final dir = Directory(vaultPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final fileName =
          WorkoutMarkdownService.sessionFilePath(session).split('/').last;
      final file = File('$vaultPath${Platform.pathSeparator}$fileName');
      file.writeAsStringSync(WorkoutMarkdownService.buildNote(session));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
