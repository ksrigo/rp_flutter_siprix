part of 'sip_service_base.dart';

mixin _SipServiceUtilities on _SipServiceBase {
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
