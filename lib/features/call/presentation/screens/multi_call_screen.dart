import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siprix_voip_sdk/calls_model.dart';

import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/contact_service.dart';
import 'in_call_screen.dart';

class MultiCallScreen extends ConsumerStatefulWidget {
  final CallInfo firstCall;
  final CallInfo secondCall;

  const MultiCallScreen({
    super.key,
    required this.firstCall,
    required this.secondCall,
  });

  @override
  ConsumerState<MultiCallScreen> createState() => _MultiCallScreenState();
}

class _MultiCallScreenState extends ConsumerState<MultiCallScreen> {
  late CallInfo _firstCall;
  late CallInfo _secondCall;
  Map<String, ContactInfo?> _contactCache = {};
  bool _isNavigating = false;
  StreamSubscription<CallInfo?>? _currentCallSubscription;

  // Constants - match call_action_screen styling
  static const _cardColors = (
    primary: Color(0xFF8B5CF6),
    border: Color(0xFFD8B4FE),
    avatar: Color(0xFFE6E6FA),
    avatarIcon: Color(0xFF6B46C1),
    active: Color(0xFF10B981),
    onHold: Color(0xFFF59E0B),
  );

  @override
  void initState() {
    super.initState();
    _firstCall = widget.firstCall;
    _secondCall = widget.secondCall;
    _loadContactInfo();

    // Sync initial speaker state from SipService
    _syncSpeakerState();

    // Listen to currentCallStream for speaker state changes
    _currentCallSubscription = SipService.instance.currentCallStream.listen((callInfo) {
      if (callInfo != null && mounted) {
        _syncSpeakerStateFromCallInfo(callInfo);
      }
    });

    // Add CallsModel listener for all state updates
    final callsModel = SipService.instance.callsModel;
    if (callsModel != null) {
      debugPrint(
          'MultiCallScreen: Adding listener to CallsModel with ${callsModel.length} calls');
      callsModel.addListener(_onCallsModelChanged);

      // Set up switched event callback specifically for call switching navigation
      callsModel.onCallSwitchedCallback = _onCallSwitched;

      // Trigger initial state update
      debugPrint('MultiCallScreen: Triggering initial state update');
      _onCallsModelChanged();
    } else {
      debugPrint('MultiCallScreen: CallsModel is null, cannot add listener');
    }
  }

  void _syncSpeakerState() {
    // On Android, multi-call scenarios default to speaker
    // The SDK's audio manager automatically switches to speaker for better UX
    final isSpeakerOn = Platform.isAndroid ? true : (SipService.instance.currentCall?.isSpeakerOn ?? false);
    debugPrint('MultiCallScreen: Setting initial speaker state to $isSpeakerOn (Android auto-speaker)');

    // Update both calls with the speaker state
    _firstCall = _firstCall.copyWith(isSpeakerOn: isSpeakerOn);
    _secondCall = _secondCall.copyWith(isSpeakerOn: isSpeakerOn);
  }

