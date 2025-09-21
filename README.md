# ringplus_pbx

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# rp_flutter_webrtc

Option 1: From Flutter
flutter clean
flutter uninstall
flutter run

Option 2: From ADB
adb uninstall com.ringplus.app

Then run again:

flutter run

Option 3: From device

Manually uninstall the app from your phone (long press → uninstall).

Then flutter run again.

---

4. Build release APK (for testing before Play Store)

Run:

flutter build apk --release

This produces:
build/app/outputs/flutter-apk/app-release.apk

You can install it on a device:

flutter install

🔹 5. Build release AAB (for Play Store)

Google Play requires an App Bundle (.aab) instead of APK. Run:

flutter build appbundle --release

This produces:
build/app/outputs/bundle/release/app-release.aab

That is the file you’ll upload to the Google Play Console.
