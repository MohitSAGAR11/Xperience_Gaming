# Google Maps Link Fix Guide

## Problem
The Google Maps link (`https://maps.app.goo.gl/JFvTLh9ompcxxXw2A`) was not opening when clicked in the cafe card, showing error:
```
I/UrlLauncher( 4723): component name for  is null
```

## Root Causes Identified

1. **Missing Android Manifest Queries** - Android 11+ requires explicit query declarations
2. **Potential Empty mapsLink** - The field might be empty or not saved properly in Firestore
3. **Insufficient Error Handling** - No fallback mechanism if the link fails

## Fixes Applied

### 1. Android Manifest Updates
**File:** `frontend/android/app/src/main/AndroidManifest.xml`

Added query declarations for URL schemes and Google Maps:
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <data android:scheme="https"/>
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <data android:scheme="http"/>
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <data android:scheme="geo"/>
    </intent>
    <!-- For Google Maps -->
    <package android:name="com.google.android.apps.maps"/>
</queries>
```

### 2. Enhanced URL Launcher Logic
**Files:** 
- `frontend/lib/widgets/cafe_card.dart`
- `frontend/lib/screens/client/cafe/cafe_details_screen.dart`

**Improvements:**
- ✅ Check if `mapsLink` is empty before attempting to launch
- ✅ Try `LaunchMode.externalApplication` first
- ✅ Fallback to default mode if external fails
- ✅ Final fallback using Google Maps Search API with address
- ✅ Comprehensive debug logging

### 3. Backend Logging
**File:** `backend/src/controllers/cafeController.js`

Added logging to verify mapsLink is being saved:
```javascript
console.log('📍 Creating cafe with mapsLink:', cafeData.mapsLink);
console.log('📍 Cafe created, mapsLink saved:', cafe.mapsLink);
```

## Testing Steps

### Step 1: Rebuild the App
```bash
cd frontend
flutter clean
flutter pub get
flutter run
```

### Step 2: Check Backend Logs
When creating/updating a cafe, verify the backend logs show:
```
📍 Creating cafe with mapsLink: https://maps.app.goo.gl/JFvTLh9ompcxxXw2A
📍 Cafe created, mapsLink saved: https://maps.app.goo.gl/JFvTLh9ompcxxXw2A
```

### Step 3: Check Frontend Logs
When clicking the map link, you should see:
```
🗺️ [MAP_LINK] Attempting to open map
🗺️ [MAP_LINK] mapsLink value: "https://maps.app.goo.gl/JFvTLh9ompcxxXw2A"
🗺️ [MAP_LINK] isEmpty: false
🗺️ [MAP_LINK] Parsed URI: https://maps.app.goo.gl/JFvTLh9ompcxxXw2A
🗺️ [MAP_LINK] canLaunchUrl result: true
🗺️ [MAP_LINK] Launching with externalApplication mode...
🗺️ [MAP_LINK] Launch successful!
```

### Step 4: Verify in Firestore
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to `cafes` collection
4. Find your cafe document
5. Verify the `mapsLink` field contains: `https://maps.app.goo.gl/JFvTLh9ompcxxXw2A`

## Troubleshooting

### If mapsLink is Empty in Firestore

1. **Re-enter the link in the cafe form:**
   - Go to Owner Dashboard → Edit Cafe
   - Paste the link in "Google Maps Link" field
   - Save the cafe

2. **Manually update in Firestore Console:**
   - Open Firebase Console
   - Go to Firestore Database
   - Find the cafe document
   - Add/Edit field: `mapsLink` = `https://maps.app.goo.gl/JFvTLh9ompcxxXw2A`

### If Link Still Doesn't Open

1. **Check if Google Maps is installed:**
   - The app tries to open Google Maps first
   - Falls back to browser if not installed

2. **Try the fallback manually:**
   - The app will automatically try: `https://www.google.com/maps/search/?api=1&query=<address>`

3. **Check Android version:**
   - Android 11+ requires the manifest queries (already added)
   - Older versions should work without them

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `component name for  is null` | Empty mapsLink or missing queries | Check Firestore + rebuild app |
| `canLaunchUrl result: false` | No app can handle the URL | Install Google Maps or use browser |
| `mapsLink is empty!` | Field not saved in database | Re-enter in cafe form |

## URL Format Support

The app now supports multiple URL formats:

1. **Google Maps Short Link** (Recommended)
   ```
   https://maps.app.goo.gl/JFvTLh9ompcxxXw2A
   ```

2. **Full Google Maps URL**
   ```
   https://www.google.com/maps/place/...
   ```

3. **Geo URI**
   ```
   geo:28.6139,77.2090?q=Cafe+Name
   ```

4. **Fallback Search** (Automatic)
   ```
   https://www.google.com/maps/search/?api=1&query=<address>
   ```

## Files Modified

1. ✅ `frontend/android/app/src/main/AndroidManifest.xml`
2. ✅ `frontend/lib/widgets/cafe_card.dart`
3. ✅ `frontend/lib/screens/client/cafe/cafe_details_screen.dart`
4. ✅ `backend/src/controllers/cafeController.js`

## Next Steps

1. **Rebuild the app** with the manifest changes
2. **Test the map link** - click on the address in cafe card
3. **Check the logs** - verify mapsLink is not empty
4. **Update existing cafes** - ensure all cafes have valid mapsLink values

## Support

If the issue persists after following all steps:
1. Share the complete logs from both frontend and backend
2. Verify the mapsLink value in Firestore
3. Check if Google Maps app is installed on the device

