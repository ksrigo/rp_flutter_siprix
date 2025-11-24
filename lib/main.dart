import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';
import 'dart:io';
import 'dart:async';

import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';
import 'package:siprix_voip_sdk/accounts_model.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/navigation_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/contacts_service.dart';
import 'core/models/app_calls_model.dart';
import 'shared/services/storage_service.dart';

// Global flag to track if we're in fast-start mode (launched from notification)
bool _isFastStartMode = false;

// Global references to early-initialized Siprix components (for iOS push handling)
// These are created in _initializeSiprixForPush() and reused by SipService
AppCallsModel? _globalCallsModel;
AccountsModel? _globalAccountsModel;
CdrsModel? _globalCdrsModel;

// Getter functions for SipService to access the early-initialized instances
AppCallsModel? getGlobalCallsModel() => _globalCallsModel;
AccountsModel? getGlobalAccountsModel() => _globalAccountsModel;

// Termination data storage
CdrsModel? getGlobalCdrsModel() => _globalCdrsModel;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    debugPrint('🚀 MAIN: Application starting...');

    // CRITICAL FOR iOS: Initialize Siprix SDK IMMEDIATELY to handle VoIP push
    // This must happen BEFORE runApp() so the CallStateListener is ready
    // when iOS delivers the pending push notification
    if (Platform.isIOS) {
      debugPrint('🚀 MAIN: iOS detected - initializing Siprix SDK for VoIP push handling');
      // Enhanced initialization for all states
      await _initializeSiprixForPush();
      debugPrint('🚀 MAIN: ✅ Siprix SDK early initialization complete for all states');
    }

    // Register Firebase background message handler for Android push notifications
    if (Platform.isAndroid) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Check if app was launched from notification (fast-start mode)
    if (Platform.isAndroid) {
      try {
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null &&
            (initialMessage.data['type'] == 'INCOMING_CALL' ||
                initialMessage.data['type'] == 'incoming_call') &&
            initialMessage.data['action'] == 'accept') {
          _isFastStartMode = true;
          debugPrint('🚀 MAIN: Fast-start mode enabled - launched from notification acceptance');
        }
      } catch (e) {
        debugPrint('🚀 MAIN: Error checking initial message: $e');
      }
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


/// Enhanced Siprix initialization for all states (killed/background/foreground)
Future<void> _initializeSiprixForPush() async {
  try {
    debugPrint('🚀 MAIN: Initializing Siprix SDK for VoIP push...');
    AppConstants.isMainCalled = true;

    final siprixSdk = SiprixVoipSdk();

    final initData = InitData();
    initData.license = "";
    initData.singleCallMode = false;
    initData.shareUdpTransport = true;
    initData.enableVideoCall = false;

    // CRITICAL: Enhanced VoIP settings for killed/locked state
    initData.enableCallKit = true;
    initData.enablePushKit = true;
    initData.unregOnDestroy = false;

    _globalAccountsModel = AccountsModel();
    debugPrint('🚀 MAIN: AccountsModel created');

    // Create CdrsModel to track call history
    _globalCdrsModel = CdrsModel(maxItems: 100);
    debugPrint('🚀 MAIN: CdrsModel created');
    print('🚀 MAIN: CdrsModel created (print)');

    // Set up CDR persistence - save changes to storage
    _globalCdrsModel!.onSaveChanges = (String jsonStr) async {
      debugPrint('🚀 MAIN: Saving CDR history to storage');
      await StorageService.instance.saveCdrCallHistory(jsonStr);
    };

    // Load CDRs from storage
    try {
      final savedCdrs = await StorageService.instance.getCdrCallHistory();
      if (savedCdrs != null && savedCdrs.isNotEmpty) {
        final loaded = _globalCdrsModel!.loadFromJson(savedCdrs);
        debugPrint('🚀 MAIN: Loaded ${_globalCdrsModel!.length} CDR entries from storage');
        print('🚀 MAIN: Loaded ${_globalCdrsModel!.length} CDR entries from storage (print)');
      } else {
        debugPrint('🚀 MAIN: No saved CDR history found');
        print('🚀 MAIN: No saved CDR history found (print)');
      }
    } catch (e) {
      debugPrint('🚀 MAIN: Error loading CDR history: $e');
      print('🚀 MAIN: Error loading CDR history: $e (print)');
    }

    // Create AppCallsModel - this sets up the CallStateListener
    _globalCallsModel = AppCallsModel(_globalAccountsModel!, null, _globalCdrsModel);
    debugPrint('🚀 MAIN: AppCallsModel created with CdrsModel - CallStateListener is now configured');
    print('🚀 MAIN: AppCallsModel created with CdrsModel - CallStateListener is now configured (print)');

    // Initialize SDK
    await siprixSdk.initialize(initData);

    debugPrint('🚀 MAIN: Siprix SDK initialized with VoIP enhancements');

    debugPrint('🚀 MAIN: ✅ Siprix SDK ready for VoIP push notifications');
  } catch (e, stackTrace) {
    debugPrint('🚀 MAIN: ❌ Failed to initialize Siprix SDK: $e');
  }
}

