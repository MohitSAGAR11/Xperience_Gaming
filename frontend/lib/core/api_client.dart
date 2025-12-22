import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import 'firebase_service.dart';
import 'logger.dart';

/// Token Refresh Interceptor with queuing to prevent thundering herd
class _TokenRefreshInterceptor extends QueuedInterceptor {
  final Future<String?> Function({bool forceRefresh}) getTokenWithQueue;
  final void Function() clearTokenCache;
  final Dio tokenDio;

  _TokenRefreshInterceptor({
    required this.getTokenWithQueue,
    required this.clearTokenCache,
    required this.tokenDio,
  });

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await getTokenWithQueue();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      AppLogger.e('🌐 [API_CLIENT] Error getting token in onRequest', e);
    }
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    return handler.next(response);
  }

  @override
  Future<void> onError(DioException error, ErrorInterceptorHandler handler) async {
    // Handle 401 - Token expired or invalid
    if (error.response?.statusCode == 401) {
      AppLogger.w('🌐 [API_CLIENT] 401 detected, refreshing token...');
      
      final currentUser = FirebaseService.currentUser;
      if (currentUser == null) {
        AppLogger.w('🌐 [API_CLIENT] No Firebase user found');
        AppLogger.w('🌐 [API_CLIENT] User already signed out or session expired');
        clearTokenCache();
        // Don't call signOut() if user is already null - avoid unnecessary operations
        return handler.next(error);
      }

      try {
        AppLogger.d('🌐 [API_CLIENT] User authenticated: ${currentUser.uid}');
        AppLogger.d('🌐 [API_CLIENT] Attempting token refresh...');
        
        // Use queued token refresh - will wait if another refresh is in progress
        final freshToken = await getTokenWithQueue(forceRefresh: true);
        
        if (freshToken == null) {
          AppLogger.e('🌐 [API_CLIENT] Failed to refresh token');
          AppLogger.e('🌐 [API_CLIENT] Checking if user is still authenticated...');
          
          // Double-check user is still authenticated before signing out
          final stillAuthenticated = FirebaseService.currentUser != null;
          if (stillAuthenticated) {
            AppLogger.w('🌐 [API_CLIENT] User still authenticated but token refresh failed');
            AppLogger.w('🌐 [API_CLIENT] This may be a temporary Firebase issue');
            AppLogger.w('🌐 [API_CLIENT] NOT signing out - will retry on next request');
            clearTokenCache(); // Clear cache to force refresh on next attempt
          } else {
            AppLogger.e('🌐 [API_CLIENT] User no longer authenticated, signing out...');
            clearTokenCache();
            await FirebaseService.auth.signOut();
          }
          return handler.next(error);
        }
        
        AppLogger.d('🌐 [API_CLIENT] Token refreshed successfully (length: ${freshToken.length})');

        // Retry the original request with new token
        final originalOptions = error.requestOptions;
        final retryHeaders = Map<String, dynamic>.from(originalOptions.headers);
        
        // Ensure Authorization header is set with fresh token (proper casing)
        retryHeaders['Authorization'] = 'Bearer $freshToken';
        
        AppLogger.d('🌐 [API_CLIENT] ========================================');
        AppLogger.d('🌐 [API_CLIENT] Preparing retry request');
        AppLogger.d('🌐 [API_CLIENT] URL: ${originalOptions.baseUrl}${originalOptions.path}');
        AppLogger.d('🌐 [API_CLIENT] Method: ${originalOptions.method}');
        AppLogger.d('🌐 [API_CLIENT] Token length: ${freshToken.length}');
        AppLogger.d('🌐 [API_CLIENT] Token preview (first 50 chars): ${freshToken.substring(0, freshToken.length > 50 ? 50 : freshToken.length)}...');
        AppLogger.d('🌐 [API_CLIENT] Authorization header set: ${retryHeaders.containsKey('Authorization')}');
        AppLogger.d('🌐 [API_CLIENT] ========================================');

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

        try {
          final authHeaderValue = retryOptions.headers['Authorization'] as String?;
          AppLogger.d('🌐 [API_CLIENT] Executing retry with tokenDio...');
          if (authHeaderValue != null) {
            AppLogger.d('🌐 [API_CLIENT] Authorization header value (first 80 chars): ${authHeaderValue.substring(0, authHeaderValue.length > 80 ? 80 : authHeaderValue.length)}...');
            AppLogger.d('🌐 [API_CLIENT] Authorization header starts with "Bearer ": ${authHeaderValue.startsWith('Bearer ')}');
          } else {
            AppLogger.e('🌐 [API_CLIENT] ⚠️ Authorization header is missing!');
          }
          
          // Use tokenDio to avoid interceptors (prevents loops)
          final response = await tokenDio.fetch(retryOptions);
          AppLogger.d('🌐 [API_CLIENT] ✅ Retry successful after token refresh');
          AppLogger.d('🌐 [API_CLIENT] Response status: ${response.statusCode}');
          return handler.resolve(response);
        } catch (retryError) {
          if (retryError is DioException) {
            AppLogger.e('🌐 [API_CLIENT] Retry failed with status: ${retryError.response?.statusCode}');
            AppLogger.e('🌐 [API_CLIENT] Retry error response: ${retryError.response?.data}');
            AppLogger.e('🌐 [API_CLIENT] Retry request headers: ${retryError.requestOptions.headers}');
            
            if (retryError.response?.statusCode == 401) {
              AppLogger.e('🌐 [API_CLIENT] ========================================');
              AppLogger.e('🌐 [API_CLIENT] ⚠️ Retry still 401 after token refresh');
              AppLogger.e('🌐 [API_CLIENT] This suggests a BACKEND verification issue');
              AppLogger.e('🌐 [API_CLIENT] Token was refreshed successfully, but backend rejected it');
              
              // Check if Firebase user is still authenticated
              final stillAuthenticated = FirebaseService.currentUser != null;
              
              if (stillAuthenticated) {
                AppLogger.w('🌐 [API_CLIENT] User is still authenticated with Firebase');
                AppLogger.w('🌐 [API_CLIENT] Likely backend token verification issue');
                AppLogger.w('🌐 [API_CLIENT] NOT signing out - preserving user session');
                AppLogger.w('🌐 [API_CLIENT] Check backend logs for token verification errors');
                // Don't sign out - backend issue, not client issue
              } else {
                AppLogger.e('🌐 [API_CLIENT] User is no longer authenticated with Firebase');
                AppLogger.e('🌐 [API_CLIENT] Signing out...');
                clearTokenCache();
                await FirebaseService.auth.signOut();
              }
              
              AppLogger.e('🌐 [API_CLIENT] ========================================');
            }
            return handler.next(retryError);
          } else {
            // Convert non-DioException to DioException
            final dioError = DioException(
              requestOptions: retryOptions,
              error: retryError,
              type: DioExceptionType.unknown,
            );
            return handler.next(dioError);
          }
        }
      } catch (refreshError) {
        AppLogger.e('🌐 [API_CLIENT] ========================================');
        AppLogger.e('🌐 [API_CLIENT] Exception in token refresh flow');
        AppLogger.e('🌐 [API_CLIENT] Error type: ${refreshError.runtimeType}');
        AppLogger.e('🌐 [API_CLIENT] Error: $refreshError');
        
        // Check if user is still authenticated before signing out
        final stillAuthenticated = FirebaseService.currentUser != null;
        if (stillAuthenticated) {
          AppLogger.w('🌐 [API_CLIENT] User still authenticated despite refresh error');
          AppLogger.w('🌐 [API_CLIENT] Clearing token cache but NOT signing out');
          clearTokenCache();
        } else {
          AppLogger.e('🌐 [API_CLIENT] User no longer authenticated, signing out...');
          clearTokenCache();
          await FirebaseService.auth.signOut();
        }
        AppLogger.e('🌐 [API_CLIENT] ========================================');
        return handler.next(error);
      }
    }
    
    return handler.next(error);
  }
}

