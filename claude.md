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
- **Legal acceptance gate LIVE 2026-07-15 — DEVICE-VERIFIED iPhone + Android (incl. decline test on Pixel).** Full map: `docs/legal/LEGAL-IMPLEMENTATION.md`. Remaining: patient device, large-text pass; attorney review of `docs/legal/TERMS_OF_USE.md` (queue: `../legal/ATTORNEY-REVIEW-QUEUE.md`). Terms text changes REQUIRE bumping `kTermsVersion` in `lib/core/legal/legal_terms.dart`.
- **Cognition features — claims language (STANDING RULE)**: describe/market as "engagement & routine support" ONLY — never "improves memory/slows decline" (FTC/Lumosity $2M) and never clinical assessment/decline-detection framing (FDA SaMD line). Full policy + STTR upside: `docs/cognitive-engagement-research.md`. Applies to ALL in-app copy, store listings, notifications.
- Daily Activities library DEVICE-VERIFIED 2026-07-13 (iPhone + Pixel): add activity, patient popup+TTS, photo verify (custom camera, one-tap shutter), push notification to caregiver. Photo flow streamlined (was 4 taps, now 2). Call screen 9px overflow fixed. No deploy needed
- Vehicles + Social Media DEVICE-VERIFIED 2026-07-14 (Pixel + iPhone): add/edit/delete vehicle w/ photo upload, social media handle w/ auto-URL generation (known platforms), link opens in browser. Storage deployed. QuadTrack Share vehicles+social verified on iPhone (07-08). Auto-URL fix: empty URL + handle → generates facebook.com/handle etc.
- **QuadTrack LIVE (2026-07-08)** — core flow device-verified end-to-end incl. push w/ deep-links (see CHANGELOG). Geofence breach + phone-dead offline push DEVICE-VERIFIED 2026-07-15 (banners + deep-links). LE share DEVICE-VERIFIED 07-15 (SMS/clipboard/email; maps-link bug FIXED). New: email body loses line breaks (one paragraph); empty MEDICAL section shows orphan heading. Profile consolidation 07-15 (per Leon): QuadTrack wizard DELETED — tabbed User Profile is single owner; register/detail open it; Setup Guide gains core Patient-profile step; Bouncie vehicle autofill added (Vehicles tab). Wizard had DATA-LOSS bug (saves wiped vehicles/socialMediaLinks arrays) — gone with wizard; Jack's data restored. Remove device DEVICE-VERIFIED 07-15 (fixed: silent rules-abort + fire-and-forget dialog). Android pass 07-15 (Pixel): breach push + deep-link, LE share SMS end-to-end, legal gate accept/decline all DEVICE-VERIFIED; fixes: manifest `<queries>` (SMS was dead), share-screen rebuild loop, hybrid-composition maps. OPEN HIGH: memory/perf bug both platforms (GC churn, 40s stalls, EXC_RESOURCE ×2 — needs DevTools profiling; task has evidence). OPEN HIGH: invite doesn't grant QuadTrack access (Apple/Google UID split; needs CF sync). Remaining tests: Android offline push (same pipeline as breach — low risk), remove device, email path. Foreground FCM shows no banner (no in-app presentation) — consider surfacing
- Bouncie per-family linking DEVICE-VERIFIED 2026-07-12 (privacy ship-blocker closed; see CHANGELOG). Patient-switch state bugs fixed same day (ChangeNotifierProvider + addManagedUser dedupe) — device-verified
- Home environment monitoring (2026-07-13) — BLE path FULLY DEVICE-VERIFIED: HT.w read via patient phone, dashboard card (red tile on violation), threshold alert push received end-to-end (BLE→Firestore→`onEnvironmentReading`→FCM). Danger tier (≥95°F/≤50°F, bypasses alerts-off, 2h cooldown) in code — confirm deployed. Restore Jack's test threshold (max temp 75→85). 3 paths behind `environment_connections/{patientId}`: BLE bridge (`sensorpush_ble_bridge.dart`, splash USER mode only), SensorPush cloud API (needs G1 — untested), Nest SDM (needs secrets + Device Access reg $5 — untested; `pollEnvironment` NOT deployed). Remaining: 15-min cadence, BLE reconnect on range exit/return, alert cooldown behavior
- Pet feeding reminders DEVICE-VERIFIED 2026-07-14 (Pixel): add/edit/delete schedule, mark-fed, feeding history. Firestore rules already deployed. Also fixed reminder day-of-week bug (weekly/custom reminders fired daily — now uses per-weekday scheduling like pet feedings)
- Expense/reimbursement DEVICE-VERIFIED 2026-07-14 (Pixel): add/scan/approve/reimburse flow. Firestore rules + storage rules already deployed
- Apple sign-in VERIFIED iPhone; Google sign-in VERIFIED Android (Pixel 10 Pro XL). Android verified 07-12: fresh install → Google → dashboard, invite redeem (incl. share-all), Bouncie card, patient list. Remaining: OCR w/ Play services, full UI walk
- Multi-device caregivers use invite codes (Apple/Google = separate UIDs; relay email blocks linking). Share-all invite live. Subscription is per-caregiver-account — family entitlement task in Dev Planner
- Account deletion LIVE + device-verified 07-13 (Apple 5.1.1v closed). Critical Alerts entitlement pending w/ Apple (req 86H4R85YY3, daily watcher). Photo-verified tasks live (hash-match-first, AI fallback, caregiver override)
- App Check provider not installed (logcat spam, harmless until enforced) — backlog task in Dev Planner

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
