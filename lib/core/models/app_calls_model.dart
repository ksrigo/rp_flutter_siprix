import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:siprix_voip_sdk/calls_model.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';

// Import CallMatcher from sip_service_base
import '../services/sip_service/sip_service_base.dart' show CallMatcher;

/// Extended CallsModel that follows Siprix SDK pattern
/// This handles all call events by overriding CallsModel methods
class AppCallsModel extends CallsModel {
  // CallMatchers list for iOS PushKit (managed internally)
  final List<CallMatcher> _callMatchers = [];

  AppCallsModel(IAccountsModel accounts, [ILogsModel? logs, CdrsModel? cdrs])
      : super(accounts, logs, cdrs) {
    // Set up CallStateListener to route Siprix SDK events to our overridden methods
    // This ensures our onIncomingPush and other methods are called by the SDK
    SiprixVoipSdk().callListener = CallStateListener(
      proceeding: onProceeding,
      incoming: onIncomingSip,
      incomingPush: onIncomingPush, // Route push events to our override
      connected: onConnected,
      terminated: onTerminated,
      switched: onSwitched,
      held: onHeld,
    );
    debugPrint('AppCallsModel: CallStateListener configured with incomingPush routing');
  }

  // Callback functions that will be set by SIP service
  void Function(int, String, String, bool)? onIncomingCallCallback;
  void Function(int)? onCallConnectedCallback;
  void Function(int)? onCallTerminatedCallback;
  void Function(int)? onCallSwitchedCallback;
  void Function(int, HoldState)? onCallHeldCallback;
  void Function(int, String)? onCallProceedingCallback;

  /// Override onIncomingPush to handle iOS PushKit notifications
  /// This method is called DIRECTLY by the Siprix SDK when a push arrives
  @override
  void onIncomingPush(String callkitUuid, Map<String, dynamic> pushPayload) {
    if (!Platform.isIOS) return;

    try {
      print('=================================================');
      print('🔔 iOS PUSH: AppCallsModel.onIncomingPush CALLED');
      print('🔔 iOS PUSH: CallKit UUID: $callkitUuid');
      print('🔔 iOS PUSH: Raw Payload: $pushPayload');
      print('=================================================');
      debugPrint('=================================================');
      debugPrint('🔔 iOS PUSH: AppCallsModel.onIncomingPush CALLED');
      debugPrint('🔔 iOS PUSH: CallKit UUID: $callkitUuid');
      debugPrint('🔔 iOS PUSH: Raw Payload: $pushPayload');
      debugPrint('=================================================');

      // Get data from 'pushPayload', which contains app specific details
      Map<String, dynamic>? apsPayload;
      try {
        apsPayload = Map<String, dynamic>.from(pushPayload["aps"]);
        debugPrint('🔔 iOS PUSH: APS Payload extracted: $apsPayload');
        print('🔔 iOS PUSH: APS Payload extracted: $apsPayload');
      } catch (err) {
        debugPrint('🔔 iOS PUSH: ❌ Error extracting aps payload: $err');
        print('🔔 iOS PUSH: ❌ Error extracting aps payload: $err');
      }

      // Extract caller details from payload
      String pushHint = apsPayload?["pushHint"] ?? "pushHint";
      String genericHandle = apsPayload?["callerNumber"] ?? "genericHandle";
      String localizedCallerName = apsPayload?["callerId"] ?? "callerName";

      debugPrint('🔔 iOS PUSH: Extracted data:');
      debugPrint('  - pushHint: $pushHint');
      debugPrint('  - callerName: $localizedCallerName');
      debugPrint('  - callerNumber: $genericHandle');
      print('🔔 iOS PUSH: Extracted - pushHint: $pushHint, caller: $localizedCallerName, number: $genericHandle');

      // Add to call matchers
      _callMatchers.add(CallMatcher(callkitUuid, pushHint));
      debugPrint('🔔 iOS PUSH: Added CallMatcher (total: ${_callMatchers.length})');
      print('🔔 iOS PUSH: Added CallMatcher (total: ${_callMatchers.length})');

      // Update CallKit call details with push notification information
      try {
        debugPrint('🔔 iOS PUSH: Updating CallKit details...');
        print('🔔 iOS PUSH: Updating CallKit details...');
        SiprixVoipSdk().updateCallKitCallDetails(
          callkitUuid,
          null, // SIP call ID will be provided when SIP call arrives
          localizedCallerName,
          genericHandle,
          false, // withVideo
        );
        debugPrint('🔔 iOS PUSH: ✅ Successfully updated CallKit details');
        print('🔔 iOS PUSH: ✅ Successfully updated CallKit details');
      } catch (e) {
        debugPrint('🔔 iOS PUSH: ❌ Failed to update CallKit details: $e');
        print('🔔 iOS PUSH: ❌ Failed to update CallKit details: $e');
      }

      debugPrint('=================================================');
      debugPrint('🔔 iOS PUSH: onIncomingPush COMPLETED');
      debugPrint('=================================================');
      print('=================================================');
      print('🔔 iOS PUSH: onIncomingPush COMPLETED');
      print('=================================================');
    } catch (e) {
      debugPrint('🔔 iOS PUSH: ❌ CRITICAL ERROR in onIncomingPush: $e');
      debugPrint('🔔 iOS PUSH: Stack trace: ${StackTrace.current}');
      print('🔔 iOS PUSH: ❌ CRITICAL ERROR: $e');
      print('🔔 iOS PUSH: Stack trace: ${StackTrace.current}');
    }
  }

