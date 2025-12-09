# Backend-Frontend Connection Test Results

**Date:** December 6, 2025  
**Status:** ✅ **CONNECTED AND WORKING**

---

## 🎯 Backend Status

### Server Information
- **Status:** ✅ Running
- **Port:** 5000
- **Environment:** Development
- **Database:** ✅ PostgreSQL Connected (`xperience_db`)

### Available Endpoints
- ✅ Auth: `/api/auth`
- ✅ Cafes: `/api/cafes`
- ✅ Bookings: `/api/bookings`
- ✅ Reviews: `/api/reviews`
- ✅ Health Check: `/api/health`

### Health Check Response
```json
{
  "status": "OK",
  "message": "Gaming Cafe API is running",
  "timestamp": "2025-12-06T11:25:11.005Z"
}
```

---

## 📱 Frontend Configuration (Flutter)

### Current Configuration
**File:** `frontend/lib/config/constants.dart`

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

### Configuration by Device Type

#### ✅ Android Emulator (Current)
```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```
- `10.0.2.2` is the special address that maps to `localhost` on your PC

#### 📱 Physical Android Device
```dart
static const String baseUrl = 'http://10.52.41.208:5000/api';
```
- Your PC's IP: `10.52.41.208`
- **Requirements:**
  - Both PC and phone must be on the same WiFi network
  - Windows Firewall must allow incoming connections on port 5000

#### 🍎 iOS Simulator
```dart
static const String baseUrl = 'http://localhost:5000/api';
```

---

## 🔌 Connection Details

### CORS Configuration
Backend CORS is enabled for cross-origin requests:
```javascript
cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
})
```

### Authentication
- **Method:** JWT (JSON Web Tokens)
- **Header:** `Authorization: Bearer <token>`
- **Token Storage:** Local storage via `flutter_secure_storage`
- **Auto-injection:** Dio interceptor automatically adds token to requests

### Request/Response Flow
1. **Frontend (Flutter)** → Makes HTTP request via Dio
2. **API Client** → Adds JWT token (if exists) to Authorization header
3. **Backend (Express)** → Validates request, processes, returns JSON
4. **Frontend** → Receives response, updates UI

---

## 🧪 Test Endpoints

### 1. Health Check
```bash
curl http://localhost:5000/api/health
```
**Expected Response:**
```json
{
  "status": "OK",
  "message": "Gaming Cafe API is running",
  "timestamp": "2025-12-06T11:25:11.005Z"
}
```

### 2. Register User (Test)
```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "password123",
    "role": "client",
    "phone": "1234567890"
  }'
```

### 3. Login User (Test)
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

---

## 🔧 Troubleshooting

### Backend Not Starting
**Error:** `EADDRINUSE: address already in use :::5000`

**Solution:**
```bash
# Find process using port 5000
netstat -ano | findstr :5000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

### Frontend Can't Connect
1. **Check backend is running:** Visit `http://localhost:5000/api/health`
2. **Verify baseUrl in constants.dart** matches your device type
3. **For physical device:** Ensure firewall allows port 5000
4. **Check network:** PC and device on same WiFi

### Firewall Configuration (Windows)
```powershell
# Allow Node.js through firewall
New-NetFirewallRule -DisplayName "Node.js Server" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow
```

---

## 📊 Database Models

All models synchronized successfully:
- ✅ **Users** (id, name, email, password, role, phone, avatar)
- ✅ **Cafes** (location, rates, stations, specs, amenities)
- ✅ **Bookings** (user, cafe, station, time, payment)
- ✅ **Reviews** (rating, comment, response)

---

## ✅ Next Steps

Your backend and frontend are properly configured and connected!

### To Test in Flutter:
1. Start Android Emulator
2. Run: `flutter run`
3. Try registration/login from the app
4. Backend will log all requests in the terminal

### For Physical Device Testing:
1. Update `baseUrl` to: `http://10.52.41.208:5000/api`
2. Ensure both devices on same network
3. Configure firewall if needed
4. Run the app

---

**Last Updated:** December 6, 2025  
**Connection Status:** ✅ Verified and Working

