# 🔥 Firebase Setup Requirements

This document lists what you need to provide from Firebase so I can help implement the migration.

---

## ✅ What You Need to Do (Firebase Console Setup)

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add Project"** or **"Create a Project"**
3. Project name: `XPerience Gaming` (or your preferred name)
4. Enable Google Analytics (optional, but recommended)
5. Click **"Create Project"**

---

### Step 2: Enable Authentication

1. In Firebase Console, go to **Authentication** → **Get Started**
2. Click on **"Sign-in method"** tab
3. Enable **"Email/Password"** provider:
   - Click on "Email/Password"
   - Toggle **"Enable"**
   - Click **"Save"**

**✅ What I need:** Just confirmation that this is enabled (no files needed)

---

### Step 3: Enable Firestore Database

1. In Firebase Console, go to **Firestore Database** → **Create Database**
2. Choose **"Start in test mode"** (we'll add security rules later)
3. Select your preferred **Cloud Firestore location** (choose closest to your users)
4. Click **"Enable"**

**✅ What I need:** Just confirmation that this is enabled (no files needed)

---

### Step 4: Get Firebase Configuration Files

#### For Frontend (Flutter):

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Scroll down to **"Your apps"** section
3. Click **"Add app"** → Select **Android** icon
4. Register your Android app:
   - **Android package name**: Check your `frontend/android/app/build.gradle.kts` file, look for `applicationId` (usually something like `com.example.xperience_gaming`)
   - **App nickname** (optional): `XPerience Gaming Android`
   - Click **"Register app"**
5. Download `google-services.json` file
6. Click **"Add app"** again → Select **iOS** icon (if you're building for iOS)
   - **iOS bundle ID**: Check your `frontend/ios/Runner.xcodeproj` or `Info.plist`
   - Download `GoogleService-Info.plist` file

**✅ What I need:**
- `google-services.json` file (place it in `frontend/android/app/`)
- `GoogleService-Info.plist` file (place it in `frontend/ios/Runner/`) - if building for iOS

---

#### For Backend (Express):

1. In Firebase Console, go to **Project Settings** → **Service Accounts** tab
2. Click **"Generate new private key"**
3. Click **"Generate key"** in the confirmation dialog
4. A JSON file will be downloaded (this is your service account key)

**✅ What I need:**
- Service account JSON file (save it as `backend/firebase-service-account.json`)
- **⚠️ IMPORTANT:** Add this file to `.gitignore` (I'll do this, but make sure you never commit it!)

---

### Step 5: Get Firebase Project Configuration

From Firebase Console → Project Settings → General tab, I need:

**✅ What I need:**
- **Project ID** (shown at the top, e.g., `xperience-gaming-12345`)
- **Project Number** (optional, but helpful)

You can also find these in the downloaded `google-services.json` file:
- `project_id`
- `project_number`

---

## 📋 Summary Checklist

Provide me with:

- [ ] **Firebase Project ID** (text)
- [ ] **`google-services.json`** file (for Android)
- [ ] **`GoogleService-Info.plist`** file (for iOS - if needed)
- [ ] **`firebase-service-account.json`** file (for backend)
- [ ] Confirmation that **Email/Password Authentication** is enabled
- [ ] Confirmation that **Firestore Database** is created

---

## 🔒 Security Notes

1. **Never commit** `firebase-service-account.json` to Git
2. **Never commit** `google-services.json` if it contains sensitive data (usually safe, but check)
3. I'll add these to `.gitignore` automatically
4. Keep your Firebase project secure - don't share service account keys publicly

---

## 📝 What I'll Do Once You Provide These

1. ✅ Install Firebase dependencies in both frontend and backend
2. ✅ Set up Firebase initialization code
3. ✅ Configure Firebase Admin SDK in backend
4. ✅ Replace PostgreSQL/Sequelize with Firestore queries
5. ✅ Replace JWT auth with Firebase Auth verification
6. ✅ Update all controllers to use Firestore
7. ✅ Update frontend services to use Firebase Auth
8. ✅ Set up Firestore Security Rules
9. ✅ Create Firestore indexes configuration
10. ✅ Update all API calls to work with Firebase

---

## 🚀 Quick Setup Guide

### Minimum Required Info:

**Option 1: Just give me the files**
- Download `google-services.json` → place in `frontend/android/app/`
- Download `firebase-service-account.json` → place in `backend/`
- Tell me your Firebase Project ID

**Option 2: I can guide you step-by-step**
- Tell me when you've created the Firebase project
- I'll guide you through each step

---

## ❓ Common Questions

**Q: Do I need to pay for Firebase?**  
A: Firebase has a generous free tier. For development and small apps, it's free. You only pay when you exceed free limits.

**Q: Can I use the same Firebase project for development and production?**  
A: It's better to have separate projects, but you can start with one project.

**Q: What if I don't have the Android package name yet?**  
A: Check `frontend/android/app/build.gradle.kts` or I can help you find it.

**Q: Do I need iOS setup if I'm only building for Android?**  
A: No, you can skip iOS setup if you're only targeting Android.

---

## 📞 Next Steps

Once you have:
1. Created Firebase project
2. Enabled Authentication (Email/Password)
3. Enabled Firestore Database
4. Downloaded the configuration files

**Just let me know and I'll start implementing!** 🚀

