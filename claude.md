# Lumina

## Maintenance Rules (follow these every session)
- **Keep this file under 60 lines.** It loads into every conversation's context.
- **Do NOT add build history or accomplishments here.** Log them in [CHANGELOG.md](CHANGELOG.md) instead.
- When a task from "Remaining Work" is completed, remove it from here and log it in CHANGELOG.md.
- When a new active issue is found, replace or add it concisely. Remove resolved issues.
- Update the build version line when a new build is made.
- If this file is growing past 60 lines, trim aggressively — details belong in CHANGELOG.md.

## Current Build
- **Version**: 1.0.0+1 (2026-02-01)
- **Package**: `com.carecompanion.app`
- **Framework**: Flutter 3.2+ / Dart 3.0+
- **History**: See [CHANGELOG.md](CHANGELOG.md)

## Active Issues
- **QuadTrack LIVE (2026-07-08)** — core flow device-verified end-to-end incl. push w/ deep-links (see CHANGELOG). Remaining tests: geofence breach push, phone-dead escalation, LE share screen, profile wizard, remove device, Android
- **Bouncie redirect now https://sosmartapps.app/bouncie (2026-07-08)** — hosted copy-code page live; all 6 secrets created (Twilio blank), full functions deploy WORKS. Reconnect vehicle via new flow + device test pending
- Bouncie per-family linking BUILT 2026-07-07 (ship-blocker fix; Manage → Vehicle Tracking) — needs `firebase deploy --only firestore` + device test: reconnect via new flow (paste .env BOUNCIE_AUTH_CODE), verify card hides for unlinked patients
- Pet feeding reminders (2026-07-06) built but NOT device-tested — test add/edit/delete schedule, mark-fed, notifications fire, history; then `firebase deploy --only firestore`
- Expense/reimbursement feature (2026-07-03) built but NOT device-tested — test add/scan/approve/reimburse flow, then deploy `firebase deploy --only firestore,storage`
- Apple sign-in VERIFIED on iPhone; Google configured both platforms (untested). Android: never run on device/emulator — needs full pass (Google sign-in, OCR w/ Play services, UI walk)

## Remaining Work
- Configure Firebase project
- Add Google Maps API keys
- Run `flutter pub get` to install dependencies
- Test on iOS/Android simulator
- Review and test all features

## Architecture

### Patterns
- **State**: Provider + Riverpod
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **Maps**: Google Maps SDK
- **TTS**: `flutter_tts` for voice prompts
- **Theme**: High-contrast, accessibility-focused, portrait-only
- **Auth**: Anonymous for patients, email/phone for caregivers
- **Caregiver access**: Hidden 5-tap header, PIN w/ SHA-256+salt, rate-limited

### Key Files
- Entry point: `lib/main.dart`
- User home: `lib/features/user_home/user_home_screen.dart`
- Theme/colors: `lib/core/theme/app_theme.dart`
- Auth: `lib/core/services/auth_service.dart`
- User model: `lib/core/models/app_user.dart`
- Firestore rules: `firestore.rules`
- Models: `lib/core/models/`
- Services: `lib/core/services/`
- Caregiver screens: `lib/features/caregiver/`

### API Keys / Secrets
- Firebase config: `lib/firebase_options.dart`
- Google Maps keys: stored in platform-specific configs (Android/iOS)
- All secrets should be gitignored, not committed

### Firebase Collections
- `users`, `caregivers`, `reminders`, `medications`, `geo_zones`, `feedback`, `notifications`, `pet_feedings`, `feeding_logs`
- Location history: `users/{id}/location_updates`

### Commands
- Install: `flutter pub get` | Run: `flutter run`
- Build: `flutter build apk --release` | `flutter build ios --release`
- Deploy: `firebase deploy --only functions` | `firebase deploy --only firestore:rules`

## Dev Task Tracking
- **All dev tasks tracked in Firebase Dev Tracker** (https://ssa-dev-tracker.web.app), NOT Notion.
- Firestore: `dev_tasks` collection in project `ssa-bug-dashboard`.
- No Firebase auth needed — scripts call the Cloud Functions HTTP API directly.
- Mark done: `node ../dev-tracker/mark-done.js --app "Lumina" --title "keyword"`
- List tasks: `node ../dev-tracker/mark-done.js --list`
- After completing work, always mark the relevant task done.
- **IMPORTANT — Mirror all tasks to SSA Dev Planner**: Any new tasks/todos MUST also be added to `dev_tasks` via Firestore REST API. POST to `https://firestore.googleapis.com/v1/projects/ssa-bug-dashboard/databases/(default)/documents/dev_tasks` with fields: title, appName, type, priority, status, description. This is Leon's primary task board.
## Crash reporting
- Firebase project: `lumina-sosmartapps` · bundle `com.carecompanion.lumina`
- Live crashes (open in browser to read stack traces): https://console.firebase.google.com/project/lumina-sosmartapps/crashlytics/app/ios:com.carecompanion.lumina/issues
- Status: wired 06-22 (build to activate). Fleet registry: `memory/crash-reporting-registry.md` · rollout: `memory/workflows/crash-reporting-rollout.md`
