import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/contact_service.dart';

class InCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String? contactName;
  final String? phoneNumber;

  const InCallScreen({
    super.key,
    required this.callId,
    this.contactName,
    this.phoneNumber,
  });

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen> {
  bool _isMuted = false;
  bool _isOnHold = false;
  bool _showKeypad = false;
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription<CallInfo?>? _callStateSubscription;
  AppCallState _currentCallState = AppCallState.connecting;
  bool _isCallAnswered = false;
  CallInfo? _currentCallInfo;
  bool _isNavigatingAway = false;
  ContactInfo? _contactInfo;

  @override
  void initState() {
    super.initState();
    _listenToCallStateChanges();
    _loadContactInfo();
    _checkInitialCallState();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callStateSubscription?.cancel();
    super.dispose();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }


  String _formatCallDuration() {
    final minutes = (_callDuration / 60).floor().toString().padLeft(2, '0');
    final seconds = (_callDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _loadContactInfo() async {
    try {
      final phoneNumber = widget.phoneNumber ?? _getPhoneNumber();
      if (phoneNumber.isNotEmpty && phoneNumber != 'Unknown') {
        debugPrint('InCallScreen: Loading contact info for: $phoneNumber');
        
        // Check if ContactService has permission before attempting lookup
        if (!ContactService.instance.hasPermission) {
          debugPrint('InCallScreen: ContactService does not have permission, skipping lookup');
          return;
        }
        
        final contactInfo = await ContactService.instance.findContactByPhoneNumber(phoneNumber);
        if (mounted) {
          setState(() {
            _contactInfo = contactInfo;
          });
          debugPrint('InCallScreen: Contact info loaded: ${contactInfo?.displayName ?? 'No contact found'}');
        }
      }
    } catch (e) {
      debugPrint('InCallScreen: Error loading contact info: $e');
      // Don't crash if contact loading fails
    }
  }

  void _checkInitialCallState() {
    // Check if there's already an active call when this screen loads
    final currentCall = SipService.instance.currentCall;
    if (currentCall != null) {
      debugPrint('InCallScreen: Found existing call on init - state: ${currentCall.state}');
      
      setState(() {
        _currentCallState = currentCall.state;
        _currentCallInfo = currentCall;
        _isMuted = currentCall.isMuted ?? false;
      });
      
      // If the call is already answered, start the timer immediately
      if (currentCall.state == AppCallState.answered && !_isCallAnswered) {
        _isCallAnswered = true;
        _startCallTimer();
        debugPrint('InCallScreen: Call was already answered on init, starting timer');
      }
    }
  }

  void _listenToCallStateChanges() {
    debugPrint('InCallScreen: Setting up call state listener for callId: ${widget.callId}');
    _callStateSubscription = SipService.instance.currentCallStream.listen((callInfo) {
      debugPrint('InCallScreen: Received call state update - callId: ${callInfo?.id}, state: ${callInfo?.state}, widgetCallId: ${widget.callId}');
      
      if (callInfo != null && mounted) {
        setState(() {
          _currentCallState = callInfo.state;
          _currentCallInfo = callInfo;
          // Sync mute state from call info
          _isMuted = callInfo.isMuted ?? false;
        });
        
        // Start timer when call is answered
        if (callInfo.state == AppCallState.answered && !_isCallAnswered) {
          _isCallAnswered = true;
          _startCallTimer();
          debugPrint('InCallScreen: Call answered, starting timer');
        }
        
        // Stop timer if call ends or fails
        if (callInfo.state == AppCallState.ended || callInfo.state == AppCallState.failed) {
          _callTimer?.cancel();
          
          // Prevent multiple navigation attempts
          if (!_isNavigatingAway) {
            _isNavigatingAway = true;
            debugPrint('InCallScreen: Call ${callInfo.state.name}: Navigating back to keypad');
            
            // Add small delay before navigation to prevent GlobalKey conflicts
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) {
                NavigationService.goToKeypad();
              }
            });
          } else {
            debugPrint('InCallScreen: Call ${callInfo.state.name}: Navigation already in progress, skipping');
          }
        }
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Quality indicator
                  _buildQualityIndicator(),
                  
                  const SizedBox(height: 48),
                  
                  // Contact avatar and name
                  _buildContactInfo(),
                  
                  const SizedBox(height: 16),
                  
                  // Call duration
                  _buildCallDuration(),
                  
                  const Spacer(),
                  
                  // Call controls
                  _buildCallControls(),
                  
                  const SizedBox(height: 48),
                  
                  // End call button
                  _buildEndCallButton(),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildQualityIndicator() {
    return Row(
      children: [
        Icon(
          Icons.signal_cellular_4_bar,
          size: 16,
          color: Colors.green,
        ),
        const SizedBox(width: 4),
        Text(
          'Excellent Quality',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    // Get the display name and phone number from call info or widget params
    final String displayName = _getDisplayName();
    final String phoneNumber = _getPhoneNumber();
    
    return Column(
      children: [
        // Avatar
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE6E6FA),
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 71, // Back to original size since no nested container
            backgroundColor: const Color(0xFFE6E6FA),
            backgroundImage: _contactInfo?.hasPhoto == true && _contactInfo?.photo != null
                ? MemoryImage(_contactInfo!.photo!)
                : null,
            child: _contactInfo?.hasPhoto == true && _contactInfo?.photo != null
                ? null
                : const Icon(
                    Icons.person,
                    size: 60,
                    color: Color(0xFF6B46C1),
                  ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Contact name or phone number
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Show phone number below name if we have a contact name
        if (widget.contactName != null && widget.contactName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            phoneNumber,
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
  
  String _getDisplayName() {
    // Priority: contact service info > widget contactName > currentCallInfo remoteName > phoneNumber
    if (_contactInfo?.displayName != null && _contactInfo!.displayName.isNotEmpty) {
      return _contactInfo!.displayName;
    }
    
    if (widget.contactName != null && widget.contactName!.isNotEmpty) {
      return widget.contactName!;
    }
    
    if (_currentCallInfo?.remoteName != null && _currentCallInfo!.remoteName.isNotEmpty) {
      return _currentCallInfo!.remoteName;
    }
    
    return _getPhoneNumber();
  }
  
  String _getPhoneNumber() {
    // Priority: widget phoneNumber > currentCallInfo remoteNumber > fallback
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      return widget.phoneNumber!;
    }
    
    if (_currentCallInfo?.remoteNumber != null && _currentCallInfo!.remoteNumber.isNotEmpty) {
      return _currentCallInfo!.remoteNumber;
    }
    
    return 'Unknown';
  }

  Widget _buildCallDuration() {
    String displayText;
    Color textColor = Colors.white.withValues(alpha: 0.9);
    
    // Show timer once the call is answered
    if (_isCallAnswered) {
      switch (_currentCallState) {
        case AppCallState.held:
          displayText = 'On Hold - ${_formatCallDuration()}';
          break;
        case AppCallState.reconnecting:
          displayText = 'Reconnecting... ${_formatCallDuration()}';
          textColor = Colors.orange[600]!;
          break;
        case AppCallState.failed:
          displayText = 'Call Failed';
          textColor = Colors.red[600]!;
          break;
        default:
          displayText = _formatCallDuration();
          break;
      }
    } else {
      // Before call is answered, show appropriate status
      switch (_currentCallState) {
        case AppCallState.ringing:
          displayText = 'Ringing...';
          break;
        case AppCallState.reconnecting:
          displayText = 'Reconnecting...';
          textColor = Colors.orange[600]!;
          break;
        case AppCallState.connecting:
        default:
          displayText = 'Connecting...';
          break;
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_currentCallState == AppCallState.reconnecting) ...[
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
        ],
        Text(
          displayText,
          style: TextStyle(
            fontSize: 16,
            color: textColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls() {
    return Column(
      children: [
        // First row of controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              isActive: _isMuted,
              onPressed: _isCallAnswered && _isCallActive() ? _toggleMute : null,
            ),
            _buildSpeakerButton(),
            _buildControlButton(
              icon: _isOnHold ? Icons.play_arrow : Icons.pause,
              label: _isOnHold ? 'Resume' : 'Hold',
              isActive: _isOnHold,
              onPressed: _isCallAnswered ? _toggleHold : null,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Second row of controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.dialpad,
              label: 'Keypad',
              isActive: _showKeypad,
              onPressed: _isCallAnswered ? _toggleKeypad : null,
            ),
            _buildControlButton(
              icon: Icons.person_add,
              label: 'Add Call',
              onPressed: _isCallAnswered ? _addCall : null,
            ),
            _buildControlButton(
              icon: Icons.call_merge,
              label: 'Transfer',
              onPressed: _isCallAnswered ? _transferCall : null,
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
    VoidCallback? onPressed,
  }) {
    final bool isEnabled = onPressed != null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isEnabled ? onPressed : null,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: !isEnabled
                  ? Colors.grey.shade300
                  : isActive 
                      ? const Color(0xFF6B46C1)
                      : const Color(0xFFE6E6FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: !isEnabled
                  ? Colors.grey.shade500
                  : isActive 
                      ? Colors.white 
                      : const Color(0xFF6B46C1),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioControlButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    final bool isEnabled = onPressed != null;
    final sipService = SipService.instance;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListenableBuilder(
          listenable: sipService,
          builder: (context, child) {
            final currentDevice = sipService.currentAudioDevice;
            
            IconData dynamicIcon = Icons.volume_up;
            bool dynamicIsActive = false;
            
            if (currentDevice != null) {
              dynamicIcon = currentDevice.icon;
              dynamicIsActive = currentDevice.category != AudioDeviceCategory.earpiece;
            }
            
            return GestureDetector(
              onTap: isEnabled ? onPressed : null,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: !isEnabled
                      ? Colors.grey.shade300
                      : dynamicIsActive 
                          ? const Color(0xFF6B46C1)
                          : const Color(0xFFE6E6FA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  dynamicIcon,
                  size: 32,
                  color: !isEnabled
                      ? Colors.grey.shade500
                      : dynamicIsActive 
                          ? Colors.white 
                          : const Color(0xFF6B46C1),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 8),
        
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildEndCallButton() {
    return Center(
      child: Container(
        width: 280,
        height: 56,
        decoration: BoxDecoration(
          color: Color(0xFFE53E3E),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _endCall,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'End Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canControlCall() {
    // Allow mute control for connecting, ringing, and answered calls
    return _currentCallState == AppCallState.connecting ||
           _currentCallState == AppCallState.ringing ||
           _currentCallState == AppCallState.answered;
  }

  bool _isCallActive() {
    // Check if the call is still active (not ended or failed)
    return _currentCallState != AppCallState.ended && 
           _currentCallState != AppCallState.failed;
  }

  void _toggleMute() async {
    final newMuteState = !_isMuted;
    
    // Optimistically update UI
    setState(() {
      _isMuted = newMuteState;
    });
    
    try {
      await SipService.instance.muteCall(widget.callId, newMuteState);
      debugPrint('InCallScreen: Mute toggled successfully to $newMuteState');
    } catch (e) {
      // Revert UI state if mute operation failed
      debugPrint('InCallScreen: Mute operation failed, reverting UI state: $e');
      setState(() {
        _isMuted = !newMuteState;
      });
    }
  }

  void _toggleHold() {
    setState(() {
      _isOnHold = !_isOnHold;
    });
    if (_isOnHold) {
      SipService.instance.holdCall(widget.callId);
    } else {
      SipService.instance.unholdCall(widget.callId);
    }
  }

  void _showAudioOutputOptions() {
    final sipService = SipService.instance;
    final availableDevices = sipService.categorizedAudioDevices;
    final currentDevice = sipService.currentAudioDevice;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E), // Dark background like mockup
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Audio devices list (no title, just devices like in mockup)
              ...availableDevices.map((deviceInfo) {
                final isSelected = currentDevice?.index == deviceInfo.index;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(
                      deviceInfo.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: Text(
                      deviceInfo.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                    onTap: () async {
                      await sipService.setAudioOutputDevice(deviceInfo.index);
                      if (!mounted) return;
                      Navigator.pop(context);
                      setState(() {
                        // The button will update its icon based on current audio device
                      });
                    },
                  ),
                );
              }),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSpeaker() {
    // Simple toggle between speaker and earpiece
    final currentCall = SipService.instance.currentCall;
    if (currentCall != null) {
      final newSpeakerState = !currentCall.isSpeakerOn;
      SipService.instance.setSpeaker(widget.callId, newSpeakerState);
      debugPrint('Speaker toggled to: $newSpeakerState');
    }
  }

  Widget _buildSpeakerButton() {
    final sipService = SipService.instance;
    
    return ListenableBuilder(
      listenable: sipService,
      builder: (context, child) {
        final currentCall = sipService.currentCall;
        final isSpeakerOn = currentCall?.isSpeakerOn ?? false;
        final isEnabled = _isCallAnswered;
        
        return _buildControlButton(
          icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: isSpeakerOn ? 'Speaker' : 'Earpiece',
          isActive: isSpeakerOn,
          onPressed: isEnabled ? _toggleSpeaker : null,
        );
      },
    );
  }

  void _toggleKeypad() {
    setState(() {
      _showKeypad = !_showKeypad;
    });
  }


  void _addCall() {
    // TODO: Implement add call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add call feature coming soon')),
    );
  }

  void _transferCall() {
    // TODO: Implement call transfer functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call transfer feature coming soon')),
    );
  }

  void _endCall() {
    if (!_isNavigatingAway) {
      _isNavigatingAway = true;
      SipService.instance.hangupCall(widget.callId);
      // Add small delay before navigation to prevent GlobalKey conflicts
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          NavigationService.goToKeypad();
        }
      });
    }
  }
}

