# Be My Guide (Flutter)

Be My Guide is a Flutter mobile application that uses Firebase for authentication and Agora for real-time video streaming. This README explains how to set up the project locally, configure Firebase and Agora, run the app, and common troubleshooting steps.

> NOTE: This README assumes the repository's main branch is `main`. Adjust paths/branch names if you use a different branch.

## Table of contents
- Features
- Requirements
- Quick start
- Firebase setup (Android & iOS)
- Agora setup
- Configuration / Environment
- Android-specific changes
- iOS-specific changes
- Useful commands
- Troubleshooting
- Security & production notes
- Contributing
- License

## Features
- Email/password authentication using Firebase Authentication
- Google Sign-In (optional, if configured)
- Real-time video calls using Agora SDK (one-to-one or group channels depending on your implementation)
- Minimal UI wiring for login, join/leave video channel, and basic in-call controls (mute/unmute, camera toggle)

## Requirements
- Flutter SDK (stable) — recommended: latest stable release
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode for device/emulator
- A Firebase project
- An Agora project (App ID; optional Token for production)
- Internet access on test devices

Tested with:
- Flutter 3.x / 4.x (update instructions below if using specific Flutter version)
- agora_rtc_engine (or Agora UIKit) package — check pubspec for exact version
- firebase_core, firebase_auth packages

## Quick start (development)
1. Clone the repo:
   - git clone https://github.com/Mahmoud-Elmokaber/be-my-guide.git
   - cd be-my-guide

2. Install dependencies:
   - flutter pub get

3. Add Firebase config files (see Firebase setup below).

4. Add Agora credentials (see Agora setup below).

5. Run the app:
   - flutter run

## Firebase setup

You must configure Firebase for Android and iOS so authentication works.

1. Go to Firebase Console: https://console.firebase.google.com/
2. Create a new project (or use an existing one).
3. Add Android app:
   - Package name must match your Flutter Android package (android/app/src/main/AndroidManifest.xml `applicationId` / package in `android/app/build.gradle`).
   - Download `google-services.json`.
   - Place `google-services.json` in `android/app/`.

4. Add iOS app:
   - Bundle ID must match your Xcode project bundle identifier (`ios/Runner.xcodeproj`, typically `com.example.app`).
   - Download `GoogleService-Info.plist`.
   - Place `GoogleService-Info.plist` in `ios/Runner/` (add to Xcode project if needed).

5. Enable the authentication providers you need:
   - In Firebase Console > Authentication > Sign-in method, enable Email/Password and any other providers (Google, Apple, etc.)
   - If you enable Google Sign-In, follow the instructions for configuring OAuth client IDs.

6. Add Firebase packages to pubspec.yaml (example):
   - firebase_core
   - firebase_auth
   - (optionally cloud_firestore, firebase_storage, etc.)

7. Initialize Firebase in Flutter before using auth (usually in `main.dart`):
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

## Agora setup

1. Create an Agora project at https://console.agora.io/
2. Copy your App ID. For development you can either:
   - Use a temporary token generated from the Agora Console (recommended if you enabled App Certificate)
   - Or disable App Certificate in the Agora Console for easier testing (NOT recommended for production)

3. In your app, configure these values:
   - AGORA_APP_ID
   - AGORA_TOKEN (optional; leave empty when App Certificate is disabled)
   - AGORA_CHANNEL (channel name to join/create)

4. Add the Agora Flutter package to `pubspec.yaml` — common choices:
   - agora_rtc_engine
   - agora_uikit (wrapper for easier integration)

5. Example very small snippet to join a channel (pseudo):
```dart
// initialize engine
RtcEngine engine = await RtcEngine.create(APP_ID);
await engine.enableVideo();
await engine.joinChannel(TOKEN, CHANNEL_NAME, null, 0);
```
Refer to the Agora package docs for full API details and best practices (token lifecycle, RTC callbacks, channel/event handling, etc.).

## Configuration / Environment

The project expects you to provide Agora credentials and Firebase files. You can:
- Add a `.env` or `.env.example` with placeholders:
  - AGORA_APP_ID=your_app_id_here
  - AGORA_TOKEN=your_token_or_empty_for_dev
  - AGORA_CHANNEL=default_channel

- Or set them via a platform-specific mechanism (gradle properties, Xcode build settings, secrets manager).

Never commit secrets (App Certificate, production tokens) to the repository.

## Android-specific changes

1. AndroidManifest permissions (android/app/src/main/AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

2. Set minSdkVersion (android/app/build.gradle):
- Agora may require minSdkVersion >= 21 or 23 depending on SDK version. Example:
```
defaultConfig {
    minSdkVersion 21
    // ...
}
```

3. Add google-services plugin in `android/build.gradle` and `android/app/build.gradle` per Firebase instructions:
- In `android/build.gradle`:
  - classpath 'com.google.gms:google-services:4.3.14' (check latest)
- In `android/app/build.gradle` at bottom:
  - apply plugin: 'com.google.gms.google-services'

4. Request runtime permissions for camera/microphone (use permission_handler or request via platform channels / Flutter runtime).

## iOS-specific changes

1. Info.plist must include privacy descriptions (ios/Runner/Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for audio during calls</string>
```

2. Set platform in `ios/Podfile` (if needed):
```
platform :ios, '11.0'
```
(Agora iOS SDK may require higher; use 11.0 or 12.0 depending on the package version)

3. Add `GoogleService-Info.plist` to the Runner target in Xcode.

4. For building on real devices, ensure signing & capabilities are configured in Xcode.

## Useful commands
- flutter pub get
- flutter analyze
- flutter run (to run on selected device)
- flutter build apk --release
- flutter build ios --release (requires Mac + Xcode)
- flutter clean

## Troubleshooting

- "Missing google-services.json / GoogleService-Info.plist"
  - Ensure files are placed correctly and not ignored by .gitignore intentionally.

- "Permission denied for camera/mic"
  - Confirm runtime permission requests and Info.plist/AndroidManifest entries.

- Agora video not showing / black screen:
  - Confirm you enabled video (engine.enableVideo()) and joined the same channel with valid App ID and token (if required).
  - Confirm both users have camera permission and local preview enabled.

- Token/Authentication errors with Agora:
  - If using App Certificate, tokens must be generated server-side or via Agora token tool for testing.
  - For quick local testing, disable App Certificate in Agora console (not recommended for production).

- Crash on iOS after adding Agora:
  - Check Podfile platform, run `pod install` inside ios folder, and open workspace in Xcode.

## Security & production notes
- Do not embed production App Certificates or tokens in client apps. Use a secure token server to issue short-lived tokens to clients.
- Use Firebase security rules for any database or storage usage.
- Limit log output in production builds and secure any logging that could leak PII.

## Contributing
Contributions are welcome. Please open an issue or a pull request describing your change. Keep secrets out of commits.

## License
Specify your license here (MIT, Apache-2.0, etc.) or remove this section if using a different arrangement.

---

What I did: I created a comprehensive README tailored for a Flutter app that uses Firebase for authentication and Agora for video streaming. It includes setup steps for Firebase and Agora, platform-specific configuration (Android/iOS), environment guidance, commands, and troubleshooting notes.

What's next: If you'd like, I can:
- Commit this README directly to the `main` branch (open a PR) — tell me if you want that and whether to target `main` or another branch.
- Generate a starter `.env.example` file or add small sample code snippets (e.g., a Firebase auth flow or an Agora join function) in a new file.
- Update the repo's pubspec.yaml with suggested dependency versions and example configuration.

Which of those would you like me to do next?
