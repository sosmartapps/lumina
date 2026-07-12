# QuadTrack — Complete Feature Reference (Pause Snapshot, 2026-07-07)

> **Purpose of this document:** QuadTrack is being **paused and unhooked from the Lumina UI on 2026-07-07**. This file is the single source of truth for resuming the feature in a fresh session with zero other context. It captures product intent, every code artifact, the Firestore footprint, Cloud Functions, exact integration points that were removed, known bugs, and a resume checklist.

---

## 1. Overview — What QuadTrack Is

QuadTrack is a **custom hardware GPS tracker for Alzheimer's/dementia patients** plus its companion software inside the Lumina caregiver app.

**Hardware concept** (from `lib/core/models/quadtrack_device.dart` doc comment, `docs/quadtrack-prior-art-research.md`, and `memory/projects/quadtrack-fcc-ptcrb-plan.md`):
- A self-charging GPS tracker that **fits into a Quad Lock phone case ring insert** — invisible to the patient, can't be forgotten like a wearable.
- **nRF9160 SiP** cellular modem (LTE-M/NB-IoT) for location reporting independent of the host phone.
- **Qi wireless energy harvesting** — powered by the host phone's reverse wireless charging (charging states: `charging_qi`, `charging_reverse`, `charging_pogo`, `on_battery`).
- BLE 5.0, LiPo battery.
- **Killer feature:** when the patient's phone battery dies, the tracker keeps reporting and **auto-escalates to emergency tracking**, alerting all caregivers.

**Software concept:** Caregivers register devices, watch live locations on Google Maps, control tracking cadence (Normal / Emergency / Idle), get push alerts (low battery, phone dead, offline, geofence breaches), navigate to the patient, and **share a full missing-person alert package with law enforcement** (identity, physical description, medical info, behavior-when-lost, vehicle, last location, photo).

