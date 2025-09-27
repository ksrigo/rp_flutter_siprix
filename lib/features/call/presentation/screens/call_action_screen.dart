import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/contact_service.dart';
import 'multi_call_screen.dart';

enum CallActionType { addCall, transfer }

class CallActionScreen extends ConsumerStatefulWidget {
  final CallActionType actionType;
  final CallInfo? activeCall;

  const CallActionScreen({
    super.key,
    required this.actionType,
    this.activeCall,
  });

  @override
  ConsumerState<CallActionScreen> createState() => _CallActionScreenState();
}

class _CallActionScreenState extends ConsumerState<CallActionScreen> {
  String _enteredNumber = '';
  ContactInfo? _contactInfo;

  // Constants
  static const _cardColors = (
    primary: Color(0xFF8B5CF6),
    border: Color(0xFFD8B4FE),
    avatar: Color(0xFFE6E6FA),
    avatarIcon: Color(0xFF6B46C1),
    active: Color(0xFF10B981),
    onHold: Color(0xFFF59E0B),
  );

  static const _keypadData = [
    [('1', ''), ('2', 'ABC'), ('3', 'DEF')],
    [('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO')],
    [('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ')],
    [('*', ''), ('0', '+'), ('#', '')],
  ];

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    final phoneNumber = widget.activeCall?.remoteNumber;
    if (phoneNumber?.isEmpty != false || phoneNumber == 'Unknown') return;

