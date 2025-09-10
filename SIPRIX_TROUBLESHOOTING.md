# Siprix VoIP SDK Troubleshooting

## MissingPluginException: No implementation found for method Module_Initialize

This error occurs when the Siprix VoIP SDK native plugin isn't properly registered. Here are the solutions in order of likelihood:

### Solution 1: Hot Restart (Most Common)
```bash
# In your IDE or terminal:
# Press Ctrl+Shift+F5 (VS Code) or Cmd+Shift+R (Android Studio)
# OR run:
flutter run --hot
```
**Why**: Native plugins require hot restart, not hot reload.

### Solution 2: Platform Check
Siprix VoIP SDK does NOT support web platform. Ensure you're running on:
- iOS Simulator/Device
- Android Emulator/Device
- macOS (if supported)
- Windows/Linux (if supported)

```bash
# Test on iOS
flutter run -d ios

# Test on Android  
flutter run -d android
```

### Solution 3: Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

### Solution 4: License Key (Trial Mode)
The SDK works in trial mode with empty license, but some features may be limited:
```dart
InitData initData = InitData();
initData.license = ""; // Trial mode - calls limited to 60 seconds
```

### Solution 5: iOS Permissions (Already Configured)
Ensure your `ios/Runner/Info.plist` has:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone for making voice calls.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

### Solution 6: Android Permissions
Ensure your `android/app/src/main/AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Debugging Steps:

1. **Check Plugin Registration**:
   ```bash
   cat .flutter-plugins-dependencies | grep siprix
   ```
   Should show siprix_voip_sdk plugins for all platforms.

2. **Verify Imports**:
   ```dart
   import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';
   import 'package:siprix_voip_sdk/accounts_model.dart';
   import 'package:siprix_voip_sdk/calls_model.dart';
   ```

3. **Test Minimal Example**:
   ```dart
   Future<void> testSiprix() async {
     try {
       InitData initData = InitData();
       initData.license = "";
       
       SiprixVoipSdk sdk = SiprixVoipSdk();
       await sdk.initialize(initData);
       
       print('Siprix initialized successfully');
     } catch (e) {
       print('Siprix error: $e');
     }
   }
   ```

### Expected Behavior:
- **Trial Mode**: Calls limited to 60 seconds
- **Licensed Mode**: Full functionality
- **Supported Platforms**: iOS, Android, Windows, Linux, macOS
- **Not Supported**: Web browsers

### Getting Help:
- Technical Support: support@siprix-voip.com  
- Licensing: sales@siprix-voip.com
- GitHub: https://github.com/siprix/FlutterPluginFederated