Future<void> _initializeServices() async {
  try {
    // Always initialize critical services first
    debugPrint('🚀 MAIN: Initializing StorageService...');
    await StorageService.instance.initialize();
    debugPrint('🚀 MAIN: StorageService initialized');

    debugPrint('🚀 MAIN: Initializing ApiService...');
    await ApiService.instance.initialize();
    debugPrint('🚀 MAIN: ApiService initialized');

    // Initialize notification service (needed for SIP registration)
    debugPrint('🚀 MAIN: Initializing NotificationService...');
    try {
      await NotificationService.instance.initialize().timeout(
        Duration(seconds: _isFastStartMode ? 3 : 10), // Shorter timeout in fast mode
        onTimeout: () {
          debugPrint('🚀 MAIN: NotificationService initialization timed out');
          throw TimeoutException('NotificationService initialization timed out');
        },
      );
      debugPrint('🚀 MAIN: NotificationService initialized');
    } catch (e) {
      debugPrint('🚀 MAIN: NotificationService initialization failed: $e');
    }

    // Initialize authentication service
    debugPrint('🚀 MAIN: Initializing AuthService...');
    await AuthService.instance.initialize();
    debugPrint('🚀 MAIN: AuthService initialized');

    // In fast-start mode, defer non-critical services to background
    if (_isFastStartMode) {
      debugPrint('🚀 MAIN: Fast-start mode - deferring ContactsService initialization');
      // Initialize contacts in background after app is shown
      Future.microtask(() async {
        debugPrint('🚀 MAIN: Background: Initializing ContactsService...');
        try {
          await ContactsService.instance.initializeWithoutApiCall();
          debugPrint('🚀 MAIN: Background: ContactsService initialized');
        } catch (e) {
          debugPrint('🚀 MAIN: Background: ContactsService initialization failed: $e');
        }
      });
    } else {
      // Normal mode - initialize contacts service synchronously
      debugPrint('🚀 MAIN: Initializing ContactsService...');
      try {
        await ContactsService.instance.initializeWithoutApiCall().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('🚀 MAIN: ContactsService initialization timed out');
            throw TimeoutException('ContactsService initialization timed out');
          },
        );
        debugPrint('🚀 MAIN: ContactsService initialized (cache only)');
      } catch (e) {
        debugPrint('🚀 MAIN: ContactsService initialization failed: $e');
      }
    }

    // SIP service will be initialized after successful authentication

  } catch (e, stackTrace) {
    debugPrint('🚀 MAIN: Error initializing services: $e');
    debugPrint('🚀 MAIN: Service initialization stack trace: $stackTrace');
    print('🚀 MAIN: Error initializing services: $e');
  }
}

class RingplusApp extends ConsumerWidget  {
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





