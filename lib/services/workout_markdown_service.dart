import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/workout_session.dart';
import '../models/set_entry.dart';
import '../models/exercise.dart';

class WorkoutMarkdownService {
  /// Generates the full Obsidian/GitHub markdown note for a session.
  static String buildNote(WorkoutSession session) {
    final date = session.startTime;
    final dateStr = _dateStr(date);
    final durationMin = session.duration.inMinutes;
    final volumeKg = session.totalVolume;

    final allSets = session.exercises.expand((e) => e.sets).toList();
    final totalSets = allSets.length;
    final completedSets = allSets.where((s) => s.completed).length;
    final completionRate =
        totalSets > 0 ? (completedSets / totalSets) : 0.0;

    final muscleGroups = session.exercises
        .map((e) => e.muscleGroup)
        .toSet()
        .toList()
      ..sort();

    final prList = session.personalRecords.isEmpty
        ? '[]'
        : '[${session.personalRecords.map((n) => '"$n"').join(', ')}]';

    final exercisesFrontmatter = session.exercises
        .map((ex) {
          if (ex.exerciseType == ExerciseType.cardio) {
            final completedCardio = ex.sets
                .where((s) => s.completed && s.kmInput.isNotEmpty)
                .toList();
            if (completedCardio.isEmpty) return null;
            final bestKm = completedCardio
                .map((s) => double.tryParse(s.kmInput) ?? 0)
                .reduce((a, b) => a > b ? a : b);
            return '  - name: "${ex.exerciseName}"\n'
                '    muscle_group: "${ex.muscleGroup}"\n'
                '    best_km: $bestKm\n'
                '    total_sets: ${completedCardio.length}';
          } else {
            final working = ex.sets
                .where((s) =>
                    s.completed &&
                    s.setType != SetType.warmUp &&
                    s.weight != null &&
                    s.reps != null)
                .toList();
            if (working.isEmpty) return null;
            double topWeight = 0;
            int topReps = 0;
            double bestE1rm = 0;
            int exVolume = 0;
            for (final s in working) {
              exVolume += (s.weight! * s.reps!).round();
              final e1rm = s.weight! * (1 + s.reps! / 30.0);
              if (e1rm > bestE1rm) {
                bestE1rm = e1rm;
                topWeight = s.weight!;
                topReps = s.reps!;
              }
            }
            return '  - name: "${ex.exerciseName}"\n'
                '    muscle_group: "${ex.muscleGroup}"\n'
                '    top_set_kg: ${_fmtW(topWeight)}\n'
                '    top_set_reps: $topReps\n'
                '    e1rm: ${bestE1rm.toStringAsFixed(1)}\n'
                '    total_sets: ${working.length}\n'
                '    volume_kg: $exVolume';
          }
        })
        .whereType<String>()
        .join('\n');

    final buf = StringBuffer();

    // ── YAML frontmatter ──────────────────────────────────────────────────
    buf.writeln('---');
    buf.writeln('date: $dateStr');
    buf.writeln('time_of_day: ${_timeOfDay(date)}');
    buf.writeln('type: workout');
    buf.writeln('duration_min: $durationMin');
    buf.writeln('volume_kg: $volumeKg');
    buf.writeln('total_sets: $totalSets');
    buf.writeln('completed_sets: $completedSets');
    buf.writeln(
        'completion_rate: ${completionRate.toStringAsFixed(2)}');
    buf.writeln(
        'muscle_groups: [${muscleGroups.map((m) => '"$m"').join(', ')}]');
    buf.writeln('personal_records: $prList');
    if (exercisesFrontmatter.isNotEmpty) {
      buf.writeln('exercises:');
      buf.writeln(exercisesFrontmatter);
    }
    buf.writeln('tags: [workout]');
    buf.writeln('daily: "[[${dateStr}]]"');
    buf.writeln('---');
    buf.writeln();

    // ── Title ─────────────────────────────────────────────────────────────
    buf.writeln(
        '# ${session.name} · ${_fmtDuration(session.duration)}');
    buf.writeln();

    if (session.personalRecords.isNotEmpty) {
      buf.writeln(
          '> **New PRs:** ${session.personalRecords.join(', ')}');
      buf.writeln();
    }

    // ── Exercise tables ───────────────────────────────────────────────────
    for (final ex in session.exercises) {
      buf.writeln('## ${ex.exerciseName}');
      buf.writeln();

      final isCardio = ex.sets
          .any((s) => s.kmInput.isNotEmpty || s.timeInput.isNotEmpty);

      if (isCardio) {
        buf.writeln('| Set | km | Time | Done |');
        buf.writeln('|-----|----|------|------|');
        for (final s in ex.sets) {
          final km = s.kmInput.isEmpty ? '—' : s.kmInput;
          final time = s.timeInput.isEmpty ? '—' : s.timeInput;
          final done = s.completed ? '✓' : '';
          buf.writeln('| ${_setLabel(s)} | $km | $time | $done |');
        }
      } else {
        final hasRpe = ex.sets.any((s) => s.rpe != null);
        if (hasRpe) {
          buf.writeln('| Set | kg | Reps | RPE | Done |');
          buf.writeln('|-----|----|------|-----|------|');
          for (final s in ex.sets) {
            final kg = s.weight != null ? _fmtW(s.weight!) : '—';
            final reps = s.reps?.toString() ?? '—';
            final rpe =
                s.rpe != null ? s.rpe!.toStringAsFixed(1) : '—';
            final done = s.completed ? '✓' : '';
            buf.writeln(
                '| ${_setLabel(s)} | $kg | $reps | $rpe | $done |');
          }
        } else {
          buf.writeln('| Set | kg | Reps | Done |');
          buf.writeln('|-----|----|------|------|');
          for (final s in ex.sets) {
            final kg = s.weight != null ? _fmtW(s.weight!) : '—';
            final reps = s.reps?.toString() ?? '—';
            final done = s.completed ? '✓' : '';
            buf.writeln('| ${_setLabel(s)} | $kg | $reps | $done |');
          }
        }
      }
      buf.writeln();
    }

    return buf.toString();
  }

  /// Relative path in the GitHub repo, e.g. "workouts/2026-04-27-evening-workout.md"
  static String sessionFilePath(WorkoutSession session) {
    final dateStr = _dateStr(session.startTime);
    final slug = session.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'workouts/$dateStr-$slug.md';
  }

  /// SHA-256 of the session JSON — used to detect edits between syncs.
  static String sessionHash(WorkoutSession session) {
    final bytes = utf8.encode(jsonEncode(session.toJson()));
    return sha256.convert(bytes).toString();
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _timeOfDay(DateTime d) {
    final h = d.hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 21) return 'evening';
    return 'night';
  }

  static String _setLabel(SetEntry s) {
    switch (s.setType) {
      case SetType.warmUp:
        return 'W${s.setNumber}';
      case SetType.dropSet:
        return 'D${s.setNumber}';
      case SetType.failure:
        return 'F${s.setNumber}';
      default:
        return '${s.setNumber}';
    }
  }

  static String _fmtW(double w) =>
      w % 1 == 0 ? w.toInt().toString() : w.toString();

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
