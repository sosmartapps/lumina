# Lumina — Terms of Use & Liability Waiver

**Version:** 1.1 — Effective July 15, 2026 (1.1: corrected contact email to leon@sosmartapps.app; no other changes)
**Status: DRAFT PENDING ATTORNEY REVIEW** (live in-app as of v1.0; flag any changes back into `lib/core/legal/legal_terms.dart` — see `docs/legal/LEGAL-IMPLEMENTATION.md` for the sync procedure)

> This file is the canonical source. The identical text ships inside the app in
> `lib/core/legal/legal_terms.dart` and is shown in a blocking acceptance screen
> before the app can be used. If an attorney edits this file, the Dart copy and
> the version constant MUST be updated in the same change.

---

## Lumina Terms of Use

These Terms of Use ("Terms") are a legal agreement between you and So Smart Apps LLC, an Arizona limited liability company ("So Smart Apps," "we," "us"), governing your use of the Lumina mobile application and related hardware integrations, including QuadTrack devices, vehicle tracking, and home-environment sensors (together, the "Service").

**You must read and accept these Terms before using the Service. If you do not agree, you may not use the Service.**

### 1. What Lumina Is — and What It Is Not

Lumina is a quality-of-life and caregiving convenience aid. It provides engagement and routine support tools such as reminders, activity libraries, location awareness features, and family coordination.

**Lumina is NOT:**

- an emergency service, emergency response system, or life-safety device;
- a medical device, and it does not provide medical advice, diagnosis, or treatment;
- a substitute for in-person care, supervision, or professional judgment;
- a guarantee that a monitored person can be located, will not wander, or will not come to harm.

**In any emergency, call 911 (or your local emergency number) immediately. Do not rely on the Service to summon help.**

### 2. Limitations of Alerts and Monitoring

You understand and agree that location tracking, geofence ("safe zone") alerts, QuadTrack pings, vehicle tracking, environment alerts, reminders, and push notifications **can fail or be delayed at any time, without warning, for reasons within or outside our control**, including but not limited to: dead or powered-off devices; loss of cellular, Wi-Fi, GPS, or Bluetooth connectivity; operating-system restrictions on background activity; notification delivery failures; GPS inaccuracy; battery-saver modes; misconfiguration; and outages of third-party services we depend on (including Google/Firebase, Apple, Bouncie, and SensorPush).

**You must never rely on the Service as your sole or primary means of monitoring the safety, location, or wellbeing of any person.**

### 3. Your Responsibilities; Assumption of Risk

You represent that you are at least 18 years old and legally able to enter this agreement. If you set up the Service for another person (the "monitored person"), you represent that you have the legal authority or the consent required to do so, and that you will comply with all applicable laws regarding location tracking and consent.

**You remain solely responsible at all times for the care, supervision, and safety of any monitored person.** You accept full responsibility for how you configure and use the Service, and you assume all risks arising from reliance on it, including the risk that an alert is not delivered or a location is unavailable or inaccurate.

### 4. No Medical or Cognitive Claims

Features involving activities, reminders, and engagement are provided for engagement and routine support only. They are not intended to diagnose, treat, cure, mitigate, or prevent any disease or condition, and no claim is made that they improve memory or slow cognitive decline.

### 5. Disclaimer of Warranties

THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE," WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, ACCURACY, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED, TIMELY, SECURE, OR ERROR-FREE, OR THAT LOCATION DATA OR ALERTS WILL BE ACCURATE OR DELIVERED.

