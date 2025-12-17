import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import 'firebase_service.dart';
import 'logger.dart';

/// Dio HTTP Client Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60), // Increased from 30 to 60
      receiveTimeout: const Duration(seconds: 60), // Increased from 30 to 60
      sendTimeout: const Duration(seconds: 60), // Added send timeout
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Token cache - shared across all requests
  String? _cachedToken;
  DateTime? _tokenExpiry;
  String? _cachedUserId; // Store user ID to validate token belongs to current user

  // Function to clear token cache (can be called from outside)
  void clearTokenCache() {
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedUserId = null;
  }

  // Add interceptors
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Firebase ID token to requests with caching
        try {
          // Check if user is still signed in - clear cache if not
          final currentUser = FirebaseService.currentUser;
          if (currentUser == null) {
            clearTokenCache();
          } else {
            final currentUserId = currentUser.uid;
            
            // CRITICAL: Check if cached token belongs to current user
            // If user ID changed (e.g., after logout/login with different account), clear cache
            if (_cachedUserId != null && _cachedUserId != currentUserId) {
              AppLogger.w('🌐 [API_CLIENT] Cached token belongs to different user, clearing cache');
              clearTokenCache();
            }
            
            // Refresh token if expired, not cached, or user changed
            if (_cachedToken == null || 
                _tokenExpiry == null || 
                _cachedUserId == null ||
                DateTime.now().isAfter(_tokenExpiry!)) {
              _cachedToken = await FirebaseService.getIdToken(forceRefresh: true);
              // Cache token for 50 minutes (tokens expire in ~1 hour)
              _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
              _cachedUserId = currentUserId; // Store user ID with token
              
              if (_cachedToken == null) {
                AppLogger.w('🌐 [API_CLIENT] WARNING: No token available!');
              }
            }
          }
          
          if (_cachedToken != null) {
            options.headers['Authorization'] = 'Bearer $_cachedToken';
          }
        } catch (e) {
          AppLogger.e('🌐 [API_CLIENT] Error getting token', e);
          // Clear cache on error
          clearTokenCache();
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Handle 401 - Token expired or invalid
        if (error.response?.statusCode == 401) {
          // Clear cached token on 401
          clearTokenCache();
          AppLogger.w('🌐 [API_CLIENT] Token expired (401), clearing cache');
          // Sign out from Firebase Auth
          await FirebaseService.auth.signOut();
          // Navigation to login will be handled by the auth state
        }
        return handler.next(error);
      },
    ),
  );

  // Add logging in debug mode only
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
});

/// API Client Service
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// GET Request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      AppLogger.d('🌐 [API] GET request to: ${_dio.options.baseUrl}$path');
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      AppLogger.d('🌐 [API] GET response: ${response.statusCode}');
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('🌐 [API] GET DioException: ${e.type} - ${e.message}', e.error);
      return ApiResponse.error(
        message: _handleError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.e('🌐 [API] GET unexpected error', e);
      return ApiResponse.error(message: e.toString());
    }
  }

  /// POST Request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      AppLogger.d('🌐 [API] POST request to: ${_dio.options.baseUrl}$path');
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      AppLogger.d('🌐 [API] POST response: ${response.statusCode}');
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.e('🌐 [API] POST DioException: ${e.type} - ${e.message}', e.error);
      return ApiResponse.error(
        message: _handleError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      AppLogger.e('🌐 [API] POST unexpected error', e);
      return ApiResponse.error(message: e.toString());
    }
  }

  /// PUT Request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: _handleError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(message: e.toString());
    }
  }

  /// DELETE Request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: _handleError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(message: e.toString());
    }
  }

  /// Handle Dio Errors
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ErrorMessages.networkError;
      case DioExceptionType.connectionError:
        return ErrorMessages.networkError;
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'];
        }
        return ErrorMessages.serverError;
      case DioExceptionType.cancel:
        return 'Request cancelled';
      default:
        return ErrorMessages.unknownError;
    }
  }
}

/// API Response Wrapper
class ApiResponse<T> {
  final T? data;
  final String? message;
  final int? statusCode;
  final bool isSuccess;

  ApiResponse._({
    this.data,
    this.message,
    this.statusCode,
    required this.isSuccess,
  });

  factory ApiResponse.success({T? data, int? statusCode}) {
    return ApiResponse._(
      data: data,
      statusCode: statusCode,
      isSuccess: true,
    );
  }

  factory ApiResponse.error({String? message, int? statusCode}) {
    return ApiResponse._(
      message: message,
      statusCode: statusCode,
      isSuccess: false,
    );
  }
}

/// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});

