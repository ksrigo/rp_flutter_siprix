// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:siprix_voip_sdk/network_model.dart';
//
// import '../../../../core/services/auth_service.dart';
// import '../../../../core/services/sip_service.dart';
// import '../../../../core/services/navigation_service.dart';
//
// class DialpadScreen extends ConsumerStatefulWidget {
//   const DialpadScreen({super.key});
//
//   @override
//   ConsumerState<DialpadScreen> createState() => _DialpadScreenState();
// }
//
// class _DialpadScreenState extends ConsumerState<DialpadScreen> {
//   String _dialedNumber = '';
//   bool _isDndEnabled = false;
//   final NetworkModel _networkModel = NetworkModel(); // Create NetworkModel instance
//
//   @override
//   void initState() {
//     super.initState();
//     _loadDndState();
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Reload DND state when screen becomes active
//     _loadDndState();
//   }
//
//   Future<void> _loadDndState() async {
//     try {
//       final dndEnabled = await SipService.instance.isDoNotDisturbEnabled();
//       if (mounted) {
//         setState(() {
//           _isDndEnabled = dndEnabled;
//         });
//       }
//     } catch (e) {
//       debugPrint('DialpadScreen: error loading DND state: $e');
//     }
//   }
//
//   void _onDigitPressed(String digit) {
//     if (_dialedNumber.length < 11) {
//       setState(() {
//         _dialedNumber += digit;
//       });
//     }
//   }
//
//   void _onBackspacePressed() {
//     if (_dialedNumber.isNotEmpty) {
//       setState(() {
//         _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1);
//       });
//     }
//   }
//
//   void _onCallPressed() async {
//     if (_dialedNumber.isNotEmpty) {
//       try {
//         final callId = await SipService.instance.makeCall(_dialedNumber);
//         if (callId != null) {
//           NavigationService.goToInCall(callId, phoneNumber: _dialedNumber);
//           if (mounted) {
//             setState(() {
//               _dialedNumber = '';
//             });
//           }
//         }
//       } catch (e) {
//         debugPrint('DialpadScreen: error initiating call: $e');
//       }
//     }
//   }
//
//   // Get display name based on network and registration status
//   String _getDisplayName() {
//     final sipService = SipService.instance;
//
//     // If network is lost OR no connectivity OR not registered, show fallback
//     if (_networkModel.networkLost ||
//         !sipService.hasNetworkConnectivity ||
//         !sipService.isRegistered) {
//       return 'User';
//     }
//
//     // Only show real details when everything is good
//     return AuthService.instance.extensionDetails?.name ?? 'User';
//   }
//
//   // Get display extension based on network and registration status
//   String _getDisplayExtension() {
//     final sipService = SipService.instance;
//
//     // If network is lost OR no connectivity OR not registered, show fallback
//     if (_networkModel.networkLost ||
//         !sipService.hasNetworkConnectivity ||
//         !sipService.isRegistered) {
//       return 'N/A';
//     }
//
//     // Only show real details when everything is good
//     return AuthService.instance.extensionDetails?.extension?.toString() ?? 'N/A';
//   }
//
//   // Build status chip with combined network and SIP status
//   Widget _buildStatusChip() {
//     final sipService = SipService.instance;
//
//     String chipText;
//     Color chipColor;
//     Color chipBgColor;
//
//     if (_isDndEnabled) {
//       chipText = 'DND';
//       chipColor = const Color(0xFFFF5252);
//       chipBgColor = const Color(0xFFFFE6E6);
//     } else if (_networkModel.networkLost || !sipService.hasNetworkConnectivity) {
//       chipText = 'Offline';
//       chipColor = const Color(0xFFFF5252);
//       chipBgColor = const Color(0xFFFFE6E6);
//     } else if (!sipService.isRegistered) {
//       chipText = 'Offline';
//       chipColor = const Color(0xFFFF9800);
//       chipBgColor = const Color(0xFFFFF3E0);
//     } else {
//       chipText = 'Online';
//       chipColor = const Color(0xFF00C853);
//       chipBgColor = const Color(0xFFE6F7F1);
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: chipBgColor,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: chipColor, width: 1),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(
//               color: chipColor,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             chipText,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: chipColor,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final media = MediaQuery.of(context);
//     final height = media.size.height;
//     final safeBottom = media.padding.bottom;
//
//     // ✅ Dynamic scaling (fixed with .toDouble())
//     final double scale = (height / 800).clamp(0.85, 1.15).toDouble();
//     final double buttonSize = (90 * scale).toDouble();
//     final double callButtonSize = (78 * scale).toDouble();
//     final double topSpacing = (height * 0.015).clamp(8.0, 18.0).toDouble();
//     final double bottomPadding =
//     (safeBottom + (height * 0.01)).clamp(10.0, 24.0).toDouble();
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).colorScheme.surface,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24),
//           child: Column(
//             children: [
//               // Header - Using ListenableBuilder for network and SIP status updates
//               ListenableBuilder(
//                 listenable: Listenable.merge([_networkModel, SipService.instance]),
//                 builder: (context, child) {
//                   final sipService = SipService.instance;
//
//                   debugPrint('DialpadScreen: UI Refreshing - '
//                       'Network Lost: ${_networkModel.networkLost}, '
//                       'Has Network: ${sipService.hasNetworkConnectivity}, '
//                       'Is Registered: ${sipService.isRegistered}, '
//                       'DND: $_isDndEnabled');
//
//                   return Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             _getDisplayName(),
//                             style: TextStyle(
//                               fontSize: 28,
//                               fontWeight: FontWeight.w600,
//                               color:
//                               Theme.of(context).colorScheme.onPrimaryContainer,
//                             ),
//                           ),
//                           Text(
//                             'Ext: ${_getDisplayExtension()}',
//                             style: const TextStyle(
//                               fontSize: 16,
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ],
//                       ),
//                       _buildStatusChip(),
//                     ],
//                   );
//                 },
//               ),
//
//               // Number display
//               Container(
//                 height: 80,
//                 margin: EdgeInsets.symmetric(vertical: topSpacing),
//                 child: Center(
//                   child: Text(
//                     _dialedNumber,
//                     style: TextStyle(
//                       fontSize: 48 * scale,
//                       fontWeight: FontWeight.w400,
//                       color:
//                       Theme.of(context).colorScheme.onPrimaryContainer,
//                     ),
//                   ),
//                 ),
//               ),
//
//              // Dialpad
//               Flexible(
//                 flex: 3,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF'], buttonSize),
//                     _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO'], buttonSize),
//                     _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ'], buttonSize),
//                     _buildRow(['*', '0', '#'], ['', '+', ''], buttonSize),
//                   ],
//                 ),
//               ),
//
//               SizedBox(height: topSpacing),
//
//               // Bottom buttons
//               Padding(
//                 padding: EdgeInsets.only(bottom: bottomPadding),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     const SizedBox(width: 90),
//
//                     // Call
//                     Container(
//                       width: callButtonSize,
//                       height: callButtonSize,
//                       decoration: const BoxDecoration(
//                         shape: BoxShape.circle,
//                         gradient: LinearGradient(
//                           colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                       ),
//                       child: InkWell(
//                         borderRadius:
//                         BorderRadius.circular(callButtonSize / 2),
//                         onTap: _dialedNumber.isNotEmpty ? _onCallPressed : null,
//                         child: Opacity(
//                           opacity: _dialedNumber.isNotEmpty ? 1.0 : 0.5,
//                           child: const Icon(Icons.call,
//                               color: Colors.white, size: 30),
//                         ),
//                       ),
//                     ),
//
//                     // Delete
//                     SizedBox(
//                       width: 90,
//                       height: 90,
//                       child: Center(
//                         child: _dialedNumber.isNotEmpty
//                             ? InkWell(
//                           borderRadius: BorderRadius.circular(8),
//                           onTap: _onBackspacePressed,
//                           child: const Icon(Icons.backspace_outlined,
//                               color: Color(0xFF666666), size: 24),
//                         )
//                             : const SizedBox(),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRow(
//       List<String> digits, List<String> letters, double size) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: List.generate(
//         3,
//             (i) => _buildButton(digits[i], letters[i], size),
//       ),
//     );
//   }
//
//   Widget _buildButton(String digit, String letters, double size) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surfaceContainerHighest,
//         shape: BoxShape.circle,
//       ),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(size / 2),
//         onTap: () => _onDigitPressed(digit),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               digit,
//               style: TextStyle(
//                 fontSize: size * 0.35,
//                 fontWeight: FontWeight.w400,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//             ),
//             if (letters.isNotEmpty)
//               Text(
//                 letters,
//                 style: TextStyle(
//                   fontSize: size * 0.12,
//                   color: Theme.of(context).colorScheme.onSurfaceVariant,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siprix_voip_sdk/network_model.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../shared/services/storage_service.dart';

