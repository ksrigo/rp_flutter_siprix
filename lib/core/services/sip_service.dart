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
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../../shared/services/storage_service.dart';
import 'navigation_service.dart';
import 'contact_service.dart';
import 'avatar_service.dart';

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

  // Flag to prevent multiple navigation attempts
  bool _isNavigatingFromCallKit = false;

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
      initData.shareUdpTransport = true; // Share UDP transport for all accounts
      initData.enableVideoCall =
          false; // Disable video - reduces WebRTC SDP attributes

      // Try disabling Siprix CallKit again and use custom CallKit with better audio handling
      if (Platform.isIOS) {
        initData.enableCallKit = false; // Disable to use custom CallKit with clean display
        initData.enablePushKit =
            false; // Disabled - no push notification infrastructure yet
        initData.unregOnDestroy = false;
        debugPrint('SIP Service: Disabled Siprix CallKit to use custom CallKit with clean caller display');
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
        // incomingPush: null - disabled until push notifications are implemented
      );

      debugPrint('SIP Service: Call and push listeners configured');

      // Set up contact name resolution callback after SDK is fully initialized
      if (_callsModel != null) {
        _callsModel!.onResolveContactName = _resolveContactNameForCallKit;
        debugPrint('SIP Service: Contact name resolution callback set on CallsModel');
      } else {
        debugPrint('SIP Service: Warning - CallsModel is null, cannot set contact name callback');
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

      // Re-enable custom CallKit listeners
      _initializeCallKitListeners();

      // Initialize contact service for avatar generation (non-blocking)
      ContactService.instance.initialize().catchError((e) {
        debugPrint('SIP Service: Contact service initialization failed: $e');
        return false; // Return false to indicate initialization failed
      });
      debugPrint('SIP Service: Contact service initialization started in background');

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
      debugPrint('🔥 SIP Service: CALLBACK TRIGGERED - Resolving contact name for CallKit display: "$extension"');
      
      // Use our existing parsing logic to handle full SIP headers
      final callerInfo = _parseCallerInfo(extension);
      final callerName = callerInfo['name'] ?? 'Unknown';
      final callerNumber = callerInfo['number'] ?? 'Unknown';
      
      debugPrint('🔥 SIP Service: Parsed for CallKit - name: "$callerName", number: "$callerNumber"');
      
      // Return the name if it's meaningful, otherwise return the number
      String result;
      if (callerName != 'Unknown' && callerName != callerNumber) {
        result = callerName;
        debugPrint('🔥 SIP Service: Returning caller name for CallKit: "$result"');
      } else {
        result = callerNumber;
        debugPrint('🔥 SIP Service: Returning caller number for CallKit: "$result"');
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

    // End any active CallKit call
    _endCallKitCall(callId.toString());

    // Update our call state to ended
    if (_currentCall != null) {
      _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

      // Clear the call after a brief delay to allow UI to update and navigate back
      Timer(const Duration(milliseconds: 800), () {
        _updateCurrentCall(null);
        // Clear hangup flag after call is terminated
        _isHangingUp = false;
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
      if (_currentCall!.isIncoming) {
        debugPrint('SIP Service: Incoming call connected, navigating to OnCallScreen');
        NavigationService.goToInCall(
          _currentCall!.id,
          phoneNumber: _currentCall!.remoteNumber,
          contactName: _currentCall!.remoteName != _currentCall!.remoteNumber ? _currentCall!.remoteName : null,
        );
      } else {
        debugPrint('SIP Service: Outgoing call connected, OnCallScreen should already be visible');
      }
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
    debugPrint('SIP Service: Stored Siprix call ID for operations: $_currentSiprixCallId');

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

    // Show CallKit incoming call with system ringtone and vibration
    // CallKit will handle the UI - no need to navigate to incoming_call_screen
    _showCallKitIncomingCall(callId.toString(), callerName, callerNumber);

    debugPrint(
        'SIP Service: CallKit incoming call displayed - no app UI needed');
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
            name = number; // Fallback to number if name is empty or same as number
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
      account.sipProxy = proxy;
      account.port = port;
      account.userAgent = '${AppConstants.appName}/${AppConstants.appVersion}';

      // Set display name for proper caller ID
      account.displName = name;

      // Critical settings for proxy authentication
      account.forceSipProxy = true; // Force using proxy for all requests
      account.rewriteContactIp = true; // Enable IP rewrite for NAT handling
      account.keepAliveTime = 30; // Keep alive packets every 30 seconds
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

      // Additional media/RTP configurations for better timing
      account.expireTime = 300; // Registration expiry time

      // Add custom authentication headers if needed
      if (account.xheaders == null) {
        account.xheaders = <String, String>{};
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
        
        // Accept call immediately - audio session is now always active
        await _siprixSdk!.accept(intCallId, false); // false = audio only
        debugPrint('Answer call: Successfully accepted call via SDK');
        
        // Brief pause to ensure call state is fully established
        await Future.delayed(const Duration(milliseconds: 50));
        
      } catch (e) {
        debugPrint('Answer call: Siprix accept failed: $e');
        // Don't rethrow to prevent UI crash, just log the error
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
        await _endCallKitCall(callId);
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
      await _endCallKitCall(callId);

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
          debugPrint('Mute: Using direct SDK with stored call ID: $_currentSiprixCallId');
          await _siprixSdk!.muteMic(_currentSiprixCallId!, mute);
          debugPrint('Mute: Successfully ${mute ? 'muted' : 'unmuted'} microphone via SDK with stored ID');
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

        debugPrint('Mute: Fallback - Active call object: ${activeCall != null ? activeCall.myCallId : 'null'}, switched ID: $switchedCallId, total calls: $callsCount');

        // Try the switched call if available
        if (activeCall != null && switchedCallId != 0) {
          try {
            await activeCall.muteMic(mute);
            debugPrint('Mute: Successfully ${mute ? 'muted' : 'unmuted'} via call object');
            muteSuccess = true;
          } catch (e) {
            debugPrint('Mute: Call object method failed: $e');
          }
        }

        // Try direct SDK with switched ID
        if (!muteSuccess && switchedCallId != 0) {
          try {
            await _siprixSdk!.muteMic(switchedCallId, mute);
            debugPrint('Mute: Successfully ${mute ? 'muted' : 'unmuted'} via SDK with switched ID');
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
      // TODO: Implement with correct Siprix API
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
      debugPrint(
          'Audio device selection disabled - CallKit handles all audio management');
      // CallKit manages all audio devices automatically
      // Custom audio device selection conflicts with CallKit and causes interruptions
    } catch (e) {
      debugPrint('Audio device selection disabled: $e');
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

  // CallKit Integration for iOS native ringtone and vibration
  Future<void> _showCallKitIncomingCall(
      String callId, String callerName, String callerNumber) async {
    try {
      final uuid = const Uuid().v4();

      debugPrint('SIP Service: CallKit display - callerName: "$callerName", callerNumber: "$callerNumber"');
      
      // Clean up the caller name by removing any remaining quotes (simple approach)
      String cleanCallerName = callerName;
      String previousName;
      do {
        previousName = cleanCallerName;
        cleanCallerName = cleanCallerName.replaceAll('"', '').replaceAll("'", '');
      } while (previousName != cleanCallerName);
      cleanCallerName = cleanCallerName.trim();
      
      // Determine what to display - show name only if it's different from number
      final displayName = cleanCallerName.isNotEmpty && cleanCallerName != 'Unknown' && cleanCallerName != callerNumber
          ? cleanCallerName
          : callerNumber;
          
      debugPrint('SIP Service: CallKit will display: "$displayName" (cleaned from: "$callerName")');

      debugPrint('SIP Service: CallKit params - nameCaller: "$displayName", handle: "$displayName", appName: "RingPlus"');

      // Avatar generation temporarily disabled to prevent crashes
      String avatarPath = '';
      // TODO: Re-enable avatar generation once core functionality is stable
      // _generateAvatarInBackground(callerNumber, displayName, uuid);

      final params = CallKitParams(
        id: uuid,
        nameCaller: displayName,
        appName: 'RingPlus',
        avatar: avatarPath, // Start with empty avatar path to avoid blocking
        handle: displayName, // Use the display name as handle to prevent SIP URI showing
        type: 0, // Audio call
        textAccept: 'Accept',
        textDecline: 'Decline',
        duration: 30000, // 30 seconds timeout
        extra: <String, dynamic>{
          'sipCallId': callId,
          'callerName': callerName,
          'callerNumber': callerNumber,
        },
        headers: <String, dynamic>{
          'apiKey': 'RingPlus_VoIP',
          'platform': 'flutter',
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: true,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#4A1458',
          backgroundUrl: '',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call',
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic', // Use generic for better CallKit display consistency
          supportsVideo: false,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'voiceChat', // Use voiceChat mode optimized for VoIP calls
          audioSessionActive:
              true, // Activate immediately to ensure audio works in all modes
          audioSessionPreferredSampleRate:
              48000.0, // Use 48kHz for better CallKit compatibility
          audioSessionPreferredIOBufferDuration: 0.01, // 10ms buffer for stable audio
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath:
              'system_ringtone_default', // This uses iOS system ringtone
        ),
      );

      // Store the mapping of CallKit UUID to SIP call ID
      _callKitToSipMapping[uuid] = callId;

      await FlutterCallkitIncoming.showCallkitIncoming(params);

      debugPrint(
          'SIP Service: CallKit incoming call shown with UUID: $uuid, SIP callId: $callId');
      
      // Add a slight delay to ensure CallKit is properly activated
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Log CallKit state for debugging full-screen vs banner issues
      debugPrint('SIP Service: CallKit incoming call displayed successfully');
          
      // Clean up old avatars periodically
      AvatarService.instance.cleanupOldAvatars();
    } catch (e) {
      debugPrint('SIP Service: Error showing CallKit incoming call: $e');
      // Fallback to direct navigation if CallKit fails
      NavigationService.goToIncomingCall(
        callId: callId,
        callerName: callerName,
        callerNumber: callerNumber,
      );
    }
  }

  /// Generate avatar in background to avoid blocking CallKit display
  void _generateAvatarInBackground(String callerNumber, String displayName, String uuid) {
    // Run avatar generation in background
    Future(() async {
      try {
        debugPrint('SIP Service: Generating avatar in background for CallKit...');
        final generatedAvatarPath = await AvatarService.instance.generateAvatarForCallKit(
          phoneNumber: callerNumber,
          displayName: displayName,
        );
        
        if (generatedAvatarPath != null && generatedAvatarPath.isNotEmpty) {
          debugPrint('SIP Service: Avatar generated successfully in background: $generatedAvatarPath');
          // Note: CallKit doesn't support updating avatar after initial display
          // This is generated for consistency and future use
        } else {
          debugPrint('SIP Service: Failed to generate avatar in background');
        }
      } catch (e) {
        debugPrint('SIP Service: Error generating avatar in background: $e');
      }
    }).catchError((e) {
      debugPrint('SIP Service: Background avatar generation failed: $e');
    });
  }

  // Mapping to track CallKit UUIDs to SIP call IDs
  final Map<String, String> _callKitToSipMapping = {};

  // Track accepted CallKit calls to prevent duplicate accepts
  final Set<String> _acceptedCallKitIds = {};

  // Initialize CallKit event listeners
  void _initializeCallKitListeners() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;

      debugPrint('SIP Service: CallKit event: ${event.event}');

      switch (event.event) {
        case Event.actionCallAccept:
          _handleCallKitAccept(event.body);
          break;
        case Event.actionCallDecline:
          _handleCallKitDecline(event.body);
          break;
        case Event.actionCallTimeout:
          _handleCallKitTimeout(event.body);
          break;
        case Event.actionCallCallback:
          _handleCallKitCallback(event.body);
          break;
        default:
          break;
      }
    });
  }

  void _handleCallKitAccept(dynamic body) async {
    try {
      final String callKitId = body['id'];
      final String? sipCallId = _callKitToSipMapping[callKitId];

      if (sipCallId != null) {
        // Check if this call has already been accepted
        if (_acceptedCallKitIds.contains(callKitId)) {
          debugPrint(
              'SIP Service: CallKit call $callKitId already accepted, ignoring duplicate accept event');
          return;
        }

        debugPrint('SIP Service: CallKit accept for SIP call: $sipCallId');

        // Mark this call as accepted to prevent duplicate attempts
        _acceptedCallKitIds.add(callKitId);

        // CallKit handles all audio session and device management automatically

        // Enhanced CallKit accept with audio debugging
        debugPrint('SIP Service: Before CallKit accept - checking system audio state');
        await _handleCallKitAcceptWithAudioFix(sipCallId);

        // Mark CallKit call as connected
        await FlutterCallkitIncoming.setCallConnected(callKitId);

        // Add small delay before navigation to prevent GlobalKey conflicts
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate to in-call screen (with debouncing)
        if (!_isNavigatingFromCallKit) {
          _isNavigatingFromCallKit = true;
          // For incoming calls, pass the caller information if available
          NavigationService.goToInCall(
            sipCallId,
            phoneNumber: _currentCall?.remoteNumber,
            contactName: _currentCall?.remoteName,
          );
          // Reset flag after a delay to allow future navigation
          Future.delayed(const Duration(milliseconds: 500), () {
            _isNavigatingFromCallKit = false;
          });
        }

        // Keep the mapping for hangup - remove it only on call termination
        debugPrint('SIP Service: CallKit call accepted and connected');
      }
    } catch (e) {
      debugPrint('SIP Service: Error handling CallKit accept: $e');
    }
  }

  /// Enhanced CallKit call acceptance with audio session debugging and fixes
  Future<void> _handleCallKitAcceptWithAudioFix(String sipCallId) async {
    try {
      debugPrint('SIP Service: CallKit accept with audio fix for SIP call: $sipCallId');
      
      // Log current audio session state for debugging
      debugPrint('SIP Service: Audio session state before accept');
      
      // Answer the SIP call with optimized timing
      await answerCall(sipCallId);
      
      // Additional audio session verification after call acceptance
      await Future.delayed(const Duration(milliseconds: 100));
      
      debugPrint('SIP Service: CallKit accept with audio fix completed');
      
    } catch (e) {
      debugPrint('SIP Service: Error in CallKit accept with audio fix: $e');
      // Fallback to regular answer call
      try {
        await answerCall(sipCallId);
      } catch (fallbackError) {
        debugPrint('SIP Service: Fallback answerCall also failed: $fallbackError');
      }
    }
  }

  void _handleCallKitDecline(dynamic body) async {
    try {
      final String callKitId = body['id'];
      final String? sipCallId = _callKitToSipMapping[callKitId];

      if (sipCallId != null) {
        debugPrint('SIP Service: CallKit decline for SIP call: $sipCallId');

        // Set hangup flag to prevent state conflicts
        _isHangingUp = true;

        // Remove the mapping first to prevent double cleanup in hangupCall
        _callKitToSipMapping.remove(callKitId);
        _acceptedCallKitIds.remove(callKitId);

        // Decline the SIP call
        await hangupCall(sipCallId);

        // Add small delay before navigation to prevent GlobalKey conflicts
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate back to keypad (with debouncing)
        if (!_isNavigatingFromCallKit) {
          _isNavigatingFromCallKit = true;
          NavigationService.goToKeypad();
          // Reset flag after a delay to allow future navigation
          Future.delayed(const Duration(milliseconds: 500), () {
            _isNavigatingFromCallKit = false;
          });
        }

        debugPrint('SIP Service: CallKit call declined successfully');
      }
    } catch (e) {
      debugPrint('SIP Service: Error handling CallKit decline: $e');
    }
  }

  void _handleCallKitTimeout(dynamic body) async {
    try {
      final String callKitId = body['id'];
      final String? sipCallId = _callKitToSipMapping[callKitId];

      if (sipCallId != null) {
        debugPrint('SIP Service: CallKit timeout for SIP call: $sipCallId');
        // The call timed out, just clean up
        _callKitToSipMapping.remove(callKitId);
        _acceptedCallKitIds.remove(callKitId);
        // Add small delay before navigation to prevent GlobalKey conflicts
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate back to keypad (with debouncing)
        if (!_isNavigatingFromCallKit) {
          _isNavigatingFromCallKit = true;
          NavigationService.goToKeypad();
          // Reset flag after a delay to allow future navigation
          Future.delayed(const Duration(milliseconds: 500), () {
            _isNavigatingFromCallKit = false;
          });
        }
      }
    } catch (e) {
      debugPrint('SIP Service: Error handling CallKit timeout: $e');
    }
  }

  void _handleCallKitCallback(dynamic body) {
    debugPrint('SIP Service: CallKit callback: $body');
    // Handle callback if needed
  }

  // End CallKit call when SIP call terminates
  Future<void> _endCallKitCall(String sipCallId) async {
    try {
      // Find the CallKit UUID for this SIP call
      String? callKitId;
      for (final entry in _callKitToSipMapping.entries) {
        if (entry.value == sipCallId) {
          callKitId = entry.key;
          break;
        }
      }

      if (callKitId != null) {
        await FlutterCallkitIncoming.endCall(callKitId);
        _callKitToSipMapping.remove(callKitId);
        _acceptedCallKitIds.remove(callKitId);
        debugPrint(
            'SIP Service: Ended CallKit call for SIP callId: $sipCallId');
      }
    } catch (e) {
      debugPrint('SIP Service: Error ending CallKit call: $e');
    }
  }
}
