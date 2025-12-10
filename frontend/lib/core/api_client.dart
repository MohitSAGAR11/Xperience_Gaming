import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import 'firebase_service.dart';

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

  // Add interceptors
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Firebase ID token to requests
        print('🌐 [API_CLIENT] Getting Firebase token...');
        final token = await FirebaseService.getIdToken();
        if (token != null) {
          print('🌐 [API_CLIENT] Token obtained: ${token.substring(0, 20)}...');
          options.headers['Authorization'] = 'Bearer $token';
          print('🌐 [API_CLIENT] Authorization header set');
        } else {
          print('🌐 [API_CLIENT] WARNING: No token available!');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Handle 401 - Token expired or invalid
        if (error.response?.statusCode == 401) {
          // Sign out from Firebase Auth
          await FirebaseService.auth.signOut();
          // Navigation to login will be handled by the auth state
        }
        return handler.next(error);
      },
    ),
  );

  // Add logging in debug mode
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ),
  );

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
      print('🌐 [API] GET request to: ${_dio.options.baseUrl}$path');
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );
      print('🌐 [API] GET response: ${response.statusCode}');
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      print('🌐 [API] GET DioException: ${e.type} - ${e.message}');
      print('🌐 [API] GET Error details: ${e.error}');
      return ApiResponse.error(
        message: _handleError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      print('🌐 [API] GET unexpected error: $e');
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
      print('🌐 [API] POST request to: ${_dio.options.baseUrl}$path');
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      print('🌐 [API] POST response: ${response.statusCode}');
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      print('🌐 [API] POST DioException: ${e.type} - ${e.message}');
      print('🌐 [API] POST Error details: ${e.error}');
      return ApiResponse.error(
        message: _handleError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      print('🌐 [API] POST unexpected error: $e');
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

