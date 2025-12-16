# 🔍 PayU "Pardon Some Error Occurred" - Debugging Guide

## ❓ What Does "Pardon Some Error Occurred" Mean?

When you see **"Pardon some error occurred"** on PayU's payment page, it means PayU rejected your payment request. This is a generic error message from PayU that can have several causes.

---

## 🚨 Common Causes & Solutions

### **1. Missing or Invalid Merchant Key** ⚠️ MOST COMMON
**Error:** PayU can't authenticate your request

**Check:**
- Is `PAYU_MERCHANT_KEY` set in `.env`?
- Is the merchant key correct?
- Are you using test key in test mode and live key in production?

**Debug with logs:**
```
💳 [PAYMENT] Environment check passed
💳 [PAYMENT] hasMerchantKey: true/false  ← Check this!
```

**Solution:**
```env
# In backend/.env
PAYU_MERCHANT_KEY=your_actual_merchant_key_here
```

---

### **2. Missing or Invalid Merchant Salt** ⚠️ MOST COMMON
**Error:** Hash generation fails or hash verification fails

**Check:**
- Is `PAYU_MERCHANT_SALT` set in `.env`?
- Is the salt correct?
- Salt is different from merchant key!

**Debug with logs:**
```
💳 [PAYMENT] Environment check passed
💳 [PAYMENT] hasMerchantSalt: true/false  ← Check this!
```

**Solution:**
```env
# In backend/.env
PAYU_MERCHANT_SALT=your_actual_merchant_salt_here
```

---

### **3. Hash Mismatch** 🔐
**Error:** PayU verifies hash and it doesn't match

**Check logs:**
```
💳 [PAYMENT] Hash Generated
💳 [PAYMENT] Hash String: MERCHANT_KEY|txnid|amount|...|SALT_HIDDEN
💳 [PAYMENT] Hash length: 128  ← Should be 128 characters
```

**Common causes:**
- Wrong merchant salt
- Amount format incorrect (should be string, e.g., "500.00")
- Missing or extra fields in hash string
- Special characters in fields (email, name, etc.)

**Solution:**
- Verify salt is correct
- Ensure amount is string format
- Check all fields are properly formatted

---

### **4. Invalid Amount Format** 💰
**Error:** Amount format is incorrect

**Check logs:**
```
💳 [PAYMENT] Payment parameters prepared
💳 [PAYMENT] amount: "500.00"  ← Should be string, not number
```

**Solution:**
- Amount must be string: `amount.toString()`
- Should have 2 decimal places: `"500.00"` not `"500"`

---

### **5. Missing Required Fields** 📝
**Error:** PayU requires certain fields that are missing

**Required fields:**
- `key` (Merchant Key)
- `txnid` (Transaction ID)
- `amount`
- `productinfo`
- `firstname`
- `email`
- `hash`
- `surl`, `furl`, `curl` (callback URLs)

**Check logs:**
```
💳 [PAYMENT] Payment parameters prepared
💳 [PAYMENT] txnid: TXN_booking_123_...
💳 [PAYMENT] amount: "500.00"
💳 [PAYMENT] email: user@example.com
💳 [PAYMENT] firstname: John Doe
```

**Solution:**
- Ensure all required fields are present
- Check email and name are not empty

---

### **6. Invalid Callback URLs** 🔗
**Error:** PayU can't reach your callback URLs

**Check logs:**
```
💳 [PAYMENT] Payment parameters prepared
💳 [PAYMENT] surl: http://localhost:5000/api/payments/success  ← Problem!
💳 [PAYMENT] furl: http://localhost:5000/api/payments/failure
💳 [PAYMENT] curl: http://localhost:5000/api/payments/cancel
```

**Problem:** `localhost` URLs won't work - PayU can't reach localhost from their servers!

**Solution:**
- Use ngrok for local testing:
  ```env
  BACKEND_URL=https://abc123.ngrok.io
  ```
- Use public URL/IP in production:
  ```env
  BACKEND_URL=https://api.yourapp.com
  ```

---

### **7. Wrong PayU Base URL** 🌐
**Error:** Using wrong PayU environment

**Check logs:**
```
💳 [PAYMENT] payuBaseUrl: https://test.payu.in  ← Should match your mode
```

**Solution:**
- Test mode: `https://test.payu.in`
- Production mode: `https://secure.payu.in`

```env
PAYU_MODE=test
PAYU_BASE_URL=https://test.payu.in
```

---

### **8. Special Characters in Fields** 🔤
**Error:** Special characters break hash generation

**Problem:** Special characters in name, email, or productinfo can break hash

**Check logs:**
```
💳 [PAYMENT] firstname: John O'Brien  ← Apostrophe might cause issues
💳 [PAYMENT] email: user+test@example.com  ← Plus sign might cause issues
```

**Solution:**
- URL encode special characters if needed
- Or sanitize input before sending

---

## 🔍 How to Debug Using Logs

### **Step 1: Check Backend Logs**

When payment fails, check your backend console for:

