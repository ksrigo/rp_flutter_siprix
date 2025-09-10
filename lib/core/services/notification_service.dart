import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
// import 'package:firebase_messaging/firebase_messaging.dart'; // Temporarily disabled
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// import 'package:flutter_voip_kit/flutter_voip_kit.dart'; // Temporarily disabled

// import '../constants/app_constants.dart'; // Temporarily disabled with Firebase
// import 'navigation_service.dart'; // Temporarily disabled with Firebase

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  // FirebaseMessaging? _firebaseMessaging; // Temporarily disabled
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

  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        debugPrint('Running on web - notifications not supported');
      } else {
        // Only try to access Platform on mobile
        try {
          if (Platform.isAndroid) {
            // await _initializeFirebaseMessaging(); // Temporarily disabled
            debugPrint('Firebase messaging temporarily disabled');
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

  /* Future<void> _initializeFirebaseMessaging() async { // Temporarily disabled Firebase
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request permission
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
        debugPrint('User granted permission for notifications');
      } else {
        debugPrint('User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('FCM Token refreshed: $token');
        // TODO: Send updated token to server
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Subscribe to topics
      await _firebaseMessaging!.subscribeToTopic(AppConstants.fcmTopicCalls);
      await _firebaseMessaging!.subscribeToTopic(AppConstants.fcmTopicVoicemail);

    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  } */ // End Firebase disabled section

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
      // Listen for CallKit events
      FlutterCallkitIncoming.onEvent.listen((event) {
        _handleCallKitEvent(event);
      });

    } catch (e) {
      debugPrint('Error initializing CallKit: $e');
    }
  }

  /* Future<void> _handleForegroundMessage(RemoteMessage message) async { // Disabled Firebase
    debugPrint('Foreground message received: ${message.data}');
    
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      await _handleIncomingCallNotification(data);
    } else if (data['type'] == 'voicemail') {
      await _handleVoicemailNotification(data);
    }
    
    _notificationController.add(data);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message received: ${message.data}');
    
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      await NotificationService.instance._handleIncomingCallNotification(data);
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Notification tapped: ${message.data}');
    
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      final callId = data['call_id'];
      if (callId != null) {
        NavigationService.goToIncomingCall(
          callId: callId,
          callerName: data['caller_name'] ?? 'Unknown',
          callerNumber: data['caller_number'] ?? 'Unknown',
        );
      }
    } else if (data['type'] == 'voicemail') {
      NavigationService.goToVoicemail();
    }
  }

  Future<void> _handleVoipPush(Map<String, dynamic> data) async {
    if (data['type'] == 'incoming_call') {
      await _handleIncomingCallNotification(data);
    }
  }


  Future<void> _handleVoicemailNotification(Map<String, dynamic> data) async {
    // Handle voicemail notification
    debugPrint('Voicemail notification: $data');
  }

  } */ // End Firebase disabled section

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
      await FlutterCallkitIncoming.endCall(callId);
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

  void dispose() {
    _notificationController.close();
    _incomingCallController.close();
  }
}

