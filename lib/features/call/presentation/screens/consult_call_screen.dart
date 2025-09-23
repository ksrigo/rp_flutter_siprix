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
  bool _isConsultCallActive = true; // Track which call is currently active

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
    _consultCallSubscription = SipService.instance.consultCallStream.listen(
      (consultCall) {
        if (mounted) {
          setState(() {
            _consultCallInfo = consultCall;
          });

          // Start timer when call is connected
          if (consultCall?.state == AppCallState.answered && _callTimer == null) {
            _startCallTimer();
          }

          // Handle call failure or end
          if (consultCall?.state == AppCallState.failed) {
            _callTimer?.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Consult call failed'),
                  ],
                ),
                backgroundColor: Colors.red[600],
                duration: const Duration(seconds: 3),
              ),
            );
            if (!_isNavigatingAway) {
              _isNavigatingAway = true;
              Future.delayed(const Duration(milliseconds: 1500), () {
                _navigateBackToOriginalCall();
              });
            }
          } else if (consultCall?.state == AppCallState.ended) {
            _callTimer?.cancel();
            if (!_isNavigatingAway) {
              _isNavigatingAway = true;
              _navigateBackToOriginalCall();
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Consult call stream error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Consult call error: $error'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      },
    );

    // Listen to transfer state changes
    _transferStateSubscription = SipService.instance.transferStateStream.listen(
      (state) {
        if (mounted) {
          setState(() {
            _transferState = state;
          });

          // Handle different transfer states
          switch (state) {
            case TransferState.completed:
              if (!_isNavigatingAway) {
                _isNavigatingAway = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Transfer completed successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    NavigationService.goToKeypad();
                  }
                });
              }
              break;

            case TransferState.failed:
              setState(() {
                _transferState = TransferState.consulting; // Return to consulting state
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Transfer failed. You can try again or cancel.'),
                    ],
                  ),
                  backgroundColor: Colors.red[600],
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Dismiss',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
              break;

            default:
              // Handle other states as needed
              break;
          }
        }
      },
      onError: (error) {
        debugPrint('Transfer state stream error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transfer error: $error'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      },
    );
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
      debugPrint('User initiated transfer completion');

      // Show loading state
      setState(() {
        _transferState = TransferState.completing;
      });

      // Ensure both calls are ready for transfer
      if (_consultCallInfo?.callModel == null) {
        throw Exception('Consult call not available');
      }

      if (_consultCallInfo!.state != AppCallState.answered) {
        throw Exception('Consult call must be answered before completing transfer');
      }

      await SipService.instance.transferAttendedComplete();
      debugPrint('Transfer completion initiated successfully');

    } catch (e) {
      debugPrint('Transfer completion failed: $e');

      // Reset transfer state on error
      setState(() {
        _transferState = TransferState.consulting;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _cancelTransfer() async {
    try {
      debugPrint('User initiated transfer cancellation');

      // Show confirmation dialog for cancel action
      final bool? shouldCancel = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2D1B69),
            title: const Text(
              'Cancel Transfer',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to cancel the transfer? This will end the consult call and return to the original call.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Keep Transfer',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Cancel Transfer'),
              ),
            ],
          );
        },
      );

      if (shouldCancel == true) {
        await SipService.instance.transferAttendedCancel();
        debugPrint('Transfer canceled successfully');

        if (!_isNavigatingAway) {
          _isNavigatingAway = true;
          _navigateBackToOriginalCall();
        }
      }

    } catch (e) {
      debugPrint('Error canceling transfer: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel transfer: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }

      // Navigate back anyway if cancellation fails
      if (!_isNavigatingAway) {
        _isNavigatingAway = true;
        _navigateBackToOriginalCall();
      }
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

  void _switchToOriginalCall() async {
    try {
      // Hold consult call and resume original call
      if (_consultCallInfo?.callModel != null) {
        final consultCallId = _consultCallInfo!.callModel!.myCallId.toString();
        await SipService.instance.holdCall(consultCallId);
        await SipService.instance.unholdCall(widget.originalCallId);

        setState(() {
          _isConsultCallActive = false;
        });
        debugPrint('Switched to original call');
      }
    } catch (e) {
      debugPrint('Error switching to original call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch calls: $e')),
        );
      }
    }
  }

  void _switchToConsultCall() async {
    try {
      // Hold original call and resume consult call
      if (_consultCallInfo?.callModel != null) {
        final consultCallId = _consultCallInfo!.callModel!.myCallId.toString();
        await SipService.instance.holdCall(widget.originalCallId);
        await SipService.instance.unholdCall(consultCallId);

        setState(() {
          _isConsultCallActive = true;
        });
        debugPrint('Switched to consult call');
      }
    } catch (e) {
      debugPrint('Error switching to consult call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch calls: $e')),
        );
      }
    }
  }

  Widget _buildCallSwitchingUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          const Text(
            'Active Calls',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Call buttons
          Row(
            children: [
              // Original Call Button
              Expanded(
                child: GestureDetector(
                  onTap: _switchToOriginalCall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: !_isConsultCallActive
                          ? const Color(0xFF6B46C1)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isConsultCallActive
                            ? const Color(0xFF6B46C1)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          !_isConsultCallActive ? Icons.phone : Icons.pause,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Original Call',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          !_isConsultCallActive ? 'Active' : 'On Hold',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Consult Call Button
              Expanded(
                child: GestureDetector(
                  onTap: _switchToConsultCall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isConsultCallActive
                          ? const Color(0xFF6B46C1)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isConsultCallActive
                            ? const Color(0xFF6B46C1)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isConsultCallActive ? Icons.phone : Icons.pause,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Consult Call',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _isConsultCallActive ? 'Active' : 'On Hold',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

                // Call switching UI - only show when consult call is answered
                if (_consultCallInfo?.state == AppCallState.answered)
                  _buildCallSwitchingUI(),

                const SizedBox(height: 24),

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