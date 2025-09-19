import 'package:flutter/material.dart';

import '../../../../core/services/contacts_service.dart';

class DeviceContactsSetting extends StatefulWidget {
  const DeviceContactsSetting({super.key});

  @override
  State<DeviceContactsSetting> createState() => _DeviceContactsSettingState();
}

class _DeviceContactsSettingState extends State<DeviceContactsSetting> {
  bool _isLoading = false;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();
  }

  void _loadCurrentState() {
    setState(() {
      _isEnabled = ContactsService.instance.isDeviceContactsEnabled;
    });
  }

  Future<void> _toggleDeviceContacts(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        await ContactsService.instance.enableDeviceContacts();
      } else {
        await ContactsService.instance.disableDeviceContacts();
      }
      
      setState(() {
        _isEnabled = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Device contacts enabled and syncing'
                : 'Device contacts disabled',
          ),
        ),
      );
    } catch (e) {
      debugPrint('DeviceContactsSetting: Error toggling device contacts: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${value ? 'enabling' : 'disabling'} device contacts: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.contacts,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text(
        'Device Contacts',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _isEnabled
            ? 'Merge device contacts with API phonebook'
            : 'Only show API phonebook contacts',
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : Switch(
              value: _isEnabled,
              onChanged: _toggleDeviceContacts,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}