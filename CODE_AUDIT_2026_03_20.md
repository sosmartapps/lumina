# Lumina Code Audit — 2026-03-20

## Critical Issues

### 1. `ReminderService.snoozeReminder()` permanently shifts recurring reminder time
**File**: `lib/core/services/reminder_service.dart:98-111`
**Severity**: High — breaks recurring reminders after first snooze
**Problem**: When a user snoozes a reminder, the `scheduledTime` is permanently updated in Firestore. For a recurring daily reminder at 8:00 AM, snoozing 10 minutes changes it to 8:10 AM *forever*, not just for today.
**Fix**: Track snooze separately (`snoozedUntil` field) or reset `scheduledTime` when the reminder is completed.

### 2. `ReminderService.getTodayReminders()` won't show recurring reminders after day 1
**File**: `lib/core/services/reminder_service.dart:70-86`
**Severity**: High — daily reminders disappear after their creation day
**Problem**: Query filters `scheduledTime` within today's date range, but recurring reminders keep their original `scheduledTime` from the day they were created. After that day, they no longer match the query.
**Fix**: Either update `scheduledTime` at end of day for recurring reminders, or change the query to filter by time-of-day only for recurring reminders, or use a separate `nextTriggerTime` field.

### 3. `AuthService._handleAuthException()` throws a String instead of an Exception
**File**: `lib/core/services/auth_service.dart:264-285`
**Severity**: Medium — `catch (e)` blocks may not work as expected
**Problem**: The method returns `String`, and callers do `throw _handleAuthException(e)`. This throws a raw String, which doesn't match `catch (FirebaseAuthException)` patterns and won't carry a stack trace.
**Fix**: Return a custom exception class or throw `Exception(message)`.

## Moderate Issues

### 4. `GeofenceServiceWrapper._checkVehicleSync()` has hardcoded empty webhook URL
**File**: `lib/core/services/geofence_service.dart:163`
**Severity**: Low — webhook alerts for Bouncie won't deliver
**Note**: `caregiverWebhookUrl: ''` is hardcoded. Should come from user/caregiver settings.

### 5. `NotificationService.notifyCaregivers()` no error handling for missing user doc
**File**: `lib/core/services/notification_service.dart:341-367`
**Severity**: Medium — will throw if user doc doesn't exist
**Problem**: `userDoc.data()` can return null if the document doesn't exist, and the `?['caregiverIds']` handles that, but this silently fails with no logging.

### 6. No rate limiting on location writes
**File**: `lib/core/services/location_service.dart:113-141`
**Severity**: Low-Medium — excessive Firestore writes for walking users
**Problem**: With a 10m distance filter, a walking user generates a write roughly every 8 seconds. At $0.18/100K writes, this could cost $0.10+/hour per active user.
**Suggestion**: Add a time-based debounce (e.g., write at most once per 30-60 seconds).

## Minor Issues / Suggestions

### 7. `Prescription.daysUntilRefillNeeded` handles `daysSupply=0` gracefully (returns 0)
No action needed — Dart's division produces infinity, which resolves to 0 days (correct as "overdue").

### 8. No Firestore composite index file
**Problem**: Several queries require composite indexes (e.g., `getMedicationLogs` with `userId` + `scheduledTime` + optional filters). Without `firestore.indexes.json`, these will fail on first run.
**Fix**: Generate indexes with `firebase deploy` or manually create `firestore.indexes.json`.

### 9. Several models use `DateTime.now()` as default in constructors
**Note**: This makes tests time-dependent. Consider injecting a clock for testability, or accept it since these are data models.

## Code Quality Observations

- **Well-structured**: Clean separation between models, services, providers, and features
- **Good error handling**: Most services wrap Firestore calls in try/catch with debugPrint
- **Riverpod 3 migration**: Clean, no leftover Provider references
- **Security**: PIN hashing with SHA-256+salt is solid; Firestore rules require auth
- **Accessibility**: Large tiles, TTS, high-contrast — all well-considered for the target audience
