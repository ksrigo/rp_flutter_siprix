import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:is_lock_screen2/is_lock_screen2.dart';
import 'package:siprix_voip_sdk/accounts_model.dart';
import 'package:siprix_voip_sdk/calls_model.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';

// Import CallMatcher from sip_service_base
import '../../main.dart';
import '../../shared/services/storage_service.dart';
import '../constants/app_constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/contacts_service.dart';
import '../services/notification_service.dart';
import '../services/sip_service/sip_service_base.dart' show CallMatcher, SipService, SipServiceCallHandling;

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
  /// Override onIncomingPush to handle iOS PushKit notifications
  /// Override onIncomingPush to handle iOS PushKit notifications
  ///
  /// This is fixed by myself by initializing registration again

  @override
  void onIncomingPush(String callkitUuid, Map<String, dynamic> pushPayload) async {
    if (!Platform.isIOS) return;
    try {
      print('=================================================');
      print('🔔 iOS PUSH: AppCallsModel.onIncomingPush CALLED');
      print('🔔 iOS PUSH: CallKit UUID: $callkitUuid');
      print('🔔 iOS PUSH: Raw Payload: $pushPayload');
      print('=================================================');

      // ✅ Extract payload safely
      Map<String, dynamic>? apsPayload;
      try {
        apsPayload = Map<String, dynamic>.from(pushPayload["aps"]);
        debugPrint('🔔 iOS PUSH: APS Payload extracted: $apsPayload');
      } catch (err) {
        debugPrint('🔔 iOS PUSH: Error extracting APS payload: $err');
      }

      // ✅ Parse incoming call data
      String pushHint = apsPayload?["pushHint"] ??
          apsPayload?["call_id"] ??
          apsPayload?["uuid"] ??
          CallMatcher.kStubPushHint;

      String genericHandle = apsPayload?["callerNumber"] ??
          apsPayload?["from"] ??
          "Unknown";

      String localizedCallerName = apsPayload?["callerId"] ??
          apsPayload?["callerName"] ??
          "Unknown";

      debugPrint('🔔 iOS PUSH: Extracted data:');
      debugPrint(' - pushHint: $pushHint');
      debugPrint(' - callerName: $localizedCallerName');
      debugPrint(' - callerNumber: $genericHandle');
      debugPrint(' - callkitUuid: $callkitUuid');

      // Add call matcher for SIP-CallKit matching
      _callMatchers.add(CallMatcher(callkitUuid, pushHint));
      debugPrint('🔔 iOS PUSH: Added CallMatcher for pushHint: $pushHint');

      // Update CallKit display
      await startBackgroundTask(callkitUuid, localizedCallerName);

      debugPrint('🔔 iOS PUSH: AppConstants.isMainCalled ${AppConstants.isMainCalled}'
          ': ${SipServiceCallHandling.isAppInForeground}');

      if(SipServiceCallHandling.isAppInForeground){
        await SipService.instance.reregister();
      } else if(!AppConstants.isMainCalled) {
        await SipService.instance.reregister();
      } else{
        AppConstants.isMainCalled = false;
      }
      String? version = await SiprixVoipSdk().version();//siprix 1.0.31 from 20251123_2311
      debugPrint('🔔 iOS PUSH: onIncomingPush COMPLETED $version');
    } catch (e, st) {
      debugPrint('🔔 iOS PUSH: CRITICAL ERROR in onIncomingPush: $e\n$st');
    }
  }

  Future<void> startBackgroundTask(String callkitUuid, String localizedCallerName) async {
    await SiprixVoipSdk().updateCallKitCallDetails(
        callkitUuid, null,
        localizedCallerName,
        null,
        false
    );
  }

  /// Enhanced onIncomingSip with better matching
  @override
  void onIncomingSip(int callId, int accId, bool withVideo, String hdrFrom, String hdrTo) async {
    debugPrint('>>> 🔔 AppCallsModel.onIncomingSip CALLED - callId: $callId, from: $hdrFrom, to: $hdrTo');

    // IMPORTANT: Call super first to let builtin functionality work
    super.onIncomingSip(callId, accId, withVideo, hdrFrom, hdrTo);

    // Notify about incoming call
    onIncomingCallCallback?.call(callId, hdrFrom, hdrTo, withVideo);

    if (Platform.isIOS) {
      // Extract push hint from SIP headers
      final String pushHint = await _extractPushHintFromSip(callId, hdrFrom);

      debugPrint('🔔 onIncomingSip: Final pushHint: $pushHint for callId: $callId');
      print('🕒 SIP ARRIVED at ${DateTime.now()} - callId: $callId, pushHint: $pushHint');

      // Match with CallKit call
      await _matchSipWithCallKit(callId, pushHint);
    }
  }

  /// Extract push hint from SIP headers
  Future<String> _extractPushHintFromSip(int callId, String hdrFrom) async {
    String? pushHint;
    List<String> headerOptions = ["X-PushHint", "Call-ID", "X-Call-ID", "X-UUID"];

    for (String header in headerOptions) {
      pushHint = await SiprixVoipSdk().getSipHeader(callId, header);
      if (pushHint != null && pushHint.isNotEmpty) {
        debugPrint('onIncomingSip: Found pushHint "$pushHint" from header: $header');
        break;
      }
    }

    // Fallback: Extract from From header
    if (pushHint == null || pushHint.isEmpty) {
      try {
        final fromUri = hdrFrom.split(';').first; // Remove parameters
        final match = RegExp(r'sip:([^@>]*)').firstMatch(fromUri);
        pushHint = match?.group(1) ?? CallMatcher.kStubPushHint;
        debugPrint('onIncomingSip: Using From header extracted pushHint: $pushHint');
      } catch (e) {
        pushHint = CallMatcher.kStubPushHint;
        debugPrint('onIncomingSip: Using stub pushHint due to error: $e');
      }
    }

    return pushHint;
  }

  /// Match SIP call with CallKit call
  Future<void> _matchSipWithCallKit(int callId, String pushHint) async {
    debugPrint('🔍 MATCHING: Looking for CallKit match for pushHint: $pushHint');
    debugPrint('🔍 MATCHING: Available matchers: ${_callMatchers..map((m) => m.push_Hint).toList()}');

    // Search for matching CallKit call
    int index = _callMatchers.indexWhere((c) => c.push_Hint == pushHint);
    if (index != -1) {
      final matcher = _callMatchers[index];
      debugPrint('✅ MATCHING: FOUND - callkit:${matcher.callkit_CallUUID} <=> sip:$callId');

      // Update CallKit with actual callId - CRITICAL STEP
      matcher.sip_CallId = callId;
      try {
        await SiprixVoipSdk().updateCallKitCallDetails(
          matcher.callkit_CallUUID,
          callId,
          null,
          null,
          null,
        );
        debugPrint('✅ MATCHING: CallKit details updated successfully');

        // Remove matched entry
        _callMatchers..removeAt(index);
        debugPrint('✅ MATCHING: Removed matched entry, remaining: ${_callMatchers..length}');
      } catch (e) {
        debugPrint('❌ MATCHING: Failed to update CallKit details: $e');
      }
    } else {
      // No matching CallKit call found
      debugPrint('❌ MATCHING: NO MATCH FOUND for pushHint: $pushHint');

      // Add for potential late matching
      _callMatchers.add(CallMatcher("", pushHint, callId));
      debugPrint('📝 MATCHING: Added late matcher for pushHint: $pushHint');
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
    AppConstants.isCallConnected = true;
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

}