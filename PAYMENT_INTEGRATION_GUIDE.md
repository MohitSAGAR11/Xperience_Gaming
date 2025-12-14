# 💳 Payment Integration & Refund System Guide

This document outlines everything needed to implement payment processing and refund functionality for the XPerience Gaming booking system.

---

## 📋 Table of Contents

1. [Payment Portal Integration](#payment-portal-integration)
2. [Refund System Integration](#refund-system-integration)
3. [Backend Requirements](#backend-requirements)
4. [Frontend Requirements](#frontend-requirements)
5. [Implementation Steps](#implementation-steps)

---

## 🎯 Payment Portal Integration

### **When User Clicks "CONFIRM BOOKING" in Booking Summary Popup**

### **From Your Side (Backend):**

#### 1. **Install Razorpay SDK**
```bash
cd backend
npm install razorpay
```

#### 2. **Add Razorpay Configuration to `.env`**
```env
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret
```

#### 3. **Create Payment Controller** (`backend/src/controllers/paymentController.js`)

**Required Endpoints:**

- **`POST /api/payments/create-order`** - Create Razorpay order
  - Input: `{ bookingId, amount, currency: 'INR' }`
  - Output: `{ orderId, amount, currency, keyId }`
  
- **`POST /api/payments/verify-payment`** - Verify payment signature
  - Input: `{ orderId, paymentId, signature, bookingId }`
  - Output: `{ success, message, booking }`
  
- **`POST /api/payments/payment-failed`** - Handle failed payments
  - Input: `{ orderId, bookingId, reason }`
  - Output: `{ success, message }`

#### 4. **Update Booking Model**
Add payment-related fields to booking document:
- `paymentOrderId` (String) - Razorpay order ID
- `paymentId` (String) - Razorpay payment ID
- `paymentSignature` (String) - Payment verification signature
- `paymentStatus` (String) - 'unpaid', 'pending', 'paid', 'failed', 'refunded'
- `paymentMethod` (String) - 'razorpay', 'cash', etc.
- `paidAt` (Date) - When payment was completed

#### 5. **Update Booking Creation Flow**
Modify `createBooking` in `bookingController.js`:
- Change initial `paymentStatus` from `'unpaid'` to `'pending'`
- Don't set booking status to `'confirmed'` until payment is verified
- Set booking status to `'pending'` initially

---

### **From My Side (Frontend):**

#### 1. **Add Razorpay Flutter Package**
```yaml
# frontend/pubspec.yaml
dependencies:
  razorpay_flutter: ^1.3.6
```

#### 2. **Create Payment Service** (`frontend/lib/services/payment_service.dart`)
- Initialize Razorpay
- Handle payment callbacks
- Verify payment with backend

#### 3. **Update Booking Summary Popup**
Modify `slot_selection_screen.dart`:
- Change "CONFIRM BOOKING" button to "PROCEED TO PAYMENT"
- After confirmation, call payment service instead of direct booking
- Show payment loading state

#### 4. **Create Payment Screen** (`frontend/lib/screens/client/payment/payment_screen.dart`)
- Display booking summary
- Show payment amount
- Initialize Razorpay checkout
- Handle payment success/failure

#### 5. **Update Booking Flow**
- After payment success → Navigate to booking confirmation
- After payment failure → Show error, allow retry
- Update booking status based on payment result

---

## 💰 Refund System Integration

### **When User Clicks "Cancel Booking"**

### **From Your Side (Backend):**

#### 1. **Create Refund Controller** (`backend/src/controllers/refundController.js`)

**Required Endpoints:**

- **`POST /api/payments/:bookingId/refund`** - Initiate refund
  - Input: `{ reason?, amount? }` (amount optional for partial refunds)
  - Output: `{ success, message, refundId, refundAmount }`
  
- **`GET /api/payments/:bookingId/refund-status`** - Check refund status
  - Output: `{ success, refundStatus, refundId, refundAmount }`

#### 2. **Update Cancel Booking Controller**
Modify `cancelBooking` in `bookingController.js`:
- Check if booking has `paymentStatus === 'paid'`
- If paid, automatically initiate refund
- Update `paymentStatus` to `'refunded'` after successful refund
- Add refund details to booking document

#### 3. **Refund Logic**
```javascript
// Pseudo-code for refund logic
if (booking.paymentStatus === 'paid') {
  // Calculate refund amount (full or partial based on cancellation policy)
  const refundAmount = calculateRefundAmount(booking);
  
  // Initiate Razorpay refund
  const refund = await razorpay.payments.refund(paymentId, {
    amount: refundAmount * 100, // Convert to paise
    notes: { reason: 'Booking cancelled' }
  });
  
  // Update booking
  booking.paymentStatus = 'refunded';
  booking.refundId = refund.id;
  booking.refundAmount = refundAmount;
  booking.refundedAt = new Date();
}
```

#### 4. **Cancellation Policy**
Implement cancellation policy logic:
- Full refund if cancelled X hours before booking
- Partial refund if cancelled within X hours
- No refund if cancelled after booking start time

#### 5. **Add Refund Fields to Booking Model**
- `refundId` (String) - Razorpay refund ID
- `refundAmount` (Number) - Amount refunded
- `refundStatus` (String) - 'pending', 'processed', 'failed'
- `refundedAt` (Date) - When refund was processed
- `refundReason` (String) - Reason for refund

---

### **From My Side (Frontend):**

#### 1. **Update Cancel Booking Dialog**
Modify `my_bookings_screen.dart`:
- Show refund information if booking is paid
- Display estimated refund amount
- Update UI after cancellation to show refund status

#### 2. **Add Refund Status Display**
- Show refund status in booking details
- Display refund amount and processing time
- Add refund history section

#### 3. **Update Booking Model**
Add refund-related fields to `Booking` class:
- `refundId`
- `refundAmount`
- `refundStatus`
- `refundedAt`

---

## 🔧 Backend Requirements (Detailed)

### **1. Payment Controller Implementation**

```javascript
// backend/src/controllers/paymentController.js
const Razorpay = require('razorpay');
const { db } = require('../config/firebase');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET
});

// Create Razorpay order
const createOrder = async (req, res) => {
  try {
    const { bookingId, amount } = req.body;
    
    // Verify booking exists and belongs to user
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists || bookingDoc.data().userId !== req.user.id) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    // Create Razorpay order
    const options = {
      amount: Math.round(amount * 100), // Convert to paise
      currency: 'INR',
      receipt: `booking_${bookingId}`,
      notes: {
        bookingId: bookingId,
        userId: req.user.id
      }
    };
    
    const order = await razorpay.orders.create(options);
    
    // Update booking with order ID
    await db.collection('bookings').doc(bookingId).update({
      paymentOrderId: order.id,
      paymentStatus: 'pending',
      updatedAt: new Date()
    });
    
    res.json({
      success: true,
      data: {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: process.env.RAZORPAY_KEY_ID
      }
    });
  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({ success: false, message: 'Failed to create order' });
  }
};

// Verify payment
const verifyPayment = async (req, res) => {
  try {
    const { orderId, paymentId, signature, bookingId } = req.body;
    
    // Verify signature
    const crypto = require('crypto');
    const generatedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');
    
    if (generatedSignature !== signature) {
      return res.status(400).json({ success: false, message: 'Invalid payment signature' });
    }
    
    // Update booking
    await db.collection('bookings').doc(bookingId).update({
      paymentId: paymentId,
      paymentSignature: signature,
      paymentStatus: 'paid',
      status: 'confirmed',
      paidAt: new Date(),
      updatedAt: new Date()
    });
    
    // Fetch updated booking
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const booking = { id: bookingDoc.id, ...bookingDoc.data() };
    
    res.json({
      success: true,
      message: 'Payment verified successfully',
      data: { booking }
    });
  } catch (error) {
    console.error('Verify payment error:', error);
    res.status(500).json({ success: false, message: 'Payment verification failed' });
  }
};

module.exports = { createOrder, verifyPayment };
```

### **2. Refund Controller Implementation**

```javascript
// backend/src/controllers/refundController.js
const Razorpay = require('razorpay');
const { db } = require('../config/firebase');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET
});

// Initiate refund
const initiateRefund = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { reason, amount } = req.body;
    
    // Get booking
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    const booking = bookingDoc.data();
    
    // Check if payment was made
    if (booking.paymentStatus !== 'paid' || !booking.paymentId) {
      return res.status(400).json({ 
        success: false, 
        message: 'No payment found to refund' 
      });
    }
    
    // Calculate refund amount (implement your cancellation policy)
    const refundAmount = amount || calculateRefundAmount(booking);
    
    // Initiate refund via Razorpay
    const refund = await razorpay.payments.refund(booking.paymentId, {
      amount: Math.round(refundAmount * 100), // Convert to paise
      notes: {
        reason: reason || 'Booking cancelled',
        bookingId: bookingId
      }
    });
    
    // Update booking
    await db.collection('bookings').doc(bookingId).update({
      refundId: refund.id,
      refundAmount: refundAmount,
      refundStatus: refund.status,
      paymentStatus: 'refunded',
      refundedAt: new Date(),
      updatedAt: new Date()
    });
    
    res.json({
      success: true,
      message: 'Refund initiated successfully',
      data: {
        refundId: refund.id,
        refundAmount: refundAmount,
        refundStatus: refund.status
      }
    });
  } catch (error) {
    console.error('Refund error:', error);
    res.status(500).json({ success: false, message: 'Refund failed' });
  }
};

// Calculate refund amount based on cancellation policy
function calculateRefundAmount(booking) {
  const bookingDateTime = new Date(`${booking.bookingDate}T${booking.startTime}`);
  const now = new Date();
  const hoursUntilBooking = (bookingDateTime - now) / (1000 * 60 * 60);
  
  // Full refund if cancelled 24+ hours before
  if (hoursUntilBooking >= 24) {
    return booking.totalAmount;
  }
  
  // 50% refund if cancelled 12-24 hours before
  if (hoursUntilBooking >= 12) {
    return booking.totalAmount * 0.5;
  }
  
  // No refund if cancelled less than 12 hours before
  return 0;
}

module.exports = { initiateRefund };
```

### **3. Update Booking Routes**

```javascript
// backend/src/routes/bookingRoutes.js
// Add payment routes
const { createOrder, verifyPayment } = require('../controllers/paymentController');
const { initiateRefund } = require('../controllers/refundController');

// Payment routes
router.post('/payments/create-order', protect, createOrder);
router.post('/payments/verify-payment', protect, verifyPayment);
router.post('/payments/:bookingId/refund', protect, initiateRefund);
```

### **4. Update Cancel Booking to Auto-Refund**

```javascript
// In bookingController.js - cancelBooking function
// After line 872 (before updating status), add:

// Check if payment was made and initiate refund
if (booking.paymentStatus === 'paid' && booking.paymentId) {
  try {
    const refundController = require('./refundController');
    await refundController.initiateRefund({ 
      params: { bookingId: req.params.id },
      body: { reason: 'Booking cancelled by user' },
      user: req.user
    }, {
      json: (data) => {
        console.log('Refund initiated:', data);
      },
      status: (code) => ({ json: (data) => {} })
    });
  } catch (refundError) {
    console.error('Refund error during cancellation:', refundError);
    // Continue with cancellation even if refund fails
  }
}
```

---

## 📱 Frontend Requirements (Detailed)

### **1. Add Razorpay Package**

```yaml
# frontend/pubspec.yaml
dependencies:
  razorpay_flutter: ^1.3.6
```

### **2. Create Payment Service**

```dart
// frontend/lib/services/payment_service.dart
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/api_client.dart';
import '../config/constants.dart';

class PaymentService {
  final Razorpay _razorpay = Razorpay();
  final ApiClient _apiClient;
  
  PaymentService(this._apiClient) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }
  
  Future<void> initiatePayment({
    required String bookingId,
    required double amount,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Create order on backend
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.payments}/create-order',
        data: {
          'bookingId': bookingId,
          'amount': amount,
        },
      );
      
      if (!response.isSuccess || response.data == null) {
        onError('Failed to create payment order');
        return;
      }
      
      final orderData = response.data!['data'];
      
      // Open Razorpay checkout
      final options = {
        'key': orderData['keyId'],
        'amount': orderData['amount'],
        'name': 'XPerience Gaming',
        'description': 'Booking Payment',
        'prefill': {
          'contact': '', // Get from user profile
          'email': '', // Get from user profile
        },
        'external': {
          'wallets': ['paytm']
        }
      };
      
      _razorpay.open(options);
    } catch (e) {
      onError('Payment initialization failed: $e');
    }
  }
  
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Verify payment with backend
    _verifyPayment(response);
  }
  
  void _handlePaymentError(PaymentFailureResponse response) {
    // Handle payment failure
    print('Payment failed: ${response.message}');
  }
  
  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet
    print('External wallet: ${response.walletName}');
  }
  
  Future<void> _verifyPayment(PaymentSuccessResponse response) async {
    // Call backend to verify payment
    // Update booking status
  }
  
  void dispose() {
    _razorpay.clear();
  }
}
```

### **3. Update Booking Summary Popup**

Modify the "CONFIRM BOOKING" button to initiate payment flow.

### **4. Create Payment Screen**

A dedicated screen for payment processing with booking summary.

---

## 📝 Implementation Steps

### **Phase 1: Backend Setup (Your Side)**

1. ✅ Install Razorpay SDK: `npm install razorpay`
2. ✅ Add Razorpay keys to `.env`
3. ✅ Create `paymentController.js` with order creation and verification
4. ✅ Create `refundController.js` with refund logic
5. ✅ Update booking routes to include payment endpoints
6. ✅ Modify `cancelBooking` to auto-initiate refunds
7. ✅ Update booking model to include payment/refund fields
8. ✅ Test payment flow with Razorpay test keys

### **Phase 2: Frontend Setup (My Side)**

1. ✅ Add `razorpay_flutter` package
2. ✅ Create `PaymentService` class
3. ✅ Update booking summary popup
4. ✅ Create payment screen
5. ✅ Update booking model with payment/refund fields
6. ✅ Update cancel booking flow to show refund info
7. ✅ Test payment integration

### **Phase 3: Integration & Testing**

1. ✅ Test complete payment flow
2. ✅ Test refund flow
3. ✅ Test cancellation with refund
4. ✅ Handle edge cases (network errors, payment failures)
5. ✅ Add proper error handling and user feedback

---

## 🔐 Security Considerations

1. **Never store Razorpay Key Secret in frontend**
2. **Always verify payment signature on backend**
3. **Use HTTPS in production**
4. **Validate all payment data on backend**
5. **Implement rate limiting on payment endpoints**
6. **Log all payment transactions for audit**

---

## 📊 Database Schema Updates

### **Booking Collection - New Fields:**

```javascript
{
  // ... existing fields ...
  
  // Payment fields
  paymentOrderId: String,
  paymentId: String,
  paymentSignature: String,
  paymentStatus: 'unpaid' | 'pending' | 'paid' | 'failed' | 'refunded',
  paymentMethod: 'razorpay' | 'cash',
  paidAt: Date,
  
  // Refund fields
  refundId: String,
  refundAmount: Number,
  refundStatus: 'pending' | 'processed' | 'failed',
  refundedAt: Date,
  refundReason: String
}
```

---

## 🧪 Testing Checklist

### **Payment Flow:**
- [ ] Create booking order
- [ ] Open Razorpay checkout
- [ ] Complete payment successfully
- [ ] Verify payment on backend
- [ ] Update booking status to confirmed
- [ ] Handle payment failure
- [ ] Handle payment cancellation

### **Refund Flow:**
- [ ] Cancel paid booking
- [ ] Auto-initiate refund
- [ ] Verify refund status
- [ ] Update booking payment status
- [ ] Handle refund failures
- [ ] Test cancellation policy (full/partial/no refund)

---

## 📞 Support & Resources

- **Razorpay Documentation:** https://razorpay.com/docs/
- **Razorpay Flutter SDK:** https://pub.dev/packages/razorpay_flutter
- **Razorpay Dashboard:** https://dashboard.razorpay.com/

---

## ⚠️ Important Notes

1. **Test Mode:** Use Razorpay test keys during development
2. **Webhook Setup:** Consider setting up webhooks for payment status updates
3. **Refund Policy:** Define and document your cancellation/refund policy clearly
4. **User Communication:** Notify users about refund processing time (usually 5-7 business days)
5. **Error Handling:** Implement comprehensive error handling for all payment scenarios

---

**Last Updated:** [Current Date]
**Version:** 1.0.0