    try {
      if (!ContactService.instance.hasPermission) return;
      final contactInfo =
          await ContactService.instance.findContactByPhoneNumber(phoneNumber!);
      if (mounted) setState(() => _contactInfo = contactInfo);
    } catch (e) {
      debugPrint('CallActionScreen: Error loading contact info: $e');
    }
  }

  String get _displayName => _contactInfo?.displayName?.isNotEmpty == true
      ? _contactInfo!.displayName
      : widget.activeCall?.remoteName?.isNotEmpty == true
          ? widget.activeCall!.remoteName
          : widget.activeCall?.remoteNumber ?? 'Unknown';

  String get _callDuration {
    if (widget.activeCall == null) return '00:00';
    final duration = DateTime.now().difference(widget.activeCall!.startTime);
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String get _callStatus =>
      widget.activeCall?.isOnHold == true ? 'On Hold' : 'Active';
  Color get _statusColor => widget.activeCall?.isOnHold == true
      ? _cardColors.onHold
      : _cardColors.active;

  bool get _hasEnteredNumber => _enteredNumber.isNotEmpty;
  bool get _hasPhoto =>
      _contactInfo?.hasPhoto == true && _contactInfo?.photo != null;

  void _addDigit(String digit) => setState(() => _enteredNumber += digit);
  void _deleteDigit() => setState(() =>
      _enteredNumber = _enteredNumber.substring(0, _enteredNumber.length - 1));
  void _makeCall() async {
    if (!_hasEnteredNumber) return;

    try {
      // If we have an active call, put it on hold first
      if (widget.activeCall != null) {
        debugPrint(
            'CallActionScreen: Putting current call on hold before making new call ${widget.activeCall!.id}');
        await SipService.instance.holdCall(widget.activeCall!.id);

        // Update the active call state to reflect it's on hold
        final heldCall = widget.activeCall!
            .copyWith(isOnHold: true, state: AppCallState.held);

        // Make the new call
        final newCallId = await SipService.instance.makeCall(_enteredNumber);
        if (newCallId != null) {
          // Create call info for the new call
          final newCall = CallInfo(
            id: newCallId,
            remoteNumber: _enteredNumber,
            remoteName: _enteredNumber,
            state: AppCallState.connecting,
            startTime: DateTime.now(),
            isIncoming: false,
          );

          // Navigate to multi-call screen with both calls
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MultiCallScreen(
                  firstCall: heldCall,
                  secondCall: newCall,
                ),
              ),
            );
          }
        }
      } else {
        // No active call, just make a regular call
        final callId = await SipService.instance.makeCall(_enteredNumber);
        if (callId != null && mounted) {
          NavigationService.goToKeypad();
        }
      }
    } catch (e) {
      debugPrint('CallActionScreen: Error making call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make call: $e')),
        );
      }
    }
  }

  void _transferCall() => _performAction(() =>
      SipService.instance.transferCall(widget.activeCall!.id, _enteredNumber));
  void _goBack() => Navigator.of(context).pop();

  void _performAction(VoidCallback action) {
    if (_hasEnteredNumber) {
      action();
      NavigationService.goToKeypad();
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
                if (widget.activeCall != null) _buildActiveCallsSection(),
                const SizedBox(height: 24),
                _buildEnteredNumber(),
                const SizedBox(height: 24),
                Expanded(child: _buildKeypad()),
                const SizedBox(height: 20),
                _buildBottomControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCallsSection() => Column(
        children: [
          _buildCallCard(
            avatar:
                _buildAvatar(hasPhoto: _hasPhoto, photo: _contactInfo?.photo),
            title: _displayName,
            subtitle: widget.activeCall?.remoteNumber ?? '',
            status: _callStatus,
            statusColor: _statusColor,
            duration: _callDuration,
            isActive: true,
          ),
          const SizedBox(height: 12),
          _buildCallCard(
            avatar: _buildAvatar(icon: Icons.add),
            title: 'Add another call',
            subtitle: 'Tap to make a second call',
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.white54),
            isActive: false,
          ),
        ],
      );

  Widget _buildCallCard({
    required Widget avatar,
    required String title,
    required String subtitle,
    String? status,
    Color? statusColor,
    String? duration,
    Widget? trailing,
    required bool isActive,
  }) {
    final colors = isActive
        ? (_cardColors.primary.withValues(alpha: 0.4), _cardColors.border)
        : (
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.3)
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.$2, width: isActive ? 2 : 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: _cardColors.border.withValues(alpha: 0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: _cardColors.border.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ]
            : null,
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (status != null && duration != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor ?? _cardColors.active)),
                const SizedBox(height: 1),
                Text(duration,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildAvatar(
          {bool hasPhoto = false, Uint8List? photo, IconData? icon}) =>
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: icon != null
              ? Colors.white.withValues(alpha: 0.2)
              : _cardColors.avatar,
          border:
              icon == null ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        child: icon != null
            ? Icon(icon, size: 16, color: Colors.white)
            : CircleAvatar(
                radius: 16,
                backgroundColor: _cardColors.avatar,
                backgroundImage: hasPhoto ? MemoryImage(photo!) : null,
                child: hasPhoto
                    ? null
                    : Icon(Icons.person,
                        size: 16, color: _cardColors.avatarIcon),
              ),
      );

  Widget _buildEnteredNumber() => SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  _hasEnteredNumber ? _enteredNumber : 'Enter number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: _hasEnteredNumber
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            if (_hasEnteredNumber) _buildDeleteButton(),
          ],
        ),
      );

  Widget _buildDeleteButton() => SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _deleteDigit,
            child: const Icon(Icons.backspace_outlined,
                color: Color(0xFF666666), size: 24),
          ),
        ),
      );

  Widget _buildKeypad() => Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _keypadData.map((row) => _buildKeypadRow(row)).toList(),
      );

  Widget _buildKeypadRow(List<(String, String)> row) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children:
            row.map((data) => _buildKeypadButton(data.$1, data.$2)).toList(),
      );

  Widget _buildKeypadButton(String digit, String letters) => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => _addDigit(digit),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(digit,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: Colors.white)),
                if (letters.isNotEmpty)
                  Text(
                    letters,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildBottomControls() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left position - Transfer button or empty space
          widget.actionType == CallActionType.transfer
              ? _buildActionButton(
                  Icons.call_merge,
                  'Transfer Now',
                  const Color(0xFF2196F3),
                  _hasEnteredNumber ? _transferCall : null)
              : const SizedBox(width: 80), // Empty space to maintain layout

          // Center position - Call button (always below 0)
          _buildActionButton(Icons.call, 'Call', const Color(0xFF4CAF50),
              _hasEnteredNumber ? _makeCall : null),

          // Right position - Back button (always below #)
          _buildActionButton(Icons.arrow_back, 'Back', Colors.white, _goBack,
              textColor: const Color(0xFF6B46C1)),
        ],
      );

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback? onPressed,
      {Color? textColor}) {
    final isEnabled = onPressed != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEnabled ? color : Colors.grey.shade600,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: onPressed,
              child: Icon(icon, size: 28, color: textColor ?? Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
