# Strong Clone

A Flutter clone of the **Strong** workout tracking app. Dark-themed, offline-first, no backend.
Goal: feature and UX parity with Strong — same flow, same sounds, same feel.

---

## Project Paths

| Thing | Path |
|-------|------|
| Project root | `D:\Aneesh\Projects\strong_clone` |
| Flutter SDK (PATH — old) | `D:\Software\flutter_windows_2.10.4-stable\flutter\bin\` |
| Strong APK decompiled | `D:\Aneesh\Projects\decompiled` (jadx output) |
| jadx | `D:\Software\jadx-1.5.5` |
| Target device | Aneesh's Redmi Note 11 (Android) |

> **How to run:** Open in Android Studio or VS Code. Connect Redmi Note 11 via USB (USB debugging on). Run via IDE — do **not** use the terminal `flutter` command (PATH points to old 2.10.4 SDK; pubspec requires `sdk: ^3.11.5`).

---

## Tech Stack

| Thing | Detail |
|-------|--------|
| Framework | Flutter / Dart (`sdk: ^3.11.5`) |
| State management | `provider` ^6.1.2 — single `WorkoutProvider` (ChangeNotifier) |
| Persistence | `hive_flutter` ^1.1.0 — single box `strongclone`, all models stored as JSON strings |
| Charts | `fl_chart` ^0.68.0 — LineChart (exercise e1RM trend) |
| Sound | `audioplayers` ^6.1.0 |
| Sharing | `share_plus` ^10.1.4 |
| Date formatting | `intl` ^0.19.0 |
| IDs | `uuid` ^4.5.1 |
| Assets | `assets/sounds/` — 13 MP3/WAV files extracted from Strong APK |

---

## File Structure

```
lib/
├── main.dart                          — App entry, MainScreen (5-tab nav), _WorkoutBanner
├── theme/
│   └── app_theme.dart                 — AppColors + AppTheme
├── models/
│   ├── exercise.dart                  — Exercise, ExerciseType enum, PlateLoadingType enum
│   ├── set_entry.dart                 — SetEntry + SetType enum (+ toJson/fromJson)
│   ├── workout_exercise.dart          — WorkoutExercise (+ toJson/fromJson)
│   ├── workout_session.dart           — WorkoutSession (+ toJson/fromJson)
│   ├── workout_template.dart          — WorkoutTemplate + TemplateExercise
│   ├── pr_record.dart                 — PrRecord {e1rm, weight, reps, date}
│   ├── insights.dart                  — PostWorkoutInsights, ExerciseInsight, InsightDirection
│   └── gym_settings.dart              — GymSettings {bars, plates, obsidianVaultPath}
├── data/
│   └── exercise_data.dart             — ~110 default exercises with tags + PlateLoadingType
├── providers/
│   └── workout_provider.dart          — Single source of truth for all state
├── services/
│   ├── csv_import_service.dart        — Parses Strong-format CSV into WorkoutSession list
│   ├── obsidian_export_service.dart   — Writes Dataview-compatible .md notes to Obsidian vault
│   └── sound_service.dart             — Sound playback (audioplayers)
├── widgets/
│   ├── custom_keyboard.dart           — Custom numeric keyboard + KeyboardController
│   └── plate_calculator.dart          — Plate calculator bottom sheet + barbell visual
└── screens/
    ├── workout_tab_screen.dart         — "Workout" tab: dashboard + start + templates
    ├── active_workout_screen.dart      — Full workout tracking screen
    ├── exercise_picker_screen.dart     — Exercise picker (search, filter chips, multi-select)
    ├── congratulations_screen.dart     — Post-workout summary + post-workout insights
    ├── history_screen.dart             — History tab: day-grouped workout cards
    ├── workout_detail_screen.dart      — Full breakdown of a past workout + share
    ├── exercises_tab_screen.dart       — Exercises tab (search/filter, taps to detail)
    ├── exercise_detail_screen.dart     — Per-exercise stats, e1RM chart, recent sessions
    └── profile_screen.dart            — Profile tab: stats, charts, PRs + SettingsScreen

assets/
└── sounds/
    boxing_bell.mp3, checkmark_revised.mp3, finish_normal.mp3, finish_pr.mp3,
    finish_super.mp3, swipe_delete.mp3, click.wav, toggle.wav, delightful.mp3,
    short_bell.mp3, tritone_revised.mp3, radar.mp3, melody_chime.mp3
