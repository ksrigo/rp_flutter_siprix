import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';

class DialpadScreen extends ConsumerStatefulWidget {
  const DialpadScreen({super.key});

  @override
  ConsumerState<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends ConsumerState<DialpadScreen> {
  String _dialedNumber = '';

  void _onDigitPressed(String digit) {
    setState(() {
      _dialedNumber += digit;
    });
  }

  void _onBackspacePressed() {
    if (_dialedNumber.isNotEmpty) {
      setState(() {
        _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1);
      });
    }
  }

  void _onCallPressed() async {
    if (_dialedNumber.isNotEmpty) {
      final callId = await SipService.instance.makeCall(_dialedNumber);
      if (callId != null) {
        // Navigate to call screen with the dialed number
        NavigationService.goToInCall(callId, phoneNumber: _dialedNumber);
        // Clear the dialed number after initiating call
        setState(() {
          _dialedNumber = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;
    final extensionDetails = authService.extensionDetails;

    // Check if keyboard is open
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header with Name, Extension and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Name and Extension
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        extensionDetails?.name ?? 'User',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'Ext: ${extensionDetails?.extension ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  // Right side - Status
                  ListenableBuilder(
                    listenable: SipService.instance,
                    builder: (context, child) {
                      final sipService = SipService.instance;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sipService.isRegistered 
                              ? const Color(0xFFE6F7F1) 
                              : const Color(0xFFFFE6E6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sipService.isRegistered 
                                ? const Color(0xFF00C853) 
                                : const Color(0xFFFF5252),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: sipService.isRegistered 
                                    ? const Color(0xFF00C853) 
                                    : const Color(0xFFFF5252),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sipService.isRegistered ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: sipService.isRegistered 
                                    ? const Color(0xFF00C853) 
                                    : const Color(0xFFFF5252),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              // Dialed Number Display - Responsive to keyboard
              Container(
                width: double.infinity,
                height: isKeyboardOpen ? 50 : 80,
                margin: EdgeInsets.symmetric(vertical: isKeyboardOpen ? 10 : 20),
                child: Center(
                  child: Text(
                    _dialedNumber.isEmpty ? '' : _dialedNumber,
                    style: TextStyle(
                      fontSize: isKeyboardOpen ? 32 : 48,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              // Dialpad Grid
              Flexible(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Row 1: 1, 2, 3
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialpadButton('1', ''),
                              _buildDialpadButton('2', 'ABC'),
                              _buildDialpadButton('3', 'DEF'),
                            ],
                          ),
                          
                          // Row 2: 4, 5, 6
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialpadButton('4', 'GHI'),
                              _buildDialpadButton('5', 'JKL'),
                              _buildDialpadButton('6', 'MNO'),
                            ],
                          ),
                          
                          // Row 3: 7, 8, 9
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialpadButton('7', 'PQRS'),
                              _buildDialpadButton('8', 'TUV'),
                              _buildDialpadButton('9', 'WXYZ'),
                            ],
                          ),
                          
                          // Row 4: *, 0, #
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialpadButton('*', ''),
                              _buildDialpadButton('0', '+'),
                              _buildDialpadButton('#', ''),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Bottom Action Buttons - Fixed positions aligned with keypad
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Left space (empty to align with "*" key)
                  const SizedBox(width: 90),
                  
                  // Call Button - centered under "0" key
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: _dialedNumber.isNotEmpty ? _onCallPressed : null,
                        child: Opacity(
                          opacity: _dialedNumber.isNotEmpty ? 1.0 : 0.5,
                          child: const Icon(
                            Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Delete Button - positioned under "#" key
                  Container(
                    width: 90,
                    height: 90,
                    child: Center(
                      child: _dialedNumber.isNotEmpty 
                          ? Container(
                              width: 48,
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _onBackspacePressed,
                                  child: const Icon(
                                    Icons.backspace_outlined,
                                    color: Color(0xFF666666),
                                    size: 24,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(), // Empty space when no number dialed
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

  Widget _buildDialpadButton(String digit, String letters) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(45),
          onTap: () => _onDigitPressed(digit),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}