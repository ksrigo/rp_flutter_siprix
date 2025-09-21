import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/sip_service.dart';
import '../widgets/read_only_field.dart';
import '../widgets/transport_selector.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String _selectedTransport = 'UDP';
  bool _isReregistering = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTransport();
  }

  void _loadCurrentTransport() async {
    // Get current transport from SIP service (which now reads from storage)
    try {
      final currentTransport =
          await SipService.instance.getCurrentTransportAsync();
      setState(() {
        _selectedTransport = currentTransport;
      });
      debugPrint(
          'Account Settings: Loaded current transport: $currentTransport');
    } catch (e) {
      debugPrint('Account Settings: Failed to load transport: $e');
      setState(() {
        _selectedTransport = 'UDP'; // Default fallback
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;
    final extensionDetails = authService.extensionDetails;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: extensionDetails == null
            ? const Center(
                child: Text('No extension details available'),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReadOnlyField(
                              label: 'Name',
                              value: extensionDetails.name,
                            ),
                            const SizedBox(height: 20),
                            ReadOnlyField(
                              label: 'Extension',
                              value: extensionDetails.extension.toString(),
                            ),
                            const SizedBox(height: 20),
                            ReadOnlyField(
                              label: 'Domain',
                              value: extensionDetails.domain,
                            ),
                            const SizedBox(height: 20),
                            TransportSelector(
                              selectedTransport: _selectedTransport,
                              onChanged: _onTransportChanged,
                            ),
                            const SizedBox(height: 40),
                            _buildReregisterButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildReregisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isReregistering ? null : _onReregisterPressed,
        icon: _isReregistering
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.refresh, color: Colors.white),
        label: Text(
          _isReregistering ? 'Re-registering...' : 'Re-register',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _onTransportChanged(String? newTransport) async {
    if (newTransport != null && newTransport != _selectedTransport) {
      final oldTransport = _selectedTransport;

      setState(() {
        _selectedTransport = newTransport;
      });

      try {
        // Update the account transport in SIP service
        final success = await SipService.instance.updateTransport(newTransport);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Transport changed to $newTransport and re-registered successfully'
                  : 'Failed to update transport. Please ensure you are registered and try again.'),
              backgroundColor: success ? Colors.green : Colors.red,
              duration: Duration(seconds: success ? 3 : 5),
            ),
          );

          // If update failed, revert the UI selection
          if (!success) {
            setState(() {
              _selectedTransport = oldTransport;
            });
          }
        }
      } catch (e) {
        debugPrint('Transport change error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update transport: $e'),
              backgroundColor: Colors.red,
            ),
          );

          // Revert the UI selection
          setState(() {
            _selectedTransport = oldTransport;
          });
        }
      }
    }
  }

  Future<void> _onReregisterPressed() async {
    setState(() {
      _isReregistering = true;
    });

    try {
      // Trigger re-registration through SIP service
      final success = await SipService.instance.reregister();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Re-registration successful'
                : 'Re-registration failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Re-registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReregistering = false;
        });
      }
    }
  }
}