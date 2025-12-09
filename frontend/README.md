# XPerience Gaming - Flutter Frontend

A gaming cafe booking app built with Flutter, featuring separate interfaces for gamers and cafe owners.

## 🎮 Features

### Client (Gamer) Side
- **Nearby Cafes**: Discover gaming cafes near your location using GPS
- **Smart Search**: Search by cafe name or game title (Valorant, GTA, etc.)
- **Cafe Details**: View PC specs, available games, pricing, and amenities
- **Slot Booking**: Book PC stations or console units with time selection
- **My Bookings**: Track upcoming and past bookings
- **Profile Management**: Update profile and preferences

### Owner Side
- **Dashboard**: Overview of all cafes with stats
- **Cafe Management**: Add, edit, and manage gaming cafes
- **Inventory**: Manage PC stations and gaming consoles
- **Bookings**: View and manage customer bookings
- **Analytics**: Track cafe performance (coming soon)

## 🛠 Tech Stack

- **Framework**: Flutter 3.2+
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **HTTP Client**: Dio
- **Maps**: Google Maps Flutter
- **Local Storage**: SharedPreferences + Flutter Secure Storage
- **UI**: Custom Cyberpunk/Gaming Theme

## 📦 Project Structure

```
lib/
├── config/           # Theme, Routes, Constants
├── core/             # API Client, Storage, Utils
├── models/           # Data models (User, Cafe, Booking)
├── services/         # API services
├── providers/        # Riverpod providers
├── screens/          # UI screens
│   ├── auth/         # Login, Register
│   ├── client/       # Gamer screens
│   └── owner/        # Cafe owner screens
├── widgets/          # Reusable UI components
└── main.dart         # Entry point
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.2.0+)
- Android Studio / VS Code with Flutter extensions
- Backend server running (see `/backend`)

### Installation

1. **Navigate to frontend folder**:
   ```bash
   cd frontend
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure API URL**:
   Edit `lib/config/constants.dart`:
   ```dart
   // For Android Emulator
   static const String baseUrl = 'http://10.0.2.2:5000/api';
   
   // For iOS Simulator
   static const String baseUrl = 'http://localhost:5000/api';
   
   // For Physical Device (use your PC's IP)
   static const String baseUrl = 'http://192.168.x.x:5000/api';
   ```

4. **Add Google Maps API Key** (for Android):
   Edit `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY"/>
   ```

5. **Create asset folders**:
   ```bash
   mkdir -p assets/images assets/icons assets/fonts
   ```

6. **Run the app**:
   ```bash
   flutter run
   ```

## 🎨 Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| True Black | `#000000` | Background |
| Surface Dark | `#121212` | Cards |
| Neon Purple | `#BC13FE` | Primary accent |
| Cyber Cyan | `#00E5FF` | Secondary accent |
| Matrix Green | `#39FF14` | Success |
| Cyber Red | `#FF003C` | Error |
| Electric Yellow | `#FFE600` | Ratings |

## 📱 Screenshots

Coming soon...

## ⚠️ Important Notes

1. **Location Permissions**: The app requires location permissions to show nearby cafes
2. **API Connection**: Ensure the backend is running before testing
3. **Google Maps**: Requires a valid API key for production

## 🔮 Upcoming Features

- [ ] Razorpay Payment Integration
- [ ] Push Notifications
- [ ] Real-time Seat Availability
- [ ] Reviews & Ratings
- [ ] Loyalty Points System
- [ ] In-app Chat Support

## 📄 License

This project is for educational purposes.

