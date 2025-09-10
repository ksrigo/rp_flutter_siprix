import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String callerName;
  final String callerNumber;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerNumber,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<CallInfo?>? _callStateSubscription;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupCallStateListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.repeat(reverse: true);
  }

  void _setupCallStateListener() {
    debugPrint('IncomingCallScreen: Setting up call state listener for callId: ${widget.callId}');
    _callStateSubscription = SipService.instance.currentCallStream.listen((callInfo) {
      debugPrint('IncomingCallScreen: Received call state update - callId: ${callInfo?.id}, state: ${callInfo?.state}, widgetCallId: ${widget.callId}');
      
      if (callInfo == null) {
        // Call was cleared/ended
        debugPrint('IncomingCallScreen: Call was cleared, returning to keypad');
        _handleCallEnded();
      } else if (callInfo.id == widget.callId) {
        // This is our call, check if it ended or failed
        if (callInfo.state == AppCallState.ended || callInfo.state == AppCallState.failed) {
          debugPrint('IncomingCallScreen: Call ${callInfo.state.name}, returning to keypad');
          _handleCallEnded();
        }
      }
    });
  }

  void _handleCallEnded() async {
    if (mounted && !_isNavigatingAway) {
      _isNavigatingAway = true;
      debugPrint('IncomingCallScreen: Navigating back to keypad due to call termination');
      // Add small delay before navigation to prevent GlobalKey conflicts
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        NavigationService.goToKeypad();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _callStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _answerCall() async {
    if (_isNavigatingAway) return;
    
    try {
      _isNavigatingAway = true;
      await SipService.instance.answerCall(widget.callId);
      if (mounted) {
        // Add small delay before navigation to prevent GlobalKey conflicts
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          NavigationService.goToInCall(
            widget.callId,
            phoneNumber: widget.callerNumber,
            contactName: widget.callerName,
          );
        }
      }
    } catch (e) {
      debugPrint('Error answering call: $e');
      _isNavigatingAway = false; // Reset flag on error
    }
  }

  Future<void> _declineCall() async {
    if (_isNavigatingAway) return;
    
    try {
      _isNavigatingAway = true;
      await SipService.instance.hangupCall(widget.callId);
      if (mounted) {
        // Add small delay before navigation to prevent GlobalKey conflicts
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          NavigationService.goToKeypad();
        }
      }
    } catch (e) {
      debugPrint('Error declining call: $e');
      _isNavigatingAway = false; // Reset flag on error
    }
  }

  String _getDisplayName() {
    // If we have a contact name, show it; otherwise show the phone number
    if (_hasContactName()) {
      return widget.callerName;
    }
    return widget.callerNumber.isNotEmpty ? widget.callerNumber : 'Unknown';
  }

  bool _hasContactName() {
    // Check if we have a real contact name (not just "Unknown" or empty)
    return widget.callerName.isNotEmpty && 
           widget.callerName.toLowerCase() != 'unknown' &&
           widget.callerName != widget.callerNumber;
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
              Color(0xFF0A0A0A), // Almost black at top
              Color(0xFF1A0B2E), // Dark black-purple 
              Color(0xFF2D1B69), // Deep purple
              Color(0xFF4A1458), // Purple-black at bottom
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with caller info
              Expanded(
                flex: 2,
                child: _buildCallerInfo(),
              ),
              
              // Bottom section with call actions
              Expanded(
                flex: 1,
                child: _buildCallActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Incoming call label
          Text(
            'Incoming Call',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Caller avatar with pulse animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE6E6FA),
                    border: Border.all(
                      color: Colors.white,
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 85,
                    backgroundColor: const Color(0xFFE6E6FA),
                    backgroundImage: null, // TODO: Add contact photo support
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: const Color(0xFF6B46C1),
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Caller name or number
          Text(
            _getDisplayName(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Show phone number below name if we have a contact name
          if (_hasContactName()) ...[
            const SizedBox(height: 8),
            Text(
              widget.callerNumber,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Call type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  'Voice Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallActions() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Decline button
          _buildActionButton(
            icon: Icons.call_end,
            color: const Color(0xFFE53E3E),
            onPressed: _declineCall,
            label: 'Decline',
          ),
          
          // Answer button
          _buildActionButton(
            icon: Icons.call,
            color: const Color(0xFF00C853),
            onPressed: _answerCall,
            label: 'Accept',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 25,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

