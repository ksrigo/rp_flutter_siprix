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

---

We have already implemented the Recents page in our Flutter softphone app.
Now we need to improve the UI based on the design provided in mockup/recents_call.jpg.
Requirements:
Follow the mockup closely for layout and styling.
Preserve the existing Bottom Navigation bar.
Background color: white.
Maintain the purple theme for interactive elements.
Recents List:
Display recent calls from CdrModel (caller/callee, time, duration, direction, status).
The list must update dynamically when CdrsModel changes (e.g., a new call is added).
Call Info View:
When tapping the info button on a call entry, show a details page with:
Caller or callee name + number (depending on direction).
Date/Time of the call.
If incoming + connected → show call duration.
If incoming + not answered → show as missed call.
If outgoing + connected → show call duration.
If outgoing + not connected → show as not answered.
Actions:
Button to call the number.
Button to add to contacts (placeholder for now).
Call Management
Support deleting calls:
Single entry (swipe left + confirm).
Multiple entries (selection mode).
You decide the best UX approach.
Other Notes:
Add placeholder logic where persistence or API integration is required.
Keep the code clean, modular, and null-safe.

---

We need to fix several bugs in the Recents page UI and logic of our Flutter softphone app.
UI Fixes:
All / Missed toggle:
Current toggle button is too small compared to the text.
Fix: the toggle indicator should be half the height of the gray bar for proper visibility.
Remove the vertical separator after the “All / Missed” title.
Call list entries:
Currently, each call is shown on a card.
Fix: remove the card background.
Display as a list separated by a thin vertical divider, consistent with the mockup (mockup/recents_call.jpg).
Missed calls display:
Currently shows “Missed Call” text.
Fix: show Name/Number (like other calls) but styled in red to indicate a missed call.
Info Window Fixes:
For answered calls (both incoming and outgoing):
Show call duration instead of the label “Answered”.
For outgoing answered calls:
Bug: they are incorrectly marked as “Not answered”.
Fix: mark them as answered with duration.
Requirements:
Follow the existing purple theme.
Preserve the current Bottom Navigation bar.
Keep code clean, modular, and null-safe.

- Multi select only allow to select Missed calls.
- Call Back button, is not calling back. It's jst go back to Keypad window
