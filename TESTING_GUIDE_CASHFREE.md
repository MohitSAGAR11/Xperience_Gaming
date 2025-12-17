# 🧪 Cashfree Payment Integration - Testing Guide

Complete step-by-step guide to test your PayU to Cashfree migration.

---

## 📋 Prerequisites Checklist

Before testing, ensure you have completed:

- [ ] **Cashfree Account Setup**
  - [ ] Account created at https://merchant.cashfree.com
  - [ ] KYC verification completed (if required)
  - [ ] Test credentials obtained (Client ID & Client Secret)

- [ ] **Environment Variables Set**
  ```env
  CASHFREE_CLIENT_ID=your_test_client_id
  CASHFREE_CLIENT_SECRET=your_test_client_secret
  CASHFREE_API_VERSION=2023-08-01
  CASHFREE_BASE_URL=https://sandbox.cashfree.com
  ```

- [ ] **Webhook Configured**
  - [ ] Webhook URL: `https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/webhook`
  - [ ] Events enabled: `success payment`, `failed payment`, `user dropped payment`
  - [ ] Webhook status: Active

- [ ] **Backend Deployed**
  - [ ] Firebase Functions deployed with updated code
  - [ ] Environment variables set in Firebase
  - [ ] Functions are running

- [ ] **Frontend Built**
  - [ ] Flutter app rebuilt with latest changes
  - [ ] APK/IPA installed on test device

---

## 🧪 Test Scenarios

### Test 1: Successful Payment Flow ✅

**Objective**: Verify complete payment success flow from initiation to booking confirmation.

#### Steps:

1. **Create a Test Booking**
   - Open your app
   - Navigate to booking/slot selection
   - Select a slot and create a booking
   - Note the `bookingId`

2. **Initiate Payment**
   - Click "Pay Now" or payment button
   - Enter payment amount (use ₹1 for testing)
   - Click "Proceed to Payment"

3. **Complete Payment on Cashfree**
   - You should be redirected to Cashfree payment page
   - Use test card details:
     ```
     Card Number: 4111 1111 1111 1111
     CVV: 123
     Expiry: 12/25 (any future date)
     Name: Test User
     ```
   - Click "Pay"

4. **Verify Success**
   - You should be redirected back to your app
   - Check booking status is updated to "paid" or "confirmed"
   - Verify success message is shown

#### What to Check:

- [ ] Payment page loads correctly
- [ ] Cashfree checkout page appears
- [ ] Payment completes successfully
- [ ] Redirect back to app works
- [ ] Booking status updated in database
- [ ] Success message displayed
- [ ] Webhook received (check Cashfree dashboard)
- [ ] Backend logs show success

#### Expected Backend Logs:

```
💳 [PAYMENT] === CREATE CASHFREE PAYMENT REQUEST ===
💳 [PAYMENT] Cashfree Configuration Validated
💳 [PAYMENT] Creating Cashfree order
💳 [PAYMENT] ✅ CASHFREE ORDER CREATED
💳 [PAYMENT] === CASHFREE PAYMENT CALLBACK ===
💳 [PAYMENT] ✅ PAYMENT VERIFIED & BOOKING CONFIRMED
💳 [PAYMENT] === CASHFREE WEBHOOK ===
💳 [PAYMENT] ✅ WEBHOOK PROCESSED
```

---

### Test 2: Payment Failure Flow ❌

**Objective**: Verify payment failure is handled correctly.

#### Steps:

1. **Initiate Payment**
   - Create a booking
   - Start payment flow

2. **Fail the Payment**
   - On Cashfree page, use test card:
     ```
     Card Number: 4000 0000 0000 0002
     CVV: 123
     Expiry: 12/25
     ```
   - OR click "Cancel" or close the payment page

3. **Verify Failure Handling**
   - Check booking status updates to "failed"
   - Verify error message is shown
   - Check webhook received (if applicable)

#### What to Check:

- [ ] Payment failure is detected
- [ ] Booking status updated to "failed"
- [ ] Error message displayed to user
- [ ] User can retry payment
- [ ] Webhook received (check dashboard)

#### Expected Backend Logs:

```
💳 [PAYMENT] === CASHFREE PAYMENT CALLBACK ===
💳 [PAYMENT] ❌ Payment failed
💳 [PAYMENT] Booking updated to failed status
```

