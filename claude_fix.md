We need to update our app. Remove welcome page entirely.
Initial page: /splash → SplashScreen.
After splash:
If user is logged in → navigate to /keypad
If user is not logged in → naviagate to /login.
When the app starts, it should show a **login page** with email + password fields.

On the login page we don't need the advanced settings.

1. On submit, POST (form-encoded) to:
   POST https://api.ringplus.co.uk/v1/signin

   Body:
   {
   "email": "string",
   "password": "string"
   }

   Response:
   {
   "access_token": "string",
   "refresh_token": "string",
   "token_type": "string"
   }

2. After login:

   - Save `access_token`, `refresh_token` in local storage (e.g. `shared_preferences`).
   - Decode the JWT `access_token` payload to get `exp`. Save `token_expires_at`.

3. For every API call:

   - Before sending, check if `now < token_expires_at - 60*1000` (1 min before expiry).
     - If true → use the existing `access_token`.
     - Else → refresh the token.

4. Token refresh:

   - Call: PUT https://api.ringplus.co.uk/v1/refresh
   - Body:
     {
     "refresh_token": "string"
     }
   - Save the new `access_token` + update its `exp`.

5. For all API requests, set the header:
   Authorization: "Bearer <access_token>"

Please generate a Flutter example using:

- `http` for networking
- `shared_preferences` for storage
- Proper async/await pattern
- A simple LoginPage widget
- An ApiClient class to handle requests + token refresh

---

'POST' \
 'https://api.ringplus.co.uk/v1/signin' \
 -H 'accept: application/json' \
 -H 'Content-Type: application/x-www-form-urlencoded' \
 -d 'username=user%40example.com&password=string'

Content type it has to x-www-form-urlencoded the signin

---

In main.dar: we have SipService.instance.initialize(). We need to initialize, only after a successfull Login /login.
If there is already hasValidToken. Then we need to call an API to get extension details.
if there is no valid token. We need login first before calling API to get extensions details.

API to GET Extension details: https://api.ringplus.co.uk/v1/extensions/mobile
It will return:

[
{
"name": "Ravi",
"extension": 1002,
"domain": "408708399.ringplus.co.uk",
"password": "1Z(OeDvN9dt0(f",
"wss": "phone.ringplus.co.uk:5622"
}
]

---

I have added an image in mockup folder called dialpad.png. Build exactly the same dialpad with on left top corner Name and Extension number dynamically. And right corner show online if Extension is Registered if not Offline.
Dial button need to be active and purple when at least one number is entered.

---

I have placed the output image in mockup dialpad_output.png. Keep Dial button and delete button in the position.
When numbers are entered the buttons are changing position.

---

