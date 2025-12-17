# Migration Guide: PayU to Cashfree Payment Gateway

This guide outlines all the changes required to migrate from PayU to Cashfree payment gateway in your XPerience Gaming application.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Backend Changes (Node.js)](#backend-changes-nodejs)
4. [Frontend Changes (Flutter)](#frontend-changes-flutter)
5. [Environment Variables](#environment-variables)
6. [API Endpoint Changes](#api-endpoint-changes)
7. [Testing Checklist](#testing-checklist)
8. [Deployment Steps](#deployment-steps)

---

## Overview

### Key Differences: PayU vs Cashfree

| Feature | PayU | Cashfree |
|---------|------|----------|
| **Authentication** | Merchant Key + Salt | Client ID + Client Secret |
| **Hash Generation** | SHA512 hash string | Signature (HMAC-SHA256) |
| **Order Creation** | HTML form POST | REST API (Create Order) |
| **Payment Flow** | Form submission to PayU URL | Payment Session ID + SDK |
| **Callback URLs** | surl/furl/curl | return_url + notify_url |
| **Transaction ID** | txnid | order_id |
| **Payment ID** | mihpayid | payment_id |
| **Webhook** | POST callback | Webhook with signature verification |

---

## Prerequisites

### 1. Cashfree Account Setup

- [ ] Create Cashfree merchant account
- [ ] Complete KYC verification
- [ ] Obtain API credentials:
  - **Client ID** (App ID)
  - **Client Secret** (Secret Key)
- [ ] Get API endpoint URLs:
  - **Sandbox**: `https://sandbox.cashfree.com`
  - **Production**: `https://api.cashfree.com`
- [ ] Configure webhook URL in Cashfree dashboard
- [ ] Whitelist your app package name (for mobile apps)

### 2. Required Information

- Cashfree Client ID
- Cashfree Client Secret
- Cashfree API Version (use `2023-08-01`)
- Webhook Secret Key (for webhook signature verification)

---

## Backend Changes (Node.js)

### 1. Update Environment Variables

**File**: `backend/functions/.env` or your environment configuration

**Remove PayU variables:**
```env
# Remove these
PAYU_MERCHANT_KEY=xxx
PAYU_MERCHANT_SALT=xxx
PAYU_BASE_URL=https://secure.payu.in
```

**Add Cashfree variables:**
```env
# Cashfree Configuration
CASHFREE_CLIENT_ID=your_client_id
CASHFREE_CLIENT_SECRET=your_client_secret
CASHFREE_API_VERSION=2023-08-01
CASHFREE_BASE_URL=https://api.cashfree.com  # Use https://sandbox.cashfree.com for testing
CASHFREE_WEBHOOK_SECRET=your_webhook_secret
```

### 2. Install Cashfree SDK (Optional but Recommended)

```bash
cd backend/functions
npm install cashfree-sdk
```

**OR** use direct HTTP requests with `axios` or `fetch` (already available).

### 3. Update Payment Controller

**File**: `backend/functions/src/controllers/paymentController.js`

#### 3.1 Update Configuration Section

```javascript
// Replace PayU config with Cashfree config
const CASHFREE_CLIENT_ID = process.env.CASHFREE_CLIENT_ID;
const CASHFREE_CLIENT_SECRET = process.env.CASHFREE_CLIENT_SECRET;
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || '2023-08-01';
const CASHFREE_BASE_URL = process.env.CASHFREE_BASE_URL || 'https://api.cashfree.com';
const CASHFREE_WEBHOOK_SECRET = process.env.CASHFREE_WEBHOOK_SECRET;
```

#### 3.2 Replace Hash Generation Functions

**Remove PayU hash functions** and **add Cashfree signature generation**:

```javascript
// Cashfree Signature Generation (for webhook verification)
function generateCashfreeSignature(payload, secret) {
  const crypto = require('crypto');
  const signature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
  return signature;
}

// Cashfree Authorization Header
function getCashfreeAuthHeaders() {
  return {
    'x-client-id': CASHFREE_CLIENT_ID,
    'x-client-secret': CASHFREE_CLIENT_SECRET,
    'x-api-version': CASHFREE_API_VERSION,
    'Content-Type': 'application/json',
  };
}
```

#### 3.3 Replace `createPayment` Function

**Complete replacement needed** - Cashfree uses REST API instead of HTML form:

```javascript
/**
 * @desc    Create Cashfree Payment Order
 * @route   POST /api/payments/create-payment
 */
const createPayment = async (req, res) => {
  const requestId = `REQ-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CREATE CASHFREE PAYMENT REQUEST ===', { requestId });
    
    // Validate Cashfree Configuration
    if (!CASHFREE_CLIENT_ID || !CASHFREE_CLIENT_SECRET) {
      logPaymentError('Server config error - Missing Cashfree credentials', { requestId });
      return res.status(500).json({ 
        success: false, 
        message: 'Server config error - Missing Cashfree credentials' 
      });
    }

    const { bookingId, amount, firstName, email, phone, productInfo } = req.body;
    
    // Validate Inputs
    if (!bookingId || !amount || !email) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields' 
      });
    }

    // Verify Booking Exists
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      return res.status(404).json({ 
        success: false, 
        message: 'Booking not found' 
      });
    }

    // Generate Order ID (Cashfree format: alphanumeric, max 50 chars)
    const orderId = `ORDER_${bookingId}_${Date.now()}`;
    const formattedAmount = parseFloat(amount).toFixed(2);
    
    // Prepare callback URLs
    const returnUrl = `${BACKEND_URL}/payments/callback`;
    const notifyUrl = `${BACKEND_URL}/payments/webhook`;

    // Create Cashfree Order Payload
    const orderPayload = {
      order_id: orderId,
      order_amount: parseFloat(formattedAmount),
      order_currency: 'INR',
      order_note: productInfo || `Booking ${bookingId}`,
      customer_details: {
        customer_id: bookingId,
        customer_name: firstName || 'Guest',
        customer_email: email,
        customer_phone: phone || '9999999999',
      },
      order_meta: {
        return_url: returnUrl,
        notify_url: notifyUrl,
        payment_methods: 'cc,dc,upi,netbanking,wallet,paylater', // Enable all payment methods
      },
    };

    logPayment('Creating Cashfree order', { orderId, bookingId, amount: formattedAmount });

    // Call Cashfree Create Order API
    const axios = require('axios');
    const cashfreeResponse = await axios.post(
      `${CASHFREE_BASE_URL}/pg/orders`,
      orderPayload,
      {
        headers: getCashfreeAuthHeaders(),
      }
    );

    const { payment_session_id, order_token } = cashfreeResponse.data;

    if (!payment_session_id) {
      logPaymentError('Cashfree order creation failed', { 
        requestId, 
        response: cashfreeResponse.data 
      });
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to create payment order' 
      });
    }

    // Update Booking in DB
    await db.collection('bookings').doc(bookingId).update({
      paymentTransactionId: orderId,
      paymentSessionId: payment_session_id,
      paymentStatus: 'pending',
      updatedAt: new Date(),
    });

    logPayment('✅ CASHFREE ORDER CREATED', {
      requestId,
      orderId,
      paymentSessionId: payment_session_id,
      bookingId,
    });

    // Return payment session data to frontend
    res.json({
      success: true,
      message: 'Payment order created successfully',
      data: {
        orderId: orderId,
        paymentSessionId: payment_session_id,
        orderAmount: formattedAmount,
        orderCurrency: 'INR',
        customerName: firstName,
        customerEmail: email,
        customerPhone: phone || '9999999999',
        returnUrl: returnUrl,
      },
    });

  } catch (error) {
    logPaymentError('❌ CREATE PAYMENT FAILED', {
      requestId,
      error: error.message,
      stack: error.stack,
      bookingId: req.body?.bookingId,
    });
    res.status(500).json({ 
      success: false, 
      message: 'Failed to create payment: ' + error.message 
    });
  }
};
```

#### 3.4 Replace Callback Handlers

**Replace `verifyPayment` (success callback)**:

```javascript
/**
 * @desc    Handle Cashfree Payment Callback (Return URL)
 * @route   GET /api/payments/callback
 */
