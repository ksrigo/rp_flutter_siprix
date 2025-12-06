part of 'sip_service_base.dart';

mixin SipServiceCallHandling on _SipServiceBase {
  // Add these tracking maps for foreground CallKit management
  final Map<int, String> _foregroundCallKitMap = {};
  final Map<int, bool> _callKitReportedMap = {};
  final Map<int, DateTime> _callStartTimeMap = {};

  @override
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
      initData.license = dotenv.env['SIPRIX_LICENCE'] ?? '';
      initData.singleCallMode = false; // Allow multiple calls

      // Share UDP transport for efficiency
      initData.shareUdpTransport = true;

      // Platform-specific initialization
      if (Platform.isIOS) {
        // ENHANCED iOS-specific settings for killed/locked state
        initData.enableVideoCall = false;
        initData.enableCallKit = true;
        initData.enablePushKit = true;
        initData.unregOnDestroy = false;

        debugPrint(
            'SIP Service: Enabled enhanced CallKit and PushKit for killed/locked state');
      } else if (Platform.isAndroid) {
        debugPrint(
            'SIP Service: Configured Siprix for Android (video disabled)');
      }

      _siprixSdk = SiprixVoipSdk();
      // Create models for account and call management
      _accountsModel = AccountsModel();
      final globalCdrsModel = getGlobalCdrsModel();
      if (globalCdrsModel != null) {
        _cdrsModel = globalCdrsModel;
        debugPrint(
            'SIP Service: ✅ Reusing CdrsModel from early initialization (iOS push)');
        debugPrint(
            'SIP Service: CdrsModel has ${_cdrsModel!.length} existing entries');
      } else {
        debugPrint('SIP Service: No saved CDR history found');
        _cdrsModel =
            CdrsModel(maxItems: 100); // Create CDRs model with max 100 items
      }

      // Set up CDR persistence - save changes to storage
      _cdrsModel!.onSaveChanges = (String jsonStr) async {
        debugPrint('SIP Service: Saving CDR history to storage');
        await StorageService.instance.saveCdrCallHistory(jsonStr);
      };

      // Load CDRs from storage
      final savedCdrs = await StorageService.instance.getCdrCallHistory();
      if (savedCdrs != null && savedCdrs.isNotEmpty) {
        final loaded = _cdrsModel!.loadFromJson(savedCdrs);
        debugPrint(
            'SIP Service: Loaded ${_cdrsModel!.length} CDR entries from storage');
      } else {
        debugPrint('SIP Service: No saved CDR history found');
      }

      // CRITICAL FOR iOS PUSH: Check if AppCallsModel was already created in main.dart
      final globalCallsModel = getGlobalCallsModel();
      if (globalCallsModel != null) {
        _callsModel = globalCallsModel;
        debugPrint(
            'SIP Service: ✅ Reusing AppCallsModel from early initialization');
      } else {
        _callsModel = AppCallsModel(_accountsModel!, null, _cdrsModel);
        debugPrint('SIP Service: Created new AppCallsModel with CdrsModel');
      }

      _networkModel = NetworkModel();
      _devicesModel = DevicesModel();

      // Set up event listeners
      _setupEventListeners();

      await _siprixSdk!.initialize(initData);

      // CRITICAL: Load audio devices immediately
      _devicesModel?.load();
      debugPrint(
          'SIP Service: Audio devices pre-loaded for killed/locked state');

      // Set up AppCallsModel callbacks
      _callsModel!.onIncomingCallCallback = _handleIncomingCall;
      _callsModel!.onCallConnectedCallback = _handleCallConnected;
      _callsModel!.onCallTerminatedCallback = _handleCallTerminated;
      _callsModel!.onCallSwitchedCallback = _handleCallSwitched;
      _callsModel!.onCallHeldCallback = _handleCallHeld;
      _callsModel!.onCallProceedingCallback = _handleCallProceeding;

      // Set up contact name resolution
      if (_callsModel != null) {
        _callsModel!.onResolveContactName = _resolveContactNameForCallKit;
      }

      debugPrint('SIP Service: Siprix SDK initialized successfully');

      // Add app lifecycle observer
      if (!kIsWeb) {
        WidgetsBinding.instance.addObserver(this);
      }

      // Initialize network monitoring
      await _initializeNetworkMonitoring();

      // Auto-register if credentials exist
      final credentials = await StorageService.instance.getCredentials();
      if (credentials != null) {
        await _autoRegister(credentials);
      }

      // iOS-specific setup for killed/locked state
      if (Platform.isIOS) {
        _configureForKilledLockedState();
        _checkIOSCapabilities();
        // debugIOSPushConfiguration();
        _scheduleDelayedTokenRetry();
      }

      debugPrint(
          'SIP Service: ✅ Initialization complete - ready for killed/locked state');
    } catch (e) {
      debugPrint('❌ Error initializing SIP service: $e');
      rethrow;
    }
  }

  /// iOS-specific method to force CDR refresh and ensure data is loaded
  @override
  Future<void> _refreshCdrForIOS() async {
    if (!Platform.isIOS) return;

    try {
      debugPrint('🔄 iOS CDR REFRESH: Forcing CDR refresh...');

      // Force reload from storage
      final savedCdrs = await StorageService.instance.getCdrCallHistory();
      if (savedCdrs != null && savedCdrs.isNotEmpty) {
        _cdrsModel?.loadFromJson(savedCdrs);
        debugPrint(
            '✅ iOS CDR REFRESH: Reloaded ${_cdrsModel?.length ?? 0} records');
      } else {
        debugPrint('⚠️ iOS CDR REFRESH: No CDR data in storage');
      }

      // Notify listeners that CDR data might have changed
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ iOS CDR REFRESH ERROR: $e');
    }
  }

  void _scheduleDelayedTokenRetry() {
    // Wait 10 seconds for SIP registration to complete
    Timer(const Duration(seconds: 10), () {
      debugPrint(
          '🔄 Starting DELAYED push token retries after SIP registration');
      _scheduleTokenRetry();
    });
  }

  /// Configure specifically for killed/locked state operation
  void _configureForKilledLockedState() {
    try {
      debugPrint('🔒 KILLED/LOCKED: Configuring for reliable operation...');

      // Ensure audio devices are loaded
      if (_devicesModel != null) {
        _devicesModel!.load();
        debugPrint('🔒 KILLED/LOCKED: Audio devices loaded');
      }

      // Additional configuration for killed state
      debugPrint(
          '🔒 KILLED/LOCKED: PushKit + CallKit configured for killed state');
    } catch (e) {
      debugPrint('🔒 KILLED/LOCKED: Error in configuration: $e');
    }
  }

  /// UNIVERSAL INCOMING CALL HANDLER with killed/locked state fixes
  void _handleIncomingCall(
      int callId, String from, String to, bool withVideo) async {
    debugPrint('🔔 UNIVERSAL INCOMING CALL: callId: $callId');
    debugPrint('🔔 APP STATE: ${WidgetsBinding.instance.lifecycleState}');

    // Check if Do Not Disturb is enabled
    final isDndEnabled = await isDoNotDisturbEnabled();
    if (isDndEnabled) {
      debugPrint(
          'SIP Service: Do Not Disturb enabled, auto-rejecting call $callId');
      try {
        await SiprixVoipSdk().reject(callId, 480);
        return;
      } catch (e) {
        debugPrint('SIP Service: Failed to auto-reject call: $e');
      }
      return;
    }

    // Get caller information
    final callerInfo = _getCachedCallerInfo(from);
    final callerName = callerInfo['name']!;
    final callerNumber = callerInfo['number']!;

    // Create call info
    final callInfo = CallInfo(
      id: callId.toString(),
      remoteNumber: callerNumber,
      remoteName: callerName,
      state: AppCallState.ringing,
      startTime: DateTime.now(),
      isIncoming: true,
    );

    _updateCurrentCall(callInfo);

    // Check for auto-answer
    if (_autoAnswerCallId == callId.toString()) {
      _handleAutoAnswer(callId, callerName, callerNumber);
      return;
    }

    // Handle based on platform
    if (Platform.isAndroid) {
      _showIncomingCallScreen(callId.toString(), callerName, callerNumber);
    } else if (Platform.isIOS) {
      _handleIOSIncomingCallUniversal(callId, callerName, callerNumber);
    }
  }

  /// iOS UNIVERSAL incoming call handler with killed/locked state fixes
  void _handleIOSIncomingCallUniversal(
      int callId, String callerName, String callerNumber) {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;

    debugPrint('🔔 iOS UNIVERSAL HANDLER:');
    debugPrint('  - Call ID: $callId');
    debugPrint('  - App State: $lifecycleState');

    // CRITICAL: Always report to CallKit for killed/locked state
    _reportCallToCallKitUniversal(callId, callerName, callerNumber);

    // Only show custom UI in foreground
    if (lifecycleState == AppLifecycleState.resumed) {
      debugPrint('🔔 iOS: FOREGROUND - showing custom UI');
      _showIncomingCallScreen(callId.toString(), callerName, callerNumber);
    } else {
      debugPrint('🔔 iOS: BACKGROUND/LOCKED/KILLED - relying on CallKit');
      // CallKit handles everything automatically in these states
    }
  }

  /// Enhanced CallKit reporting for killed/locked state
  void _reportCallToCallKitUniversal(
      int callId, String callerName, String callerNumber) {
    try {
      final callkitUuid = _generateCallKitUuid(callId);

      debugPrint(
          '🔔 CALLKIT UNIVERSAL: Reporting call $callId for killed/locked state');
      debugPrint('🔔 CALLKIT UNIVERSAL: Generated UUID $callkitUuid');

      SiprixVoipSdk().updateCallKitCallDetails(
        callkitUuid,
        callId,
        callerName,
        callerNumber,
        false, // withVideo
      );

      _foregroundCallKitMap[callId] = callkitUuid;
      _callKitReportedMap[callId] = true;
      _callStartTimeMap[callId] = DateTime.now();

      debugPrint('🔔 CALLKIT UNIVERSAL: ✅ Call reported successfully');
    } catch (e) {
      debugPrint('🔔 CALLKIT UNIVERSAL: ❌ Error: $e');
    }
  }

  /// ENHANCED answer call with killed/locked state fixes
  Future<void> answerCall(String callId) async {
    try {
      debugPrint('🔔 ENHANCED ANSWER: Answering call: $callId');
      final intCallId = int.tryParse(callId) ?? 0;
      final call = _findCallByCallId(intCallId);
      if (call == null) throw Exception('Call not found');

      final isAppInForeground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

      // CRITICAL FOR KILLED/LOCKED STATE: Enhanced audio preparation
      await _ensureAudioReadyForKilledLockedState();

      if (!isAppInForeground) {
        debugPrint('🔔 ANSWER: KILLED/LOCKED STATE - extra audio preparation');
        _prepareForBackgroundAnswer(intCallId);
      }

      // ANSWER THE CALL with retry logic for killed state
      await _answerCallWithRetry(call, intCallId);

      // Handle post-answer
      if (!isAppInForeground && Platform.isIOS) {
        _handleKilledLockedAnswer(intCallId);
      }

      // Clean up
      if (Platform.isIOS) {
        _cleanupCallKitMappings(intCallId);
      }
    } catch (e) {
      debugPrint('🔔 ANSWER: ❌ Failed to answer call: $e');
      rethrow;
    }
  }

  /// Ensure audio is ready for killed/locked state
  Future<void> _ensureAudioReadyForKilledLockedState() async {
    try {
      debugPrint('🔊 KILLED/LOCKED AUDIO: Preparing audio...');

      if (_devicesModel != null) {
        // Reload audio devices aggressively
        _devicesModel!.load();

        // Additional delay to ensure audio is ready
        await Future.delayed(const Duration(milliseconds: 200));

        debugPrint('🔊 KILLED/LOCKED AUDIO: ✅ Audio prepared');
      }
    } catch (e) {
      debugPrint('🔊 KILLED/LOCKED AUDIO: ❌ Error: $e');
    }
  }

  /// Prepare for background answer in killed/locked state
  void _prepareForBackgroundAnswer(int callId) {
    try {
      if (_foregroundCallKitMap.containsKey(callId)) {
        final callkitUuid = _foregroundCallKitMap[callId]!;

        // Update CallKit configuration
        SiprixVoipSdk().updateCallKitCallDetails(
          callkitUuid,
          callId,
          null, // Keep existing name
          null, // Keep existing number
          null, // Keep existing video setting
        );
      }
    } catch (e) {
      debugPrint('🔔 BACKGROUND PREP: Error: $e');
    }
  }

  /// Answer call with retry logic for killed state
  Future<void> _answerCallWithRetry(CallModel call, int callId) async {
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        debugPrint(
            '🔔 ANSWER ATTEMPT ${retryCount + 1}/$maxRetries for call $callId');

        await call.accept(false);
        debugPrint('🔔 ANSWER: ✅ Call answered successfully');
        return; // Success, exit retry loop
      } catch (e) {
        retryCount++;
        debugPrint('🔔 ANSWER: ❌ Attempt $retryCount failed: $e');

        if (retryCount < maxRetries) {
          // Wait before retry
          await Future.delayed(const Duration(milliseconds: 500));
          debugPrint('🔔 ANSWER: Retrying...');
        } else {
          debugPrint('🔔 ANSWER: ❌ All retry attempts failed');
          rethrow;
        }
      }
    }
  }

  /// Handle answer from killed/locked state
  void _handleKilledLockedAnswer(int callId) {
    debugPrint('🔒 KILLED/LOCKED ANSWER: Handling answer...');

    final call = _findCallByCallId(callId);
    if (call != null) {
      // Use enhanced waiting with state verification
      _waitForCallConnectionWithVerification(callId, call);
    }
  }

  /// Wait for call connection with state verification
  void _waitForCallConnectionWithVerification(int callId, CallModel call) {
    const maxWaitTime = 15000; // 15 seconds max
    const checkInterval = 1000; // Check every second
    int timeWaited = 0;

    void checkCallState() {
      timeWaited += checkInterval;

      if (call.state == CallState.connected) {
        _navigateToInCallScreen(callId, call);
      } else if (timeWaited < maxWaitTime) {
        debugPrint(
            '🔒 KILLED/LOCKED: Call not connected (${timeWaited}ms), state: ${call.state}');
        Future.delayed(
            const Duration(milliseconds: checkInterval), checkCallState);
      } else {
        debugPrint(
            '🔒 KILLED/LOCKED: ❌ Call failed to connect within $maxWaitTime ms');
        _navigateToInCallScreen(callId, call); // Navigate anyway
      }
    }

    // Start checking with initial delay
    Future.delayed(const Duration(milliseconds: 1000), checkCallState);
  }

  /// Navigate to in-call screen
  void _navigateToInCallScreen(int callId, CallModel call) {
    final callerName =
        call.displName.isNotEmpty ? call.displName : call.remoteExt;
    final callerNumber = call.remoteExt;

    debugPrint('🔒 KILLED/LOCKED: Navigating to in-call screen');

    NavigationService.goToInCall(
      callId.toString(),
      phoneNumber: callerNumber,
      contactName: callerName,
    );

    debugPrint('🔒 KILLED/LOCKED: ✅ Navigation completed');
  }

  void _handleCallConnected(int callId) {
    debugPrint('🔔 CALL CONNECTED: callId: $callId');
    debugPrint('🔔 APP STATE: ${WidgetsBinding.instance.lifecycleState}');

    if (_isHangingUp) return;

    if (_currentCall?.id == callId.toString()) {
      final updatedCall = _currentCall!.copyWith(
        state: AppCallState.answered,
        isConnectedWithAudio: true,
      );
      _updateCurrentCall(updatedCall);
    }

    _startCallDurationTimer();

    // CRITICAL: Log connection success
    debugPrint('🔔 CALL CONNECTED: ✅ Audio should be active');
  }

  void _handleCallTerminated(int callId) {
    debugPrint('🔔 CALL TERMINATED: callId: $callId');

    _callerInfoCache.clear();
    _stopCallDurationTimer();

    // Clean up CallKit
    if (Platform.isIOS) {
      _cleanupCallKitMappings(callId);
    }

    final remainingCalls = _callsModel?.length ?? 0;
    if (remainingCalls == 0) {
      _updateCurrentCall(null);
    }

    Timer(const Duration(milliseconds: 100), () => _isHangingUp = false);
  }

  void _handleCallSwitched(int callId) {
    debugPrint('SIP Service: Handling call switched - callId: $callId');

    if (callId == 0) {
      // No active calls - but check if any calls remain (might be held)
      final remainingCalls = _callsModel?.length ?? 0;
      if (remainingCalls == 0) {
        debugPrint(
            'SIP Service: No calls remaining after switch, clearing current call');
        _updateCurrentCall(null);
      } else {
        debugPrint(
            'SIP Service: No active call but $remainingCalls calls remain (likely held), keeping current call');
      }
    } else {
      // Sync with the active call
      _syncCurrentCallFromModel();
    }
  }

  void _handleCallHeld(int callId, HoldState holdState) {
    debugPrint(
        'SIP Service: Handling call held - callId: $callId, holdState: $holdState');

    // Update the current call with the new hold state
    _syncCurrentCallFromModel();

    // Notify hold event listeners
    _notifyHoldEventListeners(callId, holdState);

    // Notify any listeners about the hold state change
    notifyListeners();
  }

  void _handleCallProceeding(int callId, String response) {
    debugPrint(
        'SIP Service: Handling call proceeding - callId: $callId, response: $response');

    // Parse the SIP response code (e.g., "180 Ringing" -> 180)
    final responseCode = int.tryParse(response.split(' ').first) ?? 0;

    // Only update to ringing state for 180 (Ringing) or 183 (Session Progress)
    if (responseCode == 180 || responseCode == 183) {
      // Find and update the current call to ringing state
      if (_currentCall?.id == callId.toString()) {
        final updatedCall = _currentCall!.copyWith(
          state: AppCallState.ringing,
        );
        _updateCurrentCall(updatedCall);
      }
    }
    // For other response codes (like 100), keep the current state or sync from model
    else {
      _syncCurrentCallFromModel();
    }
  }

  /// Android-specific method to show custom incoming call screen
  /// iOS uses Siprix built-in CallKit instead
  /// Handle auto-answer scenario
  void _handleAutoAnswer(int callId, String callerName, String callerNumber) {
    debugPrint('🔔 AUTO-ANSWER: Auto-answering call $callId');
    final savedCallerName = _autoAnswerCallerName ?? callerName;
    final savedCallerNumber = _autoAnswerCallerNumber ?? callerNumber;
    clearAutoAnswerCall();

    Future.delayed(const Duration(milliseconds: 100)).then((_) async {
      try {
        await answerCall(callId.toString());
        NavigationService.goToInCall(
          callId.toString(),
          phoneNumber: savedCallerNumber,
          contactName: savedCallerName,
        );
      } catch (e) {
        debugPrint('SIP Service: Auto-answer failed: $e');
      }
    });
  }

  void _showIncomingCallScreen(
      String callId, String callerName, String callerNumber) {
    try {
      NavigationService.goToIncomingCall(
        callId: callId,
        callerName: callerName,
        callerNumber: callerNumber,
      );
    } catch (e) {
      debugPrint('SIP Service: Error showing incoming call screen: $e');
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

  /// Enhanced hangup with CallKit cleanup
  Future<void> hangupCall(String callId) async {
    try {
      debugPrint('SIP Service: Hanging up call: $callId');
      _isHangingUp = true;

      final intCallId = int.tryParse(callId) ?? 0;
      final call = _findCallByCallId(intCallId) ?? _callsModel?.switchedCall();
      if (call == null) throw Exception('No call found to terminate');

      await call.bye();
      debugPrint('SIP Service: Call hung up successfully');

      // Clean up CallKit mapping
      if (Platform.isIOS) {
        _cleanupCallKitMappings(intCallId);
      }
    } catch (e) {
      debugPrint('Hangup call failed: $e');
      rethrow;
    }
  }

  /// Enhanced reject with CallKit cleanup
  Future<void> rejectCall(String callId) async {
    try {
      debugPrint('SIP Service: Rejecting call: $callId');
      final intCallId = int.tryParse(callId) ?? 0;
      final call = _findCallByCallId(intCallId);
      if (call == null) throw Exception('Call not found');

      await call.reject();
      debugPrint('SIP Service: Call rejected successfully');

      // Clean up CallKit mapping
      if (Platform.isIOS) {
        _cleanupCallKitMappings(intCallId);
      }
    } catch (e) {
      debugPrint('Reject call failed: $e');
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

      final targetCall =
          _findCallByCallId(intCallId) ?? _callsModel?.switchedCall();
      if (targetCall == null)
        throw Exception('No active call available for muting');

      await targetCall.muteMic(mute);
    } catch (e) {
      debugPrint('Mute call failed: $e');
      rethrow;
    }
  }

  Future<void> setSpeaker(String callId, bool speaker) async {
    try {
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

        // Update the current call state to reflect the speaker change
        if (_currentCall != null && _currentCall!.id == callId) {
          final updatedCall = _currentCall!.copyWith(isSpeakerOn: speaker);
          _updateCurrentCall(updatedCall);
          debugPrint(
              'SIP Service: Updated speaker state to $speaker for call $callId');
        }
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

  /// Sync current call when CallsModel structure changes (add/remove calls)
  void _checkCallStateChanges() {
    if (_callsModel == null) return;

    final activeCall = _callsModel!.switchedCall();
    if (activeCall != null) {
      debugPrint('SIP Service: Syncing active call ${activeCall.myCallId}');
      _syncCurrentCallFromModel();
    } else if (currentCall != null) {
      // Check if there are any calls remaining (active or held) before clearing
      final totalCalls = _callsModel!.length;
      if (totalCalls == 0) {
        debugPrint(
            'SIP Service: No calls remaining in CallsModel, clearing current call');
        _updateCurrentCall(null);
      } else {
        debugPrint(
            'SIP Service: No active call but $totalCalls calls remain (likely held), keeping current call');
      }
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

  @override
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

  void _startCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (hasActiveCall && _callsModel?.switchedCall() != null) {
        // Use builtin SDK method to calculate call duration
        _callsModel?.calcDuration();
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
        return AppCallState
            .connecting; // Will be updated to ringing based on SIP response
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

  @override
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
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    var storageInstance = StorageService.instance;
    debugPrint('🔔 LIFECYCLE: DialPad App state changed to: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResume();
        await storageInstance.setInt("AppState", 1);
        break;
      case AppLifecycleState.paused:
        await storageInstance.setInt("AppState", 2);
        break;
      case AppLifecycleState.detached:
        await storageInstance.setInt("AppState", 3);
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('🔔 LIFECYCLE:detached: $state');
        break;
      default:
        break;
    }
  }

  void _handleAppResume() {
    debugPrint('🔔 APP RESUME: Checking for active calls...');

    Future.delayed(const Duration(milliseconds: 500), () {
      final activeCall = _callsModel?.switchedCall();
      if (activeCall != null && activeCall.state == CallState.connected) {
        debugPrint(
            '🔔 APP RESUME: Active connected call found, ensuring UI is correct');

        final callerName = activeCall.displName.isNotEmpty
            ? activeCall.displName
            : activeCall.remoteExt;
        final callerNumber = activeCall.remoteExt;

        NavigationService.goToInCall(
          activeCall.myCallId.toString(),
          phoneNumber: callerNumber,
          contactName: callerName,
        );
      }
    });
  }

  /// Generate UUID for CallKit
  String _generateCallKitUuid(int callId) {
    return 'callkit-$callId-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Clean up CallKit mapping
  void _cleanupCallKitMappings(int callId) {
    if (!Platform.isIOS) return;
    _foregroundCallKitMap.remove(callId);
    _callKitReportedMap.remove(callId);
    _callStartTimeMap.remove(callId);
    debugPrint('🔔 CLEANUP: Removed CallKit mapping for callId: $callId');
  }

  void _setupEventListeners() {
    _accountsModel?.addListener(_onModelsChanged);
    _callsModel?.addListener(_onModelsChanged);
    _networkModel?.addListener(_onNetworkChanged);
    _callsModel?.onSwitchedCall = _onCallSwitched;
    debugPrint('SIP Service: Event listeners configured');
  }

  @override
  void _onModelsChanged() {
    _checkCallStateChanges();
  }

  static bool get isAppInForeground {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  /// Check if the app is in background (paused)
  static bool get isAppInBackground {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused;
  }

  /// Check if the app is in terminated/detached state
  static bool get isAppTerminated {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.detached;
  }
}
