# Lumina Beta Testing Checklist
Quick Reference - Detailed test cases in BETA_TEST_PLAN.md

**Version**: 1.0.0 | **Date**: 2026-02-24 | **Status**: Active

---

## Pre-Testing Setup
- [ ] Test Firebase project configured (auth, Firestore, Storage, Messaging)
- [ ] Google Maps API keys added (iOS & Android)
- [ ] Test caregiver account created: `test.caregiver@example.com`
- [ ] Test patient profile created in Firestore
- [ ] TestFlight build uploaded (iOS) / Google Play Console beta uploaded (Android)
- [ ] Testers added to beta programs
- [ ] Test devices prepared (iOS 14+, Android 9+)
- [ ] Crash reporting configured (Crashlytics or alternative)
- [ ] Bug tracking system ready (Jira, Firebase Tracker, or similar)

---

## Phase 1: Core Flows (Days 1-2)

### Authentication & Setup
- [ ] TC-AUTH-001: Splash screen displays correctly
- [ ] TC-AUTH-002: Initial setup flow completes (patient name entry, preferences)
- [ ] TC-AUTH-003: Caregiver access triggered by 5-tap header
- [ ] TC-AUTH-004: PIN entry works on first caregiver login
- [ ] TC-AUTH-005: Anonymous auth succeeds silently on first launch
- [ ] TC-AUTH-006: Session persists after app restart

### User Home & Navigation
- [ ] TC-HOME-001: User home renders with large, visible tiles
- [ ] TC-HOME-002: One-tap home navigation opens Google Maps correctly
- [ ] TC-HOME-003: TTS welcome message plays on app launch
- [ ] TC-HOME-004: Portrait orientation locked throughout app
- [ ] TC-HOME-005: All tap targets >= 48dp (verified with dev tools)

### Critical Navigation
- [ ] TC-HOME-001: All tiles tappable and functional (home, contacts, reminders, medical)
- [ ] App does not crash on tile navigation
- [ ] Back button/gesture works correctly
- [ ] Navigation state preserved across backgrounding

---

## Phase 2: Features (Days 3-4)

### Contacts
- [ ] TC-CONTACTS-001: View emergency contacts list
- [ ] TC-CONTACTS-002: One-tap call initiates dialing
- [ ] TC-CONTACTS-003: Caregiver can add new contact
- [ ] TC-CONTACTS-004: Caregiver can delete contact
- [ ] TC-CONTACTS-005: Contact images display (if set)

### Medications
- [ ] TC-MED-001: View medications list
- [ ] TC-MED-002: Medication reminder popup appears at scheduled time
- [ ] TC-MED-002b: TTS announces medication (app in background)
- [ ] TC-MED-003: Photo verification available in reminder popup
- [ ] TC-MED-004: Refill threshold triggers caregiver alert
- [ ] TC-MED-005: Caregiver can add new medication
- [ ] TC-MED-006: Caregiver can edit medication schedule
- [ ] TC-MED-007: Prescription scan (OCR) extracts text correctly

### Reminders
- [ ] TC-REM-001: View all reminders list
- [ ] TC-REM-002: Task reminder notification appears and TTS plays
- [ ] TC-REM-003: Appointment reminders include location/time
- [ ] TC-REM-004: Hydration reminders trigger at configured intervals
- [ ] TC-REM-005: Caregiver can create new reminder
- [ ] TC-REM-006: Snooze functionality works (if available)
- [ ] TC-REM-007: Dismiss removes reminder without reappearing

### Medical Records
- [ ] TC-MED-REC-001: View medical profile (conditions, allergies, providers)
- [ ] TC-MED-REC-002: Caregiver can add health condition
- [ ] TC-MED-REC-003: Caregiver can add allergy (severity color-coded)
- [ ] TC-MED-REC-004: Caregiver can add healthcare provider
- [ ] TC-MED-REC-005: Medical summary PDF generates and shareable
- [ ] TC-MED-REC-006: Insurance information stored securely
- [ ] TC-MED-REC-007: Emergency notes added and included in summary

---

## Phase 3: Caregiver Features & Location (Days 5-6)

### Navigation & Maps
- [ ] TC-NAV-001: Google Maps loads and displays current location
- [ ] TC-NAV-002: Navigate to home works with proper directions
- [ ] TC-NAV-003: Navigate to saved locations works
- [ ] TC-NAV-004: Caregiver can add new saved location
- [ ] TC-NAV-005: Real-time location tracking shows user position (with permissions)
- [ ] TC-NAV-006: Location history viewable with timeline

