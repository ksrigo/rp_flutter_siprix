part of 'sip_service_base.dart';

mixin _SipServiceUtilities on _SipServiceBase {
  // Do Not Disturb storage key
  static const String _dndPreferenceKey = 'sip_service_do_not_disturb';

  // Do Not Disturb methods
  Future<bool> isDoNotDisturbEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_dndPreferenceKey) ?? false;
      debugPrint('SIP Service: DND state retrieved: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('SIP Service: Error getting DND state: $e');
      return false;
    }
  }

  Future<void> setDoNotDisturb(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dndPreferenceKey, enabled);
      debugPrint('SIP Service: DND state saved: $enabled');
    } catch (e) {
      debugPrint('SIP Service: Error saving DND state: $e');
      rethrow;
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
}
