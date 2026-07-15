# Lumina - Development Changelog

<!-- Claude will automatically log completed work here. -->
<!-- Format: Date - Build Number - Summary heading, then bullet points of what changed. -->

## 2026-07-15 - Legal acceptance gate (ToS/indemnity) — implemented, NOT device-tested

- **Blocking Terms of Use / liability waiver before ANY app use** — including first launch, ahead of onboarding. Gate at the splash `_navigateTo()` choke point covers all 4 destinations (setup, patient home, caregiver login/dashboard). Scroll-through terms, 4 mandatory checkboxes, decline = review-again-or-close-app, Android back blocked, fail-closed on errors.
- **New files**: `docs/legal/TERMS_OF_USE.md` (canonical, DRAFT pending attorney), `docs/legal/LEGAL-IMPLEMENTATION.md` (full system map — read this first), `lib/core/legal/legal_terms.dart` (`kTermsVersion` = re-acceptance trigger), `lib/core/services/legal_service.dart`, `lib/features/legal/legal_gate_screen.dart`, `lib/core/widgets/emergency_disclaimer_banner.dart`.
- **Acceptance storage**: local prefs (gates offline) + immutable `legal_acceptances` Firestore audit log (new rule in `firestore.rules` — NEEDS DEPLOY) + `legalAcceptance` stamp on caregiver/user docs; offline acceptances back-sync via `ensureRemoteSync()` each launch.
- **Point-of-use "not an emergency service" banners**: manage zones, monitoring settings, QuadTrack dashboard. Settings gained a read-only "Terms of Use" viewer row.
- **Open**: rules deploy, device tests, attorney review (checklist in TERMS_OF_USE.md), Privacy Policy still missing. Dev Planner tasks filed.

## 2026-07-15 (pm) - Android pass (Pixel 10 Pro XL): legal gate + QuadTrack verified, 3 fixes, perf bug isolated

- **Legal acceptance gate DEVICE-VERIFIED on Android**: decline blocks entry ✓, accept → app ✓, relaunch no-gate ✓.
- **Geofence breach push DEVICE-VERIFIED on Android**: both zone banners in shade, tap deep-links to Device Details. Note: shade-only, no heads-up popup — task filed (needs IMPORTANCE_HIGH channel).
- **LE share SMS DEVICE-VERIFIED on Android end-to-end**: Messages opens pre-filled dispatch text → sent → received on iPhone → NAVIGATE link opens turn-by-turn (5-min route to pin). iPhone shows link non-tappable (iOS unknown-sender anti-spam — expected; copy-resilience task filed).
- **Fix 1 — Android package visibility**: manifest had NO `<queries>` block → `canLaunchUrl` false for sms/tel/mailto/https → SMS path silently dead. Added queries for SENDTO(sms/mailto), DIAL, VIEW(https).
- **Fix 2 — share-screen rebuild loop**: `FutureBuilder(future: _getAddress(...))` created a new geocode future every build. Memoized (`_addressFor`).
- **Fix 3 — invite gap unblocked for testing**: invite redemption never syncs `quadtrack_devices.caregiverIds` → Google-UID caregiver (Pixel) couldn't see the device. Patched caregiverIds manually; HIGH-priority Cloud Function sync task filed.
- **PERF BUG isolated (open, high)**: 15–22MB GC every ~150ms, thousands of skipped frames, 40s main-thread stalls; persists after address-future fix AND hybrid-composition switch (`useAndroidViewSurface=true`, kept). LOS allocation signature suggests repeated full-res photo decodes and/or stacked live GoogleMap views. Matches iPhone EXC_RESOURCE kills. Needs DevTools profiling session — Dev Planner task has full evidence.

## 2026-07-15 - Profile consolidation: QuadTrack wizard DELETED, User Profile is single owner (per Leon)

- **Wizard removed** (`quadtrack_profile_setup_screen.dart` deleted): it duplicated the User Profile tabbed editor (all fields confirmed present in tabs; tabs have more — Documents, Photos, multi-Vehicles, Social Media). QuadTrack register flow + Device Details "Missing-Person Profile" now open `UserProfileScreen` directly.
- **DATA-LOSS BUG found + fixed by the removal**: wizard saves wrote the whole profile but omitted `vehicles`/`socialMediaLinks` arrays → every save overwrote them with empty. Wiped Jack's F150 + Facebook link during testing; restored via Firestore PATCH (photo survived in Storage).
- **Setup Guide gains core "Patient profile" step** (`caregiver_onboarding_screen.dart`): opens User Profile for the selected patient; auto-completes when profile has legal first name + ≥1 photo.
- **Bouncie vehicle autofill** (Vehicles tab editor): "Autofill from Bouncie" button when patient has a Bouncie link — pulls make/model/year/VIN from API, falls back to stored model string. (Bouncie has no plate/color/photos — those stay manual.)
- **Vehicles tab empty-state 46px overflow fixed** (scrollable, mainAxisSize.min) — caught on device.
- **Remove-device bug found + fixed**: `removeDevice` pre-cleanup (commands/serials docs) could hit a rules failure that silently aborted the device deletion, AND the confirm dialog fired-and-forgot the future (always showed "removed"). Now: cleanup is best-effort per-doc, device delete rethrows, dialog awaits + shows explicit failure snackbar. **DEVICE-VERIFIED after fix**: remove → card gone → re-register → profile prompt opens tabbed User Profile → restored vehicles + social media confirmed present.
- **2nd EXC_RESOURCE memory kill** (3376 MB, died in GC scavenger after several hot restarts; google_maps `recreating_view` on every hot restart suggests leaked platform views) — Dev Planner task updated.

## 2026-07-15 - QuadTrack profile wizard DEVICE-VERIFIED (iPhone) + 4 fixes shipped same-session

