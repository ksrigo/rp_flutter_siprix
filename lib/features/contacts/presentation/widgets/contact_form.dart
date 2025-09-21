import 'package:flutter/material.dart';

import '../../../../core/services/contacts_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/api_service.dart';
import '../../data/models/contact_model.dart';

class ContactForm extends StatefulWidget {
  final ContactModel? contact; // null for add, populated for edit
  final VoidCallback? onSaved;
  final VoidCallback? onDeleted;

  const ContactForm({
    super.key,
    this.contact,
    this.onSaved,
    this.onDeleted,
  });

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();

  List<PhoneNumberEntry> _phoneNumbers = [];
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get isEditMode => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (isEditMode && widget.contact != null) {
      // Pre-fill form with existing contact data
      _firstNameController.text = widget.contact!.firstName ?? '';
      _lastNameController.text = widget.contact!.lastName ?? '';
      _emailController.text = widget.contact!.emails.isNotEmpty
          ? widget.contact!.emails.first.address
          : '';
      _companyController.text = widget.contact!.company ?? '';
      _notesController.text = widget.contact!.notes ?? '';

      // Pre-fill phone numbers
      _phoneNumbers = widget.contact!.phones.map((phone) {
        final entry = PhoneNumberEntry();
        entry.controller.text = phone.number;
        entry.type = _capitalizeFirst(phone.label);
        return entry;
      }).toList();

      // Ensure at least one phone number entry
      if (_phoneNumbers.isEmpty) {
        _phoneNumbers.add(PhoneNumberEntry());
      }
    } else {
      // Initialize for add mode
      _phoneNumbers = [PhoneNumberEntry()];
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return 'Mobile';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    for (final phone in _phoneNumbers) {
      phone.dispose();
    }
    super.dispose();
  }

  void _addPhoneNumber() {
    setState(() {
      _phoneNumbers.add(PhoneNumberEntry());
    });
  }

  void _removePhoneNumber(int index) {
    if (_phoneNumbers.length > 1) {
      setState(() {
        _phoneNumbers[index].dispose();
        _phoneNumbers.removeAt(index);
      });
    }
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one phone number
    final validPhones = _phoneNumbers
        .where((phone) => phone.controller.text.trim().isNotEmpty)
        .toList();

    if (validPhones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one phone number is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = AuthService.instance;
      final apiService = ApiService.instance;

      if (!authService.isAuthenticated ||
          authService.extensionDetails == null) {
        throw Exception('Not authenticated');
      }

      // Build the payload
      final payload = {
        "is_shared": false,
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "company": _companyController.text.trim(),
        "notes": _notesController.text.trim(),
        "numbers": validPhones
            .map((phone) => {
                  "type": phone.type.toLowerCase(),
                  "number": phone.controller.text.trim(),
                })
            .toList(),
        "email": _emailController.text.trim(),
      };

      late dynamic response;

      if (isEditMode) {
        // Update existing contact
        final contactId = widget.contact!.contactId;
        response = await apiService.patch(
          '/contact/$contactId',
          data: payload,
        );
      } else {
        // Create new contact
        final extensionId = authService.extensionDetails!.id;
        response = await apiService.post(
          '/extension/$extensionId/contacts',
          data: [payload], // POST expects array
        );
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        // Success - refresh contacts
        await ContactsService.instance.refreshContacts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditMode
                  ? 'Contact updated successfully'
                  : 'Contact saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSaved?.call();
        }
      } else {
        throw Exception(
            'Failed to ${isEditMode ? 'update' : 'save'} contact: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error ${isEditMode ? 'updating' : 'saving'} contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteContact() async {
    if (!isEditMode) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
            'Are you sure you want to delete ${widget.contact!.formattedName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final apiService = ApiService.instance;
      final contactId = widget.contact!.contactId;

      final response = await apiService.delete('/contact/$contactId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Success - refresh contacts
        await ContactsService.instance.refreshContacts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onDeleted?.call();
        }
      } else {
        throw Exception('Failed to delete contact: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildAvatarSection(),
                      const SizedBox(height: 40),
                      _buildTextField(
                        label: 'First Name',
                        controller: _firstNameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Last Name',
                        controller: _lastNameController,
                      ),
                      const SizedBox(height: 20),
                      _buildPhoneSection(),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Company',
                        controller: _companyController,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        label: 'Notes',
                        controller: _notesController,
                        maxLines: 4,
                        hintText: 'Add any notes here...',
                      ),
                      const SizedBox(height: 40),
                      if (isEditMode) _buildDeleteButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          Expanded(
            child: Text(
              isEditMode ? 'Edit Contact' : 'New Contact',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          GestureDetector(
            onTap: _isSaving ? null : _saveContact,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isSaving
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ..._phoneNumbers.asMap().entries.map((entry) {
          final index = entry.key;
          final phone = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPhoneRow(phone, index),
          );
        }),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _addPhoneNumber,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Add phone number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneRow(PhoneNumberEntry phone, int index) {
    return Row(
      children: [
        // Dropdown for phone type
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: phone.type,
              onChanged: (String? newValue) {
                setState(() {
                  phone.type = newValue!;
                });
              },
              items: ['Mobile', 'Work', 'Home'].map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Phone number input
        Expanded(
          child: TextFormField(
            controller: phone.controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '(123) 456-7890',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        // Delete button
        if (_phoneNumbers.length > 1) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _removePhoneNumber(index),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isDeleting ? null : _deleteContact,
        icon: _isDeleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.delete, color: Colors.white),
        label: Text(
          _isDeleting ? 'Deleting...' : 'Delete Contact',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

class PhoneNumberEntry {
  final TextEditingController controller = TextEditingController();
  String type = 'Mobile';

  void dispose() {
    controller.dispose();
  }
}
