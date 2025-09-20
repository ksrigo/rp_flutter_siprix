import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;
  ApiService._internal();

  final Dio _dio = Dio();
  static const String _baseUrl = 'https://api.ringplus.co.uk/v1';

  Future<void> initialize() async {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add request interceptor to automatically add Bearer token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          
          // Exclude Authorization header for signin and refresh endpoints
          final isSigninEndpoint = path.contains('/signin');
          final isRefreshEndpoint = path.contains('/refresh');
          
          debugPrint('API: Request to $path, isSignin: $isSigninEndpoint, isRefresh: $isRefreshEndpoint');
          
          if (!isSigninEndpoint && !isRefreshEndpoint) {
            // Get valid access token from AuthService for all other endpoints
            final token = await AuthService.instance.getValidAccessToken();
            
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              debugPrint('API: Added Authorization header for $path');
            } else {
              debugPrint('API: No valid token available for $path - blocking request');
              // Block the request immediately if no valid token
              handler.reject(DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'Authentication required: No valid access token available',
                message: 'Request blocked due to missing authentication token',
              ));
              return;
            }
          } else {
            debugPrint('API: Skipping Authorization header for $path');
            // Ensure Authorization header is not set for these endpoints
            options.headers.remove('Authorization');
          }
          
          // Set default content type to JSON if not already set
          if (options.headers['Content-Type'] == null) {
            options.headers['Content-Type'] = 'application/json';
          }
          
          handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 unauthorized responses
          if (error.response?.statusCode == 401) {
            debugPrint('API: Received 401 Unauthorized - authentication failed');
            debugPrint('API: Request path: ${error.requestOptions.path}');
            
            // Don't handle 401s for signin and refresh endpoints - let them through
            final path = error.requestOptions.path;
            final isSigninEndpoint = path.contains('/signin');
            final isRefreshEndpoint = path.contains('/refresh');
            
            if (!isSigninEndpoint && !isRefreshEndpoint) {
              debugPrint('API: 401 on protected endpoint, triggering authentication failure flow');
              // Trigger authentication failure which will clear tokens and redirect to login
              await AuthService.instance.handleAuthenticationFailure();
            } else {
              debugPrint('API: 401 on auth endpoint ($path), passing through for normal handling');
            }
          }
          handler.next(error);
        },
      ),
    );

    // Add logging interceptor for debugging
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('API: $obj'),
      ));
    }
  }

  // Generic GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      debugPrint('API: Making GET request to $path');
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _handleApiError(e);
      rethrow;
    }
  }
  
  // Safe GET request that ensures authentication
  Future<Response<T>?> getAuthenticated<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await AuthService.instance.executeAuthenticated<Response<T>>(
      () => get<T>(path, queryParameters: queryParameters, options: options),
    );
  }

  // Generic POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      debugPrint('API: Making POST request to $path');
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _handleApiError(e);
      rethrow;
    }
  }
  
  // Safe POST request that ensures authentication
  Future<Response<T>?> postAuthenticated<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await AuthService.instance.executeAuthenticated<Response<T>>(
      () => post<T>(path, data: data, queryParameters: queryParameters, options: options),
    );
  }

  // Generic PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _handleApiError(e);
      rethrow;
    }
  }

  // Generic DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _handleApiError(e);
      rethrow;
    }
  }

  // Generic PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      debugPrint('API: Making PATCH request to $path');
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      _handleApiError(e);
      rethrow;
    }
  }
  
  // Safe PATCH request that ensures authentication
  Future<Response<T>?> patchAuthenticated<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await AuthService.instance.executeAuthenticated<Response<T>>(
      () => patch<T>(path, data: data, queryParameters: queryParameters, options: options),
    );
  }

  // Safe DELETE request that ensures authentication
  Future<Response<T>?> deleteAuthenticated<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await AuthService.instance.executeAuthenticated<Response<T>>(
      () => delete<T>(path, data: data, queryParameters: queryParameters, options: options),
    );
  }

  void _handleApiError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        debugPrint('API: Request timeout');
        break;
      case DioExceptionType.connectionError:
        debugPrint('API: Connection error');
        break;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = error.response?.data?['message'] ?? 'Unknown error';
        debugPrint('API: HTTP $statusCode - $message');
        break;
      case DioExceptionType.cancel:
        debugPrint('API: Request cancelled');
        break;
      case DioExceptionType.unknown:
        debugPrint('API: Unknown error - ${error.message}');
        break;
      default:
        debugPrint('API: Unhandled error type - ${error.type}');
    }
  }

  // Specific API methods can be added here
  
  // Example: Get user profile
  Future<Response> getUserProfile() async {
    return await get('/user/profile');
  }

  // Example: Get call history
  Future<Response> getCallHistory({
    int page = 1,
    int limit = 50,
  }) async {
    return await get('/calls/history', queryParameters: {
      'page': page,
      'limit': limit,
    });
  }

  // Example: Get contacts
  Future<Response> getContacts() async {
    return await get('/contacts');
  }

  // Example: Create contact
  Future<Response> createContact(Map<String, dynamic> contactData) async {
    return await post('/contacts', data: contactData);
  }

  // Example: Update contact
  Future<Response> updateContact(String contactId, Map<String, dynamic> contactData) async {
    return await put('/contacts/$contactId', data: contactData);
  }

  // Example: Delete contact
  Future<Response> deleteContact(String contactId) async {
    return await delete('/contacts/$contactId');
  }

  // Example: Get voicemails
  Future<Response> getVoicemails() async {
    return await get('/voicemails');
  }

  // Example: Mark voicemail as read
  Future<Response> markVoicemailAsRead(String voicemailId) async {
    return await patch('/voicemails/$voicemailId', data: {'read': true});
  }

  // Get mobile extension details for SIP configuration
  Future<Response> getExtensionDetails() async {
    return await get('/extensions/mobile');
  }
}