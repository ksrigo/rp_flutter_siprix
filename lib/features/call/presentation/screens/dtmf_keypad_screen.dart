import 'package:flutter/material.dart';
import '../../../../core/services/sip_service.dart';

class DtmfKeypadScreen extends StatefulWidget {
  final String callId;

  const DtmfKeypadScreen({
    super.key,
    required this.callId,
  });

  @override
  State<DtmfKeypadScreen> createState() => _DtmfKeypadScreenState();
}

class _DtmfKeypadScreenState extends State<DtmfKeypadScreen> {
  String _enteredDigits = '';

  static const _keypadData = [
    [('1', ''), ('2', 'ABC'), ('3', 'DEF')],
    [('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO')],
    [('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ')],
    [('*', ''), ('0', '+'), ('#', '')],
  ];

  void _sendDtmf(String digit) {
    setState(() {
      _enteredDigits += digit;
    });

    try {
      final call = SipService.instance.findCallByCallId(widget.callId);
      if (call != null) {
        call.sendDtmf(digit);
        debugPrint('DtmfKeypadScreen: Sent DTMF digit: $digit');
      }
    } catch (e) {
      debugPrint('DtmfKeypadScreen: Error sending DTMF: $e');
    }
  }

  void _deleteDigit() {
    if (_enteredDigits.isNotEmpty) {
      setState(() {
        _enteredDigits = _enteredDigits.substring(0, _enteredDigits.length - 1);
      });
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
                const SizedBox(height: 24),
                _buildEnteredDigits(),
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

  Widget _buildEnteredDigits() => SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  _enteredDigits.isNotEmpty ? _enteredDigits : 'Enter digits',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: _enteredDigits.isNotEmpty
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            if (_enteredDigits.isNotEmpty) _buildDeleteButton(),
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
            onTap: () => _sendDtmf(digit),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(Icons.arrow_back, 'Go Back', Colors.white,
              () => Navigator.of(context).pop(),
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
