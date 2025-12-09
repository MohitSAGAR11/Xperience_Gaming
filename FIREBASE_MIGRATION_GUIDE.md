# 🔥 Firebase Migration Guide

This document outlines all the changes needed to migrate from PostgreSQL/Sequelize + JWT Auth to Firebase Authentication + Firestore Database.

## 📋 Overview

**Current Stack:**
- Backend: Node.js/Express with PostgreSQL + Sequelize ORM
- Authentication: JWT tokens with bcrypt password hashing
- Frontend: Flutter app making REST API calls

**Target Stack:**
- Backend: Node.js/Express with Firebase Admin SDK (optional - can be removed if going full client-side)
- Authentication: Firebase Authentication
- Database: Cloud Firestore
- Frontend: Flutter app using Firebase SDK directly

---

## 🎯 Migration Strategy Options

### Option 1: Full Client-Side (Recommended for Flutter)
- Remove backend entirely or keep minimal serverless functions
- Use Firebase SDK directly in Flutter app
- Use Firestore Security Rules for authorization
- Use Firebase Cloud Functions for complex operations (if needed)

### Option 2: Hybrid Approach
- Keep Express backend for complex business logic
- Use Firebase Admin SDK in backend
- Frontend uses Firebase Auth SDK
- Backend verifies Firebase tokens

**This guide assumes Option 1 (Full Client-Side) for simplicity and cost-effectiveness.**

---

## 📦 Step 1: Install Firebase Dependencies

### Backend (`backend/package.json`)
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    // Remove these:
    // "pg", "pg-hstore", "sequelize", "bcryptjs", "jsonwebtoken"
  }
}
```

### Frontend (`frontend/pubspec.yaml`)
```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0  # For file uploads (avatars, cafe photos)
```

---

## 🔧 Step 2: Firebase Project Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create new project: "XPerience Gaming"
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Enable Storage (for images)

2. **Get Configuration**
   - Project Settings → General → Your apps → Add Flutter app
   - Download `google-services.json` (Android)
   - Download `GoogleService-Info.plist` (iOS)

3. **Service Account (Backend only if keeping backend)**
   - Project Settings → Service Accounts
   - Generate new private key
   - Save as `backend/firebase-service-account.json`

---

## 📁 Step 3: File Structure Changes

### New Files to Create:
```
backend/
├── firebase-service-account.json  # Service account key (if keeping backend)
└── src/
    └── config/
        └── firebase.js            # Firebase Admin initialization

frontend/
├── android/app/google-services.json
├── ios/Runner/GoogleService-Info.plist
└── lib/
    └── core/
        └── firebase_service.dart  # Firebase initialization
