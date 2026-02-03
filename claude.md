# Lumina - Development Guide

A comprehensive Flutter application for Alzheimer's care, helping people with cognitive impairments navigate daily life while providing caregivers remote management tools.

## Quick Reference

| Item | Value |
|------|-------|
| **App Name** | Lumina |
| **Package Name** | `com.carecompanion.app` |
| **Framework** | Flutter 3.2+ / Dart 3.0+ |
| **State Management** | Provider + Riverpod |
| **Backend** | Firebase (Auth, Firestore, Storage, Messaging) |
| **Maps** | Google Maps SDK |

## Project Structure

```
lumina/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── firebase_options.dart        # Firebase configuration
│   ├── core/
│   │   ├── models/                  # Data models
│   │   │   ├── app_user.dart        # Main user model
│   │   │   ├── caregiver.dart       # Caregiver model
│   │   │   ├── medication.dart      # Medication model
│   │   │   ├── prescription.dart    # Prescription tracking
│   │   │   ├── reminder.dart        # Reminders/tasks
│   │   │   ├── geo_zone.dart        # Geofencing zones
│   │   │   ├── health_profile.dart  # Health information
│   │   │   └── user_profile.dart    # User profile data
│   │   ├── services/                # Business logic
│   │   │   ├── auth_service.dart    # Firebase authentication
│   │   │   ├── location_service.dart # GPS & navigation
│   │   │   ├── notification_service.dart # Push notifications
│   │   │   ├── reminder_service.dart # Reminder scheduling
│   │   │   ├── tts_service.dart     # Text-to-speech
│   │   │   ├── geofence_service.dart # Geofencing alerts
│   │   │   ├── medical_info_service.dart # Medical profile
│   │   │   ├── app_protection_service.dart # Kiosk mode
│   │   │   ├── user_profile_service.dart # Profile management
│   │   │   └── screenshot_feedback_service.dart # Bug reports
│   │   ├── providers/               # State management
│   │   │   ├── app_state_provider.dart
│   │   │   ├── user_provider.dart
│   │   │   └── caregiver_provider.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Accessibility-focused theming
│   │   └── widgets/                 # Reusable components
│   │       ├── large_action_tile.dart # Main action buttons
│   │       └── reminder_popup.dart  # Full-screen reminders
│   └── features/
│       ├── splash/                  # Splash screen
│       ├── setup/                   # Initial setup flow
│       ├── user_home/               # Main user interface
│       ├── navigation/              # GPS navigation
│       ├── contacts/                # Contact list
│       ├── reminders/               # Reminders display
│       ├── feedback/                # Bug report screen
│       └── caregiver/               # Caregiver management screens
│           ├── caregiver_login_screen.dart
│           ├── caregiver_dashboard_screen.dart
│           ├── manage_contacts_screen.dart
│           ├── manage_locations_screen.dart
│           ├── manage_medications_screen.dart
│           ├── manage_reminders_screen.dart
│           ├── manage_zones_screen.dart
│           ├── medical_profile_screen.dart
│           ├── user_profile_screen.dart
│           └── app_protection_screen.dart
├── android/                         # Android native code
├── ios/                             # iOS native code
├── functions/                       # Firebase Cloud Functions
├── assets/
│   ├── images/
│   ├── sounds/
│   └── fonts/
├── firestore.rules                  # Database security rules
├── storage.rules                    # Storage security rules
└── pubspec.yaml                     # Dependencies
```

## Key Features

### For Users (Alzheimer's/Cognitive Impairment)
- **Large Action Tiles** - 6 big colorful buttons on home screen
- **One-Tap Navigation** - Google Maps directions to home
- **Quick Call** - Call caregivers with one tap
- **Voice Prompts** - Text-to-speech for all alerts
- **Full-Screen Reminders** - Medication and task reminders
- **No Login Required** - Opens directly to main screen

### For Caregivers
- **Secure Login** - Hidden access (5 taps on header)
- **Real-Time Location** - Track user location on map
- **Geofencing** - Alerts when user leaves safe zones
- **Medical Profile** - Complete health records
- **Prescription Tracking** - Refill alerts and history
- **Remote Management** - Configure everything remotely
- **App Protection** - Prevent app deletion (kiosk mode)

## Theme Colors

```dart
// Primary tile colors (accessibility-optimized)
Blue:   #1E88E5  // Navigation/Home
Green:  #43A047  // Call
Red:    #E53935  // Emergency
Orange: #FF9800  // Medications
Purple: #8E24AA  // Reminders
Cyan:   #00ACC1  // Help
```

## Firebase Collections

| Collection | Purpose |
|------------|---------|
| `users` | User profiles and settings |
| `caregivers` | Caregiver accounts |
| `reminders` | Medication and task reminders |
| `medications` | Medication information |
| `geo_zones` | Geofencing boundaries |
| `feedback` | Bug reports and feedback |
| `users/{id}/location_updates` | Location history |

## Commands

```bash
# Install dependencies
flutter pub get

# Run in development
flutter run

# Build for release
flutter build apk --release    # Android
flutter build ios --release    # iOS
flutter build web --release    # Web

# Deploy Firebase functions
cd functions && npm install && firebase deploy --only functions

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules
```

## Setup Requirements

1. **Firebase Project** - Create at console.firebase.google.com
2. **Google Maps API Keys** - Enable Maps SDK for iOS/Android
3. **FlutterFire CLI** - Run `flutterfire configure`
4. **Xcode** - For iOS development
5. **Android Studio** - For Android development

## Development Notes

### Hidden Caregiver Access
Users access caregiver mode by tapping the header 5 times quickly. This keeps the interface simple for users while allowing caregivers to access management features.

### Screenshot Feedback
The app includes TestFlight-style screenshot feedback for bug reports during development. It's automatically disabled in release builds (`!kReleaseMode`).

### App Protection (Kiosk Mode)
- **Android**: Device Administrator or screen pinning
- **iOS**: Requires Guided Access (system setting)
- Protected by caregiver PIN

### Voice Prompts
All reminders and alerts use text-to-speech via `flutter_tts`. Configurable per-user in settings.

---

## Development Log

### Session 1 - Project Setup (Current)
**Date:** 2026-02-01

**Completed:**
- [x] Extracted lumina_app.zip and screenshot_feedback_package.zip
- [x] Set up Flutter project structure
- [x] Screenshot feedback service integrated into main app
- [x] Created claude.md for development tracking

**Project Status:** Ready for Firebase configuration and testing

**Next Steps:**
- [ ] Configure Firebase project
- [ ] Add Google Maps API keys
- [ ] Run `flutter pub get` to install dependencies
- [ ] Test on iOS/Android simulator
- [ ] Review and test all features

---

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Provider + Riverpod | Simple state management, good for reactive UI |
| Firebase | Real-time sync, offline support, easy auth |
| Large tiles (2-column grid) | Accessibility for cognitive impairment |
| High contrast colors | Better visibility for older users |
| Portrait-only mode | Simpler, less disorienting |
| Hidden caregiver access | Clean UI for users, full control for caregivers |

## Important Files Reference

| File | Purpose |
|------|---------|
| [lib/main.dart](lib/main.dart) | App initialization and providers |
| [lib/features/user_home/user_home_screen.dart](lib/features/user_home/user_home_screen.dart) | Main user interface |
| [lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart) | Theme and colors |
| [lib/core/services/auth_service.dart](lib/core/services/auth_service.dart) | Authentication |
| [lib/core/models/app_user.dart](lib/core/models/app_user.dart) | User data model |
| [firestore.rules](firestore.rules) | Database security |
