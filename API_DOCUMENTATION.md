# XPerience Gaming - Backend API Documentation

Base URL: `http://10.10.4.37:5000/api` (or `http://localhost:5000/api`)

## 🔐 Authentication

All protected endpoints require a Firebase ID token in the Authorization header:
```
Authorization: Bearer <firebase_id_token>
```

**Roles:**
- `client` - Regular users who can book gaming stations
- `owner` - Cafe owners who can manage cafes

---

## 📋 AUTH ENDPOINTS (`/api/auth`)

### 1. Create User Profile
**After Firebase Auth registration, create user profile in Firestore**

**Endpoint:** `POST /api/auth/create-profile`  
**Auth:** Firebase Token Required (protectNewUser)  
**Body:**
```json
{
  "name": "John Doe",           // Required, 2-100 chars
  "role": "client",             // Optional, "client" or "owner", defaults to "client"
  "phone": "+1234567890"        // Optional
}
```

**Response:**
```json
{
  "success": true,
  "message": "Profile created successfully",
  "data": {
    "user": {
      "id": "firebase_uid",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "client",
      "phone": "+1234567890",
      "avatar": null,
      "createdAt": "2025-12-09T...",
      "updatedAt": "2025-12-09T..."
    }
  }
}
```

---

### 2. Get Current User Profile
**Endpoint:** `GET /api/auth/me`  
**Auth:** Firebase Token Required (protect)  
**Body:** None

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "firebase_uid",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "client",
      "phone": "+1234567890",
      "avatar": null,
      "createdAt": "2025-12-09T...",
      "updatedAt": "2025-12-09T..."
    }
  }
}
```

---

### 3. Update User Profile
**Endpoint:** `PUT /api/auth/profile`  
**Auth:** Firebase Token Required (protect)  
**Body:**
```json
{
  "name": "John Updated",       // Optional
  "phone": "+9876543210",       // Optional
  "avatar": "https://..."       // Optional, URL to avatar image
}
```

**Response:**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "user": { /* updated user object */ }
  }
}
```

---

### 4. Change Password
**Endpoint:** `PUT /api/auth/password`  
**Auth:** Firebase Token Required (protect)  
**Body:**
```json
{
  "newPassword": "newpass123"   // Required, min 6 chars
}
```

**Response:**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

---

### 5. Logout
**Endpoint:** `POST /api/auth/logout`  
**Auth:** Firebase Token Required (protect)  
**Body:** None

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## 🎮 CAFE ENDPOINTS (`/api/cafes`)

### 1. Get All Cafes
**Endpoint:** `GET /api/cafes`  
**Auth:** None (Public)  
**Query Params:**
- `page` (optional) - Page number, default 1
- `limit` (optional) - Items per page, default 10
- `city` (optional) - Filter by city

**Response:**
```json
{
  "success": true,
  "data": {
    "cafes": [ /* array of cafe objects */ ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 50
    }
  }
}
```

---

### 2. Get Nearby Cafes
**Endpoint:** `GET /api/cafes/nearby`  
**Auth:** None (Public)  
**Query Params:**
- `latitude` (required) - User's latitude
- `longitude` (required) - User's longitude
- `radius` (optional) - Search radius in km, default 10

**Example:** `/api/cafes/nearby?latitude=28.6139&longitude=77.2090&radius=5`

**Response:**
```json
{
  "success": true,
  "data": {
    "cafes": [
      {
        "id": "cafe-uuid",
        "name": "Epic Gaming Cafe",
        "address": "123 Main St",
        "city": "Delhi",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "distance": 2.5,  // in km
        "hourlyRate": 100,
        "rating": 4.5,
        "totalReviews": 20,
        /* ... more fields */
      }
    ]
  }
}
```

---

### 3. Get Cafe by ID
**Endpoint:** `GET /api/cafes/:id`  
**Auth:** None (Public)  
**Params:** `id` - Cafe UUID

