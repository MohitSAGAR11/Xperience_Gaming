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
        AppLogger.d('🌐 [API_CLIENT] ========================================');
        AppLogger.d('🌐 [API_CLIENT] ERROR HANDLER TRIGGERED');
        AppLogger.d('🌐 [API_CLIENT] Error type: ${error.runtimeType}');
        AppLogger.d('🌐 [API_CLIENT] Is DioException: ${error is DioException}');
        
        if (error is DioException) {
          AppLogger.d('🌐 [API_CLIENT] Status code: ${error.response?.statusCode}');
          AppLogger.d('🌐 [API_CLIENT] Request path: ${error.requestOptions.path}');
          AppLogger.d('🌐 [API_CLIENT] Request method: ${error.requestOptions.method}');
        }
        
        // Handle 401 - Token expired or invalid
        if (error.response?.statusCode == 401) {
          AppLogger.w('🌐 [API_CLIENT] ========================================');
          AppLogger.w('🌐 [API_CLIENT] 401 ERROR DETECTED - Token expired');
          AppLogger.w('🌐 [API_CLIENT] Attempting to refresh token...');
          
          // Check if user is still authenticated
          AppLogger.d('🌐 [API_CLIENT] Step 1: Checking current user...');
          final currentUser = FirebaseService.currentUser;
          AppLogger.d('🌐 [API_CLIENT] Current user: ${currentUser != null ? currentUser.uid : "null"}');
          
          if (currentUser == null) {
            // User is not authenticated, sign out
            AppLogger.w('🌐 [API_CLIENT] Step 1 Result: No current user found');
            AppLogger.w('🌐 [API_CLIENT] Signing out...');
            clearTokenCache();
            await FirebaseService.auth.signOut();
            AppLogger.w('🌐 [API_CLIENT] Signed out, returning original error');
            return handler.next(error);
          }
          
          AppLogger.d('🌐 [API_CLIENT] Step 1 Result: User authenticated (${currentUser.uid})');
          
          // Try to refresh token and retry request once
          try {
            AppLogger.d('🌐 [API_CLIENT] Step 2: Clearing token cache...');
            // Clear cached token to force refresh
            clearTokenCache();
            AppLogger.d('🌐 [API_CLIENT] Token cache cleared');
            
            AppLogger.d('🌐 [API_CLIENT] Step 3: Getting fresh token...');
            // Get fresh token
            final freshToken = await FirebaseService.getIdToken(forceRefresh: true);
            AppLogger.d('🌐 [API_CLIENT] Fresh token obtained: ${freshToken != null ? "SUCCESS (length: ${freshToken.length})" : "FAILED"}');
            
            if (freshToken == null) {
              AppLogger.e('🌐 [API_CLIENT] Step 3 Result: Failed to get fresh token');
              AppLogger.e('🌐 [API_CLIENT] Signing out...');
              await FirebaseService.auth.signOut();
              AppLogger.e('🌐 [API_CLIENT] Signed out, returning original error');
              return handler.next(error);
            }
            
            AppLogger.d('🌐 [API_CLIENT] Step 3 Result: Fresh token obtained successfully');
            
            AppLogger.d('🌐 [API_CLIENT] Step 4: Updating cached token...');
            // Update cached token
            _cachedToken = freshToken;
            _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
            _cachedUserId = currentUser.uid;
            AppLogger.d('🌐 [API_CLIENT] Token cache updated');
            
            AppLogger.d('🌐 [API_CLIENT] Step 5: Preparing retry request...');
            // Create a new RequestOptions to avoid modifying the original
            final originalOptions = error.requestOptions;
            AppLogger.d('🌐 [API_CLIENT] Original request path: ${originalOptions.path}');
            AppLogger.d('🌐 [API_CLIENT] Original request method: ${originalOptions.method}');
            AppLogger.d('🌐 [API_CLIENT] Original request data: ${originalOptions.data}');
            
            // Create new headers with fresh token
            final retryHeaders = Map<String, dynamic>.from(originalOptions.headers);
            retryHeaders['Authorization'] = 'Bearer $freshToken';
            
            AppLogger.d('🌐 [API_CLIENT] Creating new RequestOptions for retry...');
            final retryOptions = RequestOptions(
              path: originalOptions.path,
              method: originalOptions.method,
              headers: retryHeaders,
              data: originalOptions.data,
              queryParameters: originalOptions.queryParameters,
              baseUrl: originalOptions.baseUrl,
              contentType: originalOptions.contentType,
              responseType: originalOptions.responseType,
              followRedirects: originalOptions.followRedirects,
              validateStatus: originalOptions.validateStatus,
              extra: originalOptions.extra,
              connectTimeout: originalOptions.connectTimeout,
              receiveTimeout: originalOptions.receiveTimeout,
              sendTimeout: originalOptions.sendTimeout,
            );
            
            AppLogger.d('🌐 [API_CLIENT] Retry request prepared');
            AppLogger.d('🌐 [API_CLIENT] Retry URL: ${retryOptions.uri}');
            AppLogger.d('🌐 [API_CLIENT] Retry method: ${retryOptions.method}');
            AppLogger.d('🌐 [API_CLIENT] Retry headers: ${retryOptions.headers}');
            
            try {
              AppLogger.d('🌐 [API_CLIENT] Step 6: Executing retry request...');
              AppLogger.d('🌐 [API_CLIENT] Calling dio.fetch...');
              
              final response = await dio.fetch(retryOptions);
              
              AppLogger.d('🌐 [API_CLIENT] Step 6 Result: Retry SUCCESS');
              AppLogger.d('🌐 [API_CLIENT] Retry response status: ${response.statusCode}');
              AppLogger.d('🌐 [API_CLIENT] Retry response data type: ${response.data.runtimeType}');
              AppLogger.d('🌐 [API_CLIENT] ========================================');
              return handler.resolve(response);
            } catch (retryError, stackTrace) {
              AppLogger.e('🌐 [API_CLIENT] ========================================');
              AppLogger.e('🌐 [API_CLIENT] Step 6 Exception caught!');
              AppLogger.e('🌐 [API_CLIENT] Exception type: ${retryError.runtimeType}');
              AppLogger.e('🌐 [API_CLIENT] Exception: $retryError');
              if (retryError is Error) {
                AppLogger.e('🌐 [API_CLIENT] Error stack trace: ${retryError.stackTrace}');
              }
              AppLogger.e('🌐 [API_CLIENT] Catch stack trace: $stackTrace');
              AppLogger.e('🌐 [API_CLIENT] ========================================');
              AppLogger.e('🌐 [API_CLIENT] Step 6 Result: Retry FAILED');
              AppLogger.e('🌐 [API_CLIENT] Retry error type: ${retryError.runtimeType}');
              AppLogger.e('🌐 [API_CLIENT] Retry error: $retryError');
              AppLogger.e('🌐 [API_CLIENT] Is DioException: ${retryError is DioException}');
              
              // Retry also failed, check if it's still 401
              if (retryError is DioException) {
                AppLogger.d('🌐 [API_CLIENT] Retry error is DioException');
                AppLogger.d('🌐 [API_CLIENT] Retry error status code: ${retryError.response?.statusCode}');
                
                if (retryError.response?.statusCode == 401) {
                  AppLogger.e('🌐 [API_CLIENT] Retry also failed with 401');
                  AppLogger.e('🌐 [API_CLIENT] Signing out...');
                  clearTokenCache();
                  await FirebaseService.auth.signOut();
                  AppLogger.e('🌐 [API_CLIENT] Signed out, returning retry error');
                } else {
                  AppLogger.w('🌐 [API_CLIENT] Retry failed with different status code: ${retryError.response?.statusCode}');
                }
                AppLogger.e('🌐 [API_CLIENT] Returning DioException retry error');
                return handler.next(retryError);
              } else {
                AppLogger.e('🌐 [API_CLIENT] Retry error is NOT DioException');
                AppLogger.e('🌐 [API_CLIENT] Converting to DioException...');
                // Convert non-DioException to DioException
                final dioError = DioException(
                  requestOptions: options,
                  error: retryError,
                  type: DioExceptionType.unknown,
                );
                AppLogger.e('🌐 [API_CLIENT] Converted to DioException');
                AppLogger.e('🌐 [API_CLIENT] Returning converted DioException');
                return handler.next(dioError);
              }
            }
          } catch (refreshError) {
            AppLogger.e('🌐 [API_CLIENT] ========================================');
            AppLogger.e('🌐 [API_CLIENT] EXCEPTION in refresh token flow');
            AppLogger.e('🌐 [API_CLIENT] Refresh error type: ${refreshError.runtimeType}');
            AppLogger.e('🌐 [API_CLIENT] Refresh error: $refreshError');
            AppLogger.e('🌐 [API_CLIENT] Stack trace: ${refreshError is Error ? refreshError.stackTrace : "N/A"}');
            clearTokenCache();
            await FirebaseService.auth.signOut();
            AppLogger.e('🌐 [API_CLIENT] Signed out, returning original error');
            return handler.next(error);
          }
        } else {
          AppLogger.d('🌐 [API_CLIENT] Non-401 error, passing through');
        }
        AppLogger.d('🌐 [API_CLIENT] ========================================');
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

