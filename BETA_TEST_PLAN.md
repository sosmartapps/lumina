# Lumina Beta Testing Plan

## Document Control
- **Version**: 1.0.0
- **Date Created**: 2026-02-24
- **Last Updated**: 2026-02-24
- **Status**: Active
- **App Version**: 1.0.0+1

---

## 1. Test Overview

### Purpose
Comprehensive beta testing of Lumina — an Alzheimer's care management app supporting patients and caregivers. This plan ensures all features, accessibility requirements, and critical paths function correctly before App Store submission.

### Scope
- **In Scope**: All features across iOS/Android, Firebase integration, accessibility, push notifications, offline behavior, maps, location services, medical records, medication management
- **Out of Scope**: Production server load testing, security penetration testing (separate engagement), localization beyond English
- **Platforms**: iOS 14.0+, Android 9+
- **Environment**: TestFlight (iOS), Google Play Console (Android), emulator/device testing

### Success Criteria
- Zero P0 bugs at release
- All features functional on target iOS/Android versions
- Accessibility standards met (WCAG 2.1 AA minimum)
- <3 second app startup time
- All Firebase integrations functioning
- Push notifications delivering reliably
- No crashes in 8+ hour testing sessions

### Testing Timeline
- **Phase 1** (Days 1-2): Core flows, authentication, navigation
- **Phase 2** (Days 3-4): Feature-specific testing, medication, reminders, contacts
- **Phase 3** (Days 5-6): Caregiver access, medical records, geofencing
- **Phase 4** (Days 7-8): Accessibility, edge cases, performance, stress testing
- **Total Duration**: 8 days minimum

---

## 2. Device Matrix

### iOS Testing Devices
| Device Model | iOS Version | Device Type | Priority |
|---|---|---|---|
| iPhone 13 | 17.x | Standard | P0 |
| iPhone 14 | 18.x | Standard | P0 |
| iPhone 15 | 18.x | Latest | P0 |
| iPhone SE (2nd gen) | 17.x | Small screen | P1 |
| iPhone 12 Mini | 17.x | Small screen | P1 |
| iPad (10th gen) | 17.x | Tablet | P1 |
| iPhone 11 | 17.x | Older device | P2 |

### Android Testing Devices
| Device Model | Android Version | Device Type | Priority |
|---|---|---|---|
| Pixel 6 | Android 14 | Standard | P0 |
| Pixel 7 | Android 14-15 | Standard | P0 |
| Samsung Galaxy A53 | Android 13-14 | Mid-range | P0 |
| Google Pixel 6a | Android 14 | Smaller screen | P1 |
| Samsung Galaxy S10 | Android 12 | Older flagship | P1 |
| OnePlus 9 | Android 13 | Mid-range | P1 |
| Emulator (Pixel 3a API 34) | Android 14 | Virtual | P2 |

### Device Configuration Testing
- **Screen Sizes**: 5.4" (small), 6.1" (standard), 6.7" (large), 7.9"+ (tablet)
- **Network Conditions**: WiFi, 4G/LTE, 5G, no network
- **Device States**: Battery low, low storage, low RAM, thermal throttling
- **Orientations**: Portrait (primary), portrait upside-down (secondary)

---

## 3. Test Cases by Feature Area

### 3.1 Authentication & Setup

#### TC-AUTH-001: Splash Screen Display
- **Priority**: P0
- **Preconditions**: App freshly installed, no user created
- **Steps**:
  1. Launch app
  2. Observe splash screen
  3. Wait for automatic navigation
- **Expected Result**: Splash appears for 2-3 seconds, then transitions to Setup screen
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: TTS should play welcome message

#### TC-AUTH-002: Initial Setup Flow - Patient Creation
- **Priority**: P0
- **Preconditions**: Fresh app install
- **Steps**:
  1. Launch app, wait for splash
  2. Proceed through setup wizard
  3. Enter patient name (e.g., "John Doe")
  4. Select high contrast preference
  5. Complete setup
- **Expected Result**:
  - Setup saves patient profile to Firestore
  - User home screen loads with large tiles
  - Anonymous Firebase auth succeeds
  - Caregiver header visible
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify user document created in Firebase with correct fields

#### TC-AUTH-003: Caregiver Login Access (5-Tap Header)
- **Priority**: P0
- **Preconditions**: User home screen visible, setup complete
- **Steps**:
  1. Tap app header/title bar 5 times rapidly
  2. Observe login screen appears
  3. Enter test caregiver email & password
  4. Tap login
- **Expected Result**:
  - Caregiver dashboard loads
  - User profile visible
  - All caregiver features accessible
  - Login credentials validated via Firebase
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Timing sensitive; test various tap speeds

#### TC-AUTH-004: Caregiver Login - PIN Entry (First Time)
- **Priority**: P0
- **Preconditions**: Caregiver logged in, no PIN set
- **Steps**:
  1. Navigate to App Protection settings
  2. Tap "Set PIN"
  3. Enter 4-6 digit PIN (e.g., "1234")
  4. Confirm PIN
  5. Logout and log back in
- **Expected Result**:
  - PIN prompted after login
  - PIN validated with rate limiting
  - Access granted after correct PIN
  - Error message on incorrect PIN
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify SHA-256 hashing with salt in database

#### TC-AUTH-005: Anonymous Auth on First Launch (No Login Required)
- **Priority**: P0
- **Preconditions**: Fresh install, no network available initially
- **Steps**:
  1. Install app
  2. Launch without network
  3. Complete setup if possible
  4. Observe behavior
- **Expected Result**:
  - Anonymous Firebase auth attempted silently
  - Offline mode engaged gracefully
  - Error logged (not displayed to user)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Should not crash or show auth errors to patient

#### TC-AUTH-006: Session Persistence
- **Priority**: P1
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Login as caregiver
  2. Navigate to different screens
  3. Force close app (iOS: swipe up, Android: kill process)
  4. Relaunch app
- **Expected Result**:
  - Caregiver remains logged in
  - Session restored properly
  - No re-login required
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify FirebaseAuth session handling

---

### 3.2 User Home & Navigation

#### TC-HOME-001: User Home Screen Rendering
- **Priority**: P0
- **Preconditions**: App launched, user setup complete
- **Steps**:
  1. View user home screen
  2. Verify all tiles visible
  3. Check text legibility
  4. Verify tap targets >= 48dp
- **Expected Result**:
  - Home icon (nav), Contacts, Reminders, Medical Records tiles visible
  - Large text, high contrast colors
  - All tiles easily tappable
  - Portrait orientation enforced
- **Test Device(s)**: iPhone 14, Pixel 7, iPad
- **Notes**: Tiles should reflow on different screen sizes

#### TC-HOME-002: One-Tap Home Navigation
- **Priority**: P0
- **Preconditions**: User home visible
- **Steps**:
  1. Tap Navigation tile
  2. Allow location permission if prompted
  3. Observe map screen
  4. Tap "Go Home" button
- **Expected Result**:
  - Google Maps opens with directions to home address
  - Route displayed clearly
  - Turn-by-turn directions available
  - Fallback if home address not set
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires Google Maps API key configured

#### TC-HOME-003: TTS Welcome Message on Launch
- **Priority**: P0
- **Preconditions**: TTS enabled, speaker volume up
- **Steps**:
  1. Launch app
  2. Reach user home screen
  3. Listen for audio
- **Expected Result**:
  - Spoken welcome message plays automatically
  - Message is clear and at appropriate volume
  - Audio does not loop
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test on both speaker and with headphones

