import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';
import '../../features/call/presentation/screens/in_call_screen.dart';
import '../../features/dialpad/presentation/screens/dialpad_screen.dart';
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
            builder: (context, state) => const ContactsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-contact',
                builder: (context, state) => const AddContactScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'edit-contact',
                builder: (context, state) {
                  final contactId = state.pathParameters['id']!;
                  return EditContactScreen(contactId: contactId);
                },
              ),
              GoRoute(
                path: 'details/:id',
                name: 'contact-details',
                builder: (context, state) {
                  final contactId = state.pathParameters['id']!;
                  return ContactDetailsScreen(contactId: contactId);
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
                path: 'call-options',
                name: 'call-options',
                builder: (context, state) => const CallOptionsScreen(),
              ),
              GoRoute(
                path: 'notifications',
                name: 'notification-settings',
                builder: (context, state) => const NotificationSettingsScreen(),
              ),
              GoRoute(
                path: 'audio-network',
                name: 'audio-network-settings',
                builder: (context, state) => const AudioNetworkSettingsScreen(),
              ),
              GoRoute(
                path: 'privacy-security',
                name: 'privacy-security-settings',
                builder: (context, state) =>
                    const PrivacySecuritySettingsScreen(),
              ),
              GoRoute(
                path: 'appearance',
                name: 'appearance-settings',
                builder: (context, state) => const AppearanceSettingsScreen(),
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
          return InCallScreen(callId: callId ?? '');
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

  static void goToInCall(String callId) {
    router.go('/in-call?callId=$callId');
  }

  static void goBack() {
    if (router.canPop()) {
      router.pop();
    }
  }

  static void goToContactDetails(String contactId) {
    router.go('/contacts/details/$contactId');
  }

  static void goToVoicemailDetails(String voicemailId) {
    router.go('/voicemail/details/$voicemailId');
  }
}

// Placeholder screens - these will be implemented in later phases

class RecentsScreen extends StatelessWidget {
  const RecentsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Recents')));
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Contacts')));
}

class AddContactScreen extends StatelessWidget {
  const AddContactScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Add Contact')));
}

class EditContactScreen extends StatelessWidget {
  final String contactId;
  const EditContactScreen({super.key, required this.contactId});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Edit Contact $contactId')));
}

class ContactDetailsScreen extends StatelessWidget {
  final String contactId;
  const ContactDetailsScreen({super.key, required this.contactId});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Contact Details $contactId')));
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              
              // Settings Items
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingsItem(
                      icon: Icons.account_circle_outlined,
                      title: 'Account Settings',
                      subtitle: 'Manage your account',
                      onTap: () => context.go('/settings/account'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.call_outlined,
                      title: 'Call Options',
                      subtitle: 'Configure call settings',
                      onTap: () => context.go('/settings/call-options'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Notification preferences',
                      onTap: () => context.go('/settings/notifications'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.network_check_outlined,
                      title: 'Audio & Network',
                      subtitle: 'Audio and network settings',
                      onTap: () => context.go('/settings/audio-network'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.security_outlined,
                      title: 'Privacy & Security',
                      subtitle: 'Privacy and security options',
                      onTap: () => context.go('/settings/privacy-security'),
                    ),
                    _buildSettingsItem(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Theme and appearance',
                      onTap: () => context.go('/settings/appearance'),
                    ),
                    
                    const SizedBox(height: 32),
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
            ],
          ),
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

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Account Settings')));
}

class CallOptionsScreen extends StatelessWidget {
  const CallOptionsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Call Options')));
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Notification Settings')));
}

class AudioNetworkSettingsScreen extends StatelessWidget {
  const AudioNetworkSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Audio Network Settings')));
}

class PrivacySecuritySettingsScreen extends StatelessWidget {
  const PrivacySecuritySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Privacy Security Settings')));
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Appearance Settings')));
}
