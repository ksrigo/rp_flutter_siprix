import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';
import '../../features/call/presentation/screens/in_call_screen.dart';
import '../../features/contacts/presentation/screens/contacts_page.dart';
import '../../features/contacts/presentation/screens/add_contact_screen.dart';
import '../../features/contacts/presentation/screens/edit_contact_screen.dart';
import '../services/contacts_service.dart';
import '../../features/contacts/data/models/contact_model.dart';
import '../../features/dialpad/presentation/screens/dialpad_screen.dart';
import '../../features/recents/presentation/screens/recents_screen.dart';
import '../../shared/widgets/main_navigation.dart';
import '../services/auth_service.dart';
import '../../features/settings/presentation/screens/settings_main_screen.dart';
import '../../features/settings/presentation/screens/account_settings_screen.dart';
import '../services/api_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash and Authentication Routes
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) {
          debugPrint('🏗️ NavigationService: Building SplashScreen');
          return const SplashScreen();
        },
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
                builder: (context, state) => AddContactScreen(
                  prefilledPhone: state.extra as String?,
                ),
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
            builder: (context, state) => const SettingsMainScreen(),
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
  static void goToAddContact({String? prefilledPhone}) => 
      router.go('/contacts/add', extra: prefilledPhone);
  static void goToEditContact(ContactModel contact) =>
      router.go('/contacts/edit', extra: contact);
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

  static void goToInCall(String callId,
      {String? phoneNumber, String? contactName}) {
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
    debugPrint(
        '🔄 CallsSettings: _loadExtensionSettings called with showLoading: $showLoading');
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

      final url = '/extension/${extensionDetails.id}';
      debugPrint('🌐 CallsSettings: Making GET request to: $url');

      final response = await ApiService.instance.getAuthenticated(
        url,
      );

      if (response == null) {
        debugPrint(
            '❌ CallsSettings: Authentication failed - redirected to login');
        return;
      }

      debugPrint(
          '📥 CallsSettings: GET response - Status: ${response.statusCode}');
      debugPrint('📥 CallsSettings: GET response - Data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final clirValue = data['clir'] ?? false;
        final recordValue = data['record'] ?? false;

        debugPrint(
            '📊 CallsSettings: Server data - clir: $clirValue, record: $recordValue');

        if (mounted) {
          final oldShowCallerID = _showCallerID;
          final oldEnableRecording = _enableRecording;

          setState(() {
            // CLIR logic: false means show caller ID, true means hide caller ID
            _showCallerID = !clirValue;
            _enableRecording = recordValue;
          });

          debugPrint(
              '🔄 CallsSettings: State updated - showCallerID: $oldShowCallerID -> $_showCallerID');
          debugPrint(
              '🔄 CallsSettings: State updated - enableRecording: $oldEnableRecording -> $_enableRecording');
        }
        debugPrint('✅ CallsSettings: Settings loaded successfully');
      } else {
        debugPrint(
            '❌ CallsSettings: Invalid response - Status: ${response.statusCode}, Data: ${response.data}');
      }
    } catch (e) {
      debugPrint('CallsSettings: Error loading extension settings: $e');
      if (mounted && e is DioException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to load call settings: ${e.response?.data ?? e.message}'),
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
    debugPrint(
        '🔄 CallsSettings: _updateCallerIDSetting called with value: $value');

    if (!mounted || _isUpdating) {
      debugPrint(
          '❌ CallsSettings: Cannot update - mounted: $mounted, _isUpdating: $_isUpdating');
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

      if (extensionDetails == null) {
        throw Exception('Extension details required');
      }

      // CLIR logic: UI value true (show caller ID) = API clir: false
      final clirValue = !value;
      debugPrint(
          '📊 CallsSettings: UI value: $value -> API clir value: $clirValue');

      final url = '/extension/${extensionDetails.id}';
      final payload = {'clir': clirValue};
      debugPrint('🌐 CallsSettings: Making PATCH request to: $url');
      debugPrint('📤 CallsSettings: PATCH payload: $payload');

      final response = await ApiService.instance.patchAuthenticated(
        url,
        data: payload,
      );

      if (response == null) {
        debugPrint(
            '❌ CallsSettings: Authentication failed - redirected to login');
        return;
      }

      debugPrint(
          '📥 CallsSettings: PATCH response - Status: ${response.statusCode}');
      debugPrint('📥 CallsSettings: PATCH response - Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        updateSuccessful = true;
        debugPrint(
            '✅ CallsSettings: Caller ID setting updated successfully (Status: ${response.statusCode})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Caller ID setting ${value ? 'enabled' : 'disabled'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint(
            '❌ CallsSettings: PATCH failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ CallsSettings: Error updating caller ID setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update caller ID setting: ${e is DioException ? e.response?.data ?? e.message : e.toString()}'),
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
          debugPrint(
              '🔄 CallsSettings: Calling _loadExtensionSettings for refresh...');
          await _loadExtensionSettings(showLoading: false);
          debugPrint('✅ CallsSettings: Refresh completed');
        } else {
          debugPrint('⚠️ CallsSettings: Skipping refresh due to failed update');
        }
      }
    }
  }

  Future<void> _updateRecordingSetting(bool value) async {
    debugPrint(
        '🔄 CallsSettings: _updateRecordingSetting called with value: $value');

    if (!mounted || _isUpdating) {
      debugPrint(
          '❌ CallsSettings: Cannot update - mounted: $mounted, _isUpdating: $_isUpdating');
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

      if (extensionDetails == null) {
        throw Exception('Extension details required');
      }

      final url = '/extension/${extensionDetails.id}';
      final payload = {'record': value};
      debugPrint('🌐 CallsSettings: Making PATCH request to: $url');
      debugPrint('📤 CallsSettings: PATCH payload: $payload');

      final response = await ApiService.instance.patchAuthenticated(
        url,
        data: payload,
      );

      if (response == null) {
        debugPrint(
            '❌ CallsSettings: Authentication failed - redirected to login');
        return;
      }

      debugPrint(
          '📥 CallsSettings: PATCH response - Status: ${response.statusCode}');
      debugPrint('📥 CallsSettings: PATCH response - Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        updateSuccessful = true;
        debugPrint(
            '✅ CallsSettings: Recording setting updated successfully (Status: ${response.statusCode})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call recording ${value ? 'enabled' : 'disabled'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint(
            '❌ CallsSettings: PATCH failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ CallsSettings: Error updating recording setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update recording setting: ${e is DioException ? e.response?.data ?? e.message : e.toString()}'),
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
          debugPrint(
              '🔄 CallsSettings: Calling _loadExtensionSettings for refresh...');
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveThumbColor: Theme.of(context).colorScheme.onSurfaceVariant,
            inactiveTrackColor: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
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
                              subtitle:
                                  'Display your phone number to recipients when making calls',
                              value: _showCallerID,
                              onChanged:
                                  _isUpdating ? null : _updateCallerIDSetting,
                            ),
                            _buildToggleItem(
                              title: 'Enable Recording',
                              subtitle:
                                  'Automatically record incoming and outgoing calls',
                              value: _enableRecording,
                              onChanged:
                                  _isUpdating ? null : _updateRecordingSetting,
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
      _isDeviceContactsEnabled =
          ContactsService.instance.isDeviceContactsEnabled;
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
            content: Text(
                'Error ${value ? 'enabling' : 'disabling'} device contacts: $e'),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveThumbColor: Theme.of(context).colorScheme.onSurfaceVariant,
            inactiveTrackColor: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
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
                              onChanged:
                                  _isUpdating ? null : _toggleDeviceContacts,
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
