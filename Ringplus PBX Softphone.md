# Ringplus PBX Softphone

A production-ready multitenant PBX softphone built with Flutter + WebRTC for Android and iOS platforms.

## Overview

Ringplus is a professional VoIP softphone application that connects to cloud PBX systems, providing crystal-clear voice calls, advanced call management, and seamless business communication features.

## Features

### Core Functionality
- **HD Voice Calls**: Crystal-clear audio quality with WebRTC
- **SIP Registration**: Manual credential entry with secure storage
- **Call Management**: Make, receive, hold, transfer, and redirect calls
- **DTMF Support**: In-call keypad for interactive voice response
- **Contact Management**: Local contacts with CRUD operations
- **Call History**: Comprehensive call logs with filtering
- **Voicemail**: Playback and management with unread indicators
- **Settings**: Account management and call configuration

### Technical Features
- **Cross-Platform**: Native iOS and Android support
- **Push Notifications**: Firebase (Android) + VoIP PushKit (iOS)
- **Secure Storage**: Keychain (iOS) and Keystore (Android)
- **Internationalization**: English and French with RTL support
- **Accessibility**: WCAG AA compliance with screen reader support
- **Dark Mode**: Automatic and manual theme switching
- **Responsive Design**: Adaptive layouts for different screen sizes

## Architecture

### Project Structure
```
lib/
├── core/
│   ├── constants/          # App constants and configuration
│   ├── theme/             # Theme and styling definitions
│   ├── services/          # Core services (SIP, Navigation, Notifications)
│   └── utils/             # Utility functions and helpers
├── features/
│   ├── auth/              # Authentication and onboarding
│   ├── keypad/            # Dialing and keypad functionality
│   ├── recents/           # Call history and logs
│   ├── contacts/          # Contact management
│   ├── voicemail/         # Voicemail functionality
│   ├── settings/          # App configuration
│   └── call/              # Call management and UI
└── shared/
    ├── widgets/           # Reusable UI components
    ├── services/          # Shared services
    └── models/            # Data models
```

### Key Dependencies
- **dart_sip_ua**: SIP protocol implementation
- **flutter_webrtc**: WebRTC media handling
- **firebase_messaging**: Push notifications (Android)
- **flutter_voip_pushkit**: VoIP push notifications (iOS)
- **flutter_callkit_incoming**: Native call UI integration
- **flutter_secure_storage**: Secure credential storage
- **go_router**: Navigation and routing
- **riverpod**: State management

## Design System

### Color Palette
- **Primary Purple**: `#6B46C1` - Main brand color
- **Primary Purple Light**: `#8B5CF6` - Secondary elements
- **Secondary Purple**: `#9333EA` - Accent elements
- **Accent Purple**: `#DDD6FE` - Light backgrounds

### Typography
- **Android**: Roboto (Regular, Medium, Bold)
- **iOS**: SF Pro Display (Regular, Medium, Bold)

### Component Specifications
- **Touch Targets**: Minimum 44px x 44px
- **Buttons**: 48px height (standard), 56px (prominent)
- **Keypad Buttons**: 72px x 72px
- **Bottom Navigation**: 80px height

## Setup Instructions

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / Xcode for platform-specific development
- Firebase project for push notifications

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ringplus_pbx
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase (Android)**
   - Add `google-services.json` to `android/app/`
   - Update `android/app/build.gradle` with Firebase configuration

4. **Configure iOS**
   - Add VoIP Push capability in Xcode
   - Configure CallKit integration
   - Add required permissions to `Info.plist`

5. **Run the application**
   ```bash
   flutter run
   ```

### Configuration

#### SIP Settings
Default SIP configuration can be modified in `lib/core/constants/app_constants.dart`:
```dart
static const String defaultSipDomain = 'sip.ringplus.com';
static const int defaultSipPort = 5060;
static const String defaultStunServer = 'stun:stun.l.google.com:19302';
```

#### Push Notifications
Configure push notification topics in the same file:
```dart
static const String fcmTopicCalls = 'calls';
static const String fcmTopicVoicemail = 'voicemail';
```

