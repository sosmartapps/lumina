# Lumina - Development Changelog

<!-- Claude will automatically log completed work here. -->
<!-- Format: Date - Build Number - Summary heading, then bullet points of what changed. -->

## 2026-07-06 - Pet Feeding Reminders (NEEDS DEVICE TEST + FIREBASE DEPLOY)

- New self-contained feature under `lib/features/pet_feeding/`: schedule feeding times per pet with local notifications, mark-as-fed, and feeding history
- Model `lib/core/models/pet_feeding.dart`: `PetFeeding` (petName, PetType, foodType, amount, embedded `FeedingTime` list, `repeatDays` null=daily else weekdays 1-7, `lastFedAt`), `FeedingLog`, `PetType` enum (emoji + icon). Exported from models barrel
- Service `pet_feeding_service.dart` (+ `petFeedingServiceProvider`): CRUD on `pet_feedings`, `markFed` writes `feeding_logs` + bumps `lastFedAt`, history streams. Immediate (re)scheduling on create/update (updateFeeding cancels via *old* doc to avoid orphan notifications) + `scheduleAllFeedingNotifications` on boot
- NotificationService: added `pet_feeding_channel`, `schedulePetFeeding` (daily → `DateTimeComponents.time`; specific days → one repeating notif per weekday via `dayOfWeekAndTime`), `cancelPetFeeding` (deterministic ids), generic `scheduleNotification` now takes optional `matchComponents`
- UI: `ManagePetFeedingScreen` (add/edit/delete dialog with multiple feeding times + label, pet-type picker, every-day/weekday chips; per-pet card shows times, last-fed, next feeding, Mark Fed button) + `FeedingHistoryScreen` (grouped by day). Wired into caregiver dashboard Manage tab
- Boot scheduling hooked into splash_screen + user_home_screen (after reminder scheduling, since reminderService.scheduleAllNotifications calls cancelAll first)
- Firebase: `firestore.rules` for `pet_feedings` + `feeding_logs` (patient + caregivers r/w); 3 new indexes (pet_feedings userId+isActive; feeding_logs userId+fedAt desc; feeding_logs feedingId+fedAt desc). **Run `firebase deploy --only firestore` before shipping**

## 2026-07-06 - Device-Test Session: Firebase Live + UI Formatting Fixes

- Firebase config deployed for the first time (rules were deny-all defaults): firestore.rules, storage.rules (bucket created), 12 deduped indexes (queryScope case fixed, firebase.json now references firestore.indexes.json)
- Apple sign-in verified working on device end-to-end (caregiver doc created); Google configured (new plist w/ OAuth client + URL scheme)
- verify-auth harness PASS (analyze clean — all 30 pre-existing infos fixed incl. purchasePackage→purchase(PurchaseParams) and onReorder→onReorderItem migrations, both need functional retest when touched)
- Setup flow: keyboard now dismissed on page change; permissions page scrollable (CTA was hidden behind stuck keyboard)
- Patient home: 2×3 no-scroll tile layout (all actions visible — accessibility requirement), tiles auto-fit via Flexible/FittedBox, greeting scales instead of word-per-line wrap
- Expense flow verified on device: receipt scan → OCR pre-fill (real medical statement: merchant/date extracted) → submit → detail screen w/ role-gated actions
- **New blanket policy**: memory/workflows/ui-formatting-checklist.md — mandatory visual walk of every touched screen, referenced from root CLAUDE.md

## 2026-07-03 - Apple + Google Sign-In for Caregivers (NEEDS CONSOLE CONFIG + DEVICE TEST)

- Wired shared `ssa_auth` package (../packages/ssa_auth) into AuthService: `signInWithApple()` / `signInWithGoogle()` with `_ensureCaregiverProfile` (creates caregivers doc on first OAuth sign-in from provider displayName/email, else bumps lastLoginAt)
- "Continue with Apple/Google" buttons on setup_screen (all 3 auth modes — invite code redeemed after OAuth too; refactored shared post-auth into `_afterCaregiverAuthed`) and caregiver_login_screen (`_completeLogin` extracted); user-cancel doesn't show error banner
- `GoogleSignIn.instance.initialize()` added to post-boot steps (v7 requirement); Apple entitlement added to Runner.entitlements + CODE_SIGN_ENTITLEMENTS wired into all 3 Runner build configs (was only on ShareFeedbackExtension)
- Auth-verify harness installed (integration_test/auth_verify_test.dart) — run `bash scripts/verify-auth.sh lumina`
- **Remaining config:** enable Apple + Google providers in Firebase console (lumina-sosmartapps); re-download GoogleService-Info.plist (currently has NO CLIENT_ID/REVERSED_CLIENT_ID) + google-services.json; add REVERSED_CLIENT_ID URL scheme to Info.plist; Android needs serverClientId in GoogleSignIn.initialize

## 2026-07-03 - Fixed Black Screen at Launch (root cause)