**Business status** (memory/ROADMAP.md, session-log.md):
- Tier 4 project ("Lumina/QuadTrack — emergency response; prior art search, patent filing").
- Prior art search completed 2026-03 → **MEDIUM risk** (`memory/research/quadtrack-prior-art.md`, full report in `docs/quadtrack-prior-art-research.md`). No single product combines phone-case form factor + Qi harvesting + dementia care, but each component area has prior art (AngelSense, GPS SmartSole, Jiobit, Otiom, BoundaryCare).
- Provisional patent filing was targeted for April 2026 (pending).
- **nRF9160-DK dev kit purchased** 2026-03-22 ($202.25, DigiKey order #98175449) for firmware prototyping.
- FCC/PTCRB certification plan written (`memory/projects/quadtrack-fcc-ptcrb-plan.md`): ~$15–20K realistic, 8–10 weeks; explicitly **deferred as premature until product-market fit**.
- A separate `quadtrack_backend` repo exists under `/Users/leonherbert/development` (backend-only, no bug reporter — mentioned in session-log).

**No physical hardware exists yet.** All device-side traffic is simulated via `scripts/quadtrack-ping-simulator.js`.

---

## 2. Current Status & Completeness

### What is built and appears complete (code-level)
- Full data model (`QuadTrackDevice`, `QuadTrackPing`, 4 enums) with Firestore serialization.
- Full service layer (register, streams, tracking-mode control, caregiver sharing, emergency lifecycle, phone-battery escalation, ping history).
- Riverpod providers for every read path.
- 6 screens + 2 widgets (dashboard w/ map, detail w/ trail + battery gauges + mode selector, 4-step registration wizard, live navigate screen, LE share screen, 5-step missing-person profile setup).
- 4 Cloud Functions (ping ingestion HTTP endpoint, geofence evaluation trigger, 15-min health check, command polling endpoint) — written, deployed status unverified.
- Firestore composite indexes for pings and emergencies.
- Ping simulator script for hardware-free testing.

### What has NEVER worked in production — critical history
- **Firestore rules for `quadtrack_devices` / `quadtrack_pings` / `quadtrack_emergencies` were MISSING ENTIRELY until 2026-07-07.** Every caregiver-dashboard device query returned `PERMISSION_DENIED` since first deploy (CHANGELOG 2026-07-07). The service's `handleError` handlers swallowed these into empty lists, so the UI silently showed "No devices". Rules were added 2026-07-07 but **as of the pause the `firebase deploy --only firestore` may still be pending** (CHANGELOG note: "All need `firebase deploy --only firestore`").
- Consequence: **the entire feature is effectively device-untested end-to-end.** Nothing downstream of the first Firestore read has ever been exercised live by a caregiver account.

### Rules still missing even after the 2026-07-07 fix (found during this audit)
- **`quadtrack_commands` has NO rules** — but the Flutter client writes to it directly (`QuadTrackService.updateTrackingMode`, `activateEmergencyTracking`, `deactivateEmergency`, `removeDevice`). All tracking-mode changes from the app will be PERMISSION_DENIED until rules are added. (The Cloud Function `quadTrackCommand` reads it via Admin SDK, which bypasses rules.)
- **`quadtrack_shares` has NO rules** — the LE share screen logs every share to this collection; those writes will be denied (the share itself still goes out via SMS/share sheet, but the audit log write fails).

### Known bugs / mismatches (found during this audit — fix on resume)
1. **Ping schema mismatch, ingestion vs. app.** `ingestQuadTrackPing` (Cloud Function) writes pings as flat `{lat, lng, battery, phoneBattery, receivedAt}`. The Dart `QuadTrackPing.fromFirestore` expects `{location: GeoPoint, batteryLevel, phoneBatteryLevel, timestamp}`. Function-ingested pings have **no `timestamp` field, so `orderBy('timestamp')` queries exclude them entirely** — hardware pings would never appear in the app. The simulator writes the Dart-compatible shape, which is why simulator testing "works" while real ingestion wouldn't. (`evaluateQuadTrackGeofences` defensively handles both shapes: `ping.location?.latitude || ping.lat`.) **Decide one canonical ping schema and align function + model + simulator.**
2. **TrackingMode enum mismatch.** Dart: `normal(30 min)` / `emergency(5 min)` / `idle(240 min)`. Cloud Functions use a mode `'active'` that doesn't exist in Dart, and return `nextPingSeconds` of 60 (default) / 10 (emergency) / 30 (active) / 300 (idle) — completely different cadence semantics from the Dart `intervalMinutes`. The health-check offline threshold (2× expected interval, i.e., 20s–10min) is calibrated to the function's seconds, not the app's minutes — with 30-min normal pings, the health check would mark every device offline.
3. **Rename is a stub bug.** `quadtrack_detail_screen.dart` `_showRenameDialog` Save button calls `updateTrackingMode(deviceId, device.trackingMode)` as a placeholder with `// TODO: Implement rename in service`. There is no `renameDevice` in the service.
4. **Registration uses dummy patients.** `quadtrack_register_screen.dart` has `_dummyPatients = ['Patient 1','Patient 2','Patient 3']` producing fake IDs `patient_0/1/2` — never wired to real linked patients (`caregiverProvider` patients). Registered devices point at nonexistent patient IDs, which breaks the share screen (loads `user_profiles`/`users`/`health_profiles` by patientId) and geofence evaluation.
5. **`QuadTrackProfileSetupScreen` is orphaned** — no navigation route anywhere in `lib/` references it (ROADMAP confirms: "Lumina/QuadTrack: Hook profile setup — deferred to Q3"). It also writes `user_profiles/{id}` with a client-generated `profile_<millis>` doc ID instead of looking up/merging the patient's existing profile doc, so it can create duplicate profiles.
6. **Device create rule vs. caregiver ID.** Rules compare `caregiverIds` against `request.auth.uid`, but the app builds `caregiverId` from `caregiverNotifierProvider.caregiver?.id ?? appState.currentCaregiverId`. If caregiver doc IDs are not auth UIDs, every rule check fails. Verify caregiver doc ID == FirebaseAuth UID before trusting the rules.
7. **`patientDevicesProvider` can't pass rules.** `getDevicesForPatient` queries by `patientId`, but read rules only allow `caregiverIds.hasAny([request.auth.uid])` — a patient reading their own devices is denied. (Currently unused by any screen, so latent.)
8. **Simulator default project is wrong.** `quadtrack-ping-simulator.js` defaults `--project ssa-bug-dashboard` (the task-tracker project). Lumina's Firebase project is **`lumina-sosmartapps`**. Always pass `--project lumina-sosmartapps`. It also POSTs to the Firestore REST API unauthenticated — only works if rules allow it (they don't: pings require auth) or with an auth token added.
9. **Navigate screen leaks its Geolocator stream** — `_startLocationStream()` never stores/cancels the subscription in `dispose()`.
10. **Detail/dashboard map style issues** — `_updateMapContent` is called inside `build` (setState-during-build risk, mitigated only on dashboard via postFrameCallback); dashboard camera starts at `(0,0)` if first device has no location.

