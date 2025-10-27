# Ringplus PBX Softphone - Development Progress

## Phase 1: Project setup and architecture planning

- [x] Create Flutter project structure
- [x] Define pubspec.yaml with all required dependencies
- [x] Set up folder structure for screens, widgets, services, models
- [x] Create architecture documentation
- [x] Define app constants and configuration

## Phase 2: UI/UX design and asset creation

- [x] Research mobile PBX app designs
- [x] Create color scheme and theme definitions
- [x] Design app icons and assets
- [x] Create wireframes for all screens
- [x] Generate UI mockups

## Phase 3: Core Flutter app structure and navigation

- [x] Implement main app structure
- [x] Create bottom navigation bar
- [x] Set up routing and navigation
- [x] Implement theme system
- [x] Create base widgets and components

## Phase 4: Authentication and onboarding screens

- [x] Create welcome/onboarding screens
- [x] Implement login/registration forms
- [x] Add credential storage service
- [x] Create SIP registration logic

## Phase 5: Keypad and dialing functionality

- [x] Create dialpad UI
- [x] Implement DTMF functionality
- [x] Add call initiation logic
- [x] Create number formatting

## Phase 6: In-call UI and call management

- [x] Design in-call screen
- [x] Implement call controls (mute, hold, speaker)
- [x] Add transfer and redirect functionality
- [x] Create incoming call screen

## Phase 7: Recents and call history

- [x] Create call history UI
- [x] Implement call filtering
- [x] Add call details view
- [x] Create history storage

## Phase 8: Contacts management

- [x] Create contacts list UI
- [x] Implement CRUD operations
- [x] Add favorites functionality
- [x] Create contact details view

## Phase 9: Voicemail functionality

- [x] Create voicemail list UI
- [x] Implement playback controls
- [x] Add unread badge system
- [x] Create voicemail storage

## Phase 10: Settings and configuration

- [x] Create settings screens
- [x] Implement account management
- [x] Add call options configuration
- [x] Create privacy/security settings

## Phase 11: Internationalization and accessibility

- [x] Set up i18n framework
- [x] Create English and French translations
- [x] Implement RTL support
- [x] Add accessibility features

## Phase 12: Final integration and documentation

- [x] Complete integration testing
- [x] Create comprehensive documentation
- [x] Generate deployment guide
- [x] Create user manual

## PROJECT COMPLETED ✅

All phases have been successfully completed. The Ringplus PBX Softphone is ready for production deployment.

---

At start: 2 times sending SIP register

Unit test
Need to clean the code using codex + coderabbit.ai, Reduce APP size

---

## \*\*

Refactor the code of multi_call_screen, call_action_screen, in_call_screen without breaking any functionalities: Remove unused code, redundancy codes or simplify overcomplicated custom logic into simple code. Use builtins functions from siprix whereever possible

---

Rollback your changes. Bring back manual trigger: \_callsModel!.onConnected(callId, from, to, withVideo);
refactor the code of sip_service_call_handling.dart. Remove unused, redundancy codes or simplify overcomplicated logic into simple code. Use builtin SDK functions where possible

---

What if in unregister(), we change our current accountmodel and apply updateAccount()

curl -v \
 -d '{"aps": {"alert": "Incoming call"}, "uuid": "test-uuid", "callerName": "Ravi"}' \
 -H "apns-topic: com.ringplus.app" \
 -H "apns-push-type: voip" \
 -H "authorization: bearer <JWT_TOKEN>" \
 --http2 https://api.sandbox.push.apple.com/3/device/6dc9cbf3ae843ee31d32d9554787d6ac7d69358e557ab3bba33774a337d9f91a

---