## Usage

### Authentication
1. Launch the app to see the splash screen
2. If no credentials are stored, navigate to the welcome screen
3. Tap "Enter Details Manually" to access the login screen
4. Enter SIP credentials (username, password, domain, port)
5. Enable "Remember my credentials" for automatic login

### Making Calls
1. Navigate to the Keypad tab
2. Enter the phone number using the dialpad
3. Tap the call button to initiate the call
4. Use in-call controls for mute, hold, speaker, transfer

### Managing Contacts
1. Navigate to the Contacts tab
2. Tap the "+" button to add new contacts
3. Use the search bar to find existing contacts
4. Tap a contact to view details or make a call

### Call History
1. Navigate to the Recents tab
2. View chronological list of calls
3. Use filters to sort by call type
4. Tap an entry to call back or view details

### Voicemail
1. Navigate to the Voicemail tab
2. View list of voicemails with unread indicators
3. Tap a voicemail to play and manage
4. Mark as read/unread as needed

### Settings
1. Navigate to the Settings tab
2. Configure account settings and call options
3. Manage notifications and audio preferences
4. Adjust appearance and privacy settings

## Platform-Specific Features

### iOS
- Large title navigation bars
- CallKit integration for native call experience
- VoIP push notifications for background calls
- iOS-specific icons and design patterns

### Android
- Material Design 3 components
- Firebase Cloud Messaging for notifications
- ConnectionService for call management
- Android-specific navigation patterns

## Accessibility

### WCAG AA Compliance
- Minimum 4.5:1 contrast ratio for normal text
- Minimum 3:1 contrast ratio for large text and UI components
- Proper heading hierarchy and semantic markup
- Screen reader compatibility with meaningful labels

### Touch Targets
- Minimum 44px x 44px for all interactive elements
- Recommended 48px x 48px for primary actions
- Minimum 8px spacing between adjacent targets

### Motion and Animation
- Respects system "Reduce Motion" preferences
- Consistent animation durations and easing curves
- Optional animation disable in accessibility settings

## Internationalization

### Supported Languages
- English (en_US) - Default
- French (fr_FR)

### RTL Support
- Automatic layout mirroring for RTL languages
- Proper text direction handling
- Icon direction adjustments where appropriate

### Implementation
Localization files are located in `lib/l10n/` with automatic generation enabled in `pubspec.yaml`:
```yaml
flutter:
  generate: true
```

## Security

### Credential Storage
- iOS: Keychain with `first_unlock_this_device` accessibility
- Android: Encrypted SharedPreferences with Keystore

### Network Security
- SIP over WebSocket Secure (WSS)
- SRTP for media encryption
- TLS certificate validation

### Privacy
- No data collection without user consent
- Local storage of contacts and call history
- Secure deletion of user data on logout

## Testing

### Unit Tests
```bash
flutter test test/unit/
```

### Widget Tests
```bash
flutter test test/widget/
```

### Integration Tests
```bash
flutter test test/integration/
```

## Deployment

### Android
1. Build release APK:
   ```bash
   flutter build apk --release
   ```

2. Build App Bundle for Play Store:
   ```bash
   flutter build appbundle --release
   ```

### iOS
1. Build for iOS:
   ```bash
   flutter build ios --release
   ```

2. Archive in Xcode for App Store submission

## Contributing

### Code Style
- Follow Dart/Flutter style guidelines
- Use meaningful variable and function names
- Add documentation for public APIs
- Maintain consistent formatting with `dart format`

### Pull Request Process
1. Create feature branch from main
2. Implement changes with tests
3. Update documentation as needed
4. Submit pull request with detailed description

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support or questions:
- Email: support@ringplus.com
- Documentation: https://docs.ringplus.com
- Issues: GitHub Issues page

## Changelog

### Version 1.0.0
- Initial release with core VoIP functionality
- SIP registration and call management
- Contact and voicemail management
- Push notification support
- Cross-platform iOS and Android support
- Internationalization and accessibility features

