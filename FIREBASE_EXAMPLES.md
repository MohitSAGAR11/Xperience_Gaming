# 🔥 Firebase Implementation Examples

Example code snippets showing how to implement Firebase in your project.

---

## Backend Examples

### 1. Firebase Admin Initialization

**File: `backend/src/config/firebase.js`**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('../../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = { db, auth, admin };
```

### 2. Updated Auth Middleware

**File: `backend/src/middleware/authMiddleware.js`**
```javascript
const { auth } = require('../config/firebase');

const protect = async (req, res, next) => {
  try {
    let token;
    
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized, no token provided'
      });
    }
    
    // Verify Firebase token
    const decodedToken = await auth.verifyIdToken(token);
    
    // Get user data from Firestore
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();
    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }
    
    req.user = {
      id: decodedToken.uid,
      ...userDoc.data()
    };
    next();
  } catch (error) {
    console.error('Auth middleware error:', error.message);
    return res.status(401).json({
      success: false,
      message: 'Not authorized, token invalid'
    });
  }
};

const ownerOnly = (req, res, next) => {
  if (req.user && req.user.role === 'owner') {
    next();
  } else {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Owner role required.'
    });
  }
};

module.exports = { protect, ownerOnly };
```

### 3. Cafe Controller with Firestore

**File: `backend/src/controllers/cafeController.js` (Example)**
```javascript
const { db } = require('../config/firebase');
const admin = require('firebase-admin');

