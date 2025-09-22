library sip_service_base;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:siprix_voip_sdk/accounts_model.dart';
import 'package:siprix_voip_sdk/calls_model.dart';
import 'package:siprix_voip_sdk/devices_model.dart';
import 'package:siprix_voip_sdk/network_model.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';

import '../../constants/app_constants.dart';
import '../../../shared/services/storage_service.dart';
import '../auth_service.dart';
import '../call_history_service.dart';
import '../contact_service.dart';
import '../navigation_service.dart';
import '../notification_service.dart';

part 'sip_service_authentication.dart';
part 'sip_service_call_handling.dart';
part 'sip_service_contacts.dart';
part 'sip_service_messaging.dart';
part 'sip_service_transfer.dart';
part 'sip_service_utilities.dart';

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

abstract class _SipServiceBase extends ChangeNotifier
    with WidgetsBindingObserver {
  // Siprix SDK components
  SiprixVoipSdk? _siprixSdk;
  AccountsModel? _accountsModel;
  CallsModel? _callsModel;
  NetworkModel? _networkModel;
  DevicesModel? _devicesModel;
  int? _currentAccountId;

  // Background acceptance monitoring
  Timer? _backgroundAcceptanceTimer;

  SipRegistrationState _registrationState = SipRegistrationState.unregistered;
  CallInfo? _currentCall;
  int? _currentSiprixCallId; // Store the actual Siprix call ID for operations

  // Store CallModel for connected calls
  CallModel? _connectedCallModel;
  Timer? _connectionCheckTimer;

  // Flag to prevent actions during hangup process
  bool _isHangingUp = false;

  // Flag to prevent state updates after disposal
  bool _isDisposed = false;

  // Store credentials for re-registration
  Map<String, dynamic>? _lastCredentials;

  // Auto-answer flag for notification acceptance
  String? _autoAnswerCallId;
  String? _autoAnswerCallerName;
  String? _autoAnswerCallerNumber;

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
  @pragma('vm:entry-point')
  bool get isRegistered =>
      _registrationState == SipRegistrationState.registered;
  bool get hasActiveCall =>
      _currentCall != null && _currentCall!.state != AppCallState.ended;

  // Streams
  Stream<SipRegistrationState> get registrationStateStream =>
      _registrationStateController.stream;
  Stream<CallInfo?> get currentCallStream => _currentCallController.stream;

  Future<void> initialize();
  void _updateCurrentCall(CallInfo? call);
  Future<void> _autoRegister(Map<String, dynamic> credentials);
  void _checkIOSCapabilities();
  void _scheduleTokenRetry();
  Future<void> _initializeNetworkMonitoring();
  String _resolveContactNameForCallKit(String extension);
  void debugIOSPushConfiguration();
  Map<String, String> _parseCallerInfo(String fromHeader);
  void _onModelsChanged();
  void _onNetworkChanged();
}

@pragma('vm:entry-point')
class SipService extends _SipServiceBase
    with
        _SipServiceAuthentication,
        _SipServiceCallHandling,
        _SipServiceContacts,
        _SipServiceMessaging,
        _SipServiceTransfer,
        _SipServiceUtilities {
  @pragma('vm:entry-point')
  static final SipService _instance = SipService._internal();
  @pragma('vm:entry-point')
  static SipService get instance => _instance;

  SipService._internal();

  @override
  void dispose() {
    debugPrint('SipService: Disposing...');
    _isDisposed = true;

    // Dispose transfer resources
    disposeTransfer();

    // Close stream controllers
    _registrationStateController.close();
    _currentCallController.close();

    // Cancel timers
    _backgroundAcceptanceTimer?.cancel();

    // Remove lifecycle observer
    if (!kIsWeb) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (e) {
        debugPrint('SipService: Could not remove lifecycle observer: $e');
      }
    }

    // Cancel subscriptions
    _connectivitySubscription?.cancel();

    super.dispose();
  }
}
