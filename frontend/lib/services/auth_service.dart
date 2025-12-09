import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/api_client.dart';
import '../core/firebase_service.dart';
import '../models/user_model.dart' as app_models;

/// Authentication Service
class AuthService {
  final ApiClient _apiClient;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  AuthService(this._apiClient);

  /// Register a new user with Firebase Auth, then create profile in backend
  Future<app_models.AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role, // 'client' or 'owner'
    String? phone,
  }) async {
    try {
      print('🔐 [REGISTER] Starting Firebase Auth registration...');
      
      // Create Firebase Auth user (with timeout to prevent hanging)
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Registration timed out. Please check your connection and try again.');
        },
      );

      print('🔐 [REGISTER] Firebase Auth successful!');

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return app_models.AuthResponse(
          success: false,
          message: 'Failed to create user account',
        );
      }

      // Create user profile in backend Firestore
      final profileResponse = await _apiClient.post<Map<String, dynamic>>(
        '/auth/create-profile',
        data: {
          'name': name,
          'role': role,
          if (phone != null) 'phone': phone,
        },
      );

      if (!profileResponse.isSuccess) {
        // If profile creation fails, delete Firebase Auth user
        await firebaseUser.delete();
        return app_models.AuthResponse(
          success: false,
          message: profileResponse.message ?? 'Failed to create user profile',
        );
      }

      // Get user profile from backend
      final profileData = profileResponse.data;
      if (profileData != null && profileData['data'] != null) {
        final userData = profileData['data']['user'];
        return app_models.AuthResponse(
          success: true,
          message: 'Registration successful',
          user: app_models.User.fromJson(userData),
        );
      }

      return app_models.AuthResponse(
        success: true,
        message: 'Registration successful',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return app_models.AuthResponse(success: false, message: message);
    } catch (e) {
      return app_models.AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Login user with Firebase Auth
  Future<app_models.AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 [LOGIN] Starting Firebase Auth login...');
      
      // Sign in with Firebase Auth (with timeout to prevent hanging)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Login timed out. Please check your connection and try again.');
        },
      );

      print('🔐 [LOGIN] Firebase Auth successful!');

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        print('🔐 [LOGIN] ERROR: Firebase user is null');
        return app_models.AuthResponse(
          success: false,
          message: 'Login failed',
        );
      }

      print('🔐 [LOGIN] Firebase UID: ${firebaseUser.uid}');
      print('🔐 [LOGIN] Fetching profile from backend: ${ApiConstants.baseUrl}${ApiConstants.profile}');

      // Get user profile from backend
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.profile,
      );

      print('🔐 [LOGIN] Backend response received: isSuccess=${response.isSuccess}, message=${response.message}');

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        print('🔐 [LOGIN] Profile data received: ${data.keys}');
        return app_models.AuthResponse(
          success: true,
          message: 'Login successful',
          user: data['data'] != null && data['data']['user'] != null
              ? app_models.User.fromJson(data['data']['user'])
              : null,
        );
      }

      print('🔐 [LOGIN] Backend call failed or no data, but Firebase login succeeded');
      return app_models.AuthResponse(
        success: true,
        message: 'Login successful',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('🔐 [LOGIN] Firebase Auth ERROR: ${e.code} - ${e.message}');
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return app_models.AuthResponse(success: false, message: message);
    } catch (e) {
      print('🔐 [LOGIN] UNEXPECTED ERROR: $e');
      return app_models.AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Logout user from Firebase Auth
  Future<bool> logout() async {
    try {
      await _auth.signOut();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current user profile
  Future<app_models.AuthResponse> getProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.profile,
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      return app_models.AuthResponse(
        success: data['success'] ?? false,
        message: 'Profile fetched',
        user: data['data'] != null && data['data']['user'] != null
            ? app_models.User.fromJson(data['data']['user'])
            : null,
      );
    }

    return app_models.AuthResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Update user profile
  Future<app_models.AuthResponse> updateProfile({
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
      return app_models.AuthResponse(
        success: data['success'] ?? false,
        message: data['message'] ?? 'Profile updated',
        user: data['data'] != null && data['data']['user'] != null
            ? app_models.User.fromJson(data['data']['user'])
            : null,
      );
    }

    return app_models.AuthResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Change password using Firebase Auth
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return PasswordChangeResult(success: false, message: 'Not authenticated');
      }

      // Re-authenticate user before changing password
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(credential);

      // Update password
      await firebaseUser.updatePassword(newPassword);

      return PasswordChangeResult(success: true, message: 'Password changed successfully');
    } on firebase_auth.FirebaseAuthException catch (e) {
      String message = 'Failed to change password';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }
      return PasswordChangeResult(success: false, message: message);
    } catch (e) {
      return PasswordChangeResult(success: false, message: e.toString());
    }
  }
}

/// Simple result class for password change
class PasswordChangeResult {
  final bool success;
  final String message;
  
  PasswordChangeResult({required this.success, required this.message});
}

/// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient);
});

