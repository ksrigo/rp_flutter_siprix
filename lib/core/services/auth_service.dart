import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../../shared/services/storage_service.dart';
import '../models/extension_details.dart';
import 'sip_service.dart';
import 'navigation_service.dart';

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
      debugPrint('Auth: Initializing authentication service...');
      await _loadTokensFromStorage();
      debugPrint('Auth: Tokens loaded from storage - accessToken: ${_accessToken != null ? 'present' : 'null'}, refreshToken: ${_refreshToken != null ? 'present' : 'null'}');
      
      if (_isTokenValid()) {
        _isAuthenticated = true;
        debugPrint('Auth: Token is valid, user authenticated');
        notifyListeners();
        
        // Fetch extension details if we don't have them
        if (_extensionDetails == null) {
          debugPrint('Auth: Valid token found but no extension details, fetching...');
          await _fetchExtensionDetailsAndInitializeSIP();
        }
      } else {
        _isAuthenticated = false;
        debugPrint('Auth: Token is invalid or expired, user not authenticated');
      }
      debugPrint('Auth: Authentication service initialization completed');
    } catch (e) {
      debugPrint('Auth: Error initializing auth service: $e');
      _isAuthenticated = false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final formData = FormData.fromMap({
        'username': email,
        'password': password,
      });

      debugPrint('Auth: Sending signin request with FormData');
      debugPrint('Auth: Content-Type will be: ${Headers.formUrlEncodedContentType}');
      debugPrint('Auth: Data: username=$email&password=***');

      final response = await _dio.post(
        '$_baseUrl/signin',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            // Explicitly exclude Authorization header for signin
            'Authorization': null,
          },
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
    // If no access token, check if we have refresh token to attempt login recovery
    if (_accessToken == null) {
      debugPrint('Auth: No access token available');
      
      if (_refreshToken != null) {
        debugPrint('Auth: No access token but refresh token exists, attempting token refresh');
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          debugPrint('Auth: Successfully recovered access token using refresh token');
          _isAuthenticated = true;
          notifyListeners();
          
          // Fetch extension details if we don't have them
          if (_extensionDetails == null) {
            await _fetchExtensionDetailsAndInitializeSIP();
          }
          
          return _accessToken;
        } else {
          debugPrint('Auth: Failed to recover access token, redirecting to login');
          await handleAuthenticationFailure();
          return null;
        }
      } else {
        debugPrint('Auth: No tokens available, user needs to login');
        return null;
      }
    }

    // Check if current access token is valid
    if (!_isTokenValid()) {
      debugPrint('Auth: Access token is expired or expiring soon, attempting refresh');
      debugPrint('Auth: Current token expiry: $_tokenExpiresAt');
      debugPrint('Auth: Current time: ${DateTime.now()}');
      
      if (_refreshToken != null) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          debugPrint('Auth: Token refresh failed (response code != 200), redirecting to login');
          await handleAuthenticationFailure();
          return null;
        }
        debugPrint('Auth: Token successfully refreshed');
        _isAuthenticated = true;
        notifyListeners();
        
        // Fetch extension details if we don't have them
        if (_extensionDetails == null) {
          await _fetchExtensionDetailsAndInitializeSIP();
        }
      } else {
        debugPrint('Auth: No refresh token available, redirecting to login');
        await handleAuthenticationFailure();
        return null;
      }
    } else {
      debugPrint('Auth: Access token is still valid');
    }
    
    return _accessToken;
  }

  /// Handle authentication failure by clearing tokens and redirecting to login
  Future<void> handleAuthenticationFailure() async {
    try {
      debugPrint('Auth: Handling authentication failure - clearing tokens and redirecting to login');
      
      // Clear all authentication state
      _accessToken = null;
      _refreshToken = null;
      _tokenExpiresAt = null;
      _extensionDetails = null;
      _isAuthenticated = false;
      
      // Clear stored tokens
      await StorageService.instance.clearTokens();
      await StorageService.instance.clearCredentials();
      
      // Notify listeners of state change
      notifyListeners();
      
      // Redirect to login page
      NavigationService.goToLogin();
      
      debugPrint('Auth: Successfully cleared authentication state and redirected to login');
    } catch (e) {
      debugPrint('Auth: Error handling authentication failure: $e');
      // Even if there's an error, still try to redirect to login
      try {
        NavigationService.goToLogin();
      } catch (navError) {
        debugPrint('Auth: Error redirecting to login: $navError');
      }
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      // Create a dedicated Dio instance for token refresh to avoid circular dependency
      final refreshDio = Dio();
      refreshDio.options.baseUrl = _baseUrl;
      refreshDio.options.connectTimeout = const Duration(seconds: 30);
      refreshDio.options.receiveTimeout = const Duration(seconds: 30);
      refreshDio.options.sendTimeout = const Duration(seconds: 30);

      // Use JSON body as specified, not FormData
      final requestData = {
        'refresh_token': _refreshToken!,
      };

      debugPrint('Auth: Refreshing token with refresh_token: ${_refreshToken!.substring(0, 20)}...');
      debugPrint('Auth: Making PUT request to: $_baseUrl/refresh');

      final response = await refreshDio.put(
        '/refresh',
        data: requestData,
        options: Options(
          contentType: 'application/json',
          headers: {
            // Explicitly exclude Authorization header for refresh
            'Authorization': null,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('Auth: Token refresh successful, response received');
        
        _accessToken = data['access_token'];
        debugPrint('Auth: New access token received: ${_accessToken!.substring(0, 20)}...');

        // Update refresh token if provided
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
          debugPrint('Auth: New refresh token received: ${_refreshToken!.substring(0, 20)}...');
        }

        _updateTokenExpiry(_accessToken!);
        await _saveTokensToStorage();

        debugPrint('Auth: Token refresh completed successfully, new expiry: $_tokenExpiresAt');
        return true;
      } else {
        debugPrint('Auth: Token refresh failed with status code: ${response.statusCode}');
        debugPrint('Auth: Response data: ${response.data}');
      }
    } catch (e) {
      debugPrint('Auth: Token refresh error: $e');
      if (e is DioException) {
        debugPrint('Auth: Token refresh - Status code: ${e.response?.statusCode}');
        debugPrint('Auth: Token refresh - Response data: ${e.response?.data}');
        debugPrint('Auth: Token refresh - Error type: ${e.type}');
        debugPrint('Auth: Token refresh - Error message: ${e.message}');
      }
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
        debugPrint('Auth: JWT decoded successfully, expires at: $_tokenExpiresAt');
        debugPrint('Auth: Token valid for: ${_tokenExpiresAt!.difference(DateTime.now())}');
      } else {
        debugPrint('Auth: No expiry found in JWT payload, using fallback');
        _tokenExpiresAt = DateTime.now().add(const Duration(hours: 1));
      }
    } catch (e) {
      debugPrint('Auth: Error decoding JWT: $e');
      debugPrint('Auth: Using fallback expiry time (1 hour from now)');
      // Fallback: assume token expires in 1 hour
      _tokenExpiresAt = DateTime.now().add(const Duration(hours: 1));
    }
  }

  bool _isTokenValid() {
    if (_accessToken == null || _tokenExpiresAt == null) return false;

    // Check if now < token_expires_at - 60*1000 (1 min before expiry)
    final now = DateTime.now();
    final tokenExpiresAtMillis = _tokenExpiresAt!.millisecondsSinceEpoch;
    final nowMillis = now.millisecondsSinceEpoch;
    const oneMinuteInMillis = 60 * 1000;

    return nowMillis < (tokenExpiresAtMillis - oneMinuteInMillis);
  }

  Future<void> _loadTokensFromStorage() async {
    debugPrint('Auth: Loading tokens from storage...');
    final storage = StorageService.instance;
    _accessToken = await storage.getAccessToken();
    _refreshToken = await storage.getRefreshToken();

    debugPrint('Auth: Loaded from storage - accessToken: ${_accessToken?.substring(0, 20) ?? 'null'}..., refreshToken: ${_refreshToken?.substring(0, 20) ?? 'null'}...');

    if (_accessToken != null) {
      _updateTokenExpiry(_accessToken!);
      debugPrint('Auth: Token expiry set to: $_tokenExpiresAt');
    } else {
      debugPrint('Auth: No access token found in storage');
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
      
      // Make direct API call to avoid circular dependency with API service interceptor
      final dio = Dio();
      dio.options.baseUrl = 'https://api.ringplus.co.uk/v1';
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);
      
      final response = await dio.get(
        '/extensions/mobile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      debugPrint('Auth: Extension details API response - Status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> extensions = response.data;
        if (extensions.isNotEmpty) {
          _extensionDetails = ExtensionDetails.fromJson(extensions.first);
          debugPrint(
              'Auth: Extension details loaded: ${_extensionDetails.toString()}');

          // Initialize SIP with extension details
          await _initializeSIPWithExtension();
        } else {
          debugPrint('Auth: Extension details response is empty');
        }
      } else {
        debugPrint('Auth: Extension details API failed - Status: ${response.statusCode}, Data: ${response.data}');
      }
    } catch (e) {
      debugPrint('Auth: Error fetching extension details: $e');
      if (e is DioException) {
        debugPrint('Auth: Extension details - Status code: ${e.response?.statusCode}');
        debugPrint('Auth: Extension details - Response data: ${e.response?.data}');
      }
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
