import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      await Firebase.initializeApp();
      
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request permission for Android 13+
      final settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Android: User granted permission for notifications');
      } else {
        debugPrint('Android: User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('Android: FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('Android: FCM Token refreshed: $token');
        // Update SIP registration with new token
        _updateSipRegistrationWithToken(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps (app opened from background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('Android: Firebase messaging configured successfully');

    } catch (e) {
      debugPrint('Android: Error initializing Firebase Messaging: $e');
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
    if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
      await _handleIncomingCallNotification(data);
    } else if (data['type'] == 'voicemail') {
      await _handleVoicemailNotification(data);
    }
    
    _notificationController.add(data);
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Android: Background FCM message received: ${message.data}');
    
    final data = message.data;
    if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
      // Wake up the app and trigger SIP registration to receive the call
      await wakeUpAndRegisterForIncomingCall(data);
    }
  }

  @pragma('vm:entry-point')
  static Future<void> wakeUpAndRegisterForIncomingCall(Map<String, dynamic> data) async {
    try {
      debugPrint('🔥 Android: STARTING wake-up process for incoming call push notification');
      debugPrint('🔥 Android: Push data: $data');
      debugPrint('🔥 Android: Caller: ${data['caller_name']} (${data['caller_uri']})');
      debugPrint('🔥 Android: Callee: ${data['callee_uri']}');
      
      // Initialize core services required by SIP service
      debugPrint('🔥 Android: Initializing storage service...');
      await StorageService.instance.initialize();
      debugPrint('🔥 Android: Storage service initialized');
      
      // Initialize notification service 
      debugPrint('🔥 Android: Initializing notification service...');
      await NotificationService.instance.initialize();
      debugPrint('🔥 Android: Notification service initialized');
      
      // Initialize SIP service if not already done
      debugPrint('🔥 Android: Initializing SIP service...');
      final sipService = SipService.instance;
      
      try {
        await sipService.initialize();
        debugPrint('🔥 Android: SIP service initialized, isRegistered: ${sipService.isRegistered}');
      } catch (e) {
        debugPrint('🔥 Android: SIP service initialization failed: $e');
        debugPrint('🔥 Android: Will try background re-registration anyway...');
      }
      
      // ALWAYS force re-registration on push notification to ensure fresh REGISTER is sent
      debugPrint('🔥 Android: 🎯 FORCING background re-registration on push notification (ignoring current status)');
      
      try {
        debugPrint('🔥 Android: Attempting background re-registration...');
        final success = await sipService.attemptBackgroundReregistration();
        
        if (success) {
          debugPrint('🔥 Android: ✅ SIP registration successful from background wake-up');
        } else {
          debugPrint('🔥 Android: ❌ SIP registration failed from background wake-up');
        }
        
        // Wait a bit for registration to complete
        debugPrint('🔥 Android: Waiting 3 seconds for registration to complete...');
        await Future.delayed(const Duration(seconds: 3));
        
        try {
          if (sipService.isRegistered) {
            debugPrint('🔥 Android: ✅ SIP successfully registered, ready for incoming call');
          } else {
            debugPrint('🔥 Android: ⚠️ Warning - SIP registration may still be in progress');
          }
        } catch (e) {
          debugPrint('🔥 Android: Could not check final registration status: $e');
        }
      } catch (e) {
        debugPrint('🔥 Android: ❌ Failed to register SIP from background: $e');
      }
      
      debugPrint('🔥 Android: 🎯 App wake-up complete, waiting for incoming SIP call');
    } catch (e) {
      debugPrint('Android: Error waking up app for incoming call: $e');
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Android: Notification tapped: ${message.data}');
    
    final data = message.data;
    if (data['type'] == 'INCOMING_CALL' || data['type'] == 'incoming_call') {
      final callId = data['call_id'];
      final callerName = data['caller_name'] ?? 'Unknown';
      final callerNumber = data['caller_number'] ?? 'Unknown';
      
      if (callId != null) {
        // Navigate to incoming call screen
        NavigationService.goToIncomingCall(
          callId: callId,
          callerName: callerName,
          callerNumber: callerNumber,
        );
      } else {
        // If no call ID, just open the app to the main screen
        NavigationService.goToKeypad();
      }
    } else if (data['type'] == 'voicemail') {
      NavigationService.goToVoicemail();
    }
  }

  Future<void> _handleIncomingCallNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('Android: Handling incoming call notification: $data');
      
      final callerName = data['caller_name'] ?? 'Unknown';
      final callerNumber = data['caller_number'] ?? 'Unknown';
      final callId = data['call_id'];
      
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

