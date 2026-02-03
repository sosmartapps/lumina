# Lumina - Alzheimer's Care App

A comprehensive Flutter application designed to help people with Alzheimer's disease and other cognitive impairments navigate daily life safely, while providing caregivers with tools to manage care remotely.

## 🌟 Features

### For Users (People with Cognitive Impairments)

- **Large, Easy-to-Use Interface** - Big colorful tiles with simple icons
- **One-Tap Navigation Home** - Instantly get Google Maps directions to home
- **Quick Call Contacts** - Call caregivers or emergency contacts with one tap
- **Saved Locations** - Navigate to frequently visited places easily
- **Medication Reminders** - Full-screen alerts with voice prompts
- **Task Reminders** - Reminders for daily tasks like "Feed the dog"
- **Voice Prompts** - Text-to-speech for all alerts and reminders
- **No Login Required** - App opens directly to main screen after setup

### For Caregivers

- **Secure Login** - Email/password or phone authentication
- **Real-Time Location Tracking** - See user's location on a map
- **Geofencing Alerts** - Get notified when user leaves safe zones
- **Medical Profile Management** - Complete health record management (see below)
- **Medication Management** - Set up schedules with photo verification
- **Prescription Tracking** - Track refills and get alerts when prescriptions need filling
- **Reminder Creation** - Create custom reminders with spoken messages
- **Emergency Contact Management** - Add/edit quick-dial contacts
- **Location Management** - Add frequently visited places
- **Activity History** - View medication compliance and location history
- **App Protection** - Prevent accidental app deletion (see below)

### 📋 Medical Profile Features

Comprehensive health information management for sharing with medical personnel:

#### Health Information Tracked
- **Health Conditions** - Diagnoses, severity, treating physicians
- **Allergies** - Allergens, reactions, severity levels
- **Prescriptions** - Complete medication list with refill tracking
- **Healthcare Providers** - Doctors, specialists, contact info
- **Insurance Information** - Provider, policy, and group numbers
- **Emergency Notes** - Critical info for first responders
- **Advance Directives** - Living will, DNR, healthcare proxy

#### Prescription Refill Tracking
- Tracks remaining pills and refills
- Alerts when refill is needed (customizable days before)
- Alerts when no refills remain (contact doctor)
- Records refill history
- Pharmacy information

#### Shareable Medical Summary
- One-tap sharing of complete medical profile
- Formatted for easy reading by medical staff
- Includes allergies, conditions, medications, providers
- Perfect for ER visits, new doctors, pharmacies

### 🛡️ App Protection Features

Prevent users from accidentally deleting or exiting the app:

#### Android Protection Options

1. **Prevent App Deletion (Device Admin)**
   - Uses Android's Device Administrator feature
   - App cannot be uninstalled while active
   - Requires caregiver PIN to disable

2. **Kiosk Mode**
   - Locks the device to only show the app
   - User cannot access home screen or other apps
   - Full device lockdown for maximum protection

3. **Screen Pinning**
   - Lighter alternative to kiosk mode
   - Pins app to screen
   - User can unpin with Back + Recent buttons (harder to discover)

#### iOS Protection Options

Since iOS doesn't allow apps to control uninstallation:

1. **Guided Access**
   - Built-in iOS feature
   - Settings > Accessibility > Guided Access
   - Triple-click side button to lock to app

2. **Screen Time Restrictions**
   - Settings > Screen Time > Content & Privacy Restrictions
   - Set "Deleting Apps" to Don't Allow
   - Use a passcode the user doesn't know

#### Caregiver PIN

- Set a 4-6 digit PIN to protect settings
- Required to disable any protection features
- Only caregivers should know this PIN

### 📸 Screenshot Feedback Feature

TestFlight-style screenshot feedback for bug reports and suggestions:

- **Auto-Detection**: Automatically detects when screenshots are taken
- **Feedback Prompt**: Prompts user to send feedback with the screenshot
- **Bug Reports**: Easy bug reporting with screenshot attachments
- **Email Notifications**: Admin receives emails when feedback is submitted
- **Debug Only**: Feature is automatically disabled in release builds

#### How It Works

1. Take a screenshot while using the app (during development/testing)
2. A prompt appears asking if you want to send feedback
3. Fill in the feedback form with description
4. Screenshots are automatically attached
5. Admin receives email notification with all details

## 📱 Supported Platforms

- iOS
- Android
- Web

## 🛠 Tech Stack

- **Framework**: Flutter 3.2+
- **Backend**: Firebase
  - Authentication (Email/Phone)
  - Cloud Firestore (Database)
  - Cloud Storage (Photos)
  - Cloud Messaging (Push Notifications)
- **Maps**: Google Maps SDK
- **Location**: Geolocator package
- **State Management**: Provider + Riverpod

## 📋 Prerequisites

1. Flutter SDK 3.2.0 or higher
2. Dart 3.0 or higher
3. Firebase account
4. Google Cloud account (for Maps API)
5. Xcode (for iOS development)
6. Android Studio (for Android development)