### What was verified historically
- 2026-03-21 (CHANGELOG): emergency-mode wiring code-reviewed ("updateTrackingMode() writes commands, notifies caregivers; activeEmergencyProvider streams state"), dashboard inclusion confirmed. **Code-review only — never a device test.**
- 2026-07-06: the app-wide `ElevatedButtonTheme minimumSize` fix touched one unwrapped ElevatedButton in a quadtrack dialog (fixed, not broken, by the change).

---

## 3. Architecture

**Stack:** Flutter + Riverpod (StreamProvider.family pattern), cloud_firestore, google_maps_flutter, geolocator, geocoding, url_launcher, share_plus, image_picker, firebase_storage. Cloud Functions are TypeScript v1-style (`functions.https.onRequest`, `functions.firestore.document(...).onCreate`, `functions.pubsub.schedule`).

### 3.1 Model — `lib/core/models/quadtrack_device.dart`
Exported app-wide via `lib/core/models/models.dart` (`export 'quadtrack_device.dart';`).

**`class QuadTrackDevice`** — fields:
| Field | Type | Notes |
|---|---|---|
| `id` | String | Firestore doc ID (auto) |
| `deviceId` | String | Hardware serial / IMEI; used as device auth key by ingest function |
| `name` | String | Friendly name ("Mom's Phone") |
| `patientId` | String | Patient (user) being tracked |
| `caregiverIds` | List\<String\> | Who can see the tracker (rules key on this) |
| `registeredBy` | String | Caregiver who set it up |
| `lastLocation` | GeoPoint? | |
| `lastAccuracy` | double? | |
| `lastSeenAt` | DateTime? | |
| `lastSource` | LocationSource | gps default |
| `trackerBatteryLevel` | int (default 100) | tracker's own battery |
| `phoneBatteryLevel` | int? | host phone battery (from companion) |
| `chargingState` | ChargingState | default unknown |
| `trackingMode` | TrackingMode | default normal |
| `status` | DeviceStatus | default offline |
| `firmwareVersion` | String? | |
| `emergencyIntervalMinutes` | int? | smart interval while in emergency |
| `emergencyActivatedAt` / `emergencyActivatedBy` | DateTime? / String? | |
| `createdAt` / `updatedAt` | DateTime | `toFirestore()` always stamps updatedAt = now |

Getters: `isPhoneDead` (phoneBattery == 0 or status == phoneDead), `isBatteryLow` (< 20), `lastSeenAgo` (human string: "Just now"/"5m ago"/"3h ago"/"2d ago"/"Never"). Has `fromFirestore(doc)`, `toFirestore()`, `copyWith(...)`.

**Enums** (all with `value` string, `fromString` with safe fallback):
- `TrackingMode`: `normal('normal','Normal',30)` · `emergency('emergency','Emergency',5)` · `idle('idle','Idle',240)` — third member is `intervalMinutes` (default; overridden by `emergencyIntervalMinutes`).
- `DeviceStatus`: `online` · `offline` · `sleeping` · `phoneDead('phone_dead')` · `lowBattery('low_battery')`.
- `ChargingState`: `chargingQi('charging_qi','Wireless Charging')` · `chargingReverse('charging_reverse','Reverse Charging')` · `chargingPogo('charging_pogo','Pogo Pin Charging')` · `onBattery('on_battery')` · `unknown`.
- `LocationSource`: `gps` · `wifi` · `cell`.

**`class QuadTrackPing`** — fields: `id`, `deviceId`, `location` (GeoPoint), `accuracy?`, `altitude?`, `batteryLevel` (int), `phoneBatteryLevel?`, `chargingState`, `source`, `timestamp`. `fromFirestore` / `toFirestore`.

### 3.2 Service — `lib/core/services/quadtrack_service.dart`
`class QuadTrackService` (plain class, direct `FirebaseFirestore.instance`; imports `notification_service.dart` for `NotificationService.notifyCaregivers`). Every stream has `.handleError` that logs + returns empty (this is what masked the missing-rules failure). Methods:

