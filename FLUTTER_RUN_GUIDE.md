# 🚀 Flutter App Setup & Run Guide

## ✅ Current Status
- **Backend:** ✅ Running on port 5000
- **Flutter Environment:** ✅ Configured
- **Android Emulator:** ✅ Running (emulator-5554)
- **Dependencies:** ✅ Installed

---

## 📱 Quick Start Commands

### 1. Navigate to Frontend Directory
```powershell
cd frontend
```

### 2. Install Dependencies (If not done)
```powershell
flutter pub get
```

### 3. Run on Android Emulator
```powershell
flutter run
```

That's it! The app will automatically:
- Build the Flutter app
- Install it on your emulator
- Launch and hot-reload on save

---

## 🎮 Available Devices

Your current connected devices:
```
✅ sdk gphone64 x86 64 (emulator-5554) - Android 16 (API 36)
   Windows (desktop)
   Chrome (web)
   Edge (web)
```

### Run on Specific Device
```powershell
# Android Emulator (default if only mobile device)
flutter run -d emulator-5554

# Windows Desktop
flutter run -d windows

# Chrome Browser
flutter run -d chrome
```

---

## 🔧 Useful Flutter Commands

### Check Available Devices
```powershell
flutter devices
```

### List Available Emulators
```powershell
flutter emulators
```

### Start a Specific Emulator
```powershell
flutter emulators --launch <emulator_id>
```

### Hot Reload (while app is running)
Press `r` in the terminal

### Hot Restart (while app is running)
Press `R` in the terminal

### Quit Running App
Press `q` in the terminal

### Clean Build
```powershell
flutter clean
flutter pub get
flutter run
```

### View Logs
```powershell
flutter logs
```

### Build APK
```powershell
flutter build apk --release
```

---

## 🌐 Network Configuration

### Current Setup (Android Emulator)
Your frontend is configured for Android Emulator:

**File:** `frontend/lib/config/constants.dart`
```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

**Why 10.0.2.2?**
- `10.0.2.2` is the special IP that Android Emulator uses
- It maps to `localhost` on your PC
- Your backend running on `localhost:5000` is accessible via `10.0.2.2:5000`

### For Different Devices

#### 📱 Physical Android Device
1. Get your PC's IP address:
   ```powershell
   ipconfig | findstr "IPv4"
   # Your IP: 10.52.41.208
   ```

2. Update `frontend/lib/config/constants.dart`:
   ```dart
   static const String baseUrl = 'http://10.52.41.208:5000/api';
   ```

3. Ensure both devices on same WiFi network

#### 🍎 iOS Simulator
```dart
static const String baseUrl = 'http://localhost:5000/api';
```

---

## 🐛 Troubleshooting

### App Can't Connect to Backend

**Check Backend is Running:**
```powershell
curl http://localhost:5000/api/health
```

**Should return:**
```json
{
  "status": "OK",
  "message": "Gaming Cafe API is running",
  "timestamp": "..."
}
```

### Emulator Not Detected

1. **Start Android Studio**
2. **Open AVD Manager** (Tools → Device Manager)
3. **Launch your virtual device**
4. **Check again:**
   ```powershell
   flutter devices
   ```

### Build Errors

**Clear cache and rebuild:**
```powershell
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Gradle Issues
```powershell
cd android
./gradlew clean
cd ..
flutter run
```

---

## 📦 Project Dependencies

Your Flutter project uses:
- **flutter_riverpod** - State management
- **dio** - HTTP client
- **go_router** - Navigation
- **flutter_secure_storage** - Secure token storage
- **geolocator** - Location services
- **geocoding** - Address lookup
- **intl** - Internationalization

---

## 🎯 Testing the Connection

### 1. Launch the App
```powershell
flutter run
```

### 2. Navigate to Register/Login Screen

### 3. Try Creating an Account
The app will send a POST request to:
```
http://10.0.2.2:5000/api/auth/register
```

### 4. Check Backend Logs
In your backend terminal, you should see:
```
2025-12-06T11:25:11.005Z | POST /api/auth/register
```

### 5. If Successful
You'll receive a JWT token and be logged in!

---

## 🔥 Hot Reload Tips

While the app is running:
- Make changes to `.dart` files
- Press `r` to hot reload
- Changes appear instantly!
- Press `R` for full restart if needed

---

## 📊 Backend Endpoints Available

Your backend API endpoints:
- `POST /api/auth/register` - Create account
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get profile
- `PUT /api/auth/profile` - Update profile
- `PUT /api/auth/password` - Change password
- `POST /api/auth/logout` - Logout
- `GET /api/cafes` - List cafes
- `GET /api/cafes/nearby` - Find nearby cafes
- `POST /api/bookings` - Create booking
- `GET /api/bookings/my-bookings` - User's bookings
- `POST /api/reviews` - Add review

---

## ✨ Next Steps

1. **Run the app:** `flutter run`
2. **Test registration** with dummy data
3. **Test login** with your credentials
4. **Check backend logs** to see requests
5. **Explore the app features!**

---

**Ready to go!** 🎮 Just run:
```powershell
cd frontend
flutter run
```

Your backend is already running on port 5000, and your emulator is ready. The connection will work automatically!