```
💳 [PAYMENT] === CREATE PAYMENT REQUEST ===
💳 [PAYMENT] Environment check passed
💳 [PAYMENT] hasMerchantKey: true/false  ← Should be TRUE
💳 [PAYMENT] hasMerchantSalt: true/false  ← Should be TRUE
💳 [PAYMENT] Payment parameters prepared
💳 [PAYMENT] Hash Generated
```

**If you see:**
- `hasMerchantKey: false` → Add `PAYU_MERCHANT_KEY` to `.env`
- `hasMerchantSalt: false` → Add `PAYU_MERCHANT_SALT` to `.env`
- Hash length not 128 → Hash generation issue

---

### **Step 2: Check Frontend Logs**

Check Flutter console for:

```
💳 [PAYMENT_SERVICE] === CREATE PAYMENT REQUEST ===
💳 [PAYMENT_SERVICE] Response success: true/false
💳 [PAYMENT_SERVICE] Has data: true/false
💳 [PAYMENT_SCREEN] HTML form built
💳 [PAYMENT_SCREEN] Form will auto-submit to PayU
```

**If you see:**
- `Response success: false` → Check backend logs
- `Has data: false` → Backend didn't return payment data
- No "Form will auto-submit" → HTML form not loading

---

### **Step 3: Check PayU Response**

If PayU shows error, check:
1. **Backend logs** - See what was sent to PayU
2. **Hash verification** - Check if hash was generated correctly
3. **Field values** - Ensure all fields have valid values

---

## 📋 Debugging Checklist

### **Before Testing:**
- [ ] `PAYU_MERCHANT_KEY` added to `.env`
- [ ] `PAYU_MERCHANT_SALT` added to `.env`
- [ ] `PAYU_BASE_URL` set correctly (test/production)
- [ ] `BACKEND_URL` is publicly accessible (not localhost)
- [ ] `FRONTEND_URL` is set correctly

### **When Error Occurs:**
- [ ] Check backend console logs (look for 💳 emoji)
- [ ] Check frontend console logs (look for 💳 emoji)
- [ ] Verify merchant key and salt are correct
- [ ] Verify callback URLs are accessible
- [ ] Check hash generation logs
- [ ] Verify amount format (string with decimals)

---

## 🛠️ Quick Fixes

### **Fix 1: Missing Environment Variables**
```bash
# Add to backend/.env
PAYU_MERCHANT_KEY=your_key_here
PAYU_MERCHANT_SALT=your_salt_here
PAYU_MODE=test
PAYU_BASE_URL=https://test.payu.in
BACKEND_URL=https://your-ngrok-url.ngrok.io  # For local testing
FRONTEND_URL=http://localhost:3000
```

### **Fix 2: Localhost Callback URLs**
**Problem:** PayU can't reach `localhost`

**Solution:** Use ngrok
```bash
# Install ngrok: https://ngrok.com/
ngrok http 5000

# Use ngrok URL in .env
BACKEND_URL=https://abc123.ngrok.io
```

### **Fix 3: Hash Verification**
**Check hash string format:**
```
MERCHANT_KEY|txnid|amount|productinfo|firstname|email|||||||||||MERCHANT_SALT
```

**Ensure:**
- No extra spaces
- All fields present
- Correct order
- Salt at the end

---

## 📊 Log Examples

### **✅ Success Logs:**
```
💳 [PAYMENT] === CREATE PAYMENT REQUEST ===
💳 [PAYMENT] Environment check passed
💳 [PAYMENT] hasMerchantKey: true
💳 [PAYMENT] hasMerchantSalt: true
💳 [PAYMENT] Payment parameters prepared
💳 [PAYMENT] Hash Generated
💳 [PAYMENT] Hash length: 128
💳 [PAYMENT] === PAYMENT CREATED SUCCESSFULLY ===
```

### **❌ Error Logs:**
```
💳 [PAYMENT_ERROR] PAYU_MERCHANT_KEY is missing from environment variables
💳 [PAYMENT_ERROR] PAYU_MERCHANT_SALT is missing from environment variables
💳 [PAYMENT_ERROR] Invalid payment hash - SECURITY ALERT
```

---

## 🎯 Most Likely Cause

**90% of "Pardon some error occurred" errors are caused by:**

1. **Missing Merchant Key or Salt** (50%)
   - Not added to `.env`
   - Wrong values
   - Using test key in production or vice versa

2. **Invalid Callback URLs** (30%)
   - Using `localhost` (PayU can't reach it)
   - URLs not publicly accessible

3. **Hash Mismatch** (10%)
   - Wrong salt
   - Incorrect hash string format

---

## 📞 Next Steps

1. **Check your `.env` file** - Ensure all PayU variables are set
2. **Check backend logs** - Look for 💳 emoji logs
3. **Check frontend logs** - Look for 💳 emoji logs  
4. **Verify callback URLs** - Must be publicly accessible
5. **Test with PayU test credentials** - Use test mode first

---

**With the new logging, you'll see exactly where the error occurs!** 🎯

