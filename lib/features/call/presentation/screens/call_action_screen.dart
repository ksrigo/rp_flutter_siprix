import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siprix_voip_sdk/calls_model.dart';

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
  CallInfo? _currentCallInfo;
  bool _isAddingSecondCall = false;

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
    _currentCallInfo = widget.activeCall;
    _loadContactInfo();
    _setupHoldEventListener();
  }

  @override
  void dispose() {
    if (_currentCallInfo != null) {
      SipService.instance.removeHoldEventListener(_onHoldStateChanged);
    }
    super.dispose();
  }

  void _setupHoldEventListener() {
    debugPrint('CallActionScreen: Setting up hold event listener for callId: ${widget.activeCall?.id}');
    SipService.instance.addHoldEventListener(_onHoldStateChanged);
  }

  void _onHoldStateChanged(int callId, HoldState holdState) {
    debugPrint('CallActionScreen: Received hold event - callId: $callId, holdState: $holdState');

    // Only update if this is the same call we're tracking
    if (callId.toString() == widget.activeCall?.id) {
      // If we're adding a second call and this call gets taken off hold, put it back on hold
      if (_isAddingSecondCall && holdState == HoldState.none) {
        debugPrint('CallActionScreen: First call taken off hold during second call - putting back on hold');
        Future.delayed(const Duration(milliseconds: 100), () async {
          try {
            final currentCall = SipService.instance.findCallByCallId(callId.toString());
            await currentCall?.hold();
          } catch (e) {
            debugPrint('CallActionScreen: Error re-holding call: $e');
          }
        });
        return; // Don't update UI state yet
      }

      if (mounted) {
        setState(() {
          // Update the current call info with new hold state
          _currentCallInfo = _currentCallInfo?.copyWith(
            isOnHold: holdState != HoldState.none,
            state: holdState != HoldState.none ? AppCallState.held : AppCallState.answered,
          );
        });
        debugPrint('CallActionScreen: Updated call hold state - isOnHold: ${holdState != HoldState.none}');
      }
    }
  }

  Future<void> _loadContactInfo() async {
    final phoneNumber = _currentCallInfo?.remoteNumber;
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
      : _currentCallInfo?.remoteName?.isNotEmpty == true
          ? _currentCallInfo!.remoteName
          : _currentCallInfo?.remoteNumber ?? 'Unknown';

  String get _callDuration {
    if (_currentCallInfo == null || _currentCallInfo!.isOnHold) return '';
    final duration = DateTime.now().difference(_currentCallInfo!.startTime);
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String get _callStatus =>
      _currentCallInfo?.isOnHold == true ? 'On Hold' : 'Active';
  Color get _statusColor => _currentCallInfo?.isOnHold == true
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
      // Use builtin SDK functions directly
      final callsModel = SipService.instance.callsModel;
      if (callsModel == null) return;

      final callId = int.tryParse(_currentCallInfo?.id ?? '0') ?? 0;

      if (callId > 0) {
        // Set flag to indicate we're adding a second call
        _isAddingSecondCall = true;

        // Put current call on hold using builtin method
        final currentCall = SipService.instance.findCallByCallId(callId.toString());
        await currentCall?.hold();

        // Wait a bit for hold to be processed by SDK
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Make new call using builtin method - let SDK handle call switching naturally
      final newCallId = await SipService.instance.makeCall(_enteredNumber);
      if (newCallId != null && mounted) {
        // Reset flag after a delay to allow for call setup
        Future.delayed(const Duration(seconds: 3), () {
          _isAddingSecondCall = false;
        });

        // Navigate to multi-call screen if we have an existing call, otherwise keypad
        if (callId > 0 && _currentCallInfo != null) {
          // We have an existing call, need to create CallInfo for the new call
          final newCallInfo = CallInfo(
            id: newCallId,
            remoteNumber: _enteredNumber,
            remoteName: _enteredNumber, // Will be updated by contact resolution
            state: AppCallState.connecting,
            startTime: DateTime.now(),
            isIncoming: false,
          );

          // Navigate to multi-call screen with both calls
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MultiCallScreen(
                firstCall: _currentCallInfo!,
                secondCall: newCallInfo,
              ),
            ),
          );
        } else {
          // First call, navigate to keypad
          NavigationService.goToKeypad();
        }
      } else {
        _isAddingSecondCall = false;
      }
    } catch (e) {
      _isAddingSecondCall = false;
      debugPrint('CallActionScreen: Error making call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make call: $e')),
        );
      }
    }
  }

  void _transferCall() async {
    if (!_hasEnteredNumber) return;

    try {
      debugPrint('CallActionScreen: Initiating blind transfer to $_enteredNumber');

      // Find the call object to transfer
      final currentCall = SipService.instance.findCallByCallId(_currentCallInfo?.id ?? '');

      if (currentCall != null) {
        debugPrint('CallActionScreen: Transferring call ${_currentCallInfo?.id} to $_enteredNumber');
        await currentCall.transferBlind(_enteredNumber);
        debugPrint('CallActionScreen: Blind transfer initiated successfully');

        // Navigate back to keypad after transfer
        if (mounted) {
          NavigationService.goToKeypad();
        }
      } else {
        debugPrint('CallActionScreen: Could not find call to transfer');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to transfer: Call not found')),
          );
        }
      }
    } catch (e) {
      debugPrint('CallActionScreen: Transfer failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to transfer call: $e')),
        );
      }
    }
  }

  void _goBack() async {
    try {
      // If we have an active call that's on hold, unhold it before going back
      if (_currentCallInfo != null && _currentCallInfo!.isOnHold) {
        debugPrint('CallActionScreen: Unholding call ${_currentCallInfo!.id} before going back');
        final callObj = SipService.instance.findCallByCallId(_currentCallInfo!.id);
        if (callObj != null) {
          await callObj.hold(); // Toggle to unhold
        }
      }
    } catch (e) {
      debugPrint('CallActionScreen: Error unholding call on back: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
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
                if (_currentCallInfo != null) _buildActiveCallsSection(),
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

  Widget _buildActiveCallsSection() => _buildCallCard(
        avatar: _buildAvatar(hasPhoto: _hasPhoto, photo: _contactInfo?.photo),
        title: _displayName,
        subtitle: _currentCallInfo?.remoteNumber ?? '',
        status: _callStatus,
        statusColor: _statusColor,
        duration: _callDuration,
        isActive: !(_currentCallInfo?.isOnHold ?? false), // Show as inactive if on hold
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
          if (status != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor ?? _cardColors.active)),
                if (duration != null && duration.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(duration,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.8))),
                ],
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