  void _syncSpeakerStateFromCallInfo(CallInfo callInfo) {
    // Update speaker state for both calls when it changes
    if (_firstCall.isSpeakerOn != callInfo.isSpeakerOn ||
        _secondCall.isSpeakerOn != callInfo.isSpeakerOn) {
      debugPrint('MultiCallScreen: Speaker state changed to ${callInfo.isSpeakerOn}');
      setState(() {
        _firstCall = _firstCall.copyWith(isSpeakerOn: callInfo.isSpeakerOn);
        _secondCall = _secondCall.copyWith(isSpeakerOn: callInfo.isSpeakerOn);
      });
    }

    // On Android, when a call connects, the SDK may automatically switch to speaker
    // We need to detect this and update our UI accordingly
    if (callInfo.state == AppCallState.answered) {
      // Add a small delay to let the audio device settle
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final currentCall = SipService.instance.currentCall;
          if (currentCall != null && currentCall.isSpeakerOn != _firstCall.isSpeakerOn) {
            debugPrint('MultiCallScreen: Detected speaker state mismatch after connect, syncing to ${currentCall.isSpeakerOn}');
            setState(() {
              _firstCall = _firstCall.copyWith(isSpeakerOn: currentCall.isSpeakerOn);
              _secondCall = _secondCall.copyWith(isSpeakerOn: currentCall.isSpeakerOn);
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _currentCallSubscription?.cancel();
    final callsModel = SipService.instance.callsModel;
    if (callsModel != null) {
      callsModel.removeListener(_onCallsModelChanged);
      callsModel.onCallSwitchedCallback = null;
    }
    super.dispose();
  }

  void _onCallSwitched(int callId) {
    debugPrint(
        'MultiCallScreen: Call switched event received - callId: $callId');

    // Only check for call switching on actual switched events
    _checkForCallSwitched();
  }

  void _loadContactInfo() async {
    await _loadContactForCall(_firstCall.id);
    await _loadContactForCall(_secondCall.id);
  }

  Future<void> _loadContactForCall(String callId) async {
    final call = callId == _firstCall.id ? _firstCall : _secondCall;
    if (_contactCache.containsKey(callId)) return;

    try {
      if (!ContactService.instance.hasPermission) return;
      final contactInfo = await ContactService.instance
          .findContactByPhoneNumber(call.remoteNumber);
      if (mounted) {
        setState(() => _contactCache[callId] = contactInfo);
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error loading contact info for $callId: $e');
    }
  }


  void _onCallsModelChanged() {
    debugPrint('MultiCallScreen: CallsModel changed event triggered');

    if (!mounted) {
      debugPrint('MultiCallScreen: Not mounted, skipping update');
      return;
    }

    final callsModel = SipService.instance.callsModel;
    if (callsModel == null) {
      debugPrint('MultiCallScreen: CallsModel is null');
      return;
    }

    debugPrint('MultiCallScreen: CallsModel has ${callsModel.length} calls');

    // Track calls that are still in the model
    bool firstCallStillExists = false;
    bool secondCallStillExists = false;

    setState(() {
      // Update call states and hold states from CallsModel
      for (int i = 0; i < callsModel.length; i++) {
        final call = callsModel[i];
        final callIdStr = call.myCallId.toString();

        debugPrint(
            'MultiCallScreen: Processing call $callIdStr - SDK state: ${call.state}, hold: ${call.isLocalHold || call.isRemoteHold}, muted: ${call.isMicMuted}');

        // Determine if call is on hold (local or remote hold)
        final isOnHold = call.isLocalHold || call.isRemoteHold;
        final isMuted = call.isMicMuted;
        final newAppState = _mapCallStateToAppState(call.state);

        if (callIdStr == _firstCall.id) {
          firstCallStillExists = true;
          debugPrint(
              'MultiCallScreen: Updating first call $callIdStr - from ${_firstCall.state} to $newAppState, hold: $isOnHold, muted: $isMuted');
          _firstCall = _firstCall.copyWith(
            state: newAppState,
            isOnHold: isOnHold,
            isMuted: isMuted,
          );
        } else if (callIdStr == _secondCall.id) {
          secondCallStillExists = true;
          debugPrint(
              'MultiCallScreen: Updating second call $callIdStr - from ${_secondCall.state} to $newAppState, hold: $isOnHold, muted: $isMuted');
          _secondCall = _secondCall.copyWith(
            state: newAppState,
            isOnHold: isOnHold,
            isMuted: isMuted,
          );
        } else {
          debugPrint(
              'MultiCallScreen: Call $callIdStr does not match any tracked calls (first: ${_firstCall.id}, second: ${_secondCall.id})');
        }
      }

      // Mark calls as ended if they're no longer in the CallsModel
      if (!firstCallStillExists && _firstCall.state != AppCallState.ended) {
        debugPrint(
            'MultiCallScreen: First call ${_firstCall.id} no longer exists in CallsModel, marking as ended');
        _firstCall = _firstCall.copyWith(state: AppCallState.ended);
      }
      if (!secondCallStillExists && _secondCall.state != AppCallState.ended) {
        debugPrint(
            'MultiCallScreen: Second call ${_secondCall.id} no longer exists in CallsModel, marking as ended');
        _secondCall = _secondCall.copyWith(state: AppCallState.ended);
      }
    });

    // Check if we need to navigate after state updates
    _checkForCallEnded();
  }

  AppCallState _mapCallStateToAppState(CallState callState) {
    switch (callState) {
      case CallState.dialing:
      case CallState.accepting:
        return AppCallState.connecting;
      case CallState.proceeding:
      case CallState.ringing:
        return AppCallState.ringing;
      case CallState.rejecting:
      case CallState.disconnecting:
        return AppCallState.ended;
      case CallState.connected:
        return AppCallState.answered;
      case CallState.holding:
      case CallState.held:
        return AppCallState.held;
      default:
        return AppCallState.none;
    }
  }

  CallInfo get _activeCall {
    final callsModel = SipService.instance.callsModel;
    final switchedCall = callsModel?.switchedCall();

    if (switchedCall != null) {
      final switchedCallIdStr = switchedCall.myCallId.toString();
      if (_firstCall.id == switchedCallIdStr && _firstCall.state != AppCallState.ended) {
        return _firstCall;
      } else if (_secondCall.id == switchedCallIdStr && _secondCall.state != AppCallState.ended) {
        return _secondCall;
      }
    }

    // Fallback to first non-ended, non-held call
    if (_firstCall.state != AppCallState.ended && !_firstCall.isOnHold) {
      return _firstCall;
    }
    return _secondCall.state != AppCallState.ended ? _secondCall : _firstCall;
  }

  CallInfo get _holdCall {
    // Return the call that is NOT the active call
    return _activeCall.id == _firstCall.id ? _secondCall : _firstCall;
  }

  String _getDisplayName(CallInfo call) {
    final contact = _contactCache[call.id];
    return contact?.displayName?.isNotEmpty == true
        ? contact!.displayName
        : call.remoteName.isNotEmpty
            ? call.remoteName
            : call.remoteNumber;
  }

  String _getCallDuration(CallInfo call) {
    if (call.state != AppCallState.answered || call.isOnHold || call.startTime == null) {
      return '';
    }

    final duration = DateTime.now().difference(call.startTime!);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getCallStatus(CallInfo call) {
    switch (call.state) {
      case AppCallState.none:
        return 'Unknown';
      case AppCallState.connecting:
        return 'Connecting';
      case AppCallState.ringing:
        return 'Ringing';
      case AppCallState.answered:
        return call.isOnHold ? 'On Hold' : 'Active';
      case AppCallState.held:
        return 'On Hold';
      case AppCallState.muted:
        return 'Muted';
      case AppCallState.reconnecting:
        return 'Reconnecting';
      case AppCallState.ended:
        return 'Ended';
      case AppCallState.failed:
        return 'Failed';
    }
  }

  Color _getStatusColor(CallInfo call) {
    switch (call.state) {
      case AppCallState.none:
        return Colors.grey;
      case AppCallState.connecting:
        return Colors.blue;
      case AppCallState.ringing:
        return _cardColors.primary;
      case AppCallState.answered:
        return call.isOnHold ? _cardColors.onHold : _cardColors.active;
      case AppCallState.held:
        return _cardColors.onHold;
      case AppCallState.muted:
        return _cardColors.onHold;
      case AppCallState.reconnecting:
        return Colors.blue;
      case AppCallState.ended:
      case AppCallState.failed:
        return Colors.red;
    }
  }

  void _onMute() async {
    try {
      debugPrint('MultiCallScreen: Toggling mute for active call ${_activeCall.id}');

      // Find the active call object
      final activeCallObj = SipService.instance.findCallByCallId(_activeCall.id);
      if (activeCallObj == null) {
        debugPrint('MultiCallScreen: Could not find active call object');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to toggle mute: Call not found')),
          );
        }
        return;
      }

      // Toggle mute state using CallModel's muteMic method
      final newMuteState = !activeCallObj.isMicMuted;
      debugPrint('MultiCallScreen: Setting mute to $newMuteState');
      await activeCallObj.muteMic(newMuteState);

      debugPrint('MultiCallScreen: Mute toggled successfully');

      // Manually update the UI since SDK doesn't fire an event for mute changes
      if (mounted) {
        setState(() {
          // Update the call that was muted
          if (_firstCall.id == _activeCall.id) {
            _firstCall = _firstCall.copyWith(isMuted: newMuteState);
          } else if (_secondCall.id == _activeCall.id) {
            _secondCall = _secondCall.copyWith(isMuted: newMuteState);
          }
        });
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error toggling mute: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle mute: $e')),
        );
      }
    }
  }

  void _onSpeaker() async {
    try {
      debugPrint('MultiCallScreen: Toggling speaker for active call ${_activeCall.id}');

      final currentSpeakerState = _activeCall.isSpeakerOn;
      final newSpeakerState = !currentSpeakerState;

      debugPrint('MultiCallScreen: Setting speaker to $newSpeakerState');
      await SipService.instance.setSpeaker(_activeCall.id, newSpeakerState);

      debugPrint('MultiCallScreen: Speaker toggled successfully');

      // Manually update the UI since SDK doesn't fire an event for speaker changes
      if (mounted) {
        setState(() {
          // Update the call that had speaker toggled
          if (_firstCall.id == _activeCall.id) {
            _firstCall = _firstCall.copyWith(isSpeakerOn: newSpeakerState);
          } else if (_secondCall.id == _activeCall.id) {
            _secondCall = _secondCall.copyWith(isSpeakerOn: newSpeakerState);
          }
        });
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error toggling speaker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle speaker: $e')),
        );
      }
    }
  }

  void _onHoldResume() async {
    try {
      if (_activeCall.isOnHold) {
        await SipService.instance.unholdCall(_activeCall.id);
      } else {
        await SipService.instance.holdCall(_activeCall.id);
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error toggling hold: $e');
    }
  }

  void _onKeypad() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Keypad')),
          body: const Center(child: Text('Keypad functionality coming soon')),
        ),
      ),
    );
  }

  void _onMergeCall() async {
    try {
      // Merge both calls into a conference
      // This would require conference functionality from Siprix
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Conference merge functionality coming soon')),
      );
    } catch (e) {
      debugPrint('MultiCallScreen: Error merging calls: $e');
    }
  }

  void _onTransfer() async {
    try {
      debugPrint('MultiCallScreen: Initiating attended transfer');

      // Find which call is active and which is on hold
      CallInfo? activeCall;
      CallInfo? heldCall;

      if (!_firstCall.isOnHold && _firstCall.state != AppCallState.held) {
        activeCall = _firstCall;
        heldCall = _secondCall;
      } else if (!_secondCall.isOnHold && _secondCall.state != AppCallState.held) {
        activeCall = _secondCall;
        heldCall = _firstCall;
      }

      if (activeCall == null || heldCall == null) {
        debugPrint('MultiCallScreen: Cannot transfer - need one active and one held call');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot transfer: Need one active and one held call')),
          );
        }
        return;
      }

      // Find the active call object
      final activeCallObj = SipService.instance.findCallByCallId(activeCall.id);
      if (activeCallObj == null) {
        debugPrint('MultiCallScreen: Could not find active call object');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to transfer: Active call not found')),
          );
        }
        return;
      }

      // Parse the held call ID
      final heldCallId = int.tryParse(heldCall.id);
      if (heldCallId == null) {
        debugPrint('MultiCallScreen: Invalid held call ID: ${heldCall.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to transfer: Invalid call ID')),
          );
        }
        return;
      }

      debugPrint('MultiCallScreen: Transferring active call ${activeCall.id} to held call ${heldCall.id}');

      // Perform attended transfer
      await activeCallObj.transferAttended(heldCallId);

      debugPrint('MultiCallScreen: Attended transfer initiated successfully');

      // Navigate back to keypad after transfer
      if (mounted) {
        NavigationService.goToKeypad();
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Transfer failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to transfer: $e')),
        );
      }
    }
  }

  void _onCallCardTap(CallInfo tappedCall) async {
    try {
      debugPrint('MultiCallScreen: Tapping on call ${tappedCall.id} to switch to it');

      final callsModel = SipService.instance.callsModel;
      if (callsModel == null) return;

      // Find the tapped call in the model
      final tappedCallObj = SipService.instance.findCallByCallId(tappedCall.id);

      if (tappedCallObj != null) {
        debugPrint('MultiCallScreen: Found tapped call, isOnHold: ${tappedCallObj.isLocalHold}');

        // If the tapped call is on hold, we need to swap the calls
        if (tappedCallObj.isLocalHold) {
          // First, find the currently active call and hold it
          final firstCallObj = SipService.instance.findCallByCallId(_firstCall.id);
          final secondCallObj = SipService.instance.findCallByCallId(_secondCall.id);

          // Determine which call is currently active (not on hold)
          CallModel? activeCallObj;
          if (firstCallObj != null && !firstCallObj.isLocalHold && _firstCall.id != tappedCall.id) {
            activeCallObj = firstCallObj;
          } else if (secondCallObj != null && !secondCallObj.isLocalHold && _secondCall.id != tappedCall.id) {
            activeCallObj = secondCallObj;
          }

          // Hold the currently active call first
          if (activeCallObj != null) {
            debugPrint('MultiCallScreen: Holding active call ${activeCallObj.myCallId} first');
            await activeCallObj.hold();
            // Small delay to ensure hold completes
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Then unhold the tapped call
          debugPrint('MultiCallScreen: Unholding tapped call ${tappedCall.id}');
          await tappedCallObj.hold(); // hold() is a toggle method
        } else {
          // If it's not on hold, it's already active - do nothing
          debugPrint('MultiCallScreen: Call ${tappedCall.id} is already active');
        }
      } else {
        debugPrint('MultiCallScreen: Could not find call object for ${tappedCall.id}');
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error switching calls: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch calls: $e')),
        );
      }
    }
  }

  void _onEndCall() async {
    try {
      // End the active call
      await SipService.instance.hangupCall(_activeCall.id);
      // Navigation will be handled by _checkForCallEnded() when call state updates
    } catch (e) {
      debugPrint('MultiCallScreen: Error ending call: $e');
    }
  }

  void _checkForCallSwitched() {
    _checkCallCount();
  }

  void _checkForCallEnded() {
    _checkCallCount();
  }

  void _checkCallCount() {
    if (_isNavigating) return;

    final callsModel = SipService.instance.callsModel;
    if (callsModel == null) return;

    final callCount = callsModel.length;
    debugPrint('MultiCallScreen: CallsModel has $callCount calls');

    if (callCount == 1) {
      final remainingCall = callsModel[0];
      final callIdStr = remainingCall.myCallId.toString();

      CallInfo? activeCallInfo;
      if (_firstCall.id == callIdStr && _firstCall.state != AppCallState.ended) {
        activeCallInfo = _firstCall;
      } else if (_secondCall.id == callIdStr && _secondCall.state != AppCallState.ended) {
        activeCallInfo = _secondCall;
      }

      if (activeCallInfo != null) {
        debugPrint('MultiCallScreen: Navigating to single call screen');
        _navigateToSingleCall(activeCallInfo);
      }
    } else if (callCount == 0) {
      debugPrint('MultiCallScreen: No calls remaining, navigating to keypad');
      _isNavigating = true;
      NavigationService.goToKeypad();
    }
  }

  void _navigateToSingleCall(CallInfo remainingCall) async {
    debugPrint(
        'MultiCallScreen: Navigating to single call - callId: ${remainingCall.id}, isOnHold: ${remainingCall.isOnHold}');

    try {
      // If the remaining call is on hold, unhold it first
      if (remainingCall.isOnHold || remainingCall.state == AppCallState.held) {
        debugPrint(
            'MultiCallScreen: Unholding remaining call ${remainingCall.id}');
        await SipService.instance.unholdCall(remainingCall.id);

        // Wait a bit for the unhold to take effect
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Navigate to single call screen using Navigator (not GoRouter) since we're in Navigator stack
      if (mounted) {
        debugPrint(
            'MultiCallScreen: Navigating to InCallScreen for call ${remainingCall.id}');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InCallScreen(
              callId: remainingCall.id,
              phoneNumber: remainingCall.remoteNumber,
              contactName: _getDisplayName(remainingCall),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error in _navigateToSingleCall: $e');

      // Navigate anyway even if unhold fails
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InCallScreen(
              callId: remainingCall.id,
              phoneNumber: remainingCall.remoteNumber,
              contactName: _getDisplayName(remainingCall),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A0B2E),
              Color(0xFF2D1B69),
              Color(0xFF4A1458)
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildCallCards(),
                const Spacer(), // Push control buttons towards bottom
                _buildControlButtons(),
                const SizedBox(height: 48), // Match in_call_screen spacing
                _buildEndCallButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallCards() {
    // Determine active styling based on hold state: if not on hold, show as active
    final firstCallIsActive =
        !_firstCall.isOnHold && _firstCall.state != AppCallState.held;
    final secondCallIsActive =
        !_secondCall.isOnHold && _secondCall.state != AppCallState.held;

    return Column(
      children: [
        // Always show first call in first position
        if (_firstCall.state != AppCallState.ended)
          _buildCallCard(_firstCall,
              isActive: firstCallIsActive,
              onTap:
                  firstCallIsActive ? null : () => _onCallCardTap(_firstCall)),
        if (_firstCall.state != AppCallState.ended &&
            _secondCall.state != AppCallState.ended)
          const SizedBox(height: 16),

        // Always show second call in second position
        if (_secondCall.state != AppCallState.ended)
          _buildCallCard(_secondCall,
              isActive: secondCallIsActive,
              onTap: secondCallIsActive
                  ? null
                  : () => _onCallCardTap(_secondCall)),
      ],
    );
  }

  Widget _buildCallCard(CallInfo call,
      {required bool isActive, VoidCallback? onTap}) {
    final contact = _contactCache[call.id];
    final hasPhoto = contact?.hasPhoto == true && contact?.photo != null;

    // Use same color logic as call_action_screen
    final colors = isActive
        ? (_cardColors.primary.withValues(alpha: 0.4), _cardColors.border)
        : (
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.3)
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12), // Match call_action_screen
          decoration: BoxDecoration(
            color: colors.$1,
            borderRadius: BorderRadius.circular(12), // Match call_action_screen
            border: Border.all(color: colors.$2, width: isActive ? 2 : 1),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _cardColors.border.withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _cardColors.border.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null, // No shadow for inactive cards like call_action_screen
          ),
          child: Row(
            children: [
              _buildAvatar(call, hasPhoto: hasPhoto, photo: contact?.photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayName(call),
                      style: TextStyle(
                        fontSize: 16, // Match call_action_screen
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1), // Match call_action_screen
                    Text(
                      call.remoteNumber,
                      style: TextStyle(
                        fontSize: 12, // Match call_action_screen
                        fontWeight: FontWeight.w400,
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isActive &&
                          (call.isOnHold || call.state == AppCallState.held))
                        Icon(
                          Icons.pause_circle_filled,
                          size: 12, // Smaller icon to match text size
                          color: _cardColors.onHold,
                        ),
                      if (!isActive &&
                          (call.isOnHold || call.state == AppCallState.held))
                        const SizedBox(width: 4),
                      _buildStatusChip(call, isActive),
                    ],
                  ),
                  const SizedBox(height: 1), // Match call_action_screen
                  Text(
                    _getCallDuration(call),
                    style: TextStyle(
                      fontSize: 12, // Match call_action_screen
                      fontWeight: FontWeight.w400,
                      color: Colors.white
                          .withValues(alpha: 0.8), // Match call_action_screen
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(CallInfo call, bool isActive) {
    final status = _getCallStatus(call);
    final statusColor = _getStatusColor(call);

    // Use chip with background for better visibility
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white
                .withValues(alpha: 0.9) // White background for active cards
            : statusColor.withValues(
                alpha: 0.2), // Colored background for inactive cards
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? null
            : Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10, // Slightly smaller for chip
          fontWeight: FontWeight.w600,
          color: isActive
              ? statusColor // Colored text on white background
              : statusColor, // Colored text on colored background
        ),
      ),
    );
  }

  Widget _buildAvatar(CallInfo call,
      {bool hasPhoto = false, Uint8List? photo}) {
    return Container(
      width: 32, // Match call_action_screen
      height: 32, // Match call_action_screen
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _cardColors.avatar,
        border: Border.all(
            color: Colors.white, width: 1.5), // Match call_action_screen
      ),
      child: CircleAvatar(
        radius: 16, // Match call_action_screen
        backgroundColor: _cardColors.avatar,
        backgroundImage: hasPhoto ? MemoryImage(photo!) : null,
        child: hasPhoto
            ? null
            : Icon(
                Icons.person,
                size: 16, // Match call_action_screen
                color: _cardColors.avatarIcon,
              ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        // First row: Mute, Speaker, Hold
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _activeCall.isMuted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              isActive: _activeCall.isMuted,
              onPressed: _onMute,
            ),
            _buildControlButton(
              icon: _activeCall.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: _activeCall.isSpeakerOn ? 'Speaker' : 'Earpiece',
              isActive: _activeCall.isSpeakerOn,
              onPressed: _onSpeaker,
            ),
            _buildControlButton(
              icon: _activeCall.isOnHold ? Icons.play_arrow : Icons.pause,
              label: _activeCall.isOnHold ? 'Resume' : 'Hold',
              isActive: _activeCall.isOnHold,
              onPressed: _onHoldResume,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Second row: Keypad, Transfer, Merge Call
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.dialpad,
              label: 'Keypad',
              onPressed: _onKeypad,
            ),
            _buildControlButton(
              icon: Icons.call_split,
              label: 'Transfer',
              onPressed: _onTransfer,
            ),
            _buildControlButton(
              icon: Icons.call_merge,
              label: 'Merge Call',
              onPressed: _onMergeCall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.15),
            border: isActive
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 2)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: onPressed,
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildEndCallButton() {
    return Center(
      child: Container(
        width: 280, // Match in_call_screen
        height: 56, // Match in_call_screen
        decoration: BoxDecoration(
          color: Color(0xFFE53E3E), // Match in_call_screen
          borderRadius: BorderRadius.circular(28), // Match in_call_screen
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28), // Match in_call_screen
            onTap: _onEndCall,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 20, // Match in_call_screen
                ),
                SizedBox(width: 8), // Match in_call_screen
                Text(
                  'End Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16, // Match in_call_screen
                    fontWeight: FontWeight.w600, // Match in_call_screen
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
