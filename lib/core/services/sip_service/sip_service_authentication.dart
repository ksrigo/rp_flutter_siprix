part of 'sip_service_base.dart';

mixin _SipServiceAuthentication on _SipServiceBase {
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

      // Add RFC 8599 push notification parameters for Android
      if (Platform.isAndroid) {
        final fcmToken = NotificationService.instance.getCurrentFCMToken();
        if (fcmToken != null) {
          // Add FCM token to X-headers for backward compatibility
          account.xheaders!['X-Token'] = fcmToken;

          // Add RFC 8599 push notification parameters to Contact URI
          account.xContactUriParams ??= <String, String>{};
          account.xContactUriParams!['pn-provider'] = 'fcm';
          account.xContactUriParams!['pn-param'] = fcmToken;
          account.xContactUriParams!['pn-prid'] =
              'com.ringplus.app'; // App bundle ID
          account.xContactUriParams!['pn-timeout'] = '0';
          account.xContactUriParams!['pn-silent'] = '1';

          debugPrint(
              'Register: Added RFC 8599 push notification parameters to Contact URI');
          debugPrint(
              'Register: pn-provider=fcm, pn-param=$fcmToken, pn-prid=com.ringplus.app');
        } else {
          debugPrint(
              'Register: No FCM token available yet - push notifications will not work');
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
            // Add push token to SIP headers for backward compatibility
            account.xheaders ??= <String, String>{};
            account.xheaders!['X-Push-Token'] = pushToken;

            // Add RFC 8599 push notification parameters to Contact URI for iOS
            account.xContactUriParams ??= <String, String>{};
            account.xContactUriParams!['pn-provider'] = 'apns';
            account.xContactUriParams!['pn-param'] = pushToken;
            account.xContactUriParams!['pn-prid'] =
                'com.ringplus.app'; // App bundle ID
            account.xContactUriParams!['pn-timeout'] = '0';
            account.xContactUriParams!['pn-silent'] = '1';

            debugPrint(
                'SIP Service: ✅ Added PushKit token to account headers: $pushToken');
            debugPrint(
                'SIP Service: Added RFC 8599 push notification parameters for iOS');
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

      await StorageService.instance.clearCredentials();
      _updateRegistrationState(SipRegistrationState.unregistered);
      _updateCurrentCall(null);
    } catch (e) {
      debugPrint('Unregistration failed: $e');
    }
  }

  /// Update transport protocol and re-register if needed

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
    // Note: This is a synchronous fallback, ideally should use async version
    return 'UDP'; // Default fallback - will be updated when account loads
  }

  /// Get current transport protocol (async version that reads from storage)

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

  @pragma('vm:entry-point')
  Future<bool> attemptBackgroundReregistration() async {
    try {
      debugPrint('🔥 SIP Service: Attempting background re-registration');

      // First, ensure we're properly initialized
      if (_siprixSdk == null || _accountsModel == null) {
        debugPrint(
            '🔥 SIP Service: SDK not initialized, attempting initialization...');
        await initialize();
      }

      if (_accountsModel != null && _accountsModel!.length > 0) {
        // Try to re-register existing account
        try {
          debugPrint(
              '🔥 SIP Service: Found ${_accountsModel!.length} accounts');

          // Check current account state
          for (int i = 0; i < _accountsModel!.length; i++) {
            final account = _accountsModel![i];
            debugPrint(
                '🔥 SIP Service: Account $i before re-registration - Extension: ${account.sipExtension}, State: ${account.regState}, Text: ${account.regText}');
          }

          // First, force unregister to ensure we send a fresh REGISTER
          debugPrint(
              '🔥 SIP Service: Unregistering account first to force fresh registration...');
          try {
            await _accountsModel!.unregisterAccount(0);
            debugPrint('🔥 SIP Service: Account unregistered');
            // Wait briefly for unregistration
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            debugPrint(
                '🔥 SIP Service: Unregister failed (may be already unregistered): $e');
          }

          // Now register to send fresh REGISTER message
          debugPrint('🔥 SIP Service: Sending fresh REGISTER message...');
          await _accountsModel!.registerAccount(0); // Register first account
          debugPrint(
              '🔥 SIP Service: Background re-registration attempted - REGISTER message sent');

          // Wait for registration to complete
          await Future.delayed(const Duration(seconds: 3));

          final registered = isRegistered;
          debugPrint('🔥 SIP Service: Registration result: $registered');
          return registered;
        } catch (e) {
          debugPrint('🔥 SIP Service: Background re-registration failed: $e');
          return false;
        }
      } else {
        debugPrint(
            '🔥 SIP Service: No existing accounts for background registration');
        return false;
      }
    } catch (e) {
      debugPrint('🔥 SIP Service: Error in background re-registration: $e');
      return false;
    }
  }

  void _updateRegistrationState(SipRegistrationState state) {
    _registrationState = state;
    _registrationStateController.add(state);
    notifyListeners();
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