**Response:**
```json
{
  "success": true,
  "data": {
    "cafe": {
      "id": "cafe-uuid",
      "name": "Epic Gaming Cafe",
      "address": "123 Main St",
      "city": "Delhi",
      "latitude": 28.6139,
      "longitude": 77.2090,
      "hourlyRate": 100,
      "totalPcStations": 10,
      "pcHourlyRate": 100,
      "pcSpecs": {
        "processor": "Intel i7",
        "ram": "16GB",
        "gpu": "RTX 3060"
      },
      "pcGames": ["Valorant", "CS:GO", "GTA V"],
      "consoles": {
        "ps5": 2,
        "ps4": 3,
        "xbox_series_x": 1
      },
      "totalConsoles": 6,
      "openingTime": "10:00:00",
      "closingTime": "23:00:00",
      "photos": ["url1", "url2"],
      "amenities": ["WiFi", "AC", "Parking"],
      "availableGames": ["FIFA", "COD"],
      "rating": 4.5,
      "totalReviews": 20,
      "ownerId": "owner-uid",
      "createdAt": "2025-12-09T...",
      "updatedAt": "2025-12-09T..."
    }
  }
}
```

---

### 4. Get Cafe Availability
**Endpoint:** `GET /api/cafes/:id/availability`  
**Auth:** None (Public)  
**Params:** `id` - Cafe UUID  
**Query Params:**
- `date` (required) - Date in YYYY-MM-DD format
- `stationType` (optional) - "pc" or "console"
- `consoleType` (optional) - ps5, ps4, xbox_series_x, etc.

**Example:** `/api/cafes/abc-123/availability?date=2025-12-10&stationType=pc`

**Response:**
```json
{
  "success": true,
  "data": {
    "availability": [
      {
        "stationNumber": 1,
        "bookedSlots": [
          {
            "startTime": "10:00:00",
            "endTime": "12:00:00"
          }
        ]
      }
    ]
  }
}
```

---

### 5. Create Cafe (Owner Only)
**Endpoint:** `POST /api/cafes`  
**Auth:** Firebase Token Required (protect + ownerOnly)  
**Body:**
```json
{
  "name": "Epic Gaming Cafe",           // Required, max 200 chars
  "address": "123 Main St",             // Required
  "city": "Delhi",                      // Required
  "latitude": 28.6139,                  // Required, -90 to 90
  "longitude": 77.2090,                 // Required, -180 to 180
  "hourlyRate": 100,                    // Required, min 0
  
  // PC Stations (optional)
  "totalPcStations": 10,                // Optional, min 0
  "pcHourlyRate": 100,                  // Optional, min 0
  "pcSpecs": {                          // Optional, object
    "processor": "Intel i7",
    "ram": "16GB",
    "gpu": "RTX 3060"
  },
  "pcGames": ["Valorant", "CS:GO"],     // Optional, array
  
  // Console Stations (optional)
  "consoles": {                         // Optional, object
    "ps5": 2,
    "ps4": 3,
    "xbox_series_x": 1
  },
  "totalConsoles": 6,                   // Optional, min 0
  
  // Timing (optional)
  "openingTime": "10:00:00",            // Optional, HH:MM or HH:MM:SS
  "closingTime": "23:00:00",            // Optional, HH:MM or HH:MM:SS
  
  // Other (optional)
  "photos": ["url1", "url2"],           // Optional, array
  "amenities": ["WiFi", "AC"],          // Optional, array
  "availableGames": ["FIFA", "COD"]     // Optional, array
}
```

**Response:**
```json
{
  "success": true,
  "message": "Cafe created successfully",
  "data": {
    "cafe": { /* cafe object with id */ }
  }
}
```

---

### 6. Get My Cafes (Owner Only)
**Endpoint:** `GET /api/cafes/owner/my-cafes`  
**Auth:** Firebase Token Required (protect + ownerOnly)

**Response:**
```json
{
  "success": true,
  "data": {
    "cafes": [ /* array of owner's cafes */ ]
  }
}
```

---

