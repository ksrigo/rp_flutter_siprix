import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Constants
  static const _colors = (
    primary: Color(0xFF8B5CF6),
    border: Color(0xFFD8B4FE),
    activeBorder: Color(0xFFE879F9),
    holdBorder: Color(0xFFF59E0B),
    avatar: Color(0xFFE6E6FA),
    avatarIcon: Color(0xFF6B46C1),
    active: Color(0xFF10B981),
    onHold: Color(0xFFF59E0B),
    connecting: Color(0xFF3B82F6),
    ringing: Color(0xFF8B5CF6),
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
      }
    });
  }

  CallInfo get _activeCall => _secondCall.state != AppCallState.ended ? _secondCall : _firstCall;
  CallInfo get _holdCall => _firstCall.id != _activeCall.id ? _firstCall : _secondCall;

  String _getDisplayName(CallInfo call) {
    final contact = _contactCache[call.id];
    return contact?.displayName?.isNotEmpty == true
        ? contact!.displayName
        : call.remoteName.isNotEmpty ? call.remoteName : call.remoteNumber;
  }

  String _getCallDuration(CallInfo call) {
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
        return _colors.connecting;
      case AppCallState.ringing:
        return _colors.ringing;
      case AppCallState.answered:
        return call.isOnHold ? _colors.onHold : _colors.active;
      case AppCallState.held:
        return _colors.onHold;
      case AppCallState.muted:
        return _colors.onHold; // Use same color as hold for muted state
      case AppCallState.reconnecting:
        return _colors.connecting; // Use same color as connecting for reconnecting
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

  void _onEndCall() async {
    try {
      // End the active call
      await SipService.instance.hangupCall(_activeCall.id);

      // Navigate back or to single call screen depending on remaining calls
      if (_holdCall.state != AppCallState.ended) {
        // Navigate to single call screen with the remaining call
        NavigationService.goToInCall(
          _holdCall.id,
          phoneNumber: _holdCall.remoteNumber,
          contactName: _getDisplayName(_holdCall),
        );
      } else {
        // Navigate back to main screen
        NavigationService.goToKeypad();
      }
    } catch (e) {
      debugPrint('MultiCallScreen: Error ending call: $e');
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
    return Column(
      children: [
        _buildCallCard(_holdCall, isActive: false),
        const SizedBox(height: 16),
        _buildCallCard(_activeCall, isActive: true),
      ],
    );
  }

  Widget _buildCallCard(CallInfo call, {required bool isActive}) {
    final contact = _contactCache[call.id];
    final hasPhoto = contact?.hasPhoto == true && contact?.photo != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? _colors.primary.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _colors.activeBorder : _colors.border.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _colors.activeBorder.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: _colors.activeBorder.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  call.remoteNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isActive ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getCallStatus(call),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(call),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getCallDuration(call),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isActive ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(CallInfo call, {bool hasPhoto = false, Uint8List? photo}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colors.avatar,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: _colors.avatar,
        backgroundImage: hasPhoto ? MemoryImage(photo!) : null,
        child: hasPhoto
            ? null
            : Text(
                _getDisplayName(call).substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _colors.avatarIcon,
                ),
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