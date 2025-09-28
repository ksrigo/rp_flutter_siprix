import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siprix_voip_sdk/calls_model.dart';

import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/contact_service.dart';

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
  Timer? _timer;
  Map<String, ContactInfo?> _contactCache = {};

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
    _startTimer();
    _listenToCallUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SipService.instance.removeHoldEventListener(_handleHoldStateChange);
    super.dispose();
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
      final contactInfo = await ContactService.instance.findContactByPhoneNumber(call.remoteNumber);
      if (mounted) {
        setState(() => _contactCache[callId] = contactInfo);
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error loading contact info for $callId: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Update call durations
          if (_firstCall.state == AppCallState.answered && _firstCall.startTime != null) {
            _firstCall = _firstCall.copyWith(
              startTime: _firstCall.startTime,
            );
          }
          if (_secondCall.state == AppCallState.answered && _secondCall.startTime != null) {
            _secondCall = _secondCall.copyWith(
              startTime: _secondCall.startTime,
            );
          }
        });
      }
    });
  }

  void _listenToCallUpdates() {
    // Listen to SIP service for call state updates
    SipService.instance.currentCallStream.listen((callInfo) {
      if (callInfo == null) return;

      if (mounted) {
        setState(() {
          if (callInfo.id == _firstCall.id) {
            _firstCall = callInfo;
          } else if (callInfo.id == _secondCall.id) {
            _secondCall = callInfo;
          }
        });

        // Check if one call has ended and navigate to single call screen
        _checkForCallEnded();
      }
    });

    // Listen to hold state changes
    SipService.instance.addHoldEventListener(_handleHoldStateChange);
  }

  void _handleHoldStateChange(int callId, HoldState holdState) {
    debugPrint('MultiCallScreen: Hold state changed - callId: $callId, holdState: $holdState');

    if (!mounted) return;

    setState(() {
      final callIdStr = callId.toString();

      // Update the corresponding CallInfo with new hold state
      if (_firstCall.id == callIdStr) {
        _firstCall = _firstCall.copyWith(
          isOnHold: holdState != HoldState.none,
          state: holdState != HoldState.none ? AppCallState.held : AppCallState.answered,
        );
      } else if (_secondCall.id == callIdStr) {
        _secondCall = _secondCall.copyWith(
          isOnHold: holdState != HoldState.none,
          state: holdState != HoldState.none ? AppCallState.held : AppCallState.answered,
        );
      }
    });
  }

  CallInfo get _activeCall {
    // First check the SDK's switched call to determine which is active
    final callsModel = SipService.instance.callsModel;
    final switchedCallId = callsModel?.switchedCallId;

    if (switchedCallId != null && switchedCallId > 0) {
      final switchedCallIdStr = switchedCallId.toString();
      if (_firstCall.id == switchedCallIdStr && _firstCall.state != AppCallState.ended) {
        return _firstCall;
      } else if (_secondCall.id == switchedCallIdStr && _secondCall.state != AppCallState.ended) {
        return _secondCall;
      }
    }

    // Fallback: Determine which call is currently active (not on hold and not ended)
    if (_firstCall.state != AppCallState.ended && !_firstCall.isOnHold && _firstCall.state != AppCallState.held) {
      return _firstCall;
    } else if (_secondCall.state != AppCallState.ended && !_secondCall.isOnHold && _secondCall.state != AppCallState.held) {
      return _secondCall;
    }

    // Final fallback to first non-ended call
    return _firstCall.state != AppCallState.ended ? _firstCall : _secondCall;
  }

  CallInfo get _holdCall {
    // Return the call that is NOT the active call
    return _activeCall.id == _firstCall.id ? _secondCall : _firstCall;
  }

  String _getDisplayName(CallInfo call) {
    final contact = _contactCache[call.id];
    return contact?.displayName?.isNotEmpty == true
        ? contact!.displayName
        : call.remoteName.isNotEmpty ? call.remoteName : call.remoteNumber;
  }

  String _getCallDuration(CallInfo call) {
    // Don't show timer for calls that are on hold
    if (call.isOnHold || call.state == AppCallState.held) return '';

    if (call.startTime == null || call.state != AppCallState.answered) return '00:00';
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
        return _cardColors.onHold; // Use same color as hold for muted state
      case AppCallState.reconnecting:
        return Colors.blue; // Use same color as connecting for reconnecting
      case AppCallState.ended:
      case AppCallState.failed:
        return Colors.red;
    }
  }

  void _onMute() async {
    try {
      final currentMuteState = _activeCall.isMuted;
      await SipService.instance.muteCall(_activeCall.id, !currentMuteState);
    } catch (e) {
      debugPrint('MultiCallScreen: Error toggling mute: $e');
    }
  }

  void _onSpeaker() async {
    try {
      final currentSpeakerState = _activeCall.isSpeakerOn;
      await SipService.instance.setSpeaker(_activeCall.id, !currentSpeakerState);
    } catch (e) {
      debugPrint('MultiCallScreen: Error toggling speaker: $e');
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

  void _onAddCall() {
    // Navigate back to call action screen for adding a third call
    // For now, limit to 2 calls
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maximum 2 calls supported')),
    );
  }

  void _onMergeCall() async {
    try {
      // Merge both calls into a conference
      // This would require conference functionality from Siprix
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conference merge functionality coming soon')),
      );
    } catch (e) {
      debugPrint('MultiCallScreen: Error merging calls: $e');
    }
  }

  void _onTransfer() {
    // Navigate to transfer screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transfer functionality coming soon')),
    );
  }

  void _onCallCardTap(CallInfo tappedCall) async {
    try {
      final callsModel = SipService.instance.callsModel;

      // First put current active call on hold
      await SipService.instance.holdCall(_activeCall.id);

      // Then unhold the tapped call
      await SipService.instance.unholdCall(tappedCall.id);

      // Finally switch to the tapped call
      await callsModel?.switchToCall(int.parse(tappedCall.id));
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

  void _checkForCallEnded() {
    final firstEnded = _firstCall.state == AppCallState.ended;
    final secondEnded = _secondCall.state == AppCallState.ended;

    if (firstEnded && !secondEnded) {
      // First call ended, navigate to single call screen with second call
      _navigateToSingleCall(_secondCall);
    } else if (secondEnded && !firstEnded) {
      // Second call ended, navigate to single call screen with first call
      _navigateToSingleCall(_firstCall);
    } else if (firstEnded && secondEnded) {
      // Both calls ended, navigate back to keypad
      NavigationService.goToKeypad();
    }
  }

  void _navigateToSingleCall(CallInfo remainingCall) {
    // Add a small delay to ensure the call state has been properly updated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        NavigationService.goToInCall(
          remainingCall.id,
          phoneNumber: remainingCall.remoteNumber,
          contactName: _getDisplayName(remainingCall),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A0B2E), Color(0xFF2D1B69), Color(0xFF4A1458)],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildCallCards(),
                const SizedBox(height: 40),
                Expanded(child: _buildControlButtons()),
                const SizedBox(height: 24),
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
    final firstCallIsActive = !_firstCall.isOnHold && _firstCall.state != AppCallState.held;
    final secondCallIsActive = !_secondCall.isOnHold && _secondCall.state != AppCallState.held;

    return Column(
      children: [
        // Always show first call in first position
        if (_firstCall.state != AppCallState.ended)
          _buildCallCard(
            _firstCall,
            isActive: firstCallIsActive,
            onTap: firstCallIsActive ? null : () => _onCallCardTap(_firstCall)
          ),
        if (_firstCall.state != AppCallState.ended && _secondCall.state != AppCallState.ended)
          const SizedBox(height: 16),

        // Always show second call in second position
        if (_secondCall.state != AppCallState.ended)
          _buildCallCard(
            _secondCall,
            isActive: secondCallIsActive,
            onTap: secondCallIsActive ? null : () => _onCallCardTap(_secondCall)
          ),
      ],
    );
  }

  Widget _buildCallCard(CallInfo call, {required bool isActive, VoidCallback? onTap}) {
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
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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
                      if (!isActive && (call.isOnHold || call.state == AppCallState.held))
                        Icon(
                          Icons.pause_circle_filled,
                          size: 12, // Smaller icon to match text size
                          color: _cardColors.onHold,
                        ),
                      if (!isActive && (call.isOnHold || call.state == AppCallState.held))
                        const SizedBox(width: 4),
                      Text(
                        _getCallStatus(call),
                        style: TextStyle(
                          fontSize: 12, // Match call_action_screen
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(call),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1), // Match call_action_screen
                  Text(
                    _getCallDuration(call),
                    style: TextStyle(
                      fontSize: 12, // Match call_action_screen
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.8), // Match call_action_screen
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

  Widget _buildAvatar(CallInfo call, {bool hasPhoto = false, Uint8List? photo}) {
    return Container(
      width: 32, // Match call_action_screen
      height: 32, // Match call_action_screen
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _cardColors.avatar,
        border: Border.all(color: Colors.white, width: 1.5), // Match call_action_screen
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
              icon: Icons.volume_up,
              label: 'Speaker',
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
        // Second row: Keypad, Add Call, Merge Call
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.dialpad,
              label: 'Keypad',
              onPressed: _onKeypad,
            ),
            _buildControlButton(
              icon: Icons.person_add,
              label: 'Add Call',
              onPressed: _onAddCall,
            ),
            _buildControlButton(
              icon: Icons.call_merge,
              label: 'Merge Call',
              onPressed: _onMergeCall,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Third row: Transfer (centered)
        _buildControlButton(
          icon: Icons.call_split,
          label: 'Transfer',
          onPressed: _onTransfer,
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
                ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)
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
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _onEndCall,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.call_end,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'End Call',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}