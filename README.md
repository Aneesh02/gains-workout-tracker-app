# Gains — Workout Tracker

A Flutter workout tracking app for Android. Dark-themed, offline-first, no mandatory backend. Log every set, track PRs, and optionally sync your history as markdown to your own GitHub repo.

**Homepage:** https://aneesh02.github.io/gains-workout-tracker-app/

---

## Features

- Full workout logging — weight, reps, RPE, cardio (distance + time)
- Rest timer with ±30s adjustments
- Personal records auto-detected on workout finish
- Exercise library with 300+ exercises, plus custom exercise creation
- Progress charts — e1RM trend, volume, max weight per exercise
- Workout templates
- Plate calculator with barbell visual
- GitHub sync — push workouts as markdown to your own repo
- CSV export of full history
- Offline-first — works without any account or network

---

## Tech Stack

| Thing | Detail |
|-------|--------|
| Framework | Flutter / Dart (`sdk: ^3.11.5`) |
| State management | `provider` — single `WorkoutProvider` (ChangeNotifier) |
| Persistence | `hive_flutter` — single box, all models stored as JSON strings |
| Charts | `fl_chart` |
| Sound | `audioplayers` |
| Sharing | `share_plus` |
| GitHub sync | `http` + GitHub Contents API |
| Secure storage | `flutter_secure_storage` (Android Keystore) |

---

## Setup

### Prerequisites
- Flutter SDK `>=3.11.5`
- Android SDK (target Android 5.0+, min SDK 21)

### Run
```bash
flutter pub get
flutter run
```

### Build APK
```bash
flutter build apk --release
```

### GitHub Sync (optional)
To enable GitHub sync for all users, register a GitHub OAuth App:

1. Go to `github.com/settings/developers` → OAuth Apps → New OAuth App
2. Set Homepage URL to your app's URL
3. Enable **Device Flow**
4. Copy the `client_id` into `lib/services/github_auth_service.dart`:
   ```dart
   static const clientId = 'YOUR_CLIENT_ID_HERE';
   ```

Users then sign in via the Device Flow — they just enter a code at `github.com/login/device`, no manual tokens.

---

## File Structure

```
lib/
├── main.dart                          — App entry, MainScreen (5-tab nav)
├── theme/
│   └── app_theme.dart                 — AppColors + AppTheme
├── models/
│   ├── exercise.dart                  — Exercise, ExerciseType, PlateLoadingType
│   ├── set_entry.dart                 — SetEntry + SetType enum
│   ├── workout_exercise.dart          — WorkoutExercise
│   ├── workout_session.dart           — WorkoutSession
│   ├── workout_template.dart          — WorkoutTemplate + TemplateExercise
│   ├── pr_record.dart                 — PrRecord {e1rm, weight, reps, date}
│   ├── insights.dart                  — PostWorkoutInsights
│   ├── sync_state.dart                — SessionSyncRecord
│   └── gym_settings.dart              — GymSettings {bars, plates, github*, obsidian*}
├── data/
│   └── exercise_data.dart             — Default exercises with tags + PlateLoadingType
├── providers/
│   └── workout_provider.dart          — Single source of truth for all state
├── services/
│   ├── github_auth_service.dart       — GitHub Device Flow OAuth
│   ├── github_sync_service.dart       — GitHub Contents API sync
│   ├── workout_markdown_service.dart  — Workout → markdown formatter
│   ├── metrics_markdown_service.dart  — Metrics snapshot formatter
│   ├── csv_export_service.dart        — CSV export + share
│   ├── csv_import_service.dart        — CSV history import
│   ├── obsidian_export_service.dart   — Direct file write to Obsidian vault
│   └── sound_service.dart             — Sound playback
├── widgets/
│   ├── custom_keyboard.dart           — Custom numeric keyboard
│   └── plate_calculator.dart          — Plate calculator bottom sheet
└── screens/
    ├── workout_tab_screen.dart         — Workout tab: dashboard, templates
    ├── active_workout_screen.dart      — Active workout tracking
    ├── exercise_picker_screen.dart     — Exercise picker
    ├── create_exercise_sheet.dart      — Create / edit custom exercise
    ├── congratulations_screen.dart     — Post-workout summary
    ├── history_screen.dart             — History tab
    ├── workout_detail_screen.dart      — Past workout detail + share
    ├── edit_workout_screen.dart        — Edit completed workout
    ├── exercises_tab_screen.dart       — Exercises tab
    ├── exercise_detail_screen.dart     — Per-exercise stats + chart
    ├── github_connect_screen.dart      — GitHub OAuth + repo picker
    ├── metrics_screen.dart             — Metrics tab
    └── profile_screen.dart            — Profile tab + SettingsScreen
```