### Geofencing
- [ ] TC-GEO-001: Caregiver can create safe zones on map
- [ ] TC-GEO-002: Exit safe zone triggers alert to caregiver
- [ ] TC-GEO-003: Enter danger zone triggers alert to caregiver
- [ ] TC-GEO-004: Geofence accuracy acceptable (no false positives)
- [ ] TC-GEO-005: Multiple zones monitored simultaneously

### Caregiver Dashboard
- [ ] TC-CG-001: Caregiver login with email/password
- [ ] TC-CG-002: Caregiver dashboard displays patient info, location, activity
- [ ] TC-CG-003: PIN protection enforced for settings changes
- [ ] TC-CG-004: Multiple caregivers can be invited
- [ ] TC-CG-005: Caregiver removal revokes access
- [ ] TC-CG-006: Caregiver can edit patient profile

### App Protection
- [ ] TC-APP-PROT-001: Android device admin prevents uninstall
- [ ] TC-APP-PROT-002: Android kiosk mode locks device to app
- [ ] TC-APP-PROT-003: Android screen pinning works
- [ ] TC-APP-PROT-004: iOS Guided Access documented for caregiver
- [ ] TC-APP-PROT-005: iOS Screen Time restrictions documented
- [ ] TC-APP-PROT-006: PIN required to disable any protection

---

## Phase 4: Accessibility, Firebase, & Edge Cases (Days 7-8)

### Push Notifications
- [ ] TC-NOTIF-001: Notification permission request appears
- [ ] TC-NOTIF-002: Medication reminder push delivers (app backgrounded)
- [ ] TC-NOTIF-003: Geofence exit alert delivered to caregiver
- [ ] TC-NOTIF-004: Sundown alert delivered (if applicable)
- [ ] TC-NOTIF-005: Notification clears properly
- [ ] TC-NOTIF-006: Do Not Disturb / Focus mode respected

### Accessibility
- [ ] TC-A11Y-001: Text scales to max size without breaking layout
- [ ] TC-A11Y-002: High contrast mode works (iOS/Android)
- [ ] TC-A11Y-003: VoiceOver/TalkBack can navigate all screens
- [ ] TC-A11Y-004: All tap targets >= 48dp measured and verified
- [ ] TC-A11Y-005: Color contrast meets WCAG AA (4.5:1 for normal text)
- [ ] TC-A11Y-006: TTS speed adjustable
- [ ] TC-A11Y-007: Haptic feedback works on user actions
- [ ] TC-A11Y-008: Sound effects can be disabled

### Firebase Integration
- [ ] TC-FB-001: Anonymous auth works on fresh install
- [ ] TC-FB-002: Firestore read operations (user data) working
- [ ] TC-FB-003: Firestore write operations (save reminder) working
- [ ] TC-FB-004: Cloud Storage upload (photos) working
- [ ] TC-FB-005: Subcollections (medications) queried correctly
- [ ] TC-FB-006: Cloud Messaging push notifications deliver
- [ ] TC-FB-007: Offline support (cached data readable offline)
- [ ] TC-FB-008: Firebase Analytics events logged

### Offline & Network Resilience
- [ ] TC-OFFLINE-001: Offline mode detected and indicated
- [ ] TC-OFFLINE-002: Cached data viewable when offline
- [ ] TC-OFFLINE-003: Queued writes sync when online
- [ ] TC-OFFLINE-004: Network errors handled gracefully (no crash)
- [ ] TC-OFFLINE-005: Background service continues offline

### Performance
- [ ] TC-PERF-001: App startup time < 3 seconds (average)
- [ ] TC-PERF-002: Memory usage < 100 MB normal, < 150 MB peak
- [ ] TC-PERF-003: Battery drain < 10% per hour (with background location)
- [ ] TC-PERF-004: Large reminder list scrolls smoothly (60 FPS)
- [ ] TC-PERF-005: Maps/location history renders smoothly
- [ ] TC-PERF-006: TTS starts within 1 second (speech onset)

### Sundown Syndrome (If Applicable)
- [ ] TC-SUNDOWN-001: Sundown alert triggers at configured time
- [ ] TC-SUNDOWN-002: Caregiver can configure sundown settings
- [ ] TC-SUNDOWN-003: De-escalation tips shown to caregiver

### Edge Cases & Stress Testing
- [ ] TC-EDGE-001: App works with no permissions granted
- [ ] TC-EDGE-002: Low device storage handled gracefully
- [ ] TC-EDGE-003: Low battery mode doesn't break core features
- [ ] TC-EDGE-004: Very long text (medication name) wraps correctly
- [ ] TC-EDGE-005: 5+ simultaneous reminders queue properly
- [ ] TC-EDGE-006: Rapid screen navigation doesn't crash
- [ ] TC-EDGE-007: Rapid caregiver login attempts rate-limited
- [ ] TC-EDGE-008: Empty states (no reminders, contacts) display properly
- [ ] TC-EDGE-009: Non-ASCII text (emoji, accents) handled
- [ ] TC-EDGE-010: Rapid app backgrounding/foregrounding stable

