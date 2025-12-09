import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Service - Initialization and helpers
class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  
  /// Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    // Note: Firebase Auth persistence is automatic on mobile platforms
    // On mobile (iOS/Android), auth state persists by default
    // setPersistence() is only for web platforms
    print('🔐 [FIREBASE] Firebase initialized with automatic auth persistence');
    
    // Enable Firestore offline persistence
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    print('🔐 [FIREBASE] Firestore persistence enabled');
  }
  
  /// Get current Firebase user
  static User? get currentUser => auth.currentUser;
  
  /// Auth state changes stream
  static Stream<User?> get authStateChanges => auth.authStateChanges();
  
  /// Get Firebase ID token for backend authentication
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = auth.currentUser;
    if (user == null) return null;
    try {
      final token = await user.getIdToken(forceRefresh);
      if (forceRefresh) {
        print('🔐 [FIREBASE] Token force refreshed');
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

