# Lumina - Development Changelog

<!-- Claude will automatically log completed work here. -->
<!-- Format: Date - Build Number - Summary heading, then bullet points of what changed. -->

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
