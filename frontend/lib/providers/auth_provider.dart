import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Auth State
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }

  /// Check if user is owner
  bool get isOwner => user?.role == AppConstants.roleOwner;

  /// Check if user is client
  bool get isClient => user?.role == AppConstants.roleClient;
}

/// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final StorageService _storage;

  AuthNotifier(this._authService, this._storage) : super(AuthState());

  /// Initialize auth state (check stored token)
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      final isLoggedIn = await _storage.isLoggedIn();
      
      if (isLoggedIn) {
        // Try to fetch user profile
        final response = await _authService.getProfile();
        
        if (response.success && response.user != null) {
          await _storage.saveUser(response.user!);
          await _storage.saveRole(response.user!.role);
          
          state = AuthState(
            user: response.user,
            isAuthenticated: true,
            isLoading: false,
          );
        } else {
          // Token invalid, clear storage
          await _storage.clearAll();
          state = AuthState(isLoading: false);
        }
      } else {
        state = AuthState(isLoading: false);
      }
    } catch (e) {
      await _storage.clearAll();
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  /// Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );

      if (response.success && response.user != null && response.token != null) {
        await _storage.saveToken(response.token!);
        await _storage.saveUser(response.user!);
        await _storage.saveRole(response.user!.role);

        state = AuthState(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Login user
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      if (response.success && response.user != null && response.token != null) {
        await _storage.saveToken(response.token!);
        await _storage.saveUser(response.user!);
        await _storage.saveRole(response.user!.role);

        state = AuthState(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authService.logout();
    } catch (_) {
      // Ignore errors during logout
    }

    await _storage.clearAll();
    state = AuthState(isLoading: false);
  }

  /// Update profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.updateProfile(
        name: name,
        phone: phone,
        avatar: avatar,
      );

      if (response.success && response.user != null) {
        await _storage.saveUser(response.user!);
        
        state = state.copyWith(
          user: response.user,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(authService, storage);
});

/// Is Authenticated Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Is Owner Provider
final isOwnerProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isOwner;
});

/// Is Client Provider
final isClientProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isClient;
});

