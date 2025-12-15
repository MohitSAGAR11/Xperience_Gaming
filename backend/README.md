# 🎮 Gaming Cafe Backend API

A robust Node.js/Express backend for a Gaming Cafe discovery and booking platform. Built with Firebase Firestore (NoSQL) and Firebase Admin SDK.

## ✨ Features

- **Dual Role Authentication**: Secure JWT-based auth for Clients (Gamers) and Owners
- **Geospatial Discovery**: Find nearby cafes using Haversine formula
- **Hybrid Search**: Search cafes by name or available games
- **PC Station Booking**: Book PC stations with detailed hardware specs
- **Hardware & Game Inventory**: Track detailed PC specs and game libraries
- **Conflict-Free Booking**: Real-time slot availability with double-booking prevention
- **Automated Billing**: Calculates costs based on duration and hourly rates
- **Booking History**: Track past and upcoming reservations

## 📁 Project Structure

```
backend/
├── .env                     # Environment variables
├── server.js                # Entry point
└── src/
    ├── config/
    │   └── db.js            # Database connection
    ├── models/
    │   ├── index.js         # Model relationships
    │   ├── User.js
    │   ├── Cafe.js
    │   └── Booking.js
    ├── middleware/
    │   └── authMiddleware.js
    ├── controllers/
    │   ├── authController.js
    │   ├── cafeController.js
    │   └── bookingController.js
    └── routes/
        ├── authRoutes.js
        ├── cafeRoutes.js
        └── bookingRoutes.js
```

## 🚀 Quick Start

### Prerequisites

- Node.js v18+
- Firebase project with Firestore enabled

### Installation

1. **Clone and navigate to backend**
   ```bash
   cd backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your Firebase credentials
   ```

4. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable **Firestore Database** and **Firebase Authentication**
   - Enable **Firebase Storage** for image uploads
   - Download `firebase-service-account.json` from Project Settings → Service Accounts
   - Place the JSON file in the `backend/` directory

5. **Start the server**
   ```bash
   # Development (with hot reload)
   npm run dev

   # Production
   npm start
   ```

## 📚 API Endpoints

### Authentication (`/api/auth`)

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| POST | `/register` | Register new user | Public |
| POST | `/login` | Login user | Public |
| GET | `/me` | Get current user | Private |
| PUT | `/profile` | Update profile | Private |
| PUT | `/password` | Change password | Private |

### Cafes (`/api/cafes`)

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| GET | `/` | List all cafes | Public |
| GET | `/nearby` | Find nearby cafes | Public |
| GET | `/:id` | Get cafe details | Public |
| GET | `/:id/availability` | Check slot availability | Public |
| POST | `/` | Create cafe | Owner |
| GET | `/owner/my-cafes` | Get owner's cafes | Owner |
| PUT | `/:id` | Update cafe | Owner |
| DELETE | `/:id` | Delete cafe | Owner |

### Bookings (`/api/bookings`)

| Method | Endpoint | Description | Access |
|--------|----------|-------------|--------|
| POST | `/check-availability` | Check slot availability | Public |
| POST | `/` | Create booking | Client |
| GET | `/my-bookings` | Get user's bookings | Private |
| GET | `/:id` | Get booking details | Private |
| PUT | `/:id/cancel` | Cancel booking | Client |
| GET | `/cafe/:cafeId` | Get cafe bookings | Owner |
| PUT | `/:id/status` | Update booking status | Owner |

## 🔐 Authentication

All protected routes require a Bearer token in the Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

## 📍 Geospatial Search Example

Find cafes within 5km of a location:

```bash
GET /api/cafes/nearby?latitude=28.6139&longitude=77.2090&radius=5
```

## 🎮 Hybrid Search Example

Search by cafe name or game title:

```bash
GET /api/cafes?search=Valorant
```

## 📅 Booking Flow

### PC Station Booking

1. **Check PC Availability**
   ```json
   POST /api/bookings/check-availability
   {
     "cafeId": "uuid",
     "stationType": "pc",
     "stationNumber": 1,
     "bookingDate": "2024-12-25",
     "startTime": "14:00",
     "endTime": "17:00"
   }
   ```

2. **Create PC Booking**
   ```json
   POST /api/bookings
   {
     "cafeId": "uuid",
     "stationType": "pc",
     "stationNumber": 1,
     "bookingDate": "2024-12-25",
     "startTime": "14:00",
     "endTime": "17:00"
   }
   ```

### Billing Response

Response includes automated billing:
```json
{
  "booking": { ... },
  "billing": {
    "stationType": "pc",
    "durationHours": 3,
    "hourlyRate": 100,
    "totalAmount": 300
  }
}
```

## 🏪 Cafe Setup

Create a cafe with PC inventory:

```json
POST /api/cafes
{
  "name": "Epic Gaming Hub",
  "address": "123 Gaming Street",
  "city": "Mumbai",
  "latitude": 19.0760,
  "longitude": 72.8777,
  "hourlyRate": 100,
  "totalPcStations": 20,
  "pcHourlyRate": 100,
  "pcSpecs": {
    "cpu": "Intel i7-13700K",
    "gpu": "RTX 4070",
    "ram": "32GB DDR5",
    "monitors": "27\" 165Hz"
  },
  "pcGames": ["Valorant", "CS2", "Fortnite", "GTA V"]
}
```

## 🛠️ Tech Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: Firebase Firestore (NoSQL)
- **Cloud Services**: Firebase Admin SDK
- **Auth**: Firebase Auth + JWT + bcryptjs
- **File Upload**: Multer + Firebase Storage
- **Validation**: express-validator

## 📝 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | 5000 |
| `NODE_ENV` | Environment | development |
| `FIREBASE_SERVICE_ACCOUNT` | Path to Firebase service account JSON | ./firebase-service-account.json |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket name | - |
| `JWT_SECRET` | JWT signing secret | - |
| `JWT_EXPIRES_IN` | Token expiry | 7d |
| `CORS_ORIGIN` | Allowed origins | * |

## 📄 License

ISC

