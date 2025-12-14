# 💳 Payment & Refund Implementation Summary

## Quick Overview

### **Payment Portal (Confirm Booking)**
When user clicks "CONFIRM BOOKING" → Open Razorpay payment → Verify payment → Confirm booking

### **Refund (Cancel Booking)**
When user clicks "Cancel Booking" → Check if paid → Auto-initiate refund → Update booking status

---

## 🔴 What YOU Need to Do (Backend)

### 1. **Install & Configure Razorpay**
```bash
cd backend
npm install razorpay
```

Add to `.env`:
```env
RAZORPAY_KEY_ID=rzp_test_xxxxx
RAZORPAY_KEY_SECRET=your_secret_key
```

### 2. **Create 3 Backend Files**
- `backend/src/controllers/paymentController.js` - Payment order creation & verification
- `backend/src/controllers/refundController.js` - Refund initiation
- `backend/src/routes/paymentRoutes.js` - Payment routes

### 3. **Update Existing Files**
- `backend/src/routes/bookingRoutes.js` - Add payment routes
- `backend/src/controllers/bookingController.js` - Update `cancelBooking` to auto-refund

### 4. **Update Booking Schema**
Add these fields to booking documents:
- `paymentOrderId`, `paymentId`, `paymentSignature`
- `paymentStatus` (unpaid/pending/paid/failed/refunded)
- `refundId`, `refundAmount`, `refundStatus`, `refundedAt`

---

## 🔵 What I Need to Do (Frontend)

### 1. **Add Razorpay Package**
```yaml
# pubspec.yaml
razorpay_flutter: ^1.3.6
```

### 2. **Create Payment Service**
- `frontend/lib/services/payment_service.dart` - Handle Razorpay integration

### 3. **Update Booking Flow**
- `frontend/lib/screens/client/booking/slot_selection_screen.dart` - Change "CONFIRM" to initiate payment
- Create payment screen or integrate into existing flow

### 4. **Update Cancel Booking**
- `frontend/lib/screens/client/bookings/my_bookings_screen.dart` - Show refund info
- Update booking model with refund fields

---

## 📋 Backend Endpoints Needed

### Payment Endpoints:
```
POST /api/payments/create-order
Body: { bookingId, amount }
Response: { orderId, amount, currency, keyId }

POST /api/payments/verify-payment
Body: { orderId, paymentId, signature, bookingId }
Response: { success, booking }
```

### Refund Endpoints:
```
POST /api/payments/:bookingId/refund
Body: { reason? }
Response: { success, refundId, refundAmount }
```

---

## 🔄 Flow Diagrams

### Payment Flow:
```
User clicks "CONFIRM BOOKING"
  ↓
Frontend: Call /api/payments/create-order
  ↓
Backend: Create Razorpay order, return orderId
  ↓
Frontend: Open Razorpay checkout
  ↓
User completes payment
  ↓
Frontend: Call /api/payments/verify-payment
  ↓
Backend: Verify signature, update booking to 'paid' & 'confirmed'
  ↓
Frontend: Navigate to booking confirmation screen
```

### Refund Flow:
```
User clicks "Cancel Booking"
  ↓
Frontend: Call /api/bookings/:id/cancel
  ↓
Backend: Check if paymentStatus === 'paid'
  ↓
Backend: Call Razorpay refund API
  ↓
Backend: Update booking (paymentStatus: 'refunded', add refund details)
  ↓
Backend: Update booking status to 'cancelled'
  ↓
Frontend: Show refund status to user
```

---

## ⚙️ Key Implementation Details

### Cancellation Policy (Backend)
```javascript
// Full refund: 24+ hours before
// 50% refund: 12-24 hours before  
// No refund: < 12 hours before
```

### Payment Verification (Backend)
```javascript
// Always verify signature on backend
// Never trust frontend payment data
// Update booking only after verification
```

### Error Handling
- Payment failures → Allow retry
- Refund failures → Log error, notify admin
- Network errors → Show user-friendly messages

---

## 🧪 Testing Requirements

### Test with Razorpay Test Keys:
- Test payment success
- Test payment failure
- Test payment cancellation
- Test refund initiation
- Test refund status

### Test Scenarios:
1. ✅ Successful payment → Booking confirmed
2. ✅ Payment failure → Booking remains pending
3. ✅ Cancel paid booking → Refund initiated
4. ✅ Cancel unpaid booking → No refund needed

---

## 📝 Next Steps

1. **You (Backend):** Implement payment & refund controllers
2. **Me (Frontend):** Implement payment service & UI
3. **Both:** Test integration end-to-end
4. **Both:** Deploy to production with live Razorpay keys

---

**See `PAYMENT_INTEGRATION_GUIDE.md` for detailed implementation code.**

