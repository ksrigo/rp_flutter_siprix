import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; // Removed - using Siprix built-in CallKit
// import 'package:flutter_voip_kit/flutter_voip_kit.dart'; // Temporarily disabled

import 'navigation_service.dart';
import 'sip_service.dart';
import '../../shared/services/storage_service.dart';

@pragma('vm:entry-point')
class NotificationService {
  @pragma('vm:entry-point')
  static final NotificationService _instance = NotificationService._internal();
  @pragma('vm:entry-point')
  static NotificationService get instance => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  // FlutterVoipKit? _voipPushkit; // Temporarily disabled
  
  bool _isInitialized = false;
  String? _fcmToken;
  String? _voipToken;

  // Stream controllers for notification events
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _incomingCallController =
      StreamController<String>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;
  String? get voipToken => _voipToken;

  // Streams
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<String> get incomingCallStream => _incomingCallController.stream;

  @pragma('vm:entry-point')
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        debugPrint('Running on web - notifications not supported');
      } else {
        // Only try to access Platform on mobile
        try {
          if (Platform.isAndroid) {
            await _initializeFirebaseMessaging();
            debugPrint('Firebase messaging initialized for Android');
          } else if (Platform.isIOS) {
            await _initializeVoipPushkit();
            await _initializeCallKit();
          }
        } catch (e) {
          debugPrint('Platform detection failed: $e');
        }
      }
      
      _isInitialized = true;
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Initialize Firebase if not already done
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        debugPrint('Android: Firebase initialized in NotificationService');
      } else {
        debugPrint('Android: Firebase already initialized');
      }

      _firebaseMessaging = FirebaseMessaging.instance;

      // Request permission for Android 13+ (non-blocking)
      // Don't wait for user interaction - get token in background
      _requestPermissionAndGetToken();

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('Android: FCM Token refreshed: $token');
        // Update SIP registration with new token
        _updateSipRegistrationWithToken(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages - already registered in main.dart
      // FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps (app opened from background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state)
      // Note: This is also handled in main.dart for fast-start mode
      final initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Android: App opened from terminated state via notification');
        _handleNotificationTap(initialMessage);
      }

      debugPrint('Android: Firebase messaging configured successfully');

    } catch (e) {
      debugPrint('Android: Error initializing Firebase Messaging: $e');
    }
  }

  /// Get FCM token in background (non-blocking)
  /// Permission is already requested in main.dart, so just check status and get token
  Future<void> _requestPermissionAndGetToken() async {
    try {
      // Check current notification settings instead of requesting again
      // (permission is already being requested in main.dart's _getEarlyFcmToken)
      debugPrint('Android: Checking notification permission status...');
      final settings = await _firebaseMessaging!.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('Android: Notification permission already granted');
        // Get FCM token
        debugPrint('Android: Getting FCM token...');
        _fcmToken = await _firebaseMessaging!.getToken();
        debugPrint('Android: FCM Token obtained: $_fcmToken');
      } else if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // Permission not yet determined - wait a bit for main.dart's request to complete
        debugPrint('Android: Permission not determined yet, waiting...');
        await Future.delayed(const Duration(seconds: 2));
        // Try to get token (permission should be granted by now)
        _fcmToken = await _firebaseMessaging!.getToken();
        debugPrint('Android: FCM Token obtained after wait: $_fcmToken');
      } else {
        debugPrint('Android: Notification permission denied');
      }
    } catch (e) {
      debugPrint('Android: Error getting FCM token: $e');
    }
  }

  Future<void> _initializeVoipPushkit() async {
    try {
      // final voipPushkit = FlutterVoipKit(); // Temporarily disabled
      // Configure VoIP pushkit
      // Note: Configuration will depend on the actual flutter_voip_kit API
      debugPrint('VoIP Pushkit temporarily disabled');

    } catch (e) {
      debugPrint('Error initializing VoIP Pushkit: $e');
    }
  }

  Future<void> _initializeCallKit() async {
    try {
      // CallKit disabled - using Siprix built-in CallKit instead
      debugPrint('CallKit initialization skipped - using Siprix built-in CallKit');

    } catch (e) {
      debugPrint('Error initializing CallKit: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Android: Foreground FCM message received: ${message.data}');
    
    final data = message.data;
    final action = data['action'];
    
    if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
      // Check if this is an action-based message (accept/reject from notification)
      if (action == 'accept' || action == 'reject') {
        debugPrint('Android: Foreground action-based message received: $action');
        // Handle the action the same way as notification tap
        await _handleNotificationTap(message);
      } else {
        // Regular incoming call notification
        await _handleIncomingCallNotification(data);
      }
    } else if (data['type'] == 'voicemail') {
      await _handleVoicemailNotification(data);
    }
    
    _notificationController.add(data);
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Android: Background FCM message received: ${message.data}');
    
    final data = message.data;
    final action = data['action'];
    
    if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
      if (action == 'accept' || action == 'reject') {
        debugPrint('Android: Background action-based message received: $action');
        // For action-based messages, we need to wake up and handle the action
        await wakeUpAndHandleCallAction(data);
      } else {
        // Regular incoming call - wake up the app and trigger SIP registration to receive the call
        await wakeUpAndRegisterForIncomingCall(data);
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<void> wakeUpAndRegisterForIncomingCall(Map<String, dynamic> data) async {
    // Use print() for critical logs - debugPrint may not work in background isolates
    print('🔥 Android: STARTING wake-up process for incoming call push notification');
    print('🔥 Android: Push data: $data');
    print('🔥 Android: Caller: ${data['caller_name']} (${data['caller_uri']})');
    print('🔥 Android: Callee: ${data['callee_uri']}');

    try {
      // CRITICAL: Ensure Flutter binding is initialized before anything else
      // This is required for Siprix SDK's InitData() to work in background
      print('🔥 Android: Ensuring Flutter binding is initialized...');
      WidgetsFlutterBinding.ensureInitialized();
      print('🔥 Android: Flutter binding initialized');

      // Load dotenv for SIPRIX_LICENCE access
      // Note: This may fail in background isolate if assets aren't accessible
      print('🔥 Android: Loading dotenv...');
      try {
        await dotenv.load(fileName: ".env");
        print('🔥 Android: dotenv loaded');
      } catch (e) {
        print('🔥 Android: dotenv load failed (expected in background): $e');
        // Continue without dotenv - license will be empty but SIP can still register
      }

      // Initialize core services required by SIP service
      print('🔥 Android: Initializing storage service...');
      await StorageService.instance.initialize();
      print('🔥 Android: Storage service initialized');

      // Initialize notification service
      print('🔥 Android: Initializing notification service...');
      await NotificationService.instance.initialize();
      print('🔥 Android: Notification service initialized');

      final success = await _ensureSipRegistrationForPush('Background push wake-up');
      if (success) {
        print('🔥 Android: ✅ SIP registration successful from background wake-up');
      } else {
        print('🔥 Android: ❌ SIP registration failed from background wake-up');
      }

      try {
        print('🔥 Android: Background wake-up final registration status: ${SipService.instance.isRegistered}');
      } catch (e) {
        print('🔥 Android: Could not verify final registration status: $e');
      }

      print('🔥 Android: 🎯 App wake-up complete, waiting for incoming SIP call');
    } catch (e, stackTrace) {
      print('🔥 Android: ❌ Error waking up app for incoming call: $e');
      print('🔥 Android: Stack trace: $stackTrace');
    }
  }


  @pragma('vm:entry-point')
  static Future<bool> _ensureSipRegistrationForPush(String contextLabel) async {
    try {
      final sipService = SipService.instance;

      print('🔥 Android: [$contextLabel] Ensuring SIP service is initialized');
      try {
        await sipService.initialize();
        print('🔥 Android: [$contextLabel] SIP service initialization complete');
      } catch (e) {
        print('🔥 Android: [$contextLabel] SIP service initialization issue: $e');
      }

      print('🔥 Android: [$contextLabel] Triggering SIP re-registration');
      final success = await sipService.attemptBackgroundReregistration();
      print('🔥 Android: [$contextLabel] Re-registration result: $success');
      return success;
    } catch (e) {
      print('🔥 Android: [$contextLabel] Error ensuring SIP registration: $e');
      return false;
    }
  }

  /// Wake up app and handle call action (accept/reject) from notification
  @pragma('vm:entry-point')
  static Future<void> wakeUpAndHandleCallAction(Map<String, dynamic> data) async {
    // Use print() for critical logs - debugPrint may not work in background isolates
    print('🔥 Android: STARTING wake-up process for call action from notification');
    print('🔥 Android: Action data: $data');

    final action = data['action'];
    final callId = data['call_id'];
    print('🔥 Android: Caller: ${data['caller_name']} (${data['caller_number']})');
    print('🔥 Android: Action: $action, CallId: $callId');

    try {
      // CRITICAL: Ensure Flutter binding is initialized before anything else
      // This is required for Siprix SDK's InitData() to work in background
      print('🔥 Android: Ensuring Flutter binding is initialized...');
      WidgetsFlutterBinding.ensureInitialized();
      print('🔥 Android: Flutter binding initialized');

      // Load dotenv for SIPRIX_LICENCE access
      // Note: This may fail in background isolate if assets aren't accessible
      print('🔥 Android: Loading dotenv...');
      try {
        await dotenv.load(fileName: ".env");
        print('🔥 Android: dotenv loaded');
      } catch (e) {
        print('🔥 Android: dotenv load failed (expected in background): $e');
        // Continue without dotenv - license will be empty but SIP can still register
      }

      // Initialize core services required by SIP service
      print('🔥 Android: Initializing services for call action...');
      await StorageService.instance.initialize();
      await NotificationService.instance.initialize();

      // Initialize SIP service
      final sipService = SipService.instance;
      try {
        await sipService.initialize();
        print('🔥 Android: SIP service initialized for call action');
      } catch (e) {
        print('🔥 Android: SIP service initialization failed: $e');
      }
      
      // Handle the specific action
      if (action == 'accept' && callId != null) {
        print('🔥 Android: Handling ACCEPT action for call: $callId');
        try {
          await sipService.answerCall(callId);
          print('🔥 Android: Call answered successfully from background notification');
        } catch (e) {
          print('🔥 Android: Error answering call from background: $e');
        }
      } else if (action == 'reject' && callId != null) {
        print('🔥 Android: Handling REJECT action for call: $callId');
        try {
          await sipService.hangupCall(callId);
          print('🔥 Android: Call rejected successfully from background notification');
        } catch (e) {
          print('🔥 Android: Error rejecting call from background: $e');
        }
      }

      print('🔥 Android: 🎯 Background call action handled');
    } catch (e, stackTrace) {
      print('🔥 Android: ❌ Error handling call action from background: $e');
      print('🔥 Android: Stack trace: $stackTrace');
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Android: Notification tapped: ${message.data}');

    final data = message.data;
    if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
      final callId = data['call_id'];
      final callerName = data['caller_name'] ?? 'Unknown';
      final callerNumber = data['caller_number'] ?? 'Unknown';
      final action = data['action']; // Check if user accepted/rejected from notification

      debugPrint('Android: Incoming call notification - CallId: $callId, Action: $action');

      if (callId != null) {
        // Check if user accepted the call from the notification
        if (action == 'accept') {
          debugPrint('Android: User accepted call from notification via deep link');
          debugPrint('Android: Deep link detected - will answer and navigate to in-call screen');

          // Answer the call and navigate directly to in-call screen
          try {
            await SipService.instance.initialize();
            await SipService.instance.answerCall(callId);
            debugPrint('Android: Call answered from deep link, navigating to in-call screen');

            // Navigate directly to in-call screen (bypass incoming_call_screen)
            NavigationService.goToInCall(
              callId,
              phoneNumber: callerNumber,
              contactName: callerName,
            );
          } catch (e) {
            debugPrint('Android: Error handling deep link accept: $e');
            // Set auto-answer as fallback
            SipService.instance.setAutoAnswerCall(callId, callerName, callerNumber);
          }
        } else if (action == 'reject') {
          debugPrint('Android: User rejected call from notification, hanging up call');
          await _handleNotificationReject(callId);
        } else {
          // User just tapped the notification without specific action
          debugPrint('Android: User tapped notification, showing incoming call screen');
          NavigationService.goToIncomingCall(
            callId: callId,
            callerName: callerName,
            callerNumber: callerNumber,
          );
        }
      } else {
        // If no call ID, just open the app to the main screen
        NavigationService.goToKeypad();
      }
    } else if (data['type'] == 'voicemail') {
      NavigationService.goToVoicemail();
    }
  }

  /// Handle accepting call directly from notification
  Future<void> _handleNotificationAccept(String callId, String callerName, String callerNumber) async {
    try {
      debugPrint('🔥 Android: Handling notification accept for callId: $callId');

      // Initialize SIP service if needed
      try {
        debugPrint('🔥 Android: Ensuring SIP service is initialized...');
        await SipService.instance.initialize();
      } catch (e) {
        debugPrint('🔥 Android: Error initializing SIP service: $e');
      }

      // Set flag for auto-answer when call arrives
      debugPrint('🔥 Android: Setting auto-answer flag for callId: $callId');
      SipService.instance.setAutoAnswerCall(callId, callerName, callerNumber);

      // Check if call already exists (arrived during app wake-up)
      final currentCall = SipService.instance.currentCall;
      if (currentCall != null && currentCall.id == callId) {
        debugPrint('🔥 Android: SIP call already arrived! State: ${currentCall.state}');

        if (currentCall.state == AppCallState.ringing) {
          debugPrint('🔥 Android: Call is ringing, answering now...');
          await SipService.instance.answerCall(callId);
          debugPrint('🔥 Android: Call answered, navigating to in-call screen');

          // Navigate directly to in-call screen
          NavigationService.goToInCall(
            callId,
            phoneNumber: callerNumber,
            contactName: callerName,
          );
          return;
        } else if (currentCall.state == AppCallState.answered) {
          debugPrint('🔥 Android: Call already answered, navigating to in-call screen');

          // Navigate directly to in-call screen
          NavigationService.goToInCall(
            callId,
            phoneNumber: callerNumber,
            contactName: callerName,
          );
          return;
        }
      }

      // Call hasn't arrived yet - auto-answer flag is set, so when it arrives
      // it will be auto-answered and incoming_call_screen will detect the
      // answered state and navigate to in_call_screen automatically
      debugPrint('🔥 Android: Call not arrived yet, auto-answer flag is set');
      debugPrint('🔥 Android: When call arrives, it will be auto-answered and screen will auto-navigate');

      debugPrint('🔥 Android: Notification accept handling completed');
    } catch (e) {
      debugPrint('🔥 Android: Error handling notification accept: $e');
      // If there's an error, the auto-answer flag is still set
      // so the call will be answered when it arrives
    }
  }

  /// Handle rejecting call directly from notification  
  Future<void> _handleNotificationReject(String callId) async {
    try {
      debugPrint('🔥 Android: Handling notification reject for callId: $callId');
      
      // Reject the call directly
      await SipService.instance.hangupCall(callId);
      debugPrint('🔥 Android: Call rejected successfully from notification');
      
      // Navigate to keypad screen
      NavigationService.goToKeypad();
    } catch (e) {
      debugPrint('🔥 Android: Error handling notification reject: $e');
      // Still navigate to keypad even if reject failed
      NavigationService.goToKeypad();
    }
  }

  Future<void> _handleIncomingCallNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('Android: Handling incoming call notification: $data');

      final callerName = data['caller_name'] ?? 'Unknown';
      final callerNumber = data['caller_number'] ?? 'Unknown';
      final callId = data['call_id'];

      // Kick off SIP registration refresh so the proxy sees the device as reachable
      unawaited(
        _ensureSipRegistrationForPush('Foreground incoming push').then((_) {}),
      );

      // Trigger the incoming call stream
      _incomingCallController.add(callId ?? callerNumber);

      debugPrint('Android: Incoming call notification processed for $callerName ($callerNumber)');
    } catch (e) {
      debugPrint('Android: Error handling incoming call notification: $e');
    }
  }

  Future<void> _handleVoicemailNotification(Map<String, dynamic> data) async {
    debugPrint('Android: Voicemail notification: $data');
    // TODO: Implement voicemail handling
  }

  void _updateSipRegistrationWithToken(String token) {
    try {
      // Update SIP registration with new FCM token
      final sipService = SipService.instance;
      if (sipService.isRegistered) {
        // The token will be included in the next registration refresh
        debugPrint('Android: FCM token updated, will be included in next SIP registration');
      }
    } catch (e) {
      debugPrint('Android: Error updating SIP registration with FCM token: $e');
    }
  }

  void _handleCallKitEvent(dynamic event) {
    debugPrint('CallKit event received');
    
    // Simplified event handling - the exact API will depend on the flutter_callkit_incoming version
    try {
      if (event != null && event.toString().contains('Accept')) {
        _incomingCallController.add('call_accepted');
      }
    } catch (e) {
      debugPrint('Error handling CallKit event: $e');
    }
  }

  // VoIP push handler for iOS - temporarily disabled
  // Future<void> _handleVoipPush(Map<String, dynamic> data) async {
  //   if (data['type'] == 'incoming_call') {
  //     await _handleIncomingCallNotification(data);
  //   }
  // }


  Future<void> showIncomingCallNotification({
    required String callId,
    required String callerName,
    required String callerNumber,
  }) async {
    try {
      // For now, we'll use a simple approach
      // The exact CallKit API will need to be implemented based on the package version
      debugPrint('Showing incoming call notification for $callerName ($callerNumber)');
      
      // TODO: Implement actual CallKit integration based on package version
    } catch (e) {
      debugPrint('Error showing incoming call notification: $e');
    }
  }

  Future<void> endIncomingCallNotification(String callId) async {
    try {
      // CallKit disabled - using Siprix built-in CallKit instead
      debugPrint('CallKit end call skipped - using Siprix built-in CallKit for call: $callId');
    } catch (e) {
      debugPrint('Error ending incoming call notification: $e');
    }
  }

  Future<void> updateCallNotification({
    required String callId,
    required String status,
  }) async {
    try {
      // Update call status in CallKit
      // This would typically be used to show call duration, hold status, etc.
    } catch (e) {
      debugPrint('Error updating call notification: $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      // Firebase messaging temporarily disabled
      debugPrint('Firebase messaging permissions temporarily disabled');
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      // Firebase messaging temporarily disabled
      debugPrint('Firebase messaging topic subscription temporarily disabled');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      // Firebase messaging temporarily disabled
      debugPrint('Firebase messaging topic unsubscription temporarily disabled');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Get current FCM token for Android push notifications
  String? getCurrentFCMToken() {
    if (Platform.isAndroid) {
      return _fcmToken;
    }
    return null;
  }

  /// Request fresh FCM token
  Future<String?> refreshFCMToken() async {
    if (Platform.isAndroid && _firebaseMessaging != null) {
      try {
        _fcmToken = await _firebaseMessaging!.getToken();
        debugPrint('Android: FCM token refreshed: $_fcmToken');
        return _fcmToken;
      } catch (e) {
        debugPrint('Android: Error refreshing FCM token: $e');
        return null;
      }
    }
    return null;
  }

  void dispose() {
    _notificationController.close();
    _incomingCallController.close();
  }
}
