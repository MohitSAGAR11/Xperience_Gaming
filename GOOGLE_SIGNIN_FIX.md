# 🔧 Google Sign-In Error Fix: ApiException: 7 (Network Error)

## 🐛 Error Description

```
ApiException: 7: Network error
com.google.android.gms.common.api.ApiException: 7
```

This error occurs when Google Sign-In cannot connect to Google's servers or when OAuth client configuration is incorrect.

---

## ✅ Solution Steps

### Step 1: Verify SHA-1 Fingerprint

The most common cause is a missing or incorrect SHA-1 fingerprint in Firebase Console.

#### Get Your SHA-1 Fingerprint:

**For Debug Build:**
```bash
cd frontend/android
./gradlew signingReport
```

**For Windows:**
```bash
cd frontend/android
gradlew.bat signingReport
```

Look for output like:
```
Variant: debug
Config: debug
Store: C:\Users\...\.android\debug.keystore
Alias: AndroidDebugKey
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

#### Add SHA-1 to Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **xperience-gaming**
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Click on your Android app
6. Click **Add fingerprint**
7. Paste your SHA-1 fingerprint
8. Click **Save**

### Step 2: Download Updated google-services.json

After adding SHA-1:

1. In Firebase Console → Project Settings
2. Scroll to **Your apps**
3. Click **Download google-services.json**
4. Replace `frontend/android/app/google-services.json` with the new file

### Step 3: Verify OAuth Client Configuration

The code has been updated to include the server client ID. Verify in `firebase_service.dart`:

```dart
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email'],
  serverClientId: '180127542-8itp58lc8epvmv6iabicrabvmvepudk9.apps.googleusercontent.com',
);
```

### Step 4: Enable Google Sign-In in Firebase

1. Go to Firebase Console → **Authentication**
2. Click **Sign-in method** tab
3. Find **Google** in the list
4. Click **Enable**
5. Enter your support email
6. Click **Save**

### Step 5: Clean and Rebuild

```bash
cd frontend
flutter clean
flutter pub get
flutter run
```

---

## 🔍 Additional Checks

### 1. Check Internet Connection
- Ensure device/emulator has internet access
- Try on a physical device if emulator has network issues

### 2. Verify Package Name
Check that your package name matches in:
- `android/app/build.gradle.kts`: `applicationId = "com.example.xperience_gaming"`
- `google-services.json`: `"package_name": "com.example.xperience_gaming"`

### 3. Check Google Play Services
- Ensure Google Play Services is installed and updated on device
- For emulator: Use an image with Google Play Services

### 4. Verify OAuth Consent Screen
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **xperience-gaming**
3. Go to **APIs & Services** → **OAuth consent screen**
4. Ensure it's configured (can be in "Testing" mode for development)

---

## 🧪 Testing After Fix

1. **Clean build:**
   ```bash
   cd frontend
   flutter clean
   flutter pub get
   ```

2. **Run app:**
   ```bash
   flutter run
   ```

3. **Test Google Sign-In:**
   - Tap "Continue with Google"
   - Should see Google account picker
   - Select account
   - Should sign in successfully

---

## 📋 Checklist

- [ ] SHA-1 fingerprint added to Firebase Console
- [ ] Updated `google-services.json` downloaded and replaced
- [ ] Google Sign-In enabled in Firebase Authentication
- [ ] Server client ID added to GoogleSignIn configuration
- [ ] Package name matches in all files
- [ ] Internet connection working
- [ ] Google Play Services installed/updated
- [ ] OAuth consent screen configured
- [ ] App cleaned and rebuilt

---

## 🔄 If Still Not Working

### Option 1: Check Firebase Console Logs
1. Firebase Console → Authentication → Users
2. Check if any errors appear when attempting sign-in

### Option 2: Check Android Logcat
```bash
flutter run
# In another terminal:
adb logcat | grep -i "google\|signin\|auth"
```

### Option 3: Verify OAuth Client IDs

Check `google-services.json` for client IDs:
- **Android client** (client_type: 1): Used for Android app
- **Web client** (client_type: 3): Used as serverClientId

Make sure the serverClientId in code matches the web client ID in `google-services.json`.

### Option 4: Try Different Google Account
Sometimes specific Google accounts have restrictions. Try with a different account.

---

## 🎯 Common Causes Summary

| Cause | Solution |
|-------|----------|
| Missing SHA-1 | Add SHA-1 to Firebase Console |
| Old google-services.json | Download new one after adding SHA-1 |
| Google Sign-In not enabled | Enable in Firebase Console |
| Missing serverClientId | Add to GoogleSignIn configuration |
| Package name mismatch | Verify in build.gradle.kts |
| No internet | Check device connection |
| Google Play Services missing | Install/update on device |

---

## ✅ Expected Behavior After Fix

1. User taps "Continue with Google"
2. Google account picker appears
3. User selects account
4. App receives authentication tokens
5. User is signed in to Firebase
6. Backend creates/fetches user profile
7. User navigates to home screen

**No more `ApiException: 7` errors!** 🎉

---

## 📞 Still Having Issues?

If the error persists after following all steps:

1. **Check the exact error message** in logcat
2. **Verify SHA-1** matches exactly (no spaces, correct format)
3. **Try on a physical device** instead of emulator
4. **Check Firebase Console** for any error messages
5. **Verify OAuth consent screen** is properly configured

---

**Last Updated:** [Current Date]
**Related Files:**
- `frontend/lib/core/firebase_service.dart`
- `frontend/android/app/google-services.json`
- `frontend/android/app/build.gradle.kts`

