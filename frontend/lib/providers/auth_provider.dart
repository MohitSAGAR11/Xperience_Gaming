import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../core/storage.dart';
import '../core/firebase_service.dart';
import '../core/api_client.dart';
import '../core/logger.dart';
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
  // Flag to track initialization state - prevents clearing storage during app startup
  bool _isInitializing = false;

  AuthNotifier(this._authService, this._storage, this._ref) : super(AuthState());

  /// Initialize auth state (check Firebase Auth)
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    _isInitializing = true;

    // FIRST: Try to restore user state from storage (persisted session)
    // This ensures we maintain login state even if Firebase Auth hasn't restored yet
    final storedUser = _storage.getUser();
    final storedRole = _storage.getRole();
    
    try {
      if (storedUser != null && storedRole != null) {
        AppLogger.d('🔐 [AUTH_INIT] Found stored user: ${storedUser.email}');
        state = AuthState(
          user: storedUser,
          isAuthenticated: true,
          isLoading: true, // Still loading to verify with Firebase
        );
      }

      // Listen to Firebase Auth state changes
      // Note: This listener handles sign-out events primarily
      // Registration and login manage their own state
      FirebaseService.authStateChanges.listen((firebaseUser) async {
        // Skip if we're initializing, registering, or already loading
        if (_isInitializing || _isRegistering || state.isLoading) {
          AppLogger.d('🔐 [AUTH_LISTENER] Skipping - isInitializing=$_isInitializing, isRegistering=$_isRegistering, isLoading=${state.isLoading}');
          return;
        }
        AppLogger.d('🔐 [AUTH_LISTENER] Auth state changed: user=${firebaseUser?.uid ?? "null"}');
        
        // Only clear storage if user was authenticated and now Firebase user is null
        // This means user actually signed out, not just app restart
        if (firebaseUser == null && state.isAuthenticated) {
          // User signed out - clear state
          AppLogger.d('🔐 [AUTH_LISTENER] User signed out, clearing state');
          await _storage.clearAll();
          state = AuthState(isLoading: false);
        }
        // Note: We don't auto-fetch profile on sign-in here
        // because registration needs to create the profile first
      });

      // Check current Firebase Auth state
      final firebaseUser = FirebaseService.currentUser;
      if (firebaseUser != null) {
        AppLogger.d('🔐 [AUTH_INIT] Firebase user found: ${firebaseUser.uid}');
        AppLogger.d('🔐 [AUTH_INIT] Fetching profile from backend...');
        
        // Add timeout to prevent hanging
        final response = await _authService.getProfile().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.w('🔐 [AUTH_INIT] Profile fetch timed out, signing out...');
            FirebaseService.auth.signOut();
            throw Exception('Profile fetch timed out');
          },
        );
        
        if (response.success && response.user != null) {
          AppLogger.d('🔐 [AUTH_INIT] Profile fetched successfully');
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
          AppLogger.w('🔐 [AUTH_INIT] Profile not found in backend, signing out Firebase user');
          await FirebaseService.auth.signOut();
          await _storage.clearAll();
          state = AuthState(isLoading: false);
        }
      } else {
        // No Firebase user found
        // If we have stored user data, keep it - Firebase Auth might still be restoring
        // The listener will handle actual sign-outs
        if (storedUser != null && storedRole != null) {
          AppLogger.d('🔐 [AUTH_INIT] No Firebase user but stored user exists - keeping stored session');
          // Keep the stored user state - Firebase Auth might restore later
          state = AuthState(
            user: storedUser,
            isAuthenticated: true,
            isLoading: false,
          );
        } else {
          AppLogger.d('🔐 [AUTH_INIT] No Firebase user and no stored user');
          state = AuthState(isLoading: false);
        }
      }
    } catch (e) {
      AppLogger.e('🔐 [AUTH_INIT] Error', e);
      // Only sign out and clear if it's a critical error
      // Don't clear on network errors if we have stored user
      if (storedUser == null) {
        await FirebaseService.auth.signOut();
        await _storage.clearAll();
      }
      state = AuthState(isLoading: false, error: e.toString());
    } finally {
      // Mark initialization as complete
      _isInitializing = false;
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
    AppLogger.d('🔐 [AUTH_PROVIDER] ========== STARTING LOGOUT ==========');
    AppLogger.d('🔐 [AUTH_PROVIDER] Current state - isAuthenticated: ${state.isAuthenticated}');
    AppLogger.d('🔐 [AUTH_PROVIDER] Current state - user: ${state.user?.email ?? "null"}');
    
    state = state.copyWith(isLoading: true);

    try {
      // Unregister notification token before logout
      AppLogger.d('🔐 [AUTH_PROVIDER] Step 1: Unregistering notification token...');
      try {
        final notificationService = _ref.read(notificationServiceProvider);
        await notificationService.unregisterToken();
        AppLogger.d('🔐 [AUTH_PROVIDER] ✅ Step 1 Complete: Notification token unregistered');
      } catch (e) {
        AppLogger.e('🔐 [AUTH_PROVIDER] ⚠️ Step 1 Error: Error unregistering notification token', e);
        // Don't fail logout if notification unregister fails
      }
      
      // Call auth service logout
      AppLogger.d('🔐 [AUTH_PROVIDER] Step 2: Calling auth service logout...');
      await _authService.logout();
      AppLogger.d('🔐 [AUTH_PROVIDER] ✅ Step 2 Complete: Auth service logout called');
    } catch (e, stackTrace) {
      AppLogger.e('🔐 [AUTH_PROVIDER] ⚠️ Error during logout process', e, stackTrace);
      // Continue with storage clearing even if logout fails
    }

    // Clear all storage
    await _storage.clearAll();
    
    // CRITICAL: Invalidate API client provider to clear token cache
    // This ensures the next sign-in gets a fresh token, not a cached one from previous account
    _ref.invalidate(dioProvider);
    
    // Update state
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
      AppLogger.d('📬 [AUTH] Initializing notifications...');
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.initialize();
      AppLogger.d('📬 [AUTH] Notifications initialized successfully');
    } catch (e) {
      AppLogger.e('📬 [AUTH] Error initializing notifications', e);
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