curl -v \
-d '{"aps":{"alert":"test","callerId":"someCallerId1", "pushHint":"somehint"}}' \
-H "apns-topic: com.ringplus.app.voip" \
-H "apns-push-type: voip" \
-H "apns-priority: 10" \
-H "authorization: bearer eyJhbGciOiJFUzI1NiIsImtpZCI6IkxGSEZWNjgzNDYifQ.eyJpc3MiOiI3OUsySjMzVU5ZIiwiaWF0IjoxNzYwNjg3ODc2fQ.YhN5HgQzOSa7R9wadDr3ZH2Ypeeip3Vuc1HIct8_V0S0vCfSofe18PPQX1atxU-NxMPV4m0Sz41sQMm2OaowkA" \
--http2 \
https://api.sandbox.push.apple.com/3/device/6dc9cbf3ae843ee31d32d9554787d6ac7d69358e557ab3bba33774a337d9f91a

Name:Test APNS Key
Key ID:8MMSJQPF2W
Services:Apple Push Notifications service (APNs)

##All topics:
Name:TESTAPNS2
Key ID:LFHFV68346
Services:Apple Push Notifications service (APNs)

TeamID: 79K2J33UNY

https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns
https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
https://developer.apple.com/documentation/usernotifications/sending-push-notifications-using-command-line-tools
https://icloud.developer.apple.com/dashboard/notifications/teams/79K2J33UNY/app/com.ringplus.app/tools/generateJwt
https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html
https://getstream.io/blog/pushkit-for-calls/
https://stackoverflow.com/questions/69650283/https://stackoverflow.com/questions/69650283/open-ios-flutter-app-directly-after-answering-voip-call-from-locked-ios-device

openssl pkcs12 -in Certificates.p12 -out Certificates.pem -legacy

curl -v \
-d '{"aps":{"alert":"test","callerId":"1001", "callerNumber":"1001", "pushHint":"somehint"}}' \
-H "apns-push-type: voip" \
-H "apns-priority: 10" \
--cert "voip_services.cer" --cert-type DER --key "Certificates.pem" --key-type PEM \
--http2 \
https://api.sandbox.push.apple.com/3/device/6dc9cbf3ae843ee31d32d9554787d6ac7d69358e557ab3bba33774a337d9f91a

curl -v \
-d '{"aps":{"alert":"test","callerId":"1001", "callerNumber":"1001", "pushHint":"somehint"}}' \
-H "apns-push-type: voip" \
-H "apns-expiration: 0" \
-H "apns-priority: 0" \
-H "apns-topic: com.ringplus.app.voip" \
--cert "voip_services.cer" --cert-type DER --key "Certificates.pem" --key-type PEM \
--http2 \
https://api.sandbox.push.apple.com/3/device/6dc9cbf3ae843ee31d32d9554787d6ac7d69358e557ab3bba33774a337d9f91a

log show --predicate 'processImagePath contains "Runner"' --last 2m --info --debug 2>&1 | grep -E "(🚀|🔔|MAIN|SIP Service|Application starting)"

flutter logs -d 00008140-0002211204E3C01C

flutter run -d 00008140-0002211204E3C01C --release

---

Process to test:

Check for the code in the branch: ios-1710

##Command for sending push notification:

```
curl -v \
-d '{"aps":{"alert":"test","callerId":"1002", "callerNumber":"1002", "pushHint":"somehint"}}' \
-H "apns-push-type: voip" \
-H "apns-expiration: 0" \
-H "apns-priority: 0" \
-H "apns-topic: com.ringplus.app.voip" \
--cert "voip_services.cer" --cert-type DER --key "Certificates.pem" --key-type PEM \
--http2 \
https://api.sandbox.push.apple.com/3/device/<DEVICE_TOKEN>  ===>>>> CHANGE IT
```

DEVICE_TOKEN === CHANGE IT in the curl
Adopt callerId and callerNumber according to the number you are testing from

Run:

```
flutter run --release
```

"pushHint":"somehint" is important to link call between SIP Invite and Callkit PN. It's for now hardcoded for test purpose.

#Tests:

1. Put the app in background/Terminate
2. Execute the curl command
3. when CallKit shows up on your iphone, Call from 1002 to 1004(Iphone extension)
4. Accept the call, call should be connected.
