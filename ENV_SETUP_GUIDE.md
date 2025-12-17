# 🔐 Environment Variables Setup Guide

Complete guide for setting up Cashfree credentials in your `.env.local` file.

---

## 📁 File Location

Create this file in: `backend/functions/.env.local`

**Important:** 
- The file `.env.local` is already in `.gitignore` (won't be committed to git)
- Never commit your actual credentials to git
- Use `.env.local.example` as a template

---

## 📝 Required Cashfree Variables

### For Local Development (Sandbox/Test)

Create `backend/functions/.env.local` with:

```env
# ============================================
# Cashfree Configuration (TEST/SANDBOX)
# ============================================

# Get these from Cashfree Dashboard:
# https://merchant.cashfree.com → Developers → API Keys
CASHFREE_CLIENT_ID=your_test_client_id_here
CASHFREE_CLIENT_SECRET=your_test_client_secret_here

# API Configuration
CASHFREE_API_VERSION=2023-08-01
CASHFREE_BASE_URL=https://sandbox.cashfree.com

# ============================================
# Other Required Variables
# ============================================

BACKEND_URL=https://asia-south1-xperience-gaming.cloudfunctions.net/api
FRONTEND_URL=http://localhost:3000
JWT_SECRET=your_jwt_secret_here
NODE_ENV=development
CORS_ORIGIN=http://localhost:3000
```

---

## 🔑 How to Get Cashfree Credentials

### Step 1: Login to Cashfree Dashboard
- Go to: https://merchant.cashfree.com
- Login with your account

### Step 2: Get Test Credentials
1. Navigate to: **Developers** → **API Keys**
2. Find the **Test/Sandbox** section
3. Copy:
   - **Client ID** (App ID)
   - **Client Secret** (Secret Key)

### Step 3: Add to `.env.local`
```env
CASHFREE_CLIENT_ID=CF1234567890abcdef  # Your actual Client ID
CASHFREE_CLIENT_SECRET=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Your actual Secret
```

---

## 🚀 Quick Setup Steps

### 1. Create `.env.local` File

```bash
cd backend/functions
cp .env.local.example .env.local
# Or create manually
```

### 2. Edit `.env.local`

Open the file and replace placeholder values:

```env
CASHFREE_CLIENT_ID=CF1234567890abcdef
CASHFREE_CLIENT_SECRET=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CASHFREE_API_VERSION=2023-08-01
CASHFREE_BASE_URL=https://sandbox.cashfree.com
```

### 3. Verify Setup

Run the emulator:
```bash
cd backend/functions
npm run serve
```

Check logs for:
```
💳 [PAYMENT_CONFIG] Cashfree Configuration Status:
💳 [PAYMENT_CONFIG] CASHFREE_CLIENT_ID: CF12...
💳 [PAYMENT_CONFIG] CASHFREE_CLIENT_SECRET: ✅ SET
💳 [PAYMENT_CONFIG] CASHFREE_BASE_URL: https://sandbox.cashfree.com
```

---

## 🌍 Environment-Specific Configuration

### Local Development (Sandbox)
```env
CASHFREE_BASE_URL=https://sandbox.cashfree.com
CASHFREE_CLIENT_ID=your_test_client_id
CASHFREE_CLIENT_SECRET=your_test_client_secret
NODE_ENV=development
```

### Production
```env
CASHFREE_BASE_URL=https://api.cashfree.com
CASHFREE_CLIENT_ID=your_production_client_id
CASHFREE_CLIENT_SECRET=your_production_client_secret
NODE_ENV=production
```

**⚠️ Important:** Use different credentials for production!

---

## 🔒 Security Best Practices

### ✅ DO:
- ✅ Keep `.env.local` in `.gitignore`
- ✅ Use test credentials for local development
- ✅ Use production credentials only in Firebase Functions config
- ✅ Never share credentials publicly
- ✅ Rotate secrets if compromised

### ❌ DON'T:
- ❌ Commit `.env.local` to git
- ❌ Share credentials in chat/email
- ❌ Use production credentials locally
- ❌ Hardcode credentials in code
- ❌ Log full secrets (only show first 4 chars)

---

## 📋 Complete `.env.local` Template

```env
# ============================================
# Cashfree Payment Gateway (SANDBOX)
# ============================================
CASHFREE_CLIENT_ID=CF1234567890abcdef
CASHFREE_CLIENT_SECRET=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CASHFREE_API_VERSION=2023-08-01
CASHFREE_BASE_URL=https://sandbox.cashfree.com

# ============================================
# Application Configuration
# ============================================
BACKEND_URL=https://asia-south1-xperience-gaming.cloudfunctions.net/api
FRONTEND_URL=http://localhost:3000
JWT_SECRET=your_jwt_secret_minimum_32_chars_long
NODE_ENV=development
CORS_ORIGIN=http://localhost:3000

# ============================================
# Firebase Storage
# ============================================
APP_STORAGE_BUCKET=xperience-gaming.firebasestorage.app
```

---

## 🧪 Testing Your Setup

### 1. Start Emulator
```bash
cd backend/functions
npm run serve
```

### 2. Check Logs
Look for configuration logs:
```
💳 [PAYMENT_CONFIG] ========================================
💳 [PAYMENT_CONFIG] Cashfree Configuration Status:
💳 [PAYMENT_CONFIG] CASHFREE_CLIENT_ID: CF12...
💳 [PAYMENT_CONFIG] CASHFREE_CLIENT_SECRET: ✅ SET
💳 [PAYMENT_CONFIG] CASHFREE_BASE_URL: https://sandbox.cashfree.com
💳 [PAYMENT_CONFIG] Environment: 🟡 SANDBOX
```

### 3. Test Payment Endpoint
```bash
curl -X POST http://localhost:5001/xperience-gaming/asia-south1/api/payments/create-payment \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "bookingId": "test123",
    "amount": 1,
    "firstName": "Test",
    "email": "test@example.com"
  }'
```

---

## 🚀 Production Deployment

For production, set environment variables in Firebase:

### Using Firebase Console:
1. Go to Firebase Console
2. Select your project
3. Functions → Configuration
4. Add variables:
   - `CASHFREE_CLIENT_ID`
   - `CASHFREE_CLIENT_SECRET` (as Secret)
   - `CASHFREE_API_VERSION`
   - `CASHFREE_BASE_URL`

### Using Firebase CLI:
```bash
firebase functions:secrets:set CASHFREE_CLIENT_SECRET
firebase functions:config:set cashfree.client_id="your_prod_id"
firebase functions:config:set cashfree.base_url="https://api.cashfree.com"
```

---

## ❓ Troubleshooting

### Issue: "Missing Cashfree credentials"
**Solution:** Check `.env.local` file exists and has correct variable names

### Issue: Variables not loading
**Solution:** 
1. Ensure file is named exactly `.env.local`
2. Restart emulator after changes
3. Check file is in `backend/functions/` directory

### Issue: Wrong environment
**Solution:** Verify `CASHFREE_BASE_URL` is correct:
- Sandbox: `https://sandbox.cashfree.com`
- Production: `https://api.cashfree.com`

---

## 📚 Additional Resources

- **Cashfree Dashboard**: https://merchant.cashfree.com
- **Cashfree Docs**: https://docs.cashfree.com
- **Firebase Functions Config**: https://firebase.google.com/docs/functions/config-env

---

**✅ Once `.env.local` is set up, you're ready to test!**

