import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/api_client.dart';
import '../core/firebase_service.dart';
import '../core/logger.dart';
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
      AppLogger.d('🔐 [REGISTER] Starting Firebase Auth registration...');
      
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

      AppLogger.d('🔐 [REGISTER] Firebase Auth successful!');

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return app_models.AuthResponse(
          success: false,
          message: 'Failed to create user account',
        );
      }

      // Wait a moment for Firebase Auth to fully settle
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force refresh the token to ensure it's valid
      AppLogger.d('🔐 [REGISTER] Refreshing Firebase token...');
      await FirebaseService.refreshToken();
      
      // Create user profile in backend Firestore with retry logic
      AppLogger.d('🔐 [REGISTER] Creating profile in backend...');
      
      ApiResponse<Map<String, dynamic>> profileResponse = ApiResponse.error(message: 'Profile creation not attempted');
      int retryCount = 0;
      const maxRetries = 1;
      
      while (retryCount < maxRetries) {
        try {
          profileResponse = await _apiClient.post<Map<String, dynamic>>(
            '/auth/create-profile',
            data: {
              'name': name,
              'role': role,
              if (phone != null) 'phone': phone,
            },
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Profile creation request timed out');
            },
          );
          
          AppLogger.d('🔐 [REGISTER] Profile creation response: success=${profileResponse.isSuccess}');
          
          if (profileResponse.isSuccess) {
            break; // Success, exit retry loop
          }
          
          // If not successful, retry
          retryCount++;
          if (retryCount < maxRetries) {
            AppLogger.w('🔐 [REGISTER] Profile creation failed, retrying ($retryCount/$maxRetries)...');
            await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
          }
        } catch (e) {
          retryCount++;
          AppLogger.e('🔐 [REGISTER] Profile creation error (attempt $retryCount/$maxRetries)', e);
          if (retryCount >= maxRetries) {
            profileResponse = ApiResponse.error(message: e.toString());
            break;
          }
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }

      if (!profileResponse.isSuccess) {
        AppLogger.e('🔐 [REGISTER] Profile creation failed after $maxRetries attempts: ${profileResponse.message}');
        
        // Check if profile actually exists before deleting Firebase user
        // (in case the request succeeded but response was lost)
        try {
          AppLogger.d('🔐 [REGISTER] Checking if profile was created despite error...');
          await Future.delayed(const Duration(seconds: 2)); // Wait a bit
          
          final checkResponse = await _apiClient.get<Map<String, dynamic>>(
            ApiConstants.profile,
          );
          
          if (checkResponse.isSuccess && checkResponse.data != null) {
            AppLogger.d('🔐 [REGISTER] Profile exists! Registration actually succeeded.');
            // Profile exists, registration succeeded despite error
            final userData = checkResponse.data!['data']['user'];
            return app_models.AuthResponse(
              success: true,
              message: 'Registration successful',
              user: app_models.User.fromJson(userData),
            );
          }
        } catch (e) {
          AppLogger.e('🔐 [REGISTER] Profile check failed', e);
        }
        
        // Profile truly doesn't exist, delete Firebase Auth user
        AppLogger.w('🔐 [REGISTER] Deleting Firebase Auth user due to profile creation failure');
        try {
          await firebaseUser.delete();
        } catch (e) {
          AppLogger.e('🔐 [REGISTER] Failed to delete Firebase user', e);
        }
        
        return app_models.AuthResponse(
          success: false,
          message: profileResponse.message ?? 'Failed to create user profile after multiple attempts',
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
      AppLogger.d('🔐 [LOGIN] Starting Firebase Auth login...');
      AppLogger.d('🔐 [LOGIN] Email: $email');
      
      // Sign in with Firebase Auth (with timeout to prevent hanging)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), // Trim whitespace
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Login timed out. Please check your connection and try again.');
        },
      );

      AppLogger.d('🔐 [LOGIN] Firebase Auth successful!');

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        AppLogger.e('🔐 [LOGIN] ERROR: Firebase user is null');
        return app_models.AuthResponse(
          success: false,
          message: 'Login failed',
        );
      }

      AppLogger.d('🔐 [LOGIN] Firebase UID: ${firebaseUser.uid}');
      
      // Force refresh the token to ensure it's valid
      AppLogger.d('🔐 [LOGIN] Refreshing Firebase token...');
      await FirebaseService.refreshToken();
      
      // Wait a moment for token to settle
      await Future.delayed(const Duration(milliseconds: 500));
      
      AppLogger.d('🔐 [LOGIN] Fetching profile from backend: ${ApiConstants.baseUrl}${ApiConstants.profile}');

      // Get user profile from backend with retry logic
      ApiResponse<Map<String, dynamic>> response = ApiResponse.error(message: 'Profile fetch not attempted');
      int retryCount = 0;
      const maxRetries = 1;
      
      while (retryCount < maxRetries) {
        try {
          response = await _apiClient.get<Map<String, dynamic>>(
            ApiConstants.profile,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Profile fetch timed out');
            },
          );
          
          AppLogger.d('🔐 [LOGIN] Backend response received: isSuccess=${response.isSuccess}, message=${response.message}');
          
          if (response.isSuccess && response.data != null) {
            final data = response.data!;
            AppLogger.d('🔐 [LOGIN] Profile data received: ${data.keys}');
            
            if (data['data'] != null && data['data']['user'] != null) {
              AppLogger.d('🔐 [LOGIN] Login successful! User role: ${data['data']['user']['role']}');
              return app_models.AuthResponse(
                success: true,
                message: 'Login successful',
                user: app_models.User.fromJson(data['data']['user']),
              );
            }
          }
          
          // If profile not found but no error, retry
          retryCount++;
          if (retryCount < maxRetries) {
            AppLogger.w('🔐 [LOGIN] Profile not found, retrying ($retryCount/$maxRetries)...');
            await Future.delayed(Duration(seconds: retryCount * 2));
          }
        } catch (e) {
          retryCount++;
          AppLogger.e('🔐 [LOGIN] Profile fetch error (attempt $retryCount/$maxRetries)', e);
          if (retryCount >= maxRetries) {
            response = ApiResponse.error(message: e.toString());
            break;
          }
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }

      // Profile fetch failed after retries - sign out and show error
      AppLogger.e('🔐 [LOGIN] Profile not found in database after $maxRetries attempts.');
      await _auth.signOut();
      
      return app_models.AuthResponse(
        success: false,
        message: 'Account profile not found. Please register again or contact support.',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      AppLogger.e('🔐 [LOGIN] Firebase Auth ERROR: ${e.code} - ${e.message}', e);
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many failed attempts. Please try again later.';
      } else {
        message = 'Login failed: ${e.message ?? e.code}';
      }
      return app_models.AuthResponse(success: false, message: message);
    } catch (e) {
      AppLogger.e('🔐 [LOGIN] UNEXPECTED ERROR', e);
      return app_models.AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Sign in with Google
  Future<app_models.AuthResponse> signInWithGoogle({
    required String role, // 'client' or 'owner'
  }) async {
    try {
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Starting Google Sign-In with role: $role');
      
      // Sign in with Google (handled by FirebaseService)
      final userCredential = await FirebaseService.signInWithGoogle();
      
      if (userCredential == null) {
        return app_models.AuthResponse(
          success: false,
          message: 'Google Sign-In was cancelled',
        );
      }
      
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return app_models.AuthResponse(
          success: false,
          message: 'Failed to sign in with Google',
        );
      }
      
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Firebase user created: ${firebaseUser.uid}');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Email: ${firebaseUser.email}');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Display Name: ${firebaseUser.displayName}');
      
      // Check if this is a new user or existing user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Is new user: $isNewUser');
      
      // Wait for token to settle, then try to refresh (non-blocking if it fails)
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await FirebaseService.refreshToken();
      } catch (e) {
        // Token refresh failed, but continue with sign-in
        // Firebase usually provides a token automatically after sign-in
        AppLogger.w('🔐 [GOOGLE_SIGNIN] Token refresh failed, but continuing sign-in: $e');
      }
      
      // Send Google Sign-In data to backend
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Sending to backend...');
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/google-signin',
        data: {
          'role': role,
          'isNewUser': isNewUser,
          'name': firebaseUser.displayName,
          'email': firebaseUser.email,
        },
      );
      
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Backend response: ${response.isSuccess}');
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        if (data['data'] != null && data['data']['user'] != null) {
          AppLogger.d('🔐 [GOOGLE_SIGNIN] Success! User role: ${data['data']['user']['role']}');
          return app_models.AuthResponse(
            success: true,
            message: data['message'] ?? 'Sign in successful',
            user: app_models.User.fromJson(data['data']['user']),
          );
        }
      }
      
      // Backend failed, sign out
      AppLogger.w('🔐 [GOOGLE_SIGNIN] Backend failed, signing out');
      await FirebaseService.signOut();
      
      return app_models.AuthResponse(
        success: false,
        message: response.message ?? 'Failed to complete sign in',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      AppLogger.e('🔐 [GOOGLE_SIGNIN] Firebase Auth ERROR: ${e.code} - ${e.message}', e);
      return app_models.AuthResponse(
        success: false,
        message: 'Google Sign-In failed: ${e.message ?? e.code}',
      );
    } catch (e) {
      AppLogger.e('🔐 [GOOGLE_SIGNIN] UNEXPECTED ERROR', e);
      return app_models.AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Logout user from Firebase Auth
  Future<bool> logout() async {
    AppLogger.d('🔐 [AUTH_SERVICE] ========== AUTH SERVICE LOGOUT ==========');
    try {
      AppLogger.d('🔐 [AUTH_SERVICE] Calling FirebaseService.signOut()...');
      await FirebaseService.signOut(); // This handles both Firebase and Google sign-out
      AppLogger.d('🔐 [AUTH_SERVICE] ✅ FirebaseService.signOut() completed successfully');
      AppLogger.d('🔐 [AUTH_SERVICE] ========== AUTH SERVICE LOGOUT SUCCESS ==========');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('🔐 [AUTH_SERVICE] ❌ Error in FirebaseService.signOut()', e, stackTrace);
      AppLogger.d('🔐 [AUTH_SERVICE] ========== AUTH SERVICE LOGOUT FAILED ==========');
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