/// Dio HTTP Client Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Separate Dio instance for token refresh (no interceptors to prevent loops)
  final tokenDio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // Token cache - shared across all requests
  String? _cachedToken;
  DateTime? _tokenExpiry;
  String? _cachedUserId;

  // Lock mechanism to prevent thundering herd
  Completer<String?>? _tokenRefreshCompleter;
  bool _isRefreshing = false;

  // Function to clear token cache
  void clearTokenCache() {
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedUserId = null;
    // Cancel any pending refresh
    if (_tokenRefreshCompleter != null && !_tokenRefreshCompleter!.isCompleted) {
      _tokenRefreshCompleter!.completeError('Token cache cleared');
    }
    _tokenRefreshCompleter = null;
    _isRefreshing = false;
  }

  // Get token with queuing - only one refresh at a time
  Future<String?> _getTokenWithQueue({bool forceRefresh = false}) async {
    // Check if token is still valid
    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        _cachedUserId != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    // If already refreshing, wait for the existing refresh to complete
    if (_isRefreshing && _tokenRefreshCompleter != null) {
      AppLogger.d('🌐 [API_CLIENT] Token refresh in progress, waiting...');
      try {
        return await _tokenRefreshCompleter!.future;
      } catch (e) {
        // Refresh failed, try again
        AppLogger.w('🌐 [API_CLIENT] Queued refresh failed, retrying...');
      }
    }

    // Start new refresh
    _isRefreshing = true;
    _tokenRefreshCompleter = Completer<String?>();

    try {
      final currentUser = FirebaseService.currentUser;
      if (currentUser == null) {
        clearTokenCache();
        _tokenRefreshCompleter!.complete(null);
        return null;
      }

      final currentUserId = currentUser.uid;

      // Check if cached token belongs to different user
      if (_cachedUserId != null && _cachedUserId != currentUserId) {
        AppLogger.w('🌐 [API_CLIENT] User changed, clearing cache');
        _cachedToken = null;
        _tokenExpiry = null;
        _cachedUserId = null;
      }

      AppLogger.d('🌐 [API_CLIENT] Refreshing token...');
      final freshToken = await FirebaseService.getIdToken(forceRefresh: true);

      if (freshToken == null) {
        AppLogger.w('🌐 [API_CLIENT] Failed to get token');
        clearTokenCache();
        _tokenRefreshCompleter!.complete(null);
        return null;
      }

      // Update cache
      _cachedToken = freshToken;
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
      _cachedUserId = currentUserId;

      AppLogger.d('🌐 [API_CLIENT] Token refreshed successfully');
      _tokenRefreshCompleter!.complete(freshToken);
      return freshToken;
    } catch (e) {
      AppLogger.e('🌐 [API_CLIENT] Error refreshing token', e);
      clearTokenCache();
      _tokenRefreshCompleter!.completeError(e);
      return null;
    } finally {
      _isRefreshing = false;
      _tokenRefreshCompleter = null;
    }
  }

  // Add interceptors with queued token refresh
  dio.interceptors.add(
    _TokenRefreshInterceptor(
      getTokenWithQueue: _getTokenWithQueue,
      clearTokenCache: clearTokenCache,
      tokenDio: tokenDio,
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

