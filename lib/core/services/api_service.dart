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
          // Get valid access token from AuthService
          final token = await AuthService.instance.getValidAccessToken();
          
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
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
            debugPrint('API: Received 401, user needs to re-authenticate');
            // Sign out the user as their session is invalid
            await AuthService.instance.signOut();
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

  // Generic POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
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