// Get all cafes
const getCafes = async (req, res) => {
  try {
    const { city, search, limit = 10, offset = 0 } = req.query;
    
    let query = db.collection('cafes').where('isActive', '==', true);
    
    if (city) {
      query = query.where('city', '==', city);
    }
    
    if (search) {
      // Firestore doesn't support full-text search natively
      // You'll need to use Algolia or implement client-side filtering
      query = query.where('name', '>=', search)
                   .where('name', '<=', search + '\uf8ff');
    }
    
    const snapshot = await query.limit(parseInt(limit)).offset(parseInt(offset)).get();
    const cafes = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({
      success: true,
      data: cafes,
      count: cafes.length
    });
  } catch (error) {
    console.error('Get cafes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

// Create cafe
const createCafe = async (req, res) => {
  try {
    const cafeData = {
      ...req.body,
      ownerId: req.user.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      rating: 0,
      totalReviews: 0,
      isActive: true
    };
    
    const docRef = await db.collection('cafes').add(cafeData);
    
    res.status(201).json({
      success: true,
      message: 'Cafe created successfully',
      data: {
        id: docRef.id,
        ...cafeData
      }
    });
  } catch (error) {
    console.error('Create cafe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

module.exports = { getCafes, createCafe };
```

---

## Frontend Examples

### 1. Firebase Service

**File: `frontend/lib/core/firebase_service.dart`**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Auth
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Collections
  static CollectionReference get users => _firestore.collection('users');
  static CollectionReference get cafes => _firestore.collection('cafes');
  static CollectionReference get bookings => _firestore.collection('bookings');
  static CollectionReference get reviews => _firestore.collection('reviews');
  
  // Helper methods
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }
}
```

### 2. Updated Auth Service

**File: `frontend/lib/services/auth_service.dart`**
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Register a new user
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user == null) {
        return AuthResponse(
          success: false,
          message: 'Failed to create user',
        );
      }
      
      // Create user document in Firestore
      final userData = {
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'avatar': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseService.users.doc(user.uid).set(userData);
      
      // Get user document
      final userDoc = await FirebaseService.users.doc(user.uid).get();
      final userModel = User.fromFirestore(userDoc);
      
      return AuthResponse(
        success: true,
        message: 'Registration successful',
        user: userModel,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      }
      return AuthResponse(success: false, message: message);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }
  
  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user == null) {
        return AuthResponse(
          success: false,
          message: 'Login failed',
        );
      }
      
      // Get user document from Firestore
      final userDoc = await FirebaseService.users.doc(user.uid).get();
      if (!userDoc.exists) {
        return AuthResponse(
          success: false,
          message: 'User data not found',
        );
      }
      
      final userModel = User.fromFirestore(userDoc);
      
      return AuthResponse(
        success: true,
        message: 'Login successful',
        user: userModel,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      }
      return AuthResponse(success: false, message: message);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }
  
  /// Logout user
  Future<bool> logout() async {
    try {
      await _auth.signOut();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get current user profile
  Future<AuthResponse> getProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResponse(
          success: false,
          message: 'Not authenticated',
        );
      }
      
      final userDoc = await FirebaseService.users.doc(user.uid).get();
      if (!userDoc.exists) {
        return AuthResponse(
          success: false,
          message: 'User data not found',
        );
      }
      
      final userModel = User.fromFirestore(userDoc);
      return AuthResponse(
        success: true,
        user: userModel,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: e.toString(),
      );
    }
  }
}
```

### 3. Updated Auth Provider

**File: `frontend/lib/providers/auth_provider.dart`**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  
  AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });
  
  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  final AuthService _authService;
  
  AuthProvider(this._authService) : super(AuthState()) {
    _init();
  }
  
  void _init() {
    // Listen to Firebase Auth state changes
    FirebaseService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        // Get user data from Firestore
        final userDoc = await FirebaseService.users.doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          state = AuthState(
            user: userModel,
            isAuthenticated: true,
            isLoading: false,
          );
        }
      } else {
        state = AuthState(isAuthenticated: false, isLoading: false);
      }
    });
  }
  
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final response = await _authService.register(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
    );
    
    if (response.success && response.user != null) {
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
  }
  
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final response = await _authService.login(
      email: email,
      password: password,
    );
    
    if (response.success && response.user != null) {
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
  }
  
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    state = AuthState(isLoading: false);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthProvider(authService);
});
```

### 4. Cafe Service with Firestore

**File: `frontend/lib/services/cafe_service.dart` (Example)**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../models/cafe_model.dart';

class CafeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get all cafes
  Stream<List<CafeModel>> getCafes({
    String? city,
    String? search,
    int limit = 10,
  }) {
    Query query = FirebaseService.cafes.where('isActive', isEqualTo: true);
    
    if (city != null) {
      query = query.where('city', isEqualTo: city);
    }
    
    if (search != null && search.isNotEmpty) {
      query = query.where('name', isGreaterThanOrEqualTo: search)
                   .where('name', isLessThanOrEqualTo: '$search\uf8ff');
    }
    
    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CafeModel.fromFirestore(doc)).toList();
    });
  }
  
  /// Get nearby cafes (requires geohash implementation)
  Future<List<CafeModel>> getNearbyCafes({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    // Note: Firestore doesn't support native geospatial queries
    // You'll need to use GeoFirestore or implement geohash
    // This is a simplified example
    
    // For now, fetch all cafes and filter client-side
    // In production, use GeoFirestore library
    final snapshot = await FirebaseService.cafes
        .where('isActive', isEqualTo: true)
        .get();
    
    final cafes = snapshot.docs
        .map((doc) => CafeModel.fromFirestore(doc))
        .where((cafe) {
          // Calculate distance (Haversine formula)
          final distance = _calculateDistance(
            latitude,
            longitude,
            cafe.latitude,
            cafe.longitude,
          );
          return distance <= radiusKm;
        })
        .toList();
    
    return cafes;
  }
  
  /// Create cafe
  Future<String> createCafe(CafeModel cafe) async {
    final docRef = await FirebaseService.cafes.add(cafe.toFirestore());
    return docRef.id;
  }
  
  /// Update cafe
  Future<void> updateCafe(String cafeId, Map<String, dynamic> data) async {
    await FirebaseService.cafes.doc(cafeId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Delete cafe
  Future<void> deleteCafe(String cafeId) async {
    await FirebaseService.cafes.doc(cafeId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Calculate distance using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        _toRadians(lat1).cos() *
            _toRadians(lat2).cos() *
            (dLon / 2).sin() *
            (dLon / 2).sin();
    final c = 2 * a.sqrt().asin();
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) => degrees * (3.14159265359 / 180);
}

extension on double {
  double sin() => this; // Simplified - use dart:math in real implementation
  double cos() => this; // Simplified - use dart:math in real implementation
  double asin() => this; // Simplified - use dart:math in real implementation
  double sqrt() => this; // Simplified - use dart:math in real implementation
}
```

### 5. Updated User Model

**File: `frontend/lib/models/user_model.dart` (Add methods)**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // ... existing fields ...
  
  // Add Firestore conversion methods
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'client',
      phone: data['phone'],
      avatar: data['avatar'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar': avatar,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
```

### 6. Main.dart Firebase Initialization

**File: `frontend/lib/main.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

---

## Firestore Security Rules Example

**File: `firestore.rules`**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is owner
    function isOwner() {
      return request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner';
    }
    
    // Helper function to get user role
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && 
        (request.auth.uid == userId || isOwner());
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Cafes collection
    match /cafes/{cafeId} {
      allow read: if true; // Public read
      allow create: if request.auth != null && isOwner();
      allow update, delete: if request.auth != null && 
        resource.data.ownerId == request.auth.uid;
    }
    
    // Bookings collection
    match /bookings/{bookingId} {
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid ||
         get(/databases/$(database)/documents/cafes/$(resource.data.cafeId)).data.ownerId == request.auth.uid);
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
        (resource.data.userId == request.auth.uid ||
         get(/databases/$(database)/documents/cafes/$(resource.data.cafeId)).data.ownerId == request.auth.uid);
    }
    
    // Reviews collection
    match /reviews/{reviewId} {
      allow read: if true; // Public read
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## Notes

- **Geospatial Queries**: Use [GeoFirestore](https://pub.dev/packages/geofirestore) package for location-based queries
- **Real-time Updates**: Use `.snapshots()` for real-time listeners instead of polling
- **Offline Support**: Firestore has built-in offline persistence - enable it in initialization
- **Error Handling**: Always handle Firebase exceptions properly
- **Security Rules**: Test security rules thoroughly before deploying

