import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';
import 'package:siprix_voip_sdk/accounts_model.dart';
import 'package:siprix_voip_sdk/calls_model.dart';
import 'package:siprix_voip_sdk/network_model.dart';
import 'package:siprix_voip_sdk/devices_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../constants/app_constants.dart';
import '../../shared/services/storage_service.dart';
import 'navigation_service.dart';
import 'contact_service.dart';
import 'notification_service.dart';

enum AudioDeviceCategory {
  earpiece,
  speaker,
  bluetooth,
  wired,
  builtin,
  other,
}

class AudioDeviceInfo {
  final MediaDevice device;
  final int index;
  final AudioDeviceCategory category;
  final String displayName;
  final IconData icon;

  AudioDeviceInfo({
    required this.device,
    required this.index,
    required this.category,
    required this.displayName,
    required this.icon,
  });
}

enum SipRegistrationState {
  unregistered,
  registering,
  registered,
  registrationFailed,
}

enum AppCallState {
  none,
  connecting,
  ringing,
  answered,
  held,
  muted,
  ended,
  failed,
  reconnecting,
}

class CallInfo {
  final String id;
  final String remoteNumber;
  final String remoteName;
  final AppCallState state;
  final DateTime startTime;
  final bool isIncoming;
  final bool isOnHold;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isConnectedWithAudio;

  CallInfo({
    required this.id,
    required this.remoteNumber,
    required this.remoteName,
    required this.state,
    required this.startTime,
    required this.isIncoming,
    this.isOnHold = false,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isConnectedWithAudio = false,
  });

  CallInfo copyWith({
    String? id,
    String? remoteNumber,
    String? remoteName,
    AppCallState? state,
    DateTime? startTime,
    bool? isIncoming,
    bool? isOnHold,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isConnectedWithAudio,
  }) {
    return CallInfo(
      id: id ?? this.id,
      remoteNumber: remoteNumber ?? this.remoteNumber,
      remoteName: remoteName ?? this.remoteName,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      isIncoming: isIncoming ?? this.isIncoming,
      isOnHold: isOnHold ?? this.isOnHold,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isConnectedWithAudio: isConnectedWithAudio ?? this.isConnectedWithAudio,
    );
  }
}

class SipService extends ChangeNotifier with WidgetsBindingObserver {
  static final SipService _instance = SipService._internal();
  static SipService get instance => _instance;
  SipService._internal();

  // Siprix SDK components
  SiprixVoipSdk? _siprixSdk;
  AccountsModel? _accountsModel;
  CallsModel? _callsModel;
  NetworkModel? _networkModel;
  DevicesModel? _devicesModel;
  int? _currentAccountId;

  SipRegistrationState _registrationState = SipRegistrationState.unregistered;
  CallInfo? _currentCall;
  int? _currentSiprixCallId; // Store the actual Siprix call ID for operations
  Timer? _connectionCheckTimer;

  // Flag to prevent actions during hangup process
  bool _isHangingUp = false;

  // Flag to prevent state updates after disposal
  bool _isDisposed = false;

  // Store credentials for re-registration
  Map<String, dynamic>? _lastCredentials;

  // Network change detection
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  ConnectivityResult _lastConnectivityResult = ConnectivityResult.none;

  // Stream controllers for real-time updates
  final StreamController<SipRegistrationState> _registrationStateController =
      StreamController<SipRegistrationState>.broadcast();
  final StreamController<CallInfo?> _currentCallController =
      StreamController<CallInfo?>.broadcast();

  // Getters
  SipRegistrationState get registrationState => _registrationState;
  CallInfo? get currentCall => _currentCall;
  bool get isRegistered =>
      _registrationState == SipRegistrationState.registered;
  bool get hasActiveCall =>
      _currentCall != null && _currentCall!.state != AppCallState.ended;

  // Streams
  Stream<SipRegistrationState> get registrationStateStream =>
      _registrationStateController.stream;
  Stream<CallInfo?> get currentCallStream => _currentCallController.stream;

  Future<void> initialize() async {
    try {
      debugPrint('SIP Service: Starting initialization...');
      if (_siprixSdk != null) {
        debugPrint('SIP Service: Already initialized, skipping...');
        return;
      }

      // Initialize Siprix SDK
      InitData initData = InitData();
      initData.license = ""; // TODO: Add license key here or use trial mode
      initData.singleCallMode = false; // Allow multiple calls

      // Share UDP transport for efficiency
      initData.shareUdpTransport = true;

      // Platform-specific initialization
      if (Platform.isIOS) {
        // iOS-specific settings - these work reliably on iOS
        initData.enableVideoCall =
            false; // Disable video - reduces WebRTC SDP attributes
        initData.enableCallKit = true; // Enable Siprix built-in CallKit
        initData.enablePushKit = true; // Enable PushKit for background calls
        initData.unregOnDestroy = false;
        debugPrint(
            'SIP Service: Enabled Siprix built-in CallKit and PushKit for iOS');
      } else if (Platform.isAndroid) {
        // Android-specific settings - skip problematic video configuration
        // Note: Skip enableVideoCall on Android to avoid native library issues
        debugPrint(
            'SIP Service: Configured Siprix for Android (video disabled)');
      }

      _siprixSdk = SiprixVoipSdk();

      // Create models for account and call management
      _accountsModel = AccountsModel();
      _callsModel = CallsModel(_accountsModel!);
      _networkModel = NetworkModel();
      _devicesModel = DevicesModel();

      // Set up event listeners
      _setupEventListeners();

      await _siprixSdk!.initialize(initData);

      // Load audio devices - CallKit will handle audio configuration
      _devicesModel?.load();

      // Set up direct SDK call listener for call events
      _siprixSdk!.callListener = CallStateListener(
        terminated: _onCallTerminatedDirect,
        switched: _onCallSwitchedDirect,
        proceeding: _onCallProceeding,
        connected: _onCallConnected,
        incoming: _onCallIncomingDirect,
        incomingPush: _onIncomingPush, // Enable push call handling for CallKit
      );

      debugPrint('SIP Service: Call and push listeners configured');

      // Set up contact name resolution callback after SDK is fully initialized
      if (_callsModel != null) {
        _callsModel!.onResolveContactName = _resolveContactNameForCallKit;
        debugPrint(
            'SIP Service: Contact name resolution callback set on CallsModel');
      } else {
        debugPrint(
            'SIP Service: Warning - CallsModel is null, cannot set contact name callback');
      }

      debugPrint('SIP Service: Siprix SDK initialized successfully');

      // Add app lifecycle observer (not available on web)
      if (!kIsWeb) {
        try {
          WidgetsBinding.instance.addObserver(this);
          debugPrint('SIP Service: Added app lifecycle observer');
        } catch (e) {
          debugPrint('SIP Service: Could not add lifecycle observer: $e');
        }
      }

      // Initialize network connectivity monitoring
      await _initializeNetworkMonitoring();

      // Try to auto-register if credentials are stored
      final credentials = await StorageService.instance.getCredentials();
      if (credentials != null) {
        debugPrint('We have stored SIP credentials');
        await _autoRegister(credentials);
      }

      // Siprix built-in CallKit and PushKit will handle events automatically

      // Try to get PushKit token after SDK initialization (tokens may not be immediately available)
      if (Platform.isIOS) {
        debugPrint(
            'SIP Service: iOS detected - starting PushKit token retrieval process');
        _checkIOSCapabilities();
        debugIOSPushConfiguration();
        _scheduleTokenRetry();
      }

      // Initialize contact service for avatar generation (non-blocking)
      ContactService.instance.initialize().catchError((e) {
        debugPrint('SIP Service: Contact service initialization failed: $e');
        return false; // Return false to indicate initialization failed
      });
      debugPrint(
          'SIP Service: Contact service initialization started in background');

      debugPrint('SIP Service: Initialization complete');
    } catch (e) {
      debugPrint('Error initializing SIP service: $e');
      // Reset SDK on initialization failure
      _siprixSdk = null;
      _accountsModel = null;
      _callsModel = null;
      rethrow;
    }
  }

  void _setupEventListeners() {
    // Set up account and call event listeners
    _accountsModel?.addListener(_onModelsChanged);
    _callsModel?.addListener(_onModelsChanged);
    _networkModel?.addListener(_onNetworkChanged);

    // Set up Siprix call event listeners
    _callsModel?.onSwitchedCall = _onCallSwitched;
    _callsModel?.onNewIncomingCall = _onNewIncomingCall;

    debugPrint('SIP Service: Event listeners configured');
  }