```

---

## Data Models

### `exercise.dart`
```dart
enum ExerciseType { weight, cardio }

enum PlateLoadingType {
  none,          // dumbbells, cables, bodyweight, stack machines
  barbellBoth,   // bar + plates × 2 (standard barbell)
  barbellSingle, // bar + plates × 1 (T-bar row — one end loaded)
  machineBoth,   // plates × 2, no bar (leg press, hack squat)
  machineSingle, // plates × 1, no bar (single plate front raise)
}

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final ExerciseType type;
  final List<String> tags;
  final PlateLoadingType plateLoadingType;
  int timesPerformed;
}
```
Tag values in use: `Push`, `Pull`, `Compound`, `Isolation`, `Bodyweight`, `Unilateral`

### `set_entry.dart`
```dart
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
  double? previousWeight;   // from last session — matched by set type independently
  int? previousReps;
  double? previousRpe;
  String kmInput;
  String timeInput;
  double? previousKm;
  String? previousTime;
}
```
**Previous value matching is type-aware:** warmup set 2 matches the previous session's warmup set 2; working set 3 matches previous working set 3. They do not cross-match.

### `workout_exercise.dart`
```dart
class WorkoutExercise {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final ExerciseType exerciseType;
  PlateLoadingType plateLoadingType;  // non-final: re-applied from exercise definitions on Hive load
  List<SetEntry> sets;
  int restSeconds;
}
```

### `workout_session.dart`
```dart
class WorkoutSession {
  final String id;
  String name;
  final DateTime startTime;
  DateTime? endTime;
  List<WorkoutExercise> exercises;
  List<String> personalRecords;

  // computed: duration, formattedDuration, elapsedLabel, totalVolume, completedSets
}
```

### `pr_record.dart`
```dart
class PrRecord {
  final double e1rm;    // Epley: weight × (1 + reps/30)
  final double weight;
  final int reps;
  final DateTime date;
}
```
Backward-compat: old saves that stored only a `double` e1rm are wrapped as `PrRecord(e1rm: v, weight: 0, reps: 0, date: DateTime(2000))`.
Warmup sets are excluded from PR calculation — only `normal`, `dropSet`, `failure` sets count.

### `gym_settings.dart`
```dart
class GymBar { String name; double weight; }

