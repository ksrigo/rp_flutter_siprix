import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../../shared/services/storage_service.dart';
import '../models/extension_details.dart';
import 'api_service.dart';
import 'sip_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  AuthService._internal();

  final Dio _dio = Dio();
  static const String _baseUrl = 'https://api.ringplus.co.uk/v1';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiresAt;
  bool _isAuthenticated = false;
  ExtensionDetails? _extensionDetails;

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  ExtensionDetails? get extensionDetails => _extensionDetails;

  Future<void> initialize() async {
    try {
      await _loadTokensFromStorage();
      if (_isTokenValid()) {
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error initializing auth service: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final formData = FormData.fromMap({
        'username': email,
        'password': password,
      });

      debugPrint('Auth: Sending signin request with FormData');
      debugPrint(
          'Auth: Content-Type will be: ${Headers.formUrlEncodedContentType}');
      debugPrint('Auth: Data: username=$email&password=***');

      final response = await _dio.post(
        '$_baseUrl/signin',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // Decode JWT to get expiry time
        _updateTokenExpiry(_accessToken!);

        // Save tokens to storage
        await _saveTokensToStorage();

        _isAuthenticated = true;

        // Fetch extension details and initialize SIP
        await _fetchExtensionDetailsAndInitializeSIP();

        notifyListeners();

        return true;
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (e is DioException) {
        debugPrint('Status code: ${e.response?.statusCode}');
        debugPrint('Response data: ${e.response?.data}');
      }
    }

    return false;
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiresAt = null;
    _extensionDetails = null;
    _isAuthenticated = false;

    await StorageService.instance.clearTokens();
    notifyListeners();
  }

  Future<String?> getValidAccessToken() async {
    if (!_isTokenValid()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        await signOut();
        return null;
      }
    }
    return _accessToken;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final formData = FormData.fromMap({
        'refresh_token': _refreshToken!,
      });

      final response = await _dio.put(
        '$_baseUrl/refresh',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];

        // Update refresh token if provided
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }

        _updateTokenExpiry(_accessToken!);
        await _saveTokensToStorage();

        debugPrint('Access token refreshed successfully');
        return true;
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
    }

    return false;
  }

  void _updateTokenExpiry(String accessToken) {
    try {
      // Decode JWT without verification to get expiry
      final jwt = JWT.decode(accessToken);
      final exp = jwt.payload['exp'];
      if (exp != null) {
        _tokenExpiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
    } catch (e) {
      debugPrint('Error decoding JWT: $e');
      // Fallback: assume token expires in 1 hour
      _tokenExpiresAt = DateTime.now().add(const Duration(hours: 1));
    }
  }

  bool _isTokenValid() {
    if (_accessToken == null || _tokenExpiresAt == null) return false;

    // Check if token expires in less than 1 minute
    final now = DateTime.now();
    final oneMinuteBeforeExpiry =
        _tokenExpiresAt!.subtract(const Duration(minutes: 1));

    return now.isBefore(oneMinuteBeforeExpiry);
  }

  Future<void> _loadTokensFromStorage() async {
    final storage = StorageService.instance;
    _accessToken = await storage.getAccessToken();
    _refreshToken = await storage.getRefreshToken();

    if (_accessToken != null) {
      _updateTokenExpiry(_accessToken!);
    }
  }

  Future<void> _saveTokensToStorage() async {
    final storage = StorageService.instance;
    if (_accessToken != null) {
      await storage.saveAccessToken(_accessToken!);
    }
    if (_refreshToken != null) {
      await storage.saveRefreshToken(_refreshToken!);
    }
    if (_tokenExpiresAt != null) {
      await storage.saveTokenExpiry(_tokenExpiresAt!);
    }
  }

  Future<void> _fetchExtensionDetailsAndInitializeSIP() async {
    try {
      debugPrint('Auth: Fetching extension details...');
      final response = await ApiService.instance.getExtensionDetails();

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> extensions = response.data;
        if (extensions.isNotEmpty) {
          _extensionDetails = ExtensionDetails.fromJson(extensions.first);
          debugPrint(
              'Auth: Extension details loaded: ${_extensionDetails.toString()}');

          // Initialize SIP with extension details
          await _initializeSIPWithExtension();
        }
      }
    } catch (e) {
      debugPrint('Auth: Error fetching extension details: $e');
    }
  }

  Future<void> _initializeSIPWithExtension() async {
    if (_extensionDetails == null) {
      debugPrint('Auth: No extension details available for SIP initialization');
      return;
    }

    try {
      debugPrint('Auth: Initializing SIP service...');
      debugPrint(
          'Auth: Extension details - Name: ${_extensionDetails!.name}, Extension: ${_extensionDetails!.extension}, Domain: ${_extensionDetails!.domain}, Proxy: ${_extensionDetails!.proxy}');

      await SipService.instance.initialize();
      debugPrint('Auth: SIP service initialization completed');

      // Check if SIP is already registered from stored credentials (auto-registration)
      if (SipService.instance.isRegistered) {
        debugPrint(
            'Auth: SIP already registered from stored credentials, skipping manual registration');
        return;
      }

      // Only register if not already registered (for fresh logins)
      debugPrint('Auth: SIP not registered, attempting manual registration...');
      final success = await SipService.instance.register(
          name: _extensionDetails!.name,
          extension: _extensionDetails!.extension.toString(),
          password: _extensionDetails!.password,
          domain: _extensionDetails!.domain,
          proxy: _extensionDetails!.proxy,
          port: _extensionDetails!.port);

      if (success) {
        debugPrint('Auth: SIP registration successful');
      } else {
        debugPrint('Auth: SIP registration failed');
      }
    } catch (e) {
      debugPrint('Auth: Error initializing SIP: $e');
      // Don't rethrow to avoid breaking the authentication flow
    }
  }

  // Method to initialize SIP for authenticated users (called from splash screen)
  Future<void> initializeSIPIfAuthenticated() async {
    if (_isAuthenticated && _extensionDetails == null) {
      await _fetchExtensionDetailsAndInitializeSIP();
    } else if (_isAuthenticated && _extensionDetails != null) {
      // Extension details already loaded, just initialize SIP
      await _initializeSIPWithExtension();
    }
  }

  // Logout method to clear all authentication data
  Future<void> logout() async {
    try {
      debugPrint('Auth: Starting logout process...');

      // Clear authentication state
      _isAuthenticated = false;
      _extensionDetails = null;

      // Clear all stored data
      await StorageService.instance.clearCredentials();
      await StorageService.instance.clearTokens();
      await StorageService.instance.clearCallHistory();

      // Notify listeners
      notifyListeners();

      debugPrint('Auth: Logout completed successfully');
    } catch (e) {
      debugPrint('Auth: Error during logout: $e');
      rethrow;
    }
  }
}
