import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';

class CsvExportService {
  static const _headers = [
    'Date',
    'Workout Name',
    'Duration (min)',
    'Exercise Name',
    'Muscle Group',
    'Set Order',
    'Weight (kg)',
    'Reps',
    'Distance (km)',
    'Time (sec)',
    'RPE',
    'Completed',
    'Notes',
  ];

  static String buildCsv(List<WorkoutSession> sessions) {
    final buf = StringBuffer();
    buf.writeln(_headers.join(','));

    // Newest first matches how history screen displays
    final sorted = sessions.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    for (final session in sorted) {
      final date =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(session.startTime);
      final workoutName = _esc(session.name);
      final duration = session.duration?.inMinutes ?? 0;

      for (final ex in session.exercises) {
        final exName = _esc(ex.exerciseName);
        final muscle = _esc(ex.muscleGroup);
        final isCardio = ex.exerciseType == ExerciseType.cardio;

        for (final set in ex.sets) {
          buf.writeln([
            date,
            workoutName,
            duration,
            exName,
            muscle,
            set.setNumber,
            !isCardio && set.weight != null ? set.weight : '',
            !isCardio && set.reps != null ? set.reps : '',
            isCardio && set.kmInput.isNotEmpty ? set.kmInput : '',
            isCardio && set.timeInput.isNotEmpty ? set.timeInput : '',
            set.rpe ?? '',
            set.completed ? '1' : '0',
            _esc(session.notes),
          ].join(','));
        }
      }
    }
    return buf.toString();
  }

  static Future<void> exportAndShare(List<WorkoutSession> sessions) async {
    final csv = buildCsv(sessions);
    final dir = await getTemporaryDirectory();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/gains_export_$date.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Gains Workout History',
    );
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