### 7. Update Cafe (Owner Only)
**Endpoint:** `PUT /api/cafes/:id`  
**Auth:** Firebase Token Required (protect + ownerOnly)  
**Params:** `id` - Cafe UUID  
**Body:** Same as Create Cafe (all fields optional)

**Response:**
```json
{
  "success": true,
  "message": "Cafe updated successfully",
  "data": {
    "cafe": { /* updated cafe object */ }
  }
}
```

---

### 8. Delete Cafe (Owner Only)
**Endpoint:** `DELETE /api/cafes/:id`  
**Auth:** Firebase Token Required (protect + ownerOnly)  
**Params:** `id` - Cafe UUID

**Response:**
```json
{
  "success": true,
  "message": "Cafe deleted successfully"
}
```

---

## 📅 BOOKING ENDPOINTS (`/api/bookings`)

### 1. Check Availability
**Check if a specific station/console is available for booking**

**Endpoint:** `POST /api/bookings/check-availability`  
**Auth:** None (Public)  
**Body:**
```json
{
  "cafeId": "cafe-uuid",                // Required, UUID
  "stationType": "pc",                  // Optional, "pc" or "console"
  "consoleType": "ps5",                 // Optional, ps5/ps4/xbox_series_x/xbox_series_s/xbox_one/nintendo_switch
  "stationNumber": 1,                   // Required, min 1
  "bookingDate": "2025-12-10",          // Required, YYYY-MM-DD
  "startTime": "10:00",                 // Required, HH:MM or HH:MM:SS
  "endTime": "12:00"                    // Required, HH:MM or HH:MM:SS
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "available": true,
    "message": "Station is available for booking"
  }
}
```

---

### 2. Get Available Stations
**Get all available stations for a time slot (optimized)**

**Endpoint:** `GET /api/bookings/available-stations`  
**Auth:** Firebase Token Required (protect)  
**Query Params:**
- `cafeId` (required) - Cafe UUID
- `date` (required) - YYYY-MM-DD
- `startTime` (required) - HH:MM
- `endTime` (required) - HH:MM
- `stationType` (optional) - "pc" or "console"
- `consoleType` (optional) - console type

**Example:** `/api/bookings/available-stations?cafeId=abc-123&date=2025-12-10&startTime=10:00&endTime=12:00&stationType=pc`

**Response:**
```json
{
  "success": true,
  "data": {
    "availableStations": [1, 2, 5, 7, 9]
  }
}
```

---

### 3. Create Booking (Client Only)
**Endpoint:** `POST /api/bookings`  
**Auth:** Firebase Token Required (protect + clientOnly)  
**Body:**
```json
{
  "cafeId": "cafe-uuid",                // Required, UUID
  "stationType": "pc",                  // Optional, "pc" or "console", defaults to "pc"
  "consoleType": "ps5",                 // Optional (required if stationType is "console")
  "stationNumber": 1,                   // Required, min 1
  "bookingDate": "2025-12-10",          // Required, YYYY-MM-DD
  "startTime": "10:00",                 // Required, HH:MM or HH:MM:SS
  "endTime": "12:00",                   // Required, HH:MM or HH:MM:SS
  "notes": "Birthday party"             // Optional
}
```

**Response:**
```json
{
  "success": true,
  "message": "Booking created successfully",
  "data": {
    "booking": {
      "id": "booking-uuid",
      "cafeId": "cafe-uuid",
      "userId": "user-uid",
      "stationType": "pc",
      "consoleType": null,
      "stationNumber": 1,
      "bookingDate": "2025-12-10",
      "startTime": "10:00:00",
      "endTime": "12:00:00",
      "totalAmount": 200,
      "status": "pending",               // pending/confirmed/cancelled/completed
      "paymentStatus": "unpaid",         // unpaid/paid/refunded
      "notes": "Birthday party",
      "createdAt": "2025-12-09T...",
      "updatedAt": "2025-12-09T..."
    }
  }
}
```

---

