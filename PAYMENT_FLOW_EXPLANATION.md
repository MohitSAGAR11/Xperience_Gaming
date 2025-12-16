# 💳 PayU Payment Integration Flow - Complete Explanation

This document explains exactly how PayU payment gateway integrates with your XPerience Gaming app and how the entire payment flow works.

---

## 🔄 Complete Payment Flow (Step-by-Step)

### **Phase 1: User Initiates Payment**

#### Step 1: User Books a Slot
1. User selects date, time slot, and station
2. User clicks "BOOK NOW" button
3. Booking confirmation popup appears showing:
   - Booking details (cafe, station, date, time, amount)
   - **Refund warning** (if booking is within 1 hour)
   - "PROCEED TO PAYMENT" button

#### Step 2: User Confirms Booking
1. User clicks "PROCEED TO PAYMENT"
2. **Frontend** creates a booking via `POST /api/bookings`
3. **Backend** creates booking with:
   - Status: `'pending'` (not confirmed yet)
   - Payment Status: `'unpaid'`
   - Booking is saved in Firestore

#### Step 3: Navigate to Payment Screen
1. Frontend navigates to `PaymentScreen`
2. Payment screen shows loading state
3. Payment screen calls `PaymentService.initiatePayment()`

---

### **Phase 2: Payment Initialization**

#### Step 4: Frontend Requests Payment
```
Frontend → Backend: POST /api/payments/create-payment
```

**Request Body:**
```json
{
  "bookingId": "booking_123",
  "amount": 500.00,
  "firstName": "John Doe",
  "email": "john@example.com",
  "phone": "9876543210",
  "productInfo": "Booking booking_123"
}
```

#### Step 5: Backend Generates PayU Payment Parameters
**Backend (`paymentController.js`) does:**

1. **Validates booking:**
   - Checks if booking exists
   - Verifies user owns the booking
   - Ensures booking isn't already paid

2. **Generates unique transaction ID:**
   ```javascript
   transactionId = "TXN_booking_123_1703123456789"
   ```

3. **Creates PayU payment parameters:**
   ```javascript
   {
     key: "YOUR_MERCHANT_KEY",
     txnid: "TXN_booking_123_1703123456789",
     amount: "500.00",
     productinfo: "Booking booking_123",
     firstname: "John Doe",
     email: "john@example.com",
     phone: "9876543210",
     surl: "http://your-backend/api/payments/success",
     furl: "http://your-backend/api/payments/failure",
     curl: "http://your-backend/api/payments/cancel",
     hash: "generated_sha512_hash",
     service_provider: "payu_paisa"
   }
   ```

4. **Generates SHA512 Hash:**
   ```
   Hash String = "MERCHANT_KEY|txnid|amount|productinfo|firstname|email|||||||||||MERCHANT_SALT"
   Hash = SHA512(Hash String)
   ```
   - This hash ensures payment data integrity
   - PayU will verify this hash

5. **Updates booking:**
   - Sets `paymentTransactionId` = transaction ID
   - Sets `paymentStatus` = `'pending'`

6. **Returns payment data to frontend:**
   ```json
   {
     "success": true,
     "data": {
       "key": "MERCHANT_KEY",
       "txnid": "TXN_booking_123_...",
       "amount": "500.00",
       "hash": "abc123...",
       "paymentUrl": "https://test.payu.in/_payment",
       ...
     }
   }
   ```

---

### **Phase 3: PayU Payment Page**

#### Step 6: Frontend Loads PayU Payment Page
**Frontend (`PaymentScreen`) does:**

1. **Builds HTML form** with all payment parameters:
   ```html
   <form action="https://test.payu.in/_payment" method="post">
     <input type="hidden" name="key" value="MERCHANT_KEY">
     <input type="hidden" name="txnid" value="TXN_booking_123_...">
     <input type="hidden" name="amount" value="500.00">
     <input type="hidden" name="hash" value="abc123...">
     <!-- ... all other parameters ... -->
   </form>
   ```

2. **Loads HTML in WebView:**
   - WebView automatically submits form to PayU
   - User sees PayU's secure payment page
   - User can choose payment method:
     - Credit/Debit Card
     - UPI
     - Net Banking
     - Wallets (Paytm, PhonePe, etc.)

#### Step 7: User Completes Payment
1. User enters payment details on PayU page
2. User clicks "Pay Now"
3. PayU processes payment:
   - Validates card/bank details
   - Processes transaction
   - Generates payment ID (`mihpayid`)

---

### **Phase 4: Payment Response & Verification**

#### Step 8: PayU Redirects Back (Success Case)
**If payment succeeds:**

1. **PayU redirects to success URL:**
   ```
   POST http://your-backend/api/payments/success
   ```

2. **PayU sends response data:**
   ```javascript
   {
     txnid: "TXN_booking_123_...",
     mihpayid: "PAYU_PAYMENT_ID_12345",
     status: "success",
     hash: "payu_generated_hash",
     amount: "500.00",
     productinfo: "Booking booking_123",
     firstname: "John Doe",
     email: "john@example.com"
   }
   ```

3. **Backend (`verifyPayment`) verifies:**
   - **Extracts booking ID** from `productinfo` or `txnid`
   - **Verifies hash:**
     ```javascript
     Hash String = "MERCHANT_SALT|status|||||||||||email|firstname|productinfo|amount|txnid|MERCHANT_KEY"
     Generated Hash = SHA512(Hash String)
     
     if (Generated Hash === Received Hash) {
       // Payment is legitimate
     } else {
       // Payment is fake - reject it
     }
     ```
   - **Updates booking:**
     ```javascript
     {
       paymentId: "PAYU_PAYMENT_ID_12345",
       paymentHash: "verified_hash",
       paymentStatus: "paid",
       status: "confirmed",  // Booking is now confirmed!
       paidAt: new Date()
     }
     ```