- `Future<QuadTrackDevice> registerDevice({deviceId, name, patientId, caregiverId})` — creates `quadtrack_devices` doc, caregiverIds=[caregiverId], status offline, mode normal.
- `Stream<List<QuadTrackDevice>> getDevicesForCaregiver(caregiverId)` — `where caregiverIds arrayContains`.
- `Stream<List<QuadTrackDevice>> getDevicesForPatient(patientId)` — `where patientId ==`.
- `Stream<QuadTrackDevice?> getDevice(deviceId)` — doc snapshot stream (note: takes the **doc ID**, not hardware serial).
- `Future<void> updateTrackingMode(deviceId, TrackingMode mode)` — updates device; if emergency: writes `quadtrack_commands/{deviceId}` (`command:'set_tracking_mode', mode:'emergency', intervalMinutes, acknowledged:false`), sets status online, notifies caregivers ("🚨 Emergency Tracking Activated", data type `quadtrack_emergency`).
- `Future<void> addCaregiver(deviceId, caregiverId)` / `removeCaregiver(...)` — arrayUnion/arrayRemove.
- `Future<void> removeDevice(deviceId)` — deletes device + all its `quadtrack_commands`.
- `Future<List<QuadTrackPing>> getLocationHistory(deviceId, {start, end, limit=200})` — pings where deviceId ==, orderBy timestamp desc, optional range.
- `Stream<List<QuadTrackPing>> streamLatestPings(deviceId, {limit=1})`.
- `Future<void> reportPhoneBattery(deviceId, level)` — updates phoneBatteryLevel; if 0: status=phone_dead, mode=emergency, writes command (`reason:'phone_battery_dead'`), notifies ("🔴 Phone Battery Dead", type `quadtrack_phone_dead`). **Intended to be called by a companion-app path; nothing calls it yet.**
- `int _calculateSmartInterval(battery)` — battery-aware emergency cadence: >80→1 min, ≥50→3, ≥20→5, ≥10→10, else 15.
- `Future<void> activateEmergencyTracking({deviceId, caregiverId, reason})` — creates `quadtrack_emergencies` doc (`activatedBy, reason, startedAt, intervalMinutes (smart), trackerBatteryAtStart, endedAt:null`), updates device (mode emergency, status online, emergencyIntervalMinutes/ActivatedAt/By), writes command, notifies. **Not yet called from any screen** (detail screen uses plain `updateTrackingMode` instead).
- `Future<void> deactivateEmergency(deviceId)` — closes open emergency (sets endedAt), resets device to normal, writes 'normal' command, notifies ("✓ Emergency Tracking Ended"). **Also not called from UI yet.**
- `Stream<Map<String,dynamic>?> getActiveEmergency(deviceId)` — emergencies where deviceId == && endedAt isNull, limit 1.
- `Future<bool> isDeviceRegistered(serial)` — devices where deviceId == serial.

### 3.3 Providers — `lib/core/providers/quadtrack_provider.dart`
- `quadTrackServiceProvider` — `Provider<QuadTrackService>`.
- `selectedDeviceProvider` — `NotifierProvider<_SelectedDeviceNotifier, String?>` (currently unused by screens).
- `caregiverDevicesProvider` — `StreamProvider.family<List<QuadTrackDevice>, String>` (caregiverId).
- `patientDevicesProvider` — same, keyed by patientId (unused).
- `deviceDetailProvider` — `StreamProvider.family<QuadTrackDevice?, String>` (device doc ID).
- `devicePingsProvider` — `StreamProvider.family<List<QuadTrackPing>, String>` — streamLatestPings limit 50.
- `deviceHistoryProvider` — `FutureProvider.family<List<QuadTrackPing>, ({String deviceId, int days})>` (unused by screens).
- `deviceRegistrationCheckProvider` — `FutureProvider.family<bool, String>` (screens call the service directly instead).
- `activeEmergencyProvider` — `StreamProvider.family<Map<String,dynamic>?, String>` (unused by screens).

`lib/core/providers/providers.dart` (lines 103–104) contains only a tombstone comment: `// QuadTrack device tracking — canonical provider is in quadtrack_provider.dart` `// (removed duplicate quadTrackServiceProvider to avoid compile error)`.

### 3.4 Screens — `lib/features/quadtrack/`