### Bouncie/Vehicle Features (If Applicable)
- [ ] TC-BOUNCIE-001: Vehicle status displays correctly
- [ ] TC-BOUNCIE-002: Trip history viewable

---

## Platform-Specific Verification

### iOS (iPhone 13, 14, 15; iOS 17, 18)
- [ ] All test cases executed on at least 2 iOS devices
- [ ] TestFlight build installed and tested
- [ ] No crashes in Xcode console
- [ ] Background location permission working
- [ ] Local notifications (reminders) delivering
- [ ] Cloud Messaging (APNs) notifications working
- [ ] Portrait orientation enforced
- [ ] Safe area/notch handled correctly

### Android (Pixel 6/7, Galaxy A53; Android 13, 14, 15)
- [ ] All test cases executed on at least 2 Android devices
- [ ] Google Play beta build installed and tested
- [ ] No crashes in Android Studio logcat
- [ ] Background location permission working
- [ ] Local notifications (reminders) delivering
- [ ] Cloud Messaging (FCM) notifications working
- [ ] Portrait orientation enforced
- [ ] Device admin (if enabled) working
- [ ] Kiosk mode (if enabled) working

### Tablets (iPad 10th gen, Samsung Galaxy Tab)
- [ ] Layouts adapt to larger screen
- [ ] Portrait orientation enforced
- [ ] Large buttons/tiles remain usable
- [ ] No horizontal scrolling needed
- [ ] Maps visible and usable

---

## Bug Tracking

### P0 Bugs (Critical - Blocking Release)
- [ ] 0 remaining at release

**If P0 bugs exist, list them**:
1. [DESCRIPTION]
2. [DESCRIPTION]

### P1 Bugs (High Priority)
- [ ] Fixed or deferred with justification

**If P1 bugs deferred, document justification**:
1. [BUG]: [JUSTIFICATION]
2. [BUG]: [JUSTIFICATION]

### P2/P3 Bugs (Medium/Low)
- [ ] Documented for post-release
- [ ] Not blocking App Store submission

---

## Quality Assurance Sign-Off

### Feature Completeness
- [ ] All core features implemented and tested
- [ ] All caregiver features working
- [ ] All accessibility features working
- [ ] All integrations (Firebase, Maps, TTS) functional

### Quality Standards
- [ ] 0 P0 bugs remaining
- [ ] P1 bugs fixed or deferred with justification
- [ ] Accessibility WCAG 2.1 AA compliance verified
- [ ] Performance targets met (startup <3s, memory <100 MB, 60 FPS)
- [ ] No crashes in 8+ hour testing sessions
- [ ] All network conditions tested (online, offline, poor connection)
- [ ] All device types tested

### Documentation
- [ ] All test cases executed and documented
- [ ] All bugs logged with reproduction steps
- [ ] Test summary completed
- [ ] Release notes prepared
- [ ] Known issues documented (if any)

### Final Release Approval
**Product Manager**: _________________ Date: _______

**QA Lead**: _________________ Date: _______

**Engineering Lead**: _________________ Date: _______

**Release Approved**: [ ] YES [ ] NO

---

## Testing Notes Template

### Day 1 Notes
- Tester: _____________
- Devices tested: _____________
- Test cases completed: _____ / [TOTAL]
- Bugs found: _____
- Issues to investigate: _____________

### Day 2 Notes
- Tester: _____________
- Devices tested: _____________
- Test cases completed: _____ / [TOTAL]
- Bugs found: _____
- Issues to investigate: _____________

[Continue for each day...]

---

## Key Contact Information

**QA Lead**: [NAME] - [EMAIL] - [PHONE]

**Product Manager**: [NAME] - [EMAIL] - [PHONE]

**Engineering Lead**: [NAME] - [EMAIL] - [PHONE]

**Firebase Admin**: [NAME] - [EMAIL]

**Bug Tracking System**: [URL]

**Test Device Pool Manager**: [NAME] - [EMAIL]

---

## Related Documents
- Full Test Plan: `BETA_TEST_PLAN.md`
- Bug Tracking: [LINK TO BUG SYSTEM]
- Firebase Project: [FIREBASE CONSOLE LINK]
- App Store Submission Info: `APP_STORE_METADATA.md`
- Previous Releases: `CHANGELOG.md`

---

**Last Updated**: 2026-02-24
**Next Review**: After major feature additions or platform updates
