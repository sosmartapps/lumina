# Lumina — Recommended Upgrades
**Generated:** 2026-02-20 | **Priority:** 🔴 CRITICAL

## Summary
Lumina is the most outdated app in the portfolio. FlutterFire is 2 major versions behind (v2.x era), uses dual state management (provider + riverpod), and has deprecated notification packages.

---

## Upgrades

### 🔴 CRITICAL

#### 1. Update Dart SDK Constraint
- **Current:** `>=3.2.0 <4.0.0`
- **Target:** `>=3.7.0 <4.0.0`

#### 2. iOS Lifecycle Migration (UIScene)
- **Command:**
```bash
flutter config --enable-uiscene-migration && flutter run
# Manual fallback: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
```

#### 3. Upgrade FlutterFire from v2.x to v4.x (MAJOR)
- **Current → Target:**
  - `firebase_core: ^2.24.2` → `^4.x` ⚠️ **2 major versions behind**
  - `firebase_auth: ^4.16.0` → `^6.x` ⚠️ **2 major versions behind**
  - `cloud_firestore: ^4.14.0` → `^6.x` ⚠️ **2 major versions behind**
  - `firebase_storage: ^11.6.0` → `^13.x` ⚠️ **2 major versions behind**
  - `firebase_messaging: ^14.7.10` → `^15.x`
- **Why:** Security patches, bug fixes, performance improvements, new features
- **Migration guide:** https://firebase.flutter.dev/docs/migration/
- **Command:**
```bash
flutter pub upgrade --major-versions
flutterfire configure
```
- ⚠️ **Breaking changes:** API surface changes, initialization patterns, error handling

### 🟠 HIGH

#### 4. Remove Dual State Management
- **Current:** Both `provider: ^6.1.1` AND `flutter_riverpod: ^2.4.9`
- **Action:** Migrate all `provider` usage to Riverpod 3.0, then remove `provider`
- **Command:**
```bash
flutter pub remove provider
flutter pub add flutter_riverpod:^3.0.0
```

#### 5. Add Firebase Crashlytics + Analytics
- **Why:** No crash reporting or analytics on an app serving vulnerable users (Alzheimer's caregivers)
- **Command:**
```bash
flutter pub add firebase_crashlytics firebase_analytics
```

#### 6. Replace awesome_notifications
- **Current:** `awesome_notifications: ^0.8.3`
- **Why:** Package has had maintenance issues and compatibility problems
- **Action:** Consolidate on `flutter_local_notifications` (already in deps) and remove `awesome_notifications`
- **Command:**
```bash
flutter pub remove awesome_notifications
flutter pub add flutter_local_notifications:^18.0.0
```

#### 7. Update geolocator
- **Current:** `^10.1.0`
- **Target:** `^14.x` (4 major versions behind)
- **Command:**
```bash
flutter pub add geolocator:^14.0.0
```

### 🟡 MEDIUM

#### 8. Firebase AI Logic — AI Care Suggestions
- **Why:** AI-powered care suggestions for Alzheimer's caregivers
- **Command:**
```bash
flutter pub add firebase_ai
```

#### 9. Update google_maps_flutter
- **Current:** `^2.5.3`
- **Target:** `^2.14.0`
- **Command:**
```bash
flutter pub add google_maps_flutter:^2.14.0
```

### 🟢 LOW

#### 10. Material 3 Audit
- **Action:** Review theme for M3 compliance

---

## Estimated Effort
| Task | Time |
|------|------|
| SDK + iOS lifecycle | 1 hour |
| FlutterFire v2→v4 migration | 4-6 hours |
| Remove provider → Riverpod 3.0 | 4-6 hours |
| Add Crashlytics + Analytics | 1 hour |
| Replace awesome_notifications | 2-3 hours |
| Update geolocator | 1-2 hours |
| **Total** | **13-19 hours** |

---

## After Completing Upgrades

Run the scanner from the `development/` root to update the dashboard:
```bash
cd .. && python3 scripts/scan-upgrades.py
```

For manual upgrades the scanner can't auto-detect (like iOS lifecycle), also update the status JSON directly. See `scripts/CLAUDE_CODE_UPGRADE_GUIDE.md` for the full upgrade ID reference.
