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
    
    // Enable Firestore offline persistence
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
  
  /// Get current Firebase user
  static User? get currentUser => auth.currentUser;
  
  /// Auth state changes stream
  static Stream<User?> get authStateChanges => auth.authStateChanges();
  
  /// Get Firebase ID token for backend authentication
  static Future<String?> getIdToken() async {
    final user = auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }
}

