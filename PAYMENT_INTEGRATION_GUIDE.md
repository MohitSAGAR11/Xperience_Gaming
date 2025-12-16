# 💳 Payment Integration & Refund System Guide (PayU)

This document outlines everything needed to implement payment processing and refund functionality for the XPerience Gaming booking system using **PayU payment gateway**.

## 🚀 Quick Start Summary

### **What You Need to Do:**

#### **Backend (Your Side):**
1. ✅ Get PayU Merchant Key & Salt from PayU dashboard
2. ✅ Add credentials to `.env` file
3. ✅ Install `crypto` and `axios` packages
4. ✅ Create payment controller with hash generation
5. ✅ Create refund controller with PayU API integration
6. ✅ Set up payment routes with success/failure callbacks

#### **Frontend (My Side):**
1. ✅ Add `webview_flutter` package
2. ✅ Create payment service for PayU integration
3. ✅ Create payment screen with WebView
4. ✅ Handle payment callbacks (success/failure)

### **Key PayU Differences:**
- Uses **SHA512 hash** (not HMAC signature)
- Requires **hosted payment page** (WebView integration)
- Merchant generates **transaction ID** (txnid)
- Uses **POST API** for refunds (not SDK methods)

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

#### 1. **Install Required Packages**
```bash
cd backend
npm install crypto axios
```
Note: PayU doesn't require a specific SDK. We'll use HTTP requests and crypto for hash generation.

#### 2. **Add PayU Configuration to `.env`**
```env
# PayU Configuration
PAYU_MERCHANT_KEY=your_payu_merchant_key
PAYU_MERCHANT_SALT=your_payu_merchant_salt
PAYU_MODE=test  # or 'production' for live
PAYU_BASE_URL=https://test.payu.in  # or https://secure.payu.in for production
```

#### 3. **Create Payment Controller** (`backend/src/controllers/paymentController.js`)

**Required Endpoints:**

- **`POST /api/payments/create-payment`** - Generate PayU payment hash and parameters
  - Input: `{ bookingId, amount, firstName, email, phone, productInfo }`
  - Output: `{ transactionId, hash, merchantKey, amount, currency, productInfo, firstName, email, phone, surl, furl, curl, key }`
  
- **`POST /api/payments/verify-payment`** - Verify payment response hash
  - Input: `{ transactionId, paymentId, hash, bookingId, status }`
  - Output: `{ success, message, booking }`
  
- **`POST /api/payments/payment-failed`** - Handle failed payments
  - Input: `{ transactionId, bookingId, reason }`
  - Output: `{ success, message }`

#### 4. **Update Booking Model**
Add payment-related fields to booking document:
- `paymentTransactionId` (String) - PayU transaction ID (txnid)
- `paymentId` (String) - PayU payment ID
- `paymentHash` (String) - Payment verification hash
- `paymentStatus` (String) - 'unpaid', 'pending', 'paid', 'failed', 'refunded'
- `paymentMethod` (String) - 'payu', 'cash', etc.
- `paidAt` (Date) - When payment was completed

#### 5. **Update Booking Creation Flow**
Modify `createBooking` in `bookingController.js`:
- Change initial `paymentStatus` from `'unpaid'` to `'pending'`
- Don't set booking status to `'confirmed'` until payment is verified
- Set booking status to `'pending'` initially

---

### **From My Side (Frontend):**

#### 1. **Add Required Flutter Packages**
```yaml
# frontend/pubspec.yaml
dependencies:
  webview_flutter: ^4.4.2  # For PayU payment page
  url_launcher: ^6.2.2     # Alternative: Open PayU in external browser
```

#### 2. **Create Payment Service** (`frontend/lib/services/payment_service.dart`)
- Generate payment hash with backend
- Open PayU payment page (WebView or browser)
- Handle payment success/failure callbacks
- Verify payment with backend

#### 3. **Update Booking Summary Popup**
Modify `slot_selection_screen.dart`:
- Change "CONFIRM BOOKING" button to "PROCEED TO PAYMENT"
- After confirmation, call payment service instead of direct booking
- Show payment loading state

