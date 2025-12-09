# 🔥 Firebase Migration Checklist

Quick reference checklist of all files that need to be created, modified, or removed.

## 📦 Dependencies to Add

### Backend (`backend/package.json`)
```json
"firebase-admin": "^12.0.0"
```

**Remove:**
- `pg`, `pg-hstore`, `sequelize` (if removing backend)
- `bcryptjs`, `jsonwebtoken` (handled by Firebase)

### Frontend (`frontend/pubspec.yaml`)
```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
firebase_storage: ^12.0.0
```

---

## 🆕 New Files to Create

### Backend
- [ ] `backend/firebase-service-account.json` (download from Firebase Console)
- [ ] `backend/src/config/firebase.js` (Firebase Admin initialization)
- [ ] `backend/scripts/migrate-to-firestore.js` (data migration script - optional)

### Frontend
- [ ] `frontend/android/app/google-services.json` (download from Firebase Console)
- [ ] `frontend/ios/Runner/GoogleService-Info.plist` (download from Firebase Console)
- [ ] `frontend/lib/core/firebase_service.dart` (Firebase initialization and helpers)
- [ ] `frontend/lib/services/firebase_auth_service.dart` (Firebase Auth wrapper)
- [ ] `frontend/lib/services/firebase_firestore_service.dart` (Firestore operations)

### Firebase Configuration
- [ ] `firestore.rules` (Security rules file)
- [ ] `firestore.indexes.json` (Index definitions)

---

## ✏️ Files to Modify

### Backend

#### Configuration
- [ ] `backend/server.js`
  - Remove: `connectDB()` call
  - Add: Firebase Admin initialization
  - Update: CORS if needed

- [ ] `backend/src/config/firebase.js` (CREATE)
  - Initialize Firebase Admin SDK
  - Export Firestore instance

#### Middleware
- [ ] `backend/src/middleware/authMiddleware.js`
  - Replace JWT verification with Firebase token verification
  - Update `protect()` function
  - Update `ownerOnly()` function

#### Controllers
- [ ] `backend/src/controllers/authController.js`
  - **Option A**: Remove entirely (if going full client-side)
  - **Option B**: Keep minimal endpoints, verify Firebase tokens

- [ ] `backend/src/controllers/cafeController.js`
  - Replace Sequelize queries with Firestore Admin SDK
  - Update all CRUD operations
  - Handle geospatial queries (geohash or GeoFirestore)

- [ ] `backend/src/controllers/bookingController.js`
  - Replace Sequelize queries with Firestore Admin SDK
  - Update availability checking logic
  - Handle Firestore transactions for conflict prevention

- [ ] `backend/src/controllers/reviewController.js`
  - Replace Sequelize queries with Firestore Admin SDK
  - Update rating calculation logic

#### Routes
- [ ] `backend/src/routes/authRoutes.js`
  - Remove or simplify (auth handled by Firebase)

- [ ] `backend/src/routes/cafeRoutes.js`
  - Routes remain same, but controllers use Firestore

- [ ] `backend/src/routes/bookingRoutes.js`
  - Routes remain same, but controllers use Firestore

- [ ] `backend/src/routes/reviewRoutes.js`
  - Routes remain same, but controllers use Firestore

### Frontend

#### Core
- [ ] `frontend/lib/main.dart`
  - Initialize Firebase: `await Firebase.initializeApp()`
  - Update providers initialization

- [ ] `frontend/lib/core/firebase_service.dart` (CREATE)
  - Firebase Auth instance
  - Firestore instance
  - Collection references

- [ ] `frontend/lib/core/storage.dart`
  - Remove JWT token methods
  - Keep user data caching (optional)
  - Remove `saveToken()`, `getToken()`, `deleteToken()`

- [ ] `frontend/lib/core/api_client.dart`
  - **Option A**: Remove entirely (if going full client-side)
  - **Option B**: Keep for external APIs only

#### Services
- [ ] `frontend/lib/services/auth_service.dart`
  - Replace API calls with Firebase Auth methods
  - Use `FirebaseAuth.instance.signInWithEmailAndPassword()`
  - Use `FirebaseAuth.instance.createUserWithEmailAndPassword()`
  - Store user profile in Firestore `users` collection

- [ ] `frontend/lib/services/cafe_service.dart`
  - Replace API calls with Firestore queries
  - Use `FirebaseService.cafes.collection()` for CRUD
  - Implement geospatial queries (geohash or GeoFirestore)

- [ ] `frontend/lib/services/booking_service.dart`
  - Replace API calls with Firestore queries
  - Use Firestore transactions for booking creation
  - Implement real-time listeners for availability

- [ ] `frontend/lib/services/review_service.dart`
  - Replace API calls with Firestore queries
  - Use Firestore batch writes for rating updates

