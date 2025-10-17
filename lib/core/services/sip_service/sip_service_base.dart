library sip_service_base;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siprix_voip_sdk/accounts_model.dart';
import 'package:siprix_voip_sdk/calls_model.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';
import 'package:siprix_voip_sdk/devices_model.dart';
import 'package:siprix_voip_sdk/network_model.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';

import '../../constants/app_constants.dart';
import '../../../shared/services/storage_service.dart';
import '../../models/app_calls_model.dart';
import '../auth_service.dart';
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

//PUSH Srigo
/// Helper class used to keep different ids of the same call
class CallMatcher {
  static const String kStubPushHint = 'stubPushHint';

  ///Id assigned by CallKit when push notification received
  String callkit_CallUUID;

  ///Some data received in push payload (put by remote SIP server)
  ///This field is using to identify/match push and SIP calls
  /// each aplication may use its own way
  String push_Hint;

  ///Id assigned by library when SIP INVITE received
  int sip_CallId;

  CallMatcher(this.callkit_CallUUID, this.push_Hint, [this.sip_CallId = 0]);
}

abstract class _SipServiceBase extends ChangeNotifier
    with WidgetsBindingObserver {
  // Siprix SDK components
  SiprixVoipSdk? _siprixSdk;
  AccountsModel? _accountsModel;
  AppCallsModel? _callsModel;
  CdrsModel? _cdrsModel;
  NetworkModel? _networkModel;
  DevicesModel? _devicesModel;
  int? _currentAccountId;

  // Background acceptance monitoring
  Timer? _backgroundAcceptanceTimer;

  SipRegistrationState _registrationState = SipRegistrationState.unregistered;
  CallInfo? _currentCall;

  Timer? _connectionCheckTimer;

  // Flag to prevent actions during hangup process
  bool _isHangingUp = false;

  // Timer for call duration updates
  Timer? _callDurationTimer;

  // Cache for parsed caller information to avoid duplicate parsing
  Map<String, Map<String, String>> _callerInfoCache = {};

  /// Helper method to get parsed caller info with caching to avoid duplicate parsing
  Map<String, String> _getCachedCallerInfo(String fromHeader) {
    String callerName = '';
    String callerNumber = '';

    debugPrint('SIP Service: From HDR: $fromHeader');

    // Parse the input to extract the number first
    if (fromHeader.contains('<sip:') || fromHeader.contains('sip:')) {
      // Full SIP URI format - use builtin SDK functions
      callerName = CallsModel.parseDisplayName(fromHeader);
      callerNumber = CallsModel.parseExt(fromHeader);
      debugPrint(
          'SIP Service: Parsed SIP URI - name: "$callerName", number: "$callerNumber"');
    } else {
      // Simple extension format (like "1003") - treat as number
      callerNumber = fromHeader.trim();
      callerName = callerNumber; // Use number as name
      //debugPrint('SIP Service: Simple extension format - using "$callerNumber" as both name and number');
    }

    // Fallback to ensure we always have valid values
    if (callerName.isEmpty)
      callerName = callerNumber.isNotEmpty ? callerNumber : 'Unknown';
    if (callerNumber.isEmpty) callerNumber = 'Unknown';

    // Use the number as cache key to avoid duplicate parsing for same caller
    final cacheKey = callerNumber;

    // Check if we already have cached info for this number
    if (_callerInfoCache.containsKey(cacheKey)) {
      debugPrint('SIP Service: Using cached caller info for number: $cacheKey');
      return _callerInfoCache[cacheKey]!;
    }

    final callerInfo = {'name': callerName, 'number': callerNumber};
    _callerInfoCache[cacheKey] = callerInfo;

    debugPrint(
        'SIP Service: Cached caller info for number: $cacheKey - name: "$callerName", number: "$callerNumber"');
    return callerInfo;
  }

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

  // Hold event listeners
  final List<void Function(int callId, HoldState holdState)>
      _holdEventListeners = [];

  // Getters
  SipRegistrationState get registrationState => _registrationState;
  CallInfo? get currentCall => _currentCall;
  @pragma('vm:entry-point')
  bool get isRegistered =>
      _registrationState == SipRegistrationState.registered;
  bool get hasActiveCall =>
      _currentCall != null && _currentCall!.state != AppCallState.ended;

  // Access to Siprix CDRs (Call Detail Records)
  CdrsModel? get cdrs => _cdrsModel;

  // Access to CallsModel
  AppCallsModel? get callsModel => _callsModel;

  // Streams
  Stream<SipRegistrationState> get registrationStateStream =>
      _registrationStateController.stream;
  Stream<CallInfo?> get currentCallStream => _currentCallController.stream;

  // Hold event listener management
  void addHoldEventListener(
      void Function(int callId, HoldState holdState) listener) {
    _holdEventListeners.add(listener);
  }

  void removeHoldEventListener(
      void Function(int callId, HoldState holdState) listener) {
    _holdEventListeners.remove(listener);
  }

  void _notifyHoldEventListeners(int callId, HoldState holdState) {
    for (final listener in _holdEventListeners) {
      try {
        listener(callId, holdState);
      } catch (e) {
        debugPrint('SIP Service: Error in hold event listener: $e');
      }
    }
  }

  Future<void> initialize();
  void _updateCurrentCall(CallInfo? call);
  Future<void> _autoRegister(Map<String, dynamic> credentials);
  void _checkIOSCapabilities();
  void _scheduleTokenRetry();
  Future<void> _initializeNetworkMonitoring();
  String _resolveContactNameForCallKit(String extension);
  void debugIOSPushConfiguration();
  void _onModelsChanged();
  void _onNetworkChanged();

  // Do Not Disturb methods
  Future<bool> isDoNotDisturbEnabled();
  Future<void> setDoNotDisturb(bool enabled);
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
}
