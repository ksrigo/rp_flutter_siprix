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

      // Set up a periodic check for background call acceptance
      _setupBackgroundAcceptanceMonitor();

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
    _callsModel?.onNewIncomingCall = _onNewIncomingCall;

    debugPrint('SIP Service: Event listeners configured');
  }

  void _setupBackgroundAcceptanceMonitor() {
    debugPrint('SIP Service: Background acceptance monitor configured');
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
      if (_currentCall == null) {
        debugPrint(
            'SIP Service: Cannot add call to history - no current call data');
        return;
      }

      final currentCallState = _currentCall?.state;
      debugPrint(
          'SIP Service: Adding call to history on termination - callId: $callId, statusCode: $statusCode, currentCallState: $currentCallState');

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
            'SIP Service: Duration update check - hasConnectedModel: $hasConnectedModel, modelCallId: $modelCallId, targetCallId: $callId, callIdsMatch: $callIdsMatch, currentState: ${_currentCall!.state}');

        // If we have a connected model for this call, it means it was answered at some point
        if (hasConnectedModel && callIdsMatch) {
          debugPrint(
              'SIP Service: Updating existing answered call with final duration');

          // Try to calculate duration ourselves since CallModel.calcDuration() might not be working properly
          final callStartTime = _currentCall?.startTime ?? DateTime.now();
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

      // No CallModel found - determine if this was answered or missed
      final wasAnswered = _currentCall!.state == AppCallState.answered;
      debugPrint(
          'SIP Service: No CallModel in CallsModel - Call was ${wasAnswered ? "ANSWERED" : "MISSED/REJECTED"}');

      if (wasAnswered) {
        debugPrint(
            'SIP Service: Answered call should have been handled above - this should not happen');
        return; // Answered calls are handled above when call already exists
      }

      debugPrint('SIP Service: Creating CallModel for missed/rejected call');

      if (_accountsModel != null) {
        try {
          // Get account URI for the call
          String accUri = '';
          if (_accountsModel!.length > 0) {
            accUri = _accountsModel![0].uri; // Use first account's URI
          }

          // Create a new CallModel with our call data
          final callModel = CallModel(
            callId, // myCallId
            accUri, // accUri
            _currentCall!.remoteNumber, // remoteExt
            _currentCall!.isIncoming, // isIncoming
            false, // hasSecureMedia
            false, // hasVideo
          );

          // Set display name if available
          if (_currentCall!.remoteName.isNotEmpty &&
              _currentCall!.remoteName != _currentCall!.remoteNumber) {
            callModel.displName = _currentCall!.remoteName;
          }

          // Check if this was an answered call
          final wasConnected = _currentCall!.state == AppCallState.answered;
          debugPrint(
              'SIP Service: Created CallModel - callId: $callId, remote: ${_currentCall!.remoteNumber}, incoming: ${_currentCall!.isIncoming}, wasConnected: $wasConnected');

          // Add to CDR using our created CallModel
          CallHistoryService.instance.addCallRecord(callModel);
          debugPrint(
              'SIP Service: Successfully added created CallModel to CDR history');
        } catch (e) {
          debugPrint('SIP Service: Error creating CallModel: $e');
          debugPrint(
              'SIP Service: Cannot track this call in history without proper CallModel creation');
        }
      } else {
        debugPrint(
            'SIP Service: AccountsModel is null - cannot create CallModel');
      }
    } catch (e) {
      debugPrint(
          'SIP Service: Error adding call to history on termination: $e');
    }
  }

  void _addConnectedCallToHistory(int callId) {
    try {
      final isIncoming = _currentCall?.isIncoming ?? false;
      debugPrint(
          'SIP Service: Adding connected call to history - callId: $callId, isIncoming: $isIncoming');

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
          'SIP Service: Connected call $callId not found in CallsModel - creating connected CallModel');

      // Create CallModel for connected call and store it
      if (_accountsModel != null && _currentCall != null) {
        try {
          // Get account URI for the call
          String accUri = '';
          if (_accountsModel!.length > 0) {
            accUri = _accountsModel![0].uri;
          }

          // Create CallModel for connected call
          _connectedCallModel = CallModel(
            callId, // myCallId
            accUri, // accUri
            _currentCall!.remoteNumber, // remoteExt
            _currentCall!.isIncoming, // isIncoming
            false, // hasSecureMedia
            false, // hasVideo
          );

          // Set display name if available
          if (_currentCall!.remoteName.isNotEmpty &&
              _currentCall!.remoteName != _currentCall!.remoteNumber) {
            _connectedCallModel!.displName = _currentCall!.remoteName;
          }

          // Mark the synthesized CallModel as connected so CDR history categorizes it correctly
          // This will set the startTime internally and mark it as connected
          _connectedCallModel!.onConnected('', '', false);

          debugPrint(
              'SIP Service: Called onConnected() - CallModel startTime: ${_connectedCallModel!.startTime}');

          debugPrint(
              'SIP Service: Created and stored connected CallModel for callId: $callId');

          // Add to CDR immediately
          CallHistoryService.instance.addCallRecord(_connectedCallModel!);
          debugPrint(
              'SIP Service: Successfully added connected CallModel to CDR history');
        } catch (e) {
          debugPrint('SIP Service: Error creating connected CallModel: $e');
        }
      }
    } catch (e) {
      debugPrint('SIP Service: Error adding connected call to history: $e');
    }
  }

  void _startBackgroundAcceptanceTimer() {
    // Stop any existing timer
    _stopBackgroundAcceptanceTimer();

    // Start a timer to check for background call acceptance
    _backgroundAcceptanceTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      // Only run if we have an active call that's ringing
      if (_currentCall != null && _currentCall!.state == AppCallState.ringing) {
        _checkForBackgroundAcceptance();
      } else {
        // Stop the timer if there's no ringing call
        _stopBackgroundAcceptanceTimer();
      }
    });

    debugPrint(
        '🔥 SIP Service: Started background acceptance monitoring timer');
  }

  void _stopBackgroundAcceptanceTimer() {
    _backgroundAcceptanceTimer?.cancel();
    _backgroundAcceptanceTimer = null;
  }

  void _checkForBackgroundAcceptance() {
    try {
      if (_callsModel == null || _currentCall == null) return;

      // Get call model information
      final callCount = _callsModel!.length;
      final activeCall = _callsModel!.switchedCall();
      final switchedCallId = _callsModel!.switchedCallId;

      debugPrint(
          '🔥 SIP Service: Checking background acceptance - call count: $callCount, current state: ${_currentCall!.state}');
      debugPrint(
          '🔥 SIP Service: Active call from model: ${activeCall?.myCallId}, switched ID: $switchedCallId');

      if (_currentCall!.state == AppCallState.ringing) {
        // Check multiple conditions for background acceptance detection
        bool backgroundAcceptanceDetected = false;
        String detectionReason = '';

        // Method 1: Check if CallsModel shows connected state
        if (activeCall != null && activeCall.isConnected) {
          backgroundAcceptanceDetected = true;
          detectionReason = 'Active call shows connected state';
        }

        // Method 2: Check if there's a switched call that matches our call
        else if (switchedCallId > 0) {
          final ourCallId = int.tryParse(_currentCall!.id);
          if (ourCallId != null && switchedCallId == ourCallId) {
            backgroundAcceptanceDetected = true;
            detectionReason = 'Switched call ID matches our call';
          }
        }

        if (backgroundAcceptanceDetected) {
          debugPrint(
              '🔥 SIP Service: ========== BACKGROUND ACCEPTANCE DETECTED ==========');
          debugPrint('🔥 SIP Service: Detection reason: $detectionReason');
          debugPrint(
              '🔥 SIP Service: ATTEMPTING to trigger connected event for background acceptance');

          // Stop the timer since we found the issue
          _stopBackgroundAcceptanceTimer();

          // Get the call ID to trigger connected event
          final callIdInt = int.tryParse(_currentCall!.id);
          if (callIdInt != null) {
            // Manually trigger the connected event
            _onCallConnected(callIdInt, _currentCall!.remoteName,
                _currentCall!.remoteNumber, false // Assuming audio call
                );
          }
        }
      }
    } catch (e) {
      debugPrint('🔥 SIP Service: Error checking background acceptance: $e');
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
      _checkCallModelForConnectedState();
    } catch (e) {
      debugPrint('🔥 SIP Service: Error checking registration status: $e');
    }
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

  void _checkCallModelForConnectedState() {
    if (_callsModel == null) return;

    try {
      // Get the currently switched/active call from the calls model
      final activeCall = _callsModel!.switchedCall();
      final switchedCallId = _callsModel!.switchedCallId;
      final callsCount = _callsModel!.length;

      debugPrint(
          '🔥 SIP Service: Call model check - Active call: ${activeCall?.myCallId}, switched ID: $switchedCallId, total calls: $callsCount');

      // Check if we have a current call in ringing state but the model shows connected state
      if (_currentCall != null && _currentCall!.state == AppCallState.ringing) {
        if (activeCall != null && activeCall.isConnected) {
          debugPrint(
              '🔥 SIP Service: ========== BACKGROUND ACCEPTANCE DETECTED ==========');
          debugPrint(
              '🔥 SIP Service: Call model shows connected but our state is still ringing');
          debugPrint(
              '🔥 SIP Service: This indicates OnCallAcceptNotif was processed but connected event missed');

          // Extract call details
          final callId = activeCall.myCallId;
          final remoteExt = activeCall.remoteExt ?? 'Unknown';

          debugPrint(
              '🔥 SIP Service: Triggering missed connected event - ID: $callId, Remote: $remoteExt');

          // Stop the background acceptance timer
          _stopBackgroundAcceptanceTimer();

          // Manually trigger the connected event
          _onCallConnected(callId, remoteExt, remoteExt, false);
        }
      }
    } catch (e) {
      debugPrint(
          '🔥 SIP Service: Error checking call model for connected state: $e');
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

  // Direct SDK event handlers
  void _onCallTerminatedDirect(int callId, int statusCode) {
    debugPrint(
        'SIP Service: Direct call terminated - callId: $callId, statusCode: $statusCode');

    // Add call to history when terminated - try to find CallModel or use current call info
    _addCallToHistoryOnTermination(callId, statusCode);

    // Clear the stored Siprix call ID and connected CallModel
    _currentSiprixCallId = null;
    _connectedCallModel = null;

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

  void _onCallAcceptNotif(int callId, bool withVideo) {
    debugPrint('🔥 SIP Service: ========== ONCALLACCEPTNOTIF EVENT ==========');
    debugPrint(
        '🔥 SIP Service: OnCallAcceptNotif triggered - callId: $callId, withVideo: $withVideo');
    debugPrint('🔥 SIP Service: User accepted call from Android notification');

    // Stop background acceptance timer since we got the accept notification
    _stopBackgroundAcceptanceTimer();

    // This event means the user accepted the call from the notification
    // We need to actually answer the SIP call (let the answer flow handle state and navigation)
    if (_currentCall != null && _currentCall!.id == callId.toString()) {
      debugPrint(
          '🔥 SIP Service: Call matches current call, answering SIP call now');

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
    debugPrint('🔥 SIP Service: Current call ID: ${_currentCall?.id}');
    debugPrint(
        '🔥 SIP Service: Current call incoming: ${_currentCall?.isIncoming}');
    debugPrint('🔥 SIP Service: Is hanging up: $_isHangingUp');

    // Ignore connected events if we're in the middle of hanging up
    if (_isHangingUp) {
      debugPrint(
          '🔥 SIP Service: Ignoring connected event - hangup in progress');
      return;
    }

    // Stop background acceptance timer since we got the connected event
    _stopBackgroundAcceptanceTimer();

    // Add connected calls to history with a small delay to allow CallsModel to populate
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      _addConnectedCallToHistory(callId);
    });
    debugPrint(
        '🔥 SIP Service: Stopped background acceptance timer - call connected');

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
    } else {
      debugPrint(
          '🔥 SIP Service: WARNING - Call connected but no current call in our state');
      debugPrint(
          '🔥 SIP Service: This might be a background acceptance scenario');

      // Try to create a minimal call info from the connected event
      final callInfo = CallInfo(
        id: callId.toString(),
        remoteNumber: to.isNotEmpty ? to : from,
        remoteName: from.isNotEmpty ? from : to,
        state: AppCallState.answered,
        startTime: DateTime.now(),
        isIncoming: true, // Assume incoming for background acceptance
        isConnectedWithAudio: true,
      );

      _updateCurrentCall(callInfo);

      debugPrint(
          '🔥 SIP Service: Created call info from connected event and navigating to OnCallScreen');
      NavigationService.goToInCall(
        callId.toString(),
        phoneNumber: callInfo.remoteNumber,
        contactName: callInfo.remoteName != callInfo.remoteNumber
            ? callInfo.remoteName
            : null,
      );
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

    // Start background acceptance monitoring for incoming calls
    _startBackgroundAcceptanceTimer();
    debugPrint(
        '🔥 SIP Service: Started background acceptance timer for incoming call: $callId');

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

  /// Ensure account uses only PCMU+DTMF codecs to prevent REINVITE audio delay

  /// Ensure account uses only PCMU+DTMF codecs to prevent REINVITE audio delay
  Future<void> _ensureSingleCodecConfiguration() async {
    try {
      debugPrint(
          'SIP Service: Ensuring single codec configuration (PCMU+DTMF only)');

      if (_accountsModel != null && _accountsModel!.length > 0) {
        // Get the selected account by index
        final selectedIndex = _accountsModel!.selAccountId != null
            ? 0
            : null; // Usually first account
        if (selectedIndex != null && selectedIndex < _accountsModel!.length) {
          final currentAccount = _accountsModel![selectedIndex];

          // Set only PCMU + DTMF codecs as recommended by Siprix developers
          currentAccount.aCodecs = [
            SiprixVoipSdk.kAudioCodecPCMU,
            SiprixVoipSdk.kAudioCodecDTMF
          ];

          // Update the account in the model
          await _accountsModel!.updateAccount(currentAccount);
          debugPrint(
              'SIP Service: ✅ Account updated with PCMU+DTMF codecs only');
          debugPrint(
              'SIP Service: This prevents REINVITE and eliminates 6s audio delay');
        } else {
          debugPrint(
              'SIP Service: ⚠️ Cannot update codecs - no current account found');
        }
      } else {
        debugPrint(
            'SIP Service: ⚠️ Cannot update codecs - accounts model not available or empty');
      }
    } catch (e) {
      debugPrint(
          'SIP Service: ❌ Error ensuring single codec configuration: $e');
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
      debugPrint('🔥 SipService: ========== ANSWER CALL STARTED ==========');
      debugPrint('🔥 SipService: Answer call: $callId');

      if (_callsModel == null || _siprixSdk == null) {
        debugPrint('Answer call failed: Models not initialized');
        return;
      }

      // Parse callId to integer first
      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Answer call failed: Invalid call ID format');
        return;
      }

      // Check if the call is already answered/connected (background acceptance)
      if (_currentCall != null && _currentCall!.id == callId) {
        if (_currentCall!.state == AppCallState.answered) {
          debugPrint(
              '🔥 Answer call: Call is already answered, navigating to in-call screen');
          // Navigate to in-call screen since call is already connected
          NavigationService.goToInCall(
            callId,
            phoneNumber: _currentCall!.remoteNumber,
            contactName: _currentCall!.remoteName != _currentCall!.remoteNumber
                ? _currentCall!.remoteName
                : null,
          );
          return;
        }

        // If we reach here, the call might be in an inconsistent state
        // Let's try to proceed with the normal answer flow, but catch any errors
        debugPrint(
            '🔥 Answer call: Proceeding with answer call attempt for current call');
      }

      // CallKit handles all audio session management automatically
      // Ensure audio session is properly configured before accepting call

      try {
        // Skip codec configuration during active calls to avoid "unfinished calls" error
        if (_callsModel?.length == 0) {
          // Only update codec configuration if no calls are active
          await _ensureSingleCodecConfiguration();
        } else {
          debugPrint(
              'Answer call: Skipping codec configuration - call is active');
        }

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

        // Check immediately if the call became connected after accept
        final activeCall = _callsModel?.switchedCall();
        if (activeCall != null && activeCall.isConnected) {
          debugPrint(
              '🔥 Answer call: Call connected immediately after accept - triggering connected event');
          _onCallConnected(intCallId, activeCall.remoteExt ?? 'Unknown',
              activeCall.remoteExt ?? 'Unknown', false);
        }
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

      // Add a follow-up check to ensure connected event is triggered
      Timer(const Duration(milliseconds: 500), () {
        if (_currentCall != null &&
            _currentCall!.state == AppCallState.answered) {
          final activeCall = _callsModel?.switchedCall();
          if (activeCall != null && activeCall.isConnected) {
            debugPrint(
                '🔥 Answer call: Follow-up check detected connected call - ensuring navigation');
            // Ensure the connected event is properly handled
            _onCallConnected(
                intCallId,
                activeCall.remoteExt ?? _currentCall!.remoteNumber,
                activeCall.remoteExt ?? _currentCall!.remoteNumber,
                false);
          }
        }
      });
    } catch (e) {
      debugPrint('Answer call failed: $e');
    }
  }

  Future<void> hangupCall(String callId) async {
    try {
      debugPrint('🔥 SipService: ========== HANGUP CALL STARTED ==========');
      debugPrint('🔥 SipService: Hangup call: $callId');

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

      if (_siprixSdk == null || _callsModel == null) {
        debugPrint('Hold call failed: SDK or calls model not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Hold call failed: Invalid call ID format');
        return;
      }

      // Use the stored Siprix call ID if available
      final siprixCallId = _currentSiprixCallId ?? intCallId;

      debugPrint('Hold call: Using Siprix call ID: $siprixCallId');

      // Check current hold state first
      final currentHoldStateInt = await _siprixSdk!.getHoldState(siprixCallId);
      final currentHoldState = currentHoldStateInt != null
          ? HoldState.from(currentHoldStateInt)
          : HoldState.none;
      debugPrint('Hold call: Current hold state: $currentHoldState');

      // Only call hold() if not already on hold (since it toggles)
      if (currentHoldState == HoldState.none) {
        await _siprixSdk!.hold(siprixCallId);
        debugPrint('Hold call: Successfully put call on hold');

        // Update call state
        _updateCurrentCall(_currentCall?.copyWith(
          state: AppCallState.held,
          isOnHold: true,
        ));
      } else {
        debugPrint('Hold call: Call is already on hold');
      }
    } catch (e) {
      debugPrint('Hold call failed: $e');
      throw e;
    }
  }

  Future<void> unholdCall(String callId) async {
    try {
      debugPrint('Unhold call: $callId');

      if (_siprixSdk == null || _callsModel == null) {
        debugPrint('Unhold call failed: SDK or calls model not initialized');
        return;
      }

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        debugPrint('Unhold call failed: Invalid call ID format');
        return;
      }

      // Use the stored Siprix call ID if available
      final siprixCallId = _currentSiprixCallId ?? intCallId;

      debugPrint('Unhold call: Using Siprix call ID: $siprixCallId');

      // Check current hold state first
      final currentHoldStateInt = await _siprixSdk!.getHoldState(siprixCallId);
      final currentHoldState = currentHoldStateInt != null
          ? HoldState.from(currentHoldStateInt)
          : HoldState.none;
      debugPrint('Unhold call: Current hold state: $currentHoldState');

      // Only call hold() if currently on hold (since it toggles)
      if (currentHoldState != HoldState.none) {
        await _siprixSdk!.hold(siprixCallId);
        debugPrint('Unhold call: Successfully resumed call');

        // Update call state
        _updateCurrentCall(_currentCall?.copyWith(
          state: AppCallState.answered,
          isOnHold: false,
        ));
      } else {
        debugPrint('Unhold call: Call is not on hold');
      }
    } catch (e) {
      debugPrint('Unhold call failed: $e');
      throw e;
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
}