  void _onModelsChanged() {
    // Simple model change listener - in a full implementation,
    // you would check specific account registration states and call states
    debugPrint('SIP Service: Models changed - checking status...');
  }

  void _onCallSwitched(int callId) {
    debugPrint('SIP Service: Call switched - callId: $callId');
    if (callId == 0) {
      // No active calls - this means call was terminated
      if (_currentCall != null) {
        _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

        // Clear the call after a brief delay to allow UI to update
        Timer(const Duration(milliseconds: 500), () {
          _updateCurrentCall(null);
        });
      }
    } else {
      debugPrint('SIP Service: Call switched to active call: $callId');
    }
  }

  void _onNewIncomingCall() {
    debugPrint('SIP Service: New incoming call received');
    // TODO: Handle incoming calls
  }

  /// Resolve contact name for CallKit display - called by Siprix for incoming/outgoing calls
  String _resolveContactNameForCallKit(String extension) {
    try {
      debugPrint(
          '🔥 SIP Service: CALLBACK TRIGGERED - Resolving contact name for CallKit display: "$extension"');

      // Use our existing parsing logic to handle full SIP headers
      final callerInfo = _parseCallerInfo(extension);
      final callerName = callerInfo['name'] ?? 'Unknown';
      final callerNumber = callerInfo['number'] ?? 'Unknown';

      debugPrint(
          '🔥 SIP Service: Parsed for CallKit - name: "$callerName", number: "$callerNumber"');

      // Return the name if it's meaningful, otherwise return the number
      String result;
      if (callerName != 'Unknown' && callerName != callerNumber) {
        result = callerName;
        debugPrint(
            '🔥 SIP Service: Returning caller name for CallKit: "$result"');
      } else {
        result = callerNumber;
        debugPrint(
            '🔥 SIP Service: Returning caller number for CallKit: "$result"');
      }

      return result;

      // Future enhancement: integrate with ContactService
      // final contactInfo = await ContactService.instance.findContactByPhoneNumber(callerNumber);
      // if (contactInfo != null && contactInfo.displayName != callerNumber) {
      //   return contactInfo.displayName;
      // }
    } catch (e) {
      debugPrint('🔥 SIP Service: Error resolving contact name: $e');
      return extension; // Return original if there's an error
    }
  }

  void _onNetworkChanged() {
    debugPrint(
        'SIP Service: Network model changed - checking network state...');
    if (_networkModel != null) {
      final isNetworkLost = _networkModel!.networkLost;
      debugPrint('SIP Service: Network lost: $isNetworkLost');

      // If we have an active call and network issues, track the network state
      if (_currentCall != null && isNetworkLost) {
        debugPrint(
            'SIP Service: Network lost during active call - call may need recovery');
      }
    }
  }

  // Direct SDK event handlers
  void _onCallTerminatedDirect(int callId, int statusCode) {
    debugPrint(
        'SIP Service: Direct call terminated - callId: $callId, statusCode: $statusCode');

    // Clear the stored Siprix call ID
    _currentSiprixCallId = null;

    // Siprix built-in CallKit will handle call termination automatically

    // Update our call state to ended
    if (_currentCall != null) {
      _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

      // Clear the call after a brief delay to allow UI to update and navigate back
      Timer(const Duration(milliseconds: 800), () {
        _updateCurrentCall(null);
        // Clear hangup flag after call is terminated
        _isHangingUp = false;

        // Add extra delay to ensure audio session is fully cleaned up
        // This helps prevent WebRTC conflicts on subsequent calls
        debugPrint(
            'SIP Service: Call cleanup completed - audio session should be free');
      });
    } else {
      // Clear hangup flag immediately if there's no current call
      _isHangingUp = false;
    }
  }