| File | Purpose | Completeness |
|---|---|---|
| `quadtrack_dashboard_screen.dart` | `QuadTrackDashboardScreen(caregiverId)`. Google Map (250px) with status-colored markers (green online / yellow sleeping / red offline-lowBattery-phoneDead) + DeviceCard list + FAB → register. Empty state with "Register Device" CTA. RefreshIndicator invalidates provider. | Complete; camera at (0,0) if no location; `patientName: null` TODO in card. |
| `quadtrack_detail_screen.dart` | `QuadTrackDetailScreen(deviceId, caregiverId)`. 300px map with green marker + blue polyline trail from last 50 pings; buttons → Navigate + "Share with Law Enforcement"; info card (name/status/lastSeen/firmware); Battery card (two `BatteryGauge`s: tracker + phone); Tracking Mode 3-button row → confirm dialog; last-10 ping history; popup menu Rename (STUB/bug) + Remove (confirm dialog). | Mostly complete; rename stub; uses `updateTrackingMode` not the battery-aware `activateEmergencyTracking`. |
| `quadtrack_register_screen.dart` | 4-step wizard: Serial (≥10 chars, duplicate check via `isDeviceRegistered`) → Name → Patient (**DUMMY list**) → Review → `registerDevice` → pushReplacement to detail. | UI complete; blocked on real patient wiring. |
| `quadtrack_navigate_screen.dart` | Live caregiver Geolocator stream (best accuracy, 10m filter) vs. tracker position; blue/red markers, connecting polyline, auto-fit bounds; bottom panel with battery badge, haversine distance, naive ETA (50 km/h assumption), last ping; "Open in Google Maps" deep link. | Complete; stream never cancelled (leak); ETA is straight-line. |
| `quadtrack_share_screen.dart` | LE missing-person alert. Loads `user_profiles/{patientId}`, `users/{patientId}`, `health_profiles` (where userId==), active `users/{id}/health_conditions`. Reverse-geocodes last location. Builds huge text alert (identity, physical, medical, behavior-when-lost, vehicle, last location + maps link, frequent places, emergency contacts, photo URL, home address, wandering history, "Sent via Lumina QuadTrack"). Send paths: SMS (with >160-char multi-part warning), clipboard, share sheet; each logs to `quadtrack_shares`. Preview card + Google Maps card. | Complete and the most polished screen; share-log writes blocked by missing rules; potential null crash if `_userProfile` null but `_healthProfile`/conditions non-null (MEDICAL section uses `_userProfile!`). |
| `quadtrack_profile_setup_screen.dart` | 5-step PageView (Identity+photo via camera → Physical → Medical/behavior → Vehicle → Review) writing a `UserProfile` to `user_profiles` (+ photo to Storage `user_profiles/`). | Built but **orphaned** — no navigation reaches it; doc-ID strategy conflicts with existing profile docs. |
| `widgets/device_card.dart` | `DeviceCard(device, patientName?, onTap)` — status dot, name, lastSeen, tracker+phone linear battery bars (green/orange/red at 50/20), TrackingMode chip, red "Phone Battery Dead — Emergency Tracking Active" banner when `isPhoneDead`. | Complete. |
| `widgets/battery_gauge.dart` | `BatteryGauge(percentage, label, chargingState, isPhoneBattery)` — animated 120px circular gauge, color by level, charging emoji (⚡/🔌/📌) + state label. | Complete. |

---

## 4. Firestore Schema & Security

Firebase project: **`lumina-sosmartapps`** (bundle `com.carecompanion.lumina`).

### 4.1 Collections

**`quadtrack_devices/{autoId}`** — shape per `QuadTrackDevice.toFirestore()`:
```
deviceId, name, patientId, caregiverIds[], registeredBy,
lastLocation (GeoPoint|null), lastAccuracy, lastSeenAt (Timestamp|null), lastSource,
trackerBatteryLevel, phoneBatteryLevel, chargingState, trackingMode, status,
firmwareVersion, emergencyIntervalMinutes, emergencyActivatedAt, emergencyActivatedBy,
createdAt, updatedAt
```