- **Wizard walked end-to-end + kill-test passed** (data survives app kill mid-wizard). Fixes shipped and device-verified this session (`quadtrack_profile_setup_screen.dart`):
  1. **Imperial units**: Height (ft/in) + Weight (lbs) inputs replace cm/kg (Leon requirement); storage stays metric (no migration; generators already convert). Fields now prefill from existing profile via controllers (previously blank — TextFields had no controllers).
  2. **Keyboard dismissal**: tap-outside (GestureDetector unfocus), scroll-to-dismiss (`keyboardDismissBehavior.onDrag` on all 5 steps), unfocus on page change. Previously multiline Medical fields left NO way to close the keyboard (covered Back/Next).
  3. **Per-step autosave** (Leon requirement): every Next writes the profile doc (`_writeProfile` extracted from save; silent failures logged) — crash/kill loses only the current step.
  4. **Photo upload at capture time**: was upload-only-on-final-save with silently swallowed errors (photo lost on kill; full save didn't persist it either). Now uploads immediately on capture, persists via autosave, shows red snackbar on upload failure, avatar renders stored photo URL (previously only the fresh file).
- **Memory bug found (filed)**: Runner hit EXC_RESOURCE high watermark (3376 MB) during the session — app killed. Separate Dev Planner task.
- **Architecture note (task updated)**: wizard + User Profile screen are two editors over the same profile doc — consolidation task FgFfdlLGmlI3przMCbh6 updated per Leon.

## 2026-07-15 - QuadTrack LE share screen DEVICE-VERIFIED (iPhone) — maps-link bug fixed, new email-formatting bug

- **LE share (missing-person alert) verified**: clipboard, SMS (iMessage delivered), and email send paths all work. Package content correct: identity, physical description, vehicle w/ Storage photo URL, last known location w/ address + coords, emergency contacts, social media, home address.
- **Google Maps link bug NO LONGER REPRODUCES**: email link `https://maps.google.com/?q=32.431,-110.992` clickable and opens correct pin. Marked Dev Planner task done.
- **New bugs found**: (1) email body loses ALL line breaks — whole alert renders as one paragraph in Gmail (SMS/clipboard keep formatting); (2) empty MEDICAL INFORMATION section renders orphan heading when profile has no medical data — should hide; (3) minor: unformatted phone (`5136015092`) vs formatted others; maps-link coords truncated to 3 decimals (~110 m) — use full precision for LE.

## 2026-07-15 - QuadTrack geofence breach + phone-dead escalation DEVICE-VERIFIED (iPhone)

- **Phone-dead escalation verified end-to-end**: backdated `lastSeenAt` (Firestore PATCH) + status reset to online → next `quadTrackHealthCheck` 15-min tick flipped device offline and sent "📡 Device Offline" push → banner with app backgrounded → tap deep-linked to Device Details (status Offline red, Last Seen 3h ago). Threshold confirmed: max(2× ping interval, 10 min); emergency mode interval 5 min → 10-min timeout. Earlier "missed" push at 10:17 was actually delivered as a foreground message (app was foregrounded from breach-banner tap) — same foreground-suppression behavior as geofence pushes.

## 2026-07-15 - QuadTrack geofence breach push DEVICE-VERIFIED (iPhone)

- **Geofence breach push verified end-to-end**: synthetic ping via `ingestQuadTrackPing` (curl, `X-Device-Key: QT-2026-TEST01`) at coords outside both active zones → `evaluateQuadTrackGeofences` fired → "⚠️ Left Safe Zone / Jacks Tracker 1 has left Test" banner on iPhone with app backgrounded → tap deep-linked to Device Details showing the synthetic ping's location + battery (85%/90%). Two zones ("Test" safe, "Home" home) both evaluated.
- **Foreground behavior noted**: with app foregrounded, FCM messages arrive (`Received foreground message` in log) but no banner is shown — no in-app presentation of foreground geofence pushes. Consider surfacing.
- **Missing asset found**: `assets/sounds/alert.mp3` unavailable → TTS fallback used. Needs asset added or pubspec fix.

## 2026-07-14 - Expense/Reimbursement DEVICE-VERIFIED

- **Expense/reimbursement feature device-verified** on Pixel: full flow — add expense, scan receipt, approve, reimburse. Firestore rules (`expenses` collection) and storage rules already deployed.

## 2026-07-14 - Pet Feeding DEVICE-VERIFIED + Reminder day-of-week bug fix

- **Pet feeding reminders device-verified** on Pixel: add/edit/delete feeding schedule, mark-fed, feeding history with timestamps and feeder name. Firestore rules for `pet_feedings`/`feeding_logs` already deployed (07-13).
- **Reminder day-of-week scheduling bug fixed** (`notification_service.dart`): weekly/custom reminders (e.g. "Take out trash — Wednesday only") were firing every day because `scheduleReminder` passed `DateTimeComponents.time` (match time only, repeat daily) for all repeating reminders. Now mirrors the pet-feeding pattern: daily → `DateTimeComponents.time`, weekly/custom with `repeatDays` → one `zonedSchedule` per weekday using `DateTimeComponents.dayOfWeekAndTime`. Added `cancelReminder()` that clears all per-weekday notification IDs. Updated `reminder_service.dart` `deleteReminder` to use new cancel method.

## 2026-07-14 - Vehicles + Social Media DEVICE-VERIFIED (Pixel + iPhone)

- **Vehicles tab device-verified**: add vehicle w/ photo upload (camera + gallery), edit fields, delete vehicle — all confirmed working on Pixel. Storage rule for `vehicle_photos/` deployed (`firebase deploy --only storage`).
- **Social Media tab device-verified**: add Facebook handle for Jack (`jack.groenier`), auto-URL generation confirmed (handle → `facebook.com/jack.groenier`), tap opens in browser. Fixed bug where entering only a handle (no URL) showed "Link removed" — added auto-URL generation for known platforms (Facebook, Instagram, X, TikTok) in `user_profile_screen.dart`.
- **QuadTrack Share**: vehicles + social handles already verified on iPhone (07-08 session); Pixel has no QuadTrack device registered so skipped on Android.

## 2026-07-13 (evening) - Daily Activities DEVICE-VERIFIED + Photo flow streamlined + Call screen fix

- **Daily Activities library device-verified** on iPhone + Pixel 10 Pro XL: caregiver adds from Manage → Daily Activities (16 Montessori templates across 5 categories), activity becomes a Reminder, patient popup fires with TTS, photo verification uploads and triggers Cloud Function (push notification received on caregiver device). Full pipeline confirmed end-to-end.
- **Photo capture flow streamlined** (all task/medication verification): replaced `ImagePicker` system camera dialog with custom `camera` package implementation — full-screen live preview + one-tap shutter button. Auto-uploads immediately after capture, no preview/confirm/retake steps. Reduced from ~4 taps to 2 taps. Also fixed double-pop navigation race where ReminderPopup didn't dismiss after photo (addPostFrameCallback between sequential pops).
- **Call screen overflow fixed**: contact cards overflowed bottom by 9px (avatar radius 40 = 80px in 80px inner height). Bumped card height 120→130.


## 2026-07-13 (pm) - Vehicles + Social Media wired into EXISTING missing-person generators — needs device test

- **Vehicles** (User Profile → new "Vehicles" tab): multiple vehicles per patient, each with make/model/year/color/plate/state/VIN/notes + multiple photos. Photos upload to Storage `vehicle_photos/{patientId}/photo_<uuid>.jpg` (mirrors `user_photos`). New `Vehicle` value class on `UserProfile.vehicles` (embedded array, like `photos`/`frequentPlaces`); legacy single `vehicle*` fields fold in via `allVehicles` getter so older profiles migrate on first edit. Full-screen `_VehicleEditorScreen` (camera/gallery, immediate upload, delete-in-place).
- **Social Media** (User Profile → new "Social Media" tab): Facebook / Instagram / Twitter-X / TikTok fixed rows with linked/not-linked status + brand-ish icons, plus unlimited "Other" links. Each tappable → opens in browser (`url_launcher`, auto-prepends https). Stored as `UserProfile.socialMediaLinks` (embedded array). One link per known platform; multiple "other".
- **Wired into the EXISTING QuadTrack "Share Missing Person Alert" generator** (`quadtrack_share_screen.dart`, opened from a QuadTrack device → Share): both the on-screen preview card and the shareable alert package (SMS/email/clipboard) now use structured `allVehicles` — displayName, plate+state, VIN, notes, and vehicle photo thumbnails (card) / photo URLs (package). New SOCIAL MEDIA section lists platform + handle + URL so the public can pull recent photos. (Previously the vehicle section used only the legacy single-vehicle fields and there was no social media.)
- **Also enriched the text "Lost Person Report"** (`UserProfileService.formatLostPersonReportAsText`, User Profile screen) with VEHICLE(S) (via `allVehicles`, incl. photo URLs) + SOCIAL MEDIA sections.
- **Rules**: `storage.rules` gains `vehicle_photos/{userId}/**` (create<10MB/image, read auth, delete auth). No Firestore rule change — vehicles/social live on the existing `users/{id}/user_profile/profile` doc (covered by the current `user_profile` write rule + catch-all).
- **No new/duplicate flyer feature** — enhanced the generators already in the app. (An earlier iteration mistakenly added a standalone PDF flyer service; removed.)
- Verified: `flutter analyze` clean; model tests for `allVehicles` fold-in + vehicle/social serialization (`test/user_profile_vehicles_social_test.dart`). NOT device-tested — needs: add/edit/delete vehicle + photo capture on device, social link open-in-browser, then open QuadTrack Share and confirm vehicle photos + social handles appear in the preview card and the shared package. **REDEPLOY**: `firebase deploy --only storage`.

## 2026-07-13 (pm) - Caregiver onboarding wizard (Setup Guide) BUILT — needs device test

- **Setup Guide** (`lib/features/onboarding/`): checklist orchestrator that opens the app's REAL screens as steps and auto-detects completion from live data — patient (managedUsers), contacts (emergencyContacts), medications/reminders/safe zones (limit-1 existence probes), invite (codes created OR >1 caregiver), pets (pet_feedings), vehicle (bouncie_connections). Sundown + patient-device steps use confirm-flags in `caregivers/{uid}.onboardingProgress`. 8 core steps + 2 optional, progress bar header, pull-to-refresh.
- **PatientDeviceGuideScreen**: 6-step instructions for setting up the patient's phone (install, permissions, Guided Access/kiosk, test together).
- **Dashboard**: "Finish setting up (X of 8)" nudge card on Overview (hidden when complete or dismissed — dismissal stored as onboardingProgress.dismissed); "Setup Guide" entry in Manage for anytime access.
- No new collections/rules/indexes (probes use existing per-userId equality queries). NOT device-tested — walk all 10 steps, verify auto-detection ticks, confirm flags persist, card hides on dismiss+complete.

## 2026-07-13 - ACCOUNT DELETION SHIPPED (Apple 5.1.1v) + Robert Snith state-leak fix + pet-feeding bridge verified

- **Account deletion device-verified end-to-end** (Apple's #2 rejection reason closed): `deleteCaregiverAccount` + `deletePatient` callables (Admin SDK recursive wipe; patients with other caregivers are unlinked w/ primary reassignment, sole-caregiver patients fully wiped incl. subcollections/invites/keyed docs); Account screen under Manage (sign out + type-DELETE confirmation); long-press patient card → Remove from my care / Delete permanently (primary only).
- **Blockers found+fixed**: appspot SA lacked `roles/firebaseauth.admin` → auth deleteUser threw blank INTERNAL (granted + errors now surface with cause); **Robert Snith incident** — deleted patient rendered from RAM because `CaregiverProvider._selectedUser` survived account switches → `loadCaregiver` now evicts state on account change + validates selection; delete/sign-out clear appState + caregiver provider. Account-switch eviction test added to ui-formatting-checklist; FLEET audit task filed (so_smart_vault + apex_life priority-1; sosmartscans-app Swift included; axon-scanner/STEP have no auth).
- **Pet feeding → patient reminders bridge device-verified** ("Feed Dory" reminders auto-created per feeding time; patient photo completion writes feeding_logs + lastFedAt; caregiver Mark Fed completes the patient reminder). 3rd anonymous-auth rules trap fixed (pet_feedings/feeding_logs uid checks).
- Apple Critical Alerts entitlement submitted (Request ID 86H4R85YY3); daily reply-watcher scheduled. Mute-switch TTS bypass shipped (playback audio category).
- Cost redesign per Leon: hash-match-first verification (on-device dHash, AI only on no-reference/mismatch, Haiku→Sonnet escalation on failures, caregiver override teaches reference).

## 2026-07-12 (evening) - Share-all invites + returning-caregiver onboarding + dangling-id crash fixes (all DEVICE-VERIFIED on Pixel)

- **Share-all-patients invite**: one code, one rules-validated invite doc per patient (rules can't loop arrays, so per-doc premium/primary checks are preserved). Toggle on Invite Caregiver screen; redeem links every patient the code covers; orange snackbar reports patients the code could NOT cover (premium required / not primary). Return types: create → `(invite, skippedPatientIds)`, redeem → `List<AppUser>` (4 callers updated).
- **Returning-caregiver onboarding fixed**: setup wizard now loads the caregiver after OAuth sign-in and, if they already manage patients, skips patient creation and goes straight to the dashboard. Previously every returning caregiver on a new device was funneled into creating a duplicate patient (this is how the July 7 duplicate Jack existed).
- **Dangling managedUserId crash fixed**: rules DENY reads of deleted docs, so `get()` throws instead of `exists=false`; `_loadManagedUsers` now try/catches per doc (one deleted patient made ALL patients invisible). `selectUserById` no longer throws on empty list.
- **Data cleanup (Firebase console)**: deleted duplicate July 7 Jack (`users/2Rzg9giSjYIZkUQ8PijQ`, Google-primary), set Michael `subscriptionTier: premium` (new patients default to free, and rules block invites for free patients — root cause of share-all silently skipping him before skip-reporting existed).
- **medication_logs index added** (userId ASC + scheduledTime ASC) — deployed; existing index was DESC-only.
- **Sundown travel-mode fix**: stationary user now classified by distance-to-home (>2 km ⇒ driving) instead of defaulting to walking ("733 minutes to get home. Walking").
- **Misc**: invite share-all switch wrapped in Material (ListTile assertion spam); Android fresh-install flow verified end-to-end: Google sign-in → dashboard with both patients, Jack shows F-150 Bouncie card, Michael doesn't.
- Remaining Android items: OCR w/ Play services, full UI walk. Remaining invite item: exercise the orange "code does NOT cover" snackbar deliberately.

## 2026-07-12 (later) - Android first real pass: Google sign-in + invite redeem + Bouncie card VERIFIED; OAuth invite gap fixed

- **Android device-verified**: Google sign-in works; invite code redeem works; Jack's dashboard renders with live Bouncie vehicle card. First successful end-to-end Android session.
- **Account-split discovery**: Apple-on-iPhone (private relay email) and Google-on-Android are separate Firebase UIDs — second device lands in new-account wizard. Not linkable by email (relay). Resolution: join family via invite codes.
- **OAuth invite gap fixed**: the only redeem UI was the login screen's email/password dialog — OAuth caregivers had NO path to join a family. Added shared `redeem_invite_dialog.dart` (redeems as current signed-in user, any provider), wired into caregiver dashboard "No patients yet" empty state (new Add Patient + invite buttons) and All Patients AppBar QR icon.
- **Setup wizard "All Set" page overflowed 165px** with keyboard up (Android) — now SingleChildScrollView, Spacer→SizedBox.
- **Open question for launch**: subscription entitlement is per caregiver account — Android/Google caregiver saw "Free Plan" while Apple/iPhone caregiver has Premium, same family. Needs family-level entitlement decision. Task filed.
- Still untested on Android: OCR w/ Play services, full UI walk, patient switching (needs 2nd patient joined).

## 2026-07-12 - Bouncie per-family linking DEVICE-VERIFIED + patient-switch state bugs fixed

- **Per-family Bouncie linking verified end-to-end on dev iPhone** (PRIVACY ship-blocker closed): reconnect via new sosmartapps.app/bouncie copy-code flow works, linked patient shows live vehicle card, unlinked patient shows NO vehicle card. Firestore rules+indexes deployed (`firebase deploy --only firestore`; rules were already current, indexes deployed fresh).
- **Root-caused stale patient-switch UI**: `caregiverNotifierProvider` was a plain `Provider` wrapping a ChangeNotifier, so every `ref.watch` on it silently never rebuilt. Symptoms on device: AppBar title stuck on previous patient; `const VehicleStatusCard` stuck on previous patient's vehicle (showed Jack's F-150 on Michael's dashboard). Fix: `ChangeNotifierProvider` (flutter_riverpod/legacy) + `ref.watch` in caregiver dashboard build. Also un-froze existing watchers in patients_overview_screen and vehicle_tracking_screen.
- **Duplicate managed-user rows fixed**: `addManagedUser` appended blindly — same patient appeared twice in All Patients, both badged "Viewing". Now dedupes by id.
- All fixes device-verified on iPhone (switch Jack↔Michael: title tracks, vehicle card appears/disappears correctly, single Michael row).
- Backlog task filed in Dev Planner: Firebase App Check provider missing (Android logcat spams "No AppCheckProvider installed"; harmless until enforcement enabled). Marked "per-user Bouncie linking (PRIVACY)" done.

## 2026-07-08 - QuadTrack DEVICE-TESTED end-to-end + push notifications fixed app-wide

- **First-ever live pass verified on dev iPhone**: dashboard empty state → registration (real patients, serial dup-check, profile prompt) → detail screen (map+trail, gauges, satellite toggle, rename, battery-aware emergency w/ reason + banner) → ingest function pings render live → low-battery push banner w/ correct text → tap deep-links to device screen
- **Infra root-causes fixed (affected the whole project, not just QuadTrack):**
  - App Engine default SA had ZERO IAM roles — every Firestore-touching 1st-gen function failed with code 7 since forever. Granted roles/datastore.user + roles/firebasecloudmessaging.admin
  - iOS Runner.entitlements had no aps-environment — APNS never registered; added (development; Xcode maps to production on archive)
  - No APNs auth key in Firebase console — uploaded AuthKey_JRU6PG826J.p8 (dev+prod slots, com.carecompanion.lumina)
  - saveFCMToken existed but was NEVER called — no caregiver ever had a push token; now called from caregiver dashboard initState (with APNS-token wait loop for iOS)
  - Functions read singular `fcmToken`; app writes `fcmTokens` array — fixed in sendGeofenceAlert, sendMedicationAlert, ingestQuadTrackPing, evaluateQuadTrackGeofences, quadTrackHealthCheck (analyzeTripsAndAlert fixed in source, NOT deployed — blocked on Bouncie secrets)
- **Serial duplicate-check fix**: rules-compatible `quadtrack_serials/{serial}` registry (device query by serial fails caregiverIds-scoped rules); registerDevice writes it, removeDevice cleans up (command+serial docs deleted BEFORE device doc — their rules read it)
- **Notification deep-links**: all QuadTrack pushes carry payload `quadtrack:<deviceDocId>`; caregiver dashboard routes taps to QuadTrackDetailScreen (chains to previous reminder handler)
- **UI fixes from device pass**: BatteryGauge ring Positioned.fill (was 36px default overlapping text); Navigate/Activate/Emergency/Remove buttons foregroundColor white (theme blue was invisible on blue/red); Emergency label FittedBox (wrapped mid-word); emergency dialog SingleChildScrollView (keyboard overflow); map placeholders when no location (was (0,0) ocean) on dashboard+detail; satellite/street toggle on all 3 QuadTrack maps
- Deployed: firestore rules+indexes, storage rules, 5 functions. Full functions deploy still blocked by missing BOUNCIE_FN_*/TWILIO_* secrets
- iOS note: notification previews redact to "Notification" when delivered while locked — Settings > Notifications > Lumina > Show Previews > Always to see content on lock screen
- **Still untested**: geofence breach push (needs active geo_zone), phone-dead escalation, LE share screen send paths, profile setup wizard walkthrough, remove device, Android everything

## 2026-07-07 - QuadTrack RESUMED: full bug-fix pass (NEEDS DEPLOY + DEVICE TEST)

- Worked through the entire docs/QUADTRACK.md TODO list (§7) in one pass; UI re-hooked into caregiver dashboard (overview card + Manage tile + _buildQuadTrackCard rebuilt)
- **Rules**: added `quadtrack_commands` (device-caregiver via get() on device doc) + `quadtrack_shares` (create/read own, keyed on sharedBy); ALSO found+fixed missing rules for `user_profiles`, `health_profiles`, `users/{id}/health_conditions` (LE share screen reads were all denied) and storage.rules `user_profiles/` photo uploads
- **Ping schema unified** to the Dart shape: ingestQuadTrackPing now writes `location` GeoPoint + `batteryLevel` + `timestamp` (+ receivedAt/hardwareSerial), keyed by device DOC ID (was hardware serial — app streams by doc ID, so hardware pings would never render); fixed `phoneBattery || null` swallowing 0 (dead phone)
- **TrackingMode unified**: removed phantom 'active' mode; nextPingSeconds + health-check thresholds now derive from Dart minute semantics via shared quadTrackIntervalSeconds() (emergency uses battery-aware emergencyIntervalMinutes); health-check threshold floored at 10 min
- **Geofence function fixed**: was reading `users/{id}/geo_zones` subcollection (never matched anything) — now queries top-level `geo_zones` by userId; radius fixed from nonexistent `radiusKm` to `radiusMeters`/1000
- **quadTrackCommand hardened**: now requires X-Device-Key auth (was open to anyone); resolves command doc by device doc ID
- **Registration**: real linked patients from caregiverNotifierProvider.managedUsers (dummy list removed); post-registration prompt offers missing-person profile setup
- **Detail screen**: renameDevice() implemented (stub fixed); emergency now uses battery-aware activateEmergencyTracking/deactivateEmergency with reason prompt; red active-emergency banner (activeEmergencyProvider) with End button; Missing-Person Profile menu item; _updateMapContent deferred to postFrameCallback
- **Profile setup**: canonical doc ID = patientId (matches share screen read), loads+prefills existing profile (legacy profile_<millis> fallback), preserves photos/frequentPlaces/untouched fields
- **Service**: removeDevice deletes command doc BEFORE device (rules read device doc); renameDevice added
- **Small fixes**: navigate-screen Geolocator stream leak (subscription cancelled in dispose); share-screen MEDICAL section null-guard; simulator default project → lumina-sosmartapps + --token auth support
- Verified: caregiver doc ID == FirebaseAuth UID (auth_service `_ensureCaregiverProfile` uses doc(user.uid)) so caregiverIds rules are sound; functions `tsc --noEmit` clean; Dart edits manually reviewed (no analyzer in session)
- **NOT verified**: no flutter analyze/build, no device test, nothing deployed. Deploy needed: `firebase deploy --only firestore,storage,functions`

## 2026-07-06 - Pet Feeding Reminders (NEEDS DEVICE TEST + FIREBASE DEPLOY)

- New self-contained feature under `lib/features/pet_feeding/`: schedule feeding times per pet with local notifications, mark-as-fed, and feeding history
- Model `lib/core/models/pet_feeding.dart`: `PetFeeding` (petName, PetType, foodType, amount, embedded `FeedingTime` list, `repeatDays` null=daily else weekdays 1-7, `lastFedAt`), `FeedingLog`, `PetType` enum (emoji + icon). Exported from models barrel
- Service `pet_feeding_service.dart` (+ `petFeedingServiceProvider`): CRUD on `pet_feedings`, `markFed` writes `feeding_logs` + bumps `lastFedAt`, history streams. Immediate (re)scheduling on create/update (updateFeeding cancels via *old* doc to avoid orphan notifications) + `scheduleAllFeedingNotifications` on boot
- NotificationService: added `pet_feeding_channel`, `schedulePetFeeding` (daily → `DateTimeComponents.time`; specific days → one repeating notif per weekday via `dayOfWeekAndTime`), `cancelPetFeeding` (deterministic ids), generic `scheduleNotification` now takes optional `matchComponents`
- UI: `ManagePetFeedingScreen` (add/edit/delete dialog with multiple feeding times + label, pet-type picker, every-day/weekday chips; per-pet card shows times, last-fed, next feeding, Mark Fed button) + `FeedingHistoryScreen` (grouped by day). Wired into caregiver dashboard Manage tab
- Boot scheduling hooked into splash_screen + user_home_screen (after reminder scheduling, since reminderService.scheduleAllNotifications calls cancelAll first)
- Firebase: `firestore.rules` for `pet_feedings` + `feeding_logs` (patient + caregivers r/w); 3 new indexes (pet_feedings userId+isActive; feeding_logs userId+fedAt desc; feeding_logs feedingId+fedAt desc). **Run `firebase deploy --only firestore` before shipping**

## 2026-07-08 - User Profile Auto-Save

- Debounced auto-save: 2.5s after typing stops, profile saves silently. AppBar shows live state: spinner (saving) / white save icon (unsaved) / checkmark (all saved) / red-tinted save icon + persistent red "Changes NOT saved — check connection" banner w/ Retry (auto-save failure). Manual save button kept; failure on manual save still shows the blocking dialog; unsaved-changes back-guard still active as last resort.

## 2026-07-08 - FAB Text Illegible (Theme Root Cause)

- "Add Patient" FAB label rendered near-black on purple. No `floatingActionButtonTheme` existed; screens set only backgroundColor. Added themed `foregroundColor: Colors.white` + extendedTextStyle (light+dark) — fixes all ~12 FAB screens at once. Checklist theme-trap section updated.

## 2026-07-08 - Reminder Day-of-Week Tickboxes

- Add/Edit Reminder: Mon–Sun tickboxes appear for Every Week / Custom Days (at least one day stays selected); saved to existing `repeatDays` field. Weekly reminders now honor picked days (fallback: originally scheduled weekday). Reminder cards show the days ("Mon, Wed") instead of just "Every Week".

## 2026-07-08 - Caregiver Invites From Caregivers Screen + Multi-Role + Fiduciary

- Caregivers screen: "Invite Caregiver" FAB → invite screen. Invite screen: role dropdown → tickboxes (people can hold multiple roles), added Fiduciary (Financial) (= existing financeManager, renamed display), optional phone field + "Text Invite" button (opens Messages prefilled — no Twilio needed).
- Multi-role storage: `multiRoleOverrides.{patientId}: [roles]` on caregiver docs; legacy `roleOverrides` kept in sync (first role) for back-compat. InviteCode gains `assignedRoles`. `rolesForPatient()` on Caregiver; expense `canManageFinances` now multi-role aware. Caregivers screen "Edit Roles" tickbox dialog replaces single-role menu.
- firestore.rules: caregivers read/update relaxed to authenticated — listing co-caregivers and editing their roles was silently denied under uid==caregiverId (latent bug). NEEDS `firebase deploy --only firestore:rules`.

## 2026-07-08 - User Profile Auto-Save + Save Guards

- Debounced auto-save: 2.5s after typing stops, profile saves silently to Firestore (same path as manual save; Firestore offline queue gives free resilience). AppBar shows live state: spinner / save icon (unsaved) / checkmark (all saved). Auto-save failure → persistent red "Changes NOT saved" banner with Retry (not a missable snackbar); manual-save failure → blocking dialog; unsaved-changes back-guard as last resort.

## 2026-07-08 - Rules Audit: 8 More Silent-Denial Gaps Closed + Audit Script

- **Data loss bug**: User Profile saves write `users/{id}/user_profile/` SUBcollection; only a top-level `user_profiles` rule existed → every profile save silently denied (Leon lost a full form). Subcollection rule added.
- **user_photos** storage path (identification photos) had no rule → uploads failed; added. **pill_photos** ditto (rule said medication_photos — never matched); added.
- Catch-all rule for patient subcollections under `users/{id}` (health_profile, allergies, providers, pharmacies, prescriptions sub, refill_history, activity_events) + top-level `prescriptions` + `prescriptions/{id}/refills` — all previously unruled. TODO before external users: per-collection tenancy audit (family-trust `isAuthenticated` model for now).
- **New tooling: `scripts/audit-firestore-rules.sh <app>`** — greps every collection()/storage path in code vs rules blocks; run per firebase-preflight before any rules deploy. Already caught pill_photos.
- Needs `firebase deploy --only firestore:rules,storage`

## 2026-07-08 - Imperial/Metric Units + Lost-Person Banner Layout

- `core/utils/units.dart`: UnitsSystem resolution — 'auto' follows device region (US/LR/MM → imperial), explicit override in User Settings (Auto/Imperial/Metric SegmentedButton); `UserSettings.units` field added. Storage stays METRIC in Firestore; conversion at UI only
- User Profile Physical tab: imperial mode shows Height (ft)/(in) + Weight (lb); converts to cm/kg on save; measurement summary shows both systems either way
- Lost-person banner restructured (sentence full-width, compact full-width button below) — side-by-side layout crushed the text on iPhone
- NOT device-tested (batch with next build)

## 2026-07-07 - All Patients Overview (multi-patient management)

- New `patients_overview_screen.dart`: one page listing every managed patient with live status per card — activity badge (Active now/Xm/Xh ago), today's meds taken✓/missed✗ (red when missed), pending expense-approval count, driving-alert flag (trip_alerts within 48h). Tap card switches the dashboard to that patient; Add Patient FAB
- Entry: people icon in the caregiver dashboard AppBar
- NOT device-tested

## 2026-07-07 - Patient Display Name + Phone Editable

- User Profile → Identity tab gains "App Display" section: Display Name (users/{id}.name) and User's Phone — previously unfixable after setup (Leon had entered himself as the patient). Loads from users doc, saves with the profile.

## 2026-07-07 - Trip Concern Analysis + Caregiver Alerts (push now, SMS-ready)

- `trip_analyzer.dart`: heuristics tuned for older drivers — night driving (10pm–5am, alert), harsh driving (≥3 brake/accel events, alert), speeding (80 warn / 90 alert), long trips (≥90min, warn), pattern escalation (≥3 flagged trips). Concerns banner at top of Trip History; flagged trip cards get orange border
- `analyzeTripsAndAlert` Cloud Function (every 4h): per bouncie_connection, fetches last 25h of trips, same heuristics (thresholds mirrored — keep in sync), dedupes via `trip_alerts/{patientId}.alertedKeys`, FCM push to caregivers, and Twilio SMS to caregiver phoneNumbers when TWILIO_* secrets are non-empty (self-detecting; no code change to enable)
- rules: trip_alerts read for caregivers (function writes via Admin)
- **Pre-deploy (firebase-preflight): 6 function secrets must exist** — BOUNCIE_FN_CLIENT_ID / _SECRET / _REDIRECT_URI (real values) + TWILIO_ACCOUNT_SID / _AUTH_TOKEN / _FROM_NUMBER (empty until a Twilio account exists). Then `firebase deploy --only firestore:rules,functions:analyzeTripsAndAlert`
- tsc --noEmit clean; NOT deployed/device-tested

## 2026-07-07 - Trip History: Range Selector + Route Detail View

- Bouncie per-family linking DEVICE-VERIFIED on Android emulator (connect, vehicle card, disconnect); trips endpoint fixed to `/trips?imei=...&gps-format=polyline` (old `/vehicles/{imei}/trips` 404'd — Trip History had never worked)
- Trip list: 7/30/90-day SegmentedButton window, newest-first sort, corrected Bouncie field names (hardBrakingCount/hardAccelerationCount), tappable cards w/ chevron, error screen shows the actual reason
- New `trip_detail_screen.dart`: driven route polyline on GoogleMap (own decoder, no new deps), start/end markers, camera auto-fits route, Map/Satellite/Hybrid toggle, stat chips (distance, duration, avg/top speed, hard brakes/accels colored by severity, fuel, odometer)
- NOT device-tested (list changes + detail view)

## 2026-07-07 - Per-Family Bouncie Linking (ship-blocker fix)

- Personal creds no longer power the app: `bouncieServiceProvider`/`bouncieVehicleImeiProvider` removed. App-level (developer) config stays in .env (CLIENT_ID/SECRET/REDIRECT_URI); per-family auth code + vehicle now in Firestore `bouncie_connections/{patientId}` (BouncieConnection model; rules: patient's caregivers only)
- New Manage → Vehicle Tracking screen: opens Bouncie sign-in (authorize URL), paste auth code, validates by fetching vehicles, pick vehicle, save; disconnect supported. Bouncie auth codes are re-exchangeable — the durable per-user credential (same mechanism the old env flow used)
- Consumers patient-scoped: VehicleStatusCard hides entirely when no connection; dashboard map vehicle marker + trip history use the family connection; per-authCode token cache keys (no cross-family collisions)
- .env BOUNCIE_AUTH_CODE/VEHICLE_IMEI now unused by code (Leon can paste that auth code into the new flow to reconnect his truck)
- **Needs `firebase deploy --only firestore` + device test (not run yet)**

## 2026-07-07 - Pet Feeding: Food Photos

- `PetFeeding.foodPhotoUrls` added (model/fromFirestore/toFirestore/copyWith + createFeeding)
- Add/Edit Pet dialog: camera + gallery photo pickers with thumbnails and remove; uploads on save to Storage `pet_food_photos/{patientId}/`; removed photos cleaned up; save button shows progress and surfaces errors
- Pet card shows tappable photo strip (full-screen InteractiveViewer)
- storage.rules: `pet_food_photos` block added — **needs `firebase deploy --only storage`**
- NOT device-tested

## 2026-07-07 - QuadTrack Paused + Knowledge Doc

- QuadTrack detached from UI (dashboard overview card + Manage tile + imports removed); all code under lib/features/quadtrack + service/model/provider left intact and dormant
- **docs/QUADTRACK.md** written — complete standalone reference (architecture, Firestore schema, Cloud Functions, quoted removed integration snippets, resume checklist). Key audit findings for the resume session: quadtrack_commands + quadtrack_shares still have NO firestore rules; ping schema mismatch between ingest function (flat lat/lng/receivedAt) and Dart model (GeoPoint/timestamp) means hardware pings would never render; registration uses hardcoded dummy patients; profile-setup wizard unreachable; battery-aware emergency methods never called from UI.
- Zone map picker verified working on Android emulator (pin, satellite, coordinates incl. pasted Google copies, field/pin precedence)

## 2026-07-07 - Log-Driven Fixes from Android Session

- **bug_reporter crash loop fixed**: FlutterError.onError recorded debug-only framework assertions (ListTile ink advisory etc.) as FATAL crashes + queued the crash sheet → sheet flashed on every reload and re-persisted itself. Now: debug assertions → non-fatal Crashlytics only; crash sheet queued only in release; console visibility preserved (presentError/debugPrint).
- **quadtrack_devices/pings/emergencies rules added** — were entirely missing from firestore.rules; every caregiver dashboard device query was PERMISSION_DENIED since first deploy.
- **medication_logs composite index added** (userId ASC + scheduledTime DESC) — home-screen med counters were failing FAILED_PRECONDITION.
- All need `firebase deploy --only firestore` (zone-create relax from earlier is also still undeployed — writes were denied in testing).

## 2026-07-07 - Free Tier: 1 Safe Zone (was premium-only) + Coordinate Parsing Fixes

- **Product decision (Leon)**: free tier now includes 1 safe zone; premium unlimited. `maxGeoZones` gate added (model + provider), `canUseGeofencing` now true for all tiers, firestore.rules geo_zones create relaxed to `isCaregiverFor` (count enforced client-side like other gates). Zones FAB shows upgrade dialog → PaywallScreen at the limit. **Needs `firebase deploy --only firestore`.**
- Coordinate parsing hardened: strips invisible Unicode marks from Google Maps copies (root cause of "did not resolve"), accepts DMS (`32°29'15.9"N …`) incl. curly quotes, `;`/space separators. Parser verified against 9 input forms.
- Zone add/update errors now surface in snackbars (was: infinite spinner on failure); geocoder calls capped at 10s.
- Android: USE_EXACT_ALARM permission added (medication reminders were failing with exact_alarms_not_permitted on Android 14).

## 2026-07-07 - Zone Map Picker: tap-to-place, satellite, coords + what3words

- New `zone_map_picker_screen.dart`: full-screen map, tap (or drag marker) to set zone center, live radius circle + slider, Map/Satellite/Hybrid toggle — cross-platform (google_maps_flutter)
- Add Zone dialog: "Pick on Map" button (pin overrides typed address; reverse-geocodes label); Edit Zone dialog: "Move Center on Map"
- `LocationService.resolveLocationQuery()`: accepts street address, raw `lat, lng`, or what3words (`///word.word.word`) — used by picker search + zone dialogs
- what3words needs `W3W_API_KEY` in `.env` (placeholder added; free key at what3words.com/developers) — degrades gracefully without it
- NOT device-tested — test picker on emulator/iPhone, incl. satellite toggle + coordinate entry

## 2026-07-06 (overnight) - Android Splash Hang Hardening + Sweep Completion

- **Android emulator boot hang**: splash stuck on spinner after `BOOT: complete` — cause in splash init chain (post-bootReady). Fix: every splash step now timeboxed + `SPLASH:` logged (same pattern as `_postBootInit`): app state 10s, location permission 60s, load user 15s, tracking/geofence/sundown/reminders/pet-feeding/subscription/background 10s each. Navigation now ALWAYS happens.
- **`BOOT: notifications` 15s timeout root-caused**: FCM `requestPermission` blocks until the Android 13 dialog is answered — now fire-and-forget (`unawaited`) with result logged; listeners unaffected.
- Uncaught errors now also `debugPrint` (`UNCAUGHT:`) — the Crashlytics onError previously swallowed them from the console.
- Overflow sweep judgment items closed: trip stats row → `Wrap`; reminders + zones subtitle badges → `Flexible` + ellipsis. Code sweep now 100%; on-device visual pass remains.
- NOT verified on device/emulator — rerun on Pixel emulator, check `SPLASH:` lines for the true hang culprit (likely `app state` or `location permission`).

## 2026-07-06 - Android Cross-OS Readiness

- Audit: manifest permissions complete (bg location, notifications, foreground service), Maps key wired via local.properties, minSdk from flutter, appId com.carecompanion.app (note: differs from iOS bundle com.carecompanion.lumina — both registered in Firebase)
- Debug SHA-1 added to Firebase console; google-services.json refreshed (now has Android OAuth client + web client)
- `GoogleSignIn.initialize(serverClientId: <web client>)` — required for idToken on Android
- Apple sign-in button gated to iOS/macOS (Android web flow needs a Services ID — not configured; Google-only on Android)
- Remaining: run + visual pass on an Android device/emulator (ML Kit OCR needs Play services image)

## 2026-07-06 - Lantern Brand Mark Throughout App

- New on-light mark variant (blue ring/base, warm glow, transparent bg): `assets/images/lumina_mark.png`, source `assets/branding/lumina-mark-onlight.svg`
- Replaces generic icons at brand moments: splash screen (was heart), setup welcome page (was heart), caregiver login (was admin shield)
- Semantic icons untouched (Preferred Name heart prefix, avatars)

## 2026-07-06 - ROOT CAUSE: infinite-width button theme (vertical-text bugs)

- **`ElevatedButtonTheme minimumSize: Size(double.infinity, 64)` (both light + dark themes) made every ElevatedButton inside a Row demand infinite width** → sibling Expanded text collapsed to one character per line, button labels painted off-screen (permissions "Allow" card, User Profile lost-person banner). NOT device text-size related.
- Fix: `minimumSize: Size(64, 64)`; audited all 49 ElevatedButtons — every full-width CTA already gets width from `SizedBox(width: double.infinity)` wrappers; the one unwrapped instance (quadtrack dialog action) is fixed, not broken, by this change
- Kept as defense-in-depth: app-wide text scaling clamp (1.0–1.3×) and the 10-site fragile-Row sweep (contacts, dashboard badges, vehicle card, zones/medication button rows, paywall, medical records, setup welcome/tips)
- Lesson added to memory/workflows/ui-formatting-checklist.md ("Theme-level traps")

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

## 2026-07-13 — Home environment monitoring (temp/humidity)
Caregivers see live temperature/humidity in the patient's home + get push alerts when out of range. Three provider paths behind `environment_connections/{patientId}` (all can coexist): (1) **BLE bridge** — patient phone reads a SensorPush HT.w directly (port of So Smart Scans GATT protocol, `sensorpush_ble_bridge.dart`, flutter_blue_plus; no WiFi gateway needed) — DEVICE-VERIFIED end-to-end incl. dashboard card + threshold alert push; (2) SensorPush Gateway Cloud API (requires G1 gateway; `pollEnvironment` fn, not yet deployed); (3) Nest SDM thermostat (needs NEST secrets + Google Device Access registration). New: EnvironmentConnection model, environment settings screen (link/toggle + RangeSlider thresholds), EnvironmentStatusCard, `onEnvironmentReading` trigger with warning tier (family thresholds, 6h cooldown) + danger tier (≥95°F/≤50°F, bypasses alerts-off, 2h cooldown). Rules: caregivers + patient device may access `environment_connections/{patientId}`. Also fixed: LargeActionTile RenderFlex overflow, caregiver onboarding notifyListeners-during-build + unmounted-ref Crashlytics crash, stale kernel snapshot workaround (flutter clean).
