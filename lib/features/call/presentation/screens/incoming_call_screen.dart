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
    debugPrint('🔥 IncomingCallScreen: initState called for callId: ${widget.callId}');
    debugPrint('🔥 IncomingCallScreen: callerName: ${widget.callerName}, callerNumber: ${widget.callerNumber}');
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
    debugPrint('🔥 IncomingCallScreen: Setting up call state listener for callId: ${widget.callId}');
    debugPrint('🔥 IncomingCallScreen: Initial _isNavigatingAway state: $_isNavigatingAway');
    _callStateSubscription =
        SipService.instance.currentCallStream.listen(_handleCallStateChange);

    // Evaluate the current call state immediately in case the call already ended
    _handleCallStateChange(SipService.instance.currentCall);
  }

  void _handleCallStateChange(CallInfo? callInfo) {
    debugPrint('''🔥 IncomingCallScreen: ========== CALL STATE UPDATE ==========
🔥 IncomingCallScreen: Received call state update - callId: ${callInfo?.id}, state: ${callInfo?.state}, widgetCallId: ${widget.callId}
🔥 IncomingCallScreen: Current _isNavigatingAway: $_isNavigatingAway''');

    if (callInfo == null) {
      // Call was cleared/ended
      debugPrint('🔥 IncomingCallScreen: Call was cleared, calling _handleCallEnded()');
      _handleCallEnded();
      return;
    }

    if (callInfo.id != widget.callId) {
      debugPrint('🔥 IncomingCallScreen: Different call ID, ignoring: ${callInfo.id} vs ${widget.callId}');

      // If another call replaced ours and this screen is still visible, close it to avoid stale UI
      _handleCallEnded();
      return;
    }

    debugPrint('🔥 IncomingCallScreen: This is our call, state: ${callInfo.state}');

    if (callInfo.state == AppCallState.answered) {
      debugPrint(
          '🔥 IncomingCallScreen: Call answered (background acceptance), navigating to in-call screen IMMEDIATELY');
      if (!_isNavigatingAway) {
        _isNavigatingAway = true;
        NavigationService.goToInCall(
          widget.callId,
          phoneNumber: widget.callerNumber,
          contactName: widget.callerName,
        );
      }
      return;
    }

    if (callInfo.state == AppCallState.ended ||
        callInfo.state == AppCallState.failed) {
      debugPrint(
          '🔥 IncomingCallScreen: Call ${callInfo.state.name}, calling _handleCallEnded()');
      _handleCallEnded();
      return;
    }

    debugPrint(
        '🔥 IncomingCallScreen: Call state is ${callInfo.state.name}, keeping screen active');
  }

  void _handleCallAnswered() async {
    debugPrint('🔥 IncomingCallScreen: ========== _handleCallAnswered CALLED ==========');
    debugPrint('🔥 IncomingCallScreen: mounted: $mounted, _isNavigatingAway: $_isNavigatingAway');
    
    if (mounted && !_isNavigatingAway) {
      debugPrint('🔥 IncomingCallScreen: Setting _isNavigatingAway = true and navigating to in-call screen');
      _isNavigatingAway = true;
      debugPrint('IncomingCallScreen: Navigating to in-call screen due to background acceptance');
      // Reduce delay for faster transition on background acceptance
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        NavigationService.goToInCall(
          widget.callId,
          phoneNumber: widget.callerNumber,
          contactName: widget.callerName,
        );
      }
    } else {
      debugPrint('🔥 IncomingCallScreen: Not navigating - mounted: $mounted, _isNavigatingAway: $_isNavigatingAway');
    }
  }

  void _handleCallEnded() async {
    debugPrint('🔥 IncomingCallScreen: ========== _handleCallEnded CALLED ==========');
    debugPrint('🔥 IncomingCallScreen: mounted: $mounted, _isNavigatingAway: $_isNavigatingAway');
    
    if (mounted && !_isNavigatingAway) {
      debugPrint('🔥 IncomingCallScreen: Setting _isNavigatingAway = true and navigating to keypad');
      _isNavigatingAway = true;
      debugPrint('IncomingCallScreen: Navigating back to keypad due to call termination');
      // Add small delay before navigation to prevent GlobalKey conflicts
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        NavigationService.goToKeypad();
      }
    } else {
      debugPrint('🔥 IncomingCallScreen: Not navigating - mounted: $mounted, _isNavigatingAway: $_isNavigatingAway');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _callStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _answerCall() async {
    debugPrint('🔥 IncomingCallScreen: ========== ANSWER CALL HANDLER STARTED ==========');
    debugPrint('🔥 IncomingCallScreen: Answer button pressed! CallId: ${widget.callId}');
    debugPrint('🔥 IncomingCallScreen: Current mounted state: $mounted');
    debugPrint('🔥 IncomingCallScreen: Current _isNavigatingAway: $_isNavigatingAway');
    
    if (_isNavigatingAway) {
      debugPrint('🔥 IncomingCallScreen: Already navigating away, ignoring answer');
      return;
    }
    
    try {
      debugPrint('🔥 IncomingCallScreen: Attempting to answer call...');
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
    debugPrint('🔥 IncomingCallScreen: ========== DECLINE CALL HANDLER STARTED ==========');
    debugPrint('🔥 IncomingCallScreen: Decline button pressed! CallId: ${widget.callId}');
    debugPrint('🔥 IncomingCallScreen: Current mounted state: $mounted');
    debugPrint('🔥 IncomingCallScreen: Current _isNavigatingAway: $_isNavigatingAway');
    
    if (_isNavigatingAway) {
      debugPrint('🔥 IncomingCallScreen: Already navigating away, ignoring decline');
      return;
    }
    
    try {
      debugPrint('🔥 IncomingCallScreen: Attempting to decline call...');
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
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Decline button - positioned on the left
          _buildActionButton(
            icon: Icons.call_end,
            color: const Color(0xFFE53E3E),
            onPressed: () {
              debugPrint('🔥 IncomingCallScreen: Decline button onPressed callback invoked');
              _declineCall();
            },
            label: 'Decline',
          ),
          
          // Answer button - positioned on the right
          _buildActionButton(
            icon: Icons.call,
            color: const Color(0xFF00C853),
            onPressed: () {
              debugPrint('🔥 IncomingCallScreen: Accept button onPressed callback invoked');
              _answerCall();
            },
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
    debugPrint('🔥 IncomingCallScreen: Building action button: $label');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            debugPrint('🔥 IncomingCallScreen: onTapDown detected for: $label');
          },
          onTapUp: (details) {
            debugPrint('🔥 IncomingCallScreen: onTapUp detected for: $label');
          },
          onTap: () {
            debugPrint('🔥 IncomingCallScreen: ========== GESTURE DETECTOR onTap ==========');
            debugPrint('🔥 IncomingCallScreen: GestureDetector onTap triggered for: $label');
            debugPrint('🔥 IncomingCallScreen: mounted: $mounted');
            debugPrint('🔥 IncomingCallScreen: _isNavigatingAway: $_isNavigatingAway');
            debugPrint('🔥 IncomingCallScreen: About to call onPressed callback');
            onPressed();
          },
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
