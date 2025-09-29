import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:siprix_voip_sdk/calls_model.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';

/// Extended CallsModel that follows Siprix SDK pattern
/// This handles all call events by overriding CallsModel methods
class AppCallsModel extends CallsModel {
  AppCallsModel(IAccountsModel accounts, [ILogsModel? logs, CdrsModel? cdrs])
      : super(accounts, logs, cdrs);

  // Callback functions that will be set by SIP service
  void Function(int, String, String, bool)? onIncomingCallCallback;
  void Function(int)? onCallConnectedCallback;
  void Function(int)? onCallTerminatedCallback;
  void Function(int)? onCallSwitchedCallback;
  void Function(int, HoldState)? onCallHeldCallback;
  void Function(int, String)? onCallProceedingCallback;

  /// Handle incoming SIP call
  @override
  void onIncomingSip(int callId, int accId, bool withVideo, String hdrFrom,
      String hdrTo) async {
    debugPrint('>>> AppCallsModel.onIncomingSip CALLED - callId: $callId, from: $hdrFrom, to: $hdrTo');

    // IMPORTANT: Call super first to let builtin functionality work
    super.onIncomingSip(callId, accId, withVideo, hdrFrom, hdrTo);

    debugPrint(
        'AppCallsModel: Incoming SIP call - callId: $callId, from: $hdrFrom, to: $hdrTo');

    // Call the callback if set
    debugPrint('AppCallsModel: Calling onIncomingCallCallback...');
    onIncomingCallCallback?.call(callId, hdrFrom, hdrTo, withVideo);
    debugPrint('AppCallsModel: onIncomingCallCallback called');

    if (Platform.isIOS) {
      // iOS CallKit integration if needed
      _handleiOSCallKit(callId, hdrFrom);
    }
  }

  /// Handle call connected
  @override
  void onConnected(int callId, String from, String to, bool withVideo) {
    // IMPORTANT: Call super first to let builtin functionality work
    super.onConnected(callId, from, to, withVideo);

    debugPrint('AppCallsModel: Call connected - callId: $callId');

    // Call the callback if set
    onCallConnectedCallback?.call(callId);
  }

  /// Handle call terminated
  @override
  void onTerminated(int callId, int statusCode) {
    // IMPORTANT: Call super first to let builtin functionality work
    super.onTerminated(callId, statusCode);

    debugPrint(
        'AppCallsModel: Call terminated - callId: $callId, status: $statusCode');

    // Call the callback if set
    onCallTerminatedCallback?.call(callId);
  }

  /// Handle call switched
  @override
  void onSwitched(int callId) {
    // IMPORTANT: Call super first to let builtin functionality work
    super.onSwitched(callId);

    debugPrint('AppCallsModel: Call switched - callId: $callId');

    // Call the callback if set
    onCallSwitchedCallback?.call(callId);
  }

  /// Handle call held
  @override
  void onHeld(int callId, HoldState holdState) {
    // IMPORTANT: Call super first to let builtin functionality work
    super.onHeld(callId, holdState);

    debugPrint('AppCallsModel: Call held - callId: $callId, holdState: $holdState');

    // Call the callback if set
    onCallHeldCallback?.call(callId, holdState);
  }

  /// Handle call proceeding (outgoing call ringing)
  @override
  void onProceeding(int callId, String response) {
    // IMPORTANT: Call super first to let builtin functionality work
    super.onProceeding(callId, response);

    debugPrint('AppCallsModel: Call proceeding - callId: $callId, response: $response');

    // Call the callback if set
    onCallProceedingCallback?.call(callId, response);
  }

  /// Handle iOS CallKit integration
  void _handleiOSCallKit(int callId, String fromHeader) {
    try {
      // Parse caller info using builtin SDK functions
      final callerName = CallsModel.parseDisplayName(fromHeader);
      final callerNumber = CallsModel.parseExt(fromHeader);

      debugPrint(
          'AppCallsModel: iOS CallKit - Name: "$callerName", Number: "$callerNumber"');

      // Update CallKit with proper caller information
      // This uses the builtin SDK CallKit integration
    } catch (e) {
      debugPrint('AppCallsModel: Error updating iOS CallKit: $e');
    }
  }
}
