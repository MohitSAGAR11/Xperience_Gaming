# Google Sign-In Flow & Issues Analysis

## 📋 Complete Google Sign-In Flow

### Frontend Flow

1. **User Action** (`auth_screen.dart`)
   - User selects role (Client/Owner)
   - Clicks "Continue with Google" button
   - Calls `authProvider.signInWithGoogle(role: _selectedRole)`

2. **Auth Provider** (`auth_provider.dart`)
   - Sets loading state
   - Calls `authService.signInWithGoogle(role: role)`
   - On success: Refreshes profile, saves to storage, updates state
   - Navigates to appropriate screen (Owner Dashboard / Client Home)

3. **Auth Service** (`auth_service.dart`)
   - Calls `FirebaseService.signInWithGoogle()` to get Firebase credentials
   - Extracts user info: `displayName`, `email`, `photoURL`
   - Sends POST to `/auth/google-signin` with:
     ```json
     {
       "role": "client" | "owner",
       "isNewUser": boolean,
       "name": "User Name",
       "email": "user@example.com",
       "avatar": "https://photo-url.com"
     }
     ```
   - Receives user profile from backend
   - Returns `AuthResponse` with user data

4. **Firebase Service** (`firebase_service.dart`)
   - Initializes Google Sign-In
   - Disconnects previous account (if any)
   - Shows Google account picker
   - Gets Google auth tokens (access token, ID token)
   - Creates Firebase credential
   - Signs in to Firebase Auth
   - Returns `UserCredential`

### Backend Flow

1. **Route** (`authRoutes.js`)
   - `POST /api/auth/google-signin`
   - Uses `protectNewUser` middleware (allows new users)

2. **Middleware** (`authMiddleware.js` - `protectNewUser`)
   - Extracts `Authorization: Bearer <token>` header
   - Verifies Firebase ID token with retry logic
   - Attaches to `req.user`: `{ id: uid, email: email }`
   - **Note**: Does NOT check if user exists in Firestore (allows new users)

3. **Controller** (`authController.js` - `googleSignIn`)
   - Extracts: `role`, `name`, `email`, `avatar` from request body
   - **CRITICAL**: Uses `req.user.email` (from token) as source of truth
   - Validates role is 'client' or 'owner'
   - Checks if user exists in Firestore by `userId` (from token)

   **If User Exists:**
   - Validates email matches between token and Firestore
   - If mismatch: Updates Firestore with token email (data corruption fix)
   - Updates name if changed in Google profile
   - Updates avatar if changed in Google profile
   - Validates role matches (prevents role switching)
   - Returns user profile

   **If User Doesn't Exist:**
   - Creates new user profile in Firestore
   - Sets `verified: false` for owners, `undefined` for clients
   - Returns new user profile

---

## 🔍 Issues Found & Fixed

### ✅ Issue 1: Email Mismatch (FIXED)
**Problem**: Token email didn't match Firestore email, causing wrong user data to be returned.

**Root Cause**: Firestore document had wrong email stored (data corruption).

**Fix**: 
- Always use `req.user.email` (from verified token) as source of truth
- Validate email matches between token and Firestore
- Auto-correct Firestore if mismatch detected
- Added validation in `googleSignIn`, `getMe`, and `protect` middleware

### ✅ Issue 2: Email Priority (FIXED)
**Problem**: Code used `req.user.email || email` which could use request body email instead of token email.

**Fix**: 
- Always prioritize `req.user.email` (from token)
- Request body email is only for logging/comparison
- Added warning if request email doesn't match token email

### ✅ Issue 3: Name Not Synced (FIXED)
**Problem**: If user changed name in Google, it wasn't updated in Firestore for existing users.

**Fix**: 
- Check if name changed and update Firestore
- Only updates if name is different (avoids unnecessary writes)

### ✅ Issue 4: Avatar Not Synced (FIXED)
**Problem**: Google profile picture wasn't being saved to Firestore.

**Fix**: 
- Frontend now sends `photoURL` as `avatar` in request
- Backend saves avatar for new users
- Backend updates avatar for existing users if changed

### ✅ Issue 5: Request Body Email Validation (FIXED)
**Problem**: Email from request body could be spoofed or incorrect.