**`quadtrack_pings/{autoId}`** — TWO shapes currently in play (BUG, see §2.3 #1):
- App/simulator shape (`QuadTrackPing.toFirestore()`): `deviceId, location (GeoPoint), accuracy, altitude, batteryLevel, phoneBatteryLevel, chargingState, source, timestamp (Timestamp)`.
- Cloud Function ingest shape: `deviceId, lat, lng, accuracy, altitude, battery, phoneBattery, chargingState, source, receivedAt (serverTimestamp)`.

**`quadtrack_emergencies/{autoId}`** (written by `activateEmergencyTracking`): `deviceId, activatedBy, reason, startedAt (serverTimestamp), intervalMinutes, trackerBatteryAtStart, endedAt (null until closed)`.

**`quadtrack_commands/{deviceId}`** (doc ID = device doc ID from app; ingest/poll side keys by hardware serial — another latent mismatch to verify): `deviceId, command:'set_tracking_mode', mode, intervalMinutes, reason?, createdAt, acknowledged:false`. Deleted by `quadTrackCommand` function after retrieval.

**`quadtrack_shares/{autoId}`** (share audit log): `deviceId, patientId, sharedBy, sharedWith (phone|'share_sheet'), method ('sms'|'share'), messageLength, sharedAt, locationAtShare (GeoPoint), battery`.

Related non-quadtrack collections the feature touches: `user_profiles`, `users` (+ `users/{id}/health_conditions`, `users/{id}/geo_zones`), `health_profiles`, `caregivers` (for `fcmToken`), `geo_zone_events` (geofence alerts written by function).

### 4.2 Rules — `firestore.rules` (added 2026-07-07; deploy may still be pending)
```
// QuadTrack GPS devices (rules were missing entirely — every
// dashboard query was denied; added 2026-07-07)
match /quadtrack_devices/{deviceId} {
  allow read: if isAuthenticated() &&
    resource.data.caregiverIds.hasAny([request.auth.uid]);
  allow create: if isAuthenticated() &&
    request.resource.data.caregiverIds.hasAny([request.auth.uid]);
  allow update, delete: if isAuthenticated() &&
    resource.data.caregiverIds.hasAny([request.auth.uid]);
}

match /quadtrack_pings/{pingId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated();
}

match /quadtrack_emergencies/{emergencyId} {
  allow read: if isAuthenticated();
  allow create, update: if isAuthenticated();
}
```
Gaps: **no rules for `quadtrack_commands` or `quadtrack_shares`** (client writes both → denied); pings/emergencies rules are broad (any authed user); device rules assume caregiver doc ID == auth UID; `patientId`-based reads not allowed. Per §Firebase Pre-Flight workflow, re-verify all four surfaces before resume.

### 4.3 Indexes — `firestore.indexes.json` (created 2026-03-21)
- `quadtrack_pings`: `deviceId ASC + timestamp DESC` (streams/history) and `deviceId ASC + timestamp ASC`.
- `quadtrack_emergencies`: `deviceId ASC + endedAt ASC` (active-emergency isNull query).
Deploy: `firebase deploy --only firestore:indexes`.

---

## 5. Cloud Functions — `functions/src/index.ts`

Four QuadTrack functions (under the `// QUADTRACK LOCATION TRACKING` banner, ~line 1004+), plus one metrics touchpoint:

1. **`ingestQuadTrackPing`** (HTTPS POST, ~line 1011) — hardware ingestion endpoint. Auth via `X-Device-Key` header matched against `quadtrack_devices.deviceId`. Body: `{lat, lng, accuracy?, altitude?, battery, phoneBattery?, chargingState?, source?}`. Stores ping (flat shape — see bug), updates device (lastLocation/lastSeenAt/battery/status:'online'), returns `{success, nextPingSeconds}` (emergency 10s / 'active' 30s / idle 300s / default 60s). Battery <20 → status 'low_battery' + FCM multicast to caregiver `fcmToken`s ("🔋 QuadTrack Low Battery"). phoneBattery transitions to 0 → status 'phone_dead', mode 'emergency', urgent FCM ("🚨 URGENT: Phone Dead").
2. **`evaluateQuadTrackGeofences`** (Firestore onCreate `quadtrack_pings/{pingId}`, ~line 1198) — finds device by ping.deviceId, loads active `users/{patientId}/geo_zones`, haversine check: outside `safe`/`home` zone → `left_safe_zone`; inside `danger` zone → `entered_danger_zone`. Writes `geo_zone_events` doc + FCM to caregivers ("⚠️ Left Safe Zone" / "🚨 Entered Danger Zone"). Tolerates both ping shapes.
3. **`quadTrackHealthCheck`** (pubsub every 15 minutes, ~line 1348) — devices with status != 'offline': if lastSeenAt older than 2× expected interval (per the *seconds-based* mode table) → status 'offline' + FCM "📡 Device Offline". **Interval table conflicts with Dart minutes — see bug §2 #2.** Also note: a 15-min schedule can't meaningfully enforce 20-second timeouts.
4. **`quadTrackCommand`** (HTTPS GET `?deviceId=`, ~line 1443) — device polls for pending command at `quadtrack_commands/{deviceId}`; returns and deletes it. No device-key auth on this endpoint (anyone can consume commands — harden on resume).

Touchpoint: **`publishToApexLife`** (pubsub, ~line 934) counts `quadtrack_devices` (active = status != 'offline', collects offline device names) into its daily metrics payload (`activeQuadTrackDevices`, `offlineQuadTrackDevices`). **This stays even while the UI is paused** — it degrades gracefully to 0/undefined.

---

## 6. Integration Points (removed from UI 2026-07-07 — re-wire exactly like this)

All hooks lived in **`lib/features/caregiver/caregiver_dashboard_screen.dart`**. Nothing on the patient/user-home side referenced QuadTrack. Exact wiring that was in place:

### 6.1 Imports (top of caregiver_dashboard_screen.dart, lines ~10–11 and ~40)
```dart
import '../../core/providers/quadtrack_provider.dart';
import '../../core/models/quadtrack_device.dart' show DeviceStatus;
...
import '../quadtrack/quadtrack_dashboard_screen.dart';
```

### 6.2 Overview-tab status card (call site ~line 298, after `BatteryStatusCard`)
```dart
          // QuadTrack devices
          _buildQuadTrackCard(),
          const SizedBox(height: 12),
```
Backed by the method `_buildQuadTrackCard()` (~lines 524–653): resolves `caregiverId` from `ref.read(caregiverNotifierProvider).caregiver?.id ?? ref.read(appStateNotifierProvider).currentCaregiverId ?? ''` (returns `SizedBox.shrink()` if empty), watches `caregiverDevicesProvider(caregiverId)`, and renders a white rounded card — teal `Icons.track_changes` badge, title **'QuadTrack Devices'**, subtitle either `'No devices registered'` or a row of `'$online online'` (green dot) + `'$alerts alert(s)'` (orange warning, alerts = lowBattery + phoneDead + offline) + `'${devices.length} total'` (Flexible/ellipsis), chevron. Tapping the whole card:
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (context) => QuadTrackDashboardScreen(caregiverId: caregiverId),
));
```
Loading/error states render `SizedBox.shrink()`.

### 6.3 Manage-tab tile (~lines 843–861, between 'User Profile' and 'Saved Locations')
```dart
          _buildManageItem(
            'QuadTrack Devices',
            'GPS trackers for patient safety',
            Icons.track_changes,
            AppTheme.primaryTeal,
            () {
              final caregiverId = ref.read(caregiverNotifierProvider).caregiver?.id ??
                  ref.read(appStateNotifierProvider).currentCaregiverId ??
                  '';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuadTrackDashboardScreen(
                    caregiverId: caregiverId,
                  ),
                ),
              );
            },
          ),