## 🚀 Setup Instructions

### 1. Clone and Install Dependencies

```bash
cd caregiver_app
flutter pub get
```

### 2. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)

2. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

3. Configure Firebase:
```bash
flutterfire configure
```

4. Enable these Firebase services:
   - **Authentication**: Enable Email/Password and Phone providers
   - **Cloud Firestore**: Create database in production mode
   - **Cloud Storage**: Create default bucket
   - **Cloud Messaging**: Enable for push notifications

### 3. Google Maps Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable these APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Maps JavaScript API (for web)
   - Directions API
   - Geocoding API

3. Create API keys for each platform

4. Add keys to your app:

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ANDROID_API_KEY"/>
```

**iOS** (`ios/Runner/AppDelegate.swift`):
```swift
GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
```

**Web** (`web/index.html`):
```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_WEB_API_KEY"></script>
```

### 4. Platform-Specific Configuration

#### Android (`android/app/src/main/AndroidManifest.xml`)

Add these permissions:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

#### iOS (`ios/Runner/Info.plist`)

Add these entries:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to help navigate to saved places</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs background location access to keep caregivers informed of your location</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to verify medication was taken</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice features</string>
```

### 5. Firestore Security Rules

Deploy these security rules to your Firestore:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null &&
        (request.auth.uid == userId ||
         resource.data.caregiverIds.hasAny([request.auth.uid]));
      allow write: if request.auth != null &&
        resource.data.caregiverIds.hasAny([request.auth.uid]);
    }

    // Caregivers collection
    match /caregivers/{caregiverId} {
      allow read, write: if request.auth != null &&
        request.auth.uid == caregiverId;
    }

    // Reminders collection
    match /reminders/{reminderId} {
      allow read, write: if request.auth != null;
    }

    // Medications collection
    match /medications/{medicationId} {
      allow read, write: if request.auth != null;
    }

    // Geo zones collection
    match /geo_zones/{zoneId} {
      allow read, write: if request.auth != null;
    }

    // Location updates
    match /users/{userId}/location_updates/{updateId} {
      allow read: if request.auth != null;
      allow write: if true; // Allow device to update
    }
  }
}
```

### 6. Run the App

```bash
# Development
flutter run

# Build for release
flutter build apk --release  # Android
flutter build ios --release  # iOS
flutter build web --release  # Web
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── core/
│   ├── models/              # Data models
│   │   ├── app_user.dart
│   │   ├── caregiver.dart
│   │   ├── reminder.dart
│   │   ├── medication.dart
│   │   └── geo_zone.dart
│   ├── services/            # Business logic
│   │   ├── auth_service.dart
│   │   ├── location_service.dart
│   │   ├── notification_service.dart
│   │   ├── reminder_service.dart
│   │   ├── tts_service.dart
│   │   ├── geofence_service.dart
│   │   ├── app_protection_service.dart
│   │   └── screenshot_feedback_service.dart
│   ├── providers/           # State management
│   │   ├── app_state_provider.dart
│   │   ├── user_provider.dart
│   │   └── caregiver_provider.dart
│   ├── theme/               # UI theming
│   │   └── app_theme.dart
│   └── widgets/             # Reusable components
│       ├── large_action_tile.dart
│       └── reminder_popup.dart
└── features/
    ├── splash/              # Splash screen
    ├── setup/               # Initial setup flow
    ├── user_home/           # Main user screen
    ├── navigation/          # Navigation screen
    ├── contacts/            # Contacts screen
    ├── reminders/           # Reminders screen
    ├── feedback/            # Screenshot feedback feature
    │   └── bug_report_screen.dart
    └── caregiver/           # Caregiver screens
        ├── caregiver_login_screen.dart
        ├── caregiver_dashboard_screen.dart
        ├── manage_contacts_screen.dart
        ├── manage_locations_screen.dart
        ├── manage_medications_screen.dart
        ├── manage_reminders_screen.dart
        ├── manage_zones_screen.dart
        └── app_protection_screen.dart
```

## 🔧 Configuration Options

### User Settings (configurable by caregiver)

- High contrast mode
- Text scale factor
- Sound enabled/disabled
- Vibration enabled/disabled
- Voice prompts enabled/disabled
- Reminder volume
- Voice language

### Reminder Types

- Medication
- Task
- Appointment
- Meal time
- Hydration
- Exercise
- Pet care
- General

### Geofence Zone Types

- Home (alert on exit)
- Safe zone (alert on exit)
- Danger zone (alert on entry)
- Work/Day center
- Medical facility

## 🔐 Security Features

- Caregiver authentication required for management features
- Hidden caregiver access (5 taps on header)
- Firebase security rules for data protection
- No user credentials stored on device
- Background location permission managed separately

## 📞 Support

For issues or feature requests, please create an issue in the repository.

## 📄 License

This project is licensed under the MIT License.

---

Built with ❤️ for caregivers and their loved ones
