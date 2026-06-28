> Last compressed: 2026-05-09 17:30

# Session Context

## Where Things Stand

### Projects

#### Gains — Flutter Android Workout Tracker
**Repo:** `github.com/Aneesh02/gains-workout-tracker-app`
**GitHub Pages:** Live at the repo's Pages URL, served from `/docs` on `main`/`master` branch
**Local path:** `D:\Aneesh\Projects\strong_clone`
**Package ID:** `com.gains.app` (renamed from com.aneesh.strong_clone)
**App name:** `gains` in pubspec.yaml

**Current state — fully built, all code pushed to master:**

Features completed this session:
- Smart notifications (3-slot daily: 9 AM fixed, user-chosen time, 8:30 PM post-workout) — `lib/services/notification_service.dart`
- SoundService toggle (sounds on/off) — `lib/services/sound_service.dart`, `GymSettings.soundsEnabled`
- Keep screen on during workout — `wakelock_plus`, toggled in `ActiveWorkoutScreen` initState/dispose
- Bug report tile in Settings → Support → sends mailto to aneeshtickoo2002@gmail.com
- New user banner on Workout tab when history is empty — guides to "Load sample data"
- seedMockData() — 10 generic Push/Pull/Leg sessions, 5 weeks progressive — `WorkoutProvider`
- resetAllData() — clears everything with confirmation dialog — Settings → Data
- Load sample data button in History empty state
- CSV import from any Strong-format CSV — `lib/services/csv_import_service.dart`
  - Tile: Settings → Data → "Import data from CSV" (file_picker)
  - Parses semicolon-delimited Strong export: sets, RPE, cardio distance/time, rest timers
  - Rest Timer rows (Set Order = "Rest Timer", Seconds col = duration) averaged → restSeconds per exercise
  - Deduplicates by startTime (within 60s), computes PRs chronologically, persists to Hive
  - importFromStrong() in WorkoutProvider
- RPE picker: all 9 values (6–10 in 0.5 steps) fit on one row, no scrolling — Expanded children in Row, font size 13
- Milestone banner X button fix — added notifyListeners() to dismissMilestone()
- Package rename: com.gains.app, new MainActivity at `android/app/src/main/kotlin/com/gains/app/`
- Core library desugaring enabled in build.gradle.kts
- AndroidManifest: WAKE_LOCK, POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM permissions

**Build:**
- `flutter build apk --release` works with `kotlin.incremental=false` in `android/gradle.properties`
  (needed because pub cache is on C: and project is on D: — cross-drive Kotlin daemon bug on Windows)
- Release APK (55 MB, debug-signed): `docs/gains.apk` — live on website as direct download
- No Play Store keystore yet — APK is sideload-only for now

**Website (docs/index.html):**
- Screenshot gallery section with 8 real screenshots from screen recording (horizontally scrollable, phone-frame style)
- Screenshots in `docs/screenshots/`: workout_tab, active_workout, plate_calculator, exercise_picker, workout_summary, history, profile, settings
- Hero "Download APK" button → `gains.apk` (direct download)
- Full How-to-use guide with 11 sections including: App preferences (sounds, screen-on), Bug report, sample data, reminders (3/day corrected)
- `.nojekyll` present so GitHub Pages serves HTML directly

**Dependencies added this session:**
- `flutter_local_notifications: ^18.0.0`
- `timezone: ^0.9.4`
- `wakelock_plus: ^1.2.10` (resolved to 1.5.2)
- `file_picker: ^8.1.4` (resolved to 8.3.7)

**Key files:**
- `lib/services/csv_import_service.dart` — Strong CSV parser (already existed, now fully wired)
- `lib/services/notification_service.dart` — 3-slot smart notifications
- `lib/services/sound_service.dart` — static enabled flag
- `lib/providers/workout_provider.dart` — importFromStrong(), seedMockData(), resetAllData(), workedOutToday()
- `lib/screens/profile_screen.dart` — _ImportTile, _ResetDataTile, _switchTile, bug report, reminders, day-starts-at
- `lib/screens/active_workout_screen.dart` — wakelock, notification reschedule on finish, RPE picker fix
- `lib/screens/workout_tab_screen.dart` — _NewUserBanner
- `lib/screens/history_screen.dart` — empty state with Load sample data button
- `lib/models/gym_settings.dart` — soundsEnabled, keepScreenOn, remindersEnabled, reminderHour/Minute, dayStartHour

**User's personal Strong CSV imported:**
- File: `D:\strong4889393444804334205.csv` (~2947 rows, ~200 sessions)
- User has not yet run the import — they'll do it via Settings → Data → Import data from CSV in the app

### Open Threads

#### Play Store Setup (not started)
- Need to create a release keystore (keytool), configure `key.properties`, update `build.gradle.kts` with signingConfigs
- Then rebuild and re-upload APK to Play Store Console
- App ID is `com.gains.app`

#### Health Connect / Google Integration (discussed, not started)
User wants all 3 eventually but Health Connect is priority:
1. **Health Connect** (priority) — push workouts as health activities visible in Google Fit, Samsung Health etc.
   - Use `health` Flutter package
   - Declare permissions in AndroidManifest
   - Write WorkoutType entries per session
   - Medium difficulty, Android 9+ / Health Connect app required
2. **Google Drive** — backup workout data as files (like GitHub sync but Drive)
   - Medium-hard: needs Google Cloud project, OAuth 2.0, SHA-1 fingerprint registration
   - `google_sign_in` + `googleapis` packages
3. **Firebase Firestore** — real-time cloud backup, multi-device sync
   - Medium: Firebase project setup, `cloud_firestore` package, generous free tier

#### Settings screen shows old text (minor)
- Frames 017/018 from the screen recording show "Import from Strong" (old text, now fixed to "Import data from CSV")
- Profile PR list (frames 015/019) shows "mock_98653233" style IDs from mock data — not ideal but not blocking

#### Obsidian vault path in Settings
- There is a tile for Obsidian Vault Path in Settings (functional, tap to configure)
- Not discussed this session but it's live in the app

### Personal Context
- Aneesh is shipping Gains to the Play Store — this is the main active project
- User prefers to run `flutter run` themselves rather than having Claude build/install (except this session where APK was explicitly requested for the website)
- User pushes to GitHub themselves or asks Claude to do it explicitly
- User's email: aneeshtickoo2002@gmail.com (used in bug report mailto)

### Next Actions (ordered)
1. **Run `flutter run`** and test all recent features:
   - Import data from CSV → pick `D:\strong4889393444804334205.csv` → verify ~200 sessions import
   - RPE picker — all 9 values visible on screen, no scroll
   - Settings → App: Sounds toggle, Keep screen on toggle
   - Settings → Support: Report a bug → opens email
   - Settings → Data: Reset all data (confirmation dialog)
   - New user banner on Workout tab (reset data first to see it)
2. **Play Store signing setup:**
   - `keytool -genkey -v -keystore gains-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gains`
   - Create `android/key.properties` with keystore path + passwords
   - Update `android/app/build.gradle.kts` with signingConfigs block
   - Rebuild APK, replace `docs/gains.apk`, push
3. **Health Connect integration** — next big feature after signing
4. **Google Drive sync** — after Health Connect
5. **Firebase Firestore** — after Drive