class DialpadScreen extends ConsumerStatefulWidget  {
  const DialpadScreen({super.key});

  @override
  ConsumerState<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends ConsumerState<DialpadScreen> {
  String _dialedNumber = '';
  bool _isDndEnabled = false;
  final NetworkModel _networkModel = NetworkModel();
  final GlobalKey _numberDisplayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDndState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDndState();
  }

  Future<void> _loadDndState() async {
    try {
      final dndEnabled = await SipService.instance.isDoNotDisturbEnabled();
      if (mounted) {
        setState(() {
          _isDndEnabled = dndEnabled;
        });
      }
    } catch (e) {
      debugPrint('DialpadScreen: error loading DND state: $e');
    }
  }

  void _onDigitPressed(String digit) {
    if (_dialedNumber.length < 11) {
      setState(() {
        _dialedNumber += digit;
      });
    }
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
      try {
        final callId = await SipService.instance.makeCall(_dialedNumber);
        if (callId != null) {
          NavigationService.goToInCall(callId, phoneNumber: _dialedNumber);
          if (mounted) {
            setState(() {
              _dialedNumber = '';
            });
          }
        }
      } catch (e) {
        debugPrint('DialpadScreen: error initiating call: $e');
      }
    }
  }

  // Handle paste from clipboard
  Future<void> _handlePaste() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        String pastedText = data.text!.trim();

        // Filter only digits and allowed characters (numbers, *, #, +)
        String filteredNumber = pastedText.replaceAll(RegExp(r'[^\d*#+]'), '');

        // Limit to 11 characters
        if (filteredNumber.length > 11) {
          filteredNumber = filteredNumber.substring(0, 11);
        }

        if (mounted && filteredNumber.isNotEmpty) {
          setState(() {
            _dialedNumber = filteredNumber;
          });
        }
      }
    } catch (e) {
      debugPrint('DialpadScreen: error pasting from clipboard: $e');
    }
  }

  // Get display name based on network and registration status
  String _getDisplayName() {
    final sipService = SipService.instance;

    if (_networkModel.networkLost ||
        !sipService.hasNetworkConnectivity ||
        !sipService.isRegistered) {
      return 'User';
    }

    return AuthService.instance.extensionDetails?.name ?? 'User';
  }

  // Get display extension based on network and registration status
  String _getDisplayExtension() {
    final sipService = SipService.instance;

    if (_networkModel.networkLost ||
        !sipService.hasNetworkConnectivity ||
        !sipService.isRegistered) {
      return 'N/A';
    }

    return AuthService.instance.extensionDetails?.extension?.toString() ?? 'N/A';
  }

  // Build status chip with combined network and SIP status
  Widget _buildStatusChip() {
    final sipService = SipService.instance;

    String chipText;
    Color chipColor;
    Color chipBgColor;

    if (_isDndEnabled) {
      chipText = 'DND';
      chipColor = const Color(0xFFFF5252);
      chipBgColor = const Color(0xFFFFE6E6);
    } else if (_networkModel.networkLost || !sipService.hasNetworkConnectivity) {
      chipText = 'Offline';
      chipColor = const Color(0xFFFF5252);
      chipBgColor = const Color(0xFFFFE6E6);
    } else if (!sipService.isRegistered) {
      chipText = 'Offline';
      chipColor = const Color(0xFFFF9800);
      chipBgColor = const Color(0xFFFFF3E0);
    } else {
      chipText = 'Online';
      chipColor = const Color(0xFF00C853);
      chipBgColor = const Color(0xFFE6F7F1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: chipBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            chipText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final safeBottom = media.padding.bottom;

    final double scale = (height / 800).clamp(0.85, 1.15).toDouble();
    final double buttonSize = (90 * scale).toDouble();
    final double callButtonSize = (78 * scale).toDouble();
    final double topSpacing = (height * 0.015).clamp(8.0, 18.0).toDouble();
    final double bottomPadding =
    (safeBottom + (height * 0.01)).clamp(10.0, 24.0).toDouble();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Header
              ListenableBuilder(
                listenable: Listenable.merge([_networkModel, SipService.instance]),
                builder: (context, child) {
                  final sipService = SipService.instance;

                  debugPrint('DialpadScreen: UI Refreshing - '
                      'Network Lost: ${_networkModel.networkLost}, '
                      'Has Network: ${sipService.hasNetworkConnectivity}, '
                      'Is Registered: ${sipService.isRegistered}, '
                      'DND: $_isDndEnabled');

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDisplayName(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            'Ext: ${_getDisplayExtension()}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusChip(),
                    ],
                  );
                },
              ),

              // Number display with context menu - FULL WIDTH and ALWAYS tappable
              Container(
                key: _numberDisplayKey,
                height: 80,
                width: double.infinity, // Force full width
                margin: EdgeInsets.symmetric(vertical: topSpacing),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: Colors.transparent, // Invisible border but maintains touch area
                    width: 1,
                  ),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // This makes the entire area tappable
                  onLongPress: () {
                    _showContextMenu(context);
                  },
                  child: Container(
                    width: double.infinity, // Fill parent width
                    color: Colors.transparent, // Make background transparent but tappable
                    child: Center(
                      child: Text(
                        _dialedNumber,
                        style: TextStyle(
                          fontSize: 48 * scale,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Dialpad
              Flexible(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF'], buttonSize),
                    _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO'], buttonSize),
                    _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ'], buttonSize),
                    _buildRow(['*', '0', '#'], ['', '+', ''], buttonSize),
                  ],
                ),
              ),

              SizedBox(height: topSpacing),

              // Bottom buttons
              Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 90),

                    // Call
                    Container(
                      width: callButtonSize,
                      height: callButtonSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(callButtonSize / 2),
                        onTap: _dialedNumber.isNotEmpty ? _onCallPressed : null,
                        child: Opacity(
                          opacity: _dialedNumber.isNotEmpty ? 1.0 : 0.5,
                          child: const Icon(Icons.call, color: Colors.white, size: 30),
                        ),
                      ),
                    ),

                    // Delete
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Center(
                        child: _dialedNumber.isNotEmpty
                            ? InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _onBackspacePressed,
                          child: const Icon(Icons.backspace_outlined,
                              color: Color(0xFF666666), size: 24),
                        )
                            : const SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox renderBox = _numberDisplayKey.currentContext?.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: [
        PopupMenuItem(
          onTap: () {
            // Delay to allow the menu to close first
            Future.delayed(Duration.zero, _handlePaste);
          },
          child: const Row(
            children: [
              Icon(Icons.paste, size: 20),
              SizedBox(width: 8),
              Text('Paste'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits, List<String> letters, double size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        3,
            (i) => _buildButton(digits[i], letters[i], size),
      ),
    );
  }

  Widget _buildButton(String digit, String letters, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: () => _onDigitPressed(digit),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  fontSize: size * 0.12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}