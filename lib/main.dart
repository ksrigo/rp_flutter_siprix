import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/navigation_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'shared/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services
  await _initializeServices();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    const ProviderScope(
      child: RingplusApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  try {
    // Initialize storage service first (required by other services)
    await StorageService.instance.initialize();
    
    // Initialize authentication service
    await AuthService.instance.initialize();
    
    // Initialize API service
    await ApiService.instance.initialize();
    
    // Initialize notification service
    await NotificationService.instance.initialize();
    
    // SIP service will be initialized after successful authentication
    
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
}

class RingplusApp extends ConsumerWidget {
  const RingplusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      routerConfig: NavigationService.router,
      
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