const verifyPayment = async (req, res) => {
  const requestId = `CALLBACK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CASHFREE PAYMENT CALLBACK ===', { requestId });
    
    const { order_id, order_token, payment_id, payment_status } = req.query;
    
    logPayment('Callback parameters', {
      order_id,
      payment_id,
      payment_status,
    });

    if (!order_id) {
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=invalid_callback`);
    }

    // Find booking by order_id (stored as paymentTransactionId)
    const bookingsQuery = await db.collection('bookings')
      .where('paymentTransactionId', '==', order_id)
      .limit(1)
      .get();
    
    if (bookingsQuery.empty) {
      logPaymentError('Booking not found', { order_id, requestId });
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=booking_not_found`);
    }

    const bookingId = bookingsQuery.docs[0].id;
    const bookingData = bookingsQuery.docs[0].data();

    // Verify payment status with Cashfree API
    const axios = require('axios');
    const paymentResponse = await axios.get(
      `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`,
      {
        headers: getCashfreeAuthHeaders(),
      }
    );

    const payments = paymentResponse.data;
    const latestPayment = payments && payments.length > 0 ? payments[0] : null;

    if (!latestPayment || latestPayment.payment_status !== 'SUCCESS') {
      // Payment failed or pending
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        paymentError: latestPayment?.payment_message || 'Payment failed',
        updatedAt: new Date(),
      });
      
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&bookingId=${bookingId}`);
    }

    // Payment successful - verify and update booking
    await db.collection('bookings').doc(bookingId).update({
      paymentId: latestPayment.payment_id,
      paymentStatus: 'paid',
      status: 'confirmed',
      paidAt: new Date(),
      updatedAt: new Date(),
    });

    logPayment('✅ PAYMENT VERIFIED & BOOKING CONFIRMED', {
      requestId,
      bookingId,
      orderId: order_id,
      paymentId: latestPayment.payment_id,
    });

    return res.redirect(`${FRONTEND_URL}/payment-result?status=success&bookingId=${bookingId}`);

  } catch (error) {
    logPaymentError('❌ PAYMENT CALLBACK ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
    });
    res.redirect(`${FRONTEND_URL}/payment-result?status=failure`);
  }
};
```

**Replace `handlePaymentFailure`** - Cashfree doesn't have separate failure callback, handle in callback:

```javascript
// Remove handlePaymentFailure or keep for backward compatibility
// Cashfree handles failures in the same callback URL
```

**Replace `handlePaymentCancel`** - Similar to failure:

```javascript
// Remove handlePaymentCancel or keep for backward compatibility
```

#### 3.5 Add Webhook Handler

**New function required** - Cashfree uses webhooks for payment notifications:

```javascript
/**
 * @desc    Handle Cashfree Webhook (Payment Notifications)
 * @route   POST /api/payments/webhook
 */