class GymSettings {
  List<GymBar> bars;
  List<double> plates;          // available plate weights (kg)
  String obsidianVaultPath;     // full path, e.g. /storage/emulated/0/Obsidian/Gym
  static GymSettings get defaults;  // Olympic/Women's/EZ/Trap/Safety/Swiss bars, standard plates
}
```

---

## Provider — `WorkoutProvider`

Single `ChangeNotifier`. All state persisted to Hive box `strongclone`.

### State
```
WorkoutSession? _activeWorkout
List<WorkoutSession> _history             — newest first
List<Exercise> _exercises                 — from defaultExercises + timesPerformed from Hive
Map<String, PrRecord> _prRecords          — best e1rm per exerciseId
List<WorkoutTemplate> _templates
Map<String, int> _exerciseRestSeconds     — per-exercise rest overrides
GymSettings _gymSettings                  — bars, plates, obsidianVaultPath
Set<String> _seenMilestones
int _weeklyTargetDays = 3
int _weekStartDay = 1                     — 1 = Monday, 7 = Sunday
```

### Analytics (all offline, read from `_history`)
```
getAllTimeStats()             → {totalWorkouts, totalSets, totalVolume, totalMinutes, totalPRs}
getMuscleGroupSetsAllTime()  → Map<String, int>
getVolumeByWeek({weeks})     → List<WeeklyVolumeEntry>
getMostTrainedExercises()    → List<Exercise> top 10 by timesPerformed
getTrainingPatterns()        → {topDay, topTimeOfDay, avgDuration}
getAllTimePRs()               → List<{exerciseId, exerciseName, muscleGroup, pr}>
getExerciseHistory(id)        → List<ExerciseHistoryEntry>
getPostWorkoutInsights(s)     → PostWorkoutInsights
getMuscleNudges()             → List<MuscleNudge> overdue muscle groups
getWeeklyMuscleSets()         → Map<String, int> sets per muscle this week
getPendingMilestones()        → List<PendingMilestone> unseen banners
dismissMilestone(key)
```

### Extended metrics (all offline — built for Obsidian export and future AI coaching)
```
getConsistencyScore({weeks=12})   → int 0–100  — % of last N weeks where sessions ≥ weeklyTargetDays
getFrequencyTrend()               → {recent: double, previous: double}  — avg sessions/week, last 4 vs previous 4 weeks
getLongestGapDays()               → int  — longest gap (days) between any two consecutive workouts
getPushPullRatio()                → double  — push sets / pull sets, last 30 days (1.0 if no data)
getWeeklyVolumeSpike()            → double?  — % change last week vs 4-week avg; null if insufficient data
getNeglectedMuscles({days=14})    → List<String>  — muscles trained historically but not in last N days
getExerciseVarietyScore({days=28})→ int  — unique exercises performed in last N days
getRetiredExercises({olderThan=45})→ List<String>  — exercises not done in last N days but done before
getAvgSetCompletionRate()         → double 0–1  — avg completion rate across last 8 sessions
getAvgSessionDensity()            → double  — avg sets/hour across last 8 sessions
getPRVelocity()                   → {recent: int, previous: int}  — PRs set last 8 weeks vs previous 8 weeks
getPlateauFlags()                 → List<String>  — exercises with < 1% e1RM improvement across last 4 sessions
```

### Streak
`getCurrentStreakWeeks()` / `getBestStreakWeeks()` — a week counts only if workouts that week ≥ `weeklyTargetDays`. Week boundary driven by `weekStartDay`.

### Previous value population
`_populatePreviousValues(WorkoutExercise)` groups the previous session's sets by `SetType`, maps each new set to the same-type positional counterpart. Called on `addExercise`, `addExercises`, `replaceExercise`, `startWorkoutFromTemplate`, `addSet`.

`updateSetType()` immediately re-fetches correct previous values when a set's type changes.

### Plate loading migration
On Hive load, `plateLoadingType` is re-applied from current `_exercises` definitions. Fixes sessions saved before plate loading was implemented (they defaulted to `none`).

---

## Plate Calculator

**`plate_calculator.dart`** → `PlateCalculatorSheet`

Mode selector (3 chips):
- **Barbell** (`barbellBoth`) — bar + 2×plates; shows bar selector row
- **Machine** (`machineBoth`) — no bar, 2×plates
- **Single** (`machineSingle`) — no bar, 1×plates

Opens in the mode matching the exercise's `plateLoadingType`. Switching mode clears plates.

The barbell visual shows: shaft → collar → sorted plates (heaviest inner) → collar → sleeve. Tap a plate on the visual to remove it (outermost of that weight). Tap a plate chip to add it.

**`Use weight`** button returns the total via `Navigator.pop(context, totalWeight)`, which the keyboard controller picks up and fills into the KG field.

Plate loading assignments:
| Type | Example exercises |
|------|------------------|
| `barbellBoth` | Bench Press, Squat, Deadlift, OHP, Romanian DL, Hip Thrust (Barbell), Skull Crusher, all barbell variants |
| `barbellSingle` | T Bar Row |
| `machineBoth` | Leg Press, Hack Squat, Iso-Lateral Chest/Row, Incline Chest Press (Machine), Chest Supported Row, Hip Thrust (Machine) |
| `machineSingle` | Front Raise (Plate) |

---

## Obsidian Export

**Status:** Implemented in Session 9.

When a workout is finished, `_doFinish()` calls `ObsidianExportService.exportToVault(session, vaultPath)`. If a vault path is configured, a `.md` file is written to that folder. On failure (e.g. permission denied), a red snackbar is shown before navigating to CongratsScreen.

### Note format
File name: `2026-04-26-evening-workout.md`

```markdown
---
date: 2026-04-26
type: workout
duration_min: 52
volume_kg: 14200
muscle_groups: ["Chest", "Legs"]
personal_records: ["Bench Press (Barbell)"]
exercises:
  - name: "Bench Press (Barbell)"
    top_set_kg: 102.5
    top_set_reps: 5
    total_sets: 4
    volume_kg: 1950
---

# Evening Workout · 52m

> **New PRs:** Bench Press (Barbell)

## Bench Press (Barbell)

