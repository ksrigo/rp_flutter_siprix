import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';
import '../../features/call/presentation/screens/in_call_screen.dart';
import '../../features/contacts/presentation/screens/contacts_page.dart';
import '../../features/contacts/presentation/screens/add_contact_screen.dart';
import '../../features/contacts/presentation/screens/edit_contact_screen.dart';
import '../../features/contacts/presentation/widgets/device_contacts_setting.dart';
import '../services/contacts_service.dart';
import '../../features/contacts/data/models/contact_model.dart';
import '../../features/dialpad/presentation/screens/dialpad_screen.dart';
import '../../features/recents/presentation/screens/recents_screen.dart';
import '../../shared/widgets/main_navigation.dart';
import '../services/sip_service.dart';
import '../services/auth_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    routes: [
      // Splash and Authentication Routes
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Main App Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => MainNavigation(child: child),
        routes: [
          GoRoute(
            path: '/keypad',
            name: 'keypad',
            builder: (context, state) => const DialpadScreen(),
          ),
          GoRoute(
            path: '/recents',
            name: 'recents',
            builder: (context, state) => const RecentsScreen(),
          ),
          GoRoute(
            path: '/contacts',
            name: 'contacts',
            builder: (context, state) => const ContactsPage(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-contact',
                builder: (context, state) => const AddContactScreen(),
              ),
              GoRoute(
                path: 'edit',
                name: 'edit-contact',
                builder: (context, state) {
                  final contact = state.extra as ContactModel;
                  return EditContactScreen(contact: contact);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/voicemail',
            name: 'voicemail',
            builder: (context, state) => const VoicemailScreen(),
            routes: [
              GoRoute(
                path: 'details/:id',
                name: 'voicemail-details',
                builder: (context, state) {
                  final voicemailId = state.pathParameters['id']!;
                  return VoicemailDetailsScreen(voicemailId: voicemailId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'account',
                name: 'account-settings',
                builder: (context, state) => const AccountSettingsScreen(),
              ),
              GoRoute(
                path: 'contacts',
                name: 'contacts-settings',
                builder: (context, state) => const ContactsSettingsScreen(),
              ),
              GoRoute(
                path: 'calls',
                name: 'calls-settings',
                builder: (context, state) => const CallsSettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Call-related Routes (Full Screen)
      GoRoute(
        path: '/incoming-call',
        name: 'incoming-call',
        builder: (context, state) {
          final callId = state.uri.queryParameters['callId'];
          final callerName = state.uri.queryParameters['callerName'];
          final callerNumber = state.uri.queryParameters['callerNumber'];
          return IncomingCallScreen(
            callId: callId ?? '',
            callerName: callerName ?? 'Unknown',
            callerNumber: callerNumber ?? 'Unknown',
          );
        },
      ),
      GoRoute(
        path: '/in-call',
        name: 'in-call',
        builder: (context, state) {
          final callId = state.uri.queryParameters['callId'];
          final phoneNumber = state.uri.queryParameters['phoneNumber'];
          final contactName = state.uri.queryParameters['contactName'];
          return InCallScreen(
            callId: callId ?? '',
            phoneNumber: phoneNumber,
            contactName: contactName,
          );
        },
      ),
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/keypad'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );

  // Navigation helper methods
  static void goToKeypad() => router.go('/keypad');
  static void goToRecents() => router.go('/recents');
  static void goToContacts() => router.go('/contacts');
  static void goToAddContact() => router.go('/contacts/add');
  static void goToEditContact(ContactModel contact) => router.go('/contacts/edit', extra: contact);
  static void goToVoicemail() => router.go('/voicemail');
  static void goToSettings() => router.go('/settings');

  static void goToLogin() => router.go('/login');

  static void goToIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
  }) {
    router.go(
        '/incoming-call?callId=$callId&callerName=$callerName&callerNumber=$callerNumber');
  }

  static void goToInCall(String callId, {String? phoneNumber, String? contactName}) {
    String url = '/in-call?callId=$callId';
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      url += '&phoneNumber=${Uri.encodeQueryComponent(phoneNumber)}';
    }
    if (contactName != null && contactName.isNotEmpty) {
      url += '&contactName=${Uri.encodeQueryComponent(contactName)}';
    }
    router.go(url);
  }

  static void goBack() {
    if (router.canPop()) {
      router.pop();
    }
  }

  static void goToVoicemailDetails(String voicemailId) {
    router.go('/voicemail/details/$voicemailId');
  }
}

class VoicemailScreen extends StatelessWidget {
  const VoicemailScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Voicemail')));
}

class VoicemailDetailsScreen extends StatelessWidget {
  final String voicemailId;
  const VoicemailDetailsScreen({super.key, required this.voicemailId});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Voicemail Details $voicemailId')));
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Unregister SIP
      await SipService.instance.unregister();
      
      // Clear auth service
      await AuthService.instance.logout();
      
      // Navigate to login
      // ignore: use_build_context_synchronously
      context.go('/login');
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Settings Items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ListView(
                  children: [
                    _buildSettingsItem(
                      icon: Icons.account_circle_outlined,
                      title: 'Account Settings',
                      subtitle: 'Manage your account',
                      onTap: () => context.go('/settings/account'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.contacts_outlined,
                      title: 'Contacts',
                      subtitle: 'Manage contact settings',
                      onTap: () => context.go('/settings/contacts'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.phone_outlined,
                      title: 'Call Options',
                      subtitle: 'Manage call settings',
                      onTap: () => context.go('/settings/calls'),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // App Version
                    if (_appVersion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Version $_appVersion',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Logout Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF6B46C1),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: const Color(0xFFF8F9FA),
        onTap: onTap,
      ),
    );
  }
}

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
      final currentTransport = await SipService.instance.getCurrentTransportAsync();
      setState(() {
        _selectedTransport = currentTransport;
      });
      debugPrint('Account Settings: Loaded current transport: $currentTransport');
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                            _buildReadOnlyField(
                              label: 'Name',
                              value: extensionDetails.name,
                            ),
                            const SizedBox(height: 20),
                            _buildReadOnlyField(
                              label: 'Extension',
                              value: extensionDetails.extension.toString(),
                            ),
                            const SizedBox(height: 20),
                            _buildReadOnlyField(
                              label: 'Domain',
                              value: extensionDetails.domain,
                            ),
                            const SizedBox(height: 20),
                            _buildTransportSelector(),
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

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransportSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transport',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTransport,
              onChanged: _onTransportChanged,
              items: ['UDP', 'TCP'].map((String transport) {
                return DropdownMenuItem<String>(
                  value: transport,
                  child: Text(
                    transport,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                );
              }).toList(),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.primary,
              ),
              dropdownColor: Colors.white,
            ),
          ),
        ),
      ],
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

class CallsSettingsScreen extends StatefulWidget {
  const CallsSettingsScreen({super.key});

  @override
  State<CallsSettingsScreen> createState() => _CallsSettingsScreenState();
}

class _CallsSettingsScreenState extends State<CallsSettingsScreen> {
  bool _showCallerID = true;
  bool _enableRecording = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadExtensionSettings();
  }

  Future<void> _loadExtensionSettings({bool showLoading = true}) async {
    debugPrint('🔄 CallsSettings: _loadExtensionSettings called with showLoading: $showLoading');
    if (!mounted) {
      debugPrint('❌ CallsSettings: Widget not mounted, returning');
      return;
    }
    
    try {
      if (showLoading) {
        debugPrint('🔄 CallsSettings: Setting _isLoading = true');
        setState(() {
          _isLoading = true;
        });
      }

      final authService = AuthService.instance;
      final extensionDetails = authService.extensionDetails;
      
      if (extensionDetails == null) {
        debugPrint('❌ CallsSettings: No extension details available');
        return;
      }

      debugPrint('📋 CallsSettings: Extension ID: ${extensionDetails.id}');

      final accessToken = await authService.getValidAccessToken();
      if (accessToken == null) {
        debugPrint('❌ CallsSettings: No valid access token');
        return;
      }

      debugPrint('🔑 CallsSettings: Access token available: ${accessToken.substring(0, 20)}...');

      final url = 'https://api.ringplus.co.uk/v1/extension/${extensionDetails.id}';
      debugPrint('🌐 CallsSettings: Making GET request to: $url');

      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      debugPrint('📥 CallsSettings: GET response - Status: ${response.statusCode}');
      debugPrint('📥 CallsSettings: GET response - Data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final clirValue = data['clir'] ?? false;
        final recordValue = data['record'] ?? false;
        
        debugPrint('📊 CallsSettings: Server data - clir: $clirValue, record: $recordValue');
        
        if (mounted) {
          final oldShowCallerID = _showCallerID;
          final oldEnableRecording = _enableRecording;
          
          setState(() {
            // CLIR logic: false means show caller ID, true means hide caller ID
            _showCallerID = !clirValue;
            _enableRecording = recordValue;
          });
          
          debugPrint('🔄 CallsSettings: State updated - showCallerID: $oldShowCallerID -> $_showCallerID');
          debugPrint('🔄 CallsSettings: State updated - enableRecording: $oldEnableRecording -> $_enableRecording');
        }
        debugPrint('✅ CallsSettings: Settings loaded successfully');
      } else {
        debugPrint('❌ CallsSettings: Invalid response - Status: ${response.statusCode}, Data: ${response.data}');
      }
    } catch (e) {
      debugPrint('CallsSettings: Error loading extension settings: $e');
      if (mounted && e is DioException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load call settings: ${e.response?.data ?? e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateCallerIDSetting(bool value) async {
    debugPrint('🔄 CallsSettings: _updateCallerIDSetting called with value: $value');
    
    if (!mounted || _isUpdating) {
      debugPrint('❌ CallsSettings: Cannot update - mounted: $mounted, _isUpdating: $_isUpdating');
      return;
    }
    
    bool updateSuccessful = false;
    
    try {
      debugPrint('🔒 CallsSettings: Setting _isUpdating = true');
      setState(() {
        _isUpdating = true;
      });

      final authService = AuthService.instance;
      final extensionDetails = authService.extensionDetails;
      final accessToken = await authService.getValidAccessToken();
      
      if (extensionDetails == null || accessToken == null) {
        throw Exception('Authentication required');
      }

      // CLIR logic: UI value true (show caller ID) = API clir: false
      final clirValue = !value;
      debugPrint('📊 CallsSettings: UI value: $value -> API clir value: $clirValue');

      final url = 'https://api.ringplus.co.uk/v1/extension/${extensionDetails.id}';
      final payload = {'clir': clirValue};
      debugPrint('🌐 CallsSettings: Making PATCH request to: $url');
      debugPrint('📤 CallsSettings: PATCH payload: $payload');

      final response = await Dio().patch(
        url,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      debugPrint('📥 CallsSettings: PATCH response - Status: ${response.statusCode}');
      debugPrint('📥 CallsSettings: PATCH response - Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        updateSuccessful = true;
        debugPrint('✅ CallsSettings: Caller ID setting updated successfully (Status: ${response.statusCode})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Caller ID setting ${value ? 'enabled' : 'disabled'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('❌ CallsSettings: PATCH failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ CallsSettings: Error updating caller ID setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update caller ID setting: ${e is DioException ? e.response?.data ?? e.message : e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        debugPrint('🔓 CallsSettings: Setting _isUpdating = false');
        setState(() {
          _isUpdating = false;
        });
        
        debugPrint('🔄 CallsSettings: updateSuccessful: $updateSuccessful');
        // Refresh the data from server after update is complete (success or failure)
        if (updateSuccessful) {
          debugPrint('🔄 CallsSettings: Calling _loadExtensionSettings for refresh...');
          await _loadExtensionSettings(showLoading: false);
          debugPrint('✅ CallsSettings: Refresh completed');
        } else {
          debugPrint('⚠️ CallsSettings: Skipping refresh due to failed update');
        }
      }
    }
  }

  Future<void> _updateRecordingSetting(bool value) async {
    debugPrint('🔄 CallsSettings: _updateRecordingSetting called with value: $value');
    
    if (!mounted || _isUpdating) {
      debugPrint('❌ CallsSettings: Cannot update - mounted: $mounted, _isUpdating: $_isUpdating');
      return;
    }
    
    bool updateSuccessful = false;
    
    try {
      debugPrint('🔒 CallsSettings: Setting _isUpdating = true');
      setState(() {
        _isUpdating = true;
      });

      final authService = AuthService.instance;
      final extensionDetails = authService.extensionDetails;
      final accessToken = await authService.getValidAccessToken();
      
      if (extensionDetails == null || accessToken == null) {
        throw Exception('Authentication required');
      }

      final url = 'https://api.ringplus.co.uk/v1/extension/${extensionDetails.id}';
      final payload = {'record': value};
      debugPrint('🌐 CallsSettings: Making PATCH request to: $url');
      debugPrint('📤 CallsSettings: PATCH payload: $payload');

      final response = await Dio().patch(
        url,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      debugPrint('📥 CallsSettings: PATCH response - Status: ${response.statusCode}');
      debugPrint('📥 CallsSettings: PATCH response - Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        updateSuccessful = true;
        debugPrint('✅ CallsSettings: Recording setting updated successfully (Status: ${response.statusCode})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call recording ${value ? 'enabled' : 'disabled'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('❌ CallsSettings: PATCH failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ CallsSettings: Error updating recording setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update recording setting: ${e is DioException ? e.response?.data ?? e.message : e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        debugPrint('🔓 CallsSettings: Setting _isUpdating = false');
        setState(() {
          _isUpdating = false;
        });
        
        debugPrint('🔄 CallsSettings: updateSuccessful: $updateSuccessful');
        // Refresh the data from server after update is complete (success or failure)
        if (updateSuccessful) {
          debugPrint('🔄 CallsSettings: Calling _loadExtensionSettings for refresh...');
          await _loadExtensionSettings(showLoading: false);
          debugPrint('✅ CallsSettings: Refresh completed');
        } else {
          debugPrint('⚠️ CallsSettings: Skipping refresh due to failed update');
        }
      }
    }
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6B46C1),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Call Options',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)),
                ),
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
                            _buildToggleItem(
                              title: 'Show Caller ID',
                              subtitle: 'Display your phone number to recipients when making calls',
                              value: _showCallerID,
                              onChanged: _isUpdating ? null : _updateCallerIDSetting,
                            ),
                            _buildToggleItem(
                              title: 'Enable Recording',
                              subtitle: 'Automatically record incoming and outgoing calls',
                              value: _enableRecording,
                              onChanged: _isUpdating ? null : _updateRecordingSetting,
                            ),
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
}

class ContactsSettingsScreen extends StatefulWidget {
  const ContactsSettingsScreen({super.key});

  @override
  State<ContactsSettingsScreen> createState() => _ContactsSettingsScreenState();
}

class _ContactsSettingsScreenState extends State<ContactsSettingsScreen> {
  bool _isDeviceContactsEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();
  }

  void _loadCurrentState() {
    setState(() {
      _isLoading = true;
      _isDeviceContactsEnabled = ContactsService.instance.isDeviceContactsEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleDeviceContacts(bool value) async {
    if (!mounted || _isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      if (value) {
        await ContactsService.instance.enableDeviceContacts();
      } else {
        await ContactsService.instance.disableDeviceContacts();
      }
      
      if (mounted) {
        setState(() {
          _isDeviceContactsEnabled = value;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Device contacts enabled and syncing'
                  : 'Device contacts disabled',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('ContactsSettings: Error toggling device contacts: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${value ? 'enabling' : 'disabling'} device contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6B46C1),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Contacts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)),
                ),
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
                            _buildToggleItem(
                              title: 'Device Contacts',
                              subtitle: _isDeviceContactsEnabled
                                  ? 'Merge device contacts with API phonebook'
                                  : 'Only show API phonebook contacts',
                              value: _isDeviceContactsEnabled,
                              onChanged: _isUpdating ? null : _toggleDeviceContacts,
                            ),
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
}