- **Root cause:** `ios/Runner/SceneDelegate.swift` existed on disk but was never added to `project.pbxproj` (missed during the 2025-12 UIScene migration). iOS couldn't resolve `UISceneDelegateClassName: Runner.SceneDelegate`, created the scene with no delegate → no window → solid black screen while the Dart VM ran invisibly. Diagnosed by confirming the class was absent from the built `Runner.debug.dylib` (`strings` showed ScreenshotDetector but no SceneDelegate).
- **Fix:** added SceneDelegate.swift to pbxproj (BuildFile + FileReference + group + Sources phase).
- **Hardening:** restructured `main()` — only dotenv + Firebase.initializeApp + crash-handler wiring run before `runApp()`; bug reporter, notifications, background service, anonymous auth, deep links now run post-first-frame, each try/caught and 15s-timeboxed with `BOOT:` logs. A hung plugin can never black-screen boot again. SplashScreen awaits `bootReady` so Firestore reads don't race anonymous auth.

## 2026-07-03 - App Icon Created

- Replaced default Flutter icon with Lumina brand icon (guiding-light lantern per claude-design-system.md: Lumina Blue bg #1565C0→#0D47A1, warm glow #F2B137/#FFD97A, white ring + base)
- Master SVG + 1024 PNG: `assets/branding/lumina-icon{.svg,-1024.png}`
- Generated all 15 iOS appiconset sizes (RGB, no alpha — App Store safe) + 5 Android mipmap ic_launcher sizes
- Verified visually at 1024px and 120px

## 2026-07-03 - Expense & Reimbursement Tracking (NEEDS DEVICE TEST)

**New feature: family caregiver expense reimbursement**
- `lib/core/models/expense.dart` — Expense model with lifecycle submitted → approved/rejected → reimbursed; categories, receipt URLs, full approval + payment audit trail (who/when/method/note)
- `CaregiverRole.financeManager` added to caregiver.dart (assignable per-patient via roleOverrides); approval rights = financeManager OR primary caregiver fallback (`ExpenseService.canManageFinances`)
- `lib/core/services/expense_service.dart` — CRUD, status transitions, receipt upload to Storage `expense_receipts/{patientId}/`, owed-balance helpers
- `lib/core/services/receipt_scan_service.dart` — on-device ML Kit OCR (same stack as prescription scan) pre-fills amount/merchant/date from receipt photo; manual edit always available
- Screens: `manage_expenses_screen.dart` (list, status filters, pending/owed summary), `add_expense_screen.dart` (photo → OCR → form), `expense_detail_screen.dart` (role-gated approve/reject/mark-reimbursed, receipt viewer)
- Wired into caregiver dashboard Manage tab; providers registered in providers.dart
- Firebase surfaces (pre-flight done): firestore.rules `expenses` block, storage.rules `expense_receipts` block, 2 composite indexes in firestore.indexes.json
- Deploy: `firebase deploy --only firestore,storage`
- **Not verified on device** — OCR parsing, photo upload, and approve/reimburse flow need device test on Leon's iPhone

## 2026-03-21 - Infrastructure & Deployment Readiness

**Firestore Composite Indexes:**
- Created `firestore.indexes.json` with 12 composite indexes required by production queries
- Covers reminders (userId + isActive + scheduledTime), geofence events (userId + timestamp), quadtrack pings/emergencies, invite codes, and location history
- Deploy with: `firebase deploy --only firestore:indexes`

**Bouncie Vehicle Tracking Webhook:**
- Added `bouncieWebhook` Cloud Function to handle vehicle location mismatch alerts from geofence service
- Stores alerts in `bouncie_alerts` collection and notifies caregivers via notifications collection
- Configured webhook URL in geofence_service.dart: `https://us-central1-lumina-sosmartapps.cloudfunctions.net/bouncieWebhook`

**NotificationService Error Handling:**
- Fixed `notifyCaregivers()` to handle missing or null user documents gracefully
- Added null checks on both user and caregiver docs, wraps in try-catch, logs errors instead of crashing
- Prevents notification failures from blocking other operations

**Widget Tests:**
- Created `test/features/user_home_screen_test.dart` (6 tests) — verifies rendering, theme colors, accessibility-focused UI
- Created `test/features/caregiver_dashboard_screen_test.dart` (6 tests) — verifies dashboard navigation, app bar, theme colors
- Tests are placeholder-level (don't mock Firebase) to verify basic rendering without setup complexity

**QuadTrack Emergency Mode & UI Verification:**
- Verified emergency mode activation is fully wired: updateTrackingMode() writes commands, notifies caregivers
- Confirmed caregiver dashboard includes QuadTrackDashboardScreen with device status display
- activeEmergencyProvider in quadtrack_provider.dart streams active emergency state to UI

## 2026-03-20 - Development Push: Tests, Bug Fixes, Code Audit

**Test Suite Created (11 test files, ~2,100 lines):**
- Unit tests for all 9 core models: AppUser, Reminder, Medication, GeoZone, Caregiver, Subscription, HealthProfile, Prescription, InviteCode
- Tests cover: serialization/toFirestore, fromMap roundtrips, copyWith, enum parsing, default values, business logic (subscription feature gates, prescription refill calculations, invite code validity, reminder homeOnly defaults, spoken message substitution)
- SunsetCalculator tests: sunrise/sunset for Tucson across seasons, polar edge cases
- SundownService tests: travel mode detection logic, alert level threshold verification

**Bug Fixes (3 critical, 1 moderate):**
- **Fixed**: `getTodayReminders()` now correctly shows recurring daily/weekly/custom reminders (was filtering by scheduledTime date range, hiding all recurring reminders after creation day)
- **Fixed**: `snoozeReminder()` no longer permanently shifts recurring reminder times (now uses lastTriggeredAt instead of modifying scheduledTime)
- **Fixed**: `AuthService._handleAuthException()` now throws typed `AuthException` instead of raw String (enables proper catch blocks)
- **Fixed**: Added 30-second debounce to location writes (was writing every ~8 seconds for walking users, excessive Firestore costs)

**Code Audit Report:**
- Created `CODE_AUDIT_2026_03_20.md` documenting 9 issues found across services
- Architecture rated as well-structured with clean Riverpod 3 migration
- Security (PIN hashing, Firestore rules) and accessibility patterns confirmed solid

## 2026-02-01 - v1.0.0+1 - Project Setup

- Extracted lumina_app.zip and screenshot_feedback_package.zip
- Set up Flutter project structure
- Screenshot feedback service integrated into main app
- Created CLAUDE.md for development tracking

**Architecture decisions established:**
- Provider + Riverpod for state management (simple, reactive UI)
- Firebase for backend (real-time sync, offline support, easy auth)
- Large tiles in 2-column grid (accessibility for cognitive impairment)
- High contrast colors (better visibility for older users)
- Portrait-only mode (simpler, less disorienting)
- Hidden caregiver access via 5-tap header (clean UI for users, full control for caregivers)

**Key features implemented:**
- User: Large action tiles, one-tap navigation, quick call, voice prompts, full-screen reminders, no login required
- Caregiver: Secure hidden login, real-time location, geofencing, medical profile, prescription tracking, remote management, app protection (kiosk mode)

## 2026-02-05 - CI Fix: firebase_options.dart stub

- `firebase_options.dart` is gitignored (contains API keys) but CI needs it for `flutter analyze`
- Added a step in `daily-doctor.yml` that generates a stub with dummy values before analysis

## 2026-02-19 - Major Dependency Upgrade & Riverpod 3 Migration

**SDK & Dependencies:**
- Dart SDK constraint updated to `>=3.7.0 <4.0.0`
- Ran `dart fix --apply` and `flutter pub upgrade --major-versions` (25 packages upgraded)
- Ran `flutterfire configure` for Firebase project `lumina-sosmartapps`

**Package changes:**
- Removed `provider`, added `flutter_riverpod:^3.2.1`
- Removed `awesome_notifications`, kept `flutter_local_notifications:^21.0.0-dev.1`
- Added `firebase_crashlytics:^5.0.7`, `firebase_analytics:^12.1.2`, `firebase_ai:^3.8.0`
- Upgraded `geolocator` to `^14.0.2`

**Riverpod 3 migration (provider → flutter_riverpod):**
- Created central `lib/core/providers/providers.dart` with all Riverpod provider definitions
- Replaced `MultiProvider` in main.dart with `ProviderScope`
- Migrated 15+ screens from `Provider.of<T>()` to `ref.read()` + `ListenableBuilder`
- Pattern: `Provider<T>` for DI, `ListenableBuilder` for reactive ChangeNotifier rebuilds

**API fixes:**
- flutter_local_notifications v21: all positional params → named (`settings:`, `id:`, `title:`, `body:`, etc.), removed `uiLocalNotificationDateInterpretation`
- geolocator v14: `desiredAccuracy` → `locationSettings: LocationSettings(accuracy:)`
- share_plus: `Share.share()` → `SharePlus.instance.share(ShareParams(...))`

**Result:** `flutter analyze` passes with 0 issues.

## 2026-02-05 - Security Hardening & Geofence Fix

**Firestore rules — closed unauthenticated write holes:**
- Replaced `allow create: if true` with `allow create: if isAuthenticated()` on `location_updates`, `medication_logs`, `geo_zone_events`
- Added anonymous Firebase Auth sign-in in `main.dart` so patient devices satisfy `isAuthenticated()` without a login screen

**Caregiver PIN — replaced weak hash with proper crypto:**
- Replaced trivial bit-shift hash with SHA-256 + random 32-byte salt (`package:crypto`)
- Added rate limiting: 5 max attempts, 15-minute lockout (tracked in Firestore)
- Legacy hash preserved for backwards-compatible migration

**Geofence alerts — connected the missing notification delivery:**
- `NotificationService.notifyCaregivers()` writes to `notifications` collection, but no Cloud Function was processing it
- Added `deliverPushNotification` Cloud Function (`functions/src/index.ts`) that triggers on `notifications/{id}` creates, sends FCM push, and marks delivered/failed

**CLAUDE.md restructure:**
- Replaced verbose CLAUDE.md (220 lines) with lean template (60 lines)
- Created CHANGELOG.md for development history tracking
- Applied claude-project-template for better context management