| Set | kg | Reps | Done |
|-----|----|------|------|
| W1 | 60 | 10 | ✓ |
| 1 | 100 | 5 | ✓ |
| 2 | 102.5 | 5 | ✓ |
```

Set labels: `W`=warmup, `D`=drop, `F`=failure, number=normal.
Cardio exercises get `km`/`Time` columns instead of `kg`/`Reps`.
RPE column added to tables where any set has an RPE value.

### Configuration
Settings → Obsidian → Vault Path. Enter a full device path, e.g.:
```
/storage/emulated/0/Obsidian/Gym
```

### Android permissions
`AndroidManifest.xml` has:
- `WRITE_EXTERNAL_STORAGE` (maxSdk 29)
- `READ_EXTERNAL_STORAGE` (maxSdk 32)
- `MANAGE_EXTERNAL_STORAGE`
- `android:requestLegacyExternalStorage="true"` on `<application>`

On Android 11+, grant **"All files access"** for the app via Settings → Apps → Special app access → All files access. Without this the write will fail and the snackbar will show the error.

### Why direct file write (not MCP)
MCP is for Claude to *read* data on demand for AI coaching. It is not needed for app→Obsidian writes. The app calculates all metrics itself, formats them into Dataview-compatible YAML frontmatter, and writes directly. The Dataview frontmatter means notes are queryable in Obsidian without AI involvement.

### Future scope: AI coaching via MCP
When Claude AI coaching is integrated (Phase 2 / ROCK project), the approach will be:
1. The app continues writing notes to Obsidian on every workout finish.
2. A Claude MCP server is configured to *read* the Obsidian vault.
3. Claude can then query workout history on demand to give periodization advice, progression nudges, deload recommendations, etc.
4. This is additive — the Dataview-compatible format makes the same notes useful for both Obsidian queries and AI consumption, with no reformatting needed.

---

## Screens

### `main.dart` — `MainScreen`
5-tab bottom nav: **Profile** | **History** | **Workout** | **Exercises** | Measure (stub).
Default tab index 2 (Workout).

`_WorkoutBanner` — shown above bottom nav when `hasActiveWorkout`. Tapping pushes `ActiveWorkoutScreen`.

### `workout_tab_screen.dart`
- `_MilestoneBanner` — dismissable gold banner (thresholds: 1, 10, 25, 50, 100, 250, 500 workouts)
- `_StreakCard` + `_NudgeCard` — side by side
- `_WeeklyBalanceCard` — sets per muscle group this week
- Quick Start button
- Templates section (swipe-to-delete)

### `active_workout_screen.dart`
Column header: `SET | PREVIOUS | KG/KM | REPS/TIME | RPE | ✓`
SET column width: 32 px.

Set label (`_setTypeLabel`): `W1`/`W2` (amber), `1`/`2` (white), `D1` (blue), `F1` (red). Tapping opens set-type menu.

Plate calculator triggered when tapping KG field on exercises with non-`none` `plateLoadingType`.

### `exercise_detail_screen.dart`
Entry from Exercises tab or Most Trained list.
- `_StatsRow` — PB, sessions, avg sets, last trained
- `_TrendCallout` — trending up/plateaued/declining (last 4 sessions)
- `_ChartCard` — e1RM / max weight / volume toggle; cardio shows km
- `_RecentSessionsTable` — last 10 sessions

### `profile_screen.dart`
Gear icon → `SettingsScreen`.

Sections: All-Time Stats Grid → Workouts Per Week chart → Muscle Group Breakdown → Training Patterns → Most Trained Exercises → Personal Records.

**`_AllTimeStatsGrid`** — 3×2 grid of stat cells:
| Cell | Value | Notes |
|------|-------|-------|
| Workouts | total count | |
| Sets | total sets | |
| Volume | formatted (1.2k kg / 1.5M kg) | |
| Time | Xh Ym | |
| PRs | total PR count | |
| Consistency | `X%` (subtitle: "Last 12 wks") | `getConsistencyScore()` — % of last 12 weeks where sessions ≥ weeklyTargetDays |

**`SettingsScreen`** sections:
- **Training:** Weekly target (1–7 days), Week starts Mon/Sun
- **Gym Equipment:** Plates & Bars → `GymEquipmentScreen`
- **Obsidian:** Vault Path (tap to edit via dialog)
- **Display:** Units (Soon)
- **Day & Time:** Day starts at, Reminders (Soon)
- **Integrations — Phase 2:** Claude AI, Health data (Soon)
- **Data:** Export workouts, Sync to cloud (Soon)

`_WorkoutsPerWeekChart`: 12 weeks, 7 squares per column, bottom N filled. Blue = met target, orange = below target.

---

## App Theme

```dart
AppColors.background        = 0xFF2A2D35
AppColors.surface           = 0xFF32363F
AppColors.surfaceVariant    = 0xFF3A3E49
AppColors.blue              = 0xFF4A9EFF
AppColors.red               = 0xFFCF6679
AppColors.textPrimary       = Colors.white
AppColors.textSecondary     = 0xFF9E9E9E
AppColors.divider           = 0xFF3E424C
AppColors.completedGreen    = 0xFF1E3A2E
AppColors.checkGreen        = 0xFF4CAF50
AppColors.keyboardBackground = 0xFF1E2028
AppColors.keyboardKey       = 0xFF3A3E49
```

Muscle group palette:
```
Chest=0xFF4A9EFF  Back=0xFF7B61FF  Shoulders=0xFFFF9F43  Arms=0xFFFF6B6B
Legs=0xFF26DE81   Core=0xFFFECA57  Full Body=0xFF45B7D1  Cardio=0xFFFF8C94
```

---

## Key Design Decisions

- **Single provider** — All state in `WorkoutProvider`. No per-screen providers.
- **Hive persistence** — Single box `strongclone`. All models `toJson/fromJson`. Active workout persisted for crash recovery.
- **Type-aware previous values** — Warmup and working sets have independent previous-value histories. Changing a set's type immediately refreshes its previous display.
- **Warmup sets excluded from PRs** — Only `normal`, `dropSet`, `failure` count toward e1RM personal records.
- **Streak is weekly, target-based** — Week boundary from `weekStartDay`. A week counts only if workouts ≥ `weeklyTargetDays`.
- **Settings are instant** — `SettingsScreen` uses `context.watch<WorkoutProvider>()`, rebuilds on every notification. No close-and-reopen needed.
- **Plate loading migration** — On Hive load, `plateLoadingType` re-applied from exercise definitions. Transparent fix for old saves.
- **Sounds via fresh AudioPlayer** — Avoids singleton stop/play race conditions.
- **Dismissible key = set.id** — Stable counter-based ID, not position index.
- **Previous values as faint overlay** — 40% opacity `Text`, disappears once field is non-empty.
- **fl_chart usage** — `getTooltipColor` callback (not deprecated `tooltipBgColor`).
- **Obsidian: direct file write, Dataview frontmatter** — App writes YAML frontmatter so notes are queryable by Dataview in Obsidian without AI. MCP is reserved for Phase 2 AI coaching (Claude reads the vault on demand).
- **Obsidian export is fire-and-forget** — `_doFinish()` stays synchronous; the export `Future<String?>` is passed to `CongratsScreen` which shows the snackbar on failure. Keeping `_doFinish` sync prevents a race where `notifyListeners()` triggers a rebuild before `Navigator.pushReplacement` fires (which would show a blank `SizedBox.shrink()` — the dark screen bug).
- **Extended metrics pre-computed** — `getConsistencyScore`, `getFrequencyTrend`, `getPushPullRatio`, etc. are all computed in-app and available to be included in the Obsidian note YAML, making the notes rich enough for Dataview queries and AI coaching without needing live data access.

---

## What Is NOT Yet Built

| Priority | Feature | Notes |
|----------|---------|-------|
| High | **Custom exercises** | No UI to add user-defined exercises. Provider and picker are architecturally ready. |
| High | **Measure tab** | Stub. Body measurements / bodyweight tracking. |
| Medium | **Superset support** | Exercises grouped to share rest timer. Not implemented. |
| Medium | **workout_detail_screen set numbers** | Still `Colors.orange`. Should be white. |
| Low | **Day starts at** | In Settings as placeholder. |
| Future | **Obsidian export UX polish** | Permission guidance, test button, export log, per-session re-export from history. See brainstorm below. |
| Future | **Firebase sync** | Phase 3. Fully offline until then. |
| Future | **Claude AI coaching** | Phase 2 guided sessions; MCP reads Obsidian vault. ROCK project. |

---

## Obsidian Export — Brainstorm & Future Work

Current state: works automatically on workout finish if a path is configured.

### Known gaps to address
- **No runtime permission request** — app writes and silently fails on Android 11+ unless "All files access" is granted manually. Need in-app guidance or permission check.
- **No test button** — user can't verify the path works without finishing a workout.
- **No export log** — no way to know if past exports succeeded or where files went.
- **No re-export** — can't re-send a past session from history.

### Ideas under consideration
- **Test write button** in Settings → Obsidian: writes a `_test.md` stub and shows success/failure inline.
- **Permission guidance dialog**: on first export attempt, if write fails, show a dialog with exact steps to grant "All files access".
- **Export status on CongratsScreen**: small tag ("Saved to Obsidian ✓" or "Export failed") so the user knows immediately.
- **Re-export from workout detail**: "Send to Obsidian" button on `WorkoutDetailScreen` for past sessions.
- **Folder auto-creation**: already implemented (`dir.createSync(recursive: true)`).
- **Configurable subfolder by year/month**: e.g. `2026/04/2026-04-26-workout.md` for vault organisation.
- **Toggle**: on/off switch in Settings so the path is remembered but export can be paused.

---

## CSV Import / Seeding

`seedFromAsset()` — reads `assets/strong_seed.csv` via `compute()`, seeds `_history` for dev/demo.

`importFromCsv(String csv)` — same format, for future file-picker UI.

**Strong CSV format:** `Workout Name, Start Date, End Date, Exercise Name, Superset Index, Set Type, Weight (kg), Reps, Distance (m), Duration (s), RPE`

---

## APK / Decompile Reference

- Strong APK decompiled to: `D:\Aneesh\Projects\decompiled`
- Strong uses **Realm** database (not SQLite)
- Sound files from `res/raw/` inside the APK
- Set types from decompiled code: `WARM_UP("W")`, `DROP_SET("D")`, `FAILURE("F")`
- RPE range: 6.0–10.0 in 0.5 increments
- CSV export format confirmed from decompiled export logic

---

## Session History

| Session | What was done |
|---------|--------------|
| 1 | Exercise icons, weight vs cardio, green completed sets |
| 2 | 13 UX improvements: blue softening, auto workout naming, _WorkoutBanner, more exercises, filter chips, history screen, PR tracking, sounds, swipe-to-delete, incomplete warning, share |
| 3 | APK extraction, split APK assembly, jadx decompilation, Realm DB analysis |
| 4 | SetType enum (W/D/F), exercise tags, multi-select picker, faint previous hints, sounds fix, swipe-to-delete stable key, rest bar ±30s, incomplete sets fix |
| 5 | Hive persistence (history, PRs, timesPerformed, templates, active workout crash recovery), previous value population, workout templates |
| 6 | PrRecord + PostWorkoutInsights models, ExerciseDetailScreen (fl_chart), ProfileScreen (stats/charts/PRs), WorkoutTab dashboard (streak/nudges/weekly balance/milestones), CongratsScreen insights, gym_settings.dart, plate_calculator.dart, RPE picker, PlateLoadingType enum |
| 7 | SettingsScreen (gear icon), weekly target + week start day settings, workouts-per-week stacked-squares chart, search icon removed, SET header width fix, warmup set numbering (W1/W2 type-aware), type-aware previous values, warmup sets excluded from PR calc, updateSetType refreshes previous, plate calculator mode selector (Barbell/Machine/Single), 12-week chart, plate loading types audited |
| 8 | Bar chip Column overflow fixed, plateLoadingType made non-final, Hive load migration re-applies plate types, more exercises tagged (_mb/_ms): incline chest press machine, chest supported row, hip thrust machine, front raise plate |
| 9 | Obsidian export: `obsidian_export_service.dart`, `obsidianVaultPath` in GymSettings, Settings → Obsidian section with vault path dialog, Android manifest storage permissions |
| 10 | Dark-screen bug fix: reverted `_doFinish` to sync void, export runs as fire-and-forget Future passed to CongratsScreen; Profile consistency score cell (6th stat in grid, `getConsistencyScore()`); 11 new extended metrics methods added to provider: `getFrequencyTrend`, `getLongestGapDays`, `getPushPullRatio`, `getWeeklyVolumeSpike`, `getNeglectedMuscles`, `getExerciseVarietyScore`, `getRetiredExercises`, `getAvgSetCompletionRate`, `getAvgSessionDensity`, `getPRVelocity`, `getPlateauFlags` |
| 11 | Exercise notes per exercise: `notes: String` on `WorkoutExercise`, shown inline below exercise name (italic + note icon, tappable), editable via "Add Note / Edit Note" in exercise menu, shown in WorkoutDetailScreen. Workout rename UI: tap name or pencil icon → rename dialog. Cardio PRs: `PrRecord.km` field + `isCardio` getter; best-km PR tracked in `finishWorkout`; profile PR list and exercise detail stats both display correctly. Units section removed from Settings. |