#### TC-HOME-004: Portrait Orientation Lock
- **Priority**: P1
- **Preconditions**: Device orientation allowed in system settings
- **Steps**:
  1. Launch app
  2. Attempt to rotate device to landscape
  3. Observe screen behavior
- **Expected Result**:
  - Screen remains in portrait mode
  - No landscape layout displayed
  - Orientation lock enforced throughout app
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify SystemChrome.setPreferredOrientations working

#### TC-HOME-005: Large Tap Targets
- **Priority**: P0
- **Preconditions**: User home visible
- **Steps**:
  1. Attempt to tap each button/tile
  2. Verify hit area with developer tools
  3. Test with fingers/hands at various sizes
- **Expected Result**:
  - All tappable elements >= 48dp (iOS) / 48dp (Android)
  - No accidental secondary taps
  - Tactile feedback on tap
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Use accessibility inspector (iOS) and layout bounds (Android)

---

### 3.3 Contacts Feature

#### TC-CONTACTS-001: View Emergency Contacts
- **Priority**: P0
- **Preconditions**: User home visible, caregiver has added contacts
- **Steps**:
  1. Tap Contacts tile from home
  2. Observe list of contacts
  3. Verify names, phone numbers visible
- **Expected Result**:
  - Contacts screen displays all saved contacts
  - Each contact shows name, relationship, phone
  - Large text, high contrast
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Contacts stored in Firestore `users/{id}/contacts`

#### TC-CONTACTS-002: One-Tap Call
- **Priority**: P0
- **Preconditions**: Contacts screen visible, contact added
- **Steps**:
  1. Tap contact tile
  2. Verify dialing prompt
  3. Allow call permission if prompted
  4. Observe call interface
- **Expected Result**:
  - Phone app opens with contact number
  - Call initiates if permission granted
  - Return to Lumina after call ends
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with real phone number; verify url_launcher integration

#### TC-CONTACTS-003: Add/Edit Contacts (Caregiver)
- **Priority**: P0
- **Preconditions**: Caregiver logged in, contacts management screen visible
- **Steps**:
  1. Navigate to Manage Contacts
  2. Tap "Add Contact"
  3. Fill in name, phone, relationship
  4. Save contact
  5. Verify contact appears in user's view
- **Expected Result**:
  - Contact saved to Firestore
  - Synced to user home immediately
  - Appears in contacts list on both iOS/Android
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify Firestore rules allow caregiver write

#### TC-CONTACTS-004: Delete Contact (Caregiver)
- **Priority**: P1
- **Preconditions**: Caregiver logged in, contact exists
- **Steps**:
  1. Navigate to Manage Contacts
  2. Select contact to delete
  3. Confirm deletion
  4. Verify removed from user's view
- **Expected Result**:
  - Contact deleted from Firestore
  - Removed from user's contacts list immediately
  - No orphaned data
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify cascading deletion if needed

#### TC-CONTACTS-005: Contact Image/Avatar
- **Priority**: P1
- **Preconditions**: Caregiver can upload contact image
- **Steps**:
  1. Add contact with image
  2. View contact in user home
  3. Verify image displays correctly
- **Expected Result**:
  - Image stored in Firebase Storage
  - Cached locally
  - Displays in contact tile
  - Falls back to initials if no image
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test JPEG, PNG formats

---

### 3.4 Medication Management

#### TC-MED-001: View Medications
- **Priority**: P0
- **Preconditions**: Caregiver has added medications
- **Steps**:
  1. Tap Reminders tile from home
  2. Filter to show medications only
  3. Verify all medications visible
- **Expected Result**:
  - Medications display with name, dosage, frequency
  - Clear visual indication of medication type
  - Next dose time prominent
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Read from Firestore `medications` collection

#### TC-MED-002: Medication Reminder Notification
- **Priority**: P0
- **Preconditions**: Medication scheduled, notification time reached
- **Steps**:
  1. Set medication reminder for 1 minute from now
  2. Keep app in background
  3. Wait for scheduled time
  4. Observe notification
- **Expected Result**:
  - Full-screen reminder popup appears
  - Medication name, dosage, image displayed
  - TTS voice prompt plays ("Take your medication")
  - Vibration/haptics triggered if enabled
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with app backgrounded, locked, and killed

#### TC-MED-003: Medication Photo Verification
- **Priority**: P0
- **Preconditions**: Medication reminder showing
- **Steps**:
  1. View medication reminder popup
  2. Tap "Take photo" option
  3. Take photo of medication/pill
  4. Submit photo
- **Expected Result**:
  - Camera launches
  5. Photo captured and saved
  6. Photo uploaded to Firebase Storage
  7. Caregiver can review in dashboard
  8. Compliance recorded in Firestore
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires camera permission; verify storage quota

#### TC-MED-004: Medication Refill Tracking
- **Priority**: P1
- **Preconditions**: Caregiver set refill threshold (e.g., 10 days before refill needed)
- **Steps**:
  1. Navigate to Manage Medications
  2. Set remaining pills and refill threshold
  3. Check when alert triggers
  4. Verify alert message
- **Expected Result**:
  - Alert notification sent to caregiver when threshold met
  - Message includes medication name and refill deadline
  - Alert not sent to patient (caregiver only)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify date calculation logic

#### TC-MED-005: Add Medication (Caregiver)
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Medications
  2. Tap "Add Medication"
  3. Enter name, dosage, frequency (daily, twice daily, etc.)
  4. Set schedule times
  5. Upload medication image (optional)
  6. Save
- **Expected Result**:
  - Medication saved to Firestore
  - Reminders created automatically
  - Appears in patient's reminders
  - Schedule validated (no conflicts)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify data model matches Medication class

#### TC-MED-006: Medication Schedule Editing
- **Priority**: P1
- **Preconditions**: Medication exists
- **Steps**:
  1. Edit medication schedule
  2. Change time or frequency
  3. Save changes
  4. Verify reminders updated
- **Expected Result**:
  - Changes reflected immediately in user's reminders
  - Old reminders cleared
  - New reminders created correctly
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with active reminders to ensure cleanup

#### TC-MED-007: Prescription Scan
- **Priority**: P1
- **Preconditions**: Caregiver has prescription image
- **Steps**:
  1. Navigate to Manage Medications
  2. Tap "Scan Prescription"
  3. Select/take photo of prescription
  4. Verify OCR extraction
- **Expected Result**:
  - Text extracted from prescription (OCR)
  - Medication name, dosage, frequency populated
  - Caregiver can edit extracted data
  - Option to save or discard
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses google_mlkit_text_recognition; test with various prescription formats

---

### 3.5 Reminders Feature

#### TC-REM-001: View All Reminders
- **Priority**: P0
- **Preconditions**: User home visible, reminders created
- **Steps**:
  1. Tap Reminders tile
  2. Observe list of all reminders
  3. Verify sorting (by time of day)
- **Expected Result**:
  - Reminders list displays all scheduled reminders
  - Sorted chronologically or by type
  - Each reminder shows time, name, icon
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Reminders include medications, tasks, appointments

#### TC-REM-002: Task Reminder Notification
- **Priority**: P0
- **Preconditions**: Task reminder scheduled
- **Steps**:
  1. Create task reminder ("Feed the dog" at 5 PM)
  2. Wait for scheduled time
  3. Observe notification
- **Expected Result**:
  - Full-screen reminder popup
  - Task name and details visible
  - TTS voice prompt plays task
  - User can mark as done or dismiss
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with app backgrounded; verify local_notifications integration

