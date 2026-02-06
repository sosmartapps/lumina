# Lumina - Development Changelog

<!-- Claude will automatically log completed work here. -->
<!-- Format: Date - Build Number - Summary heading, then bullet points of what changed. -->

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
