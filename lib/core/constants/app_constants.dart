import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'Ringplus';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Multitenant PBX Softphone';
  
  // Supported Locales
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('fr', 'FR'), // French
  ];
  
  // API Configuration
  static const String defaultSipDomain = 'sip.ringplus.com';
  static const int defaultSipPort = 5060;
  static const String defaultStunServer = 'stun:stun.l.google.com:19302';
  
  // Storage Keys
  static const String keyUserCredentials = 'user_credentials';
  static const String keyAppSettings = 'app_settings';
  static const String keyCallHistory = 'call_history';
  static const String keyContacts = 'contacts';
  static const String keyVoicemails = 'voicemails';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  
  // Call Configuration
  static const Duration callTimeout = Duration(seconds: 30);
  static const Duration ringTimeout = Duration(seconds: 45);
  static const int maxCallHistoryEntries = 1000;
  static const int maxVoicemailEntries = 100;
  
  // UI Configuration
  static const double bottomNavHeight = 80.0;
  static const double appBarHeight = 56.0;
  static const double keypadButtonSize = 72.0;
  static const double minTouchTarget = 44.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Network Configuration
  static const Duration networkTimeout = Duration(seconds: 10);
  static const int maxRetryAttempts = 3;
  
  // Audio Configuration
  static const List<String> supportedAudioCodecs = [
    'PCMU',
    'PCMA',
    'G722',
    'opus',
  ];
  
  // Push Notification Configuration
  static const String fcmTopicCalls = 'calls';
  static const String fcmTopicVoicemail = 'voicemail';
  
  // Privacy Policy
  static const String privacyPolicyUrl = 'https://ringplus.com/privacy';
  static const String termsOfServiceUrl = 'https://ringplus.com/terms';
  static const String supportUrl = 'https://ringplus.com/support';
  
  // File Paths
  static const String assetsPath = 'assets';
  static const String imagesPath = '$assetsPath/images';
  static const String iconsPath = '$assetsPath/icons';
  static const String soundsPath = '$assetsPath/sounds';
  
  // Sound Files
  static const String ringtonePath = '$soundsPath/ringtone.mp3';
  static const String dialtonePath = '$soundsPath/dialtone.mp3';
  static const String busytonePath = '$soundsPath/busytone.mp3';
  static const String dtmfPath = '$soundsPath/dtmf';
  
  // Regular Expressions
  static final RegExp phoneNumberRegex = RegExp(r'^[\+]?[0-9\-\(\)\s]+$');
  static final RegExp sipUriRegex = RegExp(r'^sip:[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  
  // Error Messages
  static const String errorNetworkUnavailable = 'Network unavailable';
  static const String errorInvalidCredentials = 'Invalid credentials';
  static const String errorCallFailed = 'Call failed';
  static const String errorRegistrationFailed = 'Registration failed';
  
  // Feature Flags
  static const bool enableCallRecording = false;
  static const bool enableVideoCall = false;
  static const bool enableConferenceCall = true;
  static const bool enableCallTransfer = true;
  
  // Accessibility
  static const double minTextSize = 12.0;
  static const double maxTextSize = 24.0;
  static const double defaultTextSize = 16.0;
}