#### 4. **Create Payment Screen** (`frontend/lib/screens/client/payment/payment_screen.dart`)
- Display booking summary
- Show payment amount
- Load PayU payment page in WebView
- Handle payment success/failure redirects

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
  
  // Initiate PayU refund via API
  const refund = await initiatePayURefund({
    paymentId: booking.paymentId,
    amount: refundAmount,
    reason: 'Booking cancelled'
  });
  
  // Update booking
  booking.paymentStatus = 'refunded';
  booking.refundId = refund.refundId;
  booking.refundAmount = refundAmount;
  booking.refundedAt = new Date();
}
```

#### 4. **Cancellation Policy**
**Refund Rules:**
- **Full refund** if cancelled **before 1 hour** of booking slot start time
- **No refund** if cancelled **within 1 hour** of booking slot start time
- Users booking slots within 1 hour will see a warning that they won't get refunds

#### 5. **Add Refund Fields to Booking Model**
- `refundId` (String) - PayU refund ID
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
const crypto = require('crypto');
const axios = require('axios');
const { db } = require('../config/firebase');

const PAYU_MERCHANT_KEY = process.env.PAYU_MERCHANT_KEY;
const PAYU_MERCHANT_SALT = process.env.PAYU_MERCHANT_SALT;
const PAYU_BASE_URL = process.env.PAYU_BASE_URL || 'https://test.payu.in';

// Generate PayU payment hash
function generatePaymentHash(params) {
  const hashString = `${PAYU_MERCHANT_KEY}|${params.txnid}|${params.amount}|${params.productinfo}|${params.firstname}|${params.email}|||||||||||${PAYU_MERCHANT_SALT}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
}

// Generate PayU response hash for verification
function generateResponseHash(params) {
  const hashString = `${PAYU_MERCHANT_SALT}|${params.status}|||||||||||${params.email}|${params.firstname}|${params.productinfo}|${params.amount}|${params.txnid}|${PAYU_MERCHANT_KEY}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
}

// Create PayU payment
const createPayment = async (req, res) => {
  try {
    const { bookingId, amount, firstName, email, phone, productInfo } = req.body;
    
    // Verify booking exists and belongs to user
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists || bookingDoc.data().userId !== req.user.id) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    // Generate unique transaction ID
    const transactionId = `TXN_${bookingId}_${Date.now()}`;
    
    // Prepare payment parameters
    const paymentParams = {
      key: PAYU_MERCHANT_KEY,
      txnid: transactionId,
      amount: amount.toString(),
      productinfo: productInfo || `Booking ${bookingId}`,
      firstname: firstName || req.user.name || 'Guest',
      email: email || req.user.email,
      phone: phone || req.user.phone || '',
      surl: `${process.env.BACKEND_URL || 'http://localhost:3000'}/api/payments/success`,
      furl: `${process.env.BACKEND_URL || 'http://localhost:3000'}/api/payments/failure`,
      curl: `${process.env.BACKEND_URL || 'http://localhost:3000'}/api/payments/cancel`,
      hash: '',
      service_provider: 'payu_paisa'
    };
    
    // Generate hash
    paymentParams.hash = generatePaymentHash(paymentParams);
    
    // Update booking with transaction ID
    await db.collection('bookings').doc(bookingId).update({
      paymentTransactionId: transactionId,
      paymentStatus: 'pending',
      updatedAt: new Date()
    });
    
    res.json({
      success: true,
      data: {
        ...paymentParams,
        paymentUrl: `${PAYU_BASE_URL}/_payment`
      }
    });
  } catch (error) {
    console.error('Create payment error:', error);
    res.status(500).json({ success: false, message: 'Failed to create payment' });
  }
};

// Verify payment (called from PayU success URL)
const verifyPayment = async (req, res) => {
  try {
    const { txnid, mihpayid, status, hash, bookingId } = req.body;
    
    // Verify hash
    const generatedHash = generateResponseHash(req.body);
    
    if (generatedHash !== hash) {
      return res.status(400).json({ success: false, message: 'Invalid payment hash' });
    }
    
    // Get booking
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    // Update booking based on status
    if (status === 'success') {
      await db.collection('bookings').doc(bookingId).update({
        paymentId: mihpayid,
        paymentHash: hash,
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date()
      });
      
      // Fetch updated booking
      const updatedBookingDoc = await db.collection('bookings').doc(bookingId).get();
      const booking = { id: updatedBookingDoc.id, ...updatedBookingDoc.data() };
      
      // Redirect to success page (frontend URL)
      const frontendSuccessUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/booking/${bookingId}/success?paymentId=${mihpayid}`;
      return res.redirect(frontendSuccessUrl);
    } else {
      // Payment failed
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        updatedAt: new Date()
      });
      
      const frontendFailureUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/booking/${bookingId}/failure?reason=${status}`;
      return res.redirect(frontendFailureUrl);
    }
  } catch (error) {
    console.error('Verify payment error:', error);
    res.status(500).json({ success: false, message: 'Payment verification failed' });
  }
};

// Handle payment failure
const handlePaymentFailure = async (req, res) => {
  try {
    const { txnid, bookingId } = req.body;
    
    await db.collection('bookings').doc(bookingId).update({
      paymentStatus: 'failed',
      updatedAt: new Date()
    });
    
    const frontendFailureUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/booking/${bookingId}/failure`;
    return res.redirect(frontendFailureUrl);
  } catch (error) {
    console.error('Payment failure handler error:', error);
    res.status(500).json({ success: false, message: 'Failed to process payment failure' });
  }
};