### 4. Get My Bookings
**Endpoint:** `GET /api/bookings/my-bookings`  
**Auth:** Firebase Token Required (protect)  
**Query Params:**
- `status` (optional) - Filter by status: pending/confirmed/cancelled/completed

**Example:** `/api/bookings/my-bookings?status=confirmed`

**Response:**
```json
{
  "success": true,
  "data": {
    "bookings": [
      {
        "id": "booking-uuid",
        "cafe": { /* cafe details */ },
        "stationType": "pc",
        "stationNumber": 1,
        "bookingDate": "2025-12-10",
        "startTime": "10:00:00",
        "endTime": "12:00:00",
        "totalAmount": 200,
        "status": "confirmed",
        "paymentStatus": "paid",
        /* ... */
      }
    ]
  }
}
```

---

### 5. Get Booking by ID
**Endpoint:** `GET /api/bookings/:id`  
**Auth:** Firebase Token Required (protect)  
**Params:** `id` - Booking UUID

**Response:**
```json
{
  "success": true,
  "data": {
    "booking": { /* booking object with cafe details */ }
  }
}
```

---

### 6. Cancel Booking
**Endpoint:** `PUT /api/bookings/:id/cancel`  
**Auth:** Firebase Token Required (protect)  
**Params:** `id` - Booking UUID  
**Body:** None

**Response:**
```json
{
  "success": true,
  "message": "Booking cancelled successfully",
  "data": {
    "booking": { /* updated booking object */ }
  }
}
```

---

### 7. Get Cafe Bookings (Owner Only)
**Get all bookings for a specific cafe**

**Endpoint:** `GET /api/bookings/cafe/:cafeId`  
**Auth:** Firebase Token Required (protect + ownerOnly)  
**Params:** `cafeId` - Cafe UUID  
**Query Params:**
- `status` (optional) - Filter by status
- `date` (optional) - Filter by date (YYYY-MM-DD)

**Response:**
```json
{
  "success": true,
  "data": {
    "bookings": [ /* array of bookings with user details */ ]
  }
}
```

---

### 8. Update Booking Status (Owner Only)
**Endpoint:** `PUT /api/bookings/:id/status`  
**Auth:** Firebase Token Required (protect + ownerOnly)  
**Params:** `id` - Booking UUID  
**Body:**
```json
{
  "status": "confirmed"        // pending/confirmed/cancelled/completed
}
```

**Response:**
```json
{
  "success": true,
  "message": "Booking status updated",
  "data": {
    "booking": { /* updated booking */ }
  }
}
```

---

## ⭐ REVIEW ENDPOINTS (`/api/reviews`)

### 1. Get Cafe Reviews
**Endpoint:** `GET /api/reviews/cafe/:cafeId`  
**Auth:** None (Public)  
**Params:** `cafeId` - Cafe UUID  
**Query Params:**
- `page` (optional) - Page number
- `limit` (optional) - Items per page
- `sort` (optional) - Sort by: recent, rating_high, rating_low

**Example:** `/api/reviews/cafe/abc-123?page=1&limit=10&sort=recent`

**Response:**
```json
{
  "success": true,
  "data": {
    "reviews": [
      {
        "id": "review-uuid",
        "cafeId": "cafe-uuid",
        "userId": "user-uid",
        "userName": "John Doe",
        "userAvatar": "https://...",
        "rating": 5,
        "title": "Amazing place!",
        "comment": "Great gaming cafe with excellent service",
        "ownerResponse": "Thank you!",
        "ownerResponseDate": "2025-12-09T...",
        "createdAt": "2025-12-09T...",
        "updatedAt": "2025-12-09T..."
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 50
    },
    "summary": {
      "averageRating": 4.5,
      "totalReviews": 50,
      "ratingDistribution": {
        "5": 30,
        "4": 15,
        "3": 3,
        "2": 1,
        "1": 1
      }
    }
  }
}
```

---

### 2. Get My Reviews
**Endpoint:** `GET /api/reviews/my-reviews`  
**Auth:** Firebase Token Required (protect)