const handleWebhook = async (req, res) => {
  const requestId = `WEBHOOK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CASHFREE WEBHOOK ===', { requestId });
    
    const signature = req.headers['x-cashfree-signature'];
    const payload = req.body;

    // Verify webhook signature
    if (CASHFREE_WEBHOOK_SECRET) {
      const expectedSignature = generateCashfreeSignature(payload, CASHFREE_WEBHOOK_SECRET);
      if (signature !== expectedSignature) {
        logPaymentError('Webhook signature mismatch', { requestId });
        return res.status(401).json({ success: false, message: 'Invalid signature' });
      }
    }

    const { data } = payload;
    const { order, payment } = data || {};

    if (!order || !payment) {
      return res.status(400).json({ success: false, message: 'Invalid webhook data' });
    }

    const orderId = order.order_id;
    const paymentStatus = payment.payment_status;
    const paymentId = payment.payment_id;

    logPayment('Webhook data', {
      orderId,
      paymentId,
      paymentStatus,
    });

    // Find booking
    const bookingsQuery = await db.collection('bookings')
      .where('paymentTransactionId', '==', orderId)
      .limit(1)
      .get();

    if (bookingsQuery.empty) {
      logPaymentError('Booking not found for webhook', { orderId, requestId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    const bookingId = bookingsQuery.docs[0].id;

    // Update booking based on payment status
    if (paymentStatus === 'SUCCESS') {
      await db.collection('bookings').doc(bookingId).update({
        paymentId: paymentId,
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      });
    } else if (paymentStatus === 'FAILED' || paymentStatus === 'USER_DROPPED') {
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        paymentError: payment.payment_message || 'Payment failed',
        updatedAt: new Date(),
      });
    }

    logPayment('✅ WEBHOOK PROCESSED', {
      requestId,
      bookingId,
      orderId,
      paymentStatus,
    });

    res.json({ success: true });

  } catch (error) {
    logPaymentError('❌ WEBHOOK ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ success: false, message: 'Webhook processing failed' });
  }
};
```

#### 3.6 Update Module Exports

```javascript
module.exports = {
  createPayment,
  verifyPayment,
  handleWebhook, // New
  // Remove: handlePaymentFailure, handlePaymentCancel (or keep for compatibility)
};
```

#### 3.7 Update Routes

**File**: `backend/functions/src/routes/paymentRoutes.js` (or wherever routes are defined)

```javascript
// Update routes
router.post('/create-payment', paymentController.createPayment);
router.get('/callback', paymentController.verifyPayment); // Changed from POST to GET
router.post('/webhook', paymentController.handleWebhook); // New webhook route

// Keep these for backward compatibility or remove:
// router.post('/success', paymentController.verifyPayment);
// router.post('/failure', paymentController.handlePaymentFailure);
// router.post('/cancel', paymentController.handlePaymentCancel);
```

---

## Frontend Changes (Flutter)

### 1. Update Dependencies

**File**: `frontend/pubspec.yaml`

**Remove PayU SDK** (if using SDK approach):
```yaml
# Remove this if present:
# payu_checkoutpro_flutter: ^x.x.x
```

**Add Cashfree SDK** (if using SDK) OR use WebView approach:
```yaml
dependencies:
  # Keep webview_flutter for Cashfree integration
  webview_flutter: ^4.5.0
  
  # Optional: Add Cashfree Flutter SDK if available
  # cashfree_pg_sdk: ^x.x.x
```

Run:
```bash
cd frontend
flutter pub get
```

### 2. Update Payment Service

**File**: `frontend/lib/services/payment_service.dart`

#### 2.1 Update PaymentData Model

```dart
/// Payment Data (Updated for Cashfree)
class PaymentData {
  final String orderId;           // Changed from txnid
  final String paymentSessionId; // New - Cashfree payment session
  final String orderAmount;
  final String orderCurrency;
  final String customerName;      // Changed from firstname
  final String customerEmail;
  final String customerPhone;
  final String returnUrl;         // Changed from surl/furl/curl

  PaymentData({
    required this.orderId,
    required this.paymentSessionId,
    required this.orderAmount,
    required this.orderCurrency,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.returnUrl,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      orderId: json['orderId'] ?? '',
      paymentSessionId: json['paymentSessionId'] ?? '',
      orderAmount: json['orderAmount'] ?? '0',
      orderCurrency: json['orderCurrency'] ?? 'INR',
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      returnUrl: json['returnUrl'] ?? '',
    );
  }
}
```

#### 2.2 Update PaymentResponse Model

Keep the same structure, but update comments and field names as needed.

#### 2.3 Update initiatePayment Method

The method signature stays the same, but the backend response structure changes:

```dart
// The method implementation stays mostly the same
// Just update the response parsing to match Cashfree format
```

### 3. Create/Update Cashfree Service

**File**: `frontend/lib/services/cashfree/cashfree_service.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/logger.dart';

/// Cashfree Service - Handles Cashfree payment integration via WebView
class CashfreeService {
  static final CashfreeService _instance = CashfreeService._internal();
  factory CashfreeService() => _instance;
  CashfreeService._internal();

  /// Open Cashfree payment page in WebView
  /// 
  /// [paymentSessionId] - Payment session ID from Cashfree order creation
  /// [returnUrl] - URL to redirect after payment
  Future<CashfreePaymentResult> openPayment({
    required BuildContext context,
    required String paymentSessionId,
    required String returnUrl,
  }) async {
    try {
      AppLogger.d('💳 [CASHFREE] Opening payment page');
      AppLogger.d('💳 [CASHFREE] Payment Session ID: $paymentSessionId');
      
      // Cashfree Checkout URL
      final checkoutUrl = 'https://payments.cashfree.com/checkout/payment_session_id/$paymentSessionId';
      
      // Navigate to payment screen with WebView
      // Implementation depends on your navigation setup
      // You can use Navigator.push with a WebView widget
      
      return CashfreePaymentResult(
        status: CashfreePaymentStatus.pending,
        message: 'Payment initiated',
      );
    } catch (e, stackTrace) {
      AppLogger.e('💳 [CASHFREE] Payment error', e, stackTrace);
      return CashfreePaymentResult(
        status: CashfreePaymentStatus.error,
        message: 'Payment failed: $e',
      );
    }
  }
}

/// Payment result model
enum CashfreePaymentStatus {
  success,
  failure,
  cancelled,
  error,
  pending,
}

class CashfreePaymentResult {
  final CashfreePaymentStatus status;
  final String? orderId;
  final String? paymentId;
  final String? message;
  final Map<String, dynamic>? response;

  CashfreePaymentResult({
    required this.status,
    this.orderId,
    this.paymentId,
    this.message,
    this.response,
  });

  bool get isSuccess => status == CashfreePaymentStatus.success;
  bool get isFailure => status == CashfreePaymentStatus.failure;
  bool get isCancelled => status == CashfreePaymentStatus.cancelled;
  bool get isError => status == CashfreePaymentStatus.error;
}
```

### 4. Update Payment Screen

**File**: `frontend/lib/screens/client/payment/payment_screen_webview.dart`

#### 4.1 Update URL Detection

Replace PayU URL checks with Cashfree:

```dart
// Replace:
// url.contains('secure.payu.in') || url.contains('test.payu.in')

// With:
// url.contains('payments.cashfree.com') || url.contains('cashfree.com')
```

#### 4.2 Update Callback URL Detection

```dart
void _checkPaymentCallback(String url) {
  AppLogger.d('💳 [PAYMENT_WEBVIEW] Checking callback: $url');
  
  // Cashfree callback detection
  if (url.contains('/payments/callback')) {
    // Extract query parameters
    final uri = Uri.parse(url);
    final status = uri.queryParameters['payment_status'];
    final orderId = uri.queryParameters['order_id'];
    
    if (status == 'SUCCESS' || url.contains('status=success')) {
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ Payment Success');
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Payment successful!');
        context.pop(true);
      }
    } else if (status == 'FAILED' || url.contains('status=failure')) {
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ❌ Payment Failed');
      if (mounted) {
        SnackbarUtils.showError(context, 'Payment failed');
        context.pop(false);
      }
    }
  }
}
```

#### 4.3 Update Payment Form HTML Generation

**File**: `frontend/lib/services/payment_service.dart` - Update `buildPaymentFormHtml()`:

```dart
/// Build Cashfree payment page HTML
String buildPaymentPageHtml() {
  // Cashfree uses a redirect URL approach, not form submission
  // You can either:
  // 1. Redirect directly to Cashfree checkout URL
  // 2. Use Cashfree JavaScript SDK
  
  final checkoutUrl = 'https://payments.cashfree.com/checkout/payment_session_id/$paymentSessionId';
  
  return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Processing Payment</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
          margin: 0;
          background: #f5f5f5;
        }
        .container {
          text-align: center;
          padding: 20px;
        }
        .spinner {
          border: 4px solid #f3f3f3;
          border-top: 4px solid #3498db;
          border-radius: 50%;
          width: 40px;
          height: 40px;
          animation: spin 1s linear infinite;
          margin: 0 auto 20px;
        }
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="spinner"></div>
        <p>Redirecting to Cashfree...</p>
      </div>
      <script>
        window.location.href = '$checkoutUrl';
      </script>
    </body>
    </html>
  ''';
}
```

### 5. Remove PayU Service (if using SDK approach)

**File**: `frontend/lib/services/payu/payu_service.dart`

- [ ] Delete this file or keep for reference
- [ ] Remove all imports of `PayUService`
- [ ] Update payment screens to use `CashfreeService` instead

### 6. Update Payment Screen SDK (if using SDK)

**File**: `frontend/lib/screens/client/payment/payment_screen_sdk.dart`

Replace PayU SDK calls with Cashfree SDK calls (if using SDK) or switch to WebView approach.

---

## Environment Variables

### Backend Environment Variables

**File**: `.env` or your deployment platform's environment config

```env
# Cashfree Configuration
CASHFREE_CLIENT_ID=your_client_id_here
CASHFREE_CLIENT_SECRET=your_client_secret_here
CASHFREE_API_VERSION=2023-08-01
CASHFREE_BASE_URL=https://api.cashfree.com
# For testing use: https://sandbox.cashfree.com
CASHFREE_WEBHOOK_SECRET=your_webhook_secret_here

# Keep existing variables
BACKEND_URL=https://your-backend-url.com/api
FRONTEND_URL=https://your-frontend-url.com
```

### Frontend Environment Variables (if needed)

**File**: `frontend/lib/config/constants.dart` or similar

```dart
class ApiConstants {
  // Update payment endpoints if needed
  static const String createPayment = '/payments/create-payment';
  static const String paymentCallback = '/payments/callback';
  
  // Cashfree checkout base URL (if hardcoding)
  // static const String cashfreeCheckoutUrl = 'https://payments.cashfree.com/checkout';
}
```

---

## API Endpoint Changes

### Backend Endpoints

| Old PayU Endpoint | New Cashfree Endpoint | Method Change |
|-------------------|----------------------|---------------|
| `POST /api/payments/create-payment` | `POST /api/payments/create-payment` | Same |
| `POST /api/payments/success` | `GET /api/payments/callback` | GET instead of POST |
| `POST /api/payments/failure` | `GET /api/payments/callback` | Merged into callback |
| `POST /api/payments/cancel` | `GET /api/payments/callback` | Merged into callback |
| N/A | `POST /api/payments/webhook` | **NEW** - Webhook endpoint |

### Frontend API Calls

No changes needed - the frontend still calls the same `/create-payment` endpoint, but receives different response structure.

---

## Testing Checklist

### 1. Sandbox Testing

- [ ] Create test order with small amount (₹1)
- [ ] Test successful payment flow
- [ ] Test failed payment flow
- [ ] Test payment cancellation
- [ ] Verify webhook is received
- [ ] Verify booking status updates correctly
- [ ] Test with different payment methods (UPI, Card, Net Banking, etc.)

### 2. Test Scenarios

- [ ] Payment success → Booking confirmed
- [ ] Payment failure → Booking status updated
- [ ] Payment cancellation → Booking status updated
- [ ] Network timeout → Error handling
- [ ] Invalid credentials → Error message displayed
- [ ] Webhook signature verification → Security check

### 3. Edge Cases

- [ ] Duplicate payment attempts
- [ ] Payment timeout
- [ ] Webhook received before callback
- [ ] Missing booking ID
- [ ] Invalid order ID

---

## Deployment Steps

### 1. Pre-Deployment

- [ ] Complete all code changes
- [ ] Test thoroughly in sandbox environment
- [ ] Update environment variables in production
- [ ] Configure webhook URL in Cashfree dashboard
- [ ] Whitelist production domain/package name

### 2. Backend Deployment

```bash
cd backend/functions
npm install  # Install any new dependencies
# Deploy to your platform (Firebase Functions, etc.)
```

- [ ] Deploy backend changes
- [ ] Verify environment variables are set
- [ ] Test API endpoints are accessible
- [ ] Verify webhook endpoint is reachable from Cashfree

### 3. Frontend Deployment

```bash
cd frontend
flutter clean
flutter pub get
flutter build apk  # or ios
```

- [ ] Build and deploy frontend
- [ ] Test payment flow in production
- [ ] Monitor logs for errors

### 4. Post-Deployment

- [ ] Monitor payment transactions
- [ ] Check webhook logs
- [ ] Verify booking status updates
- [ ] Monitor error rates
- [ ] Set up alerts for payment failures

---

## Rollback Plan

If issues occur, you can temporarily rollback:

1. **Backend**: Revert to previous PayU code
2. **Frontend**: Revert to previous PayU integration
3. **Environment**: Restore PayU credentials

**Note**: Ensure you have a backup of the PayU integration code before migration.

---

## Additional Resources

- [Cashfree API Documentation](https://docs.cashfree.com/)
- [Cashfree Payment Gateway Integration](https://docs.cashfree.com/payments)
- [Cashfree Webhooks](https://docs.cashfree.com/payments/webhooks)
- [Cashfree Migration Guide](https://docs.cashfree.com/payments/migration/overview)

---

## Support

- Cashfree Support: support@cashfree.com
- Cashfree Dashboard: https://merchant.cashfree.com
- API Status: https://status.cashfree.com

---

## Migration Checklist Summary

### Backend
- [ ] Update environment variables
- [ ] Replace hash generation with signature
- [ ] Update createPayment function
- [ ] Update callback handlers
- [ ] Add webhook handler
- [ ] Update routes
- [ ] Test all endpoints

### Frontend
- [ ] Update dependencies
- [ ] Update PaymentData model
- [ ] Create/update CashfreeService
- [ ] Update payment screens
- [ ] Update URL detection logic
- [ ] Remove PayU service (if using SDK)
- [ ] Test payment flow

### Configuration
- [ ] Set up Cashfree account
- [ ] Configure webhook URL
- [ ] Whitelist app package
- [ ] Update environment variables
- [ ] Test in sandbox

### Testing & Deployment
- [ ] Complete sandbox testing
- [ ] Deploy backend
- [ ] Deploy frontend
- [ ] Monitor production
- [ ] Verify transactions

---

**Last Updated**: [Current Date]
**Migration Status**: ⚠️ In Progress / ✅ Complete

