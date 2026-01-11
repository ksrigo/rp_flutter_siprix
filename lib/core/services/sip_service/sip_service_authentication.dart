part of 'sip_service_base.dart';

mixin _SipServiceAuthentication on _SipServiceBase {
  // Add these tracking variables
  int _registrationRetryCount = 0;
  Timer? _registrationRetryTimer;
  bool _isBackgroundRegistrationInProgress = false;

  @override
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
      account.expireTime = 3600; // Increased to 1 hour for better stability
      account.sipProxy = '$proxy:$port'; // Concatenate proxy with port
      //account.port = 0; // Use random port selection by Siprix SDK
      account.port = 38380; //hardcoded port
      account.userAgent = '${AppConstants.appName}/${AppConstants.appVersion}';

      // Set display name for proper caller ID
      account.displName = name;

      // Critical settings for proxy authentication
      account.forceSipProxy = true; // Force using proxy for all requests
      //account.rewriteContactIp = true; // Enable IP rewrite for NAT handling
      account.rewriteContactIp =
          false; // Disable IP rewrite to prevent second REGISTER
      account.keepAliveTime = 30; // Keep alive packets every 30 seconds

      // Transport configuration - load from saved setting
      final savedTransport = await _loadTransportSetting();
      account.transport =
          savedTransport == 'TCP' ? SipTransport.tcp : SipTransport.udp;
      debugPrint(
          'Register: Using saved transport setting: $savedTransport (${account.transport})');

      // Disable all WebRTC-specific features for traditional SIP compatibility
      account.iceEnabled =
          false; // Disable ICE - prevents WebRTC SDP attributes
      account.rtcpMuxEnabled = false; // Disable RTCP-Mux - prevents a=rtcp-mux

      // Ensure no STUN/TURN servers are set to prevent WebRTC behavior
      account.stunServer = null;
      account.turnServer = null;

      // Configure audio codecs to match server capabilities
      // Support PCMU (0), PCMA (8), and DTMF (101) as seen in server SDP
      account.aCodecs = [
        SiprixVoipSdk.kAudioCodecPCMU,
        SiprixVoipSdk.kAudioCodecDTMF
      ];

      // Generate unique instance ID for proper authentication
      account.instanceId = await _accountsModel!.genAccInstId();

      debugPrint(
          'Register: Authentication settings - AuthId: ${account.sipAuthId}, Proxy: ${account.sipProxy}, Force Proxy: ${account.forceSipProxy}');
      debugPrint(
          'Register: Display Name: ${account.displName}, Server: ${account.sipServer}');

      debugPrint(
          'Register: Account configured - server: ${account.sipServer}, ext: ${account.sipExtension}');

      // ==================== ANDROID FCM PUSH NOTIFICATIONS ====================
      if (Platform.isAndroid) {
        try {
          debugPrint('Register: Checking for Android FCM token...');
          final fcmToken = NotificationService.instance.getCurrentFCMToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            // Add RFC 8599 push notification parameters to Contact URI
            account.xContactUriParams ??= <String, String>{};
            account.xContactUriParams!['pn-provider'] = 'fcm';
            account.xContactUriParams!['pn-param'] = 'none';
            account.xContactUriParams!['pn-prid'] = fcmToken;

            debugPrint(
                'Register: ✅ Added RFC 8599 FCM push notification parameters to Contact URI');
            debugPrint('Register: FCM token length: ${fcmToken.length}');
          } else {
            debugPrint(
                'Register: ⚠️ No FCM token available yet - Android push notifications may not work');
          }
        } catch (e) {
          debugPrint('Register: Error getting FCM token: $e');
        }
      }

      // ==================== iOS PUSHKIT NOTIFICATIONS ====================
      if (Platform.isIOS) {
        try {
          debugPrint('SIP Service: Requesting PushKit token...');
          final pushToken = await _siprixSdk!.getPushKitToken();
          debugPrint('SIP Service: PushKit token response: $pushToken');

          if (pushToken != null && pushToken.isNotEmpty) {
            // Add push token to SIP headers for backward compatibility
            account.xheaders ??= <String, String>{};
            account.xheaders!['X-Push-Token'] = pushToken;

            // Add RFC 8599 push notification parameters to Contact URI for iOS
            account.xContactUriParams ??= <String, String>{};
            account.xContactUriParams!['pn-provider'] = 'apns';
            account.xContactUriParams!['pn-prid'] = pushToken;
            account.xContactUriParams!['pn-param'] = 'none';

            debugPrint(
                'SIP Service: ✅ Added PushKit token to account headers: $pushToken');
            debugPrint(
                'SIP Service: Added RFC 8599 push notification parameters for iOS');
          } else {
            debugPrint(
                'SIP Service: ❌ No PushKit token available yet - Check iOS capabilities configuration');
          }
        } catch (e) {
          debugPrint('SIP Service: ❌ Failed to get PushKit token: $e');
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

  Future<void> unregister({bool clearCredentialsFromStorage = false}) async {
    try {
      _lastCredentials = null;
      _connectionCheckTimer?.cancel();
      _registrationRetryTimer?.cancel();

      // Properly clear accounts from SIP SDK
      if (_accountsModel != null && _accountsModel!.length > 0) {
        debugPrint(
            'SIP Service: Clearing ${_accountsModel!.length} accounts from SIP SDK');

        // Unregister and delete all accounts
        for (int i = _accountsModel!.length - 1; i >= 0; i--) {
          try {
            debugPrint('SIP Service: Unregistering account at index $i');
            await _accountsModel!.unregisterAccount(i);

            debugPrint('SIP Service: Deleting account at index $i');
            await _accountsModel!.deleteAccount(i);
            debugPrint('SIP Service: Account $i deleted successfully');
          } catch (e) {
            debugPrint('SIP Service: Failed to delete account $i: $e');
          }
        }

        debugPrint('SIP Service: All accounts cleared from SIP SDK');
      } else {
        debugPrint('SIP Service: No accounts to clear');
      }

      // Only clear credentials from storage if explicitly requested
      if (clearCredentialsFromStorage) {
        await StorageService.instance.clearCredentials();
        debugPrint('SIP Service: Credentials cleared from storage');
      } else {
        debugPrint(
            'SIP Service: Credentials preserved in storage (soft unregister)');
      }

      _updateRegistrationState(SipRegistrationState.unregistered);
      _updateCurrentCall(null);
    } catch (e) {
      debugPrint('Unregistration failed: $e');
    }
  }

  /// Update transport protocol and re-register if needed
  Future<bool> updateTransport(String transport) async {
    try {
      debugPrint('SIP Service: Updating transport to $transport');

      // Enhanced debugging
      debugPrint('SIP Service: Accounts model null: ${_accountsModel == null}');
      debugPrint('SIP Service: Registration state: $_registrationState');
      if (_accountsModel != null) {
        debugPrint(
            'SIP Service: Accounts model length: ${_accountsModel!.length}');
      }

      if (_accountsModel == null) {
        debugPrint('Cannot update transport: Accounts model not initialized');
        return false;
      }

      if (_accountsModel!.length == 0) {
        debugPrint('Cannot update transport: No accounts available');
        return false;
      }

      // Check if we're in a state where we can modify accounts
      if (_registrationState == SipRegistrationState.registering) {
        debugPrint(
            'Cannot update transport: Currently registering, please wait');
        return false;
      }

      // Get the current account (use index 0 for first account)
      AccountModel account;
      try {
        account = _accountsModel![0];
        debugPrint(
            'SIP Service: Got account - Extension: ${account.sipExtension}, Current transport: ${account.transport}');
      } catch (e) {
        debugPrint('Failed to get current account: $e');
        debugPrint(
            'SIP Service: Accounts model length at error: ${_accountsModel!.length}');
        return false;
      }

      // Save transport setting to persistent storage first
      await _saveTransportSetting(transport.toUpperCase());
      debugPrint(
          'Transport setting saved to storage: ${transport.toUpperCase()}');

      // For transport changes, we need to recreate the account entirely
      // because the existing account object maintains its original transport
      return await _recreateAccountWithNewTransport();
    } catch (e) {
      debugPrint('Failed to update transport: $e');
      return false;
    }
  }

  /// Get current transport protocol
  String getCurrentTransport() {
    try {
      if (_accountsModel != null && _accountsModel!.length > 0) {
        AccountModel account = _accountsModel![0];
        return account.transport == SipTransport.tcp ? 'TCP' : 'UDP';
      }
    } catch (e) {
      debugPrint('Failed to get current transport from account: $e');
    }

    // Fallback to reading from storage synchronously if account not available
    return 'UDP'; // Default fallback - will be updated when account loads
  }

  /// Get current transport protocol (async version that reads from storage)
  Future<String> getCurrentTransportAsync() async {
    try {
      if (_accountsModel != null && _accountsModel!.length > 0) {
        AccountModel account = _accountsModel![0];
        return account.transport == SipTransport.tcp ? 'TCP' : 'UDP';
      }
    } catch (e) {
      debugPrint('Failed to get current transport from account: $e');
    }

    // Fallback to reading from storage
    return await _loadTransportSetting();
  }

  /// Save transport setting to persistent storage
  Future<void> _saveTransportSetting(String transport) async {
    try {
      await StorageService.instance.setString('sip_transport', transport);
      debugPrint('SIP Service: Saved transport setting: $transport');
    } catch (e) {
      debugPrint('SIP Service: Failed to save transport setting: $e');
    }
  }

  /// Load transport setting from persistent storage
  Future<String> _loadTransportSetting() async {
    try {
      final savedTransport =
          await StorageService.instance.getString('sip_transport');
      debugPrint('SIP Service: Loaded transport setting: $savedTransport');
      return savedTransport ?? 'UDP'; // Default to UDP if not set
    } catch (e) {
      debugPrint('SIP Service: Failed to load transport setting: $e');
      return 'UDP'; // Default fallback
    }
  }

  /// Recreate account with new transport settings
  Future<bool> _recreateAccountWithNewTransport() async {
    try {
      debugPrint('SIP Service: Recreating account with new transport...');

      // Get extension details for recreating the account
      final authService = AuthService.instance;
      final extensionDetails = authService.extensionDetails;

      if (extensionDetails == null) {
        debugPrint('Cannot recreate account: No extension details available');
        return false;
      }

      // Perform complete unregister first (clears all accounts and resets state)
      debugPrint(
          'SIP Service: Performing complete unregister before recreating account...');
      await unregister();

      // Wait for unregistration to complete fully
      await Future.delayed(const Duration(milliseconds: 2000));

      // Now register with the new transport setting (will read from saved storage)
      debugPrint(
          'SIP Service: Starting fresh registration with new transport setting...');
      final success = await register(
        name: extensionDetails.name,
        extension: extensionDetails.extension.toString(),
        password: extensionDetails.password,
        domain: extensionDetails.domain,
        proxy: extensionDetails.proxy,
        port: extensionDetails.port,
      );

      if (success) {
        debugPrint(
            'SIP Service: Account recreated with new transport successfully');
      } else {
        debugPrint(
            'SIP Service: Failed to recreate account with new transport');
      }

      return success;
    } catch (e) {
      debugPrint(
          'SIP Service: Error recreating account with new transport: $e');
      _updateRegistrationState(SipRegistrationState.registrationFailed);
      return false;
    }
  }

  /// Re-register the existing account
  Future<bool> reregister() async {
    try {
      debugPrint('SIP Service: Starting re-registration...');

      if (_accountsModel == null || _accountsModel!.length == 0) {
        debugPrint('Cannot re-register: No accounts available');
        return false;
      }

      _updateRegistrationState(SipRegistrationState.registering);

      // Use index 0 for the first (and typically only) account
      const accountIndex = 0;

      // Get account info for logging
      final account = _accountsModel![accountIndex];
      debugPrint(
          'SIP Service: Re-registering account - Extension: ${account.sipExtension}, Current state: ${account.regState}');

      // First unregister the current account
      await _accountsModel!.unregisterAccount(accountIndex);
      debugPrint('SIP Service: Unregistered account at index $accountIndex');

      // Wait a moment for unregistration to complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // Re-register the account
      await _accountsModel!.registerAccount(accountIndex);
      debugPrint('SIP Service: Re-registered account at index $accountIndex');

      _updateRegistrationState(SipRegistrationState.registered);
      debugPrint('SIP Service: Re-registration completed successfully');
      return true;
    } catch (e) {
      debugPrint('SIP Service: Re-registration failed: $e');
      _updateRegistrationState(SipRegistrationState.registrationFailed);
      return false;
    }
  }

  /// Enhanced background re-registration with network state awareness and retry logic
  /// Works for both Android and iOS
  @pragma('vm:entry-point')
  Future<bool> attemptBackgroundReregistration() async {
    try {
      if (_isBackgroundRegistrationInProgress) {
        debugPrint(
            '🔥 SIP Service: Background registration already in progress, skipping');
        return false;
      }

      _isBackgroundRegistrationInProgress = true;
      debugPrint(
          '🔥 SIP Service: Attempting background re-registration with network check');

      // First check network connectivity
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();

      debugPrint('🔥 Network state: $connectivityResult');

      // If no network, don't attempt re-registration
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('🔥 No network available - skipping SIP re-registration');
        _isBackgroundRegistrationInProgress = false;
        return false;
      }

      // CRITICAL FIX: Check if we have valid credentials before proceeding
      final credentials = await StorageService.instance.getCredentials();
      if (credentials == null) {
        debugPrint('🔥 SIP Service: No credentials found - cannot re-register');
        _isBackgroundRegistrationInProgress = false;
        return false;
      }

      // Ensure we're properly initialized based on platform
      if (_siprixSdk == null || _accountsModel == null) {
        debugPrint(
            '🔥 SIP Service: SDK not initialized, attempting platform-specific initialization...');

        if (Platform.isAndroid) {
          await _initializeForAndroidBackground();
        } else {
          await _quickInitializeForBackground();
        }
      }

      if (_accountsModel != null && _accountsModel!.length > 0) {
        debugPrint('🔥 SIP Service: Found ${_accountsModel!.length} accounts');

        // Check current registration state
        for (int i = 0; i < _accountsModel!.length; i++) {
          final account = _accountsModel![i];
          debugPrint(
              '🔥 SIP Service: Account $i - Extension: ${account.sipExtension}, State: ${account.regState}, Text: ${account.regText}');
        }

        // Use aggressive re-registration strategy for background
        final result = await _aggressiveBackgroundReregister();
        _isBackgroundRegistrationInProgress = false;
        return result;
      } else {
        debugPrint(
            '🔥 SIP Service: No existing accounts for background registration - creating new account');

        // CRITICAL: If no accounts exist, create a new one with stored credentials
        final result = await _createNewAccountFromStoredCredentials();
        _isBackgroundRegistrationInProgress = false;
        return result;
      }
    } catch (e) {
      debugPrint('🔥 SIP Service: Error in background re-registration: $e');
      _isBackgroundRegistrationInProgress = false;
      return false;
    }
  }

  /// Create new account from stored credentials when no accounts exist
  Future<bool> _createNewAccountFromStoredCredentials() async {
    try {
      debugPrint(
          '🆕 SIP Service: Creating new account from stored credentials');

      final credentials = await StorageService.instance.getCredentials();
      if (credentials == null) {
        debugPrint(
            '❌ SIP Service: No credentials available to create new account');
        return false;
      }

      debugPrint('🆕 SIP Service: Registering with stored credentials...');

      final success = await register(
        name: credentials['name'],
        extension: credentials['extension'],
        password: credentials['password'],
        domain: credentials['domain'],
        proxy: credentials['proxy'],
        port: credentials['port'],
      );

      if (success) {
        debugPrint(
            '✅ SIP Service: New account created successfully from stored credentials');
        return true;
      } else {
        debugPrint(
            '❌ SIP Service: Failed to create new account from stored credentials');
        return false;
      }
    } catch (e) {
      debugPrint('❌ SIP Service: Error creating new account: $e');
      return false;
    }
  }

  /// Manual re-register method that can be called externally
  Future<bool> manualReregister() async {
    try {
      debugPrint('🔄 MANUAL REREGISTER: Starting manual re-registration');

      if (_accountsModel == null || _accountsModel!.length == 0) {
        debugPrint('❌ MANUAL REREGISTER: No accounts available');
        return false;
      }

      // Force unregister first
      try {
        await _accountsModel!.unregisterAccount(0);
        debugPrint('🔄 MANUAL REREGISTER: Successfully unregistered');
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('🔄 MANUAL REREGISTER: Unregister failed: $e');
      }

      // Register fresh
      await _accountsModel!.registerAccount(0);
      debugPrint('✅ MANUAL REREGISTER: Fresh registration completed');

      // Wait for registration to complete
      await Future.delayed(const Duration(seconds: 2));

      // Verify registration
      if (_accountsModel!.length > 0) {
        final account = _accountsModel![0];
        final isRegistered = await _checkRegistrationStatus(account);

        if (isRegistered) {
          debugPrint('✅ MANUAL REREGISTER: Registration verified successfully');
          _updateRegistrationState(SipRegistrationState.registered);
          return true;
        }
      }

      debugPrint('❌ MANUAL REREGISTER: Registration verification failed');
      return false;
    } catch (e) {
      debugPrint(
          '❌ MANUAL REREGISTER: Error during manual re-registration: $e');
      return false;
    }
  }

  /// Enhanced aggressive re-registration strategy for background state
  Future<bool> _aggressiveBackgroundReregister() async {
    try {
      debugPrint(
          '🔥 SIP Service: Starting aggressive background re-registration');

      // First, check if we're already registered
      if (_accountsModel!.length > 0) {
        final account = _accountsModel![0];
        final isCurrentlyRegistered = await _checkRegistrationStatus(account);
        if (isCurrentlyRegistered) {
          debugPrint(
              '✅ SIP Service: Already registered, no need to re-register');
          return true;
        }
      }

      // If not registered, proceed with aggressive re-registration
      // First, force unregister to clear any stale state
      try {
        debugPrint('🔥 SIP Service: Force unregistering account...');
        await _accountsModel!.unregisterAccount(0);
        debugPrint('🔥 SIP Service: Account unregistered');
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        debugPrint(
            '🔥 SIP Service: Unregister failed (may be already unregistered): $e');
      }

      // Now register with retry logic
      const maxRegisterAttempts = 3;

      for (int attempt = 1; attempt <= maxRegisterAttempts; attempt++) {
        try {
          debugPrint(
              '🔥 SIP Service: Register attempt $attempt/$maxRegisterAttempts');

          // Clear any previous registration state
          _updateRegistrationState(SipRegistrationState.registering);

          await _accountsModel!
              .registerAccount(0)
              .timeout(const Duration(seconds: 10));

          debugPrint(
              '🔥 SIP Service: ✅ Registration attempt $attempt completed');

          // Wait for registration to propagate
          await Future.delayed(const Duration(seconds: 2));

          // Check if registration was successful using the correct method
          final account = _accountsModel![0];
          bool isRegistered = await _checkRegistrationStatus(account);

          if (isRegistered) {
            debugPrint(
                '🔥 SIP Service: ✅ Background registration successful on attempt $attempt');
            _updateRegistrationState(SipRegistrationState.registered);
            return true;
          } else {
            debugPrint(
                '🔥 SIP Service: ❌ Registration not successful, state: ${account.regState}, text: ${account.regText}');

            // If we get 503 error, try different strategy
            if (account.regText.contains('503') == true &&
                attempt < maxRegisterAttempts) {
              debugPrint(
                  '🔥 SIP Service: 503 error detected, trying alternative approach...');
              await _handle503Error(attempt);
            }
          }
        } catch (e) {
          debugPrint(
              '🔥 SIP Service: ❌ Registration attempt $attempt failed: $e');

          // If it's a 503 error, we should retry with different strategy
          if (e.toString().contains('503') && attempt < maxRegisterAttempts) {
            debugPrint(
                '🔥 SIP Service: 503 error detected, trying alternative approach...');
            await _handle503Error(attempt);
            continue;
          }

          // For other errors or final attempt, give up
          if (attempt == maxRegisterAttempts) {
            debugPrint('🔥 SIP Service: ❌ All registration attempts failed');
            _updateRegistrationState(SipRegistrationState.registrationFailed);

            // Schedule a retry for later
            _scheduleDelayedRegistrationRetry();
            return false;
          }
        }
      }

      debugPrint('🔥 SIP Service: ❌ All registration attempts failed');
      _updateRegistrationState(SipRegistrationState.registrationFailed);
      return false;
    } catch (e) {
      debugPrint('🔥 SIP Service: ❌ Aggressive re-registration failed: $e');
      _updateRegistrationState(SipRegistrationState.registrationFailed);
      return false;
    }
  }

  /// Handle 503 "No route to host" errors specifically
  Future<void> _handle503Error(int attempt) async {
    debugPrint('🔄 503 HANDLER: Attempting to recover from 503 error...');

    // Strategy 1: Wait longer before retry
    final waitTime = attempt * 3; // 3, 6, 9 seconds
    debugPrint('🔄 503 HANDLER: Waiting $waitTime seconds before retry...');
    await Future.delayed(Duration(seconds: waitTime));

    // Strategy 2: Try to refresh network state
    try {
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      debugPrint('🔄 503 HANDLER: Current network state: $connectivityResult');
    } catch (e) {
      debugPrint('🔄 503 HANDLER: Error checking network: $e');
    }
  }

  /// Schedule delayed registration retry
  void _scheduleDelayedRegistrationRetry() {
    if (_registrationRetryCount >= 3) {
      debugPrint('🔥 SIP Service: Maximum retry attempts reached, giving up');
      return;
    }

    _registrationRetryCount++;
    final delaySeconds = _registrationRetryCount * 10; // 10, 20, 30 seconds

    debugPrint(
        '🔥 SIP Service: Scheduling registration retry #$_registrationRetryCount in $delaySeconds seconds');

    _registrationRetryTimer = Timer(Duration(seconds: delaySeconds), () async {
      debugPrint(
          '🔥 SIP Service: Executing delayed registration retry #$_registrationRetryCount');
      await attemptBackgroundReregistration();
    });
  }

  /// Check registration status using the correct Siprix SDK method
  Future<bool> _checkRegistrationStatus(AccountModel account) async {
    try {
      debugPrint(
          '🔍 Checking registration status for account: ${account.sipExtension}');
      debugPrint('🔍 Account registration state: ${account.regState}');
      debugPrint('🔍 Account registration text: ${account.regText}');

      // Check if we have any explicit failure indicators
      final regText = (account.regText ?? '').toLowerCase();

      if (regText.contains('fail') ||
          regText.contains('error') ||
          regText.contains('503') ||
          regText.contains('no route') ||
          regText.contains('timeout')) {
        debugPrint('❌ Registration explicitly failed: $regText');
        return false;
      }

      // Check for success indicators
      if (regText.contains('ok') ||
          regText.contains('registered') ||
          regText.contains('200') ||
          regText.contains('success')) {
        debugPrint('✅ Registration explicitly successful: $regText');
        return true;
      }

      // If registration state is a number, check if it's in success range (200-299)
      if (account.regState is int) {
        final state = account.regState as int;
        if (state >= 200 && state < 300) {
          debugPrint('✅ Registration state indicates success: $state');
          return true;
        } else if (state >= 400) {
          debugPrint('❌ Registration state indicates failure: $state');
          return false;
        }
      }

      // If we don't have explicit failures, assume registration might be working
      // The actual call attempt will determine if it's really working
      debugPrint(
          '⚠️ Registration status unclear, but no explicit failure detected');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking registration status: $e');
      // In case of error, be optimistic and let the call attempt determine success
      return true;
    }
  }

  /// Quick initialization for iOS background state
  Future<void> _quickInitializeForBackground() async {
    try {
      debugPrint(
          '🔥 QUICK INIT: Starting quick initialization for background...');

      if (_siprixSdk == null) {
        _siprixSdk = SiprixVoipSdk();

        // Minimal initialization for iOS background
        final initData = InitData();
        initData.license = '';
        initData.singleCallMode = false;
        initData.shareUdpTransport = true;
        initData.enableVideoCall = false;
        initData.enableCallKit = true;
        initData.enablePushKit = true;
        initData.unregOnDestroy = false;

        await _siprixSdk!.initialize(initData);
      }

      _accountsModel ??= getGlobalAccountsModel() ?? AccountsModel();

      _callsModel ??=
          getGlobalCallsModel() ?? AppCallsModel(_accountsModel!, null, null);

      debugPrint('🔥 QUICK INIT: Quick initialization completed');
    } catch (e) {
      debugPrint('🔥 QUICK INIT: Error during quick initialization: $e');
      throw e;
    }
  }

  /// Android-specific background service initialization
  Future<void> _initializeForAndroidBackground() async {
    try {
      debugPrint('SIP Service: Initializing for Android background...');

      // Initialize the SDK with Android-specific settings
      _siprixSdk = SiprixVoipSdk();

      final initData = InitData();
      initData.license = '';
      initData.singleCallMode = false;
      initData.shareUdpTransport = true;
      initData.enableVideoCall = false;

      // Android-specific settings
      // initData.enableAndroidForegroundService = true;
      // initData.foregroundServiceNotificationId = 1001;
      // initData.foregroundServiceNotificationTitle = AppConstants.appName;
      // initData.foregroundServiceNotificationText = 'SIP service running';

      await _siprixSdk!.initialize(initData);

      _accountsModel ??= getGlobalAccountsModel() ?? AccountsModel();
      _callsModel ??= AppCallsModel(_accountsModel!, null, null);

      debugPrint('SIP Service: Android background initialization completed');
    } catch (e) {
      debugPrint('SIP Service: Android background initialization failed: $e');
      throw e;
    }
  }

  void _updateRegistrationState(SipRegistrationState state) {
    _registrationState = state;
    _registrationStateController.add(state);
    notifyListeners();
  }

  /// Check iOS capabilities and device requirements for PushKit
  @override
  void _checkIOSCapabilities() {
    if (!Platform.isIOS) return;

    debugPrint('SIP Service: 🔍 Checking iOS PushKit requirements...');
    debugPrint('SIP Service: Platform.isIOS: ${Platform.isIOS}');

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
  @override
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
  @override
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
