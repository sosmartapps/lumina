# Secrets Setup Guide

This project requires several configuration files that contain API keys. These files are **not** included in the repository for security reasons.

## Required Files

### 1. Firebase Options (Flutter)
**File:** `lib/firebase_options.dart`

**Setup:**
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (this generates firebase_options.dart automatically)
flutterfire configure --project=lumina-sosmartapps
```

Or copy `lib/firebase_options.dart.template` and fill in your values manually.

### 2. iOS Firebase Configuration
**File:** `ios/Runner/GoogleService-Info.plist`

**Setup:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Project Settings → Your apps → iOS app
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/`

### 3. Android Firebase Configuration
**File:** `android/app/google-services.json`

**Setup:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Project Settings → Your apps → Android app
3. Download `google-services.json`
4. Place it in `android/app/`

### 4. macOS Firebase Configuration
**File:** `macos/Runner/GoogleService-Info.plist`

**Setup:**
Same as iOS - download from Firebase Console for your macOS app.

### 5. iOS Secrets (Share Extension)
**File:** `ios/Flutter/Secrets.xcconfig`

**Setup:**
Create the file with:
```xcconfig
GMS_API_KEY=your_google_maps_api_key
REPAIR_TASK_API_KEY=your_share_extension_api_key
```

## Security Notes

- **NEVER** commit files containing API keys to version control
- All sensitive files are listed in `.gitignore`
- If you accidentally commit secrets, rotate them immediately in the respective consoles
- Use environment variables for CI/CD pipelines

## Firebase Project Info

- **Project ID:** lumina-sosmartapps
- **Console:** https://console.firebase.google.com/project/lumina-sosmartapps

## Rotating Compromised Keys

If API keys are exposed:

1. **Firebase API Keys:** Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → API Keys → Regenerate
2. **Share Extension API Key:** Run `firebase functions:secrets:set VSCODE_REPAIR_API_KEY`