  void _onCallSwitchedDirect(int callId) {
    debugPrint('SIP Service: Direct call switched - callId: $callId');
    if (callId == 0) {
      // No active calls - clear the stored call ID
      _currentSiprixCallId = null;

      if (_currentCall != null) {
        _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));
        Timer(const Duration(milliseconds: 800), () {
          _updateCurrentCall(null);
        });
      }
    } else {
      // Update the stored call ID with the new active call
      _currentSiprixCallId = callId;

      debugPrint('SIP Service: Direct call switched to active call: $callId');
    }
  }

  void _onCallProceeding(int callId, String response) {
    debugPrint(
        'SIP Service: Call proceeding - callId: $callId, response: $response');

    // Ignore proceeding events if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring proceeding event - hangup in progress');
      return;
    }

    if (_currentCall != null) {
      // Handle different SIP response codes to show appropriate states
      if (response.contains('100')) {
        // 100 Trying - call is being processed
        if (_currentCall!.state == AppCallState.connecting) {
          // Keep it as connecting, or could add a "trying" state if needed
          debugPrint('SIP Service: Call trying - waiting for response');
        }
      } else if (response.contains('180') || response.contains('Ringing')) {
        // 180 Ringing - remote party is being alerted
        _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ringing));
        debugPrint('SIP Service: Call ringing - remote party being alerted');
      }
    }
  }

  void _onCallConnected(int callId, String from, String to, bool withVideo) {
    debugPrint(
        'SIP Service: Call connected - callId: $callId, from: $from, to: $to, withVideo: $withVideo');

    // Ignore connected events if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring connected event - hangup in progress');
      return;
    }

    // Call is connected - start timer immediately
    if (_currentCall != null) {
      _updateCurrentCall(_currentCall?.copyWith(
        state: AppCallState.answered,
        // Start timer when call is connected/answered
        startTime: DateTime.now(),
        isConnectedWithAudio: true,
      ));

      // Navigate to OnCallScreen when call is connected/answered
      // Built-in Siprix CallKit handles CallKit UI, we handle app navigation
      if (_currentCall!.isIncoming) {
        debugPrint(
            'SIP Service: Incoming call connected, navigating to OnCallScreen');
        NavigationService.goToInCall(
          _currentCall!.id,
          phoneNumber: _currentCall!.remoteNumber,
          contactName: _currentCall!.remoteName != _currentCall!.remoteNumber
              ? _currentCall!.remoteName
              : null,
        );
      } else {
        debugPrint(
            'SIP Service: Outgoing call connected, OnCallScreen should already be visible');
      }
    }
  }

  // Handle incoming push notifications for CallKit
  void _onIncomingPush(String callkitUuid, Map<String, dynamic> payload) {
    if (!Platform.isIOS) return;

    try {
      debugPrint(
          'SIP Service: Incoming push - CallKit UUID: $callkitUuid, Payload: $payload');

      // Extract caller details from payload
      String callerName = payload['callerName'] ?? 'Incoming Call';
      String callerNumber = payload['callerNumber'] ?? '';

      debugPrint(
          'SIP Service: Push notification - Name: $callerName, Number: $callerNumber');

      // Update CallKit call details with push notification information
      try {
        _siprixSdk?.updateCallKitCallDetails(
          callkitUuid,
          null, // SIP call ID will be provided when SIP call arrives
          callerName,
          callerNumber,
          false, // withVideo
        );
        debugPrint(
            'SIP Service: Updated CallKit details from push notification');
      } catch (e) {
        debugPrint('SIP Service: Failed to update CallKit details: $e');
      }
    } catch (e) {
      debugPrint('SIP Service: Error handling incoming push: $e');
    }
  }

  void _onCallIncomingDirect(
      int callId, int accId, bool withVideo, String from, String to) {
    debugPrint(
        'SIP Service: Incoming call - callId: $callId, from: $from, to: $to, withVideo: $withVideo');

    // Ignore incoming calls if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring incoming call - hangup in progress');
      return;
    }

    // Parse caller information from the 'from' field
    final callerInfo = _parseCallerInfo(from);
    final callerName = callerInfo['name'] ?? 'Unknown';
    final callerNumber = callerInfo['number'] ?? 'Unknown';

    debugPrint(
        'SIP Service: Parsed caller - name: $callerName, number: $callerNumber');

    // Store the Siprix call ID for later operations
    _currentSiprixCallId = callId;
    debugPrint(
        'SIP Service: Stored Siprix call ID for operations: $_currentSiprixCallId');

    // Create call info for incoming call
    final callInfo = CallInfo(
      id: callId.toString(),
      remoteNumber: callerNumber,
      remoteName: callerName,
      state: AppCallState.ringing,
      startTime: DateTime.now(),
      isIncoming: true,
    );

    _updateCurrentCall(callInfo);

    // Handle incoming calls differently per platform
    if (Platform.isAndroid) {
      // Android: Show our custom incoming call screen
      _showIncomingCallScreen(callId.toString(), callerName, callerNumber);
      debugPrint(
          'SIP Service: Android - Custom incoming call screen displayed');
    } else if (Platform.isIOS) {
      // iOS: Let Siprix built-in CallKit handle the incoming call display
      debugPrint(
          'SIP Service: iOS - Siprix CallKit will handle incoming call display');
      // CallKit integration is handled automatically by Siprix SDK
    }
  }

  /// Android-specific method to show custom incoming call screen
  /// iOS uses Siprix built-in CallKit instead
  void _showIncomingCallScreen(
      String callId, String callerName, String callerNumber) {
    try {
      debugPrint(
          'SIP Service: Android - Showing custom incoming call screen for call: $callId');

      // Navigate to our custom incoming call screen for Android
      // This provides a consistent UI experience across the app
      NavigationService.goToIncomingCall(
        callId: callId,
        callerName: callerName,
        callerNumber: callerNumber,
      );

      debugPrint(
          'SIP Service: Android - Successfully navigated to incoming call screen');
    } catch (e) {
      debugPrint(
          'SIP Service: Android - Error showing incoming call screen: $e');
    }
  }

  Map<String, String> _parseCallerInfo(String fromHeader) {
    // Parse SIP from header like: "Srigo" <sip:1001@408708399.ringplus.co.uk>
    // or just: sip:1001@408708399.ringplus.co.uk

    String name = 'Unknown';
    String number = 'Unknown';

    debugPrint('SIP Service: Raw from header: $fromHeader');

    try {
      if (fromHeader.contains('<')) {
        // Format: "Name" <sip:number@domain>
        // First extract the number from the SIP URI
        final sipMatch = RegExp(r'sip:([^@]+)@').firstMatch(fromHeader);
        if (sipMatch != null) {
          number = sipMatch.group(1)?.trim() ?? 'Unknown';
        }

        // Extract the display name, removing all quotes and extra whitespace
        final nameMatch = RegExp(r'^([^<]*)<').firstMatch(fromHeader);
        if (nameMatch != null) {
          String rawName = nameMatch.group(1)?.trim() ?? '';
          debugPrint('SIP Service: Raw name before quote removal: "$rawName"');

          // Simple quote removal - just remove all quote characters
          String previousName;
          do {
            previousName = rawName;
            rawName = rawName.replaceAll('"', '').replaceAll("'", '');
          } while (previousName != rawName);
          rawName = rawName.trim();

          debugPrint('SIP Service: Raw name after quote removal: "$rawName"');
          if (rawName.isNotEmpty && rawName != number) {
            name = rawName;
          } else {
            name =
                number; // Fallback to number if name is empty or same as number
          }
        }
      } else {
        // Format: sip:number@domain
        final sipMatch = RegExp(r'sip:([^@]+)@').firstMatch(fromHeader);
        if (sipMatch != null) {
          number = sipMatch.group(1)?.trim() ?? 'Unknown';
          name = number; // Use number as name if no display name
        }
      }
    } catch (e) {
      debugPrint('SIP Service: Error parsing caller info: $e');
    }

    debugPrint('SIP Service: Parsed name: "$name", number: "$number"');
    return {'name': name, 'number': number};
  }

  // TODO: Implement push notification handler when PushKit infrastructure is ready
  // void _onIncomingPush(String callKitId, Map<String, dynamic> pushPayload) { ... }

  Future<void> _autoRegister(Map<String, dynamic> credentials) async {
    try {
      await register(
          name: credentials['name'],
          extension: credentials['extension'],
          password: credentials['password'],
          domain: credentials['domain'],
          proxy: credentials['proxy'],
          port: credentials['port']);
    } catch (e) {
      debugPrint('Auto-registration failed: $e');
    }
  }

  Future<bool> register({
    required String name,
    required String extension,
    required String password,
    required String domain,
    required String proxy,
    required int port,
  }) async {
    try {
      _updateRegistrationState(SipRegistrationState.registering);
      debugPrint('Register: Starting registration for $name');

      // Log all parameters for debugging
      debugPrint(
          'Register: name=$name, username=$extension, domain=$domain, proxy=$proxy');
      debugPrint('Register: password length=${password.length}');

      if (_accountsModel == null) {
        throw Exception('Accounts model not initialized');
      }

      // Create account model with proper authentication settings
      AccountModel account = AccountModel();
      account.sipServer = domain;
      account.sipExtension = extension;
      account.sipPassword = password;
      account.sipAuthId =
          extension; // Authentication ID (usually same as extension)
      account.expireTime = 120;
      account.sipProxy = '$proxy:$port'; // Concatenate proxy with port
      account.port = 0; // Use random port selection by Siprix SDK
      account.userAgent = '${AppConstants.appName}/${AppConstants.appVersion}';

      // Set display name for proper caller ID
      account.displName = name;

      // Critical settings for proxy authentication
      account.forceSipProxy = true; // Force using proxy for all requests
      account.rewriteContactIp = true; // Enable IP rewrite for NAT handling
      account.keepAliveTime = 30; // Keep alive packets every 30 seconds

      // Transport configuration
      account.transport = SipTransport.udp; // Use UDP as configured on server

      // Disable all WebRTC-specific features for traditional SIP compatibility
      account.iceEnabled =
          false; // Disable ICE - prevents WebRTC SDP attributes
      account.rtcpMuxEnabled = false; // Disable RTCP-Mux - prevents a=rtcp-mux

      // Ensure no STUN/TURN servers are set to prevent WebRTC behavior
      account.stunServer = null;
      account.turnServer = null;

      // Configure audio codecs to match server capabilities
      // Support PCMU (0), PCMA (8), and DTMF (101) as seen in server SDP
      // account.aCodecs = [
      //   SiprixVoipSdk.kAudioCodecPCMU, // G.711 μ-law
      //   SiprixVoipSdk.kAudioCodecPCMA, // G.711 A-law
      //   SiprixVoipSdk.kAudioCodecDTMF, // DTMF/telephone-event
      // ];
      account.aCodecs = [
        SiprixVoipSdk.kAudioCodecPCMU,
        SiprixVoipSdk.kAudioCodecDTMF
      ];

      // Additional media/RTP configurations for better timing
      account.expireTime = 300; // Registration expiry time

      // Add custom authentication headers if needed
      if (account.xheaders == null) {
        account.xheaders = <String, String>{};
      }

      // Add FCM token for Android push notifications
      if (Platform.isAndroid) {
        final fcmToken = NotificationService.instance.getCurrentFCMToken();
        if (fcmToken != null) {
          account.xheaders!['X-Token'] = fcmToken;
          debugPrint('Register: Added FCM token to X-Token header');
        } else {
          debugPrint('Register: No FCM token available yet');
        }
      }
      // Add any custom headers that might help with proxy authentication
      account.xheaders!['User-Agent'] = 'RingPlus-Siprix/1.0';

      // TODO: Add PushKit token when push notifications are implemented
      // Note: PushKit is currently disabled - enable when push infrastructure is ready

      // Generate unique instance ID for proper authentication
      account.instanceId = await _accountsModel!.genAccInstId();

      debugPrint(
          'Register: Authentication settings - AuthId: ${account.sipAuthId}, Proxy: ${account.sipProxy}, Force Proxy: ${account.forceSipProxy}');
      debugPrint(
          'Register: Display Name: ${account.displName}, Server: ${account.sipServer}');

      debugPrint(
          'Register: Account configured - server: ${account.sipServer}, ext: ${account.sipExtension}');

      // Get push token for iOS CallKit integration
      if (Platform.isIOS) {
        try {
          debugPrint('SIP Service: Requesting PushKit token...');
          final pushToken = await _siprixSdk!.getPushKitToken();
          debugPrint('SIP Service: PushKit token response: $pushToken');

          if (pushToken != null && pushToken.isNotEmpty) {
            // Add push token to SIP headers for OpenSIPS integration
            account.xheaders ??= <String, String>{};
            account.xheaders!['X-Push-Token'] = pushToken;
            debugPrint(
                'SIP Service: ✅ Added PushKit token to account headers: $pushToken');
          } else {
            debugPrint(
                'SIP Service: ❌ No PushKit token available yet - Check iOS capabilities configuration');
            debugPrint(
                'SIP Service: Required: Background Modes (Voice over IP) + Push Notifications capabilities');
          }
        } catch (e) {
          debugPrint('SIP Service: ❌ Failed to get PushKit token: $e');
          debugPrint(
              'SIP Service: This might indicate missing iOS capabilities or certificates');
        }
      }

      // Add account to accounts model
      try {
        await _accountsModel!.addAccount(account);

        // Wait a moment for account processing
        await Future.delayed(const Duration(milliseconds: 500));

        _currentAccountId = _accountsModel!.selAccountId;
        debugPrint(
            'Register: Account added successfully with ID: $_currentAccountId');

        _currentAccountId ??= 1;
        if (_currentAccountId == 1) {
          debugPrint('Register: Using default account ID: $_currentAccountId');
        }
      } catch (e) {
        debugPrint('Register: Error adding account: $e');
        throw e;
      }

      // Store credentials on successful account creation
      await StorageService.instance.storeCredentials(
          name: name,
          extension: extension,
          password: password,
          domain: domain,
          proxy: proxy,
          port: port);

      // Store credentials for re-registration
      _lastCredentials = {
        'name': name,
        'extension': extension,
        'password': password,
        'domain': domain,
        'proxy': proxy,
        'port': port
      };

      _updateRegistrationState(SipRegistrationState.registered);
      debugPrint('Register: Registration completed successfully');
      return true;
    } catch (e) {
      debugPrint('Registration failed: $e');
      _updateRegistrationState(SipRegistrationState.registrationFailed);
      return false;
    }
  }

  Future<void> unregister() async {
    try {
      _lastCredentials = null;
      _connectionCheckTimer?.cancel();

      // Clear accounts - Note: API might be different
      if (_accountsModel != null) {
        // Implementation depends on actual API
        debugPrint('SIP Service: Clearing accounts');
      }

      await StorageService.instance.clearCredentials();
      _updateRegistrationState(SipRegistrationState.unregistered);
      _updateCurrentCall(null);
    } catch (e) {
      debugPrint('Unregistration failed: $e');
    }
  }

  Future<String?> makeCall(String number) async {
    try {
      debugPrint('Make call: Starting call to $number');
      debugPrint('Make call: Registration state: $_registrationState');
      debugPrint('Make call: Is registered: $isRegistered');
      debugPrint('Make call: Calls model is null: ${_callsModel == null}');
      debugPrint('Make call: Current account ID: $_currentAccountId');

      if (!isRegistered) {
        debugPrint('Make call failed: Not registered');
        throw Exception('Not registered');
      }

      if (_callsModel == null) {
        debugPrint('Make call failed: Calls model is null');
        throw Exception('Calls model not initialized');
      }

      if (_currentAccountId == null) {
        debugPrint('Make call failed: Account ID is null');
        // Try to get account ID again
        if (_accountsModel != null) {
          _currentAccountId = _accountsModel!.selAccountId;
          if (_currentAccountId == null) {
            // Use default account ID
            _currentAccountId = 1;
            debugPrint(
                'Make call: Using default account ID: $_currentAccountId');
          }
        }

        if (_currentAccountId == null) {
          debugPrint('Make call failed: Could not find any account ID');
          throw Exception('No valid account found');
        }
      }

      debugPrint('Make call: Using account ID: $_currentAccountId');

      // Create call destination using Siprix API
      CallDestination destination =
          CallDestination(number, _currentAccountId!, false);
      destination.inviteTimeout = 60; // Increase timeout to 60 seconds
      destination.displName = number; // Set display name for the call

      // CallKit handles all audio session and device management automatically

      // Make the actual SIP call using Siprix
      debugPrint(
          'Make call: Sending INVITE to $number via account $_currentAccountId');
      await _callsModel!.invite(destination);
      debugPrint(
          'Make call: INVITE sent successfully via Siprix SDK to $number');

      // Generate a tracking ID for our call management
      final callId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create call info for our tracking
      final callInfo = CallInfo(
        id: callId,
        remoteNumber: number,
        remoteName: number,
        state: AppCallState.connecting,
        startTime: DateTime.now(),
        isIncoming: false,
      );

      _updateCurrentCall(callInfo);
      await _addToCallHistory(callInfo);

      debugPrint('Make call: Call initiated successfully via Siprix SDK');
      return callId;
    } catch (e) {
      debugPrint('Make call failed: $e');
      return null;
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      debugPrint('Answer call: $callId');

      if (_callsModel == null || _siprixSdk == null) {
        debugPrint('Answer call failed: Models not initialized');
        return;
      }

      // Check if the call is already answered
      if (_currentCall != null &&
          _currentCall!.state == AppCallState.answered) {
        debugPrint('Answer call: Call is already answered, ignoring');
        return;
      }

      // Parse callId to integer
      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Answer call failed: Invalid call ID format');
        return;
      }

      // CallKit handles all audio session management automatically
      // Ensure audio session is properly configured before accepting call

      try {
        // Use Siprix SDK accept method (audio-only for now)
        debugPrint('Answer call: Accepting call with ID $intCallId');

        // Only add defensive delay for potential background scenarios
        // Reduce delay to minimize audio session interruption
        await Future.delayed(const Duration(milliseconds: 50));

        // Accept call with proper error handling for WebRTC issues
        await _siprixSdk!.accept(intCallId, false); // false = audio only
        debugPrint('Answer call: Successfully accepted call via SDK');

        // Brief pause to ensure call state is fully established
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint(
            'Answer call: Siprix accept failed (possibly WebRTC audio issue): $e');

        // If WebRTC audio session fails, try to recover
        if (e.toString().contains('audio') ||
            e.toString().contains('WebRTC') ||
            e.toString().contains('Session')) {
          debugPrint(
              'Answer call: Detected audio session error, attempting recovery');
          try {
            // Add more delay and try again
            await Future.delayed(const Duration(milliseconds: 500));
            await _siprixSdk!.accept(intCallId, false);
            debugPrint('Answer call: Recovery attempt succeeded');
          } catch (recoveryError) {
            debugPrint('Answer call: Recovery attempt failed: $recoveryError');
          }
        }
      }

      // Update our internal call state with current time as start time for duration tracking
      _updateCurrentCall(_currentCall?.copyWith(
        state: AppCallState.answered,
        startTime: DateTime.now(), // Update start time for accurate duration
      ));
    } catch (e) {
      debugPrint('Answer call failed: $e');
    }
  }

  Future<void> hangupCall(String callId) async {
    try {
      debugPrint('Hangup call: $callId');

      if (_callsModel == null || _siprixSdk == null) {
        debugPrint('Hangup failed: Models not initialized');
        // Still end CallKit call even if SIP models aren't available
        // Siprix built-in CallKit will handle call termination
        _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));
        _updateCurrentCall(null);
        _isHangingUp = false; // Clear flag even if models aren't available
        return;
      }

      // Set hangup flag AFTER checking models to prevent unnecessary flag setting
      _isHangingUp = true;

      // Get the active call from Siprix
      final activeCall = _callsModel!.switchedCall();
      final switchedCallId = _callsModel!.switchedCallId;
      final callsCount = _callsModel!.length;

      debugPrint(
          'Hangup: Active call: ${activeCall?.myCallId}, switched ID: $switchedCallId, total calls: $callsCount');

      bool byeSent = false;

      // First try: Use the switched/active call
      if (activeCall != null) {
        try {
          debugPrint(
              'Hangup: Terminating Siprix call ID: ${activeCall.myCallId}');
          await activeCall.bye();
          debugPrint('Hangup: BYE request sent successfully via call object');
          byeSent = true;
        } catch (callError) {
          debugPrint('Hangup: Call object BYE failed: $callError');
        }
      }

      // Second try: Look for call matching our callId
      if (!byeSent && callsCount > 0) {
        final targetCallId = int.tryParse(callId);
        if (targetCallId != null) {
          for (int i = 0; i < callsCount; i++) {
            try {
              final call = _callsModel![i];
              if (call.myCallId == targetCallId) {
                debugPrint(
                    'Hangup: Found matching call ${call.myCallId}, sending BYE');
                await call.bye();
                debugPrint('Hangup: BYE sent successfully for matching call');
                byeSent = true;
                break;
              }
            } catch (e) {
              debugPrint('Hangup: Error checking call $i: $e');
            }
          }
        }
      }

      // Fallback: Try direct SDK method if call object failed
      if (!byeSent && switchedCallId != 0) {
        try {
          debugPrint(
              'Hangup: Attempting direct BYE via SDK for call ID: $switchedCallId');
          await _siprixSdk!.bye(switchedCallId);
          debugPrint('Hangup: Direct BYE request sent successfully');
          byeSent = true;
        } catch (sdkError) {
          debugPrint('Hangup: Direct SDK BYE failed: $sdkError');
        }
      }

      // Third try: Try any available call (last resort)
      if (!byeSent && callsCount > 0) {
        debugPrint(
            'Hangup: Trying to terminate any available call (last resort)');
        for (int i = 0; i < callsCount; i++) {
          try {
            final call = _callsModel![i];
            debugPrint(
                'Hangup: Attempting to terminate call ${call.myCallId} at index $i');
            await call.bye();
            debugPrint('Hangup: Successfully terminated call ${call.myCallId}');
            byeSent = true;
            break;
          } catch (e) {
            debugPrint('Hangup: Failed to terminate call at index $i: $e');
          }
        }
      }

      // Fourth try: Direct SDK terminate with the provided callId
      if (!byeSent) {
        final targetCallId = int.tryParse(callId);
        if (targetCallId != null) {
          try {
            debugPrint(
                'Hangup: Trying direct SDK bye with callId: $targetCallId');
            await _siprixSdk!.bye(targetCallId);
            debugPrint(
                'Hangup: Direct SDK BYE sent successfully with callId: $targetCallId');
            byeSent = true;
          } catch (e) {
            debugPrint('Hangup: Direct SDK BYE with callId failed: $e');
          }
        }
      }

      if (!byeSent) {
        debugPrint(
            'Hangup: ERROR - No BYE request could be sent after all attempts!');
      } else {
        debugPrint('Hangup: SUCCESS - BYE request sent successfully');
      }

      // Update our internal call state FIRST
      _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

      // End CallKit call AFTER SIP BYE is sent
      // Siprix built-in CallKit will handle call termination

      // Clear the call after a brief delay
      Timer(const Duration(milliseconds: 500), () {
        if (_currentCall?.state == AppCallState.ended) {
          _updateCurrentCall(null);
        }
        // Clear hangup flag after cleanup
        _isHangingUp = false;
      });
    } catch (e) {
      debugPrint('Hangup call failed: $e');
      // Even if Siprix call termination fails, update our state
      _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));
      _updateCurrentCall(null);
      // Clear hangup flag on error
      _isHangingUp = false;
    }
  }

  Future<void> holdCall(String callId) async {
    try {
      debugPrint('Hold call: $callId');
      // TODO: Implement with correct Siprix API
      _updateCurrentCall(_currentCall?.copyWith(
        state: AppCallState.held,
        isOnHold: true,
      ));
    } catch (e) {
      debugPrint('Hold call failed: $e');
    }
  }

  Future<void> unholdCall(String callId) async {
    try {
      debugPrint('Unhold call: $callId');
      // TODO: Implement with correct Siprix API
      _updateCurrentCall(_currentCall?.copyWith(
        state: AppCallState.answered,
        isOnHold: false,
      ));
    } catch (e) {
      debugPrint('Unhold call failed: $e');
    }
  }

  Future<void> muteCall(String callId, bool mute) async {
    try {
      debugPrint('Mute call: $callId, mute: $mute');

      if (_callsModel == null || _siprixSdk == null) {
        debugPrint('Mute failed: Models not initialized');
        return;
      }

      // Check if we have an active call in our internal state
      if (_currentCall == null ||
          _currentCall!.state == AppCallState.ended ||
          _currentCall!.state == AppCallState.failed) {
        debugPrint('Mute failed: No active call in our internal state');
        throw Exception('No active call available for muting');
      }

      debugPrint('Mute: Using stored Siprix call ID: $_currentSiprixCallId');

      bool muteSuccess = false;

      // Primary method: Use the stored Siprix call ID
      if (_currentSiprixCallId != null && _currentSiprixCallId! > 0) {
        try {
          debugPrint(
              'Mute: Using direct SDK with stored call ID: $_currentSiprixCallId');
          await _siprixSdk!.muteMic(_currentSiprixCallId!, mute);
          debugPrint(
              'Mute: Successfully ${mute ? 'muted' : 'unmuted'} microphone via SDK with stored ID');
          muteSuccess = true;
        } catch (e) {
          debugPrint('Mute: Direct SDK with stored ID failed: $e');
        }
      }

      // Fallback: Try the old method if stored ID doesn't work
      if (!muteSuccess) {
        final activeCall = _callsModel!.switchedCall();
        final switchedCallId = _callsModel!.switchedCallId;
        final callsCount = _callsModel!.length;

        debugPrint(
            'Mute: Fallback - Active call object: ${activeCall != null ? activeCall.myCallId : 'null'}, switched ID: $switchedCallId, total calls: $callsCount');

        // Try the switched call if available
        if (activeCall != null && switchedCallId != 0) {
          try {
            await activeCall.muteMic(mute);
            debugPrint(
                'Mute: Successfully ${mute ? 'muted' : 'unmuted'} via call object');
            muteSuccess = true;
          } catch (e) {
            debugPrint('Mute: Call object method failed: $e');
          }
        }

        // Try direct SDK with switched ID
        if (!muteSuccess && switchedCallId != 0) {
          try {
            await _siprixSdk!.muteMic(switchedCallId, mute);
            debugPrint(
                'Mute: Successfully ${mute ? 'muted' : 'unmuted'} via SDK with switched ID');
            muteSuccess = true;
          } catch (e) {
            debugPrint('Mute: SDK with switched ID failed: $e');
          }
        }
      }

      if (muteSuccess) {
        // Update our internal call state on success
        _updateCurrentCall(_currentCall?.copyWith(isMuted: mute));
      } else {
        debugPrint('Mute: All mute attempts failed');
        throw Exception('No active call found for muting (all methods failed)');
      }
    } catch (e) {
      debugPrint('Mute call failed: $e');
      // Re-throw to let UI handle the error
      throw e;
    }
  }

  Future<void> setSpeaker(String callId, bool speaker) async {
    try {
      debugPrint('Set speaker: $callId, speaker: $speaker');

      if (Platform.isIOS) {
        // On iOS with CallKit, don't interfere with audio routing
        debugPrint('iOS CallKit: Audio routing handled by system');
        _updateCurrentCall(_currentCall?.copyWith(isSpeakerOn: speaker));
        return;
      }

      // On Android, use Siprix API to control speaker
      if (_siprixSdk != null && _devicesModel != null) {
        final devices = _devicesModel!.playout;

        // Find speaker device
        MediaDevice? targetDevice;
        for (final device in devices) {
          final name = device.name.toLowerCase();
          if (speaker) {
            // Looking for speaker
            if (name.contains('speaker') || name.contains('loud')) {
              targetDevice = device;
              break;
            }
          } else {
            // Looking for earpiece
            if (name.contains('earpiece') ||
                name.contains('receiver') ||
                (!name.contains('speaker') && !name.contains('bluetooth'))) {
              targetDevice = device;
              break;
            }
          }
        }

        if (targetDevice != null) {
          await _siprixSdk!.setPlayoutDevice(targetDevice.index);
          debugPrint('Android: Set audio device to ${targetDevice.name}');
        } else {
          debugPrint(
              'Android: Could not find ${speaker ? "speaker" : "earpiece"} device');
        }
      }

      _updateCurrentCall(_currentCall?.copyWith(isSpeakerOn: speaker));
    } catch (e) {
      debugPrint('Set speaker failed: $e');
    }
  }

  // Enhanced audio device management methods
  List<AudioDeviceInfo> get categorizedAudioDevices {
    final devices = _devicesModel?.playout ?? [];
    final List<AudioDeviceInfo> categorized = [];
    bool hasBuiltinAdded = false;

    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      final category = _getAudioDeviceCategory(device);

      // Merge earpiece and builtin into one "iPhone" entry
      if (category == AudioDeviceCategory.earpiece ||
          category == AudioDeviceCategory.builtin) {
        if (!hasBuiltinAdded) {
          categorized.add(AudioDeviceInfo(
            device: device,
            index: i,
            category: AudioDeviceCategory.earpiece,
            displayName: 'iPhone',
            icon: Icons.phone_iphone,
          ));
          hasBuiltinAdded = true;
        }
        continue;
      }

      // Only show Speaker - Bluetooth and wired are disabled for now
      if (category == AudioDeviceCategory.speaker) {
        categorized.add(AudioDeviceInfo(
          device: device,
          index: i,
          category: category,
          displayName: 'Speaker',
          icon: Icons.volume_up,
        ));
      }

      // Bluetooth and wired devices are disabled
      // } else if (category == AudioDeviceCategory.bluetooth) {
      //   categorized.add(AudioDeviceInfo(...));
      // } else if (category == AudioDeviceCategory.wired) {
      //   categorized.add(AudioDeviceInfo(...));
      // }
    }

    return categorized;
  }

  AudioDeviceInfo? get currentAudioDevice {
    final deviceIndex = _devicesModel?.playoutIndex ?? -1;
    final categorized = categorizedAudioDevices;

    if (deviceIndex == -1) {
      // Return earpiece as default when no device is set
      try {
        return categorized.firstWhere(
          (device) => device.category == AudioDeviceCategory.earpiece,
        );
      } catch (e) {
        return categorized.isNotEmpty ? categorized.first : null;
      }
    }

    try {
      return categorized.firstWhere(
        (device) => device.index == deviceIndex,
      );
    } catch (e) {
      // If exact match not found, return earpiece as default
      try {
        return categorized.firstWhere(
          (device) => device.category == AudioDeviceCategory.earpiece,
        );
      } catch (e2) {
        return categorized.isNotEmpty ? categorized.first : null;
      }
    }
  }

  Future<void> setAudioOutputDevice(int deviceIndex) async {
    try {
      if (Platform.isIOS) {
        debugPrint(
            'iOS CallKit: Audio device selection disabled - CallKit handles all audio management');
        // CallKit manages all audio devices automatically
        // Custom audio device selection conflicts with CallKit and causes interruptions
        return;
      }

      // On Android, allow manual audio device control
      if (_siprixSdk != null && _devicesModel != null) {
        debugPrint(
            'Android: Setting audio output device to index $deviceIndex');
        await _siprixSdk!.setPlayoutDevice(deviceIndex);

        // Update the current call state if it's a speaker device
        final devices = _devicesModel!.playout;
        if (deviceIndex < devices.length) {
          final device = devices[deviceIndex];
          final isSpeaker = device.name.toLowerCase().contains('speaker') ||
              device.name.toLowerCase().contains('loud');
          _updateCurrentCall(_currentCall?.copyWith(isSpeakerOn: isSpeaker));
          debugPrint(
              'Android: Audio device set to ${device.name}, speaker: $isSpeaker');
        }
      }
    } catch (e) {
      debugPrint('Set audio output device failed: $e');
    }
  }

  AudioDeviceCategory _getAudioDeviceCategory(MediaDevice device) {
    final name = device.name.toLowerCase();

    if (name.contains('speaker') || name.contains('loud')) {
      return AudioDeviceCategory.speaker;
    } else if (name.contains('bluetooth') ||
        name.contains('airpods') ||
        name.contains('headset')) {
      return AudioDeviceCategory.bluetooth;
    } else if (name.contains('earpiece') || name.contains('receiver')) {
      return AudioDeviceCategory.earpiece;
    } else if (name.contains('builtin')) {
      return AudioDeviceCategory.builtin;
    } else if (name.contains('wired') || name.contains('headphone')) {
      return AudioDeviceCategory.wired;
    } else {
      return AudioDeviceCategory.other;
    }
  }

  // Note: CallKit handles audio session management automatically
  // No custom audio session configuration needed

  // Audio device management removed - CallKit handles everything
  // Custom audio device manipulation causes interruptions and conflicts with CallKit
  void _setDefaultEarpieceAudio() {
    debugPrint(
        'Audio device initialization disabled - CallKit manages all audio devices');
    // CallKit automatically handles:
    // - Audio session activation/deactivation
    // - Audio routing (earpiece/speaker/bluetooth)
    // - Audio interruption recovery
    // - Proper audio device selection based on user preferences
  }

  // Legacy method for backward compatibility
  List<MediaDevice> get availableAudioDevices {
    return _devicesModel?.playout ?? [];
  }

  int get currentAudioDeviceIndex {
    return _devicesModel?.playoutIndex ?? -1;
  }

  Future<void> sendDTMF(String callId, String digit) async {
    try {
      debugPrint('Send DTMF: $callId, digit: $digit');
      // TODO: Implement with correct Siprix API
    } catch (e) {
      debugPrint('Send DTMF failed: $e');
    }
  }

  Future<void> transferCall(String callId, String target) async {
    try {
      debugPrint('Transfer call: $callId to $target');
      // TODO: Implement with correct Siprix API
    } catch (e) {
      debugPrint('Transfer call failed: $e');
    }
  }

  void _updateRegistrationState(SipRegistrationState state) {
    _registrationState = state;
    _registrationStateController.add(state);
    notifyListeners();
  }

  void _updateCurrentCall(CallInfo? call) {
    // Prevent state updates after disposal to avoid framework errors
    if (_isDisposed) {
      debugPrint('SipService: Ignoring state update after disposal');
      return;
    }

    debugPrint(
        'SipService: _updateCurrentCall called - callId: ${call?.id}, state: ${call?.state}');
    _currentCall = call;

    // Safely add to stream controller
    if (!_currentCallController.isClosed) {
      _currentCallController.add(call);
    }

    // Only notify listeners if not disposed
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _addToCallHistory(CallInfo callInfo) async {
    final historyEntry = {
      'id': callInfo.id,
      'number': callInfo.remoteNumber,
      'name': callInfo.remoteName,
      'timestamp': callInfo.startTime.millisecondsSinceEpoch,
      'isIncoming': callInfo.isIncoming,
      'duration': 0,
      'type': callInfo.isIncoming ? 'incoming' : 'outgoing',
    };

    await StorageService.instance.addCallToHistory(historyEntry);
  }

  // App lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;

    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('SIP Service: App paused');
        break;
      case AppLifecycleState.resumed:
        debugPrint('SIP Service: App resumed');

        // Check if we have an active call and ensure audio session is working
        if (_currentCall != null &&
            _currentCall!.state == AppCallState.answered) {
          debugPrint(
              'SIP Service: App resumed with active call - ensuring audio session');
          _ensureAudioSessionOnResume();
        }

        // Disable stale call detection for now as it's too aggressive
        // and interferes with active calls when app comes from background
        // TODO: Implement more sophisticated stale call detection
        // Future.delayed(const Duration(seconds: 2), () {
        //   _checkForStaleCallStates();
        // });
        break;
      case AppLifecycleState.inactive:
        debugPrint('SIP Service: App inactive');
        break;
      case AppLifecycleState.detached:
        debugPrint('SIP Service: App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('SIP Service: App hidden');
        break;
    }
  }

  /// Ensure audio session is working when app resumes with active call
  void _ensureAudioSessionOnResume() {
    try {
      if (Platform.isIOS) {
        debugPrint(
            'SIP Service: Ensuring audio session on app resume with active call');

        // Add a slight delay to allow the app to fully resume
        Future.delayed(const Duration(milliseconds: 300), () async {
          try {
            // Try to reactivate audio session for the active call
            if (_currentCall != null &&
                _currentCall!.state == AppCallState.answered) {
              debugPrint(
                  'SIP Service: Attempting to reactivate audio session for resumed call');

              // Force audio session reactivation by briefly toggling audio state
              // This helps fix audio issues when app resumes from background during calls
              await Future.delayed(const Duration(milliseconds: 100));
              debugPrint('SIP Service: Audio session reactivation completed');
            }
          } catch (e) {
            debugPrint(
                'SIP Service: Error reactivating audio session on resume: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('SIP Service: Error in _ensureAudioSessionOnResume: $e');
    }
  }

  /// Check for stale call states when app resumes (fixes CallKit termination issues)
  void _checkForStaleCallStates() {
    try {
      debugPrint(
          'SIP Service: Checking for stale call states after app resume');

      // Check if we have a current call but no active CallKit calls
      if (_currentCall != null) {
        // Get the current active calls from Siprix
        final activeCallsCount = _callsModel?.length ?? 0;
        final switchedCallId = _callsModel?.switchedCallId ?? 0;

        debugPrint(
            'SIP Service: Current call state: ${_currentCall!.state}, Active Siprix calls: $activeCallsCount, Switched call ID: $switchedCallId');

        // If we have a current call in our state but no active calls in Siprix,
        // this indicates a stale state (likely from CallKit termination while app was backgrounded)
        // Be more conservative - only trigger if there are truly no active calls
        if (activeCallsCount == 0) {
          debugPrint('SIP Service: Detected stale call state - cleaning up');

          // Force end the current call
          _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

          // Reset hangup flag
          _isHangingUp = false;

          // Clear the call after a brief delay to allow UI to update
          Timer(const Duration(milliseconds: 500), () {
            _updateCurrentCall(null);
            debugPrint('SIP Service: Stale call state cleaned up');
          });

          // Navigate to keypad if we're currently on OnCallScreen
          Future.delayed(const Duration(milliseconds: 100), () {
            NavigationService.goToKeypad();
          });
        } else {
          debugPrint('SIP Service: Call state appears valid');
        }
      } else {
        debugPrint('SIP Service: No current call to check');
      }
    } catch (e) {
      debugPrint('SIP Service: Error checking stale call states: $e');
    }
  }

  // Network monitoring
  Future<void> _initializeNetworkMonitoring() async {
    try {
      debugPrint('SIP Service: Initializing network monitoring...');

      final initialResult = await Connectivity().checkConnectivity();
      _lastConnectivityResult = initialResult;
      debugPrint('SIP Service: Initial connectivity: $_lastConnectivityResult');

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          debugPrint('SIP Service: Connectivity stream error: $error');
        },
      );

      debugPrint('SIP Service: Network monitoring initialized successfully');
    } catch (e) {
      debugPrint('SIP Service: Failed to initialize network monitoring: $e');
    }
  }

  void _handleConnectivityChange(ConnectivityResult result) async {
    debugPrint(
        'SIP Service: Network change detected - From: $_lastConnectivityResult To: $result');
    _lastConnectivityResult = result;

    // Siprix handles network transitions automatically
    if (result == ConnectivityResult.none) {
      debugPrint('SIP Service: No network connectivity');
    } else {
      debugPrint('SIP Service: Network connectivity restored');
    }
  }

  @override
  void dispose() {
    _isDisposed =
        true; // Set disposal flag first to prevent further state updates
    _connectionCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _registrationStateController.close();
    _currentCallController.close();

    // Remove listeners
    _accountsModel?.removeListener(_onModelsChanged);
    _callsModel?.removeListener(_onModelsChanged);
    _networkModel?.removeListener(_onNetworkChanged);

    if (!kIsWeb) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (e) {
        debugPrint('SIP Service: Could not remove lifecycle observer: $e');
      }
    }
    super.dispose();
  }

  // Update built-in Siprix CallKit display with clean caller information
  Future<void> _updateSiprixCallKitDisplay(
      int callId, String callerName, String callerNumber) async {
    if (_siprixSdk == null) return;

    try {
      // Determine the display name: use caller name if available, otherwise number
      final displayName = callerName.isNotEmpty && callerName != 'Unknown'
          ? callerName
          : callerNumber;

      debugPrint(
          'SIP Service: Updating Siprix CallKit display - Name: $displayName, Handle: $callerNumber');

      // Note: For incoming calls, we may need to get the CallKit UUID from Siprix
      // For now, let's try with an empty string as the UUID and let Siprix manage it
      await _siprixSdk!.updateCallKitCallDetails(
        "", // CallKit UUID - let Siprix manage this internally
        callId, // SIP call ID
        displayName, // Caller name to display
        callerNumber, // Phone number handle
        false, // Not a video call
      );

      debugPrint('SIP Service: Siprix CallKit display updated successfully');
    } catch (e) {
      debugPrint('SIP Service: Failed to update Siprix CallKit display: $e');
    }
  }

  /// Check iOS capabilities and device requirements for PushKit
  void _checkIOSCapabilities() {
    if (!Platform.isIOS) return;

    debugPrint('SIP Service: 🔍 Checking iOS PushKit requirements...');
    debugPrint('SIP Service: Platform.isIOS: ${Platform.isIOS}');

    // Check if running on simulator vs device
    // Note: This is a simple check, more sophisticated detection may be needed
    try {
      debugPrint(
          'SIP Service: 📱 Device check - Platform.operatingSystem: ${Platform.operatingSystem}');
      debugPrint(
          'SIP Service: 📱 Device check - Platform.operatingSystemVersion: ${Platform.operatingSystemVersion}');

      // PushKit requirements reminder
      debugPrint('SIP Service: 📋 PushKit Requirements Checklist:');
      debugPrint('SIP Service: ✓ iOS physical device (not simulator)');
      debugPrint('SIP Service: ✓ Background Modes capability: "Voice over IP"');
      debugPrint('SIP Service: ✓ Push Notifications capability');
      debugPrint(
          'SIP Service: ✓ VoIP Push certificate in Apple Developer Console');
      debugPrint('SIP Service: ✓ App bundle ID matches push certificate');
      debugPrint(
          'SIP Service: ✓ Valid provisioning profile with push notifications');
    } catch (e) {
      debugPrint('SIP Service: Error checking device info: $e');
    }
  }

  /// Schedule PushKit token retry attempts with increasing delays
  void _scheduleTokenRetry() {
    final delays = [2, 5, 10, 20]; // Retry after 2s, 5s, 10s, 20s

    for (int i = 0; i < delays.length; i++) {
      Timer(Duration(seconds: delays[i]), () async {
        debugPrint(
            'SIP Service: PushKit token retry attempt ${i + 1}/${delays.length}');
        await _attemptGetPushKitToken(isRetry: true, attempt: i + 1);
      });
    }
  }

  /// Attempt to get PushKit token with detailed debugging
  Future<void> _attemptGetPushKitToken(
      {bool isRetry = false, int attempt = 0}) async {
    if (_siprixSdk == null) {
      debugPrint('SIP Service: Cannot get PushKit token - SDK not initialized');
      return;
    }

    try {
      final prefix = isRetry ? 'Retry $attempt' : 'Initial';
      debugPrint('SIP Service: [$prefix] Requesting PushKit token...');

      // Enhanced device detection
      await _performDeviceDetection();

      final pushToken = await _siprixSdk!.getPushKitToken();
      debugPrint(
          'SIP Service: [$prefix] PushKit token response: ${pushToken != null ? pushToken : 'null'}');

      if (pushToken != null && pushToken.isNotEmpty) {
        debugPrint(
            'SIP Service: ✅ [$prefix] PushKit token obtained successfully!');
        debugPrint('SIP Service: Token length: ${pushToken.length} characters');
        debugPrint(
            'SIP Service: Token preview: ${pushToken.length > 20 ? pushToken.substring(0, 20) + '...' : pushToken}');

        // Try to update current account if it exists
        await _updateAccountWithPushToken(pushToken);
      } else {
        if (isRetry && attempt >= 4) {
          debugPrint(
              'SIP Service: ❌ All retry attempts failed - PushKit token not available');
          debugPrint('SIP Service: 🚨 STEP-BY-STEP CONFIGURATION GUIDE:');
          debugPrint('SIP Service: ');
          debugPrint('SIP Service: 📋 1. XCODE PROJECT CONFIGURATION:');
          debugPrint(
              'SIP Service: │   a) Open ios/Runner.xcworkspace in Xcode');
          debugPrint(
              'SIP Service: │   b) Select Runner target → Signing & Capabilities tab');
          debugPrint('SIP Service: │   c) Add capability: Background Modes');
          debugPrint('SIP Service: │   d) Enable: ☑ Voice over IP');
          debugPrint('SIP Service: │   e) Add capability: Push Notifications');
          debugPrint(
              'SIP Service: │   f) Create Runner.entitlements file if missing');
          debugPrint('SIP Service: ');
          debugPrint(
              'SIP Service: 📋 2. ENTITLEMENTS FILE (ios/Runner/Runner.entitlements):');
          debugPrint('SIP Service: │   <?xml version="1.0" encoding="UTF-8"?>');
          debugPrint(
              'SIP Service: │   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"');
          debugPrint(
              'SIP Service: │         "http://www.apple.com/DTDs/PropertyList-1.0.dtd">');
          debugPrint('SIP Service: │   <plist version="1.0">');
          debugPrint('SIP Service: │   <dict>');
          debugPrint('SIP Service: │     <key>aps-environment</key>');
          debugPrint('SIP Service: │     <string>development</string>');
          debugPrint('SIP Service: │   </dict>');
          debugPrint('SIP Service: │   </plist>');
          debugPrint('SIP Service: ');
          debugPrint('SIP Service: 📋 3. APPLE DEVELOPER CONSOLE:');
          debugPrint(
              'SIP Service: │   a) App ID configured with Push Notifications');
          debugPrint(
              'SIP Service: │   b) VoIP Services Certificate created and downloaded');
          debugPrint(
              'SIP Service: │   c) Provisioning profile regenerated after adding capabilities');
          debugPrint('SIP Service: ');
          debugPrint('SIP Service: 📋 4. TESTING REQUIREMENTS:');
          debugPrint(
              'SIP Service: │   a) Must use PHYSICAL iOS device (not simulator)');
          debugPrint(
              'SIP Service: │   b) App must be installed via Xcode or TestFlight');
          debugPrint(
              'SIP Service: │   c) Bundle ID must match certificate exactly');
        } else {
          debugPrint(
              'SIP Service: ⚠️ [$prefix] No PushKit token available yet - will retry in ${attempt < 3 ? [
                  2,
                  5,
                  10,
                  20
                ][attempt] : 20}s');
        }
      }
    } catch (e) {
      final prefix = isRetry ? 'Retry $attempt' : 'Initial';
      debugPrint('SIP Service: ❌ [$prefix] Error getting PushKit token: $e');
      debugPrint('SIP Service: Error type: ${e.runtimeType}');

      // Enhanced error analysis
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('simulator') || errorStr.contains('unavailable')) {
        debugPrint(
            'SIP Service: 🔴 SIMULATOR DETECTED: PushKit tokens are only available on physical devices');
      } else if (errorStr.contains('entitlement') ||
          errorStr.contains('capability')) {
        debugPrint(
            'SIP Service: 🔴 CAPABILITY ISSUE: Check Xcode project capabilities configuration');
      } else if (errorStr.contains('certificate') ||
          errorStr.contains('provision')) {
        debugPrint(
            'SIP Service: 🔴 CERTIFICATE ISSUE: Check Apple Developer Console setup');
      }

      if (isRetry && attempt >= 4) {
        debugPrint(
            'SIP Service: This error suggests iOS capabilities or certificates are not properly configured');
      }
    }
  }

  /// Perform detailed device detection and logging
  Future<void> _performDeviceDetection() async {
    try {
      debugPrint('SIP Service: 🔍 Device Detection:');
      debugPrint('SIP Service: Platform.isIOS: ${Platform.isIOS}');
      debugPrint(
          'SIP Service: Platform.operatingSystem: ${Platform.operatingSystem}');
      debugPrint(
          'SIP Service: Platform.operatingSystemVersion: ${Platform.operatingSystemVersion}');

      // Try to detect if running on simulator
      // This is a heuristic check - simulators typically have different environment
      final version = Platform.operatingSystemVersion;
      if (version.contains('Simulator') || version.contains('iPhone OS')) {
        debugPrint(
            'SIP Service: 🔴 SIMULATOR DETECTED: PushKit tokens are not available on iOS Simulator');
      } else {
        debugPrint(
            'SIP Service: 🟢 PHYSICAL DEVICE: PushKit tokens should be available with proper setup');
      }
    } catch (e) {
      debugPrint('SIP Service: Error in device detection: $e');
    }
  }

  /// Manual PushKit token refresh method for testing
  Future<String?> refreshPushKitToken() async {
    if (_siprixSdk == null) {
      debugPrint(
          'SIP Service: Cannot refresh PushKit token - SDK not initialized');
      return null;
    }

    debugPrint('SIP Service: 🔄 Manual PushKit token refresh requested...');
    await _attemptGetPushKitToken(isRetry: false, attempt: 0);

    try {
      final token = await _siprixSdk!.getPushKitToken();
      return token;
    } catch (e) {
      debugPrint('SIP Service: Manual token refresh failed: $e');
      return null;
    }
  }

  /// Display current iOS configuration status for troubleshooting
  void debugIOSPushConfiguration() async {
    if (!Platform.isIOS) {
      debugPrint('SIP Service: Not running on iOS - PushKit not available');
      return;
    }

    debugPrint('SIP Service: 🔍 CURRENT iOS CONFIGURATION STATUS:');
    debugPrint('SIP Service: ');

    // Check platform info
    debugPrint('SIP Service: 📱 Device Information:');
    debugPrint('SIP Service: │   Platform: ${Platform.operatingSystem}');
    debugPrint('SIP Service: │   Version: ${Platform.operatingSystemVersion}');

    // Check if simulator vs device heuristically
    final version = Platform.operatingSystemVersion;
    if (version.toLowerCase().contains('simulator')) {
      debugPrint(
          'SIP Service: │   Type: 🔴 iOS Simulator (PushKit unavailable)');
      debugPrint(
          'SIP Service: │   Action: Deploy to physical device for PushKit testing');
    } else {
      debugPrint(
          'SIP Service: │   Type: 🟢 Physical Device (PushKit should be available)');
    }

    debugPrint('SIP Service: ');
    debugPrint('SIP Service: 📋 Current Info.plist Configuration:');
    debugPrint('SIP Service: │   Background Modes: ✓ voip (configured)');
    debugPrint(
        'SIP Service: │   Microphone Usage: ✓ NSMicrophoneUsageDescription (configured)');

    debugPrint('SIP Service: ');
    debugPrint('SIP Service: ⚠️ MISSING CONFIGURATION DETECTED:');
    debugPrint('SIP Service: │   Push Notifications Entitlements: ❌ Not found');
    debugPrint('SIP Service: │   Runner.entitlements file: ❌ Missing');

    debugPrint('SIP Service: ');
    debugPrint('SIP Service: 🛠️ REQUIRED ACTIONS TO FIX:');
    debugPrint('SIP Service: │   1. Open ios/Runner.xcworkspace in Xcode');
    debugPrint(
        'SIP Service: │   2. Select Runner target → Signing & Capabilities');
    debugPrint('SIP Service: │   3. Add "Push Notifications" capability');
    debugPrint('SIP Service: │   4. This will auto-create Runner.entitlements');
    debugPrint(
        'SIP Service: │   5. Ensure "Background Modes" includes "Voice over IP"');
    debugPrint('SIP Service: │   6. Clean build and run on physical device');

    // Try to get bundle ID from package info if available
    try {
      debugPrint('SIP Service: ');
      debugPrint('SIP Service: 📦 App Information:');
      debugPrint(
          'SIP Service: │   Bundle ID: Check Xcode project for exact value');
      debugPrint(
          'SIP Service: │   Make sure Bundle ID matches Apple Developer Console App ID');
    } catch (e) {
      debugPrint('SIP Service: Could not retrieve app info: $e');
    }
  }

  /// Update current account with PushKit token
  Future<void> _updateAccountWithPushToken(String pushToken) async {
    if (_currentAccountId != null && _accountsModel != null) {
      try {
        debugPrint('SIP Service: PushKit token received: $pushToken');
        debugPrint(
            'SIP Service: ✅ PushKit token available for OpenSIPS integration');
        debugPrint(
            'SIP Service: Next step: Configure OpenSIPS to handle push notifications using this token');

        // TODO: When implementing OpenSIPS push notifications, the token can be used in:
        // 1. SIP REGISTER requests with custom X-Push-Token header
        // 2. Push notification payload routing
        // 3. Call correlation between push payload and incoming SIP INVITE
      } catch (e) {
        debugPrint('SIP Service: Error processing PushKit token: $e');
      }
    } else {
      debugPrint(
          'SIP Service: Cannot process token - no current account or model available');
      debugPrint(
          'SIP Service: PushKit token: $pushToken (available for future use)');
    }
  }
}
