import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/contact_service.dart';

class ConsultCallScreen extends ConsumerStatefulWidget {
  final String consultCallId;
  final String targetNumber;
  final String originalCallId;

  const ConsultCallScreen({
    super.key,
    required this.consultCallId,
    required this.targetNumber,
    required this.originalCallId,
  });

  @override
  ConsumerState<ConsultCallScreen> createState() => _ConsultCallScreenState();
}

class _ConsultCallScreenState extends ConsumerState<ConsultCallScreen> {
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription<ConsultCallInfo?>? _consultCallSubscription;
  StreamSubscription<TransferState>? _transferStateSubscription;
  ConsultCallInfo? _consultCallInfo;
  TransferState _transferState = TransferState.none;
  ContactInfo? _contactInfo;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadContactInfo();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _consultCallSubscription?.cancel();
    _transferStateSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    // Listen to consult call changes
    _consultCallSubscription = SipService.instance.consultCallStream.listen((consultCall) {
      if (mounted) {
        setState(() {
          _consultCallInfo = consultCall;
        });

        // Start timer when call is connected
        if (consultCall?.state == AppCallState.answered && _callTimer == null) {
          _startCallTimer();
        }

        // Handle call failure or end
        if (consultCall?.state == AppCallState.failed || consultCall?.state == AppCallState.ended) {
          _callTimer?.cancel();
          if (!_isNavigatingAway) {
            _isNavigatingAway = true;
            _navigateBackToOriginalCall();
          }
        }
      }
    });

    // Listen to transfer state changes
    _transferStateSubscription = SipService.instance.transferStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _transferState = state;
        });

        // Navigate away when transfer is completed
        if (state == TransferState.completed && !_isNavigatingAway) {
          _isNavigatingAway = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              NavigationService.goToKeypad();
            }
          });
        }
      }
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatCallDuration() {
    final minutes = (_callDuration / 60).floor().toString().padLeft(2, '0');
    final seconds = (_callDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _loadContactInfo() async {
    try {
      if (ContactService.instance.hasPermission) {
        final contactInfo = await ContactService.instance.findContactByPhoneNumber(widget.targetNumber);
        if (mounted) {
          setState(() {
            _contactInfo = contactInfo;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading contact info: $e');
    }
  }

  void _completeTransfer() async {
    try {
      await SipService.instance.transferAttendedComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e')),
        );
      }
    }
  }

  void _cancelTransfer() async {
    try {
      await SipService.instance.transferAttendedCancel();
      _navigateBackToOriginalCall();
    } catch (e) {
      debugPrint('Error canceling transfer: $e');
      _navigateBackToOriginalCall();
    }
  }

  void _navigateBackToOriginalCall() {
    NavigationService.goToInCall(
      widget.originalCallId,
      phoneNumber: null, // Will be retrieved from current call
      contactName: null,
    );
  }

  String _getDisplayName() {
    if (_contactInfo?.displayName != null && _contactInfo!.displayName.isNotEmpty) {
      return _contactInfo!.displayName;
    }
    return widget.targetNumber;
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
              Color(0xFF4A1458),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: _cancelTransfer,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Consult Call',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),

                const SizedBox(height: 48),

                // Contact avatar and name
                _buildContactInfo(),

                const SizedBox(height: 16),

                // Call duration or status
                _buildCallStatus(),

                const Spacer(),

                // Transfer state indicator
                if (_transferState == TransferState.completing)
                  const Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Completing Transfer...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                else
                  // Action buttons
                  _buildActionButtons(),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    final displayName = _getDisplayName();

    return Column(
      children: [
        // Avatar
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE6E6FA),
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
          ),
          child: CircleAvatar(
            radius: 58,
            backgroundColor: const Color(0xFFE6E6FA),
            backgroundImage: _contactInfo?.hasPhoto == true && _contactInfo?.photo != null
                ? MemoryImage(_contactInfo!.photo!)
                : null,
            child: _contactInfo?.hasPhoto == true && _contactInfo?.photo != null
                ? null
                : const Icon(
                    Icons.person,
                    size: 50,
                    color: Color(0xFF6B46C1),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Contact name or phone number
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Show phone number below name if we have a contact name
        if (_contactInfo?.displayName != null && _contactInfo!.displayName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.targetNumber,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildCallStatus() {
    String displayText;
    Color textColor = Colors.white.withValues(alpha: 0.9);

    switch (_consultCallInfo?.state ?? AppCallState.connecting) {
      case AppCallState.connecting:
        displayText = 'Connecting...';
        break;
      case AppCallState.ringing:
        displayText = 'Ringing...';
        break;
      case AppCallState.answered:
        displayText = _formatCallDuration();
        break;
      case AppCallState.failed:
        displayText = 'Call Failed';
        textColor = Colors.red[600]!;
        break;
      case AppCallState.ended:
        displayText = 'Call Ended';
        textColor = Colors.white.withValues(alpha: 0.7);
        break;
      default:
        displayText = 'Connecting...';
        break;
    }

    return Text(
      displayText,
      style: TextStyle(
        fontSize: 16,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool isCallAnswered = _consultCallInfo?.state == AppCallState.answered;

    return Column(
      children: [
        // Complete Transfer Button
        if (isCallAnswered)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _completeTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call_merge, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Complete Transfer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (isCallAnswered) const SizedBox(height: 16),

        // Cancel Transfer Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _cancelTransfer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call_end, size: 20),
                SizedBox(width: 8),
                Text(
                  'Cancel Transfer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}