part of 'sip_service_base.dart';

mixin _SipServiceCallHandling on _SipServiceBase {
  @pragma('vm:entry-point')
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
      _cdrsModel =
          CdrsModel(maxItems: 100); // Create CDRs model with max 100 items
      _callsModel = AppCallsModel(
          _accountsModel!, null, _cdrsModel); // Use our extended AppCallsModel

      _networkModel = NetworkModel();
      _devicesModel = DevicesModel();

      // Set up event listeners
      _setupEventListeners();

      await _siprixSdk!.initialize(initData);

      // Load audio devices - CallKit will handle audio configuration
      _devicesModel?.load();

      // Set up AppCallsModel callbacks instead of direct SDK listeners
      debugPrint('SIP Service: Setting up AppCallsModel callbacks...');
      _callsModel!.onIncomingCallCallback = _handleIncomingCall;
      _callsModel!.onCallConnectedCallback = _handleCallConnected;
      _callsModel!.onCallTerminatedCallback = _handleCallTerminated;
      _callsModel!.onCallSwitchedCallback = _handleCallSwitched;
      _callsModel!.onCallHeldCallback = _handleCallHeld;
      debugPrint('SIP Service: AppCallsModel callbacks set successfully');

      // Set up CallStateListener to route events to AppCallsModel
      _siprixSdk!.callListener = CallStateListener(
        incoming: (int callId, int accId, bool withVideo, String from, String to) {
          debugPrint('>>> CallStateListener.incoming CALLED - routing to AppCallsModel');
          _callsModel?.onIncomingSip(callId, accId, withVideo, from, to);
        },
        connected: (int callId, String from, String to, bool withVideo) {
          debugPrint('>>> CallStateListener.connected CALLED - routing to AppCallsModel');
          _callsModel?.onConnected(callId, from, to, withVideo);
        },
        terminated: (int callId, int statusCode) {
          debugPrint('>>> CallStateListener.terminated CALLED - routing to AppCallsModel');
          _callsModel?.onTerminated(callId, statusCode);
        },
        switched: (int callId) {
          debugPrint('>>> CallStateListener.switched CALLED - routing to AppCallsModel');
          _callsModel?.onSwitched(callId);
        },
        held: (int callId, HoldState holdState) {
          debugPrint('>>> CallStateListener.held CALLED - routing to AppCallsModel: callId=$callId, holdState=$holdState');
          _callsModel?.onHeld(callId, holdState);
        },
        incomingPush: _onIncomingPush, // Enable push call handling for CallKit
        acceptNotif: _onCallAcceptNotif, // Handle Android notification acceptance
      );

      // Note: Call history is now handled by Siprix CDRs automatically

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

    debugPrint('SIP Service: Event listeners configured');
  }

  void _onModelsChanged() {
    debugPrint('SIP Service: Models changed - syncing call states');
    _checkCallStateChanges();
  }

  // Handler methods called by AppCallsModel after builtin processing

  void _handleIncomingCall(int callId, String from, String to, bool withVideo) {
    debugPrint('>>> SIP Service: _handleIncomingCall CALLED - callId: $callId, from: $from, to: $to, withVideo: $withVideo');

    // Ignore incoming calls if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring incoming call - hangup in progress');
      return;
    }

    // Get cached caller information (parsed using builtin SDK functions)
    final callerInfo = _getCachedCallerInfo(from);
    final callerName = callerInfo['name']!;
    final callerNumber = callerInfo['number']!;

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

    // Check if this call should be auto-answered (notification acceptance)
    if (_autoAnswerCallId == callId.toString()) {
      debugPrint('SIP Service: Auto-answering call $callId');

      // Clear the auto-answer flag
      clearAutoAnswerCall();

      // Answer the call immediately with a small delay
      Future.delayed(const Duration(milliseconds: 100)).then((_) async {
        try {
          await answerCall(callId.toString());
          debugPrint('SIP Service: Auto-answer successful');
        } catch (e) {
          debugPrint('SIP Service: Auto-answer failed: $e');
        }
      });
      return; // Exit early, don't show incoming call screen
    }

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

  void _handleCallConnected(int callId) {
    debugPrint('SIP Service: Handling call connected - callId: $callId');

    // Ignore connected events if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring connected event - hangup in progress');
      return;
    }

    // Find the current call and update its state
    if (_currentCall?.id == callId.toString()) {
      final updatedCall = _currentCall!.copyWith(
        state: AppCallState.answered,
        isConnectedWithAudio: true,
      );
      _updateCurrentCall(updatedCall);
    }

    _startCallDurationTimer();
  }

  void _handleCallTerminated(int callId) {
    debugPrint('SIP Service: Handling call terminated - callId: $callId');

    // Clear current call and cleanup
    _callerInfoCache.clear();
    _stopCallDurationTimer();
    _updateCurrentCall(null);

    // Reset hangup flag after brief delay
    Timer(const Duration(milliseconds: 100), () => _isHangingUp = false);
  }

  void _handleCallSwitched(int callId) {
    debugPrint('SIP Service: Handling call switched - callId: $callId');

    if (callId == 0) {
      // No active calls
      _updateCurrentCall(null);
    } else {
      // Sync with the active call
      _syncCurrentCallFromModel();
    }
  }

  void _handleCallHeld(int callId, HoldState holdState) {
    debugPrint('SIP Service: Handling call held - callId: $callId, holdState: $holdState');

    // Update the current call with the new hold state
    _syncCurrentCallFromModel();

    // Notify hold event listeners
    _notifyHoldEventListeners(callId, holdState);

    // Notify any listeners about the hold state change
    notifyListeners();
  }

  /// Sync current call when CallsModel structure changes (add/remove calls)
  void _checkCallStateChanges() {
    if (_callsModel == null) return;

    final activeCall = _callsModel!.switchedCall();
    if (activeCall != null) {
      debugPrint('SIP Service: Syncing active call ${activeCall.myCallId}');
      _syncCurrentCallFromModel();
    } else if (currentCall != null) {
      debugPrint(
          'SIP Service: No active call in CallsModel, clearing current call');
      _updateCurrentCall(null);
    }
  }

  void _onCallSwitched(int callId) {
    debugPrint('SIP Service: Call switched - callId: $callId');
    if (callId == 0) {
      // No active calls - this means call was terminated
      _updateCurrentCall(null);
      debugPrint('SIP Service: All calls ended - cleared current call');
    } else {
      debugPrint('SIP Service: Call switched to active call: $callId');
      // Sync with the active call from CallsModel
      _syncCurrentCallFromModel();
    }
  }

  void _onNetworkChanged() {
    debugPrint(
        'SIP Service: Network model changed - checking network state...');
    if (_networkModel != null) {
      final isNetworkLost = _networkModel!.networkLost;
      debugPrint('SIP Service: Network lost: $isNetworkLost');

      // If we have an active call and network issues, track the network state
      if (hasActiveCall && isNetworkLost) {
        debugPrint(
            'SIP Service: Network lost during active call - call may need recovery');
      }
    }
  }

  // Push notifications and special SDK event handlers

  void _onCallAcceptNotif(int callId, bool withVideo) {
    debugPrint('SIP Service: Call accept notification - callId: $callId');

    final call = _findCallByCallId(callId);
    if (call != null) {
      debugPrint('SIP Service: Found call $callId, answering');
      Future.delayed(const Duration(milliseconds: 50)).then((_) async {
        try {
          await answerCall(callId.toString());
          debugPrint('SIP Service: Call answered from notification');
        } catch (e) {
          debugPrint('SIP Service: Error answering call from notification: $e');
        }
      });
    } else {
      debugPrint('SIP Service: AcceptNotif for unknown call ID: $callId');
    }
  }

  // Handle incoming push notifications for CallKit

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

  /// Android-specific method to show custom incoming call screen
  /// iOS uses Siprix built-in CallKit instead

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

  /// Set auto-answer flag for notification acceptance
  void setAutoAnswerCall(
      String callId, String callerName, String callerNumber) {
    debugPrint('SIP Service: Setting auto-answer for callId: $callId');
    _autoAnswerCallId = callId;
    _autoAnswerCallerName = callerName;
    _autoAnswerCallerNumber = callerNumber;
  }

  /// Clear auto-answer flag
  void clearAutoAnswerCall() {
    debugPrint('SIP Service: Clearing auto-answer flag');
    _autoAnswerCallId = null;
    _autoAnswerCallerName = null;
    _autoAnswerCallerNumber = null;
  }

  Future<String?> makeCall(String number) async {
    try {
      debugPrint('Make call: Starting call to $number');

      // Validate prerequisites
      if (!isRegistered) throw Exception('Not registered');
      if (_callsModel == null) throw Exception('Calls model not initialized');

      // Get account ID
      final accountId = _currentAccountId ??
          _accountsModel?.selAccountId ??
          1; // Default fallback

      // Create and make call using built-in SDK functions
      final destination = CallDestination(number, accountId, false)
        ..inviteTimeout = 60
        ..displName = number;

      await _callsModel!.invite(destination);
      debugPrint('Make call: INVITE sent successfully to $number');

      // Return the new call ID from CallsModel
      return _callsModel!.length > 0
          ? _callsModel![_callsModel!.length - 1].myCallId.toString()
          : null;
    } catch (e) {
      debugPrint('Make call failed: $e');
      return null;
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      debugPrint('SIP Service: Answering call: $callId');
      final call = _findCallByCallId(int.tryParse(callId) ?? 0);
      if (call == null) throw Exception('Call not found');

      await call.accept(false); // Use built-in SDK method
      debugPrint('SIP Service: Call answered successfully');
    } catch (e) {
      debugPrint('Answer call failed: $e');
      rethrow;
    }
  }

  Future<void> hangupCall(String callId) async {
    try {
      debugPrint('SIP Service: Hanging up call: $callId');
      _isHangingUp = true;

      final call = _findCallByCallId(int.tryParse(callId) ?? 0) ??
          _callsModel?.switchedCall();
      if (call == null) throw Exception('No call found to terminate');

      await call.bye(); // Use built-in SDK method
      debugPrint('SIP Service: Call hung up successfully');
    } catch (e) {
      debugPrint('Hangup call failed: $e');
      rethrow;
    }
  }

  Future<void> holdCall(String callId) async {
    try {
      final call = _findCallByCallId(int.tryParse(callId) ?? 0);
      if (call == null) throw Exception('Call not found');
      await call.hold();
    } catch (e) {
      debugPrint('Hold call failed: $e');
      rethrow;
    }
  }

  Future<void> unholdCall(String callId) async {
    try {
      final call = _findCallByCallId(int.tryParse(callId) ?? 0);
      if (call == null) throw Exception('Call not found');
      await call.hold(); // Toggles hold state
    } catch (e) {
      debugPrint('Unhold call failed: $e');
      rethrow;
    }
  }

  Future<void> muteCall(String callId, bool mute) async {
    try {
      final intCallId = int.tryParse(callId);
      if (intCallId == null) throw Exception('Invalid call ID format');

      final targetCall = _findCallByCallId(intCallId) ?? _callsModel?.switchedCall();
      if (targetCall == null) throw Exception('No active call available for muting');

      await targetCall.muteMic(mute);
    } catch (e) {
      debugPrint('Mute call failed: $e');
      rethrow;
    }
  }

  Future<void> setSpeaker(String callId, bool speaker) async {
    try {
      if (Platform.isIOS) return; // CallKit handles audio routing

      if (_siprixSdk != null && _devicesModel != null) {
        final devices = _devicesModel!.playout;
        final targetDevice = devices.firstWhere(
          (device) => speaker
              ? device.name.toLowerCase().contains('speaker')
              : device.name.toLowerCase().contains('earpiece') ||
                  !device.name.toLowerCase().contains('speaker'),
          orElse: () => devices.first,
        );
        await _siprixSdk!.setPlayoutDevice(targetDevice.index);
      }
    } catch (e) {
      debugPrint('Set speaker failed: $e');
    }
  }

  List<AudioDeviceInfo> get categorizedAudioDevices {
    final devices = _devicesModel?.playout ?? [];
    final List<AudioDeviceInfo> categorized = [];
    bool hasBuiltinAdded = false;

    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      final category = _getAudioDeviceCategory(device);

      if (category == AudioDeviceCategory.earpiece || category == AudioDeviceCategory.builtin) {
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

      if (category == AudioDeviceCategory.speaker) {
        categorized.add(AudioDeviceInfo(
          device: device,
          index: i,
          category: category,
          displayName: 'Speaker',
          icon: Icons.volume_up,
        ));
      }
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
      if (Platform.isIOS) return; // CallKit handles audio routing

      if (_siprixSdk != null) {
        await _siprixSdk!.setPlayoutDevice(deviceIndex);
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

  List<MediaDevice> get availableAudioDevices {
    return _devicesModel?.playout ?? [];
  }

  int get currentAudioDeviceIndex {
    return _devicesModel?.playoutIndex ?? -1;
  }

  /// Public method to find a call in CallsModel by its callId
  CallModel? findCallByCallId(String callId) {
    return _findCallByCallId(int.tryParse(callId) ?? 0);
  }

  /// Helper method to find a call in CallsModel by its callId
  CallModel? _findCallByCallId(int callId) {
    if (_callsModel == null) return null;

    for (int i = 0; i < _callsModel!.length; i++) {
      final call = _callsModel![i];
      if (call.myCallId == callId) {
        return call;
      }
    }
    return null;
  }

  /// Helper method to sync the current call UI state with the active call from CallsModel
  void _syncCurrentCallFromModel() {
    if (_callsModel == null) {
      _updateCurrentCall(null);
      return;
    }

    final activeCall = _callsModel!.switchedCall();
    if (activeCall != null) {
      final callInfo = CallInfo(
        id: activeCall.myCallId.toString(),
        remoteNumber: activeCall.remoteExt,
        remoteName: activeCall.displName.isNotEmpty
            ? activeCall.displName
            : activeCall.remoteExt,
        state: _mapCallStateToAppCallState(activeCall.state),
        startTime: activeCall.startTime,
        isIncoming: activeCall.isIncoming,
        isMuted: activeCall.isMicMuted,
        isSpeakerOn: false,
        isOnHold: activeCall.isLocalHold,
      );
      _updateCurrentCall(callInfo);
    } else {
      _updateCurrentCall(null);
    }
  }

  void _startCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (hasActiveCall && _callsModel?.switchedCall() != null) {
        if (!_isDisposed && !_currentCallController.isClosed) {
          notifyListeners();
        }
      } else {
        _stopCallDurationTimer();
      }
    });
  }

  void _stopCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
  }

  /// Helper method to map CallState to AppCallState
  AppCallState _mapCallStateToAppCallState(CallState callState) {
    switch (callState) {
      case CallState.dialing:
        return AppCallState.connecting;
      case CallState.proceeding:
        return AppCallState.connecting;
      case CallState.ringing:
        return AppCallState.ringing;
      case CallState.rejecting:
        return AppCallState.ended;
      case CallState.accepting:
        return AppCallState.connecting;
      case CallState.connected:
        return AppCallState.answered;
      case CallState.disconnecting:
        return AppCallState.ended;
      case CallState.holding:
        return AppCallState.held;
      case CallState.held:
        return AppCallState.held;
      case CallState.transferring:
        return AppCallState.connecting;
    }
  }

  void _updateCurrentCall(CallInfo? call) {
    if (_isDisposed) return;

    _currentCall = call;

    if (!_currentCallController.isClosed) {
      _currentCallController.add(call);
    }

    if (!_isDisposed) {
      notifyListeners();
    }
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
        if (hasActiveCall) {
          debugPrint(
              'SIP Service: App resumed with active call - ensuring audio session');
          _ensureAudioSessionOnResume();
        }

        // Stale call detection removed to prevent interference with active calls
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

  void _ensureAudioSessionOnResume() {
    if (Platform.isIOS && hasActiveCall) {
      Future.delayed(const Duration(milliseconds: 300), () {
        // Audio session reactivation completed
      });
    }
  }
}
