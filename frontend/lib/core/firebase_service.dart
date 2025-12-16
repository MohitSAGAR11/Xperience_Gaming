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
    try {
      AppLogger.d('🔐 [GOOGLE] Starting Google Sign-In...');
      
      // Initialize Google Sign-In
      // Use server client ID from google-services.json (client_type: 3)
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: '180127542-8itp58lc8epvmv6iabicrabvmvepudk9.apps.googleusercontent.com',
      );
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        AppLogger.d('🔐 [GOOGLE] User canceled sign-in');
        return null;
      }
      
      AppLogger.d('🔐 [GOOGLE] Google user signed in: ${googleUser.email}');
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      AppLogger.d('🔐 [GOOGLE] Got Google auth tokens');
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      AppLogger.d('🔐 [GOOGLE] Created Firebase credential');
      
      // Sign in to Firebase with the Google credential
      final userCredential = await auth.signInWithCredential(credential);
      
      AppLogger.d('🔐 [GOOGLE] Successfully signed in to Firebase');
      AppLogger.d('🔐 [GOOGLE] User ID: ${userCredential.user?.uid}');
      AppLogger.d('🔐 [GOOGLE] Email: ${userCredential.user?.email}');
      AppLogger.d('🔐 [GOOGLE] Display Name: ${userCredential.user?.displayName}');
      
      return userCredential;
    } catch (e) {
      AppLogger.e('🔐 [GOOGLE] Error during Google Sign-In', e);
      rethrow;
    }
  }
  
  /// Sign out from both Firebase and Google
  static Future<void> signOut() async {
    try {
      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      AppLogger.d('🔐 [GOOGLE] Signed out from Google');
      
      // Sign out from Firebase
      await auth.signOut();
      AppLogger.d('🔐 [FIREBASE] Signed out from Firebase');
    } catch (e) {
      AppLogger.e('🔐 [FIREBASE] Error during sign out', e);
      rethrow;
    }
  }
}

