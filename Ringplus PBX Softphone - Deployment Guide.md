# Ringplus PBX Softphone - Deployment Guide

This guide provides step-by-step instructions for deploying the Ringplus PBX softphone to production environments.

## Pre-Deployment Checklist

### Code Quality
- [ ] All unit tests passing
- [ ] Widget tests covering critical UI components
- [ ] Integration tests for core user flows
- [ ] Code review completed
- [ ] Performance testing completed
- [ ] Security audit completed

### Configuration
- [ ] Production SIP server endpoints configured
- [ ] Firebase project set up for production
- [ ] Push notification certificates configured
- [ ] App signing certificates ready
- [ ] Privacy policy and terms of service updated

### Assets
- [ ] App icons generated for all required sizes
- [ ] Splash screens created for both platforms
- [ ] Store listing assets prepared
- [ ] Screenshots captured for app stores

## Android Deployment

### 1. Prepare Release Build

#### Configure Signing
Create `android/key.properties`:
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-keystore-file>
```

#### Update `android/app/build.gradle`
```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 2. Configure Firebase

#### Add Production Configuration
1. Download `google-services.json` from Firebase Console
2. Place in `android/app/` directory
3. Ensure FCM is properly configured for production

#### Update Notification Channels
In `android/app/src/main/kotlin/MainActivity.kt`:
```kotlin
class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "incoming_calls",
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            )
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
```

### 3. Build Release

#### Build APK
```bash
flutter build apk --release --target-platform android-arm64
```

#### Build App Bundle (Recommended)
```bash
flutter build appbundle --release
```

### 4. Play Store Submission

#### Store Listing
- **Title**: Ringplus - Business VoIP Phone
- **Short Description**: Professional VoIP softphone for business communications
- **Full Description**: Include feature list and benefits
- **Category**: Business
- **Content Rating**: Everyone

#### Required Permissions
Ensure these permissions are documented:
- `INTERNET` - Network communication
- `RECORD_AUDIO` - Voice calls
- `MODIFY_AUDIO_SETTINGS` - Audio routing
- `WAKE_LOCK` - Keep device awake during calls
- `VIBRATE` - Incoming call notifications
- `READ_PHONE_STATE` - Call state management

## iOS Deployment

### 1. Xcode Configuration

#### Update Info.plist
Add required permissions and capabilities:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice calls</string>
<key>NSContactsUsageDescription</key>
<string>This app needs contacts access to manage your business contacts</string>
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>background-processing</string>
</array>
```

#### Configure Capabilities
In Xcode project settings, enable:
- Voice over IP
- Push Notifications
- Background App Refresh

### 2. Certificates and Provisioning

#### VoIP Push Certificate
1. Create VoIP Services Certificate in Apple Developer Portal
2. Download and install in Keychain
3. Export as .p12 file for server configuration

#### App Store Provisioning Profile
1. Create App Store distribution provisioning profile
2. Download and install in Xcode
3. Select for release builds

### 3. Build for Release

#### Archive Build
```bash
flutter build ios --release
```

#### Xcode Archive
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Upload to App Store Connect

### 4. App Store Submission

#### App Store Connect Configuration
- **App Information**: Complete all required fields
- **Pricing**: Set appropriate pricing tier
- **App Review Information**: Provide test credentials
- **Version Information**: Include what's new

#### Review Guidelines Compliance
- Ensure app follows iOS Human Interface Guidelines
- Test on multiple device sizes and orientations
- Verify accessibility features work correctly
- Test with VoiceOver enabled

## Server Configuration

### SIP Server Setup

#### Asterisk Configuration
Example `sip.conf` configuration:
```ini
[general]
context=default
allowoverlap=no
udpbindaddr=0.0.0.0:5060
tcpenable=yes
tcpbindaddr=0.0.0.0:5060
transport=udp,tcp,ws,wss

[ringplus-template](!)
type=friend
host=dynamic
context=internal
disallow=all
allow=ulaw,alaw,g722,opus
dtmfmode=rfc2833
```

#### WebRTC Gateway
Configure WebRTC-to-SIP gateway:
- Kamailio with WebSocket support
- FreeSWITCH with mod_verto
- Asterisk with chan_sip and WebSocket transport

### Push Notification Server

#### Firebase Setup
1. Configure Firebase Cloud Functions for call notifications
2. Set up FCM topic subscriptions
3. Implement server-side push logic

#### iOS VoIP Push
1. Configure VoIP push certificate on server
2. Implement PushKit payload format
3. Test background call delivery

## Monitoring and Analytics

### Crash Reporting
Integrate Firebase Crashlytics:
```yaml
dependencies:
  firebase_crashlytics: ^3.4.8
```

### Analytics
Track key metrics:
- Call success rates
- Registration failures
- User engagement
- Performance metrics

### Logging
Implement structured logging:
```dart
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);
```

## Security Considerations

### Network Security
- Use TLS 1.2+ for all communications
- Implement certificate pinning
- Validate server certificates
- Use SRTP for media encryption

### Data Protection
- Encrypt local storage
- Implement secure key management
- Regular security audits
- GDPR compliance for EU users

### Authentication
- Strong password requirements
- Optional two-factor authentication
- Session timeout management
- Secure credential storage

## Performance Optimization

### App Size Optimization
```bash
flutter build apk --release --split-per-abi
```

### Memory Management
- Implement proper disposal of resources
- Monitor memory usage during calls
- Optimize image loading and caching

### Battery Optimization
- Minimize background processing
- Use efficient audio codecs
- Implement smart wake lock management

## Testing Strategy

### Automated Testing
```bash
# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# Integration tests
flutter drive --target=test_driver/app.dart
```

### Manual Testing
- Test on various device models
- Verify call quality on different networks
- Test push notifications in background
- Validate accessibility features

### Load Testing
- Simulate multiple concurrent calls
- Test server capacity limits
- Monitor performance under load

## Rollout Strategy

### Phased Deployment
1. **Alpha**: Internal testing team
2. **Beta**: Limited external users
3. **Staged Rollout**: Gradual percentage increase
4. **Full Release**: 100% availability

### Monitoring
- Real-time crash monitoring
- Performance metrics tracking
- User feedback collection
- Server health monitoring

### Rollback Plan
- Ability to quickly revert to previous version
- Database migration rollback procedures
- Communication plan for users

## Post-Deployment

### Maintenance
- Regular security updates
- Performance monitoring
- Bug fix releases
- Feature updates

### Support
- User documentation
- FAQ and troubleshooting guides
- Support ticket system
- Community forums

### Compliance
- Regular security audits
- Privacy policy updates
- Terms of service maintenance
- Regulatory compliance monitoring

This deployment guide ensures a smooth and secure release of the Ringplus PBX softphone to production environments.