4. **Backend redirects to frontend:**
   ```
   Redirect: http://your-frontend/booking/booking_123/success?paymentId=PAYU_PAYMENT_ID_12345
   ```

5. **Frontend shows success page:**
   - "Payment successful!"
   - "Booking confirmed!"
   - Booking details

---

#### Step 9: PayU Redirects Back (Failure Case)
**If payment fails:**

1. **PayU redirects to failure URL:**
   ```
   POST http://your-backend/api/payments/failure
   ```

2. **Backend updates booking:**
   ```javascript
   {
     paymentStatus: "failed"
   }
   ```

3. **Backend redirects to frontend:**
   ```
   Redirect: http://your-frontend/payment/failure?bookingId=booking_123&reason=failed
   ```

4. **Frontend shows error:**
   - "Payment failed"
   - "Please try again"
   - Option to retry payment

---

### **Phase 5: Refund Flow (When User Cancels)**

#### Step 10: User Cancels Booking
1. User clicks "Cancel Booking" in My Bookings
2. Frontend calls `POST /api/bookings/:id/cancel`

#### Step 11: Backend Checks Refund Eligibility
**Backend (`cancelBooking` → `refundController`) does:**

1. **Checks if payment was made:**
   ```javascript
   if (booking.paymentStatus === 'paid' && booking.paymentId) {
     // Refund is needed
   }
   ```

2. **Calculates refund amount:**
   ```javascript
   bookingDateTime = new Date("2024-01-15T14:00:00")
   now = new Date()
   hoursUntilBooking = (bookingDateTime - now) / (1000 * 60 * 60)
   
   if (hoursUntilBooking >= 1) {
     refundAmount = booking.totalAmount  // Full refund
   } else {
     refundAmount = 0  // No refund (within 1 hour)
   }
   ```

3. **If refund eligible:**
   - Generates refund hash
   - Calls PayU refund API
   - Updates booking with refund details

4. **If not eligible:**
   - Updates booking: `refundStatus = 'not_eligible'`
   - Returns message: "No refund eligible - cancelled within 1 hour"

---

## 🔐 Security Features

### **Hash Verification**
- **Payment Hash:** Ensures payment request is from your backend
- **Response Hash:** Ensures payment response is from PayU
- **Refund Hash:** Ensures refund request is legitimate

### **Transaction ID**
- Unique for each payment
- Format: `TXN_{bookingId}_{timestamp}`
- Prevents duplicate payments

### **Payment Status Tracking**
- `unpaid` → `pending` → `paid` / `failed`
- Booking status: `pending` → `confirmed` (only after payment)

---

## 📊 Database Flow

### **Booking Document States:**

**1. Initial Booking:**
```javascript
{
  status: "pending",
  paymentStatus: "unpaid",
  paymentTransactionId: null,
  paymentId: null
}
```

**2. Payment Initiated:**
```javascript
{
  status: "pending",
  paymentStatus: "pending",
  paymentTransactionId: "TXN_booking_123_...",
  paymentId: null
}
```

**3. Payment Successful:**
```javascript
{
  status: "confirmed",
  paymentStatus: "paid",
  paymentTransactionId: "TXN_booking_123_...",
  paymentId: "PAYU_PAYMENT_ID_12345",
  paidAt: Date
}
```

**4. Refund Processed:**
```javascript
{
  status: "cancelled",
  paymentStatus: "refunded",
  refundId: "REF_12345",
  refundAmount: 500.00,
  refundStatus: "processed",
  refundedAt: Date
}
```

---

## 🎯 Key Points

1. **Booking is created FIRST** (status: pending)
2. **Payment happens SECOND** (via PayU)
3. **Booking confirmed AFTER** payment verification
4. **Hash verification** ensures security
5. **Refund policy** enforced automatically
6. **User sees warning** if booking within 1 hour

---

## 🔄 Visual Flow Diagram

```
User → Select Slot → Confirm Booking
  ↓
Create Booking (status: pending)
  ↓
Navigate to Payment Screen
  ↓
Request Payment from Backend
  ↓
Backend Generates PayU Parameters + Hash
  ↓
Load PayU Payment Page (WebView)
  ↓
User Pays via PayU
  ↓
PayU Processes Payment
  ↓
PayU Redirects to Backend (success/failure)
  ↓
Backend Verifies Hash
  ↓
Backend Updates Booking (status: confirmed, paymentStatus: paid)
  ↓
Backend Redirects to Frontend Success Page
  ↓
User Sees "Booking Confirmed!"
```

---

## 🛡️ Error Handling

### **Payment Failures:**
- Network errors → Retry payment
- Payment declined → Show error, allow retry
- Hash mismatch → Reject payment, log security issue

### **Refund Failures:**
- PayU API error → Log error, notify admin
- Booking still cancelled, but refund may need manual processing

---

## 📝 Important Notes

1. **Never store PayU Merchant Salt in frontend** - Only backend has it
2. **Always verify hash on backend** - Never trust frontend data
3. **Use HTTPS in production** - Required by PayU
4. **Test with PayU test credentials** - Before going live
5. **Monitor payment callbacks** - Ensure all payments are processed

---

## 🧪 Testing Flow

1. **Test Mode:**
   - Use PayU test credentials
   - Use test cards: `5123456789012346` (any CVV, any future expiry)
   - Test success/failure scenarios

2. **Production Mode:**
   - Use live PayU credentials
   - Real payments processed
   - Real refunds processed

---

**This is the complete flow!** Every step is implemented in your codebase and ready to work once you add PayU credentials to your `.env` file.

