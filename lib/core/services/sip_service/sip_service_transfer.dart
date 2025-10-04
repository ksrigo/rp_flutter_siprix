part of 'sip_service_base.dart';

enum TransferState {
  none,
  initiating,
  consulting,
  completing,
  completed,
  failed,
}

class ConsultCallInfo {
  final String id;
  final String targetNumber;
  final AppCallState state;
  final DateTime startTime;
  CallModel? callModel;

  ConsultCallInfo({
    required this.id,
    required this.targetNumber,
    required this.state,
    required this.startTime,
    this.callModel,
  });

  ConsultCallInfo copyWith({
    String? id,
    String? targetNumber,
    AppCallState? state,
    DateTime? startTime,
    CallModel? callModel,
  }) {
    return ConsultCallInfo(
      id: id ?? this.id,
      targetNumber: targetNumber ?? this.targetNumber,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      callModel: callModel ?? this.callModel,
    );
  }
}

mixin _SipServiceTransfer on _SipServiceBase {
  TransferState _transferState = TransferState.none;
  ConsultCallInfo? _consultCall;
  String? _originalCallId;

  // Stream controllers for transfer events
  final StreamController<TransferState> _transferStateController =
      StreamController<TransferState>.broadcast();
  final StreamController<ConsultCallInfo?> _consultCallController =
      StreamController<ConsultCallInfo?>.broadcast();

  // Getters
  TransferState get transferState => _transferState;
  ConsultCallInfo? get consultCall => _consultCall;

  // Streams
  Stream<TransferState> get transferStateStream => _transferStateController.stream;
  Stream<ConsultCallInfo?> get consultCallStream => _consultCallController.stream;

  /// Performs a blind transfer - transfers the current call directly to target
  Future<void> transferBlind(String callId, String targetNumber) async {
    try {
      debugPrint('Starting blind transfer: $callId to $targetNumber');

      if (_siprixSdk == null || _callsModel == null) {
        throw Exception('SIP service not initialized');
      }

      if (!isRegistered) {
        throw Exception('Not registered');
      }

      _updateTransferState(TransferState.initiating);

      final intCallId = int.tryParse(callId);
      if (intCallId == null) {
        throw Exception('Invalid call ID format');
      }

      debugPrint('Blind transfer - looking for call ID: $intCallId');
      debugPrint('Current Siprix call ID: $_currentSiprixCallId');
      debugPrint('CallsModel length: ${_callsModel!.length}');
      debugPrint('Switched call ID: ${_callsModel!.switchedCallId}');

      // Log all available calls
      for (int i = 0; i < _callsModel!.length; i++) {
        final call = _callsModel![i];
        debugPrint('Available call $i: ID=${call.myCallId}, Remote=${call.remoteExt}, Connected=${call.isConnected}, State=${call.state}');
      }

      // Determine which call ID to use for transfer
      int callIdToUse;

      // Priority 1: Use stored Siprix call ID if available (most reliable)
      if (_currentSiprixCallId != null && _currentSiprixCallId! > 0) {
        callIdToUse = _currentSiprixCallId!;
        debugPrint('Using stored Siprix call ID for transfer: $callIdToUse');
      }
      // Priority 2: Use the parsed call ID from our app
      else if (intCallId > 0) {
        callIdToUse = intCallId;
        debugPrint('Using parsed call ID for transfer: $callIdToUse');
      }
      // Priority 3: Try to get from switched call if CallsModel has calls
      else if (_callsModel!.switchedCallId > 0) {
        callIdToUse = _callsModel!.switchedCallId;
        debugPrint('Using switched call ID for transfer: $callIdToUse');
      }
      else {
        throw Exception('No valid call ID available for transfer');
      }

      debugPrint('Performing blind transfer on call $callIdToUse to $targetNumber');

      // Perform the blind transfer using Siprix SDK directly
      // Use the SDK method with call ID and target extension
      await _siprixSdk!.transferBlind(callIdToUse, targetNumber);

      debugPrint('Blind transfer initiated successfully');
      _updateTransferState(TransferState.completed);

      // The transfer is complete, the original call should be terminated by the server
      // Update our call state to ended
      if (_currentCall != null && _currentCall!.id == callId) {
        _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

        // Clear the call after a brief delay
        Timer(const Duration(milliseconds: 1000), () {
          _updateCurrentCall(null);
          _updateTransferState(TransferState.none);
        });
      }

    } catch (e) {
      debugPrint('Blind transfer failed: $e');
      _updateTransferState(TransferState.failed);
      throw Exception('Blind transfer failed: $e');
    }
  }

  /// Starts an attended transfer - first makes a call to the target, then allows consultation
  Future<String> transferAttendedStart(String callId, String targetNumber) async {
    try {
      debugPrint('Starting attended transfer: $callId, consulting with $targetNumber');

      if (_siprixSdk == null || _callsModel == null) {
        throw Exception('SIP service not initialized');
      }

      if (!isRegistered) {
        throw Exception('Not registered');
      }

      if (_currentAccountId == null) {
        throw Exception('No valid account found');
      }

      _updateTransferState(TransferState.initiating);
      _originalCallId = callId;

      // Put the original call on hold
      final intCallId = int.tryParse(callId);
      if (intCallId != null) {
        await _siprixSdk!.hold(intCallId);
      }

      // Create call destination for the consult call
      CallDestination destination = CallDestination(targetNumber, _currentAccountId!, false);
      destination.inviteTimeout = 60;
      destination.displName = targetNumber;

      debugPrint('Making consult call to $targetNumber');

      // Make the consult call
      await _callsModel!.invite(destination);

      // Generate a tracking ID for the consult call
      final consultCallId = 'consult_${DateTime.now().millisecondsSinceEpoch}';

      // Create consult call info
      _consultCall = ConsultCallInfo(
        id: consultCallId,
        targetNumber: targetNumber,
        state: AppCallState.connecting,
        startTime: DateTime.now(),
      );

      _updateTransferState(TransferState.consulting);
      _consultCallController.add(_consultCall);

      debugPrint('Consult call initiated, ID: $consultCallId');
      return consultCallId;

    } catch (e) {
      debugPrint('Attended transfer start failed: $e');
      _updateTransferState(TransferState.failed);
      // Resume the original call if it was held
      if (_originalCallId != null) {
        try {
          final intCallId = int.tryParse(_originalCallId!);
          if (intCallId != null) {
            await _siprixSdk!.hold(intCallId);
          }
        } catch (resumeError) {
          debugPrint('Failed to resume original call: $resumeError');
        }
      }
      _cleanup();
      throw Exception('Attended transfer start failed: $e');
    }
  }

  /// Completes the attended transfer by connecting the original call to the consult call
  Future<void> transferAttendedComplete() async {
    try {
      debugPrint('Completing attended transfer');

      if (_siprixSdk == null || _callsModel == null) {
        throw Exception('SIP service not initialized');
      }

      if (_originalCallId == null) {
        throw Exception('No original call to transfer');
      }

      if (_consultCall == null) {
        throw Exception('No consult call active');
      }

      _updateTransferState(TransferState.completing);

      final intOriginalCallId = int.tryParse(_originalCallId!);
      if (intOriginalCallId == null) {
        throw Exception('Invalid original call ID format');
      }

      // Find both calls in the calls model
      CallModel? originalCall;
      CallModel? consultCallModel;

      for (int i = 0; i < _callsModel!.length; i++) {
        final call = _callsModel![i];
        if (call.myCallId == intOriginalCallId) {
          originalCall = call;
        } else if (call.remoteExt == _consultCall!.targetNumber) {
          consultCallModel = call;
        }
      }

      if (originalCall == null) {
        throw Exception('Original call not found');
      }

      if (consultCallModel == null) {
        throw Exception('Consult call not found');
      }

      debugPrint('Performing attended transfer: original call ${originalCall.myCallId} to consult call ${consultCallModel.myCallId}');

      // Perform the attended transfer using Siprix SDK directly
      // Transfer from original call to consult call
      await _siprixSdk!.transferAttended(originalCall.myCallId, consultCallModel.myCallId);

      debugPrint('Attended transfer completed successfully');
      _updateTransferState(TransferState.completed);

      // Both calls should be terminated by the server after transfer
      _updateCurrentCall(_currentCall?.copyWith(state: AppCallState.ended));

      // Clear everything after a brief delay
      Timer(const Duration(milliseconds: 1000), () {
        _updateCurrentCall(null);
        _cleanup();
      });

    } catch (e) {
      debugPrint('Attended transfer completion failed: $e');
      _updateTransferState(TransferState.failed);
      throw Exception('Attended transfer completion failed: $e');
    }
  }

  /// Cancels an attended transfer and resumes the original call
  Future<void> transferAttendedCancel() async {
    try {
      debugPrint('Canceling attended transfer');

      // Hangup the consult call if it exists
      if (_consultCall?.callModel != null) {
        try {
          await _consultCall!.callModel!.bye();
        } catch (e) {
          debugPrint('Failed to hangup consult call: $e');
        }
      }

      // Resume the original call
      if (_originalCallId != null) {
        try {
          final intCallId = int.tryParse(_originalCallId!);
          if (intCallId != null) {
            await _siprixSdk!.hold(intCallId);
          }
        } catch (e) {
          debugPrint('Failed to resume original call: $e');
        }
      }

      _cleanup();
      debugPrint('Attended transfer canceled');

    } catch (e) {
      debugPrint('Transfer cancel failed: $e');
      _cleanup();
    }
  }

  /// Handle call events to detect consult call state changes
  void handleCallEvent(int callId, String eventType, {String? remoteExt}) {
    if (_consultCall == null || _transferState != TransferState.consulting) {
      return;
    }

    debugPrint('Transfer: Handling call event - callId: $callId, event: $eventType, remote: $remoteExt');

    // Check if this call matches our consult call target
    if (remoteExt != null && remoteExt == _consultCall!.targetNumber) {
      debugPrint('Transfer: Event matches consult call target');

      switch (eventType) {
        case 'connected':
          // Find the call in the calls model and set it
          if (_callsModel != null) {
            for (int i = 0; i < _callsModel!.length; i++) {
              final call = _callsModel![i];
              if (call.myCallId == callId) {
                _consultCall = _consultCall!.copyWith(
                  callModel: call,
                  state: AppCallState.answered,
                );
                _consultCallController.add(_consultCall);
                debugPrint('Transfer: Consult call connected - callId: $callId');
                return;
              }
            }
          }
          break;

        case 'terminated':
          _consultCall = _consultCall!.copyWith(state: AppCallState.ended);
          _consultCallController.add(_consultCall);
          debugPrint('Transfer: Consult call terminated - callId: $callId');
          // Cancel transfer if consult call ends
          transferAttendedCancel();
          break;
      }
    }
  }

  void _updateTransferState(TransferState state) {
    _transferState = state;
    if (!_transferStateController.isClosed) {
      _transferStateController.add(state);
    }
    debugPrint('Transfer state updated to: $state');
  }

  void _cleanup() {
    _transferState = TransferState.none;
    _consultCall = null;
    _originalCallId = null;

    if (!_transferStateController.isClosed) {
      _transferStateController.add(_transferState);
    }
    if (!_consultCallController.isClosed) {
      _consultCallController.add(null);
    }
  }

  /// Disposes transfer-related resources
  void disposeTransfer() {
    _transferStateController.close();
    _consultCallController.close();
  }
}
