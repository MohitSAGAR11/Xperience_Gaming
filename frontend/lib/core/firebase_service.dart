import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

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
    print('🔐 [FIREBASE] Firebase initialized with automatic auth persistence');
    
    // Enable Firestore offline persistence
    // Configure this first before any Firestore operations
    try {
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('🔐 [FIREBASE] Firestore persistence enabled');
    } catch (e) {
      print('🔐 [FIREBASE] Warning: Could not configure Firestore persistence: $e');
    }
    
    // DEVELOPMENT ONLY: Disable app verification in debug mode
    // This prevents the "empty reCAPTCHA token" timeout issue during development
    // IMPORTANT: This is automatically disabled in production builds (kDebugMode = false)
    if (kDebugMode) {
      try {
        await auth.setSettings(appVerificationDisabledForTesting: true);
        print('🔐 [FIREBASE] [DEBUG MODE] App verification disabled for testing');
      } catch (e) {
        print('🔐 [FIREBASE] Warning: Could not disable app verification: $e');
      }
    } else {
      print('🔐 [FIREBASE] [PRODUCTION MODE] App verification enabled for security');
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
      print('🔐 [FIREBASE] ERROR: No current user when getting token!');
      return null;
    }
    try {
      print('🔐 [FIREBASE] Getting token for user: ${user.uid}');
      final token = await user.getIdToken(forceRefresh);
      if (token != null) {
        print('🔐 [FIREBASE] Token obtained successfully (length: ${token.length})');
        if (forceRefresh) {
          print('🔐 [FIREBASE] Token force refreshed');
        }
      } else {
        print('🔐 [FIREBASE] WARNING: Token is null!');
      }
      return token;
    } catch (e) {
      print('🔐 [FIREBASE] Error getting token: $e');
      return null;
    }
  }
  
  /// Refresh the current user's token
  static Future<void> refreshToken() async {
    final user = auth.currentUser;
    if (user != null) {
      await user.getIdToken(true);
      print('🔐 [FIREBASE] Token refreshed for user: ${user.uid}');
    }
  }
}

