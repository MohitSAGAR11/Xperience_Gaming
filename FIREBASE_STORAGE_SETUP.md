# 🔥 Firebase Storage Setup Guide

## ⚠️ Issue
Backend error: "Bucket name not specified or invalid"

## ✅ Solution - Enable Firebase Storage

### Step 1: Go to Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project (XPerience Gaming)

### Step 2: Enable Firebase Storage

1. In the left sidebar, click **"Build"**
2. Click **"Storage"**
3. Click **"Get Started"** button

### Step 3: Set Security Rules

When prompted, select **"Start in production mode"** and click **"Next"**

Then, you'll set custom rules. Use these rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow public read access to cafe images
    match /cafes/{cafeId}/{allPaths=**} {
      allow read: if true;  // Public read
      allow write: if request.auth != null;  // Only authenticated users can write
    }
  }
}
```

Click **"Done"**

### Step 4: Verify Bucket Name

1. After Storage is enabled, you'll see the Storage dashboard
2. Check the bucket name at the top - it should be something like:
   - `your-project-id.appspot.com`
   - Or `your-project-id.firebasestorage.app` (newer format)

3. **Important**: Copy this bucket name

### Step 5: Update Backend Configuration (if needed)

**Option A: If your bucket is the default format** (`project-id.appspot.com`):
- ✅ No changes needed! The backend automatically uses this format

**Option B: If your bucket has a different name**:

1. Open `backend/.env` file (create if it doesn't exist)
2. Add this line with YOUR actual bucket name:

```env
FIREBASE_STORAGE_BUCKET=your-actual-bucket-name-here
```

For example:
```env
FIREBASE_STORAGE_BUCKET=xperience-gaming-abc123.firebasestorage.app
```

3. Save the file
4. Restart the backend server

### Step 6: Restart Backend

```bash
cd backend
npm run dev
```

Look for this in the startup logs:
```
✅ Storage bucket configured: your-project-id.appspot.com
```

### Step 7: Test Upload

1. Go to your app
2. Login as owner
3. Edit a cafe
4. Try uploading an image
5. Check backend logs - you should see:

```
📸 [FILE_FILTER] ✅ File accepted
📸 [UPLOAD] Starting image upload for cafe: ...
📸 [UPLOAD] File uploaded successfully
📸 [UPLOAD] Public URL: https://storage.googleapis.com/...
```

---

## 🔍 How to Find Your Bucket Name

### Method 1: Firebase Console
1. Go to Firebase Console → Storage
2. The bucket name is shown at the top of the Storage page

### Method 2: Check Service Account JSON
1. Open `backend/firebase-service-account.json`
2. Look for `"project_id"` field
3. Your bucket is likely: `project_id.appspot.com`

### Method 3: From Error (once Storage is enabled)
If you get a different error mentioning a bucket name, that's your actual bucket name!

---

## 🎯 Quick Checklist

- [ ] Firebase Storage enabled in console
- [ ] Security rules set (public read, auth write)
- [ ] Bucket name verified
- [ ] Backend restarted
- [ ] Startup logs show "Storage bucket configured"
- [ ] Test upload successful

---

## 🐛 Troubleshooting

### Error: "Bucket name not specified"
- ✅ **Solution**: Enable Firebase Storage in console first!

### Error: "The specified bucket does not exist"
- Check the bucket name in Firebase Console
- Add correct bucket name to `.env` file
- Restart backend

### Error: "Permission denied"
- Check Firebase Storage Rules
- Make sure rules allow public read and authenticated write
- Rules should match the example above

### Images upload but can't be viewed
- Check Storage Rules allow `read: if true` 
- Verify the URL is public (starts with `https://storage.googleapis.com/`)

---

## 📝 Storage Rules Explained

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /cafes/{cafeId}/{allPaths=**} {
      // Anyone can view cafe images (for users browsing)
      allow read: if true;
      
      // Only authenticated cafe owners can upload/delete
      allow write: if request.auth != null;
    }
  }
}
```

- `allow read: if true` - Public access so users can see cafe images
- `allow write: if request.auth != null` - Only logged-in users can upload
- Backend code also verifies the user is the actual cafe owner

---

## ✅ Once Done

After Firebase Storage is enabled and configured:
1. Backend will start successfully
2. You can upload images from the app
3. Images will be stored at: `cafes/{cafeId}/{filename}`
4. Public URLs will be generated automatically
5. Images will appear in cafe cards and details

**Cost**: ~$0.16/month for 100 cafes with 5 images each (very cheap!) 💰


