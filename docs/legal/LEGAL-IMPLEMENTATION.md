# Lumina Legal Acceptance System — Complete Implementation Map

Created 2026-07-15. **Status: implemented, NOT yet device-tested; terms text is a DRAFT pending attorney review.**
This is the single source of truth for everything legal-related in the app and where it lives.

## Why it exists

Lumina monitors vulnerable people. The worst-case claim is "the app failed and someone was harmed/went missing." Protection = (1) a blocking Terms of Use / liability waiver that MUST be accepted before the app can be used, (2) an immutable audit record of every acceptance, (3) point-of-use "not an emergency service" warnings on safety-adjacent screens. A ToS alone is not complete protection — the LLC and product-liability/E&O insurance cover the rest (business decision, outside the app).

## The rule enforced in code

**The app cannot be used — by anyone, on any path — until the current terms version is accepted on that device (or already accepted on the account).** This includes the very first launch: the gate appears BEFORE onboarding/setup.

## File inventory

| What | Where |
|---|---|
| Canonical terms text (attorney edits THIS) | `docs/legal/TERMS_OF_USE.md` |
| In-app terms text + version constant | `lib/core/legal/legal_terms.dart` (`kTermsVersion`, `kTermsIntro`, `kTermsSections`, `kRequiredAcknowledgments`) |
| Acceptance logic (gate check, recording, sync) | `lib/core/services/legal_service.dart` |
| Blocking gate screen + read-only viewer | `lib/features/legal/legal_gate_screen.dart` |
| Gate wiring (single choke point) | `lib/features/splash/splash_screen.dart` → `_navigateTo()` |
| Point-of-use disclaimer widget | `lib/core/widgets/emergency_disclaimer_banner.dart` |
| Firestore audit-log security rule | `firestore.rules` → `match /legal_acceptances/{acceptanceId}` |
| Terms viewer in Settings | `lib/features/caregiver/account_settings_screen.dart` ("Terms of Use" row) |
| This document | `docs/legal/LEGAL-IMPLEMENTATION.md` |

## How the gate works

1. `SplashScreen._initializeApp()` decides the destination (SetupScreen / UserHomeScreen / CaregiverLoginScreen / CaregiverDashboardScreen) exactly as before.
2. `_navigateTo()` — which ALL four destinations pass through — calls `LegalService.needsAcceptance()`.
3. If acceptance is needed, the destination is swapped for `LegalGateScreen(next: destination)`. The gate:
   - shows a red "NOT an emergency service — call 911" banner, then the full terms;
   - places the 4 mandatory checkboxes and the Agree button BELOW the text, so the user must scroll through everything to reach them;
   - keeps "I Agree — Continue" disabled until all 4 boxes are checked;
   - "I Do Not Agree" → dialog with only "Review Again" or "Close App" — no path into the app;
   - blocks the Android back button (`PopScope(canPop: false)`);
   - on Agree → `LegalService.recordAcceptance()`, then continues to the original destination.
4. Any error or timeout in the check **defaults to showing the gate** (fail-closed).

## Acceptance storage (3 layers)

1. **Local (authoritative for gating):** SharedPreferences `legal.acceptedVersion` + `legal.acceptedAtIso`. Works offline; checked every launch.
2. **Audit log:** Firestore top-level collection `legal_acceptances` — one immutable doc per acceptance: `authUid, caregiverId, patientUserId, version, acceptedAt (server), acceptedAtLocal, platform, acknowledgments[]`. Rules: create-only (must match own authUid), read own, update/delete denied. This is the legal-defense record.
3. **Account stamp:** `legalAcceptance` map merged onto `caregivers/{id}` and (when a caregiver context exists) `users/{patientId}`. Lets a reinstall or a patient device pass the gate without re-prompting once the caregiver has accepted the current version.

Offline acceptance: local write always succeeds and gates the app; remote audit doc + stamps retry on later launches via `LegalService.ensureRemoteSync()` (called on every successful gate pass). Audit doc and account stamp are tracked as SEPARATE sync flags — first-run acceptance succeeds before accounts exist, so the stamp back-fills on a later launch once caregiver/user ids are known (gap found + fixed during 2026-07-15 device test).

## Versioning / re-acceptance

- Bump `kTermsVersion` in `lib/core/legal/legal_terms.dart` whenever the terms change (format `major.minor-YYYY-MM-DD`) and update `TERMS_OF_USE.md` in the same commit.
- Every device re-shows the gate on next launch after a bump.
- **Known limitation:** after a version bump, a patient device re-shows the gate to whoever holds the phone unless the account stamp already carries the new version. A caregiver acceptance stamps only the currently selected patient. Rare event (only on terms changes); mitigation: after bumping terms, caregivers should open the app once per patient before the patient's device is used. Flag for attorney/UX review.

## Point-of-use disclaimers (EmergencyDisclaimerBanner)

Courts weigh warnings at the point of reliance, not just in a ToS. Current placements — update this list when adding/removing:

- `lib/features/caregiver/manage_zones_screen.dart` — safe zones list (always visible, incl. empty state)
- `lib/features/caregiver/monitoring_settings_screen.dart` — battery/fuel alert settings (top of list)
- `lib/features/quadtrack/quadtrack_dashboard_screen.dart` — QuadTrack dashboard (above map)

Candidates not yet done: sundown settings, environment monitoring dashboard, Bouncie vehicle tracking.

## What is NOT covered by this implementation (for the attorney / Leon)

- **Privacy Policy** — Terms Section 8 references it; a real Privacy Policy still needs to be written and hosted (also an App Store requirement).
- **Insurance** — general liability / product liability / E&O; ToS caps mean little without it.
- **QuadTrack hardware** — attorney should decide if the physical device needs its own packaging insert / signed waiver.
- **App Store metadata** — store listing must link Terms + Privacy Policy; add to app-to-market checklist at submission time.
- The full attorney checklist is at the bottom of `TERMS_OF_USE.md`.

## Deploy + test checklist (open items)

- [x] `firebase deploy --only firestore:rules` — DONE 2026-07-15 (rules compiled + released to lumina-sosmartapps)
- [x] Device test PARTIAL (iPhone, 2026-07-15): fresh install → gate appears before setup ✓; scroll-through + checkboxes render clean ✓; accept (v1.1) → setup proceeds ✓
- [x] Relaunch after acceptance → no gate ✓ (iPhone, 2026-07-15)
- [x] `legal_acceptances` audit docs VERIFIED in Firestore console (2026-07-15): both acceptances logged (v1.0 + v1.1) with server timestamp, verbatim acknowledgments, authUid, platform ✓. (Settings ToS viewer row: in code, not yet device-checked.)
- [x] Caregiver-doc `legalAcceptance` stamp back-fill VERIFIED in Firestore console (2026-07-15, after hot restart w/ fix): version 1.1, original acceptedAtLocal preserved, authUid matches audit doc ✓
- [ ] Device test remaining: decline → app closes; patient-mode device; large-text pass on gate + banners; Settings ToS viewer visual check
- [ ] Device test: existing install (Leon's iPhone) → gate appears once on first launch after update
- [ ] Device test: patient-mode device → gate appears after update, banner screens render without overflow (large-text pass per ui-formatting-checklist)
- [ ] Attorney review of `TERMS_OF_USE.md`; sync any edits into `legal_terms.dart` + bump `kTermsVersion`
