# 🔥 Firebase Storage Setup Guide (Blaze Plan)

## 🎯 Overview

This guide will help you set up Firebase Storage for your XPerience Gaming app after upgrading to the Blaze plan. Firebase Storage allows you to upload and store images (cafe photos, profile pictures, etc.) securely in the cloud.

## 📋 Prerequisites

- ✅ Firebase project upgraded to **Blaze Plan** (required for Storage)
- ✅ Firebase Admin SDK service account JSON file (`firebase-service-account.json`)
- ✅ Backend server running Node.js with Express

## 🚀 Step-by-Step Setup

### Step 1: Enable Firebase Storage in Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **xperience-gaming**
3. Navigate to **Storage** in the left sidebar
4. Click **Get Started** (if not already enabled)
5. Choose **Start in production mode** (we'll set up rules next)
6. Select a **location** for your storage bucket (choose closest to your users)
7. Click **Done**

### Step 2: Configure Storage Bucket

Your bucket name should be: `xperience-gaming.firebasestorage.app`

**To verify:**
- Firebase Console → Storage → Settings
- Look for "Default bucket" or check the URL

### Step 3: Deploy Storage Security Rules

1. **Create `storage.rules` file** in your project root (already created ✅)
2. **Deploy the rules** using Firebase CLI:

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init storage

# Deploy storage rules
firebase deploy --only storage
```

**Or manually in Firebase Console:**
- Go to Storage → Rules tab
- Copy the rules from `storage.rules` file
- Paste and click **Publish**

### Step 4: Configure Backend Environment

Create a `.env` file in the `backend/` directory:

```env
# Server Configuration
PORT=5000
NODE_ENV=development

# Firebase Storage Bucket
# Format: {project-id}.firebasestorage.app
FIREBASE_STORAGE_BUCKET=xperience-gaming.firebasestorage.app

# CORS (optional)
CORS_ORIGIN=*
```

**Important:** The backend code already has the bucket name as a fallback, but using environment variables is recommended.

### Step 5: Verify Backend Configuration

The backend is already configured in `backend/src/config/firebase.js`:

```javascript
const storageBucket = process.env.FIREBASE_STORAGE_BUCKET || 
                     'xperience-gaming.firebasestorage.app';
```

**To verify it's working:**
1. Start your backend server: `cd backend && npm start`
2. Check the logs - you should see:
   ```
   ✅ Firebase Admin SDK initialized successfully
   ✅ Firestore connected
   ✅ Storage bucket configured: xperience-gaming.firebasestorage.app
   ```

### Step 6: Verify Frontend Configuration

The frontend is already configured in `frontend/lib/firebase_options.dart`:

```dart
storageBucket: 'xperience-gaming.firebasestorage.app'
```

No changes needed here! ✅

## 📁 Current Setup Status

### Frontend Configuration ✅
The frontend already has the storage bucket configured in `frontend/lib/firebase_options.dart`:
```dart
storageBucket: 'xperience-gaming.firebasestorage.app'
```

### Backend Configuration ✅
The backend is configured in `backend/src/config/firebase.js`:
```javascript
const storageBucket = process.env.FIREBASE_STORAGE_BUCKET || 
                     'xperience-gaming.firebasestorage.app';
```

## 🔧 Code Locations

### Image Upload Endpoints

**Backend Routes:** `backend/src/routes/uploadRoutes.js`
- `POST /api/upload/cafe-image/:cafeId` - Upload cafe image
- `DELETE /api/upload/cafe-image/:cafeId` - Delete cafe image

**Backend Controller:** `backend/src/controllers/uploadController.js`
- Handles file uploads using Multer
- Uploads to Firebase Storage
- Updates Firestore with image URLs

**Frontend Service:** `frontend/lib/services/image_upload_service.dart`
- `uploadCafeImage()` - Uploads images from Flutter app
- `deleteCafeImage()` - Deletes images

**Frontend Widget:** `frontend/lib/widgets/image_gallery_manager.dart`
- UI component for managing cafe images
- Handles image picking and upload progress

## 🧪 Testing Image Upload

### 1. Test Backend Upload

After configuration, test image upload:

1. **Start backend server:**
   ```bash
   cd backend
   npm start
   ```

2. **Check logs** - you should see:
   ```
   ✅ Storage bucket configured: xperience-gaming.firebasestorage.app
   ```

3. **Test upload via API:**
   - Use Postman or your Flutter app
   - POST to `/api/upload/cafe-image/:cafeId`
   - Include `Authorization: Bearer <token>` header
   - Upload an image file

4. **Backend logs should show:**
   ```
   📸 [UPLOAD] Uploading to path: cafes/{cafeId}/{filename}
   📸 [UPLOAD] File uploaded successfully
   📸 [UPLOAD] Public URL: https://storage.googleapis.com/xperience-gaming.firebasestorage.app/...
   ```

### 2. Test Frontend Upload

1. Open your Flutter app
2. Navigate to cafe management screen
3. Try uploading an image
4. Check Firebase Console → Storage to see the uploaded file

## 🔍 How to Find Your Bucket Name

### Method 1: Firebase Console
1. Firebase Console → Storage
2. Look at the URL or bucket name in settings

### Method 2: From google-services.json
Check `frontend/android/app/google-services.json`:
```json
{
  "project_info": {
    "storage_bucket": "xperience-gaming.firebasestorage.app"
  }
}
```

### Method 3: From firebase_options.dart
Already configured: `xperience-gaming.firebasestorage.app`

## 🧪 Testing

After configuration, test image upload:

1. **Backend logs should show:**
   ```
   ✅ Storage bucket configured: xperience-gaming.firebasestorage.app
   📸 [UPLOAD] Uploading to path: cafes/{cafeId}/{filename}
   📸 [UPLOAD] Public URL: https://storage.googleapis.com/xperience-gaming.firebasestorage.app/...
   ```

2. **Upload should succeed** and return a public URL

3. **Check Firebase Console** → Storage to see uploaded files

## 📝 Complete .env Example

```env
# Server
PORT=5000
NODE_ENV=development

# Firebase
FIREBASE_STORAGE_BUCKET=xperience-gaming.firebasestorage.app

# Razorpay (for payments)
RAZORPAY_KEY_ID=your_key_id
RAZORPAY_KEY_SECRET=your_key_secret
```

## ⚠️ Important Notes

1. **Bucket Name Format:**
   - Old format: `{project-id}.appspot.com`
   - New format: `{project-id}.firebasestorage.app`
   - Your bucket uses the new format

2. **Permissions:**
   - Ensure your Firebase service account has Storage Admin permissions
   - Check in Firebase Console → IAM & Admin

3. **Public Access:**
   - The upload controller calls `file.makePublic()` to make files publicly accessible
   - Ensure Storage rules allow public read access if needed

## 🔐 Storage Security Rules

Storage rules are defined in `storage.rules` file in your project root. The rules include:

- **Cafe Images:** Public read, owner-only write/delete
- **User Profile Images:** Authenticated users can read, users can manage their own
- **Community Post Images:** Public read, authenticated users can upload

**To deploy rules:**

```bash
firebase deploy --only storage
```

**Or manually:**
1. Firebase Console → Storage → Rules
2. Copy rules from `storage.rules`
3. Paste and click **Publish**

**Current Rules Summary:**
- ✅ Cafe images: Public read, owner-only write
- ✅ File size limit: 10MB
- ✅ File type: Images only (image/*)
- ✅ Ownership verification via Firestore

## ✅ Complete Setup Checklist

### Firebase Console Setup
- [ ] Firebase project upgraded to Blaze Plan
- [ ] Storage enabled in Firebase Console
- [ ] Storage bucket created: `xperience-gaming.firebasestorage.app`
- [ ] Storage rules deployed (from `storage.rules` file)
- [ ] Service account has Storage Admin permissions

### Backend Setup
- [ ] `.env` file created in `backend/` directory
- [ ] `FIREBASE_STORAGE_BUCKET` added to `.env`
- [ ] Backend server restarted
- [ ] Logs show: `✅ Storage bucket configured: xperience-gaming.firebasestorage.app`
- [ ] Upload endpoint tested and working

### Frontend Setup
- [ ] `firebase_options.dart` has correct `storageBucket`
- [ ] Image upload service working
- [ ] Test upload from Flutter app succeeds

### Verification
- [ ] Test upload succeeds
- [ ] Public URL is accessible
- [ ] Files appear in Firebase Console → Storage
- [ ] Images display correctly in app

## 🐛 Troubleshooting

### Issue: "Storage bucket not found"
**Solution:** 
- Verify bucket name in Firebase Console
- Check `.env` file has correct `FIREBASE_STORAGE_BUCKET`
- Restart backend server

### Issue: "Permission denied" on upload
**Solution:**
- Check Storage rules are deployed
- Verify user is authenticated
- Check user has owner role (for cafe images)
- Verify cafe ownership in Firestore

### Issue: "File too large"
**Solution:**
- Current limit is 10MB
- Compress images before upload
- Or increase limit in `uploadController.js` and Storage rules

### Issue: Upload works but image doesn't display
**Solution:**
- Check public URL is correct
- Verify `file.makePublic()` is called in upload controller
- Check Storage rules allow public read

## 📚 Additional Resources

- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [Storage Security Rules](https://firebase.google.com/docs/storage/security)
- [Firebase Admin SDK Storage](https://firebase.google.com/docs/admin/setup)

---

**Current Bucket Name:** `xperience-gaming.firebasestorage.app`

**Next Steps:**
1. Create `backend/.env` file with `FIREBASE_STORAGE_BUCKET=xperience-gaming.firebasestorage.app`
2. Deploy Storage rules: `firebase deploy --only storage`
3. Restart backend server
4. Test image upload from your app

