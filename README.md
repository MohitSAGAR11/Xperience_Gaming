<div align="center">

# 🎮 XPerience Gaming

**The Ultimate Gaming Cafe Discovery & Booking Platform**

[![Flutter](https://img.shields.io/badge/Flutter-3.2+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Firestore](https://img.shields.io/badge/Firestore-Latest-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/products/firestore)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)

*Discover, book, and game at the best cafes near you*

[Features](#-features) • [Tech Stack](#-tech-stack) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 📖 Overview

**XPerience Gaming** is a full-stack mobile application that revolutionizes how gamers discover and book gaming cafes. Whether you're looking for high-end PC stations, our platform connects gamers with the perfect gaming experience.

### 🎯 Problem We Solve

Finding the right gaming cafe with available slots, preferred games, and suitable hardware can be frustrating. XPerience Gaming eliminates this hassle by providing:
- **Real-time availability** of PC stations
- **Location-based discovery** of nearby gaming cafes
- **Smart search** by cafe name or game titles
- **Seamless booking** experience for both gamers and cafe owners

---

## ✨ Features

### 👥 For Gamers (Client App)

#### 🗺️ Discovery & Search
- **📍 Location-Based Discovery**: Find gaming cafes near you using GPS
- **🔍 Smart Search**: Search by cafe name or game title (Valorant, GTA V, FIFA, etc.)
- **🗺️ Interactive Maps**: View cafes on Google Maps with distance and directions
- **⭐ Ratings & Reviews**: See what other gamers think before booking

#### 🎮 Booking System
- **💻 PC Station Booking**: Book high-performance gaming PCs with detailed specs
- **⏰ Flexible Time Slots**: Choose your preferred date and time
- **💰 Transparent Pricing**: See hourly rates before booking
- **📱 Booking Management**: Track upcoming and past reservations

#### 👤 Profile & Community
- **📝 Profile Management**: Update your information and preferences
- **👥 Community Features**: Connect with other gamers
- **📊 Booking History**: View all your past and upcoming bookings
- **🔔 Push Notifications**: Stay updated on booking confirmations and reminders

### 🏪 For Cafe Owners

#### 📊 Dashboard & Analytics
- **📈 Performance Dashboard**: Overview of all cafes with key metrics (Upcoming)
- **💰 Earnings Tracking**: Monitor revenue and booking statistics (Upcoming)
- **📅 Booking Calendar**: View all reservations at a glance

#### 🏢 Cafe Management
- **➕ Multi-Cafe Support**: Manage multiple gaming cafes from one account
- **🖥️ PC Inventory**: Add and manage PC stations
- **📸 Image Gallery**: Showcase your cafe with multiple photos

#### 📋 Booking Management
- **✅ Booking Approvals**: Accept or reject booking requests
- **🔄 Status Updates**: Update booking status (pending, confirmed, completed, cancelled)
- **📧 Customer Communication**: Notify customers about booking changes

---

## 🛠️ Tech Stack

### 📱 Frontend (Flutter)

| Category | Technology |
|----------|-----------|
| **Framework** | Flutter 3.2+ |
| **State Management** | Riverpod 2.4+ |
| **Navigation** | GoRouter 13.0 |
| **HTTP Client** | Dio 5.4 |
| **Maps & Location** | Google Maps Flutter, Geolocator |
| **Authentication** | Firebase Auth, Google Sign-In |
| **Storage** | SharedPreferences, Flutter Secure Storage |
| **Notifications** | Firebase Cloud Messaging, Flutter Local Notifications |
| **UI Components** | Custom Cyberpunk/Gaming Theme |
| **Image Handling** | Cached Network Image, Image Picker |
| **Fonts** | Google Fonts |

### 🚀 Backend (Node.js)

| Category | Technology |
|----------|-----------|
| **Runtime** | Node.js 18+ |
| **Framework** | Express.js 4.18 |
| **Database** | Firebase Firestore (NoSQL) |
| **Authentication** | Firebase Auth + JWT |
| **File Upload** | Multer + Firebase Storage |
| **Validation** | express-validator |
| **Cloud Services** | Firebase Admin SDK |
| **Notifications** | Firebase Cloud Messaging |

### ☁️ Infrastructure

- **Firebase**: Authentication, Cloud Messaging, Firestore (NoSQL database), Storage
- **Google Maps API**: Location services and maps

---

## 🏗️ Architecture

```
XPerience_Gaming/
├── frontend/                 # Flutter mobile application
│   ├── lib/
│   │   ├── config/          # Theme, Routes, Constants
│   │   ├── core/            # API Client, Storage, Utils
│   │   ├── models/          # Data models
│   │   ├── providers/       # Riverpod state providers
│   │   ├── screens/         # UI screens
│   │   │   ├── auth/        # Authentication screens
│   │   │   ├── client/      # Gamer interface
│   │   │   └── owner/       # Cafe owner interface
│   │   ├── services/        # API service layer
│   │   └── widgets/         # Reusable UI components
│   ├── android/             # Android platform files
│   ├── ios/                 # iOS platform files
│   └── assets/              # Images, icons, fonts
│
├── backend/                 # Node.js/Express API server
│   ├── src/
│   │   ├── config/          # Database & Firebase config
│   │   ├── controllers/     # Request handlers
│   │   ├── middleware/      # Auth & validation middleware
│   │   ├── routes/          # API route definitions
│   │   └── services/        # Business logic services
│   └── server.js            # Entry point
│
└── README.md               # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** 3.2.0 or higher
- **Node.js** 18.0 or higher
- **Firebase Account** (for authentication, Firestore database, and notifications)
- **Google Cloud Account** (for Maps API)
- **Android Studio** or **VS Code** with Flutter extensions

### 📋 Installation Steps

#### 1️⃣ Clone the Repository

```bash
git clone https://github.com/yourusername/XPerience_Gaming.git
cd XPerience_Gaming
```

#### 2️⃣ Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create .env file
cp .env.example .env
```

Configure your `.env` file:

```env
PORT=5000
NODE_ENV=development

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key
JWT_EXPIRES_IN=7d

# CORS Configuration
CORS_ORIGIN=http://localhost:5000

# Firebase Configuration
FIREBASE_SERVICE_ACCOUNT=./firebase-service-account.json
FIREBASE_STORAGE_BUCKET=xperience-gaming.firebasestorage.app
```

**Firebase Setup:**

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable **Firestore Database** and **Firebase Authentication**
3. Enable **Firebase Storage** for image uploads
4. Download `firebase-service-account.json` from Project Settings → Service Accounts
5. Place the JSON file in the `backend/` directory

Start the backend server:

```bash
# Development mode (with hot reload)
npm run dev

# Production mode
npm start
```

The API will be available at `http://localhost:5000`

#### 3️⃣ Frontend Setup

```bash
# Navigate to frontend directory
cd frontend

# Install Flutter dependencies
flutter pub get

# Generate code (for Riverpod generators)
flutter pub run build_runner build
```

Configure API URL in `lib/config/constants.dart`:

```dart
// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:5000/api';

// For iOS Simulator
static const String baseUrl = 'http://localhost:5000/api';

// For Physical Device (use your PC's IP address)
static const String baseUrl = 'http://192.168.x.x:5000/api';
```

**Firebase Setup:**

1. Add `google-services.json` to `android/app/`
2. Add `GoogleService-Info.plist` to `ios/Runner/`
3. Configure Firebase in `lib/firebase_options.dart` (auto-generated)

**Google Maps Setup:**

Add your API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

And to `ios/Runner/AppDelegate.swift`:

```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

#### 4️⃣ Run the Application

**Backend:**
```bash
cd backend
npm run dev
```

**Frontend:**
```bash
cd frontend
flutter run
```

Or use the PowerShell script:
```powershell
cd frontend
.\run_app.ps1
```

---

## 📚 API Documentation

### Authentication Endpoints

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| `POST` | `/api/auth/register` | Register new user (Client/Owner) | Public |
| `POST` | `/api/auth/login` | Login user | Public |
| `GET` | `/api/auth/me` | Get current user profile | Private |
| `PUT` | `/api/auth/profile` | Update user profile | Private |
| `PUT` | `/api/auth/password` | Change password | Private |

### Cafe Endpoints

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| `GET` | `/api/cafes` | List all cafes (with search) | Public |
| `GET` | `/api/cafes/nearby` | Find nearby cafes | Public |
| `GET` | `/api/cafes/:id` | Get cafe details | Public |
| `GET` | `/api/cafes/:id/availability` | Check slot availability | Public |
| `POST` | `/api/cafes` | Create new cafe | Owner |
| `GET` | `/api/cafes/owner/my-cafes` | Get owner's cafes | Owner |
| `PUT` | `/api/cafes/:id` | Update cafe | Owner |
| `DELETE` | `/api/cafes/:id` | Delete cafe | Owner |

### Booking Endpoints

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| `POST` | `/api/bookings/check-availability` | Check slot availability | Public |
| `POST` | `/api/bookings` | Create booking | Client |
| `GET` | `/api/bookings/my-bookings` | Get user's bookings | Private |
| `GET` | `/api/bookings/:id` | Get booking details | Private |
| `PUT` | `/api/bookings/:id/cancel` | Cancel booking | Client |
| `GET` | `/api/bookings/cafe/:cafeId` | Get cafe bookings | Owner |
| `PUT` | `/api/bookings/:id/status` | Update booking status | Owner |

### Review & Community Endpoints

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| `POST` | `/api/reviews` | Create review | Client |
| `GET` | `/api/reviews/cafe/:cafeId` | Get cafe reviews | Public |
| `GET` | `/api/community` | Get community posts | Public |
| `POST` | `/api/community` | Create community post | Private |

### Upload Endpoints

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| `POST` | `/api/upload/image` | Upload image | Private |
| `POST` | `/api/upload/images` | Upload multiple images | Private |

---

## 🎨 Design System

### Color Palette

| Color | Hex Code | Usage |
|-------|----------|-------|
| **True Black** | `#000000` | Primary background |
| **Surface Dark** | `#121212` | Cards and surfaces |
| **Neon Purple** | `#BC13FE` | Primary accent, CTAs |
| **Cyber Cyan** | `#00E5FF` | Secondary accent, links |
| **Matrix Green** | `#39FF14` | Success states |
| **Cyber Red** | `#FF003C` | Error states, warnings |
| **Electric Yellow** | `#FFE600` | Ratings, highlights |

### Typography

- **Primary Font**: Google Fonts (configurable via `google_fonts` package)
- **Icons**: Iconsax icon library

---

## 🔐 Security Features

- **JWT Authentication**: Secure token-based authentication
- **Password Hashing**: bcryptjs for password encryption
- **Input Validation**: express-validator for request validation
- **CORS Protection**: Configurable cross-origin resource sharing
- **Secure Storage**: Flutter Secure Storage for sensitive data
- **Firebase Security Rules**: Database and storage security

---

## 📱 Supported Platforms

- ✅ **Android** (API 21+)
- ❌ **iOS** (iOS 12+)
- ❌ Web (not currently supported)
- ❌ Desktop (not currently supported)

---

## 🧪 Testing

### Backend Testing

```bash
cd backend
npm test
```

### Frontend Testing

```bash
cd frontend
flutter test
```

---

## 📦 Building for Production

### Android APK

```bash
cd frontend
flutter build apk --release
```

### Android App Bundle (for Play Store)

```bash
cd frontend
flutter build appbundle --release
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- **Flutter**: Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- **JavaScript**: Follow [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- Use meaningful commit messages
- Add comments for complex logic

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Google Maps for location services
- All open-source contributors whose packages made this possible

---

## 📞 Support & Contact

- **Issues**: [GitHub Issues](https://github.com/MohitSAGAR11/XPerience_Gaming/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MohitSAGAR11/XPerience_Gaming/discussions)

---

## 🔮 Roadmap

### Upcoming Features

- [ ] **Payment Integration**: Razorpay payment gateway
- [ ] **Real-time Availability**: WebSocket-based live updates
- [ ] **Advanced Analytics**: Detailed performance metrics for owners
- [ ] **Loyalty Program**: Points and rewards system
- [ ] **In-app Chat**: Direct communication between gamers and owners
- [ ] **Social Features**: Friend system and gaming groups
- [ ] **Tournament Support**: Organize and participate in gaming tournaments
- [ ] **Multi-language Support**: Internationalization (i18n)

---

<div align="center">

**Made with ❤️ by the Mohit Sagar**

⭐ Star this repo if you find it helpful!

</div>