```

### Files to Modify:
- All backend controllers → Use Firestore Admin SDK
- All backend models → Remove (Firestore is schema-less)
- Frontend services → Use Firebase SDK instead of API calls
- Frontend providers → Update to use Firebase streams
- Frontend storage → Use Firebase Auth state instead of JWT

### Files to Remove (if going full client-side):
- `backend/src/config/db.js`
- `backend/src/models/*`
- `backend/src/middleware/authMiddleware.js` (replace with Firestore Rules)
- Most backend routes (keep only Cloud Functions if needed)

---

## 🔐 Step 4: Authentication Changes

### Backend (if keeping backend)

**Replace `backend/src/middleware/authMiddleware.js`:**
```javascript
const admin = require('firebase-admin');

const protect = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token' });
    }
    
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: 'Invalid token' });
  }
};
```

**Remove `backend/src/controllers/authController.js`** - Auth handled by Firebase

### Frontend

**Create `frontend/lib/core/firebase_service.dart`:**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Auth methods
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Firestore collections
  static CollectionReference users = _firestore.collection('users');
  static CollectionReference cafes = _firestore.collection('cafes');
  static CollectionReference bookings = _firestore.collection('bookings');
  static CollectionReference reviews = _firestore.collection('reviews');
}
```

**Replace `frontend/lib/services/auth_service.dart`:**
- Remove API calls
- Use `FirebaseAuth.instance.signInWithEmailAndPassword()`
- Use `FirebaseAuth.instance.createUserWithEmailAndPassword()`
- Store user data in Firestore `users` collection

---

## 💾 Step 5: Database Schema Migration

### Firestore Collections Structure:

```
users/
  {userId}/
    - name: string
    - email: string
    - role: 'client' | 'owner'
    - phone: string?
    - avatar: string?
    - createdAt: timestamp
    - updatedAt: timestamp

cafes/
  {cafeId}/
    - ownerId: string (reference to users)
    - name: string
    - description: string
    - address: string
    - city: string
    - latitude: number
    - longitude: number
    - phone: string
    - email: string
    - openingHours: map
    - totalPcStations: number
    - pcHourlyRate: number
    - pcSpecs: map
    - pcGames: array
    - consoles: map
    - totalConsoles: number
    - photos: array
    - amenities: array
    - isActive: boolean
    - rating: number
    - totalReviews: number
    - createdAt: timestamp
    - updatedAt: timestamp

bookings/
  {bookingId}/
    - userId: string (reference to users)
    - cafeId: string (reference to cafes)
    - stationType: 'pc' | 'console'
    - stationId: string
    - consoleType: string? (if stationType is console)
    - startTime: timestamp
    - endTime: timestamp
    - duration: number (hours)
    - totalCost: number
    - status: 'pending' | 'confirmed' | 'cancelled' | 'completed'
    - paymentStatus: 'unpaid' | 'paid' | 'refunded'
    - createdAt: timestamp
    - updatedAt: timestamp

reviews/
  {reviewId}/
    - userId: string (reference to users)
    - cafeId: string (reference to cafes)
    - rating: number (1-5)
    - comment: string
    - createdAt: timestamp
```

### Firestore Indexes Needed:
- `cafes` collection: `latitude`, `longitude` (for geospatial queries)
- `bookings` collection: `cafeId`, `startTime`, `endTime` (for availability checks)
- `reviews` collection: `cafeId`, `createdAt` (for cafe reviews)

---

## 🛡️ Step 6: Firestore Security Rules

Create `firestore.rules`:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read their own data, owners can read all
    match /users/{userId} {
      allow read: if request.auth != null && 
        (request.auth.uid == userId || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner');
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Cafes: public read, owner write
    match /cafes/{cafeId} {
      allow read: if true; // Public read
      allow create: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner';
      allow update, delete: if request.auth != null && 
        resource.data.ownerId == request.auth.uid;
    }
    
    // Bookings: users can read their own, owners can read cafe bookings
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
    
    // Reviews: public read, authenticated write
    match /reviews/{reviewId} {
      allow read: if true;
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 🔄 Step 7: Code Changes Checklist

### Backend Changes:

- [ ] Install `firebase-admin`
- [ ] Create `backend/src/config/firebase.js` with Admin SDK initialization
- [ ] Update `backend/src/middleware/authMiddleware.js` to verify Firebase tokens
- [ ] Replace all Sequelize queries in controllers with Firestore Admin SDK
- [ ] Update `backend/src/controllers/authController.js` - Remove (handled by Firebase)
- [ ] Update `backend/src/controllers/cafeController.js` - Use Firestore
- [ ] Update `backend/src/controllers/bookingController.js` - Use Firestore
- [ ] Update `backend/src/controllers/reviewController.js` - Use Firestore
- [ ] Remove `backend/src/models/*` files
- [ ] Remove `backend/src/config/db.js`
- [ ] Update `backend/server.js` - Remove database connection, add Firebase init

### Frontend Changes:

- [ ] Add Firebase packages to `pubspec.yaml`
- [ ] Add `google-services.json` to Android project
- [ ] Add `GoogleService-Info.plist` to iOS project
- [ ] Create `lib/core/firebase_service.dart`
- [ ] Initialize Firebase in `lib/main.dart`
- [ ] Replace `lib/services/auth_service.dart` with Firebase Auth
- [ ] Replace `lib/services/cafe_service.dart` with Firestore queries
- [ ] Replace `lib/services/booking_service.dart` with Firestore queries
- [ ] Replace `lib/services/review_service.dart` with Firestore queries
- [ ] Update `lib/providers/auth_provider.dart` to use Firebase Auth streams
- [ ] Update `lib/providers/cafe_provider.dart` to use Firestore streams
- [ ] Update `lib/providers/booking_provider.dart` to use Firestore streams
- [ ] Update `lib/providers/review_provider.dart` to use Firestore streams
- [ ] Update `lib/core/storage.dart` - Remove JWT token storage, use Firebase Auth state
- [ ] Remove `lib/core/api_client.dart` (or keep for external APIs)
- [ ] Update all screens to use Firebase providers instead of API calls

---

## 📝 Step 8: Data Migration Script

If you have existing PostgreSQL data, create a migration script:

```javascript
// backend/scripts/migrate-to-firestore.js
const admin = require('firebase-admin');
const { sequelize, User, Cafe, Booking, Review } = require('../src/models');

admin.initializeApp({
  credential: admin.credential.cert(require('../firebase-service-account.json'))
});

const db = admin.firestore();

async function migrateUsers() {
  const users = await User.findAll();
  for (const user of users) {
    await db.collection('users').doc(user.id).set({
      name: user.name,
      email: user.email,
      role: user.role,
      phone: user.phone || null,
      avatar: user.avatar || null,
      createdAt: admin.firestore.Timestamp.fromDate(user.createdAt),
      updatedAt: admin.firestore.Timestamp.fromDate(user.updatedAt)
    });
  }
}

// Similar functions for cafes, bookings, reviews...
```

---

## 🚀 Step 9: Testing Checklist

- [ ] User registration with Firebase Auth
- [ ] User login with Firebase Auth
- [ ] User logout
- [ ] Create cafe (owner)
- [ ] List cafes
- [ ] Search cafes
- [ ] Nearby cafes (geospatial query)
- [ ] Create booking
- [ ] Check booking availability
- [ ] List user bookings
- [ ] Cancel booking
- [ ] Create review
- [ ] List cafe reviews
- [ ] Update user profile
- [ ] Firestore Security Rules work correctly
- [ ] Offline persistence (Firestore)

---

## ⚠️ Important Considerations

### Geospatial Queries
Firestore doesn't have native geospatial queries. Options:
1. Use GeoFirestore library
2. Use geohash for approximate location queries
3. Use Cloud Functions for complex geospatial queries

### Real-time Updates
Firestore provides real-time listeners - update providers to use `.snapshots()` instead of polling.

### Offline Support
Firestore has built-in offline persistence - enable in Firebase initialization.

### Costs
- Firebase Auth: Free tier includes 50K MAU
- Firestore: Free tier includes 50K reads/day, 20K writes/day
- Monitor usage in Firebase Console

### Performance
- Use Firestore indexes for complex queries
- Implement pagination with `limit()` and `startAfter()`
- Use composite indexes for multi-field queries

---

## 📚 Resources

- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Auth Flutter](https://firebase.flutter.dev/docs/auth/overview)
- [Cloud Firestore Flutter](https://firebase.flutter.dev/docs/firestore/overview)

---

## 🎯 Next Steps

1. Set up Firebase project
2. Install dependencies
3. Start with authentication migration
4. Migrate one feature at a time (cafes → bookings → reviews)
5. Test thoroughly before removing old code
6. Deploy Firestore Security Rules
7. Monitor Firebase Console for errors

