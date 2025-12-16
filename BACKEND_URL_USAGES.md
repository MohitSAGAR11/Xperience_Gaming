# 🔍 BACKEND_URL Environment Variable - All Usages

This document lists all places where `BACKEND_URL` from `.env` is used in the codebase.

---

## 📍 Summary

**Total Usages:** 4 locations  
**File:** `backend/src/controllers/paymentController.js`  
**Purpose:** PayU payment callback URLs (success, failure, cancel)

---

## 📄 File: `backend/src/controllers/paymentController.js`

### **Line 7: Variable Declaration**
```javascript
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5000';
```
**Purpose:** Reads `BACKEND_URL` from environment variables, defaults to `http://localhost:5000` if not set.

---

### **Line 60: Success Callback URL (surl)**
```javascript
surl: `${BACKEND_URL}/api/payments/success`,
```
**Purpose:** PayU will redirect to this URL when payment is successful.  
**Full URL Example:** `http://your-backend:5000/api/payments/success`

**Used in:** `createPayment()` function - Payment parameters sent to PayU

---

### **Line 61: Failure Callback URL (furl)**
```javascript
furl: `${BACKEND_URL}/api/payments/failure`,
```
**Purpose:** PayU will redirect to this URL when payment fails.  
**Full URL Example:** `http://your-backend:5000/api/payments/failure`

**Used in:** `createPayment()` function - Payment parameters sent to PayU

---

### **Line 62: Cancel Callback URL (curl)**
```javascript
curl: `${BACKEND_URL}/api/payments/cancel`,
```
**Purpose:** PayU will redirect to this URL when user cancels payment.  
**Full URL Example:** `http://your-backend:5000/api/payments/cancel`

**Used in:** `createPayment()` function - Payment parameters sent to PayU

---

## 🎯 What These URLs Are Used For

These URLs are **callback URLs** that PayU uses to notify your backend about payment status:

1. **Success URL (`surl`):**
   - PayU redirects here after successful payment
   - Backend verifies payment hash
   - Backend updates booking status to `confirmed` and `paid`
   - Backend redirects user to frontend success page

2. **Failure URL (`furl`):**
   - PayU redirects here if payment fails
   - Backend updates booking: `paymentStatus = 'failed'`
   - Backend redirects user to frontend failure page

3. **Cancel URL (`curl`):**
   - PayU redirects here if user cancels payment
   - Backend updates booking: `paymentStatus = 'failed'`
   - Backend redirects user to frontend cancel page

---

## ⚙️ Environment Variable Setup

### **Development (.env):**
```env
BACKEND_URL=http://localhost:5000
```

### **Production (.env):**
```env
BACKEND_URL=https://api.yourapp.com
# OR
BACKEND_URL=https://your-backend-domain.com
```

---

## 🔐 Important Notes

1. **Must be publicly accessible:** PayU needs to reach these URLs from their servers
2. **Must use HTTPS in production:** PayU requires HTTPS for production
3. **Must include port if not standard:** If your backend runs on non-standard port, include it
4. **No trailing slash:** Don't add `/` at the end

---

## 📋 Related Environment Variables

Also used in the same file:
- `FRONTEND_URL` - Used for redirecting users after payment processing
- `PAYU_MERCHANT_KEY` - PayU merchant key
- `PAYU_MERCHANT_SALT` - PayU merchant salt (secret!)
- `PAYU_BASE_URL` - PayU API base URL

---

## 🧪 Testing

### **Local Development:**
```env
BACKEND_URL=http://localhost:5000
```
- Works for local testing
- PayU can't reach `localhost` from their servers
- Use **ngrok** or similar tool for testing callbacks

### **Using ngrok for Local Testing:**
```bash
# Terminal 1: Start your backend
npm start

# Terminal 2: Start ngrok tunnel
ngrok http 5000

# Use ngrok URL in .env
BACKEND_URL=https://abc123.ngrok.io
```

### **Production:**
```env
BACKEND_URL=https://api.yourapp.com
```
- Must be publicly accessible
- Must use HTTPS
- Must be reachable by PayU servers

---

## ✅ Checklist

- [ ] `BACKEND_URL` added to `.env` file
- [ ] URL is publicly accessible (for PayU callbacks)
- [ ] HTTPS enabled (for production)
- [ ] No trailing slash in URL
- [ ] Port included if non-standard (e.g., `:5000`)
- [ ] Tested with ngrok (for local development)

---

## 📝 Example .env Configuration

```env
# Backend Configuration
BACKEND_URL=http://localhost:5000
FRONTEND_URL=http://localhost:3000

# PayU Configuration
PAYU_MERCHANT_KEY=your_merchant_key
PAYU_MERCHANT_SALT=your_merchant_salt
PAYU_MODE=test
PAYU_BASE_URL=https://test.payu.in
```

---

**Last Updated:** December 2024

