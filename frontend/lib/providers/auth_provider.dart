import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../config/constants.dart';
import '../core/storage.dart';
import '../core/firebase_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';


/// Auth State
class AuthState {
  final User? user; // This is our app's User model, not Firebase's
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
  final Ref _ref;
  
  // Flag to prevent listener from interfering during registration
  bool _isRegistering = false;

  AuthNotifier(this._authService, this._storage, this._ref) : super(AuthState());

  /// Initialize auth state (check Firebase Auth)
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      // Listen to Firebase Auth state changes
      // Note: This listener handles sign-out events primarily
      // Registration and login manage their own state
      FirebaseService.authStateChanges.listen((firebaseUser) async {
        // Skip if we're in the middle of registration or already loading
        if (_isRegistering || state.isLoading) {
          print('🔐 [AUTH_LISTENER] Skipping - isRegistering=$_isRegistering, isLoading=${state.isLoading}');
          return;
        }
        print('🔐 [AUTH_LISTENER] Auth state changed: user=${firebaseUser?.uid ?? "null"}');
        
        if (firebaseUser == null) {
          // User signed out - clear state
          print('🔐 [AUTH_LISTENER] User signed out, clearing state');
          await _storage.clearAll();
          state = AuthState(isLoading: false);
        }
        // Note: We don't auto-fetch profile on sign-in here
        // because registration needs to create the profile first
      });

      // Check current Firebase Auth state
      final firebaseUser = FirebaseService.currentUser;
      if (firebaseUser != null) {
        print('🔐 [AUTH_INIT] Firebase user found: ${firebaseUser.uid}');
        print('🔐 [AUTH_INIT] Fetching profile from backend...');
        
        // Add timeout to prevent hanging
        final response = await _authService.getProfile().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('🔐 [AUTH_INIT] Profile fetch timed out, signing out...');
            FirebaseService.auth.signOut();
            throw Exception('Profile fetch timed out');
          },
        );
        
        if (response.success && response.user != null) {
          print('🔐 [AUTH_INIT] Profile fetched successfully');
          await _storage.saveUser(response.user!);
          await _storage.saveRole(response.user!.role);
          state = AuthState(
            user: response.user,
            isAuthenticated: true,
            isLoading: false,
          );
          
          // Initialize notifications after successful authentication
          _initializeNotifications();
        } else {
          // Profile not found - user exists in Firebase but not in our DB
          // Sign them out to allow fresh registration
          print('🔐 [AUTH_INIT] Profile not found in backend, signing out Firebase user');
          await FirebaseService.auth.signOut();
          await _storage.clearAll();
          state = AuthState(isLoading: false);
        }
      } else {
        print('🔐 [AUTH_INIT] No Firebase user found');
        state = AuthState(isLoading: false);
      }
    } catch (e) {
      print('🔐 [AUTH_INIT] Error: $e');
      await FirebaseService.auth.signOut();
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
    
    // Set flag to prevent auth listener from interfering
    _isRegistering = true;

    try {
      final response = await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );

      if (response.success && response.user != null) {
        await _storage.saveUser(response.user!);
        await _storage.saveRole(response.user!.role);

        state = AuthState(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        _isRegistering = false;
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        _isRegistering = false;
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _isRegistering = false;
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

      if (response.success && response.user != null) {
        await _storage.saveUser(response.user!);
        await _storage.saveRole(response.user!.role);

        state = AuthState(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        
        // Initialize notifications after successful login
        _initializeNotifications();
        
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
      // Unregister notification token before logout
      try {
        final notificationService = _ref.read(notificationServiceProvider);
        await notificationService.unregisterToken();
        print('📬 [AUTH] Notification token unregistered');
      } catch (e) {
        print('📬 [AUTH] Error unregistering notification token: $e');
        // Don't fail logout if notification unregister fails
      }
      
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

  /// Sign in with Google
  Future<bool> signInWithGoogle({
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    // Set flag to prevent auth listener from interfering
    _isRegistering = true;

    try {
      final response = await _authService.signInWithGoogle(role: role);

      if (response.success && response.user != null) {
        await _storage.saveUser(response.user!);
        await _storage.saveRole(response.user!.role);

        state = AuthState(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        
        // Initialize notifications after successful Google sign-in
        _initializeNotifications();
        
        _isRegistering = false;
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        _isRegistering = false;
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _isRegistering = false;
      return false;
    }
  }

  /// Initialize notifications (called after successful authentication)
  Future<void> _initializeNotifications() async {
    try {
      print('📬 [AUTH] Initializing notifications...');
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.initialize();
      print('📬 [AUTH] Notifications initialized successfully');
    } catch (e) {
      print('📬 [AUTH] Error initializing notifications: $e');
      // Don't fail authentication if notifications fail
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
  return AuthNotifier(authService, storage, ref);
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

