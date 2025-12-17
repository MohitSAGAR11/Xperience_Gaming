# PayU to Cashfree Migration - Quick Checklist

## 🔴 Critical Changes Required

### Backend (Node.js)

- [ ] **Environment Variables**
  - Remove: `PAYU_MERCHANT_KEY`, `PAYU_MERCHANT_SALT`, `PAYU_BASE_URL`
  - Add: `CASHFREE_CLIENT_ID`, `CASHFREE_CLIENT_SECRET`, `CASHFREE_API_VERSION`, `CASHFREE_BASE_URL`, `CASHFREE_WEBHOOK_SECRET`

- [ ] **paymentController.js**
  - [ ] Replace PayU config constants with Cashfree config
  - [ ] Remove `generatePaymentHash()` and `generateResponseHash()`
  - [ ] Add `generateCashfreeSignature()` and `getCashfreeAuthHeaders()`
  - [ ] Completely rewrite `createPayment()` - Use Cashfree REST API
  - [ ] Rewrite `verifyPayment()` - Handle GET callback with query params
  - [ ] Add new `handleWebhook()` function for webhook processing
  - [ ] Update module exports

- [ ] **Routes**
  - [ ] Update `/payments/create-payment` (no change needed)
  - [ ] Change `/payments/success` → `/payments/callback` (GET instead of POST)
  - [ ] Remove or deprecate `/payments/failure` and `/payments/cancel`
  - [ ] Add new `/payments/webhook` route (POST)

### Frontend (Flutter)

- [ ] **Dependencies (pubspec.yaml)**
  - [ ] Remove `payu_checkoutpro_flutter` (if using SDK)
  - [ ] Keep `webview_flutter` for Cashfree integration

- [ ] **payment_service.dart**
  - [ ] Update `PaymentData` model fields:
    - `txnid` → `orderId`
    - `firstname` → `customerName`
    - Remove: `hash`, `surl`, `furl`, `curl`
    - Add: `paymentSessionId`, `returnUrl`
  - [ ] Update `PaymentData.fromJson()` to parse Cashfree response
  - [ ] Update `buildPaymentFormHtml()` → `buildPaymentPageHtml()` (redirect approach)

- [ ] **cashfree_service.dart** (NEW FILE)
  - [ ] Create new CashfreeService class
  - [ ] Implement `openPayment()` method
  - [ ] Add `CashfreePaymentResult` and `CashfreePaymentStatus` enums

- [ ] **payment_screen_webview.dart**
  - [ ] Update URL detection: `payments.cashfree.com` instead of `payu.in`
  - [ ] Update callback detection: `/payments/callback` with query params
  - [ ] Handle `payment_status`, `order_id` query parameters

- [ ] **payment_screen_sdk.dart** (if using SDK)
  - [ ] Replace PayU SDK calls with Cashfree SDK or WebView
  - [ ] Update payment result handling

- [ ] **payu_service.dart**
  - [ ] Delete or archive this file
  - [ ] Remove all imports/references

## 🟡 Configuration Changes

- [ ] **Cashfree Dashboard**
  - [ ] Create merchant account
  - [ ] Complete KYC verification
  - [ ] Get API credentials (Client ID, Secret)
  - [ ] Configure webhook URL: `https://your-backend.com/api/payments/webhook`
  - [ ] Whitelist app package name (for mobile)
  - [ ] Enable required payment methods

- [ ] **Environment Setup**
  - [ ] Update backend `.env` with Cashfree credentials
  - [ ] Set `CASHFREE_BASE_URL` to sandbox for testing
  - [ ] Switch to production URL when ready

## 🟢 Testing

- [ ] **Sandbox Testing**
  - [ ] Create test order (₹1)
  - [ ] Test successful payment
  - [ ] Test failed payment
  - [ ] Test cancellation
  - [ ] Verify webhook received
  - [ ] Verify booking status updates

- [ ] **Production Testing**
  - [ ] Test with real payment (small amount)
  - [ ] Monitor logs
  - [ ] Verify webhook processing
  - [ ] Check booking confirmations

## 📋 Key Differences Summary

| Aspect | PayU | Cashfree |
|--------|------|----------|
| Auth | Merchant Key + Salt | Client ID + Secret |
| Hash | SHA512 string | HMAC-SHA256 signature |
| Order | HTML form POST | REST API (JSON) |
| Payment | Form submission | Payment Session ID |
| Callback | POST surl/furl/curl | GET return_url |
| Webhook | Optional | Required (recommended) |
| Transaction ID | `txnid` | `order_id` |
| Payment ID | `mihpayid` | `payment_id` |

## ⚠️ Important Notes

1. **Webhook is Critical**: Cashfree relies heavily on webhooks for payment status updates. Ensure your webhook endpoint is:
   - Publicly accessible
   - HTTPS enabled
   - Properly configured in Cashfree dashboard

2. **Callback vs Webhook**:
   - Callback (`return_url`): User is redirected here after payment (GET request)
   - Webhook (`notify_url`): Server-to-server notification (POST request with signature)

3. **Payment Session ID**: This is the key identifier for Cashfree payments. Store it in your booking document.

4. **Testing**: Always test in sandbox first. Cashfree sandbox URL: `https://sandbox.cashfree.com`

5. **Backward Compatibility**: Consider keeping old PayU endpoints temporarily for any pending transactions.

## 🚀 Deployment Order

1. Backend changes first (API endpoints)
2. Update environment variables
3. Test backend endpoints
4. Deploy frontend changes
5. Test end-to-end flow
6. Monitor production

## 📞 Support

- Cashfree Docs: https://docs.cashfree.com
- Cashfree Support: support@cashfree.com
- Migration Guide: See `MIGRATION_GUIDE_PAYU_TO_CASHFREE.md`

---

**Status**: ⚠️ Ready to Start Migration
**Last Updated**: [Current Date]