---

## Data Models

### `exercise.dart`
```dart
enum ExerciseType { weight, cardio }

enum PlateLoadingType {
  none,          // dumbbells, cables, bodyweight, stack machines
  barbellBoth,   // bar + plates × 2
  barbellSingle, // bar + plates × 1 (e.g. T-bar row)
  machineBoth,   // plates × 2, no bar (e.g. leg press)
  machineSingle, // plates × 1, no bar
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
}
```

### `set_entry.dart`
```dart
enum SetType { normal, warmUp, dropSet, failure }

class SetEntry {
  SetType setType;
  int setNumber;
  String weightInput;
  String repsInput;
  double? rpe;
  bool completed;
  double? previousWeight;
  int? previousReps;
  String kmInput;
  String timeInput;
}
```

Previous value matching is type-aware: warmup set 2 matches the previous session's warmup set 2; working set 3 matches working set 3.

### `workout_session.dart`
```dart
class WorkoutSession {
  final String id;
  String name;
  String notes;
  final DateTime startTime;
  DateTime? endTime;
  List<WorkoutExercise> exercises;
  List<String> personalRecords;

  // computed: duration, formattedDuration, totalVolume, completedSets
}
```

---

## GitHub Sync — How it works

Each finished workout is pushed to GitHub as `workouts/YYYY-MM-DD-workout-name.md` with YAML frontmatter (date, duration, volume, muscles, PRs, per-exercise stats) followed by markdown set tables.

- SHA-256 hash of session JSON — skips unchanged sessions
- Live SHA fetch before every PUT — prevents 422 conflicts
- Rename detection — archives old file, creates at new path
- Delete locally → next sync moves file to `archive/` on GitHub
- `metrics-snapshot.md` always overwritten on sync
- Auth via GitHub Device Flow — no manual tokens

---

## Analytics

All computed offline from local history:

```
getAllTimeStats()             → {totalWorkouts, totalSets, totalVolume, totalMinutes, totalPRs}
getConsistencyScore()        → int 0–100
getMuscleGroupSetsAllTime()  → Map<String, int>
getMostTrainedExercises()    → List<Exercise> top 10
getTrainingPatterns()        → {topDay, topTimeOfDay, avgDuration}
getAllTimePRs()               → grouped by muscle group
getExerciseHistory(id)        → e1RM + volume trend data
getPostWorkoutInsights(s)     → PRs, volume change, rest comparison
getFrequencyTrend()           → avg sessions/week, last 4 vs previous 4 weeks
getPushPullRatio()            → push sets / pull sets, last 30 days
getNeglectedMuscles()         → muscles not trained in last 14 days
getPlateauFlags()             → exercises with <1% e1RM improvement over last 4 sessions
```

---

## App Theme

```
Background    #2A2D35
Surface       #32363F
Blue          #4A9EFF
Red           #CF6679
Check green   #4CAF50
Text primary  #FFFFFF
Text muted    #9E9E9E
```

Muscle group colours: Chest=blue, Back=purple, Shoulders=orange, Arms=red, Legs=green, Core=yellow, Full Body=teal, Cardio=pink.

---

## Key Design Decisions

- **Single provider** — All state in `WorkoutProvider`. No per-screen providers.
- **Hive persistence** — Single box. All models `toJson/fromJson`. Active workout persisted for crash recovery.
- **Type-aware previous values** — Warmup and working sets have independent previous-value histories. Changing a set's type immediately refreshes its previous display.
- **Warmup sets excluded from PRs** — Only `normal`, `dropSet`, `failure` sets count toward e1RM personal records.
- **Debounced saves** — Input methods (weight, reps, km, time) debounce Hive writes at 500ms with no `notifyListeners()` — zero rebuilds per keystroke.
- **Isolated timers** — Rest timer uses `ValueNotifier` + `ValueListenableBuilder`; elapsed counter is its own `StatefulWidget`. Neither triggers a full-screen rebuild.
- **RepaintBoundary per exercise card** — Prevents repaints cascading across the exercise list.
- **GitHub sync: always fetch live SHA** — Avoids 422/409 conflicts regardless of sync record state.

---

## Roadmap

| Priority | Feature |
|----------|---------|
| High | Progressive overload suggestions |
| Medium | Supersets |
| Medium | Body measurements tab |
| Low | Notifications / reminders |
| Future | Firebase cloud backup |
| Future | Claude AI coaching integration |

---

## License

MIT
