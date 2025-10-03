# Push Notification Debugging Guide

## Current Implementation Status

### ✅ What's Implemented

1. **FCM Integration**
   - Firebase Core and Firebase Messaging initialized
   - FCM token generation and refresh handling
   - Background message handler (`@pragma('vm:entry-point')`)
   - Foreground message handler
   - Notification tap handlers

2. **SIP Integration**
   - X-Token header with FCM token in REGISTER
   - RFC 8599 push parameters in Contact URI:
     - `pn-provider=fcm`
     - `pn-param={FCM_TOKEN}`
     - `pn-prid=com.ringplus.app`
     - `pn-timeout=0`
     - `pn-silent=1`

3. **Wake-up Flow**
   - Background wake-up on push notification
   - SIP re-registration after wake-up
   - Auto-answer support for accepted calls

### 🔍 Debug Steps

#### Step 1: Verify FCM Token Generation
Run the app and check logs for:
```
Android: FCM Token: {TOKEN}
```

If missing, check:
- Firebase is initialized in main.dart
- google-services.json is in android/app/
- Firebase Messaging permissions granted

#### Step 2: Verify SIP Registration with Push Params
Check logs for:
```
Register: Added RFC 8599 push notification parameters to Contact URI
Register: pn-provider=fcm, pn-param={TOKEN}, pn-prid=com.ringplus.app
```

If missing, check:
- NotificationService is initialized before SipService
- FCM token is available when registering

#### Step 3: Test Push Notification Delivery
Send test push to verify app wakes up:
```json
{
  "data": {
    "type": "INCOMING_CALL",
    "caller_name": "Test Caller",
    "caller_number": "+1234567890",
    "callee_uri": "sip:1002@domain"
  }
}
```

Check for log:
```
🔥 Android: STARTING wake-up process for incoming call push notification
```

#### Step 4: Verify SIP Re-registration After Wake-up
After push arrives, check for:
```
🔥 Android: [Background push wake-up] Ensuring SIP service is initialized
🔥 Android: [Background push wake-up] Re-registration result: true
```

#### Step 5: Verify Incoming Call Handling
Once SIP re-registers, server should send INVITE. Check for:
```
SIP Service: Incoming call from {caller}
```

### 🐛 Common Issues

1. **No FCM Token**
   - Firebase not initialized
   - google-services.json missing
   - Permissions not granted

2. **Push Not Waking App**
   - Background handler not registered
   - Data-only notification not configured
   - Battery optimization killing app

3. **SIP Not Re-registering**
   - Credentials not persisted
   - Network not available after wake
   - SIP service initialization failure

4. **INVITE Not Arriving**
   - Server not sending to registered Contact
   - Firewall blocking SIP after wake
   - Contact URI parameters incorrect

### 📝 Required Server Configuration

Your SIP server must:
1. Support RFC 8599 push notifications
2. Parse Contact URI parameters (`pn-provider`, `pn-param`, etc.)
3. Send FCM push when INVITE arrives for offline user
4. Wait for re-REGISTER before sending INVITE
5. Route INVITE to newly registered Contact URI

### 🔧 Testing Commands

Test FCM token retrieval:
```dart
final token = await NotificationService.instance.refreshFCMToken();
print('Current FCM Token: $token');
```

Test manual SIP re-registration:
```dart
await SipService.instance.attemptBackgroundReregistration();
```

### 📊 Expected Flow

1. App registers with SIP server including FCM token in Contact URI
2. App goes to background
3. Server receives INVITE for extension
4. Server detects extension is offline/unreachable
5. Server sends FCM push using token from Contact URI
6. FCM wakes app in background
7. App re-registers with SIP server
8. Server sends INVITE to newly registered Contact
9. App shows incoming call screen

### ⚠️ Critical Requirements

- **Data-only notifications**: No notification title/body (silent push)
- **High priority**: `priority: high` in FCM payload
- **Server timing**: Must wait for re-REGISTER before sending INVITE
- **Contact URI**: Must include all RFC 8599 parameters
