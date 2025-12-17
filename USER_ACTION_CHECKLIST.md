# 🚀 PayU to Cashfree Migration - User Action Checklist

## ✅ Code Migration Completed!

All code changes have been implemented. Now you need to complete the following steps to make the migration functional.

---

## 🔴 CRITICAL: Steps You Must Complete

### 1. Set Up Cashfree Account ⚠️ REQUIRED

- [ ] **Create Cashfree Merchant Account**
  - Go to: https://merchant.cashfree.com
  - Sign up for a new account
  - Complete the registration process

- [ ] **Complete KYC Verification**
  - Submit required documents (PAN, Bank details, etc.)
  - Wait for verification approval (usually 1-2 business days)

- [ ] **Get API Credentials**
  - Log in to Cashfree Dashboard
  - Navigate to: **Developers** → **API Keys**
  - Copy your **Client ID** (App ID)
  - Copy your **Client Secret** (Secret Key)
  - **⚠️ Keep these secure - never commit to git!**

- [ ] **Get Webhook Secret**
  - In Cashfree Dashboard: **Developers** → **Webhooks**
  - Generate or copy the **Webhook Secret Key**
  - This is used to verify webhook signatures

---

### 2. Configure Environment Variables ⚠️ REQUIRED

**Backend Environment Variables** (Firebase Functions or your hosting platform)

Add these to your backend `.env` file or environment configuration:

```env
# Cashfree Configuration (REQUIRED)
CASHFREE_CLIENT_ID=your_client_id_here
CASHFREE_CLIENT_SECRET=your_client_secret_here
CASHFREE_API_VERSION=2023-08-01
CASHFREE_BASE_URL=https://sandbox.cashfree.com
# For production, change to: https://api.cashfree.com
CASHFREE_WEBHOOK_SECRET=your_webhook_secret_here

# Keep existing variables
BACKEND_URL=https://asia-south1-xperience-gaming.cloudfunctions.net/api
FRONTEND_URL=your_frontend_url_here
```

**⚠️ Important:**
- Use `https://sandbox.cashfree.com` for testing
- Switch to `https://api.cashfree.com` for production
- Never commit `.env` files to git
- Update environment variables in your hosting platform (Firebase Functions, etc.)

---

### 3. Configure Webhook URL ⚠️ REQUIRED

- [ ] **In Cashfree Dashboard:**
  - Go to: **Developers** → **Webhooks**
  - Click **Add Webhook**
  - Webhook URL: `https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/webhook`
  - Select events to listen to:
    - ✅ `PAYMENT_SUCCESS_WEBHOOK`
    - ✅ `PAYMENT_FAILED_WEBHOOK`
    - ✅ `PAYMENT_USER_DROPPED_WEBHOOK`
  - Save the webhook configuration

- [ ] **Verify Webhook is Accessible**
  - Your webhook endpoint must be publicly accessible
  - Must use HTTPS (not HTTP)
  - Test the webhook URL is reachable from internet

---

### 4. Whitelist App Package (For Mobile Apps) ⚠️ REQUIRED

- [ ] **In Cashfree Dashboard:**
  - Go to: **Settings** → **App Settings**
  - Add your Android package name (e.g., `com.yourapp.package`)
  - Add your iOS bundle identifier (if applicable)
  - Save settings

---

### 5. Install Backend Dependencies ⚠️ REQUIRED

```bash
cd backend/functions
npm install axios
# axios should already be installed, but verify it's in package.json
```

---

### 6. Test in Sandbox Environment ⚠️ REQUIRED

**Before going to production, test thoroughly:**

- [ ] **Test Payment Flow:**
  1. Create a test booking
  2. Initiate payment with small amount (₹1)
  3. Complete payment on Cashfree sandbox
  4. Verify callback is received
  5. Verify webhook is received
  6. Verify booking status updates correctly

- [ ] **Test Payment Failure:**
  1. Initiate payment
  2. Cancel or fail the payment
  3. Verify booking status updates to "failed"

- [ ] **Check Logs:**
  - Monitor backend logs for errors
  - Check Cashfree dashboard for transaction logs
  - Verify webhook deliveries in Cashfree dashboard

---

### 7. Deploy Backend Changes ⚠️ REQUIRED

```bash
cd backend/functions

# Deploy to Firebase Functions (or your platform)
firebase deploy --only functions

# OR if using other platform, deploy according to your setup
```

**After deployment:**
- [ ] Verify environment variables are set correctly
- [ ] Test API endpoints are accessible
- [ ] Verify webhook endpoint is reachable

---

### 8. Deploy Frontend Changes ⚠️ REQUIRED

```bash
cd frontend

# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release  # For Android
# OR
flutter build ios --release   # For iOS
```

**After building:**
- [ ] Install the new APK/IPA on test device
- [ ] Test payment flow end-to-end
- [ ] Verify no errors in app logs

---

### 9. Switch to Production ⚠️ REQUIRED (After Testing)

Once sandbox testing is successful:

- [ ] **Update Environment Variable:**
  ```env
  CASHFREE_BASE_URL=https://api.cashfree.com
  ```

- [ ] **Redeploy Backend** with production URL

- [ ] **Update Webhook URL** in Cashfree Dashboard (if different for production)

- [ ] **Test with Real Payment** (small amount first)

---

## 📋 Optional: Cleanup (After Migration is Stable)

Once Cashfree migration is working and stable:

- [ ] Remove PayU environment variables (if not needed)
- [ ] Remove legacy PayU callback handlers (if not needed)
- [ ] Archive or delete PayU service files
- [ ] Update documentation

---

## 🆘 Troubleshooting

### Payment Not Working?

1. **Check Environment Variables:**
   - Verify all Cashfree credentials are set
   - Check `CASHFREE_BASE_URL` is correct (sandbox vs production)

2. **Check Webhook:**
   - Verify webhook URL is accessible
   - Check webhook secret matches
   - View webhook logs in Cashfree dashboard

3. **Check Logs:**
   - Backend logs: Check Firebase Functions logs
   - Frontend logs: Check app console/debug logs
   - Cashfree dashboard: Check transaction logs

4. **Common Issues:**
   - **"Missing Cashfree credentials"** → Set environment variables
   - **"Webhook signature mismatch"** → Check webhook secret
   - **"Booking not found"** → Check order_id matches paymentTransactionId
   - **"Payment session not found"** → Verify payment_session_id is stored

---

## 📞 Support Resources

- **Cashfree Documentation:** https://docs.cashfree.com
- **Cashfree Support:** support@cashfree.com
- **Cashfree Dashboard:** https://merchant.cashfree.com
- **Migration Guide:** See `MIGRATION_GUIDE_PAYU_TO_CASHFREE.md`

---

## ✅ Migration Checklist Summary

### Setup (Do First)
- [ ] Create Cashfree account
- [ ] Complete KYC verification
- [ ] Get API credentials
- [ ] Get webhook secret

### Configuration
- [ ] Set environment variables
- [ ] Configure webhook URL
- [ ] Whitelist app package
- [ ] Install dependencies

### Testing
- [ ] Test payment success flow
- [ ] Test payment failure flow
- [ ] Verify webhook delivery
- [ ] Check booking status updates

### Deployment
- [ ] Deploy backend changes
- [ ] Deploy frontend changes
- [ ] Test end-to-end
- [ ] Switch to production

---

**Status**: ⚠️ **Code Migration Complete - Action Required**

**Next Step**: Set up Cashfree account and configure environment variables

**Last Updated**: [Current Date]

