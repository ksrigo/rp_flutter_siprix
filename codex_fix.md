We are building a Flutter softphone app using the Siprix SDK.
The Recents Call page is already implemented with CdrsModel and CdrModel.
Outgoing calls display correctly.
Incoming calls display, but answered incoming calls are incorrectly shown as missed.
Task:
Fix the logic so that incoming calls are properly categorized as answered or missed.
Keep the implementation simple and clean, focusing only on the Recents Call page and its use of CdrsModel and CdrModel.
Make sure the UI reflects the correct status for all call types.

Still showing as Type missed when the call was answerd. Find the logs below:

I/flutter (12784): SIP Service: Adding connected call to history - callId: 204
I/flutter (12784): SIP Service: CallsModel has 1 calls during connected event
I/flutter (12784): SIP Service: CallsModel[0] - ID: 203, Remote: 1001
I/flutter (12784): SIP Service: Connected call 204 not found in CallsModel - creating connected CallModel
I/flutter (12784): SIP Service: Created and stored connected CallModel for callId: 204
I/flutter (12784): CallHistory: Call history changed, updating listeners
I/flutter (12784): CallHistory: Added new call record - CallId: 204
I/flutter (12784): SIP Service: Successfully added connected CallModel to CDR history
I/flutter (12784): CallHistory: Saved 10 calls to storage
...
I/flutter (12784): event OnCallTerminated {callId: 204, statusCode: 0}
I/flutter (12784): SIP Service: Direct call terminated - callId: 204, statusCode: 0
I/flutter (12784): SIP Service: Adding call to history on termination - callId: 204, statusCode: 0
I/flutter (12784): SIP Service: Call 204 already exists in CDR history, skipping duplicate
I/flutter (12784): SipService: \_updateCurrentCall called - callId: 204, state: AppCallState.ended
I/flutter (12784): InCallScreen: Received call state update - callId: 204, state: AppCallState.ended, widgetCallId: 204
I/flutter (12784): InCallScreen: Call ended: Navigating back to keypad

Fix it to show it as Incoming answered call when connected or answered.

https://docs.siprix-voip.com/rst/flutter.html,
https://docs.siprix-voip.com/rst/api.html,
https://pub.dev/documentation/siprix_voip_sdk/latest/,
https://github.com/siprix/FlutterPluginFederated/.

https://github.com/siprix/FlutterPluginFederated/blob/main/siprix_voip_sdk/example/lib/calls_model_app.dart
https://github.com/siprix/FlutterPluginFederated/blob/main/siprix_voip_sdk/example/lib/call_add.dart
https://pub.dev/documentation/siprix_voip_sdk/latest/calls_model/CallModel-class.html
https://pub.dev/documentation/siprix_voip_sdk/latest/calls_model/CallsModel-class.html
https://pub.dev/documentation/siprix_voip_sdk/latest/cdrs_model/CdrModel-class.html
https://pub.dev/documentation/siprix_voip_sdk/latest/cdrs_model/CdrsModel-class.html

---

I have implemented (for now for Android only) the push notification to wakeup the app (when it's in background or killed) and to register to the proxy. It was working fine. A change broke it. Now when the app get a push notification I have this line in my logs and Sip Register is not sent to the Proxy:

D/FLTFireMsgReceiver(14640): broadcast received for message
I/flutter (14640): Android: Foreground FCM message received: {caller_name: Test In, callee_uri: sip:1002@example.com, caller_uri: sip:1001@example.com, type: INCOMING_CALL, timestamp: 1758232322, call_id: abc123}
I/flutter (14640): Android: Handling incoming call notification: {caller_name: Test In, callee_uri: sip:1002@example.com, caller_uri: sip:1001@example.com, type: INCOMING_CALL, timestamp: 1758232322, call_id: abc123}
I/flutter (14640): Android: Incoming call notification processed for Test In (Unknown)

---

Problem:
When the app is in the background and an incoming call rings for more than ~4 seconds, if the caller cancels before the user answers, the app shows the On Call screen in “Connecting” state when reopened.
Expected behavior: if the call was cancelled (missed), the app should not show the On Call screen.
Task:
Fix the logic that decides whether to display the Incoming Call screen or the On Call screen when the app resumes from background.
Ensure cancelled calls do not trigger “On Call” UI.
Answered calls → show On Call screen.
Missed/Cancelled calls → skip On Call screen, add to Recents as missed.
Keep the fix minimal and clean.