**Fix**: 
- Always use token email as source of truth
- Request body email is validated but not trusted
- Added warning logs if mismatch detected

---

## 🔐 Security Improvements

1. **Token Email as Source of Truth**: Always use `req.user.email` from verified Firebase token
2. **Email Validation**: Validates token email matches Firestore email
3. **Auto-Correction**: Automatically fixes data corruption issues
4. **Request Body Validation**: Validates but doesn't trust request body data

---

## 📊 Data Flow Diagram

```
User → Select Role → Click "Sign in with Google"
  ↓
Frontend: FirebaseService.signInWithGoogle()
  ↓
Google Account Picker → User Selects Account
  ↓
Firebase Auth: signInWithCredential()
  ↓
Get Firebase ID Token
  ↓
Frontend: POST /api/auth/google-signin
  Headers: Authorization: Bearer <Firebase_ID_Token>
  Body: { role, name, email, avatar }
  ↓
Backend: protectNewUser Middleware
  ↓
Verify Firebase Token → Extract UID & Email
  ↓
Backend: googleSignIn Controller
  ↓
Check Firestore: users/{uid}
  ↓
┌─────────────────┬─────────────────┐
│ User Exists     │ User Doesn't    │
│                 │ Exist           │
├─────────────────┼─────────────────┤
│ 1. Validate     │ 1. Create new   │
│    email match  │    profile       │
│ 2. Update name  │ 2. Set verified │
│    if changed   │    (owner only) │
│ 3. Update avatar│ 3. Save avatar  │
│    if changed   │    if available │
│ 4. Validate role│                 │
│    match        │                 │
│ 5. Return       │ 4. Return new   │
│    profile      │    profile      │
└─────────────────┴─────────────────┘
  ↓
Frontend: Receive User Profile
  ↓
Frontend: Refresh Profile (getMe)
  ↓
Frontend: Save to Storage
  ↓
Frontend: Update State
  ↓
Navigate to Dashboard/Home
```

---

## 🐛 Potential Issues (Still Need Attention)

### ⚠️ Issue 1: Role Switching
**Current Behavior**: If user tries to sign in with different role, returns error.

**Question**: Should users be allowed to have multiple roles? Or is one role per account correct?

**Recommendation**: Current behavior is correct - one account = one role. But error message could be clearer.

### ⚠️ Issue 2: Avatar URL Validation
**Current Behavior**: Saves avatar URL directly from Google.

**Potential Issue**: No validation that URL is valid or from Google domain.

**Recommendation**: Add URL validation (optional, low priority).

### ⚠️ Issue 3: Name/Email from Request Body
**Current Behavior**: Uses name from request body, email from token.

**Potential Issue**: Name could be spoofed (but not critical since it's just display name).

**Recommendation**: Consider getting name from Firebase token if available (currently only email is in token).

### ⚠️ Issue 4: Token Refresh Timing
**Current Behavior**: Waits 500ms then refreshes token.

**Potential Issue**: Race condition if token not ready.

**Recommendation**: Current implementation is fine - token refresh is non-blocking.

---

## ✅ All Fixed Issues Summary

1. ✅ Email mismatch detection and auto-correction
2. ✅ Email priority (token email always used)
3. ✅ Name syncing from Google profile
4. ✅ Avatar syncing from Google profile
5. ✅ Request body email validation
6. ✅ Better error logging
7. ✅ Data corruption prevention

---

## 🧪 Testing Checklist

- [ ] New user sign-in as client
- [ ] New user sign-in as owner
- [ ] Existing user sign-in (same role)
- [ ] Existing user tries different role (should fail)
- [ ] Email mismatch scenario (auto-correction)
- [ ] Name change in Google (should sync)
- [ ] Avatar change in Google (should sync)
- [ ] Token expiration handling
- [ ] Network error handling
- [ ] User cancellation handling

---

## 📝 Notes

- The `protectNewUser` middleware is used for Google Sign-In because new users won't exist in Firestore yet
- The `protect` middleware is used for other endpoints that require existing users
- Email validation happens in multiple places for defense in depth
- All updates to Firestore include `updatedAt` timestamp
- The `verified` field is only set for owners (undefined for clients)