#### TC-REM-003: Appointment Reminder
- **Priority**: P1
- **Preconditions**: Appointment reminder created (doctor visit, etc.)
- **Steps**:
  1. Create appointment reminder 30 minutes before visit
  2. Wait for notification time
  3. Verify reminder content
- **Expected Result**:
  - Notification includes appointment type, location, time
  - Map to location option available
  - Caregiver can edit appointment details
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Appointment data stored in Firestore

#### TC-REM-004: Hydration Reminder
- **Priority**: P1
- **Preconditions**: Hydration reminders enabled
- **Steps**:
  1. Create hydration reminder every 2 hours
  2. Wait for scheduled times
  3. Observe notifications
- **Expected Result**:
  - Reminders appear at scheduled intervals
  - Message: "Time to drink water"
  - Caregiver can adjust interval
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Special reminder type; verify frequency logic

#### TC-REM-005: Create Reminder (Caregiver)
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Reminders
  2. Tap "Add Reminder"
  3. Select type (medication, task, appointment, etc.)
  4. Fill in details
  5. Set schedule
  6. Save
- **Expected Result**:
  - Reminder saved to Firestore
  - Notifications scheduled locally
  - Appears in patient's view immediately
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify ReminderService creates notifications correctly

#### TC-REM-006: Snooze Reminder
- **Priority**: P1
- **Preconditions**: Reminder notification showing
- **Steps**:
  1. View reminder popup
  2. Tap "Snooze" (if available)
  3. Select snooze duration (5, 15, 30 min)
  4. Verify reminder reappears
- **Expected Result**:
  - Reminder hidden for specified duration
  - Reappears with new notification
  - Option to disable future snoozes
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify snooze persistence across app restarts

#### TC-REM-007: Dismiss Reminder
- **Priority**: P1
- **Preconditions**: Reminder notification showing
- **Steps**:
  1. View reminder popup
  2. Tap "Dismiss" or swipe away
  3. Verify reminder closed
- **Expected Result**:
  - Reminder notification disappears
  - Does not reappear unless rescheduled
  - Action logged in Firestore
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test gesture interaction thoroughly

---

### 3.6 Medical Records Feature

#### TC-MED-REC-001: View Medical Profile
- **Priority**: P0
- **Preconditions**: Caregiver has added medical information
- **Steps**:
  1. Navigate to Medical Records/Profile
  2. Observe sections for conditions, allergies, medications, providers
- **Expected Result**:
  - All medical information organized and readable
  - Sections collapsed/expandable for readability
  - Data current and accurate
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Read from Firestore; design for caregiver input, patient view

#### TC-MED-REC-002: Add Health Condition
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Medical Records
  2. Tap "Add Condition"
  3. Enter condition (e.g., "Type 2 Diabetes"), severity, treating physician
  4. Save
- **Expected Result**:
  - Condition saved to Firestore
  - Appears in patient's medical profile
  - Can be edited or deleted
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify data model

#### TC-MED-REC-003: Add Allergy
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Medical Records
  2. Tap "Add Allergy"
  3. Enter allergen, reaction type, severity
  4. Save
- **Expected Result**:
  - Allergy saved and displayed prominently
  - Severity color-coded (red for severe)
  - Visible on medical summary
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Critical safety feature; test persistence

#### TC-MED-REC-004: Add Healthcare Provider
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Medical Records
  2. Tap "Add Provider"
  3. Enter name, specialty, contact info
  4. Save
- **Expected Result**:
  - Provider saved to Firestore
  - Phone/address clickable
  - Appears in medical profile
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify contact info is launchable

#### TC-MED-REC-005: Generate Medical Summary (PDF)
- **Priority**: P1
- **Preconditions**: Medical records complete
- **Steps**:
  1. View medical profile
  2. Tap "Share" or "Generate Summary"
  3. Verify PDF generation
  4. Test opening/sharing PDF
- **Expected Result**:
  - PDF generated with all medical information
  - Formatted for easy reading by medical staff
  - Can be emailed or printed
  - Includes timestamp
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses `pdf` and `printing` packages

#### TC-MED-REC-006: Add Insurance Information
- **Priority**: P1
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Medical Records
  2. Add insurance provider, policy number, group number
  3. Save
- **Expected Result**:
  - Insurance info saved securely
  - Not displayed unless specifically viewed
  - Included in medical summary
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Sensitive data; verify access controls

#### TC-MED-REC-007: Add Emergency Notes
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Medical Records
  2. Add emergency notes (e.g., "Prefers afternoon appointments", "Severe anxiety with strangers")
  3. Save
- **Expected Result**:
  - Notes saved to Firestore
  - Visible in medical summary
  - Easy for first responders to access
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Critical for emergency situations

---

### 3.7 Navigation & Maps

#### TC-NAV-001: Google Maps Integration
- **Priority**: P0
- **Preconditions**: Location permission granted, Google Maps API key configured
- **Steps**:
  1. Launch navigation screen
  2. Verify map loads
  3. Observe current location marker
- **Expected Result**:
  - Google Maps displays user's current location
  - Map responsive to zoom/pan
  - Proper attribution visible
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires google_maps_flutter and API keys

#### TC-NAV-002: Navigate to Home
- **Priority**: P0
- **Preconditions**: Home address set, location permission granted
- **Steps**:
  1. Tap "Go Home" button
  2. Observe navigation route
- **Expected Result**:
  - Route from current location to home displayed
  - Directions clear and navigable
  - Estimated time displayed
  - Option to open in Maps app for turn-by-turn
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses Directions API; test with various starting locations

