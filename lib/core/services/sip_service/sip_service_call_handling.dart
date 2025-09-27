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
        acceptNotif:
            _onCallAcceptNotif, // Handle Android notification acceptance
      );

      // Set up direct SDK event listeners

      // Initialize call history service
      await _initializeCallHistoryService();

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


  Future<void> _initializeCallHistoryService() async {
    try {
      await CallHistoryService.instance.initialize();
      debugPrint('SIP Service: Call history service initialized');
    } catch (e) {
      debugPrint('SIP Service: Error initializing call history service: $e');
    }
  }

  void _addCallToHistoryOnTermination(int callId, int statusCode) {
    try {
      debugPrint(
          'SIP Service: Adding call to history on termination - callId: $callId, statusCode: $statusCode');

      // Check if this call is already in CDR history
      final existingCall = CallHistoryService.instance.getCallById(callId);
      if (existingCall != null) {
        debugPrint(
            'SIP Service: Call $callId already exists in CDR history - updating with final duration');

        // For answered calls, update the existing CallModel with final duration
        // Check if we have a connected model for this call - this indicates it was answered
        final hasConnectedModel = _connectedCallModel != null;
        final modelCallId = _connectedCallModel?.myCallId;
        final callIdsMatch = modelCallId == callId;

        debugPrint(
            'SIP Service: Duration update check - hasConnectedModel: $hasConnectedModel, modelCallId: $modelCallId, targetCallId: $callId, callIdsMatch: $callIdsMatch');

        // If we have a connected model for this call, it means it was answered at some point
        if (hasConnectedModel && callIdsMatch) {
          debugPrint(
              'SIP Service: Updating existing answered call with final duration');

          // Use the connected model's start time for duration calculation
          final callStartTime = _connectedCallModel!.startTime;
          final callEndTime = DateTime.now();
          final actualDurationMs =
              callEndTime.difference(callStartTime).inMilliseconds;
          final actualDurationSeconds = (actualDurationMs / 1000).round();

          debugPrint(
              'SIP Service: Manual duration calculation - Start: $callStartTime, End: $callEndTime, Duration: ${actualDurationMs}ms (${actualDurationSeconds}s)');

          // Trigger duration calculation on the CallModel
          _connectedCallModel!.calcDuration();

          final modelDurationStr = _connectedCallModel!.durationStr;
          final modelDurationMs = _connectedCallModel!.duration.inMilliseconds;
          debugPrint(
              'SIP Service: CallModel duration - durationStr: $modelDurationStr, durationMs: ${modelDurationMs}ms');
          debugPrint(
              'SIP Service: CallModel startTime: ${_connectedCallModel!.startTime}');

          // If CallModel duration is 0 but we have actual duration, manually update the CDR
          if (modelDurationMs == 0 && actualDurationMs > 1000) {
            debugPrint(
                'SIP Service: CallModel duration is 0 but actual duration is ${actualDurationMs}ms - using manual duration update');
            // Manually update the CDR record with our calculated duration
            CallHistoryService.instance
                .updateCallDuration(callId, actualDurationMs);
          } else {
            // Update the CallModel in CDR with the calculated duration
            CallHistoryService.instance.addCallRecord(_connectedCallModel!);
            debugPrint(
                'SIP Service: Updated existing CDR record with CallModel duration');
          }
        } else {
          debugPrint(
              'SIP Service: Skipping duration update - condition not met');
        }

        return;
      }

      // First try to find if there's a connected call in CallsModel
      if (_callsModel != null) {
        for (int i = 0; i < _callsModel!.length; i++) {
          final call = _callsModel![i];
          if (call.myCallId == callId) {
            debugPrint(
                'SIP Service: Found matching connected call in CallsModel - using it');
            CallHistoryService.instance.addCallRecord(call);
            return;
          }
        }
      }

      // No existing call history found and no CallModel in CallsModel
      // This means the call was likely missed/rejected and not properly tracked
      debugPrint('SIP Service: Call $callId not found in history or CallsModel - likely missed/rejected');

      // For missed/rejected calls, we may not have complete data
      // The CDR system should rely on the terminated event's status code
      // to determine if this was a missed call vs rejected call
      debugPrint('SIP Service: Termination status code: $statusCode - letting CDR handle based on status');
    } catch (e) {
      debugPrint(
          'SIP Service: Error adding call to history on termination: $e');
    }
  }

  void _addConnectedCallToHistory(int callId) {
    try {
      debugPrint('SIP Service: Adding connected call to history - callId: $callId');

      // Check if already exists to prevent duplicates
      final existingCall = CallHistoryService.instance.getCallById(callId);
      if (existingCall != null) {
        debugPrint(
            'SIP Service: Connected call $callId already exists in CDR history, skipping');
        return;
      }

      // Find the connected call in CallsModel (should be there now)
      if (_callsModel != null) {
        debugPrint(
            'SIP Service: CallsModel has ${_callsModel!.length} calls during connected event');
        for (int i = 0; i < _callsModel!.length; i++) {
          final call = _callsModel![i];
          debugPrint(
              'SIP Service: CallsModel[$i] - ID: ${call.myCallId}, Remote: ${call.remoteExt}');
          if (call.myCallId == callId) {
            debugPrint(
                'SIP Service: Found connected call in CallsModel - adding to CDR and storing for duration tracking');

            // Store this CallModel for duration tracking at termination
            _connectedCallModel = call;
            debugPrint(
                'SIP Service: Stored CallModel in _connectedCallModel for duration tracking');

            CallHistoryService.instance.addCallRecord(call);
            debugPrint(
                'SIP Service: Successfully added connected call $callId to CDR history');
            return;
          }
        }
      }

      debugPrint(
          'SIP Service: Connected call $callId not found in CallsModel - may be added later');

      // If we can't find the call in CallsModel, we can't create a proper CallModel
      // This case should be rare since Siprix SDK should have the call in CallsModel after connection
      debugPrint('SIP Service: Unable to create CallModel without data from CallsModel - skipping CDR entry');
    } catch (e) {
      debugPrint('SIP Service: Error adding connected call to history: $e');
    }
  }


  void _onModelsChanged() {
    debugPrint(
        '🔥 SIP Service: Models changed - checking registration status and call states...');

    try {
      if (_accountsModel != null && _accountsModel!.length > 0) {
        for (int i = 0; i < _accountsModel!.length; i++) {
          final account = _accountsModel![i];
          debugPrint(
              '🔥 SIP Service: Account $i - Extension: ${account.sipExtension}, State: ${account.regState}, Text: ${account.regText}');
        }

        // Check overall registration status
        final registered = isRegistered;
        debugPrint('🔥 SIP Service: Overall registration status: $registered');
      } else {
        debugPrint('🔥 SIP Service: No accounts available');
      }

      // Check for call state changes (this will detect OnCallAcceptNotif events)
    } catch (e) {
      debugPrint('🔥 SIP Service: Error checking registration status: $e');
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

  // Direct SDK event handlers

  // Direct SDK event handlers
  void _onCallTerminatedDirect(int callId, int statusCode) {
    debugPrint(
        'SIP Service: Direct call terminated - callId: $callId, statusCode: $statusCode');

    // IMPORTANT: Forward the terminated event to CallsModel for proper cleanup
    if (_callsModel != null) {
      debugPrint('SIP Service: Forwarding terminated event to CallsModel for cleanup');
      _callsModel!.onTerminated(callId, statusCode);

      // Debug: Check CallsModel state after cleanup
      debugPrint('SIP Service: CallsModel has ${_callsModel!.length} calls after cleanup');
      for (int i = 0; i < _callsModel!.length; i++) {
        final call = _callsModel![i];
        debugPrint('SIP Service: Remaining CallsModel[$i] - ID: ${call.myCallId}, Remote: ${call.remoteExt}');
      }
    }

    // Add call to history when terminated - try to find CallModel or use current call info
    _addCallToHistoryOnTermination(callId, statusCode);

    // Clear the stored Siprix call ID and connected CallModel
    _connectedCallModel = null;

    // Clear caller info cache for ended calls to prevent memory leaks
    _callerInfoCache.clear();

    // Stop call duration timer when call ends
    _stopCallDurationTimer();

    // Siprix built-in CallKit will handle call termination automatically

    // Clear the call state and hangup flag
    _updateCurrentCall(null);
    Timer(const Duration(milliseconds: 100), () {
      _isHangingUp = false;
      debugPrint('SIP Service: Call cleanup completed - audio session should be free');
    });
  }

  void _onCallSwitchedDirect(int callId) {
    debugPrint('SIP Service: Direct call switched - callId: $callId');

    // Forward the switched event to CallsModel and sync our current call
    if (_callsModel != null) {
      _callsModel!.onSwitched(callId);
      debugPrint('SIP Service: Forwarded switched event to CallsModel');

      // Sync our current call state from CallsModel
      _syncCurrentCallFromModel();
    }
  }

  void _onCallProceeding(int callId, String response) {
    debugPrint('SIP Service: Call proceeding - callId: $callId, response: $response');

    // Ignore proceeding events if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring proceeding event - hangup in progress');
      return;
    }

    // Just forward to CallsModel - it will handle the state updates
    // No need for custom logic, let Siprix SDK handle this
  }

  void _onCallAcceptNotif(int callId, bool withVideo) {
    debugPrint('🔥 SIP Service: ========== ONCALLACCEPTNOTIF EVENT ==========');
    debugPrint(
        '🔥 SIP Service: OnCallAcceptNotif triggered - callId: $callId, withVideo: $withVideo');
    debugPrint('🔥 SIP Service: User accepted call from Android notification');


    // This event means the user accepted the call from the notification
    // We need to actually answer the SIP call (let the answer flow handle state and navigation)
    final call = _findCallByCallId(callId);
    if (call != null) {
      debugPrint(
          '🔥 SIP Service: Found call $callId in CallsModel, answering SIP call now');

      // Actually answer the SIP call without pre-setting state
      Future.delayed(const Duration(milliseconds: 50)).then((_) async {
        try {
          debugPrint(
              '🔥 SIP Service: Performing SIP answer for notification acceptance');
          await answerCall(callId.toString());
          debugPrint(
              '🔥 SIP Service: SIP call answered successfully from notification');
        } catch (e) {
          debugPrint(
              '🔥 SIP Service: Error answering SIP call from notification: $e');
        }
      });
    } else {
      debugPrint(
          '🔥 SIP Service: WARNING - AcceptNotif for unknown call ID: $callId');
    }
  }

  void _onCallConnected(int callId, String from, String to, bool withVideo) {
    debugPrint('🔥 SIP Service: ========== CALL CONNECTED EVENT ==========');
    debugPrint(
        '🔥 SIP Service: Call connected - callId: $callId, from: $from, to: $to, withVideo: $withVideo');
    debugPrint('🔥 SIP Service: Processing call event for callId: $callId');
    debugPrint('🔥 SIP Service: Is hanging up: $_isHangingUp');

    // Ignore connected events if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint(
          '🔥 SIP Service: Ignoring connected event - hangup in progress');
      return;
    }

    // Add connected calls to history with a small delay to allow CallsModel to populate
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      _addConnectedCallToHistory(callId);
    });

    // Find the call in CallsModel and sync our current call state
    final call = _findCallByCallId(callId);
    if (call != null) {
      debugPrint('SIP Service: Found call in CallsModel - state: ${call.state}, isConnected: ${call.isConnected}');

      // Parse caller information
      final callerInfo = _getCachedCallerInfo(from);
      final callerName = callerInfo['name']!;
      final callerNumber = callerInfo['number']!;

      // Immediately update to answered state for UI responsiveness
      final connectedCallInfo = CallInfo(
        id: callId.toString(),
        remoteNumber: callerNumber,
        remoteName: callerName,
        state: AppCallState.answered,
        startTime: DateTime.now(),
        isIncoming: call.isIncoming,
        isConnectedWithAudio: call.isConnected,
      );
      _updateCurrentCall(connectedCallInfo);
      debugPrint('SIP Service: Immediately updated call $callId to answered state for UI');

      // Give CallsModel a moment to process the connected event, then sync with accurate data
      Future.delayed(const Duration(milliseconds: 100), () {
        _syncCurrentCallFromModel();
        debugPrint('SIP Service: Synced current call state with connected CallModel (delayed)');

        // Start periodic sync for timer updates if not already running
        _startCallDurationTimer();
      });

      // Navigate to OnCallScreen when call is connected/answered
      // Built-in Siprix CallKit handles CallKit UI, we handle app navigation
      if (call.isIncoming) {
        debugPrint('SIP Service: Incoming call connected, navigating to OnCallScreen');
        NavigationService.goToInCall(
          call.myCallId.toString(),
          phoneNumber: call.remoteExt,
          contactName: call.displName.isNotEmpty ? call.displName : null,
        );
      } else {
        debugPrint('SIP Service: Outgoing call connected, OnCallScreen should already be visible');
      }
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

  void _onCallIncomingDirect(
      int callId, int accId, bool withVideo, String from, String to) {
    debugPrint(
        'SIP Service: Incoming call - callId: $callId, from: $from, to: $to, withVideo: $withVideo');

    // Ignore incoming calls if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint('SIP Service: Ignoring incoming call - hangup in progress');
      return;
    }

    // Get cached caller information (parsed using builtin SDK functions)
    final callerInfo = _getCachedCallerInfo(from);
    final callerName = callerInfo['name']!;
    final callerNumber = callerInfo['number']!;

    // Store the Siprix call ID for later operations

    // CRITICAL FIX: Call onIncomingSip to add the call to CallsModel
    // This is essential for the call to appear in CallsModel for hold operations
    if (_callsModel != null) {
      debugPrint('🔥 SIP Service: Adding incoming call to CallsModel via onIncomingSip');
      debugPrint('🔥 SIP Service: CallsModel length BEFORE onIncomingSip: ${_callsModel!.length}');

      _callsModel!.onIncomingSip(callId, accId, withVideo, from, to);

      debugPrint('🔥 SIP Service: CallsModel length AFTER onIncomingSip: ${_callsModel!.length}');
      debugPrint('🔥 SIP Service: Successfully added incoming call to CallsModel');
    } else {
      debugPrint('🔥 SIP Service: ERROR - CallsModel is null, cannot add incoming call');
    }

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

    // Debug: Check if incoming call gets added to CallsModel
    debugPrint(
        'SIP Service: After incoming call setup - CallsModel has ${_callsModel?.length ?? 0} calls');
    if (_callsModel != null) {
      for (int i = 0; i < _callsModel!.length; i++) {
        final call = _callsModel![i];
        debugPrint(
            'SIP Service: CallsModel[$i] - ID: ${call.myCallId}, Remote: ${call.remoteExt}');
      }
    }

    // Check if this call should be auto-answered (notification acceptance)
    if (_autoAnswerCallId == callId.toString()) {
      debugPrint('🔥 SIP Service: ========== AUTO-ANSWER DETECTED ==========');
      debugPrint(
          '🔥 SIP Service: Call $callId matches auto-answer flag, answering immediately');

      // Clear the auto-answer flag
      clearAutoAnswerCall();

      // Answer the call immediately with a small delay
      Future.delayed(const Duration(milliseconds: 100)).then((_) async {
        try {
          await answerCall(callId.toString());
          debugPrint(
              '🔥 SIP Service: Auto-answer successful for notification acceptance');
        } catch (e) {
          debugPrint('🔥 SIP Service: Auto-answer failed: $e');
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
    debugPrint('🔥 SIP Service: Setting auto-answer for callId: $callId');
    _autoAnswerCallId = callId;
    _autoAnswerCallerName = callerName;
    _autoAnswerCallerNumber = callerNumber;
  }

  /// Clear auto-answer flag
  void clearAutoAnswerCall() {
    debugPrint('🔥 SIP Service: Clearing auto-answer flag');
    _autoAnswerCallId = null;
    _autoAnswerCallerName = null;
    _autoAnswerCallerNumber = null;
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

      // Use CallsModel to make the call (it returns void but adds call to CallsModel)
      await _callsModel!.invite(destination);
      debugPrint(
          'Make call: INVITE sent successfully via Siprix SDK to $number');

      // Get the newly created call ID from the last element in CallsModel (since it gets appended)
      String? newCallId;
      if (_callsModel!.length > 0) {
        final lastCall = _callsModel![_callsModel!.length - 1];
        newCallId = lastCall.myCallId.toString();
        debugPrint('Make call: Got new call ID from last element in CallsModel: $newCallId');
      } else {
        debugPrint('Make call: Warning - CallsModel is empty, no call ID available');
      }

      debugPrint('Make call: Call initiated successfully via Siprix SDK');
      return newCallId; // Return the actual Siprix call ID from CallsModel
    } catch (e) {
      debugPrint('Make call failed: $e');
      return null;
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      debugPrint('SIP Service: Answering call: $callId');

      if (_callsModel == null) {
        debugPrint('Answer call failed: CallsModel not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Answer call failed: Invalid call ID format');
        return;
      }

      // Find the call in CallsModel and use its accept method
      final targetCall = _findCallByCallId(intCallId);
      if (targetCall == null) {
        debugPrint('Answer call failed: Call not found in CallsModel');
        return;
      }

      // Use CallModel's built-in accept method (much simpler!)
      await targetCall.accept(false); // false = audio only
      debugPrint('SIP Service: Call accepted successfully');
    } catch (e) {
      debugPrint('Answer call failed: $e');
      rethrow;
    }
  }

  Future<void> hangupCall(String callId) async {
    try {
      debugPrint('SIP Service: Hanging up call: $callId');

      if (_callsModel == null) {
        debugPrint('Hangup failed: CallsModel not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Hangup failed: Invalid call ID format');
        return;
      }

      // Find the call in CallsModel and use its bye method
      final targetCall = _findCallByCallId(intCallId) ?? _callsModel!.switchedCall();
      if (targetCall == null) {
        debugPrint('Hangup failed: No call found to terminate');
        return;
      }

      // Use CallModel's built-in bye method (much simpler!)
      await targetCall.bye();
      debugPrint('SIP Service: Call hung up successfully');
    } catch (e) {
      debugPrint('Hangup call failed: $e');
      rethrow;
    }
  }

  Future<void> holdCall(String callId) async {
    try {
      debugPrint('SIP Service: Holding call: $callId');

      if (_callsModel == null) {
        debugPrint('Hold call failed: CallsModel not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Hold call failed: Invalid call ID format');
        return;
      }

      // Find the call in CallsModel and use its hold method
      final targetCall = _findCallByCallId(intCallId);
      if (targetCall == null) {
        debugPrint('Hold call failed: Call not found in CallsModel');
        throw Exception('Call not found');
      }

      // Use CallModel's built-in hold method (Siprix handles state validation internally)
      await targetCall.hold();
      debugPrint('SIP Service: Call hold toggled successfully');
    } catch (e) {
      debugPrint('Hold call failed: $e');
      rethrow;
    }
  }

  Future<void> unholdCall(String callId) async {
    try {
      debugPrint('SIP Service: Unholding call: $callId');

      if (_callsModel == null) {
        debugPrint('Unhold call failed: CallsModel not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Unhold call failed: Invalid call ID format');
        return;
      }

      // Find the call in CallsModel and use its hold method (it toggles)
      final targetCall = _findCallByCallId(intCallId);
      if (targetCall == null) {
        debugPrint('Unhold call failed: Call not found in CallsModel');
        throw Exception('Call not found');
      }

      // Use CallModel's built-in hold method (it toggles hold state)
      await targetCall.hold();
      debugPrint('SIP Service: Call unhold toggled successfully');
    } catch (e) {
      debugPrint('Unhold call failed: $e');
      rethrow;
    }
  }

  Future<void> muteCall(String callId, bool mute) async {
    try {
      debugPrint('SIP Service: ${mute ? 'Muting' : 'Unmuting'} call: $callId');

      if (_callsModel == null) {
        debugPrint('Mute failed: CallsModel not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Mute failed: Invalid call ID format');
        return;
      }

      // Find the call in CallsModel and use its muteMic method
      final targetCall = _findCallByCallId(intCallId) ?? _callsModel!.switchedCall();
      if (targetCall == null) {
        debugPrint('Mute failed: No call found to mute');
        throw Exception('No active call available for muting');
      }

      // Use CallModel's built-in muteMic method (much simpler!)
      await targetCall.muteMic(mute);
      debugPrint('SIP Service: Call ${mute ? 'muted' : 'unmuted'} successfully');
    } catch (e) {
      debugPrint('Mute call failed: $e');
      rethrow;
    }
  }

  Future<void> setSpeaker(String callId, bool speaker) async {
    try {
      debugPrint('Set speaker: $callId, speaker: $speaker');

      if (Platform.isIOS) {
        // On iOS with CallKit, don't interfere with audio routing
        debugPrint('iOS CallKit: Audio routing handled by system');
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

    } catch (e) {
      debugPrint('Set speaker failed: $e');
    }
  }

  // Enhanced audio device management methods

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

        // Audio device set successfully
        final devices = _devicesModel!.playout;
        if (deviceIndex < devices.length) {
          final device = devices[deviceIndex];
          debugPrint('Android: Audio device set to ${device.name}');
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

  // Note: CallKit handles audio session management automatically
  // No custom audio session configuration needed

  // Audio device management removed - CallKit handles everything
  // Custom audio device manipulation causes interruptions and conflicts with CallKit

  // Legacy method for backward compatibility

  // Legacy method for backward compatibility
  List<MediaDevice> get availableAudioDevices {
    return _devicesModel?.playout ?? [];
  }

  int get currentAudioDeviceIndex {
    return _devicesModel?.playoutIndex ?? -1;
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
      final appCallState = _mapCallStateToAppCallState(activeCall.state);
      debugPrint('SIP Service: Syncing call - CallModel state: ${activeCall.state}, mapped to: $appCallState');
      debugPrint('SIP Service: CallModel startTime: ${activeCall.startTime}, isConnected: ${activeCall.isConnected}');

      final callInfo = CallInfo(
        id: activeCall.myCallId.toString(),
        remoteNumber: activeCall.remoteExt,
        remoteName: activeCall.displName.isNotEmpty ? activeCall.displName : activeCall.remoteExt,
        state: appCallState,
        startTime: activeCall.startTime,
        isIncoming: activeCall.isIncoming,
        isMuted: activeCall.isMicMuted,
        isSpeakerOn: false, // Track separately if needed
        isOnHold: activeCall.isLocalHold,
      );
      _updateCurrentCall(callInfo);
    } else {
      _updateCurrentCall(null);
    }
  }

  /// Start periodic timer to update call duration
  void _startCallDurationTimer() {
    // Cancel existing timer if running
    _callDurationTimer?.cancel();

    // Start new timer that syncs every second during active calls
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (hasActiveCall && _callsModel?.switchedCall() != null) {
        _syncCurrentCallFromModel();
      } else {
        // Stop timer when call ends or changes state
        _stopCallDurationTimer();
      }
    });

    debugPrint('SIP Service: Started call duration timer');
  }

  /// Stop the call duration timer
  void _stopCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    debugPrint('SIP Service: Stopped call duration timer');
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

  /// Ensure audio session is working when app resumes with active call

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
            if (hasActiveCall) {
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

}
