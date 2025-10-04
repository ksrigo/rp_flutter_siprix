import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/contact_service.dart';
import '../../../contacts/data/models/contact_model.dart';

enum TransferType { blind, attended }

class CallTransferDialog extends ConsumerStatefulWidget {
  final String callId;
  final VoidCallback onCancel;
  final Function(String number, TransferType type) onTransfer;

  const CallTransferDialog({
    super.key,
    required this.callId,
    required this.onCancel,
    required this.onTransfer,
  });

  @override
  ConsumerState<CallTransferDialog> createState() => _CallTransferDialogState();
}

class _CallTransferDialogState extends ConsumerState<CallTransferDialog> {
  final TextEditingController _numberController = TextEditingController();
  final FocusNode _numberFocusNode = FocusNode();
  bool _isTransferring = false;
  List<ContactInfo> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _numberController.addListener(_onNumberChanged);
  }

  @override
  void dispose() {
    _numberController.removeListener(_onNumberChanged);
    _numberController.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  void _onNumberChanged() {
    final query = _numberController.text.trim();
    if (query != _searchQuery) {
      _searchQuery = query;
      _searchContacts(query);
    }
  }

  Future<void> _searchContacts(String query) async {
    // Disable contact search for now since it only works with exact phone number matches
    // and causes confusion with the loading spinner
    setState(() {
      _searchResults.clear();
      _isSearching = false;
    });
    return;

    // Future enhancement: Implement proper contact name/partial number search
    /*
    if (query.isEmpty || query.length < 2) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      if (ContactService.instance.hasPermission) {
        // TODO: Implement proper contact search by name and partial phone number
        final contact = await ContactService.instance.findContactByPhoneNumber(query);
        setState(() {
          _searchResults = contact != null ? [contact] : [];
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching contacts: $e');
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
    }
    */
  }

  void _selectContact(ContactInfo contact) {
    // Use the contact's phone number
    final phoneNumber = contact.phoneNumber;

    if (phoneNumber.isNotEmpty) {
      _numberController.text = phoneNumber;
      setState(() {
        _searchResults.clear();
      });
      _numberFocusNode.unfocus();
    }
  }

  void _handleTransfer(TransferType type) {
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() {
      _isTransferring = true;
    });

    widget.onTransfer(number, type);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with close button only
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _isTransferring ? null : widget.onCancel,
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),

            // Number input field
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _numberFocusNode.hasFocus
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _numberController,
                focusNode: _numberFocusNode,
                enabled: !_isTransferring,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.phone,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),

            // Search results
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            else if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: _searchResults.map((contact) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage: contact.hasPhoto && contact.photo != null
                            ? MemoryImage(contact.photo!)
                            : null,
                        child: contact.hasPhoto && contact.photo != null
                            ? null
                            : Text(
                                contact.displayName.isNotEmpty
                                    ? contact.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      title: Text(
                        contact.displayName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: contact.phoneNumber.isNotEmpty
                          ? Text(
                              contact.phoneNumber,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            )
                          : null,
                      onTap: _isTransferring ? null : () => _selectContact(contact),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 24),

            // Transfer buttons
            if (_isTransferring)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transferring...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Transfer buttons on same line
              Row(
                children: [
                  // Blind Transfer Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _handleTransfer(TransferType.blind),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_merge, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Blind',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Attended Transfer Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _handleTransfer(TransferType.attended),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.supervisor_account, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Attended',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }
}