---

### Test 3: Payment Cancellation 🚫

**Objective**: Verify user cancellation is handled.

#### Steps:

1. **Start Payment**
   - Create booking
   - Initiate payment

2. **Cancel Payment**
   - On Cashfree page, click "Cancel" or "Back"
   - OR close the payment page

3. **Verify Cancellation**
   - Check booking status
   - Verify cancellation is handled gracefully

#### What to Check:

- [ ] Cancellation detected
- [ ] Booking status updated appropriately
- [ ] User can retry payment
- [ ] No error crashes

---

### Test 4: Webhook Verification 📡

**Objective**: Verify webhooks are received and processed correctly.

#### Steps:

1. **Make a Test Payment**
   - Complete a successful payment (Test 1)

2. **Check Cashfree Dashboard**
   - Login to Cashfree Dashboard
   - Go to: **Developers** → **Webhooks**
   - Click on your webhook
   - Check "Recent Deliveries"
   - Verify webhook shows "Delivered" status

3. **Check Backend Logs**
   - View Firebase Functions logs
   - Verify webhook processing logs

#### What to Check:

- [ ] Webhook shows "Delivered" in Cashfree dashboard
- [ ] Backend logs show webhook received
- [ ] Booking status updated via webhook
- [ ] No webhook delivery failures

#### Expected Webhook Payload:

```json
{
  "data": {
    "order": {
      "order_id": "ORDER_xxx_xxx",
      "order_amount": 1.00,
      "order_currency": "INR"
    },
    "payment": {
      "payment_id": "CFxxx",
      "payment_status": "SUCCESS",
      "payment_amount": 1.00,
      "payment_message": "Transaction successful"
    }
  }
}
```

---

### Test 5: Different Payment Methods 💳

**Objective**: Test various payment methods available.

#### Test UPI Payment:

1. **Initiate Payment**
2. **Select UPI Option**
3. **Use Test UPI IDs:**
   - Success: `success@upi`
   - Failure: `failure@upi`
4. **Complete Payment**
5. **Verify Result**

#### Test Net Banking:

1. **Select Net Banking**
2. **Choose any test bank**
3. **Complete payment**
4. **Verify Result**

#### Test Wallet:

1. **Select Wallet option**
2. **Choose test wallet**
3. **Complete payment**
4. **Verify Result**

---

## 🔍 Verification Checklist

### Backend Verification

- [ ] **API Endpoints Working**
  ```bash
  # Test create payment endpoint
  POST /api/payments/create-payment
  # Should return payment session ID
  ```

- [ ] **Callback Endpoint Working**
  ```bash
  # Test callback endpoint
  GET /api/payments/callback?order_id=xxx&payment_status=SUCCESS
  # Should redirect to frontend
  ```

- [ ] **Webhook Endpoint Working**
  ```bash
  # Test webhook endpoint
  POST /api/payments/webhook
  # Should process webhook and return 200
  ```

- [ ] **Database Updates**
  - [ ] Booking `paymentTransactionId` is set
  - [ ] Booking `paymentSessionId` is stored
  - [ ] Booking `paymentStatus` updates correctly
  - [ ] Booking `status` changes to "confirmed" on success

### Frontend Verification

- [ ] **Payment Screen Loads**
  - [ ] WebView initializes
  - [ ] Loading indicator shows
  - [ ] Cashfree page loads

- [ ] **Payment Flow**
  - [ ] Payment initiation works
  - [ ] Redirect to Cashfree works
  - [ ] Payment completion works
  - [ ] Redirect back to app works

- [ ] **Error Handling**
  - [ ] Network errors handled
  - [ ] Payment failures handled
  - [ ] User cancellations handled
  - [ ] Error messages displayed

### Cashfree Dashboard Verification

- [ ] **Transactions Visible**
  - [ ] Go to: **Payments** → **Transactions**
  - [ ] Test transactions are visible
  - [ ] Transaction status is correct

- [ ] **Webhooks Delivered**
  - [ ] Go to: **Developers** → **Webhooks**
  - [ ] Webhook deliveries show "Delivered"
  - [ ] No failed deliveries

---

## 🐛 Troubleshooting Common Issues

### Issue 1: Payment Page Not Loading