```

### 6.4 Passive integration points that should REMAIN during the pause
- `lib/core/models/models.dart`: `export 'quadtrack_device.dart';` (harmless barrel export).
- `lib/core/providers/providers.dart` lines 103–104: tombstone comment only.
- `functions/src/index.ts`: all 4 quadtrack functions + `publishToApexLife` counting (server-side, harmless with zero devices).
- `firestore.rules` quadtrack blocks + `firestore.indexes.json` quadtrack indexes (keep deployed so resume is easier).
- Internal navigation between quadtrack screens (dashboard→register/detail→navigate/share) is self-contained inside `lib/features/quadtrack/` and needs no changes.

---

## 7. Remaining Work / TODO (in dependency order)

1. **Deploy the 2026-07-07 rules** if not yet done: `firebase deploy --only firestore` (Terminal, from `/Users/leonherbert/development/lumina`).
2. **Add missing rules** for `quadtrack_commands` (client write/update/delete by device caregivers) and `quadtrack_shares` (create by authed caregiver), then redeploy. Run the Firebase pre-flight (`memory/workflows/firebase-preflight.md`).
3. **Verify caregiver doc ID == auth UID**; if not, key `caregiverIds` on auth UIDs (or change rules to look up the caregiver doc).
4. **Unify the ping schema** — pick the Dart shape (`location` GeoPoint + `batteryLevel` + `timestamp`), update `ingestQuadTrackPing` to write it (keep `receivedAt` as extra), update `evaluateQuadTrackGeofences`, redeploy functions.
5. **Unify TrackingMode semantics** — remove 'active' from functions or add it to Dart; make `nextPingSeconds` derive from the device's `emergencyIntervalMinutes`/mode `intervalMinutes`; recalibrate `quadTrackHealthCheck` thresholds (and its 15-min schedule floor).
6. **Wire real patients into registration** — replace `_dummyPatients` with the caregiver's linked patients (same source the rest of the caregiver dashboard uses).
7. **Implement `renameDevice(deviceId, name)`** in the service and fix `_showRenameDialog`.
8. **Hook up battery-aware emergency** — detail screen should call `activateEmergencyTracking`/`deactivateEmergency` (and surface `activeEmergencyProvider`), not bare `updateTrackingMode`.
9. **Hook `QuadTrackProfileSetupScreen`** into a flow (post-registration prompt and/or User Profile screen) and make it load-then-merge the existing `user_profiles` doc for the patient instead of creating `profile_<millis>` duplicates.
10. Fix navigate-screen stream leak; guard share screen's MEDICAL section `_userProfile!` derefs; add reason prompt for emergency; harden `quadTrackCommand` with device-key auth.
11. **End-to-end test with simulator** (see checklist) — this feature has never had a live pass.
12. Companion-app phone-battery reporting (`reportPhoneBattery` caller) — currently nothing invokes it; the ingest path's `phoneBattery` field is the only live source.
13. Hardware track (separate from app): nRF9160-DK firmware prototype → talk to `ingestQuadTrackPing`/`quadTrackCommand`; certification per `memory/projects/quadtrack-fcc-ptcrb-plan.md` only after product-market fit.

---

## 8. Resume Checklist (re-enable in the UI)

1. **Re-add the three hooks** to `lib/features/caregiver/caregiver_dashboard_screen.dart` exactly as quoted in §6.1–6.3 (imports, overview card call + `_buildQuadTrackCard()` method if it was deleted rather than orphaned — check the file first, and pull the full method body from §6.2/git history `git log -p -- lib/features/caregiver/caregiver_dashboard_screen.dart`).
2. `flutter analyze` — expect zero new issues (all quadtrack lib files remained in-tree and compiling during the pause).
3. Confirm rules/indexes deployed: `firebase deploy --only firestore` (Terminal). Verify in console that `quadtrack_devices` reads succeed for a signed-in caregiver.
4. Work TODO items 2–8 (§7) before any device test — registration is unusable for real data until #6.
5. **Simulate**: register a device in-app (note its doc… serial), then in Terminal:
   `node scripts/quadtrack-ping-simulator.js --deviceId <serial-or-docId-see-§4.1-commands-note> --project lumina-sosmartapps --pattern walk --count 30`
   (add auth or temporarily relax ping rules; verify which ID the pings should carry — service queries pings by the value stored in `deviceId` field of the ping vs. device docs' hardware `deviceId`; the app streams pings by **device doc ID** (`streamLatestPings(deviceId)` is called with `device.id`) while the simulator docs say "device document ID" — keep them consistent).
6. Walk every screen per `memory/workflows/ui-formatting-checklist.md` (dashboard, detail, register, navigate, share, profile setup) on the dev iPhone (`00008150-00010C5E3EB8C01C`).
7. Test push paths: emergency activation notification, low-battery (simulate `--battery 15`), phone-dead (`reportPhoneBattery(id, 0)` or ingest with phoneBattery 0), geofence event (needs an active geo_zone for the patient).
8. Mark the Dev Planner task done (`node ../dev-tracker/mark-done.js --app "Lumina" --title "quadtrack"`) and log to CHANGELOG.md.

---

## 9. Related Files & Docs (absolute paths)

| Artifact | Path |
|---|---|
| Model | `/Users/leonherbert/development/lumina/lib/core/models/quadtrack_device.dart` |
| Service | `/Users/leonherbert/development/lumina/lib/core/services/quadtrack_service.dart` |
| Providers | `/Users/leonherbert/development/lumina/lib/core/providers/quadtrack_provider.dart` |
| Screens + widgets | `/Users/leonherbert/development/lumina/lib/features/quadtrack/` (6 screens, `widgets/device_card.dart`, `widgets/battery_gauge.dart`) |
| Dashboard hooks (removed) | `/Users/leonherbert/development/lumina/lib/features/caregiver/caregiver_dashboard_screen.dart` (§6) |
| Cloud Functions | `/Users/leonherbert/development/lumina/functions/src/index.ts` (lines ~934, 1011, 1198, 1348, 1443) |
| Rules / Indexes | `/Users/leonherbert/development/lumina/firestore.rules` (§4.2) · `firestore.indexes.json` (§4.3) |
| Ping simulator | `/Users/leonherbert/development/lumina/scripts/quadtrack-ping-simulator.js` |
| Prior art (full) | `/Users/leonherbert/development/lumina/docs/quadtrack-prior-art-research.md` |
| Prior art (summary) | `/Users/leonherbert/development/memory/research/quadtrack-prior-art.md` |
| FCC/PTCRB plan | `/Users/leonherbert/development/memory/projects/quadtrack-fcc-ptcrb-plan.md` |
| Hardware kit | nRF9160-DK, purchased 2026-03-22 (session-log.md) |
| Backend repo | `/Users/leonherbert/development/quadtrack_backend` (backend-only; not audited here) |

*Snapshot compiled 2026-07-07 by full read of all files above.*