  /// Handle incoming SIP call
  @override
  void onIncomingSip(int callId, int accId, bool withVideo, String hdrFrom,
      String hdrTo) async {
    debugPrint(
        '>>> AppCallsModel.onIncomingSip CALLED - callId: $callId, from: $hdrFrom, to: $hdrTo');

    // IMPORTANT: Call super first to let builtin functionality work
    super.onIncomingSip(callId, accId, withVideo, hdrFrom, hdrTo);

    debugPrint(
        'AppCallsModel: Incoming SIP call - callId: $callId, from: $hdrFrom, to: $hdrTo');

    // Call the callback if set
    debugPrint('AppCallsModel: Calling onIncomingCallCallback...');
    onIncomingCallCallback?.call(callId, hdrFrom, hdrTo, withVideo);
    debugPrint('AppCallsModel: onIncomingCallCallback called');

    if (Platform.isIOS) {
      //TODO Match push and sip calls using just received SIP INVITE and data from push (put to '_callMatchers')
      //Get some hint from just received SIP INVITE (added by remote server) or math this SIP-call with CallKit-call

      //For Test, Disable below Code for prod
      String pushHint = 'somehint';

      //String pushHint =
      //    await SiprixVoipSdk().getSipHeader(callId, "X-PushHint") ??
      //        CallMatcher.kStubPushHint;

      debugPrint('onIncomingSip callId:$callId pushHint:$pushHint');
      //Searchs is there CallKit call which matches this one
      int index = _callMatchers.indexWhere((c) => c.push_Hint == pushHint);
      if (index != -1) {
        final matcher = _callMatchers[index];
        debugPrint(
            'onIncomingSip match index $index call:${matcher.callkit_CallUUID} <=> $callId');

        //Update CallKit with 'callId'
        matcher.sip_CallId = callId;
        SiprixVoipSdk().updateCallKitCallDetails(
            matcher.callkit_CallUUID, callId, null, null, null);
      } else {
        //Case - there is no CallKit call (push notif hasn't received yet)
        _callMatchers.add(CallMatcher("", pushHint, callId));
      }
      // iOS CallKit integration if needed
      //_handleiOSCallKit(callId, hdrFrom);
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

    debugPrint(
        'AppCallsModel: Call held - callId: $callId, holdState: $holdState');

    // Call the callback if set
    onCallHeldCallback?.call(callId, holdState);
  }

  /// Handle call proceeding (outgoing call ringing)
  @override
  void onProceeding(int callId, String response) {
    // IMPORTANT: Call super first to let builtin functionality work
    super.onProceeding(callId, response);

    debugPrint(
        'AppCallsModel: Call proceeding - callId: $callId, response: $response');

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