### 6. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, SO SMART APPS LLC AND ITS MEMBERS, OFFICERS, EMPLOYEES, AND AGENTS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR ANY PERSONAL INJURY, DEATH, DISAPPEARANCE, PROPERTY DAMAGE, OR OTHER HARM TO YOU OR ANY MONITORED PERSON, ARISING OUT OF OR RELATED TO THE SERVICE OR YOUR RELIANCE ON IT — INCLUDING FAILED, DELAYED, OR INACCURATE ALERTS OR LOCATION DATA — EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR TOTAL AGGREGATE LIABILITY FOR ALL CLAIMS RELATING TO THE SERVICE WILL NOT EXCEED THE GREATER OF (A) THE AMOUNTS YOU PAID US FOR THE SERVICE IN THE TWELVE (12) MONTHS BEFORE THE CLAIM AROSE, OR (B) FIFTY U.S. DOLLARS (US $50).

Some jurisdictions do not allow certain limitations, so some of the above may not apply to you. Nothing in these Terms limits liability that cannot be limited by law, including liability for gross negligence or willful misconduct where such limitation is prohibited.

### 7. Indemnification

You agree to indemnify, defend, and hold harmless So Smart Apps LLC and its members, officers, employees, and agents from and against any claims, damages, losses, liabilities, and expenses (including reasonable attorneys' fees) brought by any third party — including a monitored person or their family members — arising out of or related to: (a) your use or misuse of the Service; (b) your violation of these Terms; (c) your violation of any law or of any third party's rights, including privacy and consent rights of a monitored person; or (d) harm to a monitored person alleged to result from reliance on the Service.

### 8. Privacy and Location Data

The Service collects and processes location data, sensor data, photos, and other personal information about you and monitored persons in order to function. You are responsible for obtaining any consent required from or on behalf of the monitored person. Our data practices are described in the Lumina Privacy Policy.

### 9. Subscriptions; Termination

Certain features require a paid subscription billed through the app stores. We may suspend or terminate access for violation of these Terms. You may stop using the Service at any time; Sections 3, 5, 6, 7, 10, and 11 survive termination.

### 10. Dispute Resolution; Arbitration; Class Waiver

Any dispute arising out of or relating to these Terms or the Service will be resolved by binding individual arbitration administered by the American Arbitration Association under its Consumer Arbitration Rules, rather than in court, except that either party may bring an individual claim in small-claims court. **YOU AND SO SMART APPS EACH WAIVE THE RIGHT TO A JURY TRIAL AND TO PARTICIPATE IN A CLASS ACTION.** The arbitration will be conducted in Pima County, Arizona, or remotely by agreement. These Terms are governed by the laws of the State of Arizona, without regard to conflict-of-law rules.

### 11. Changes to These Terms

We may update these Terms. When we do, the app will require you to review and accept the new version before continued use. The version and effective date appear at the top of these Terms.

### 12. Contact

So Smart Apps LLC — leon@sosmartapps.app

---

## Required Acknowledgments (shown as mandatory checkboxes in-app)

1. I understand Lumina is **not an emergency service or medical device** and that in an emergency I must call 911.
2. I understand that **alerts, notifications, and location data can fail or be delayed** and I will not rely on Lumina as the sole means of monitoring anyone's safety.
3. I remain **fully responsible for the care and supervision** of any person I monitor with Lumina.
4. I accept the **Terms of Use, including the limitation of liability and my agreement to indemnify So Smart Apps LLC**.

---

## Attorney Review Checklist (remove after review)

- Enforceability of liability cap and injury/death exclusion for a consumer caregiving app (AZ + key states; note some states restrict pre-injury releases).
- Indemnification clause scope (consumer context — consider narrowing to third-party claims only, already drafted that way).
- Arbitration clause: AAA Consumer Rules compliance (fee allocation, 30-day opt-out often recommended — currently NOT included).
- Consent/authority language for tracking a cognitively impaired adult (guardianship vs. consent; state two-party consent/tracking statutes).
- FTC claims language (Section 4) — matches standing rule in docs/cognitive-engagement-research.md.
- Whether a separate signed waiver is advisable for QuadTrack hardware.
- Privacy Policy cross-reference (Section 8) — ensure a real Privacy Policy exists and matches.
- Age/eligibility, App Store EULA interaction (Apple's standard EULA vs. custom).