#### Providers
- [ ] `frontend/lib/providers/auth_provider.dart`
  - Use `FirebaseAuth.instance.authStateChanges()` stream
  - Remove API-based login/register
  - Update state management for Firebase Auth

- [ ] `frontend/lib/providers/cafe_provider.dart`
  - Use Firestore `.snapshots()` for real-time updates
  - Replace API calls with Firestore queries

- [ ] `frontend/lib/providers/booking_provider.dart`
  - Use Firestore `.snapshots()` for real-time updates
  - Replace API calls with Firestore queries

- [ ] `frontend/lib/providers/review_provider.dart`
  - Use Firestore `.snapshots()` for real-time updates
  - Replace API calls with Firestore queries

#### Models
- [ ] `frontend/lib/models/user_model.dart`
  - Add `fromFirestore()` and `toFirestore()` methods
  - Keep existing structure (mostly compatible)

- [ ] `frontend/lib/models/cafe_model.dart`
  - Add `fromFirestore()` and `toFirestore()` methods
  - Update for Firestore data types (Timestamp, GeoPoint)

- [ ] `frontend/lib/models/booking_model.dart`
  - Add `fromFirestore()` and `toFirestore()` methods
  - Update for Firestore Timestamp types

- [ ] `frontend/lib/models/review_model.dart`
  - Add `fromFirestore()` and `toFirestore()` methods
  - Update for Firestore Timestamp types

#### Config
- [ ] `frontend/lib/config/constants.dart`
  - Remove `ApiConstants` class (or keep for external APIs)
  - Keep `AppConstants` (still needed)

#### Screens
- [ ] `frontend/lib/screens/auth/login_screen.dart`
  - Update to use Firebase Auth directly
  - Handle Firebase Auth errors

- [ ] `frontend/lib/screens/auth/register_screen.dart`
  - Update to use Firebase Auth directly
  - Create user document in Firestore after registration

- [ ] All screens using API calls
  - Update to use Firebase providers/services
  - Handle Firestore errors appropriately

---

## 🗑️ Files to Remove (if going full client-side)

### Backend
- [ ] `backend/src/config/db.js` (PostgreSQL connection)
- [ ] `backend/src/models/User.js`
- [ ] `backend/src/models/Cafe.js`
- [ ] `backend/src/models/Booking.js`
- [ ] `backend/src/models/Review.js`
- [ ] `backend/src/models/index.js`
- [ ] `backend/src/controllers/authController.js` (handled by Firebase)

### Frontend
- [ ] `frontend/lib/core/api_client.dart` (if not using external APIs)

---

## 🔧 Configuration Files

### Android
- [ ] `frontend/android/build.gradle.kts`
  - Add Google Services plugin
  - Add classpath for Google Services

- [ ] `frontend/android/app/build.gradle.kts`
  - Apply Google Services plugin
  - Add Firebase dependencies

### iOS
- [ ] `frontend/ios/Podfile`
  - Add Firebase pods (usually auto-added)

- [ ] `frontend/ios/Runner/Info.plist`
  - May need additional permissions

### Environment
- [ ] `backend/.env`
  - Remove: `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `JWT_SECRET`
  - Add: `FIREBASE_PROJECT_ID` (if needed)

---

## 📋 Migration Order (Recommended)

1. **Setup Phase**
   - [ ] Create Firebase project
   - [ ] Install dependencies
   - [ ] Add configuration files

2. **Authentication Migration**
   - [ ] Initialize Firebase in frontend
   - [ ] Replace auth service
   - [ ] Update auth provider
   - [ ] Test login/register/logout

3. **Database Migration (One feature at a time)**
   - [ ] Migrate User data structure
   - [ ] Migrate Cafe CRUD operations
   - [ ] Migrate Booking operations
   - [ ] Migrate Review operations

4. **Backend Cleanup (if removing backend)**
   - [ ] Remove unused dependencies
   - [ ] Remove database models
   - [ ] Remove API routes (or convert to Cloud Functions)

5. **Testing & Optimization**
   - [ ] Test all features
   - [ ] Set up Firestore Security Rules
   - [ ] Create Firestore indexes
   - [ ] Enable offline persistence
   - [ ] Performance testing

---

## 🎯 Quick Start Commands

### Backend
```bash
cd backend
npm install firebase-admin
# Download firebase-service-account.json from Firebase Console
```

### Frontend
```bash
cd frontend
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage
# Add google-services.json and GoogleService-Info.plist
flutter pub get
```

---

## 📝 Notes

- **Geospatial Queries**: Firestore doesn't support native geospatial queries. Consider using GeoFirestore or geohash.
- **Real-time Updates**: Use Firestore `.snapshots()` for real-time data instead of polling.
- **Offline Support**: Firestore has built-in offline persistence - enable it.
- **Security Rules**: Always set up proper Firestore Security Rules before deploying.
- **Indexes**: Create composite indexes for complex queries in Firebase Console.