flutter: [2025-09-05 23:05:28.464] Level.info ua.dart:372 ::: Closing connection\^[[0m
flutter: [2025-09-05 23:05:28.466] Level.debug socket_transport.dart:99 ::: Transport close()
flutter: [2025-09-05 23:05:28.467] Level.debug web_socket.dart:119 ::: disconnect()

- Is only happening when the restart and the credential is already in the storage. If I do logout and login, registration works fine and connection is not closed.
- Once logged in and registrerd Offline button become Online when we start to dial a number.

---

I have placed in mockup on_call_screen.png, when we dial and number and call. It should open call screen. Make sure hangup button works. Instead of putting End Call button replace it with a red round button in the same style as the dial button.

---

on CallStateEnum.FAILED, we need to come back to Keypad screen.

---

Auth: Extension details - Name: Ravi, Extension: 1002, Domain: 408708399.ringplus.co.uk, WSS: phone.ringplus.co.uk:4643
SIP Service: Starting initialization...
SIP Service: Helper created and listener added
Error initializing SIP service: Unsupported operation: Platform.\_operatingSystem
Auth: Error initializing SIP: Unsupported operation: Platform.\_operatingSystem

---

From IOS:

flutter: Make call: Registration state - SipRegistrationState.registered
flutter: Make call: Starting call to 1001
flutter: Make call: SIP URI - sip:1001@408708399.ringplus.co.uk
flutter: [2025-09-07 14:14:50.395] Level.debug ua.dart:252 ::: call()
flutter: [2025-09-07 14:14:50.396] Level.debug rtc_session.dart:70 ::: new
flutter: [2025-09-07 14:14:50.397] Level.debug rtc_session.dart:238 ::: connect()
flutter: Make call: Call initiated successfully with temporary tracking ID - 1757247290403
flutter: SipService: \_updateCurrentCall called - callId: 1757247290403, state: AppCallState.connecting
flutter: SipService: Call state added to stream - AppCallState.connecting
flutter: [2025-09-07 14:14:50.407] Level.debug rtc_session.dart:1655 ::: emit "peerconnection"
flutter: [2025-09-07 14:14:50.407] Level.debug rtc_session.dart:3219 ::: newRTCSession()
flutter: [2025-09-07 14:14:50.407] Level.debug sip_ua_helper.dart:234 ::: newRTCSession => Instance of 'EventNewRTCSession'
flutter: SIP Service: Call state changed - 774mubc5godf7juzbepnpoueaopz3c - CallStateEnum.CALL_INITIATION
flutter: SIP Service: Added new call to active calls - 774mubc5godf7juzbepnpoueaopz3c
flutter: SIP Service: Checking call update conditions - currentCallId: 1757247290403, eventCallId: 774mubc5godf7juzbepnpoueaopz3c, currentCall is null: false
flutter: SIP Service: Condition met - updating call info
flutter: SIP Service: About to update current call - 774mubc5godf7juzbepnpoueaopz3c - AppCallState.connecting
flutter: SipService: \_updateCurrentCall called - callId: 774mubc5godf7juzbepnpoueaopz3c, state: AppCallState.connecting
flutter: SipService: Call state added to stream - AppCallState.connecting
flutter: SIP Service: Updated current call - 774mubc5godf7juzbepnpoueaopz3c - AppCallState.connecting
flutter: Make call: Successfully initiated call
flutter: InCallScreen: Setting up call state listener for callId: 1757247290403
flutter: [2025-09-07 14:14:50.430] Level.debug rtc_session.dart:3224 ::: session connecting
flutter: [2025-09-07 14:14:50.431] Level.debug rtc_session.dart:3225 ::: emit "connecting"
flutter: [2025-09-07 14:14:50.431] Level.debug sip_ua_helper.dart:277 ::: call connecting
flutter: SIP Service: Call state changed - 774mubc5godf7juzbepnpoueaopz3c - CallStateEnum.CONNECTING
flutter: SIP Service: Checking call update conditions - currentCallId: 774mubc5godf7juzbepnpoueaopz3c, eventCallId: 774mubc5godf7juzbepnpoueaopz3c, currentCall is null: false
flutter: SIP Service: Condition met - updating call info
flutter: SIP Service: About to update current call - 774mubc5godf7juzbepnpoueaopz3c - AppCallState.connecting
flutter: SipService: \_updateCurrentCall called - callId: 774mubc5godf7juzbepnpoueaopz3c, state: AppCallState.connecting
flutter: SipService: Call state added to stream - AppCallState.connecting
flutter: SIP Service: Updated current call - 774mubc5godf7juzbepnpoueaopz3c - AppCallState.connecting
flutter: [2025-09-07 14:14:50.432] Level.debug rtc_session.dart:1662 ::: createLocalDescription()
flutter: InCallScreen: Received call state update - callId: 774mubc5godf7juzbepnpoueaopz3c, state: AppCallState.connecting, widgetCallId: 1757247290403
flutter: SIP Service: Call state changed - 774mubc5godf7juzbepnpoueaopz3c - CallStateEnum.STREAM
flutter: SIP Service: Checking call update conditions - currentCallId: 774mubc5godf7juzbepnpoueaopz3c, eventCallId: 774mubc5godf7juzbepnpoueaopz3c, currentCall is null: false
flutter: SIP Service: Condition met - updating call info
flutter: SIP Service: About to update current call - 774mubc5godf7juzbepnpoueaopz3c - AppCallState.connecting
flutter: SipService: \_updateCurrentCall called - callId: 774mubc5godf7juzbepnpoueaopz3c, state: AppCallState.connecting
flutter: SipService: Call state added to stream - AppCallState.connecting
flutter: SIP Service: Updated current call - 774mubc5godf7juzbepnpoueaopz3c - AppCallState.connecting
flutter: InCallScreen: Received call state update - callId: 774mubc5godf7juzbepnpoueaopz3c, state: AppCallState.connecting, widgetCallId: 1757247290403
flutter: [2025-09-07 14:14:50.937] Level.debug rtc_session.dart:1722 ::: emit "sdp"
flutter: [2025-09-07 14:14:50.938] Level.debug rtc_session.dart:2395 ::: emit "sending" [request]
flutter: [2025-09-07 14:14:50.939] Level.debug socket_transport.dart:128 ::: Socket Transport send()
flutter: [2025-09-07 14:14:50.940] Level.debug sip_message.dart:276 ::: Outgoing Message: SipMethod.INVITE body: v=0
o=- 3456688998043334879 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=extmap-allow-mixed
a=msid-semantic: WMS ECA5D256-B5CD-482F-9969-26BC855B319D
m=audio 45581 UDP/TLS/RTP/SAVPF 111 63 9 102 0 8 13 110 126
c=IN IP4 88.174.209.3
a=rtcp:9 IN IP4 0.0.0.0
a=candidate:2084073027 1 udp 2122194687 192.168.0.183 50640 typ host generation 0 network-id 1 network-cost 10
a=candidate:4140454980 1 udp 2122063615 10.31.19.52 55919 typ host generation 0 network-id 8 network-cost 900
a=candidate:200451935 1 udp 2121932543 127.0.0.1 55562 typ host generation 0 network-id 6
a=candidate:3587789822 1 udp 2122262783 2a01:e0a:bb4:40e0::79df:4446 58372 typ host generation 0 network-id 2 network-cost 10
a=candidate:3067140329 1 udp 2122131711 2a0d:e487:52f:142e:1959:a49b:1f83:b054 60762 typ host generation 0 network-id 9 network-cost 900
a=candidate:652964740 1 udp 2122005759 ::1 55130 typ host gene
flutter: [2025-09-07 14:14:50.941] Level.debug web_socket.dart:136 ::: send()
flutter: [2025-09-07 14:14:50.943] Level.debug websocket_dart_impl.dart:54 ::: send:

INVITE sip:1001@408708399.ringplus.co.uk SIP/2.0
Via: SIP/2.0/WSS 2c333j35ps31.invalid;branch=z9hG4bK1111604880000000
Max-Forwards: 69
To: <sip:1001@408708399.ringplus.co.uk>
From: "Ravi" <sip:1002@408708399.ringplus.co.uk>;tag=poueaopz3c
Call-ID: 774mubc5godf7juzbepn
CSeq: 2910 INVITE
Contact: <sip:em5ffr91@2c333j35ps31.invalid;transport=WSS;ob>
Content-Type: application/sdp
Session-Expires: 120
Allow: INVITE,ACK,CANCEL,BYE,UPDATE,MESSAGE,OPTIONS,REFER,INFO,NOTIFY
Supported: timer,ice,replaces,outbound
User-Agent: Ringplus/1.0.0
Content-Length: 3044

v=0
o=- 3456688998043334879 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=extmap-allow-mixed
a=msid-semantic: WMS ECA5D256-B5CD-482F-9969-26BC855B319D
m=audio 45581 UDP/TLS/RTP/SAVPF 111 63 9 102 0 8 13 110 126
c=IN IP4 88.174.209.3
a=rtcp:9 IN IP4 0.0.0.0
a=candidate:2084073027 1 udp 2122194687 192.168.0.183 50640 typ host generation 0 network-id 1
flutter: [2025-09-07 14:14:50.983] Level.debug web_socket.dart:102 ::: Closed [1002, null]!
flutter: [2025-09-07 14:14:50.984] Level.debug web_socket.dart:168 ::: WebSocket wss://phone.ringplus.co.uk:4643 closed
flutter: [2025-09-07 14:14:50.986] Level.debug invite_client.dart:60 ::: transport error occurred, deleting transaction z9hG4bK1111604880000000
flutter: [2025-09-07 14:14:50.988] Level.error rtc_session.dart:1423 ::: onTransportError()\^[[0m
flutter: [2025-09-07 14:14:50.990] Level.debug rtc_session.dart:716 ::: terminate()
flutter: [2025-09-07 14:14:50.991] Level.debug rtc_session.dart:741 ::: canceling session
flutter: [2025-09-07 14:14:50.992] Level.debug rtc_session.dart:3268 ::: session failed
flutter: [2025-09-07 14:14:50.993] Level.debug rtc_session.dart:3271 ::: emit "\_failed"
flutter: [2025-09-07 14:14:50.994] Level.debug rtc_session.dart:1501 ::: close()
flutter: [2025-09-07 14:14:50.995] Level.debug rtc_session.dart:3282 ::: emit "failed"
flutter: [2025-09-07 14:14:50.997] Level.debug sip_ua_helper.dart:288 ::: call failed with cause: Code: [500], Cause: Canceled, Reason: SIP ;cause=500 ;text="Connection Error"
flutter: SIP Service: Call state changed - 774mubc5godf7juzbepnpoueaopz3c - CallStateEnum.FAILED

From Chrome:

Make call: Registration state - SipRegistrationState.registered
Make call: Starting call to 1001
Make call: SIP URI - sip:1001@408708399.ringplus.co.uk
[2025-09-07 14:12:25.181] Level.debug null ::: call()
[2025-09-07 14:12:25.185] Level.debug null ::: new
[2025-09-07 14:12:25.188] Level.debug null ::: connect()
[2025-09-07 14:12:25.194] Level.debug null ::: emit "peerconnection"
[2025-09-07 14:12:25.195] Level.debug null ::: newRTCSession()
[2025-09-07 14:12:25.197] Level.debug null ::: newRTCSession => Instance of 'EventNewRTCSession'
SIP Service: Call state changed - 0614545740706461652416s3790a47 - CallStateEnum.CALL_INITIATION
SIP Service: Added new call to active calls - 0614545740706461652416s3790a47
SIP Service: Checking call update conditions - currentCallId: null, eventCallId: 0614545740706461652416s3790a47, currentCall is
null: true
SIP Service: Condition met - updating call info
SIP Service: About to update current call - 0614545740706461652416s3790a47 - AppCallState.connecting
SipService: \_updateCurrentCall called - callId: 0614545740706461652416s3790a47, state: AppCallState.connecting
SipService: Call state added to stream - AppCallState.connecting
SIP Service: Updated current call - 0614545740706461652416s3790a47 - AppCallState.connecting
Make call: Call initiated successfully with temporary tracking ID - 1757247145201
SipService: \_updateCurrentCall called - callId: 1757247145201, state: AppCallState.connecting
SipService: Call state added to stream - AppCallState.connecting
Make call: Successfully initiated call
InCallScreen: Setting up call state listener for callId: 1757247145201
[2025-09-07 14:12:25.893] Level.debug null ::: session connecting
[2025-09-07 14:12:25.894] Level.debug null ::: emit "connecting"
[2025-09-07 14:12:25.896] Level.debug null ::: call connecting
SIP Service: Call state changed - 0614545740706461652416s3790a47 - CallStateEnum.CONNECTING
SIP Service: Checking call update conditions - currentCallId: 1757247145201, eventCallId: 0614545740706461652416s3790a47,
currentCall is null: false
SIP Service: Condition met - updating call info
SIP Service: About to update current call - 0614545740706461652416s3790a47 - AppCallState.connecting
SipService: \_updateCurrentCall called - callId: 0614545740706461652416s3790a47, state: AppCallState.connecting
SipService: Call state added to stream - AppCallState.connecting
SIP Service: Updated current call - 0614545740706461652416s3790a47 - AppCallState.connecting
[2025-09-07 14:12:25.898] Level.debug null ::: createLocalDescription()
InCallScreen: Received call state update - callId: 0614545740706461652416s3790a47, state: AppCallState.connecting, widgetCallId:
1757247145201
SIP Service: Call state changed - 0614545740706461652416s3790a47 - CallStateEnum.STREAM
SIP Service: Checking call update conditions - currentCallId: 0614545740706461652416s3790a47, eventCallId:
0614545740706461652416s3790a47, currentCall is null: false
SIP Service: Condition met - updating call info
SIP Service: About to update current call - 0614545740706461652416s3790a47 - AppCallState.connecting
SipService: \_updateCurrentCall called - callId: 0614545740706461652416s3790a47, state: AppCallState.connecting
SipService: Call state added to stream - AppCallState.connecting
SIP Service: Updated current call - 0614545740706461652416s3790a47 - AppCallState.connecting
InCallScreen: Received call state update - callId: 0614545740706461652416s3790a47, state: AppCallState.connecting, widgetCallId:
1757247145201
[2025-09-07 14:12:26.409] Level.debug null ::: emit "sdp"
[2025-09-07 14:12:26.412] Level.debug null ::: emit "sending" [request]
[2025-09-07 14:12:26.414] Level.debug null ::: Socket Transport send()
[2025-09-07 14:12:26.416] Level.debug null ::: Outgoing Message: SipMethod.INVITE body: v=0
o=- 3333007003474375108 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=extmap-allow-mixed
a=msid-semantic: WMS 94aec60b-2ae8-4b78-adf5-ef5d8c090041
m=audio 34775 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126
c=IN IP4 88.174.209.3
a=rtcp:9 IN IP4 0.0.0.0
a=candidate:2477250150 1 udp 2122260223 169.254.69.197 57488 typ host generation 0 network-id 3
a=candidate:290064091 1 udp 2122129151 192.168.0.185 49737 typ host generation 0 network-id 1 network-cost 10
a=candidate:2372779730 1 udp 2122197247 2a01:e0a:bb4:40e0::5596:e9d2 63469 typ host generation 0 network-id 2 network-cost 10
a=candidate:1751362651 1 udp 2122068735 fd9d:2d8:4784::2 54049 typ host generation 0 network-id 4 network-cost 50
a=candidate:3498332561 1 udp 1685921535 88.174.209.3 34775 typ srflx raddr 192.168.0.185 rport 49737 generation 0 network-id 1
network-cost 10
a=candidate:1829569266 1 tcp 1518280447 169.254.69.197 9 typ host tcptype active generation 0 network-id 3
a=candidate:4024488527 1 tcp 1518149375 192.168.0.185 9 typ host tcptype active generation 0 network-id 1 network-cost 10
a=candidate:1942448710 1 tcp 1518217471 2a01:e0a:bb4:40e0::5596:e9d2 9 typ host tcptype active generation 0 network-id 2
network-cost 10
a=candidate:2529786063 1 tcp 1518088959 fd9d:2d8:4784::2 9 typ host tcptype active generation 0 network-id 4 network-cost 50
a=ice-ufrag:INjW
a=ice-pwd:gylZdpAZ3SRoI6hNA3Cx+jMU
a=ice-options:trickle
a=fingerprint:sha-256 F0:4D:1A:04:07:BF:3D:C5:4A:C0:17:C5:D5:E7:BD:B6:33:82:B5:84:16:00:9C:10:FB:14:BF:75:30:B4:6F:53
a=setup:actpass
a=mid:0
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid
a=sendrecv
a=msid:94aec60b-2ae8-4b78-adf5-ef5d8c090041 d4660d00-e320-4730-9575-7a89f828f8e5
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:111 opus/48000/2
a=rtcp-fb:111 transport-cc
a=fmtp:111 minptime=10;useinbandfec=1
a=rtpmap:63 red/48000/2
a=fmtp:63 111/111
a=rtpmap:9 G722/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:13 CN/8000
a=rtpmap:110 telephone-event/48000
a=rtpmap:126 telephone-event/8000
a=ssrc:3180635935 cname:JXQrRdS4XF+WHqM+
a=ssrc:3180635935 msid:94aec60b-2ae8-4b78-adf5-ef5d8c090041 d4660d00-e320-4730-9575-7a89f828f8e5

[2025-09-07 14:12:26.418] Level.debug null ::: send()
[2025-09-07 14:12:26.420] Level.debug null ::: send:

INVITE sip:1001@408708399.ringplus.co.uk SIP/2.0
Via: SIP/2.0/WSS d85gjhgezcyn.invalid;branch=z9hG4bK7028820370000000
Max-Forwards: 69
To: <sip:1001@408708399.ringplus.co.uk>
From: "Ravi" <sip:1002@408708399.ringplus.co.uk>;tag=16s3790a47
Call-ID: 06145457407064616524
CSeq: 65 INVITE
Contact: <sip:sssno9un@d85gjhgezcyn.invalid;transport=WSS;ob>
Content-Type: application/sdp
Session-Expires: 120
Allow: INVITE,ACK,CANCEL,BYE,UPDATE,MESSAGE,OPTIONS,REFER,INFO,NOTIFY
Supported: timer,ice,replaces,outbound
User-Agent: Ringplus/1.0.0
Content-Length: 2393

v=0
o=- 3333007003474375108 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=extmap-allow-mixed
a=msid-semantic: WMS 94aec60b-2ae8-4b78-adf5-ef5d8c090041
m=audio 34775 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126
c=IN IP4 88.174.209.3
a=rtcp:9 IN IP4 0.0.0.0
a=candidate:2477250150 1 udp 2122260223 169.254.69.197 57488 typ host generation 0 network-id 3
a=candidate:290064091 1 udp 2122129151 192.168.0.185 49737 typ host generation 0 network-id 1 network-cost 10
a=candidate:2372779730 1 udp 2122197247 2a01:e0a:bb4:40e0::5596:e9d2 63469 typ host generation 0 network-id 2 network-cost 10
a=candidate:1751362651 1 udp 2122068735 fd9d:2d8:4784::2 54049 typ host generation 0 network-id 4 network-cost 50
a=candidate:3498332561 1 udp 1685921535 88.174.209.3 34775 typ srflx raddr 192.168.0.185 rport 49737 generation 0 network-id 1
network-cost 10
a=candidate:1829569266 1 tcp 1518280447 169.254.69.197 9 typ host tcptype active generation 0 network-id 3
a=candidate:4024488527 1 tcp 1518149375 192.168.0.185 9 typ host tcptype active generation 0 network-id 1 network-cost 10
a=candidate:1942448710 1 tcp 1518217471 2a01:e0a:bb4:40e0::5596:e9d2 9 typ host tcptype active generation 0 network-id 2
network-cost 10
a=candidate:2529786063 1 tcp 1518088959 fd9d:2d8:4784::2 9 typ host tcptype active generation 0 network-id 4 network-cost 50
a=ice-ufrag:INjW
a=ice-pwd:gylZdpAZ3SRoI6hNA3Cx+jMU
a=ice-options:trickle
a=fingerprint:sha-256 F0:4D:1A:04:07:BF:3D:C5:4A:C0:17:C5:D5:E7:BD:B6:33:82:B5:84:16:00:9C:10:FB:14:BF:75:30:B4:6F:53
a=setup:actpass
a=mid:0
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid
a=sendrecv
a=msid:94aec60b-2ae8-4b78-adf5-ef5d8c090041 d4660d00-e320-4730-9575-7a89f828f8e5
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:111 opus/48000/2
a=rtcp-fb:111 transport-cc
a=fmtp:111 minptime=10;useinbandfec=1
a=rtpmap:63 red/48000/2
a=fmtp:63 111/111
a=rtpmap:9 G722/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:13 CN/8000
a=rtpmap:110 telephone-event/48000
a=rtpmap:126 telephone-event/8000
a=ssrc:3180635935 cname:JXQrRdS4XF+WHqM+
a=ssrc:3180635935 msid:94aec60b-2ae8-4b78-adf5-ef5d8c090041 d4660d00-e320-4730-9575-7a89f828f8e5

[2025-09-07 14:12:26.457] Level.debug null ::: Received WebSocket message
[2025-09-07 14:12:26.458] Level.debug null ::: received text message:

SIP/2.0 100 Giving it a try
Via: SIP/2.0/WSS d85gjhgezcyn.invalid;received=88.174.209.3;rport=41802;branch=z9hG4bK7028820370000000
To: <sip:1001@408708399.ringplus.co.uk>
From: "Ravi" <sip:1002@408708399.ringplus.co.uk>;tag=16s3790a47
Call-ID: 06145457407064616524
CSeq: 65 INVITE
Server: RingPlus
Content-Length: 0

[2025-09-07 14:12:26.461] Level.debug null ::: receiveInviteResponse() current status: 1
[2025-09-07 14:12:26.471] Level.debug null ::: Received WebSocket message

When testing I have no issue but with IOS, Websocket is getting closed. I can see this error in my opensips logs for Ios Invite: ERROR:proto_wss:ws_process: Made 4 read attempts but message is not complete yet - closing connection

---

## When calling a number InCallScreen shows up and timer starts. We should only starts showing timer when call is answered/established. Prior to it we should show if call is connecting/trying/ringing before starts timer once answered.

there is a small bug. Connecting and Ringing shows properly but once call is answered timer shows up but very quickly is replaced by Connecting text.
I guess when state change timer is hidden by the state.

---

I have added an image in mockup/new_keypad.jpg. Bring same look to the current keypad

---

Your changes broke the keypad page. Look the image keypad_issue.png in mockup. You don't need to create a bottom bar, on keypad, there is already one bottom bar and it's fine. fix the overflow issue. Reduce the fix height around diald number and white space. I need a proper dialpad page.

---

The issue: when the network changes (e.g. from Wi-Fi to 4G or back), the WebRTC peer connection disconnects and the call drops.

I need you to generate robust Flutter code that:

1. Detects network changes using connectivity_plus (listen for connectivity changes).
2. Listens to the RTCPeerConnection state (iceConnectionState and connectionState).
3. If a call is active and the state becomes “disconnected” or “failed”, automatically reconnection (attempts an ICE?):
   - Create a new SDP offer with `iceRestart: true`.
   - Send this offer as a SIP re-INVITE through sip_ua.
   - Apply the remote SDP answer and update the peer connection.
4. If ICE restart fails (e.g. timeout, negotiation error), gracefully end the broken peer connection and immediately try to re-establish the call using the same SIP dialog if possible.
5. Make reconnection transparent for the user:
   - Show a small “Reconnecting…” indicator while trying to recover.
   - Resume the in-call timer and UI when reconnection succeeds.
6. Structure the code cleanly:
   - Event listeners for both connectivity changes and WebRTC state changes.
   - Async/await handling for the re-INVITE and ICE restart process.

---

flutter: SIP Service: Keep-alive check - Registration state: SipRegistrationState.registered
flutter: [2025-09-07 21:33:02.45] Level.debug invite_client.dart:81 ::: Timer B expired for transaction z9hG4bK14592725460000000
flutter: SIP Service: App inactive
flutter: [2025-09-07 21:33:04.47] Level.debug invite_client.dart:70 ::: Timer M expired for transaction z9hG4bK14592725460000000
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: App inactive
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.mobile
flutter: SIP Service: Network transition during active call - starting recovery
flutter: SIP Service: Starting call recovery for call: 34xan6iys5p4jhr800130412993705
flutter: SipService: \_updateCurrentCall called - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SipService: \_updateCurrentCall called - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SIP Service: Monitoring peer connection for call: 34xan6iys5p4jhr800130412993705
flutter: InCallScreen: Received call state update - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.reconnecting, widgetCallId: 1757273546847
flutter: InCallScreen: Received call state update - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.reconnecting, widgetCallId: 1757273546847
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: Peer connection state: RTCPeerConnectionState.RTCPeerConnectionStateConnected
flutter: SIP Service: ICE connection state: RTCIceConnectionState.RTCIceConnectionStateCompleted
flutter: SIP Service: Peer connection is healthy - recovery successful
flutter: SIP Service: Call recovery successful
flutter: SipService: \_updateCurrentCall called - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.answered, widgetCallId: 1757273546847
flutter: SipService: \_updateCurrentCall called - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: 34xan6iys5p4jhr800130412993705, state: AppCallState.answered, widgetCallId: 1757273546847
flutter: SIP Service: Keep-alive check - Registration state: SipRegistrationState.registered
flutter: [2025-09-07 21:33:32.71] Level.debug rtc_session.dart:3175 ::: runSessionTimer() | sending session refresh request
flutter: [2025-09-07 21:33:32.73] Level.debug rtc_session.dart:2848 ::: sendUpdate()
flutter: [2025-09-07 21:33:32.74] Level.debug rtc_session.dart:1264 ::: sendRequest()
flutter: [2025-09-07 21:33:32.80] Level.debug socket_transport.dart:128 ::: Socket Transport send()
flutter: [2025-09-07 21:33:32.80] Level.debug web_socket.dart:136 ::: send()
flutter: [2025-09-07 21:33:32.82] Level.debug websocket_dart_impl.dart:54 ::: send:
...
flutter: [2025-09-07 21:34:32.207] Level.debug rtc_session.dart:3175 ::: runSessionTimer() | sending session refresh request
flutter: [2025-09-07 21:34:32.209] Level.debug rtc_session.dart:2848 ::: sendUpdate()
flutter: [2025-09-07 21:34:32.210] Level.debug rtc_session.dart:1264 ::: sendRequest()
flutter: [2025-09-07 21:34:32.216] Level.debug socket_transport.dart:128 ::: Socket Transport send()
flutter: [2025-09-07 21:34:32.217] Level.debug web_socket.dart:136 ::: send()
flutter: [2025-09-07 21:34:32.219] Level.debug websocket_dart_impl.dart:54 ::: send:

UPDATE sip:139.59.160.105:4643;transport=wss;did=eec.d7ec19a3 SIP/2.0
Via: SIP/2.0/WSS 7k0vgtcgy7l8.invalid;branch=z9hG4bK33923526
Max-Forwards: 69
To: <sip:1001@408708399.ringplus.co.uk>;tag=1465482185
From: "Ravi" <sip:1002@408708399.ringplus.co.uk>;tag=0412993705
Call-ID: 34xan6iys5p4jhr80013
CSeq: 8772 UPDATE
Contact: <sip:nujzpwt1@7k0vgtcgy7l8.invalid;transport=WSS;ob>
Session-Expires: 120;refresher=uac
Allow: INVITE,ACK,CANCEL,BYE,UPDATE,MESSAGE,OPTIONS,REFER,INFO,NOTIFY
Supported: timer,ice,outbound
User-Agent: Ringplus/1.0.0
Content-Length: 0
flutter: [2025-09-07 21:34:32.268] Level.debug web_socket.dart:176 ::: Received WebSocket message
flutter: [2025-09-07 21:34:32.269] Level.debug socket_transport.dart:278 ::: received text message:

SIP/2.0 404 Not Here
Via: SIP/2.0/WSS 7k0vgtcgy7l8.invalid;received=37.174.62.89;rport=48455;branch=z9hG4bK33923526
To: <sip:1001@408708399.ringplus.co.uk>;tag=1465482185
From: "Ravi" <sip:1002@408708399.ringplus.co.uk>;tag=0412993705
Call-ID: 34xan6iys5p4jhr80013
CSeq: 8772 UPDATE
Server: RingPlus
Content-Length: 0
flutter: [2025-09-07 21:34:56.541] Level.debug rtc_session.dart:1140 ::: renegotiate()
flutter: [2025-09-07 21:34:56.546] Level.debug rtc_session.dart:2692 ::: sendVideoUpgradeReinvite()
flutter: [2025-09-07 21:34:56.549] Level.debug rtc_session.dart:1662 ::: createLocalDescription()
flutter: [2025-09-07 21:34:56.552] Level.debug rtc_session.dart:1769 ::: emit "sdp"
flutter: [2025-09-07 21:34:56.553] Level.debug rtc_session.dart:2812 ::: emit "sdp"
flutter: [2025-09-07 21:34:56.554] Level.debug rtc_session.dart:1264 ::: sendRequest()
flutter: [2025-09-07 21:34:56.554] Level.debug socket_transport.dart:128 ::: Socket Transport send()

After long time reinvite is sent but it's already too late the call was cut other side.
At network conditions changes Reinvite is not send instantly or Websocket connection need to be reestabilished.

---

flutter: SIP Service: WebSocket reconnection failed: type 'Null' is not a subtype of type 'String'
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: type 'Null' is not a subtype of type 'String'
#0 SipService.\_forceReconnectSip (package:ringplus_pbx/core/services/sip_service.dart:1086:33)
<asynchronous suspension>
#1 SipService.\_handleConnectivityChange (package:ringplus_pbx/core/services/sip_service.dart:952:9)
<asynchronous suspension>
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi
flutter: [2025-09-07 21:56:10.446] Level.info ua.dart:372 ::: Closing connection\^[[0m
flutter: [2025-09-07 21:56:10.448] Level.debug socket_transport.dart:99 ::: Transport close()
flutter: [2025-09-07 21:56:10.449] Level.debug web_socket.dart:119 ::: disconnect()
flutter: [2025-09-07 21:56:10.450] Level.debug web_socket.dart:168 ::: WebSocket wss://phone.ringplus.co.uk:4643 closed
flutter: [2025-09-07 21:56:10.454] Level.debug sip_ua_helper.dart:205 ::: disconnected => Code: [0], Cause: disconnect, Reason: close by local
flutter: SIP Service: Transport state changed to TransportStateEnum.DISCONNECTED
flutter: SIP Service: Transport disconnected - Code: [0], Cause: disconnect, Reason: close by local
flutter: SIP Service: Normal transport disconnection, not reconnecting
flutter: [2025-09-07 21:56:10.515] Level.debug web_socket.dart:102 ::: Closed [1000, ]!
flutter: [2025-09-07 21:56:10.518] Level.debug web_socket.dart:168 ::: WebSocket wss://phone.ringplus.co.uk:4643 closed
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi

You were implementing, websocket reconnection and reinvite when network conditions change. Following your changes I have this error when network condition change.

---

flutter: SIP Service: App inactive
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.mobile
flutter: SIP Service: Network transition detected - forcing WebSocket reconnection
flutter: SIP Service: Network transition during active call - starting immediate recovery
flutter: SIP Service: Starting call recovery for call: 65r82lx1znsv8pi6mnnrxsr70dkbvd
flutter: SipService: \_updateCurrentCall called - callId: 65r82lx1znsv8pi6mnnrxsr70dkbvd, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SipService: \_updateCurrentCall called - callId: 65r82lx1znsv8pi6mnnrxsr70dkbvd, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SIP Service: Starting aggressive call recovery for: 65r82lx1znsv8pi6mnnrxsr70dkbvd
flutter: SIP Service: Forcing WebSocket reconnection...
flutter: [2025-09-07 22:10:13.299] Level.debug ua.dart:311 ::: stop()
flutter: [2025-09-07 22:10:13.302] Level.debug socket_transport.dart:128 ::: Socket Transport send()
flutter: [2025-09-07 22:10:13.303] Level.debug web_socket.dart:136 ::: send()
flutter: [2025-09-07 22:10:13.303] Level.debug ua.dart:331 ::: closing session 65r82lx1znsv8pi6mnnrxsr70dkbvd
flutter: [2025-09-07 22:10:13.304] Level.debug rtc_session.dart:716 ::: terminate()
flutter: [2025-09-07 22:10:13.305] Level.debug rtc_session.dart:784 ::: terminating session
flutter: [2025-09-07 22:10:13.305] Level.debug rtc_session.dart:1264 ::: sendRequest()
flutter: [2025-09-07 22:10:13.306] Level.debug socket_transport.dart:128 ::: Socket Transport send()
flutter: [2025-09-07 22:10:13.306] Level.debug web_socket.dart:136 ::: send()
flutter: [2025-09-07 22:10:13.307] Level.debug rtc_session.dart:3258 ::: session ended
flutter: [2025-09-07 22:10:13.307] Level.debug rtc_session.dart:1501 ::: close()
flutter: [2025-09-07 22:10:13.308] Level.debug rtc_session.dart:3261 ::: emit "ended"
flutter: [2025-09-07 22:10:13.308] Level.debug sip_ua_helper.dart:296 ::: call ended with cause: Code: [200], Cause: Terminated, Reason: Terminated by local
flutter: SIP Service: Call state changed - 65r82lx1znsv8pi6mnnrxsr70dkbvd - CallStateEnum.ENDED
flutter: SIP Service: Checking call update conditions - currentCallId: 65r82lx1znsv8pi6mnnrxsr70dkbvd, eventCallId: 65r82lx1znsv8pi6mnnrxsr70dkbvd, currentCall is null: false
flutter: SIP Service: Condition met - updating call info
flutter: SIP Service: About to update current call - 65r82lx1znsv8pi6mnnrxsr70dkbvd - AppCallState.ended
flutter: SipService: \_updateCurrentCall called - callId: 65r82lx1znsv8pi6mnnrxsr70dkbvd, state: AppCallState.ended
flutter: SipService: Call state added to stream - AppCallState.ended
flutter: SIP Service: Updated current call - 65r82lx1znsv8pi6mnnrxsr70dkbvd - AppCallState.ended
flutter: SIP Service: Removed call from active calls - 65r82lx1znsv8pi6mnnrxsr70dkbvd
flutter: SIP Service: Stopped existing SIP helper

When network condition changes, forcing websocket reconnection make the existing call drops.

---

flutter: SIP Service: App inactive
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: App inactive
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: App inactive
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.mobile
flutter: SIP Service: Network transition detected - forcing WebSocket reconnection
flutter: SIP Service: Network transition during active call - starting immediate recovery
flutter: SIP Service: Starting call recovery for call: n6269cdyv7ixvmbdellbkuauyllogs
flutter: SipService: \_updateCurrentCall called - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SipService: \_updateCurrentCall called - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SIP Service: Starting aggressive call recovery for: n6269cdyv7ixvmbdellbkuauyllogs
flutter: SIP Service: Sending immediate re-INVITE due to network change
flutter: SIP Service: Sending immediate re-INVITE to maintain call
flutter: InCallScreen: Received call state update - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.reconnecting, widgetCallId: 1757276336316
flutter: InCallScreen: Received call state update - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.reconnecting, widgetCallId: 1757276336316
flutter: SIP Service: Set new local description for re-INVITE
flutter: SIP Service: Re-INVITE triggered by local description update
flutter: SIP Service: Network change detected - From: ConnectivityResult.mobile To: ConnectivityResult.mobile
flutter: SIP Service: Waiting for call recovery...
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: Connection state: RTCPeerConnectionState.RTCPeerConnectionStateConnected, ICE state: RTCIceConnectionState.RTCIceConnectionStateCompleted
flutter: SIP Service: Call recovery successful - connection restored
flutter: SIP Service: Call recovery successful
flutter: SipService: \_updateCurrentCall called - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.answered, widgetCallId: 1757276336316
flutter: SipService: \_updateCurrentCall called - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: n6269cdyv7ixvmbdellbkuauyllogs, state: AppCallState.answered, widgetCallId: 1757276336316
flutter: [2025-09-07 22:19:31.452] Level.debug invite_client.dart:81 ::: Timer B expired for transaction z9hG4bK15846521970000000
flutter: [2025-09-07 22:19:34.166] Level.debug invite_client.dart:70 ::: Timer M expired for transaction z9hG4bK15846521970000000
flutter: SIP Service: App inactive
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: Keep-alive check - Registration state: SipRegistrationState.registered

---

flutter: SIP Service: App inactive
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.mobile
flutter: SIP Service: Network transition detected - forcing WebSocket reconnection
flutter: SIP Service: Network transition during active call - starting immediate recovery
flutter: SIP Service: Starting call recovery for call: 905963p1p5fb1aghks613582671167
flutter: SipService: \_updateCurrentCall called - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SipService: \_updateCurrentCall called - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SIP Service: Starting aggressive call recovery for: 905963p1p5fb1aghks613582671167
flutter: SIP Service: Sending immediate re-INVITE due to network change
flutter: SIP Service: Sending immediate re-INVITE to maintain call
flutter: InCallScreen: Received call state update - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.reconnecting, widgetCallId: 1757277680777
flutter: InCallScreen: Received call state update - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.reconnecting, widgetCallId: 1757277680777
flutter: SIP Service: Set new local description for re-INVITE
flutter: SIP Service: Re-INVITE triggered by local description update
flutter: SIP Service: Network change detected - From: ConnectivityResult.mobile To: ConnectivityResult.mobile
flutter: SIP Service: App resumed - checking SIP connection
flutter: SIP Service: Connection is healthy - already registered
flutter: SIP Service: Waiting for call recovery...
flutter: SIP Service: Connection state: RTCPeerConnectionState.RTCPeerConnectionStateConnected, ICE state: RTCIceConnectionState.RTCIceConnectionStateConnected
flutter: SIP Service: Call recovery successful - connection restored
flutter: SIP Service: Call recovery successful
flutter: SipService: \_updateCurrentCall called - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.answered, widgetCallId: 1757277680777
flutter: SipService: \_updateCurrentCall called - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: 905963p1p5fb1aghks613582671167, state: AppCallState.answered, widgetCallId: 1757277680777
flutter: [2025-09-07 22:41:55.893] Level.debug invite_client.dart:81 ::: Timer B expired for transaction z9hG4bK6083656360000000
flutter: [2025-09-07 22:41:59.105] Level.debug invite_client.dart:70 ::: Timer M expired for transaction z9hG4bK6083656360000000

---

flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.wifi
flutter: SIP Service: Network change detected - From: ConnectivityResult.wifi To: ConnectivityResult.mobile
flutter: SIP Service: Network transition detected - forcing WebSocket reconnection
flutter: SIP Service: Network transition during active call - starting immediate recovery
flutter: SIP Service: Starting call recovery for call: ehvn3y92chv4h60nme4ckl4w8a5697
flutter: SipService: \_updateCurrentCall called - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SipService: \_updateCurrentCall called - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.reconnecting
flutter: SipService: Call state added to stream - AppCallState.reconnecting
flutter: SIP Service: Starting aggressive call recovery for: ehvn3y92chv4h60nme4ckl4w8a5697
flutter: SIP Service: Checking WebSocket connectivity...
flutter: InCallScreen: Received call state update - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.reconnecting, widgetCallId: 1757278786170
flutter: SIP Service: WebSocket connectivity verified
flutter: SIP Service: Sending immediate re-INVITE due to network change
flutter: SIP Service: Sending immediate re-INVITE to maintain call
flutter: SIP Service: Current registration status: true
flutter: SIP Service: Call ID: ehvn3y92chv4h60nme4ckl4w8a5697
flutter: InCallScreen: Received call state update - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.reconnecting, widgetCallId: 1757278786170
flutter: SIP Service: Created new offer with ICE restart
flutter: SIP Service: Offer type: offer
flutter: SIP Service: Set new local description for re-INVITE
flutter: SIP Service: Re-INVITE should have been triggered by local description update
flutter: SIP Service: Waiting for SIP transaction to complete...
flutter: SIP Service: Network change detected - From: ConnectivityResult.mobile To: ConnectivityResult.mobile
flutter: SIP Service: Waiting for call recovery...
flutter: SIP Service: Connection state: RTCPeerConnectionState.RTCPeerConnectionStateConnected, ICE state: RTCIceConnectionState.RTCIceConnectionStateCompleted
flutter: SIP Service: Call recovery successful - connection restored
flutter: SIP Service: Call recovery successful
flutter: SipService: \_updateCurrentCall called - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.answered, widgetCallId: 1757278786170
flutter: [2025-09-07 23:00:21.291] Level.debug invite_client.dart:81 ::: Timer B expired for transaction z9hG4bK20523055690000000
flutter: SipService: \_updateCurrentCall called - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.answered
flutter: SipService: Call state added to stream - AppCallState.answered
flutter: InCallScreen: Received call state update - callId: ehvn3y92chv4h60nme4ckl4w8a5697, state: AppCallState.answered, widgetCallId: 1757278786170
flutter: [2025-09-07 23:00:23.684] Level.debug invite_client.dart:70 ::: Timer M expired for transaction z9hG4bK20523055690000000

Reinvite was not sent.
I feel like we are not able recreate a new websocket connection when a socket drops and reuse existing call on the new connection.

Keep last known Call-ID → SIP dialog stays valid during re-INVITE.
Use Outbound SIP with Path/GRUU → makes re-registration after transport change smoother.
Handle ICE candidate gathering timeout → fallback to TURN if STUN fails after roaming.
On iOS: background network switches are tricky — you’ll want CallKit integration for reliability.
On network change → reconnect WebSocket → if a call is active → createOffer({ iceRestart: true }) → send SIP re-INVITE with new SDP.

---

This is a project in initial state of developement of a multitenant PBX softphone called Ringplus built with Flutter + WebRTC.
Use case: Connects to a cloud PBX. User connect by entering manually their username/password. After registration, they can make/receive calls, transfer, redirect, manage contacts, view recents/voicemail, and configure settings. App persists credentials
Navigation: Bottom tab bar with 5 tabs — Keypad, Recents, Contacts, Voicemail, Settings. Use large top titles on iOS and standard app bars on Android.
Internationalization: English + French; support RTL layout. All labels as tokens/strings.

This application was initially started with flutter_webrtc and dart_sip_ua. But handling network condition changes seems to be very complicate.

We now need to update the code to use siprix_voip_sdk: 1.0.25 instead of flutter_webrtc and dart_sip_ua.
check for documentation here: https://docs.siprix-voip.com/rst/flutter.html, https://docs.siprix-voip.com/rst/api.html, https://pub.dev/documentation/siprix_voip_sdk/latest/, https://github.com/siprix/FlutterPluginFederated/.

You need to clean up the old code to remove all references to webrtc and sip_ua and bring the same functionality using siprix_voip_sdk.
Analyze needed codes before making any breaking changes.

These are the plugins you need to use:

Signaling & media: siprix_voip_sdk
Push notifications: firebase_messaging (Android) + flutter_voip_pushkit (iOS).
Incoming call UI: flutter_callkit_incoming.
Theme: Keep the color theme centered around purple, white, and light accent colors.
Calling Features
Dialpad with DTMF.
In-call UI: mute, hold, speaker, keypad, transfer (blind & attended), redirect.
Call history (recents) with filters.
Incoming call screen (CallKit/ConnectionService style).
Contacts & Directory
Local contacts CRUD (add/edit/delete).
Quick call from contact.
Favorites section.
Voicemail
List voicemails with playback.
Show new/unread badge.
Settings
Account unregister and reregister
Call options (default audio route, forwarding placeholder).
Notifications (push, DND).
Audio/network (codec preference, STUN/TURN info read-only).
Privacy/security (TLS/SRTP indicators, data deletion).
Appearance (light/dark, per-tenant theme).
Technical Notes
Signaling: SIP over WSS, media: WebRTC (with STUN/TURN).
Push notifications: iOS PushKit+CallKit, Android FCM+ConnectionService.
Secure credential storage (Keychain/Keystore).
Localization: English & French, RTL ready.
Accessibility: WCAG AA, large touch targets, screen reader labels.

---

When calling a number InCallScreen shows up and it's showing Connecting. We should start showing timer when call is answered/established. Prior to it we should show if call is connecting/trying/ringing before starts timer once answered.

---

When we start to type a number on the keypad, the dial button is moving to left side. Keep the dial button at the same position under 0 anytime. Same for delete button it should stay under #.

---

When Im on the call, network condition changes From wifi to 4g or vice. Changes is detected an Reinvite is properly sent and the communcation works properly. But when I hangup the call on my side (siprix), the bye is not sent. But if try to send hangup the call from Other side (after network changes), I get the Bye and the call is hungup properly.

---

On Call screen has a hardcoded value: Ethan Carter. You should display the dialed Number or Contact Name (once contact is defined).
Below the called Number or Contact Name, we should have in a circle avatar displaying contact photo if calling from COntact list and the photo is defined or when it's a dialed number an avatar with Contact Icon inside. Add some colors.

---

Make the circular avatar little bit bigger and bring it little bit down (towards the center) with dialed number. Change the gradient color from blue to purple.

---

On onCall Screen, once the call is established. I should be able to mute and and unmute a call. If the call is established. Button should be disabled.

---

On onCall Screen, we need to work on the audio output button (currently speaker button). We need to able to switch between different audio output available on the device level (earphone, speaker ou any bluetooth device available).

---

On onCall Screen, for the audio output changes look good. We need some improvements: I have place an image audio_output.png in mockup. When we press on the audio output button: We should have Earpiece (Usually Buildtin one: merge earpiece and builtin together), Speaker, All the Bluetooth devices currently connected (Bluetooth options should only appear if there is any compatible device available).
For each type of sound output, show different icons as on the image. Based on the choice the Icon of the button should change (Not always shows Speak button).

---

By default, output is selected on bluetooth, it should be earpiece. For now disable bluetooth output. Just keep Earpiece and speaker by default earpiece should be selected

---

On oncall screen, I want the background in the same style as on_call_screen_bg.png from mockup folder. Don't change anything except the background colors. It has to be purple oriented.

---

Looks good. I want the background gradient more black and purple. Change the border of Avatar circle. Avatar icon is white and the circle is also a kind of white. We cant see the icon properly.
Make the buttons (mute, audio, hold etcc) bigger. same size as the in the previous image buttons.

I want avatar circle background color same as the buttons background color.

Make the avatar circle border thinner and change to white color and add white shadow effect.

---

We need to work Incoming Call Screen. There are 2 types of Incoming Call Screen: When the phone is locked vs unlocked. We are going to work first on the unlocked one. Inspired from on our existing theme colors, build it. It should show the title: Incoming Call followed by avatar (need to show the photo when we implement the contact), if the called number is not in the contact list we should show an icon (same as oncall screen) and follwed by Caller Name and Number.
At the bottom level, we need to show 2 buttons on the left and right side: Decline and Accept.

---

When an incoming calls come in and then caller hungup it before being answered. Incoming Call screen should detect the call was cancelled and returns to the keypad screen.

---

When I have an incoming call, I have callkit starting show the incoming call when i press on the button to accept the call, incoming_call_screen shows up. When I hangup that call with our app hangup. I have IOS callkit screen, still running in the background. Hangup doenst work from both UI.

---

On the incoming call, when I try to hangup on Call Screen, the same screen reopens again with Caller number Unknown and Status: Connecting. Bye message is never sent to hangup the call.

---

Issue with Screen reopening is fixed but when hanging up the call Bye SIP message is not sent.

---

Outgoing call is not working. Invite is sent properly but on 407 Proxy Authentication Required, the new invite is not sent. Caller details is shown as Unknown on oncall screen.

---

When making an outgoing call, once the dial button is pressed oncall screen shows up and for few milliseconds Caller Number is Unknown (I guess till a replied is received), for an outgoing call we know the dialer number we should show, so we dont have Unknow for few milliseconds.

---

On incoming call and once answered siprix sends:

U 2025/09/10 22:22:45.681266 78.240.172.143:56741 -> 10.16.0.5:5060 #8057
SIP/2.0 200 OK.
Via: SIP/2.0/UDP 68.183.254.236:5060;branch=z9hG4bK31f4.eb8b6bd6.0.
Contact: <sip:1002@78.240.172.143:56741;transport=udp>;+sip.instance="<urn:uuid:0e4ef933-94e1-43fb-bc07-64cb9d827db5>";reg-id=1.
To: <sip:1002@408708399.ringplus.co.uk;user=phone>;tag=ee9f2220.
From: "Srigo" <sip:1001@408708399.ringplus.co.uk>;tag=3099470047.
Call-ID: 72255472@192_168_0_75.
CSeq: 3 INVITE.
Session-Expires: 1800;refresher=uas.
Allow: INVITE, ACK, CANCEL, OPTIONS, BYE, REFER, NOTIFY, SUBSCRIBE, UPDATE, PRACK, INFO, MESSAGE.
Content-Type: application/sdp.
Supported: replaces, timer, norefersub, answermode, tdialog.
User-Agent: Ringplus/1.0.0.
Content-Length: 302.
.
v=0.
o=- 6472689401898196955 2 IN IP4 127.0.0.1.
s=-.
t=0 0.
m=audio 59040 RTP/AVP 0 8 101.
c=IN IP4 10.31.124.203.
a=rtpmap:0 PCMU/8000.
a=rtpmap:8 PCMA/8000.
a=rtpmap:101 telephone-event/8000.
a=fmtp:101 0-16.
a=mid:0.
a=sendrecv.
a=msid:- siprixAudio.
a=ptime:20.
a=rtcp:61846 IN IP4 10.31.124.203.

SDP has 127.0.0.1 and 10.31.124.203. Can siprix detect it's behind a NAT and add the public IP in the SDP

---

On incoming call, siprix send 200 OK with a=mid and a=msid and a=rtcp-mux. Can we disable them?

---

We are working on a softphone for IOS/Android using flutter and siprix SDK. You can pubspec for other dependances.
On a incoming call, I have callkit shows up. Currently it shows Ringplus Audio just below "Srigo" 1001@1XXXX.ringplus.co.uk. I need to show only the name eg: Srigo (without double quotes). If name doesnt exist show only caller number.

---

I have place callkit_notification.PNG in mockup folder look how it shows up.
logs:
flutter: SIP Service: Incoming call - callId: 205, from: "Test" <sip:1003@408708399.ringplus.co.uk>, to: sip:1002@408708399.ringplus.co.uk, withVideo: false
flutter: SIP Service: Raw from header: "Test" <sip:1003@408708399.ringplus.co.uk>
flutter: SIP Service: Parsed name: "Test", number: "1003"
flutter: SIP Service: Parsed caller - name: Test, number: 1003
flutter: SipService: \_updateCurrentCall called - callId: 205, state: AppCallState.ringing
flutter: SIP Service: CallKit display - callerName: "Test", callerNumber: "1003"
flutter: SIP Service: CallKit will display: "Test"
flutter: SIP Service: CallKit incoming call displayed - no app UI needed

check for documentation here: https://docs.siprix-voip.com/rst/flutter.html, https://docs.siprix-voip.com/rst/api.html, https://pub.dev/documentation/siprix_voip_sdk/latest/, https://github.com/siprix/FlutterPluginFederated/.

flutter: SIP Service: Incoming call - callId: 207, from: "Test" <sip:1003@408708399.ringplus.co.uk>, to: sip:1002@408708399.ringplus.co.uk, withVideo: false
flutter: SIP Service: Raw from header: "Test" <sip:1003@408708399.ringplus.co.uk>
flutter: SIP Service: Raw name before quote removal: ""Test""
flutter: SIP Service: Raw name after quote removal: "Test"
flutter: SIP Service: Parsed name: "Test", number: "1003"
flutter: SIP Service: Parsed caller - name: Test, number: 1003
flutter: SipService: \_updateCurrentCall called - callId: 207, state: AppCallState.ringing
flutter: SIP Service: CallKit display - callerName: "Test", callerNumber: "1003"
flutter: SIP Service: CallKit will display: "Test" (cleaned from: "Test")
flutter: SIP Service: CallKit params - nameCaller: "Test", handle: "1003", appName: "RingPlus"
flutter: SIP Service: CallKit incoming call displayed - no app UI needed

Don't show URI after CallerName.

---

We now need to show avatar on callkit incoming notification. It has to have same style as the one on OnCallScreen, We need to display contact photo if calling number is found in our COntact list (not yet implemented) and if the photo is defined. if the number is not known then show an avatar with Contact Icon inside (same as the on on call screen)

---

On incoming call, on call screen shows up when we accept the call. But sometimes when the call is connected timer starts show up but sometimes it only show Connecting...

---

Mute button not working on incoming call on the call screen:

flutter: Mute call: 205, mute: true
flutter: Mute: Active call object: null, switched ID: 0, total calls: 0
flutter: Mute: All mute attempts failed
flutter: Mute call failed: Exception: No active call found for muting (all methods failed)
flutter: InCallScreen: Mute operation failed, reverting UI state: Exception: No active call found for muting (all methods failed)

---

When we accept the call on Callkit, it should take use to OnCallScreen.

---

In the callkit incoming calls notfification shows only Caller Name or Caller Number if Caller Name is not available.

---

Sometimes Callkit shows up as a full screen on incoming, sometimes It shows as a notification. In the first I have no audio, second case I have audio

---

234459.332 [4971242] (RTCLogging.mm:33): (RTCAudioSession.mm:407 -[RTCAudioSession setActive:error:]): Number of current activations: 1
234459.341 [4971242] (RTCLogging.mm:33): (RTCAudioSession.mm:724 -[RTCAudioSession configureWebRTCSession:]): Failed to set WebRTC audio configuration: The operation couldn’t be completed. (OSStatus error -50.)
234459.341 [4971242] (RTCLogging.mm:33): (audio_device_ios.mm:836 ConfigureAudioSessionLocked): Failed to configure audio session.
234459.341 [4971242] (RTCLogging.mm:33): (voice_processing_audio_unit.mm:477 DisposeAudioUnit): Disposing audio unit.

---

Remove fallback logic of starting timer after 3s on the OnCallScreen

---

We only need to start timer when OnConnectedConfirmed till then show Connecting:

235937.199 [4991257] (InviteSession.cxx:2841): Transition UAS_Accepted -> InviteSession::Connected
235937.199 [4991257] (RemoteParticipant.cxx:1610): onConnectedConfirmed: handle=208, SipReq: ACK 1002@192.168.0.163:5060 tid=2ed5.65d81271.2 cseq=751 ACK contact=68.183.254.236:5060 / 751 from(wire)
235937.199 [4991257] (SiprixConvManager.cpp:232): onParticipantConnectedConfirmed callId:208
235937.199 [4991257] (RemoteParticipant.cxx:538): RemoteParticipant::stateTransition of handle=208 to state=Connected
235937.200 [4991256] (Transport.cxx:403): RX 'Req ACK/cseq=751' from: [68.183.254.236:5060 UDP]
235937.200 [4991258] (Callbacks.cpp:295): Callback:41 callId:208
235937.200 [4991257] (DialogUsageManager.cxx:2102): Handling in-dialog request: SipReq: ACK 1002@192.168.0.163:5060 tid=2ed5.65d81271.2 cseq=751 ACK contact=68.183.254.236:5060 / 751 from(wire)
flutter: event OnCallConnected {from: "RP 1003" <sip:1003@408708399.ringplus.co.uk>, withVideo: false, callId: 208, to: sip:1002@408708399.ringplus.co.uk}
flutter: SIP Service: Call connected - callId: 208, from: "RP 1003" <sip:1003@408708399.ringplus.co.uk>, to: sip:1002@408708399.ringplus.co.uk, withVideo: false
flutter: SipService: \_updateCurrentCall called - callId: 208, state: AppCallState.answered
flutter: SIP Service: Incoming call connected, navigating to OnCallScreen
flutter: InCallScreen: Received call state update - callId: 208, state: AppCallState.answered, widgetCallId: 208

Check this and see different pages if needed: docs: https://docs.siprix-voip.com/index.html
Check if there is event called OnCallSwitched, to start the timer on the on call screen. If not do not start the timer till the call is connected. Instead show Connecting

OnCallSwitched doesnt seem to start when Audio starts. Let change to show timer only when the call is answered event.

---

When the phone is locked and if we get an incoming call and answer it and hangup, callkit close up but if we open the app, oncallscreen shows up as the call is active and we need to hangup on it, to have SIP BYE sent.

---

When the app is in background (Phone not locked). When I get incoming call and accept it. It opens the app and on callscreen shows up and disappear before showing keypad screen while the call is active.

---

Problem persists, when the app is in background and accept an incoming call, the app opens and on call screen shows up for around 1secs and go back to keypad. Hanging up the call from the caller doesnt close the callkit screen in the background. Seems like the event is not sent to callkit to cut the call.

Logs:
flutter: event OnCallIncoming {from: "Ravi" <sip:1001@408708399.ringplus.co.uk>, to: sip:1002@408708399.ringplus.co.uk, accId: 1, callId: 207, withVideo: false}
flutter: SIP Service: Incoming call - callId: 207, from: "Ravi" <sip:1001@408708399.ringplus.co.uk>, to: sip:1002@408708399.ringplus.co.uk, withVideo: false
flutter: SIP Service: Raw from header: "Ravi" <sip:1001@408708399.ringplus.co.uk>
flutter: SIP Service: Raw name before quote removal: ""Ravi""
flutter: SIP Service: Raw name after quote removal: "Ravi"
flutter: SIP Service: Parsed name: "Ravi", number: "1001"
flutter: SIP Service: Parsed caller - name: Ravi, number: 1001
flutter: SIP Service: Stored Siprix call ID for operations: 207
flutter: SipService: \_updateCurrentCall called - callId: 207, state: AppCallState.ringing
flutter: SIP Service: CallKit display - callerName: "Ravi", callerNumber: "1001"
flutter: SIP Service: CallKit will display: "Ravi" (cleaned from: "Ravi")
flutter: SIP Service: CallKit params - nameCaller: "Ravi", handle: "Ravi", appName: "RingPlus"
flutter: SIP Service: CallKit incoming call displayed - no app UI needed
flutter: event OnCallSwitched {callId: 207}
flutter: SIP Service: Direct call switched - callId: 207
flutter: SIP Service: Direct call switched to active call: 207
flutter: SIP Service: CallKit incoming call shown with UUID: b4a3486c-f670-4882-9dd4-0a42a19b3ba4, SIP callId: 207
flutter: SIP Service: CallKit event: Event.actionCallIncoming
flutter: SIP Service: CallKit incoming call displayed successfully
flutter: SIP Service: CallKit event: Event.actionCallAccept
flutter: SIP Service: CallKit accept for SIP call: 207
flutter: SIP Service: Before CallKit accept - checking system audio state
flutter: SIP Service: CallKit accept with audio fix for SIP call: 207
flutter: SIP Service: Audio session state before accept
flutter: Answer call: 207
flutter: Answer call: Accepting call with ID 207
flutter: Answer call: Successfully accepted call via SDK
flutter: SipService: \_updateCurrentCall called - callId: 207, state: AppCallState.answered
flutter: event OnCallConnected {from: "Ravi" <sip:1001@408708399.ringplus.co.uk>, withVideo: false, callId: 207, to: sip:1002@408708399.ringplus.co.uk}
flutter: SIP Service: Call connected - callId: 207, from: "Ravi" <sip:1001@408708399.ringplus.co.uk>, to: sip:1002@408708399.ringplus.co.uk, withVideo: false
flutter: SipService: \_updateCurrentCall called - callId: 207, state: AppCallState.answered
flutter: SIP Service: Incoming call connected, navigating to OnCallScreen
flutter: SIP Service: App hidden
flutter: SIP Service: App inactive
flutter: SIP Service: CallKit event: Event.actionCallToggleAudioSession
flutter: SIP Service: CallKit accept with audio fix completed
flutter: InCallScreen: Setting up call state listener for callId: 207
flutter: InCallScreen: Loading contact info for: 1001
flutter: InCallScreen: ContactService does not have permission, skipping lookup
flutter: InCallScreen: Found existing call on init - state: AppCallState.answered
flutter: InCallScreen: Call was already answered on init, starting timer
flutter: SIP Service: CallKit event: Event.actionCallAccept
flutter: SIP Service: CallKit call b4a3486c-f670-4882-9dd4-0a42a19b3ba4 already accepted, ignoring duplicate accept event
flutter: SIP Service: CallKit call accepted and connected
flutter: SIP Service: App resumed
flutter: SIP Service: Checking for stale call states after app resume
flutter: SIP Service: Current call state: AppCallState.answered, Active Siprix calls: 0, Switched call ID: 0
flutter: SIP Service: Detected stale call state - cleaning up
flutter: SipService: \_updateCurrentCall called - callId: 207, state: AppCallState.ended
flutter: InCallScreen: Received call state update - callId: 207, state: AppCallState.ended, widgetCallId: 207
flutter: InCallScreen: Call ended: Navigating back to keypad
flutter: SipService: \_updateCurrentCall called - callId: null, state: null
flutter: SIP Service: Stale call state cleaned up
flutter: InCallScreen: Received call state update - callId: null, state: null, widgetCallId: 207
flutter: event OnCallTerminated {statusCode: 0, callId: 207}
flutter: SIP Service: Direct call terminated - callId: 207, statusCode: 0
flutter: event OnCallSwitched {callId: 0}
flutter: SIP Service: Direct call switched - callId: 0
flutter: event OnCallSwitched {callId: 0}
flutter: SIP Service: Direct call switched - callId: 0
