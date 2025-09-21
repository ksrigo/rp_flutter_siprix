import 'package:flutter/material.dart';

class TransportSelector extends StatelessWidget {
  final String selectedTransport;
  final ValueChanged<String?> onChanged;

  const TransportSelector({
    super.key,
    required this.selectedTransport,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transport',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedTransport,
              onChanged: onChanged,
              items: ['UDP', 'TCP'].map((String transport) {
                return DropdownMenuItem<String>(
                  value: transport,
                  child: Text(
                    transport,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.primary,
              ),
              dropdownColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}