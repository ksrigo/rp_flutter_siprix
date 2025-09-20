import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'dart:async';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/navigation_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/contacts_service.dart';
import 'shared/services/storage_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    debugPrint('🚀 MAIN: Application starting...');
    print('🚀 MAIN: Application starting (print)...');
    
    // Register Firebase background message handler for Android push notifications
    if (Platform.isAndroid) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
    
    debugPrint('🚀 MAIN: About to initialize services...');
    // Initialize core services
    await _initializeServices();
    debugPrint('🚀 MAIN: Services initialized successfully');
    
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    debugPrint('🚀 Main: Starting app with runApp');
    runApp(
      const ProviderScope(
        child: RingplusApp(),
      ),
    );
    debugPrint('🚀 Main: runApp called successfully');
  } catch (e, stackTrace) {
    debugPrint('🚀 MAIN: FATAL ERROR: $e');
    debugPrint('🚀 MAIN: STACK TRACE: $stackTrace');
    print('🚀 MAIN: FATAL ERROR: $e');
    print('🚀 MAIN: STACK TRACE: $stackTrace');
  }
}

Future<void> _initializeServices() async {
  try {
    // Initialize storage service first (required by other services)
    debugPrint('🚀 MAIN: Initializing StorageService...');
    await StorageService.instance.initialize();
    debugPrint('🚀 MAIN: StorageService initialized');
    
    // Initialize API service before auth service (auth service needs API for extension details)
    debugPrint('🚀 MAIN: Initializing ApiService...');
    await ApiService.instance.initialize();
    debugPrint('🚀 MAIN: ApiService initialized');
    
    // Initialize authentication service
    debugPrint('🚀 MAIN: Initializing AuthService...');
    await AuthService.instance.initialize();
    debugPrint('🚀 MAIN: AuthService initialized');
    
    // Initialize notification service
    debugPrint('🚀 MAIN: Initializing NotificationService...');
    try {
      await NotificationService.instance.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('🚀 MAIN: NotificationService initialization timed out');
          throw TimeoutException('NotificationService initialization timed out', const Duration(seconds: 10));
        },
      );
      debugPrint('🚀 MAIN: NotificationService initialized');
    } catch (e) {
      debugPrint('🚀 MAIN: NotificationService initialization failed: $e');
      // Continue with app initialization even if notification service fails
    }
    
    // Initialize contacts service (cache only, no API call)
    debugPrint('🚀 MAIN: Initializing ContactsService...');
    try {
      await ContactsService.instance.initializeWithoutApiCall().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('🚀 MAIN: ContactsService initialization timed out');
          throw TimeoutException('ContactsService initialization timed out', const Duration(seconds: 10));
        },
      );
      debugPrint('🚀 MAIN: ContactsService initialized (cache only)');
    } catch (e) {
      debugPrint('🚀 MAIN: ContactsService initialization failed: $e');
      // Continue with app initialization even if contacts service fails
    }
    
    // SIP service will be initialized after successful authentication
    
  } catch (e, stackTrace) {
    debugPrint('🚀 MAIN: Error initializing services: $e');
    debugPrint('🚀 MAIN: Service initialization stack trace: $stackTrace');
    print('🚀 MAIN: Error initializing services: $e');
  }
}

class RingplusApp extends ConsumerWidget {
  const RingplusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🏗️ RingplusApp: Building MaterialApp.router');
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      
      // Localization
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConstants.supportedLocales,
      
      // Navigation
      routerConfig: (() {
        debugPrint('🧭 RingplusApp: Accessing NavigationService.router');
        return NavigationService.router;
      })(),
      
      // Builder for global configurations
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Firebase background message handler for Android push notifications
/// This function must be top-level (not inside a class) for Firebase to call it
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    debugPrint('🚀 Android: =================================');
    debugPrint('🚀 Android: BACKGROUND PUSH NOTIFICATION RECEIVED');
    debugPrint('🚀 Android: Message ID: ${message.messageId}');
    debugPrint('🚀 Android: From: ${message.from}');
    debugPrint('🚀 Android: Data: ${message.data}');
    debugPrint('🚀 Android: Type: ${message.data['type']}');
    debugPrint('🚀 Android: =================================');
    
    if (message.data['type'] == 'INCOMING_CALL' || message.data['type'] == 'incoming_call') {
      debugPrint('🚀 Android: ✅ Recognized as incoming call notification');
      // Call the notification service handler
      await NotificationService.wakeUpAndRegisterForIncomingCall(message.data);
    } else {
      debugPrint('🚀 Android: ❌ Ignoring push notification with type: ${message.data['type']}');
    }
  } catch (e) {
    debugPrint('🚀 Android: ❌ ERROR in background message handler: $e');
    debugPrint('🚀 Android: Stack trace: ${StackTrace.current}');
  }
}

