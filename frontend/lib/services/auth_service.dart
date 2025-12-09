import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/api_client.dart';
import '../models/user_model.dart';

/// Authentication Service
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// Register a new user
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role, // 'client' or 'owner'
    String? phone,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (phone != null) 'phone': phone,
      },
    );

    if (response.isSuccess && response.data != null) {
      return AuthResponse.fromJson(response.data!);
    }

    return AuthResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    if (response.isSuccess && response.data != null) {
      return AuthResponse.fromJson(response.data!);
    }

    return AuthResponse(
      success: false,
      message: response.message ?? ErrorMessages.invalidCredentials,
    );
  }

  /// Logout user
  Future<bool> logout() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.logout,
    );
    return response.isSuccess;
  }

  /// Get current user profile
  Future<AuthResponse> getProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.profile,
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      return AuthResponse(
        success: data['success'] ?? false,
        message: 'Profile fetched',
        user: data['data'] != null && data['data']['user'] != null
            ? User.fromJson(data['data']['user'])
            : null,
      );
    }

    return AuthResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Update user profile
  Future<AuthResponse> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      ApiConstants.updateProfile,
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (avatar != null) 'avatar': avatar,
      },
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      return AuthResponse(
        success: data['success'] ?? false,
        message: data['message'] ?? 'Profile updated',
        user: data['data'] != null && data['data']['user'] != null
            ? User.fromJson(data['data']['user'])
            : null,
      );
    }

    return AuthResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Change password
  Future<ApiResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _apiClient.put(
      ApiConstants.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}

/// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient);
});