**Symptoms:**
- WebView shows blank page
- Payment page doesn't redirect

**Solutions:**
1. Check `CASHFREE_BASE_URL` is set to `https://sandbox.cashfree.com`
2. Verify `paymentSessionId` is received from backend
3. Check network connectivity
4. Verify Cashfree checkout URL is correct

**Debug Steps:**
```bash
# Check backend logs
firebase functions:log

# Look for:
# ✅ CASHFREE ORDER CREATED
# paymentSessionId should be present
```

---

### Issue 2: Webhook Not Received

**Symptoms:**
- Payment completes but webhook not delivered
- Booking status not updated

**Solutions:**
1. Verify webhook URL is accessible:
   ```bash
   curl https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/webhook
   ```

2. Check webhook configuration in Cashfree dashboard
3. Verify webhook events are enabled
4. Check backend logs for webhook attempts

**Debug Steps:**
- Check Cashfree Dashboard → Webhooks → Recent Deliveries
- Check Firebase Functions logs
- Verify webhook endpoint is public (no auth required)

---

### Issue 3: Signature Verification Failed

**Symptoms:**
- Webhook returns 401 error
- "Invalid signature" in logs

**Solutions:**
1. Verify `CASHFREE_CLIENT_SECRET` is set correctly
2. Check signature format matches Cashfree's format
3. Verify webhook payload is not modified

**Debug Steps:**
```bash
# Check logs for signature details
# Look for: "Webhook signature mismatch"
# Compare received vs expected signature
```

---

### Issue 4: Booking Not Found

**Symptoms:**
- "Booking not found" error
- Payment completes but booking not updated

**Solutions:**
1. Verify `order_id` matches `paymentTransactionId` in database
2. Check booking was created before payment
3. Verify order_id format is correct

**Debug Steps:**
```bash
# Check database for booking
# Verify paymentTransactionId field exists
# Check order_id format: ORDER_bookingId_timestamp
```

---

### Issue 5: Callback Not Working

**Symptoms:**
- Payment completes but user not redirected
- Callback URL not called

**Solutions:**
1. Verify `return_url` in order creation
2. Check callback route is GET (not POST)
3. Verify frontend URL is correct

**Debug Steps:**
- Check backend logs for callback
- Verify redirect URL format
- Test callback URL manually

---

## 📊 Test Results Template

Use this template to track your test results:

```
Date: ___________
Tester: ___________

Test 1: Successful Payment
- [ ] Pass / [ ] Fail
- Notes: _________________________________

Test 2: Payment Failure
- [ ] Pass / [ ] Fail
- Notes: _________________________________

Test 3: Payment Cancellation
- [ ] Pass / [ ] Fail
- Notes: _________________________________

Test 4: Webhook Verification
- [ ] Pass / [ ] Fail
- Notes: _________________________________

Test 5: Payment Methods
- [ ] Pass / [ ] Fail
- Notes: _________________________________

Overall Status: [ ] Ready for Production / [ ] Needs Fixes

Issues Found:
1. _________________________________
2. _________________________________
3. _________________________________
```

---

## 🚀 Production Readiness Checklist

Before going live, ensure:

- [ ] All test scenarios pass
- [ ] Webhooks working reliably
- [ ] Error handling tested
- [ ] Environment variables set for production:
  ```env
  CASHFREE_BASE_URL=https://api.cashfree.com
  ```
- [ ] Production credentials obtained
- [ ] Production webhook configured
- [ ] Monitoring and alerts set up
- [ ] Rollback plan prepared

---

## 📞 Support Resources

- **Cashfree Documentation**: https://docs.cashfree.com
- **Cashfree Support**: support@cashfree.com
- **Cashfree Dashboard**: https://merchant.cashfree.com
- **Test Cards**: https://docs.cashfree.com/payments/test-cards

---

## ✅ Quick Test Commands

### Test Backend Endpoint:
```bash
curl -X POST https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/create-payment \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "bookingId": "test123",
    "amount": 1,
    "firstName": "Test",
    "email": "test@example.com"
  }'
```

### Check Webhook Endpoint:
```bash
curl https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/webhook
```

### View Backend Logs:
```bash
firebase functions:log --only payments
```

---

**Happy Testing! 🎉**

If you encounter any issues, refer to the troubleshooting section or check the backend logs for detailed error messages.

