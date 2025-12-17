import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';
import 'logger.dart';

/// Firebase Service - Initialization and helpers
class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  
  /// Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Note: Firebase Auth persistence is automatic on mobile platforms
    // On mobile (iOS/Android), auth state persists by default
    // setPersistence() is only for web platforms
    AppLogger.d('🔐 [FIREBASE] Firebase initialized with automatic auth persistence');
    
    // Enable Firestore offline persistence
    // Configure this first before any Firestore operations
    try {
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      AppLogger.d('🔐 [FIREBASE] Firestore persistence enabled');
    } catch (e) {
      AppLogger.w('🔐 [FIREBASE] Warning: Could not configure Firestore persistence', e);
    }
    
    // DEVELOPMENT ONLY: Disable app verification in debug mode
    // This prevents the "empty reCAPTCHA token" timeout issue during development
    // IMPORTANT: This is automatically disabled in production builds (kDebugMode = false)
    if (kDebugMode) {
      try {
        await auth.setSettings(appVerificationDisabledForTesting: true);
        AppLogger.d('🔐 [FIREBASE] [DEBUG MODE] App verification disabled for testing');
      } catch (e) {
        AppLogger.w('🔐 [FIREBASE] Warning: Could not disable app verification', e);
      }
    } else {
      AppLogger.d('🔐 [FIREBASE] [PRODUCTION MODE] App verification enabled for security');
    }
  }
  
  /// Get current Firebase user
  static User? get currentUser => auth.currentUser;
  
  /// Auth state changes stream
  static Stream<User?> get authStateChanges => auth.authStateChanges();
  
  /// Get Firebase ID token for backend authentication
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = auth.currentUser;
    if (user == null) {
      AppLogger.e('🔐 [FIREBASE] ERROR: No current user when getting token!');
      return null;
    }
    try {
      AppLogger.d('🔐 [FIREBASE] Getting token for user: ${user.uid}');
      final token = await user.getIdToken(forceRefresh);
      if (token != null) {
        AppLogger.d('🔐 [FIREBASE] Token obtained successfully (length: ${token.length})');
        if (forceRefresh) {
          AppLogger.d('🔐 [FIREBASE] Token force refreshed');
        }
      } else {
        AppLogger.w('🔐 [FIREBASE] WARNING: Token is null!');
      }
      return token;
    } catch (e) {
      AppLogger.e('🔐 [FIREBASE] Error getting token', e);
      return null;
    }
  }
  
  /// Refresh the current user's token
  static Future<void> refreshToken() async {
    final user = auth.currentUser;
    if (user != null) {
      await user.getIdToken(true);
      AppLogger.d('🔐 [FIREBASE] Token refreshed for user: ${user.uid}');
    }
  }
  
  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    AppLogger.d('🔐 [GOOGLE_SIGNIN] ========== STARTING GOOGLE SIGN-IN ==========');
    
    try {
      // Check current Firebase state
      final currentFirebaseUser = auth.currentUser;
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Current Firebase user before sign-in: ${currentFirebaseUser?.uid ?? "null"}');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Current Firebase user email: ${currentFirebaseUser?.email ?? "null"}');
      
      // Initialize Google Sign-In
      // Use server client ID from google-services.json (client_type: 3)
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: '180127542-8itp58lc8epvmv6iabicrabvmvepudk9.apps.googleusercontent.com',
      );
      
      AppLogger.d('🔐 [GOOGLE_SIGNIN] GoogleSignIn instance created');
      
      // Check if there's a previously signed-in account and disconnect it
      // This ensures the account picker is shown on next sign-in
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Step 1: Checking for previously signed-in account...');
      try {
        final currentAccount = await googleSignIn.signInSilently();
        if (currentAccount != null) {
          AppLogger.w('🔐 [GOOGLE_SIGNIN] ⚠️ Found previously signed-in account!');
          AppLogger.w('🔐 [GOOGLE_SIGNIN] Previous account email: ${currentAccount.email}');
          AppLogger.w('🔐 [GOOGLE_SIGNIN] Previous account ID: ${currentAccount.id}');
          AppLogger.w('🔐 [GOOGLE_SIGNIN] Previous account display name: ${currentAccount.displayName}');
          AppLogger.d('🔐 [GOOGLE_SIGNIN] Disconnecting previous account...');
          await googleSignIn.disconnect();
          AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ Previous account disconnected');
          
          // Verify disconnect worked
          try {
            final accountAfterDisconnect = await googleSignIn.signInSilently();
            if (accountAfterDisconnect != null) {
              AppLogger.w('🔐 [GOOGLE_SIGNIN] ⚠️ WARNING: Account still accessible after disconnect: ${accountAfterDisconnect.email}');
            } else {
              AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ Verified: No account accessible after disconnect');
            }
          } catch (e) {
            AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ Verified: signInSilently() failed (expected after disconnect): $e');
          }
        } else {
          AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ No previous account found');
        }
      } catch (e) {
        // No previous account or error - this is fine, continue with sign-in
        AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ No previous account found or error (expected): $e');
      }
      
      // Trigger the authentication flow (will show account picker)
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Step 2: Calling googleSignIn.signIn() - should show account picker...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        AppLogger.d('🔐 [GOOGLE_SIGNIN] ❌ User canceled sign-in');
        AppLogger.d('🔐 [GOOGLE_SIGNIN] ========== SIGN-IN CANCELLED ==========');
        return null;
      }
      
      AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ User selected account');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Selected account email: ${googleUser.email}');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Selected account ID: ${googleUser.id}');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Selected account display name: ${googleUser.displayName}');
      
      // Check if this is the same account that was previously signed in
      if (currentFirebaseUser != null && currentFirebaseUser.email == googleUser.email) {
        AppLogger.w('🔐 [GOOGLE_SIGNIN] ⚠️ WARNING: User selected the same account that was already signed in!');
      }
      
      // Obtain the auth details from the request
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Step 3: Getting authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ Got Google auth tokens');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Has access token: ${googleAuth.accessToken != null}');
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Has ID token: ${googleAuth.idToken != null}');
      
      // Create a new credential
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Step 4: Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      AppLogger.d('🔐 [GOOGLE_SIGNIN] ✅ Created Firebase credential');
      
      // Sign in to Firebase with the Google credential
      AppLogger.d('🔐 [GOOGLE_SIGNIN] Step 5: Signing in to Firebase...');
      final userCredential = await auth.signInWithCredential(credential);
      
      // CRITICAL: Force token refresh to ensure we get a fresh token for the new user
      // This prevents using a cached token from a previous account
      await refreshToken();
      
      return userCredential;
    } catch (e, stackTrace) {
      AppLogger.e('🔐 [GOOGLE_SIGNIN] ❌ ERROR during Google Sign-In', e, stackTrace);
      AppLogger.d('🔐 [GOOGLE_SIGNIN] ========== SIGN-IN FAILED ==========');
      rethrow;
    }
  }
  
  /// Sign out from both Firebase and Google
  static Future<void> signOut() async {
    AppLogger.d('🔐 [SIGNOUT] ========== STARTING SIGNOUT PROCESS ==========');
    
    try {
      // Check current state before sign out
      final currentFirebaseUser = auth.currentUser;
      AppLogger.d('🔐 [SIGNOUT] Current Firebase user before sign out: ${currentFirebaseUser?.uid ?? "null"}');
      AppLogger.d('🔐 [SIGNOUT] Current Firebase user email: ${currentFirebaseUser?.email ?? "null"}');
      
      // Sign out and disconnect from Google to clear account cache
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: '180127542-8itp58lc8epvmv6iabicrabvmvepudk9.apps.googleusercontent.com',
      );
      
      // Check if there's a currently signed-in Google account
      AppLogger.d('🔐 [SIGNOUT] Checking for signed-in Google account...');
      try {
        final currentGoogleAccount = await googleSignIn.signInSilently();
        if (currentGoogleAccount != null) {
          AppLogger.d('🔐 [SIGNOUT] Found signed-in Google account: ${currentGoogleAccount.email}');
          AppLogger.d('🔐 [SIGNOUT] Google account ID: ${currentGoogleAccount.id}');
        } else {
          AppLogger.d('🔐 [SIGNOUT] No signed-in Google account found');
        }
      } catch (e) {
        AppLogger.d('🔐 [SIGNOUT] Error checking Google account (may not be signed in): $e');
      }
      
      // First sign out (clears current session)
      AppLogger.d('🔐 [SIGNOUT] Step 1: Calling googleSignIn.signOut()...');
      await googleSignIn.signOut();
      AppLogger.d('🔐 [SIGNOUT] ✅ Step 1 Complete: Signed out from Google');
      
      // Then disconnect (clears cached account, forces account picker on next sign-in)
      // Note: disconnect() may fail on Android if account is already signed out, which is fine
      try {
        await googleSignIn.disconnect();
      } catch (disconnectError) {
        // disconnect() may fail on Android - this is often okay if signOut() already worked
        // Try one more time with a fresh instance
        try {
          final freshGoogleSignIn = GoogleSignIn(
            scopes: ['email'],
            serverClientId: '180127542-8itp58lc8epvmv6iabicrabvmvepudk9.apps.googleusercontent.com',
          );
          await freshGoogleSignIn.disconnect();
        } catch (retryError) {
          // Continue anyway - signOut() already worked, which is the most important part
        }
      }
      
      // Sign out from Firebase
      AppLogger.d('🔐 [SIGNOUT] Step 3: Calling auth.signOut()...');
      await auth.signOut();
      AppLogger.d('🔐 [SIGNOUT] ✅ Step 3 Complete: Signed out from Firebase');
      
      // Verify Firebase sign out
      final userAfterFirebaseSignOut = auth.currentUser;
      if (userAfterFirebaseSignOut == null) {
        AppLogger.d('🔐 [SIGNOUT] ✅ Verified: No Firebase user after signOut()');
      } else {
        AppLogger.w('🔐 [SIGNOUT] ⚠️ WARNING: Firebase user still exists after signOut(): ${userAfterFirebaseSignOut.uid}');
      }
      
      AppLogger.d('🔐 [SIGNOUT] ========== SIGNOUT PROCESS COMPLETE ==========');
    } catch (e, stackTrace) {
      AppLogger.e('🔐 [SIGNOUT] ❌ ERROR during sign out', e, stackTrace);
      // Don't rethrow - try to continue with Firebase sign out even if Google disconnect fails
      try {
        AppLogger.d('🔐 [SIGNOUT] Attempting Firebase sign out after error...');
        await auth.signOut();
        AppLogger.d('🔐 [SIGNOUT] ✅ Signed out from Firebase (after Google error)');
      } catch (firebaseError) {
        AppLogger.e('🔐 [SIGNOUT] ❌ Error during Firebase sign out', firebaseError);
        rethrow;
      }
    }
  }
}