module.exports = { createPayment, verifyPayment, handlePaymentFailure };
```

### **2. Refund Controller Implementation**

```javascript
// backend/src/controllers/refundController.js
const crypto = require('crypto');
const axios = require('axios');
const { db } = require('../config/firebase');

const PAYU_MERCHANT_KEY = process.env.PAYU_MERCHANT_KEY;
const PAYU_MERCHANT_SALT = process.env.PAYU_MERCHANT_SALT;
const PAYU_BASE_URL = process.env.PAYU_BASE_URL || 'https://test.payu.in';

// Generate PayU refund hash
function generateRefundHash(paymentId, amount) {
  const hashString = `${PAYU_MERCHANT_KEY}|${paymentId}|${amount}|${PAYU_MERCHANT_SALT}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
}

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
    
    // Generate refund hash
    const refundHash = generateRefundHash(booking.paymentId, refundAmount);
    
    // Initiate refund via PayU API
    const refundData = {
      key: PAYU_MERCHANT_KEY,
      command: 'cancel_refund_transaction',
      var1: booking.paymentId, // Payment ID
      var2: refundAmount.toString(), // Refund amount
      hash: refundHash
    };
    
    // Call PayU refund API
    // Note: PayU refund API endpoint may vary - check PayU documentation for latest endpoint
    const refundResponse = await axios.post(
      `${PAYU_BASE_URL}/merchant/postservice?form=2`,
      new URLSearchParams(refundData).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );
    
    // Parse PayU response
    const refundResult = refundResponse.data;
    
    if (refundResult.status === 'success' || refundResult.status === 1) {
      // Update booking
      await db.collection('bookings').doc(bookingId).update({
        refundId: refundResult.refundId || `REF_${Date.now()}`,
        refundAmount: refundAmount,
        refundStatus: 'processed',
        paymentStatus: 'refunded',
        refundReason: reason || 'Booking cancelled',
        refundedAt: new Date(),
        updatedAt: new Date()
      });
      
      res.json({
        success: true,
        message: 'Refund initiated successfully',
        data: {
          refundId: refundResult.refundId,
          refundAmount: refundAmount,
          refundStatus: 'processed'
        }
      });
    } else {
      // Refund failed
      await db.collection('bookings').doc(bookingId).update({
        refundStatus: 'failed',
        updatedAt: new Date()
      });
      
      res.status(400).json({
        success: false,
        message: refundResult.message || 'Refund failed',
        data: refundResult
      });
    }
  } catch (error) {
    console.error('Refund error:', error);
    res.status(500).json({ success: false, message: 'Refund failed', error: error.message });
  }
};

// Calculate refund amount based on cancellation policy
// Full refund if cancelled before 1 hour of booking slot, otherwise no refund
function calculateRefundAmount(booking) {
  const bookingDateTime = new Date(`${booking.bookingDate}T${booking.startTime}`);
  const now = new Date();
  const hoursUntilBooking = (bookingDateTime - now) / (1000 * 60 * 60);
  
  // Full refund if cancelled 1+ hours before booking start time
  if (hoursUntilBooking >= 1) {
    return booking.totalAmount;
  }
  
  // No refund if cancelled less than 1 hour before booking
  return 0;
}

module.exports = { initiateRefund };
```

### **3. Update Booking Routes**

```javascript
// backend/src/routes/paymentRoutes.js (create new file)
const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { createPayment, verifyPayment, handlePaymentFailure } = require('../controllers/paymentController');
const { initiateRefund } = require('../controllers/refundController');

// Payment routes
router.post('/create-payment', protect, createPayment);
router.post('/success', verifyPayment); // PayU success callback (no auth needed)
router.post('/failure', handlePaymentFailure); // PayU failure callback
router.post('/cancel', handlePaymentFailure); // PayU cancel callback
router.post('/:bookingId/refund', protect, initiateRefund);

module.exports = router;

// In server.js or main routes file:
// const paymentRoutes = require('./routes/paymentRoutes');
// app.use('/api/payments', paymentRoutes);
```

### **4. Update Cancel Booking to Auto-Refund**

```javascript
// In bookingController.js - cancelBooking function
// After checking booking status, add:

// Check if payment was made and initiate refund
if (booking.paymentStatus === 'paid' && booking.paymentId) {
  try {
    const { initiateRefund } = require('./refundController');
    const refundReq = {
      params: { bookingId: req.params.id },
      body: { reason: 'Booking cancelled by user' },
      user: req.user
    };
    const refundRes = {
      json: (data) => {
        console.log('Refund initiated:', data);
      },
      status: (code) => ({ json: (data) => {} })
    };
    await initiateRefund(refundReq, refundRes);
  } catch (refundError) {
    console.error('Refund error during cancellation:', refundError);
    // Continue with cancellation even if refund fails
    // You may want to notify admin about refund failure
  }
}
```

---

## 📱 Frontend Requirements (Detailed)

### **1. Add Required Packages**

```yaml
# frontend/pubspec.yaml
dependencies:
  webview_flutter: ^4.4.2
  url_launcher: ^6.2.2
  flutter_inappwebview: ^6.0.0  # Alternative: More features than webview_flutter
```

### **2. Create Payment Service**

```dart
// frontend/lib/services/payment_service.dart
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../config/constants.dart';

class PaymentService {
  final ApiClient _apiClient;
  
  PaymentService(this._apiClient);
  
  /// Initiate PayU payment
  /// Returns payment URL and parameters to load in WebView
  Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    required double amount,
    required String firstName,
    required String email,
    String? phone,
    String? productInfo,
  }) async {
    try {
      // Create payment on backend
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.payments}/create-payment',
        data: {
          'bookingId': bookingId,
          'amount': amount,
          'firstName': firstName,
          'email': email,
          'phone': phone,
          'productInfo': productInfo ?? 'Booking Payment',
        },
      );
      
      if (!response.isSuccess || response.data == null) {
        throw Exception('Failed to create payment: ${response.message}');
      }
      
      return response.data!['data'];
    } catch (e) {
      throw Exception('Payment initialization failed: $e');
    }
  }
  
  /// Build PayU payment form HTML
  String buildPaymentForm(Map<String, dynamic> paymentParams) {
    final formFields = paymentParams.entries.map((entry) {
      return '<input type="hidden" name="${entry.key}" value="${entry.value}">';
    }).join('\n');
    
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PayU Payment</title>
      </head>
      <body>
        <form id="payuForm" action="${paymentParams['paymentUrl']}" method="post">
          $formFields
        </form>
        <script>
          document.getElementById('payuForm').submit();
        </script>
      </body>
      </html>
    ''';
  }
  
  /// Handle payment success callback
  Future<bool> verifyPayment({
    required String transactionId,
    required String paymentId,
    required String hash,
    required String bookingId,
    required String status,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.payments}/verify-payment',
        data: {
          'txnid': transactionId,
          'mihpayid': paymentId,
          'hash': hash,
          'bookingId': bookingId,
          'status': status,
        },
      );
      
      return response.isSuccess;
    } catch (e) {
      return false;
    }
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

1. ✅ Install required packages: `npm install crypto axios`
2. ✅ Add PayU credentials to `.env` (Merchant Key & Salt)
3. ✅ Create `paymentController.js` with payment hash generation and verification
4. ✅ Create `refundController.js` with PayU refund API integration
5. ✅ Create `paymentRoutes.js` with payment endpoints
6. ✅ Modify `cancelBooking` to auto-initiate refunds
7. ✅ Update booking model to include payment/refund fields
8. ✅ Test payment flow with PayU test credentials

### **Phase 2: Frontend Setup (My Side)**

1. ✅ Add `webview_flutter` or `flutter_inappwebview` package
2. ✅ Create `PaymentService` class for PayU integration
3. ✅ Update booking summary popup
4. ✅ Create payment screen with WebView
5. ✅ Update booking model with payment/refund fields
6. ✅ Update cancel booking flow to show refund info
7. ✅ Test payment integration with PayU test environment

### **Phase 3: Integration & Testing**

1. ✅ Test complete payment flow
2. ✅ Test refund flow
3. ✅ Test cancellation with refund
4. ✅ Handle edge cases (network errors, payment failures)
5. ✅ Add proper error handling and user feedback

---

## 🔐 Security Considerations

1. **Never store PayU Merchant Salt in frontend** - Keep it only on backend
2. **Always verify payment hash on backend** - Use SHA512 hash verification
3. **Use HTTPS in production** - PayU requires HTTPS for production
4. **Validate all payment data on backend** - Never trust frontend data
5. **Implement rate limiting on payment endpoints** - Prevent abuse
6. **Log all payment transactions for audit** - Keep transaction logs
7. **Use PayU test mode during development** - Test with sandbox credentials
8. **Handle webhook callbacks securely** - Verify webhook signatures if using webhooks

---

## 📊 Database Schema Updates

### **Booking Collection - New Fields:**

```javascript
{
  // ... existing fields ...
  
  // Payment fields
  paymentTransactionId: String,  // PayU txnid
  paymentId: String,              // PayU mihpayid
  paymentHash: String,            // PayU hash for verification
  paymentStatus: 'unpaid' | 'pending' | 'paid' | 'failed' | 'refunded',
  paymentMethod: 'payu' | 'cash',
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
- [ ] Create payment hash on backend
- [ ] Load PayU payment page in WebView
- [ ] Complete payment successfully
- [ ] Verify payment hash on backend
- [ ] Update booking status to confirmed
- [ ] Handle payment failure
- [ ] Handle payment cancellation
- [ ] Test success/failure/cancel callbacks

### **Refund Flow:**
- [ ] Cancel paid booking
- [ ] Auto-initiate refund
- [ ] Verify refund status
- [ ] Update booking payment status
- [ ] Handle refund failures
- [ ] Test cancellation policy (full/partial/no refund)

---

## 📞 Support & Resources

- **PayU Documentation:** https://devguide.payu.in/
- **PayU Integration Guide:** https://devguide.payu.in/docs/payment-gateway/
- **PayU API Reference:** https://devguide.payu.in/api-reference/
- **PayU Merchant Dashboard:** https://dashboard.payu.in/
- **PayU Test Credentials:** Available in PayU dashboard under Test Mode
- **PayU Hash Generation:** https://devguide.payu.in/docs/payment-gateway/hash-generation/

---

## ⚠️ Important Notes

1. **Test Mode:** Use PayU test credentials during development (available in dashboard)
2. **Hash Generation:** Always generate hash on backend, never on frontend
3. **Success/Failure URLs:** Configure proper callback URLs (surl, furl, curl) in payment params
4. **Webhook Setup:** Consider setting up PayU webhooks for payment status updates (optional)
5. **Refund Policy:** Define and document your cancellation/refund policy clearly
6. **User Communication:** Notify users about refund processing time (usually 5-7 business days)
7. **Error Handling:** Implement comprehensive error handling for all payment scenarios
8. **HTTPS Required:** PayU production requires HTTPS - ensure SSL certificate is configured
9. **Transaction ID:** Generate unique transaction IDs (txnid) for each payment
10. **Payment Methods:** PayU supports Credit/Debit Cards, UPI, Net Banking, Wallets - configure in dashboard

---

## 🔄 PayU vs Razorpay Key Differences

### **Hash Generation:**
- **PayU:** Uses SHA512 hash with specific string format
- **Razorpay:** Uses HMAC SHA256 signature

### **Payment Flow:**
- **PayU:** Redirects to PayU hosted page (WebView integration)
- **Razorpay:** Can use SDK for native checkout

### **Refund API:**
- **PayU:** Uses POST API with hash verification
- **Razorpay:** Uses SDK methods for refunds

### **Transaction ID:**
- **PayU:** Merchant generates unique txnid
- **Razorpay:** Razorpay generates order ID

### **Verification:**
- **PayU:** Verifies response hash from callback
- **Razorpay:** Verifies signature from payment response

---

**Last Updated:** December 2024
**Version:** 2.0.0 (PayU Integration)
**Payment Gateway:** PayU India