#### TC-NAV-003: Navigate to Saved Locations
- **Priority**: P0
- **Preconditions**: Saved locations exist (e.g., doctor's office, grocery store)
- **Steps**:
  1. Tap saved location tile
  2. View navigation route
  3. Observe directions
- **Expected Result**:
  - Navigation to selected location
  - Clear, large route display
  - Easy access to Maps app
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify location data fetched from Firestore

#### TC-NAV-004: Add Saved Location (Caregiver)
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Locations
  2. Tap "Add Location"
  3. Enter location name, address
  4. Set latitude/longitude (auto from map or manual)
  5. Save
- **Expected Result**:
  - Location saved to Firestore
  - Appears in patient's navigation options
  - Address validated
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify geocoding integration

#### TC-NAV-005: Real-Time Location Tracking
- **Priority**: P0
- **Preconditions**: Caregiver logged in, location permission granted
- **Steps**:
  1. Caregiver views location tracking on dashboard
  2. User moves to different location
  3. Observe caregiver's map update
- **Expected Result**:
  - User's location updates in real-time (or near real-time)
  - Caregiver sees updated position
  - Accuracy within ~10-30 meters
  - No excessive battery drain
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires background location permission; verify background service running

#### TC-NAV-006: Location History
- **Priority**: P1
- **Preconditions**: User has been moving, location tracking active
- **Steps**:
  1. Caregiver views location history
  2. Review path traveled
  3. Check timestamps
- **Expected Result**:
  - Path displayed on map with timeline
  - Can zoom in/out to see route
  - Timestamps accurate
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: History stored in `users/{id}/location_updates` subcollection

---

### 3.8 Geofencing & Location Alerts

#### TC-GEO-001: Create Safe Zone
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Manage Zones
  2. Tap "Add Zone"
  3. Select zone type (Home, Safe Zone)
  4. Draw zone on map
  5. Save
- **Expected Result**:
  - Zone saved to Firestore in `geo_zones` collection
  - Zone displayed on caregiver's map
  - Radius/boundary clearly shown
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with various zone sizes (home: 100m radius, safe zone: 500m)

#### TC-GEO-002: Exit Safe Zone Alert
- **Priority**: P0
- **Preconditions**: Safe zone created, location permission active, user inside zone
- **Steps**:
  1. User leaves safe zone
  2. Observe background location service detects exit
  3. Check if caregiver receives notification
- **Expected Result**:
  - Notification sent to caregiver: "John has left the safe zone"
  - Notification includes time, location
  - Push notification delivered reliably
  - Not sent to patient
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Geofence service may use native geofencing (iOS) + background location (Android)

#### TC-GEO-003: Enter Danger Zone Alert
- **Priority**: P0
- **Preconditions**: Danger zone created (e.g., industrial area), user outside zone
- **Steps**:
  1. User moves into danger zone
  2. Observe geofence detection
  3. Check caregiver receives alert
- **Expected Result**:
  - Alert sent: "John has entered restricted area"
  - Includes location and time
  - Urgent notification style
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Danger zone type triggers on entry (vs safe zone on exit)

#### TC-GEO-004: Geofence Accuracy
- **Priority**: P1
- **Preconditions**: Zone created, user at boundary
- **Steps**:
  1. Move to zone boundary
  2. Test multiple times
  3. Observe consistency of alerts
- **Expected Result**:
  - No false positives at boundary
  - Alerts only trigger when clearly in/out
  - Minimal GPS jitter impact
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Geofence service uses Geolocator package; accuracy dependent on GPS quality

#### TC-GEO-005: Multiple Zones
- **Priority**: P1
- **Preconditions**: Multiple zones created (home, work, doctor's office)
- **Steps**:
  1. User travels between zones
  2. Observe alerts for each exit/entry
- **Expected Result**:
  - Each zone monitored independently
  - Correct alerts fired for correct zones
  - No duplicate alerts
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with 3-5 zones simultaneously

---

### 3.9 Caregiver-Specific Features

#### TC-CG-001: Caregiver Login
- **Priority**: P0
- **Preconditions**: Caregiver email/password registered in Firebase
- **Steps**:
  1. Launch app
  2. Tap header 5 times to access login
  3. Enter caregiver credentials
  4. Tap login
- **Expected Result**:
  - Login validates against Firebase Auth
  - Dashboard loads on success
  - Error message on failure
  - Rate limiting active (max 5 attempts)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify Firebase Auth configuration

#### TC-CG-002: Caregiver Dashboard
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. View caregiver dashboard
  2. Verify all sections visible: patient info, location, recent activity
- **Expected Result**:
  - Dashboard displays patient name, photo
  - Real-time location on map
  - Recent activity feed (medications, reminders)
  - Quick action buttons (edit patient, manage settings)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Design for quick at-a-glance status

#### TC-CG-003: PIN Protection (Caregiver Settings)
- **Priority**: P0
- **Preconditions**: Caregiver logged in, no PIN set
- **Steps**:
  1. Navigate to App Protection
  2. Tap "Set PIN"
  3. Enter 4-6 digit PIN
  4. Confirm PIN
  5. Logout and log back in
  6. Verify PIN prompt appears
  7. Enter PIN
- **Expected Result**:
  - PIN set successfully
  - Prompted on next login
  - Rate limited after 3 failed attempts
  - PIN stored as SHA-256 hash + salt
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify crypto/sha256 integration

#### TC-CG-004: Multiple Caregivers
- **Priority**: P1
- **Preconditions**: Primary caregiver logged in
- **Steps**:
  1. Navigate to Manage Caregivers
  2. Tap "Invite Caregiver"
  3. Enter email address of secondary caregiver
  4. Select permissions (view, edit, manage)
  5. Send invite
- **Expected Result**:
  - Email invitation sent
  - Secondary caregiver can accept invite
  - Both caregivers see patient's data
  - Permissions enforced correctly
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify Firestore security rules for multi-caregiver access

#### TC-CG-005: Remove Caregiver Access
- **Priority**: P1
- **Preconditions**: Multiple caregivers assigned
- **Steps**:
  1. Navigate to Manage Caregivers
  2. Select caregiver to remove
  3. Confirm removal
  4. Attempt login with removed caregiver's account
- **Expected Result**:
  - Caregiver removed from patient's caregiverIds array
  - Removed caregiver cannot access patient data
  - Error message on login attempt
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify Firestore rule evaluation

#### TC-CG-006: Edit Patient Profile
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to User Profile
  2. Edit patient name, date of birth, photo
  3. Save changes
  4. Verify changes appear in patient's app
- **Expected Result**:
  - Changes saved to Firestore
  - Synced to patient's device immediately
  - Photo uploaded to Cloud Storage
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with various image formats/sizes

---

### 3.10 App Protection Features

#### TC-APP-PROT-001: Prevent App Deletion (Android Device Admin)
- **Priority**: P1
- **Preconditions**: Android device, caregiver enabled app protection
- **Steps**:
  1. Caregiver navigates to App Protection
  2. Enable "Prevent App Deletion"
  3. Device admin permission prompt appears
  4. Grant permission
  5. Attempt to uninstall app
- **Expected Result**:
  - Device admin permission requested and granted
  - App cannot be uninstalled from Play Store
  - "This app is managed" message shown in Settings
  - Requires caregiver PIN to disable protection
- **Test Device(s)**: Pixel 7, Galaxy A53
- **Notes**: Uses DeviceAdminReceiver; Android only

#### TC-APP-PROT-002: Kiosk Mode (Android)
- **Priority**: P1
- **Preconditions**: Android device with kiosk mode support
- **Steps**:
  1. Caregiver enables Kiosk Mode
  2. Device enters kiosk mode
  3. User cannot exit app
  4. Home button disabled
- **Expected Result**:
  - App launches in kiosk mode
  - Back button, home button, recent apps hidden
  - Device fully locked to Lumina
  - Only caregiver can exit kiosk
- **Test Device(s)**: Pixel 7, Galaxy A53
- **Notes**: Requires DevicePolicyManager; may need work profile

#### TC-APP-PROT-003: Screen Pinning (Android)
- **Priority**: P1
- **Preconditions**: Android device with screen pinning support
- **Steps**:
  1. Caregiver enables Screen Pinning
  2. Device pins app to screen
  3. User tries to swipe away or use back button
  4. Observe restrictions
- **Expected Result**:
  - App pinned to screen
  - Requires back + recent button combination to unpin
  - Not discoverable for typical users
- **Test Device(s)**: Pixel 7, Galaxy A53
- **Notes**: Uses WindowManager; lighter than kiosk

#### TC-APP-PROT-004: Guided Access (iOS)
- **Priority**: P1
- **Preconditions**: iOS device with Guided Access enabled
- **Steps**:
  1. Enable Guided Access in Settings > Accessibility
  2. Launch Lumina
  3. Triple-click home/side button to activate Guided Access
  4. Lock to Lumina
  5. Attempt to exit app
- **Expected Result**:
  - Guided Access enabled (manual by caregiver)
  - Device locked to Lumina
  - Home/app switcher disabled
  - Requires passcode to disable
- **Test Device(s)**: iPhone 14
- **Notes**: iOS built-in feature; app just documents it

#### TC-APP-PROT-005: Screen Time Restrictions (iOS)
- **Priority**: P1
- **Preconditions**: iOS device, caregiver controls Screen Time
- **Steps**:
  1. Caregiver sets Screen Time on device
  2. Restrict app deletion
  3. User attempts to delete Lumina
- **Expected Result**:
  - Lumina cannot be deleted
  - Requires Screen Time passcode to enable deletion
- **Test Device(s)**: iPhone 14
- **Notes**: iOS built-in feature; not managed by app

#### TC-APP-PROT-006: PIN Requirement for Disabling Protection
- **Priority**: P0
- **Preconditions**: App protection enabled, PIN set
- **Steps**:
  1. Caregiver views app protection settings
  2. Attempt to disable protection
  3. PIN prompt appears
  4. Enter incorrect PIN
  5. Verify error and rate limiting
- **Expected Result**:
  - PIN required before disabling any protection
  - Max 3 incorrect attempts
  - 5-minute lockout after failed attempts
  - Lockout message clear
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Critical security feature

---

### 3.11 Push Notifications

#### TC-NOTIF-001: Notification Permission Request
- **Priority**: P0
- **Preconditions**: Fresh app install, no notification permission yet
- **Steps**:
  1. Launch app on iOS/Android
  2. Observe notification permission prompt
  3. Grant permission
- **Expected Result**:
  - Platform-appropriate prompt appears
  - User can allow or deny
  - App records permission status
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses flutter_local_notifications

#### TC-NOTIF-002: Medication Reminder Push
- **Priority**: P0
- **Preconditions**: Medication reminder scheduled, notification permission granted
- **Steps**:
  1. Set medication reminder for 1 minute
  2. App in background or locked
  3. Wait for scheduled time
  4. Observe notification
- **Expected Result**:
  - Notification appears on lock screen
  - Tapping notification opens app to reminder details
  - Notification includes medication name, dosage
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify notification routing to correct screen

#### TC-NOTIF-003: Geofence Exit Alert
- **Priority**: P0
- **Preconditions**: Safe zone created, caregiver logged in
- **Steps**:
  1. User exits safe zone
  2. Caregiver has notification permission
  3. Wait for alert delivery
- **Expected Result**:
  - Notification received by caregiver
  - Message: "John has left the safe zone"
  - Includes location and timestamp
  - Actionable (tap to view location)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses Firebase Cloud Messaging; verify server-side function

#### TC-NOTIF-004: Caregiver Notification for Sundown Syndrome
- **Priority**: P1
- **Preconditions**: Sundown alerts enabled, sundown time triggered
- **Steps**:
  1. User's app detects sundown period (e.g., 6 PM)
  2. Observe alert to caregiver
- **Expected Result**:
  - Caregiver notified of sundown alert
  - Includes recommendations for de-escalation
  - Can acknowledge or ignore
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Sundown period customizable; uses SundownService

#### TC-NOTIF-005: Notification Clear
- **Priority**: P1
- **Preconditions**: Notification displayed
- **Steps**:
  1. View notification on lock screen
  2. Dismiss/clear notification
  3. Verify cleared
- **Expected Result**:
  - Notification disappears
  - Not sent again unless rescheduled
  - Tap action still available until cleared
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test swipe-to-dismiss on iOS, swipe-to-remove on Android

#### TC-NOTIF-006: Do Not Disturb / Quiet Hours
- **Priority**: P1
- **Preconditions**: Device in quiet/focus mode during night hours
- **Steps**:
  1. Set device to Do Not Disturb / Focus mode
  2. Trigger reminder notification
  3. Observe notification behavior
- **Expected Result**:
  - Notification still delivered but silently (vibrate only)
  - Or notification batched until morning
  - Critical alerts (caregiver) may bypass DND
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: System setting behavior; verify notification importance level

---

### 3.12 Accessibility Features

#### TC-A11Y-001: Text Scaling
- **Priority**: P0
- **Preconditions**: User home visible
- **Steps**:
  1. Change system text size to largest (200-240%)
  2. Navigate through app screens
  3. Verify all text readable
- **Expected Result**:
  - Text scales without clipping
  - Layout reflows to accommodate large text
  - Tiles stack vertically if needed
  - No horizontal scroll required
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test on device settings, not in-app settings

#### TC-A11Y-002: High Contrast Mode
- **Priority**: P0
- **Preconditions**: High contrast enabled in settings
- **Steps**:
  1. Enable high contrast on device (iOS/Android)
  2. Launch app
  3. Verify all UI elements highly visible
- **Expected Result**:
  - Colors updated to high contrast palette
  - Text remains readable
  - Buttons and interactive elements clearly defined
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires theme updates; uses AppTheme.highContrastTheme

#### TC-A11Y-003: VoiceOver / TalkBack Support
- **Priority**: P0
- **Preconditions**: VoiceOver (iOS) or TalkBack (Android) enabled
- **Steps**:
  1. Enable screen reader
  2. Navigate home screen
  3. Interact with tiles and buttons
- **Expected Result**:
  - All elements announced correctly
  - Semantic labels accurate
  - Gestures work as expected
  - No dead zones or missing labels
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires semantic labeling in widgets

#### TC-A11Y-004: Touch Target Size
- **Priority**: P0
- **Preconditions**: App on any device
- **Steps**:
  1. Inspect all tappable elements
  2. Measure tap target area
- **Expected Result**:
  - All tap targets >= 48x48 dp (standard) or >= 44x44 pt (iOS)
  - Spacing between targets >= 8dp
  - No accidental adjacent taps
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Use accessibility inspector tools

#### TC-A11Y-005: Color Contrast
- **Priority**: P0
- **Preconditions**: App screens visible
- **Steps**:
  1. Test all text vs background contrast
  2. Use online contrast checker
- **Expected Result**:
  - Normal text >= 4.5:1 contrast (AA)
  - Large text >= 3:1 contrast (AA)
  - UI elements >= 3:1 contrast
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: WCAG 2.1 AA minimum

#### TC-A11Y-006: Text-to-Speech Speed Control
- **Priority**: P1
- **Preconditions**: TTS enabled
- **Steps**:
  1. Navigate to accessibility settings
  2. Adjust TTS speed (slow, normal, fast)
  3. Trigger reminder/welcome message
- **Expected Result**:
  - Speed adjusts immediately
  - Audio clear at all speeds
  - No audio artifacts
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses flutter_tts; verify speed parameters

#### TC-A11Y-007: Haptic Feedback
- **Priority**: P1
- **Preconditions**: Haptics enabled
- **Steps**:
  1. Tap buttons and interact with elements
  2. Verify haptic feedback on each action
- **Expected Result**:
  - Haptics triggered on tap
  - Intensity appropriate
  - Can be disabled in settings
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses HapticFeedback

#### TC-A11Y-008: Disable Sound Effects
- **Priority**: P1
- **Preconditions**: App settings visible
- **Steps**:
  1. Toggle sound effects off
  2. Trigger reminders/alerts
  3. Verify no sound plays
- **Expected Result**:
  - TTS still plays (separate from sound effects)
  - All audio cues have visual alternatives
  - Caregiver can enforce sound on/off
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: User preference stored in Firestore

---

### 3.13 Firebase Integration

#### TC-FB-001: Firebase Authentication (Anonymous)
- **Priority**: P0
- **Preconditions**: Firebase project configured, anonymous auth enabled
- **Steps**:
  1. Launch app
  2. Observe Firebase Auth initialization
  3. Verify anonymous user created
- **Expected Result**:
  - Anonymous auth succeeds silently
  - No error message to user
  - Firestore rules allow access
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify in Firebase Console under Authentication

#### TC-FB-002: Firestore Read (User Data)
- **Priority**: P0
- **Preconditions**: User data exists in Firestore
- **Steps**:
  1. Launch app
  2. Navigate to screens that read user data
  3. Observe data loads
- **Expected Result**:
  - User data loaded from Firestore
  - Displayed on screen with no delay
  - Real-time updates work
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify security rules in firestore.rules

#### TC-FB-003: Firestore Write (Save Reminder)
- **Priority**: P0
- **Preconditions**: Caregiver can create reminders
- **Steps**:
  1. Create new reminder in caregiver app
  2. Observe save to Firestore
  3. Verify appears in patient app
- **Expected Result**:
  - Data written to Firestore collection
  - Patient's app reflects change in real-time
  - No data loss on connection loss
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify write timestamp and user ID

#### TC-FB-004: Cloud Storage Upload (Profile Photo)
- **Priority**: P1
- **Preconditions**: Caregiver uploading photo
- **Steps**:
  1. Upload patient profile photo
  2. Observe upload progress (if slow network)
  3. Verify photo accessible
- **Expected Result**:
  - Photo uploaded to Cloud Storage
  - URL stored in Firestore
  - Photo displays in caregiver/patient views
  - Cached locally after first load
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify storage rules allow caregiver write

#### TC-FB-005: Cloud Firestore Subcollection (Medications)
- **Priority**: P0
- **Preconditions**: Medications data exists
- **Steps**:
  1. Navigate to medications
  2. Observe medications loaded from `medications` collection
- **Expected Result**:
  - Medications queried and loaded correctly
  - Real-time listener active
  - Changes sync immediately
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test query performance with many documents

#### TC-FB-006: Cloud Messaging (Push Notification)
- **Priority**: P0
- **Preconditions**: Firebase Messaging configured, notification permission granted
- **Steps**:
  1. App registered for messaging
  2. Trigger server-side notification send
  3. Observe delivery
- **Expected Result**:
  - Notification delivered within 5 seconds
  - Payload parsed correctly
  - Action taken (navigate to reminder, etc.)
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with app foreground, background, and killed

#### TC-FB-007: Firestore Offline Support
- **Priority**: P1
- **Preconditions**: App has local cache, network lost
- **Steps**:
  1. Load data while online
  2. Go offline
  3. Navigate to cached screens
  4. Attempt to edit data
- **Expected Result**:
  - Cached data readable offline
  - Edits queued for sync
  - Sync occurs when online
  - User notified of offline state
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Enable Firebase offline persistence

#### TC-FB-008: Firebase Analytics Logging
- **Priority**: P1
- **Preconditions**: Analytics enabled
- **Steps**:
  1. Navigate through app
  2. Trigger events (view reminder, call contact, etc.)
  3. Check Firebase Analytics dashboard
- **Expected Result**:
  - Events logged correctly
  - Timestamps accurate
  - Custom events with parameters recorded
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Allow 24 hours for data to appear in console

---

### 3.14 Offline Behavior & Network Resilience

#### TC-OFFLINE-001: Offline Mode Detection
- **Priority**: P0
- **Preconditions**: App online, then lose network
- **Steps**:
  1. Toggle airplane mode on
  2. Observe app response
  3. Check for offline indicator
- **Expected Result**:
  - App detects offline state
  - Visual indicator shows offline (e.g., banner, icon)
  - Core functionality remains accessible
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Uses connectivity_plus package

#### TC-OFFLINE-002: View Cached Data Offline
- **Priority**: P0
- **Preconditions**: Data loaded while online, then offline
- **Steps**:
  1. Load reminders while online
  2. Go offline
  3. View reminders
- **Expected Result**:
  - Cached reminders display
  - No error shown to user
  - Data marked as cached/stale
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Firestore offline persistence must be enabled

#### TC-OFFLINE-003: Queued Write Operations
- **Priority**: P1
- **Preconditions**: Offline, attempt to create/edit data
- **Steps**:
  1. Go offline
  2. Create or edit data (if allowed)
  3. Return online
  4. Verify sync
- **Expected Result**:
  - Changes queued locally
  - Synced to Firestore when online
  - No data loss
  - User notified of sync status
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with intentional delay between offline/online

#### TC-OFFLINE-004: Network Error Handling
- **Priority**: P1
- **Preconditions**: App attempting network operation with poor connection
- **Steps**:
  1. Simulate poor network (use dev tools or actual network)
  2. Attempt operation (load data, send notification)
  3. Observe error handling
- **Expected Result**:
  - Graceful error message
  - Retry option provided
  - No crash or hang
  - Timeout after reasonable delay
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with various network delays

#### TC-OFFLINE-005: Background Service Offline
- **Priority**: P1
- **Preconditions**: Background location/reminder service active, network lost
- **Steps**:
  1. Enable background monitoring
  2. Go offline
  3. Observe service behavior
- **Expected Result**:
  - Service continues running
  - Does not crash due to network error
  - Resumes syncing when online
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Critical for reliability in poor coverage areas

---

### 3.15 Performance & Load Testing

#### TC-PERF-001: App Startup Time
- **Priority**: P0
- **Preconditions**: Fresh app kill, device state normal
- **Steps**:
  1. Kill app completely
  2. Launch app
  3. Time from tap to user home visible
  4. Repeat 5 times, measure average
- **Expected Result**:
  - Average startup < 3 seconds
  - First launch may be slower (initialization)
  - Subsequent launches < 2 seconds
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Measure with Xcode Instruments (iOS) or Android Studio (Android)

#### TC-PERF-002: Memory Usage
- **Priority**: P1
- **Preconditions**: App running, normal usage
- **Steps**:
  1. Monitor memory usage while:
     - Loading home screen
     - Viewing large lists (many reminders)
     - Navigating between screens
     - Playing TTS audio
  2. Measure peak memory usage
- **Expected Result**:
  - Normal use < 100 MB (iOS), < 150 MB (Android)
  - No memory leaks over 30 min usage
  - No crashes due to OOM
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Use Instruments (iOS) / Memory Profiler (Android)

#### TC-PERF-003: Battery Impact
- **Priority**: P1
- **Preconditions**: Device with normal battery level, background location enabled
- **Steps**:
  1. Run app for 2 hours with background location active
  2. Measure battery drain
  3. Compare to device baseline
- **Expected Result**:
  - Battery drain < 10% per hour of active usage
  - Background location <5% per hour
  - No unusual battery spikes
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Use Settings app to monitor battery

#### TC-PERF-004: List Performance (Many Reminders)
- **Priority**: P1
- **Preconditions**: 100+ reminders created
- **Steps**:
  1. Load reminders list
  2. Measure load time
  3. Scroll through list
  4. Measure scroll smoothness (FPS)
- **Expected Result**:
  - List loads in < 1 second
  - Scrolling smooth at 60 FPS (iOS), 60 FPS (Android)
  - No jank or stuttering
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Use Performance Profiler; consider virtual scrolling if needed

#### TC-PERF-005: Map Performance
- **Priority**: P1
- **Preconditions**: Large location history (50+ points)
- **Steps**:
  1. Load location history on map
  2. Draw route with many points
  3. Measure rendering performance
- **Expected Result**:
  - Map loads quickly
  - Polyline renders smoothly
  - Zoom/pan responsive
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with clustered vs sparse location points

#### TC-PERF-006: TTS Performance
- **Priority**: P1
- **Preconditions**: Long text to speak (reminder message, medical summary)
- **Steps**:
  1. Trigger TTS with various message lengths
  2. Measure speech onset time (latency)
  3. Measure audio quality
- **Expected Result**:
  - Speech starts within 1 second
  - No stuttering or audio artifacts
  - Clear pronunciation
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test on device speakers and headphones

---

### 3.16 Edge Cases & Stress Testing

#### TC-EDGE-001: No Permissions Granted
- **Priority**: P1
- **Preconditions**: App with no permissions
- **Steps**:
  1. Deny all permissions (location, camera, notifications, contacts)
  2. Navigate through app
  3. Attempt features requiring permissions
- **Expected Result**:
  - App functions without crash
  - Graceful degradation (e.g., map unavailable)
  - Clear message explaining permission requirement
  - Option to enable in settings
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test each permission independently and combined

#### TC-EDGE-002: Low Device Storage
- **Priority**: P1
- **Preconditions**: Device with < 100 MB free storage
- **Steps**:
  1. Attempt to upload photos
  2. Download medical records
  3. Record location data
- **Expected Result**:
  - App detects low storage
  - User notified
  - Graceful failure (not crash)
  - Suggestion to free storage
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Use device settings to simulate low storage

#### TC-EDGE-003: Low Battery
- **Priority**: P1
- **Preconditions**: Device battery < 10%
- **Steps**:
  1. View app behavior on low battery
  2. Attempt to use location services
  3. Observe TTS and notifications
- **Expected Result**:
  - Critical features still work
  - Low battery warning shown
  - Location frequency may reduce
  - TTS and notifications continue
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Enable Low Power Mode in device settings

#### TC-EDGE-004: Very Long Medication Name
- **Priority**: P1
- **Preconditions**: Add medication with very long name (>50 chars)
- **Steps**:
  1. Create medication with name like "Methylprednisolone Acetate 40mg Oral Suspension"
  2. View in reminder popup
  3. Check text wrapping
- **Expected Result**:
  - Text wraps correctly
  - No clipping or overflow
  - Still readable in reminder popup
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with various text sizes

#### TC-EDGE-005: Many Simultaneous Reminders
- **Priority**: P1
- **Preconditions**: Schedule 5+ reminders at same time
- **Steps**:
  1. Set reminders for 14:00: Med A, Med B, Task, Appointment, Hydration
  2. Wait for scheduled time
  3. Observe notifications
- **Expected Result**:
  - All reminders delivered
  - Queued in notification tray
  - No duplicate notifications
  - User can address each separately
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test alert queue logic

#### TC-EDGE-006: Rapid Navigation Between Screens
- **Priority**: P1
- **Preconditions**: App running
- **Steps**:
  1. Rapidly tap tiles and navigate between screens
  2. Swipe back/forward quickly
  3. Observe app stability
- **Expected Result**:
  - No crashes or freezes
  - Screens load correctly
  - Navigation state consistent
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Stress test the nav stack

#### TC-EDGE-007: Rapid Caregiver Access Attempts
- **Priority**: P1
- **Preconditions**: User home visible
- **Steps**:
  1. Rapidly tap header to trigger caregiver login
  2. Attempt login with wrong password repeatedly
  3. Observe rate limiting
- **Expected Result**:
  - Rate limiting kicks in after 5-10 attempts
  - Account locked for 5 minutes
  - User notified of lockout
  - No brute force possible
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify auth_service rate limiting

#### TC-EDGE-008: Empty State Handling
- **Priority**: P1
- **Preconditions**: User with no reminders, contacts, medications
- **Steps**:
  1. Navigate to contacts, reminders, medications
  2. Observe empty screens
- **Expected Result**:
  - Empty state message displayed
  - Helpful guidance given
  - No crash or blank screen
  - Invite to caregiver or add data
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Check all feature screens

#### TC-EDGE-009: Unusual Language Input
- **Priority**: P2
- **Preconditions**: Caregiver entering non-ASCII text
- **Steps**:
  1. Add reminder/contact with emoji, special chars
  2. Verify storage and display
- **Expected Result**:
  - Text stored correctly
  - Displays without corruption
  - TTS can handle special chars
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test with emoji, accents, RTL text if applicable

#### TC-EDGE-010: Rapid App Backgrounding/Foregrounding
- **Priority**: P1
- **Preconditions**: App running
- **Steps**:
  1. Switch between Lumina and other apps repeatedly
  2. Observe memory leaks
  3. Check if services resume
- **Expected Result**:
  - Smooth transitions
  - Background service resumes correctly
  - No memory leaks
  - State preserved
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test App Lifecycle handling

---

### 3.17 Sundown Syndrome Features

#### TC-SUNDOWN-001: Sundown Alert Trigger
- **Priority**: P0
- **Preconditions**: Sundown alerts enabled, sundown time configured (e.g., 6-8 PM)
- **Steps**:
  1. Set current system time to approach sundown time
  2. Observe app behavior at sundown trigger time
  3. Check for alert to user
- **Expected Result**:
  - Alert displayed to user at configured sundown time
  - Message explains time (visual and TTS)
  - Caregiver receives notification
  - Soothing background colors/UI applied
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Mock system time if needed; verify SundownService logic

#### TC-SUNDOWN-002: Sundown Settings Configuration
- **Priority**: P0
- **Preconditions**: Caregiver logged in
- **Steps**:
  1. Navigate to Sundown Settings
  2. Enable sundown detection
  3. Set start time (e.g., 6 PM) and end time (e.g., 10 PM)
  4. Save
- **Expected Result**:
  - Settings saved to Firestore
  - Synced to user's app
  - Service uses new times
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Verify SundownService receives updates

#### TC-SUNDOWN-003: Sundown De-escalation Tips
- **Priority**: P0
- **Preconditions**: Sundown alert triggered
- **Steps**:
  1. View sundown alert popup
  2. Observe caregiver tips displayed
  3. Check if music/calming content option available
- **Expected Result**:
  - Tips displayed to caregiver
  - Options for music, relaxation activities
  - Alert can be acknowledged/dismissed
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Design to reduce caregiver stress

---

### 3.18 Bouncie/Vehicle Integration (If Applicable)

#### TC-BOUNCIE-001: Vehicle Status Display
- **Priority**: P2
- **Preconditions**: Bouncie API key configured, vehicle linked
- **Steps**:
  1. View vehicle status in app
  2. Observe battery, location, trip info
- **Expected Result**:
  - Vehicle data fetched from Bouncie API
  - Battery level displayed
  - Last location shown
  - Last trip details visible
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Requires valid Bouncie account and vehicle

#### TC-BOUNCIE-002: Trip History
- **Priority**: P2
- **Preconditions**: Vehicle with trip history
- **Steps**:
  1. Navigate to Trip History
  2. View list of recent trips
  3. Select trip to view details
- **Expected Result**:
  - Trips listed with date, time, distance
  - Trip details show route, duration, cost estimate
  - Integration with Bouncie API successful
- **Test Device(s)**: iPhone 14, Pixel 7
- **Notes**: Test API pagination if many trips

---

## 4. Test Execution Guidelines

### Test Execution Process
1. **Create Test Account**: Set up test caregiver and patient accounts in Firebase
2. **Execute Test Case**: Follow preconditions and steps exactly
3. **Document Result**: Record pass/fail, any issues, device/OS version
4. **Log Bugs**: Use bug report template (Section 5)
5. **Mark Complete**: Record test date and tester name

### Concurrent Testing
- Multiple testers can work on different feature areas simultaneously
- Coordinate on shared test accounts to avoid conflicts
- Rotate devices to ensure comprehensive coverage

### Test Data
- Use realistic test data (real medication names, contact names, addresses)
- Create test accounts in Firebase auth: `test.caregiver@example.com`
- Generate test firebase user with proper caregiverId mappings

### Platform-Specific Notes
- **iOS**: Test on actual device or simulator with location spoofing
- **Android**: Emulator sufficient for basic testing; device testing critical for sensors
- **Cross-Platform**: Execute identical test cases on both iOS and Android

---

## 5. Bug Report Template

### Bug Report Format
Use this template for all identified issues:

```
**Bug ID**: [AUTO-GENERATED or MANUAL]
**Title**: [Concise description]
**Severity**: P0 (Critical) | P1 (High) | P2 (Medium) | P3 (Low)
**Priority**: [Same as Severity for alignment]
**Status**: Open | In Progress | Fixed | Verified
**Component**: [Feature module]
**Affected Platforms**: iOS / Android / Both
**Device(s)**: [Model, OS Version]
**Reproducibility**: Always | Often | Sometimes | Rarely | Unable to reproduce

**Description**:
[Clear, detailed description of the issue]

**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Step 3]
...

**Expected Result**:
[What should happen]

**Actual Result**:
[What actually happened]

**Screenshots/Video**:
[Attach relevant screenshots or screen recording]

**Logs**:
[Include relevant error logs from Xcode/Android Studio]

**Workaround** (if applicable):
[Any known workaround]

**Additional Notes**:
[Any other relevant information]

**Reported by**: [Tester Name]
**Report Date**: [YYYY-MM-DD]
**Assigned to**: [Developer]
```

### Severity Guidelines
- **P0 (Critical)**: App crash, data loss, security issue, blocking usage
- **P1 (High)**: Feature broken, significant usability issue, major UI issue
- **P2 (Medium)**: Minor visual issue, non-critical feature broken, workaround exists
- **P3 (Low)**: Polish, typo, cosmetic issue, does not affect functionality

---

## 6. Sign-Off Checklist

### Core Features Tested
- [ ] Authentication (patient setup, caregiver login, PIN)
- [ ] User home screen and navigation
- [ ] Contacts (view, call, add, edit, delete)
- [ ] Medications (view, create, schedule, reminders, refill tracking)
- [ ] Reminders (all types: medication, task, appointment, hydration)
- [ ] Medical records (view, edit, generate summary)
- [ ] Location & maps (home navigation, saved locations, location tracking)
- [ ] Geofencing (safe zones, danger zones, alerts)
- [ ] Caregiver dashboard (view patient, manage profile, manage settings)
- [ ] App protection (PIN, device admin, kiosk mode)
- [ ] Push notifications (all types, permissions)
- [ ] Firebase integration (auth, Firestore, Storage, Messaging)
- [ ] Offline behavior (offline detection, cached data, queued writes)

### Quality Standards Met
- [ ] Zero P0 bugs remaining
- [ ] All P1 bugs fixed or deferred with justification
- [ ] Accessibility standards met (WCAG 2.1 AA minimum)
- [ ] Performance targets met (startup <3s, memory <100MB, 60 FPS scrolling)
- [ ] All network conditions tested (online, offline, poor connection)
- [ ] All device types tested (phones, tablets, various screen sizes)
- [ ] All OS versions tested (iOS 14+, Android 9+)
- [ ] No crashes in extended testing sessions
- [ ] All permissions handled gracefully
- [ ] Push notifications reliable

### Device Coverage
- [ ] iPhone (minimum 2 models, both iOS versions)
- [ ] Android (minimum 2 devices, both OS versions)
- [ ] Tablets (at least 1 iPad, 1 Android tablet)
- [ ] Various screen sizes (small, medium, large)
- [ ] Different network conditions tested

### Documentation Complete
- [ ] Test plan signed off by Product Manager
- [ ] All test cases executed and documented
- [ ] All bugs logged and tracked
- [ ] Regression testing completed
- [ ] Known issues documented with workarounds
- [ ] Release notes prepared

### Final Approval
- **Product Manager**: _________________ Date: _______
- **QA Lead**: _________________ Date: _______
- **Engineering Lead**: _________________ Date: _______
- **Ready for App Store**: [YES / NO] Date: _______

---

## 7. Test Summary Template (To Complete During Testing)

### Testing Period
- **Start Date**: [DATE]
- **End Date**: [DATE]
- **Total Tester-Hours**: [NUMBER]

### Coverage Summary
- **Total Test Cases**: [COUNT]
- **Executed**: [COUNT]
- **Passed**: [COUNT]
- **Failed**: [COUNT]
- **Blocked**: [COUNT]
- **Pass Rate**: [PERCENTAGE]

### Bugs Summary
- **Total Bugs Found**: [COUNT]
- **P0 (Critical)**: [COUNT]
- **P1 (High)**: [COUNT]
- **P2 (Medium)**: [COUNT]
- **P3 (Low)**: [COUNT]
- **Fixed**: [COUNT]
- **Remaining**: [COUNT]

### Platform-Specific Results
**iOS**:
- Devices tested: [LIST]
- Pass rate: [PERCENTAGE]
- Major issues: [LIST]

**Android**:
- Devices tested: [LIST]
- Pass rate: [PERCENTAGE]
- Major issues: [LIST]

### Recommendations
- [RECOMMENDATION 1]
- [RECOMMENDATION 2]
- [RECOMMENDATION 3]

### Release Decision
- **Recommendation**: [APPROVED FOR RELEASE / CONDITIONAL / NOT APPROVED]
- **Rationale**: [EXPLANATION]
- **Remaining Risks**: [IF ANY]

---

## Appendix A: Test Account Credentials

**Test Caregiver Account**:
- Email: `test.caregiver@example.com`
- Password: `[SECURE PASSWORD - KEEP CONFIDENTIAL]`
- PIN: `1234`

**Test Caregiver Account (Secondary)**:
- Email: `test.caregiver2@example.com`
- Password: `[SECURE PASSWORD - KEEP CONFIDENTIAL]`
- PIN: `5678`

**Firebase Project ID**: [FROM .firebaserc]
**Google Maps API Keys**: [CONFIGURE IN iOS/Android]

---

## Appendix B: Useful Testing Tools

### iOS Testing
- **Xcode Instruments**: Memory, CPU, Network, FPS profiling
- **Accessibility Inspector**: Semantic labels, contrast checking
- **Network Link Conditioner**: Simulate various network conditions
- **System Preferences**: VoiceOver, text scaling, high contrast testing

### Android Testing
- **Android Profiler**: Memory, CPU, network monitoring
- **Layout Inspector**: View hierarchy and tap target verification
- **Android Emulator**: Network simulation, sensor spoofing
- **Accessibility Scanner**: Automated a11y checks

### Firebase Tools
- **Firebase Console**: Monitor authentication, Firestore, Storage, Messaging
- **Firestore Emulator**: Local testing without cloud
- **Cloud Functions Logs**: Debug server-side issues
- **Analytics**: Track events and user behavior

### Device Testing
- **Charles Proxy**: Intercept and monitor network traffic
- **Burp Suite**: Security testing (if applicable)
- **Git Blame / Git Log**: Understand recent changes to code

---

## Appendix C: Known Limitations & Considerations

### Platform Limitations
- **iOS Kiosk Mode**: Not natively supported; use Guided Access (manual)
- **Android Older Versions**: Some features may require Android 10+
- **iPad Layouts**: Portrait-only may not optimize for larger tablets

### Backend Considerations
- **Firebase Quota**: Free tier may throttle during heavy testing
- **Google Maps API**: Cost scaling with usage; monitor API calls
- **Device Admin**: Android only; iOS relies on built-in features

### Testing Constraints
- **Location Services**: May not work accurately indoors; use emulator location spoofing
- **Push Notifications**: Testing requires valid Firebase project and device tokens
- **Background Services**: Behavior varies across iOS/Android; test on device preferred

---

**End of Beta Test Plan**

---

*This document is controlled and versioned. Updates require approval from Product Manager and QA Lead.*
*Last Review Date: 2026-02-24*
*Next Review Due: After major feature additions or platform updates*