**Response:**
```json
{
  "success": true,
  "data": {
    "reviews": [ /* array of user's reviews with cafe details */ ]
  }
}
```

---

### 3. Check User Review
**Check if user has already reviewed a cafe**

**Endpoint:** `GET /api/reviews/check/:cafeId`  
**Auth:** Firebase Token Required (protect)  
**Params:** `cafeId` - Cafe UUID

**Response:**
```json
{
  "success": true,
  "data": {
    "hasReviewed": true,
    "review": { /* user's review if exists */ }
  }
}
```

---

### 4. Create Review (Client Only)
**Endpoint:** `POST /api/reviews`  
**Auth:** Firebase Token Required (protect + clientOnly)  
**Body:**
```json
{
  "cafeId": "cafe-uuid",                // Required, UUID
  "rating": 5,                          // Required, 1-5
  "title": "Amazing place!",            // Optional, max 100 chars
  "comment": "Great gaming cafe..."     // Optional, max 1000 chars
}
```

**Response:**
```json
{
  "success": true,
  "message": "Review created successfully",
  "data": {
    "review": { /* review object */ }
  }
}
```

---

### 5. Update Review
**Endpoint:** `PUT /api/reviews/:id`  
**Auth:** Firebase Token Required (protect, must be review owner)  
**Params:** `id` - Review UUID  
**Body:**
```json
{
  "rating": 4,                          // Optional, 1-5
  "title": "Updated title",             // Optional, max 100 chars
  "comment": "Updated comment"          // Optional, max 1000 chars
}
```

**Response:**
```json
{
  "success": true,
  "message": "Review updated successfully",
  "data": {
    "review": { /* updated review */ }
  }
}
```

---

### 6. Delete Review
**Endpoint:** `DELETE /api/reviews/:id`  
**Auth:** Firebase Token Required (protect, must be review owner)  
**Params:** `id` - Review UUID

**Response:**
```json
{
  "success": true,
  "message": "Review deleted successfully"
}
```

---

### 7. Respond to Review (Owner Only)
**Endpoint:** `POST /api/reviews/:id/respond`  
**Auth:** Firebase Token Required (protect + ownerOnly)  
**Params:** `id` - Review UUID  
**Body:**
```json
{
  "response": "Thank you for your feedback!"  // Required, max 500 chars
}
```

**Response:**
```json
{
  "success": true,
  "message": "Response added successfully",
  "data": {
    "review": { /* updated review with owner response */ }
  }
}
```

---

## 🏥 HEALTH CHECK

### Health Check
**Endpoint:** `GET /api/health`  
**Auth:** None (Public)

**Response:**
```json
{
  "status": "OK",
  "message": "Gaming Cafe API is running",
  "timestamp": "2025-12-09T13:00:00.000Z"
}
```

---

## 🚨 Error Responses

All error responses follow this format:

```json
{
  "success": false,
  "message": "Error message here",
  "errors": [  // Optional, for validation errors
    {
      "field": "email",
      "message": "Invalid email format"
    }
  ]
}
```

**Common HTTP Status Codes:**
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation error)
- `401` - Unauthorized (no token or invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `500` - Internal Server Error

---

## 📝 Notes

1. **Authentication Flow:**
   - Register/Login with Firebase Auth on frontend
   - Get Firebase ID token
   - Call `/api/auth/create-profile` to create Firestore profile
   - Use Firebase token for all subsequent requests

2. **Console Types:**
   - `ps5`, `ps4`, `xbox_series_x`, `xbox_series_s`, `xbox_one`, `nintendo_switch`

3. **Time Format:**
   - Use 24-hour format: `HH:MM` or `HH:MM:SS`
   - Example: `14:30` for 2:30 PM

4. **Date Format:**
   - Use ISO format: `YYYY-MM-DD`
   - Example: `2025-12-10`

5. **Pagination:**
   - Default page: 1
   - Default limit: 10
   - Max limit: 100

