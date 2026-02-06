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
<!-- None currently tracked -->

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
- `users`, `caregivers`, `reminders`, `medications`, `geo_zones`, `feedback`, `notifications`
- Location history: `users/{id}/location_updates`

### Commands
- Install: `flutter pub get` | Run: `flutter run`
- Build: `flutter build apk --release` | `flutter build ios --release`
- Deploy: `firebase deploy --only functions` | `firebase deploy --only firestore:rules`
