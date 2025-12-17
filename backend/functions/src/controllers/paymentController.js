const crypto = require('crypto');
const { db } = require('../config/firebase');

// --- Configuration ---
const PAYU_MERCHANT_KEY = process.env.PAYU_MERCHANT_KEY;
const PAYU_MERCHANT_SALT = process.env.PAYU_MERCHANT_SALT;
const PAYU_BASE_URL = process.env.PAYU_BASE_URL;

// Ensure BACKEND_URL includes /api
let BACKEND_URL = process.env.BACKEND_URL || 'https://asia-south1-xperience-gaming.cloudfunctions.net/api';
if (BACKEND_URL && !BACKEND_URL.includes('/api')) {
  BACKEND_URL = BACKEND_URL.endsWith('/') ? `${BACKEND_URL}api` : `${BACKEND_URL}/api`;
}
const FRONTEND_URL = process.env.FRONTEND_URL;

// --- Helper Logs ---
const logPayment = (message, data = null) => {
  console.log(`💳 [PAYMENT] ${message}`);
  if (data) {
    console.log(`💳 [PAYMENT] Data:`, JSON.stringify(data, null, 2));
  }
};

const logPaymentError = (message, error = null) => {
  console.error(`💳 [PAYMENT_ERROR] ${message}`);
  if (error) {
    console.error(`💳 [PAYMENT_ERROR] Details:`, error);
    if (error.stack) {
      console.error(`💳 [PAYMENT_ERROR] Stack:`, error.stack);
    }
  }
};

// --- Hash Generation (Request) ---
function generatePaymentHash(params) {
  // STANDARD PAYU FORMAT:
  // key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt
  // Phone is intentionally EXCLUDED from the hash string (it is sent as a separate POST param)
  
  const hashString = `${PAYU_MERCHANT_KEY}|${params.txnid}|${params.amount}|${params.productinfo}|${params.firstname}|${params.email}|||||||||||${PAYU_MERCHANT_SALT}`;
  
  const hash = crypto.createHash('sha512').update(hashString).digest('hex');
  
  logPayment('Hash Generated', {
    hashString: hashString.replace(PAYU_MERCHANT_SALT, '[SALT_HIDDEN]'),
    hashLength: hash.length
  });
  
  return hash;
}

// --- Hash Generation (Response Verification) ---
function generateResponseHash(params) {
  // Reverse Hash for verification: SALT|status||||||udf5|udf4...|email|firstname|productinfo|amount|txnid|key
  const hashString = `${PAYU_MERCHANT_SALT}|${params.status}|||||||||||${params.email}|${params.firstname}|${params.productinfo}|${params.amount}|${params.txnid}|${PAYU_MERCHANT_KEY}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
}

/**
 * @desc    Initiate PayU Payment
 * @route   POST /api/payments/create-payment
 */
const createPayment = async (req, res) => {
  const requestId = `REQ-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CREATE PAYMENT REQUEST ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'authorization': req.headers['authorization'] ? 'Bearer [TOKEN_PRESENT]' : 'MISSING',
      'user-agent': req.headers['user-agent'],
      'origin': req.headers['origin'],
      'referer': req.headers['referer']
    });
    logPayment('Request Body', req.body);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);

    // Validate PayU Configuration
    if (!PAYU_MERCHANT_KEY || !PAYU_MERCHANT_SALT) {
      logPaymentError('Server config error - Missing PayU credentials', { 
        requestId,
        hasMerchantKey: !!PAYU_MERCHANT_KEY,
        hasMerchantSalt: !!PAYU_MERCHANT_SALT
      });
      return res.status(500).json({ success: false, message: 'Server config error - Missing PayU credentials' });
    }
    
    if (!PAYU_BASE_URL) {
      logPaymentError('Server config error - Missing PAYU_BASE_URL', { requestId });
      return res.status(500).json({ success: false, message: 'Server config error - Missing PayU base URL' });
    }
    
    // Validate PayU Base URL format
    const isValidPayUUrl = PAYU_BASE_URL === 'https://secure.payu.in' || 
                           PAYU_BASE_URL === 'https://test.payu.in' ||
                           PAYU_BASE_URL.startsWith('https://secure.payu.in') ||
                           PAYU_BASE_URL.startsWith('https://test.payu.in');
    
    if (!isValidPayUUrl) {
      logPaymentError('Server config error - Invalid PAYU_BASE_URL', { 
        requestId,
        payuBaseUrl: PAYU_BASE_URL,
        expected: 'https://secure.payu.in (production) or https://test.payu.in (test)'
      });
      return res.status(500).json({ success: false, message: 'Server config error - Invalid PayU base URL' });
    }
    
    logPayment('PayU Configuration Validated', {
      requestId,
      payuBaseUrl: PAYU_BASE_URL,
      merchantKeyPrefix: PAYU_MERCHANT_KEY ? PAYU_MERCHANT_KEY.substring(0, 4) + '...' : 'MISSING',
      hasSalt: !!PAYU_MERCHANT_SALT,
      isProduction: PAYU_BASE_URL.includes('secure.payu.in')
    });

    const { bookingId, amount, firstName, email, phone, productInfo } = req.body;
    
    logPayment('Extracted Request Data', {
      bookingId,
      amount,
      firstName,
      email,
      phone: phone || 'not provided',
      productInfo: productInfo || 'not provided'
    });
    
    // 1. Validate Inputs
    if (!bookingId || !amount || !email) {
      logPaymentError('Validation failed - Missing required fields', {
        requestId,
        missing: {
          bookingId: !bookingId,
          amount: !amount,
          email: !email
        }
      });
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    // 2. Verify Booking Exists
    logPayment('Checking booking existence', { bookingId, requestId });
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      logPaymentError('Booking not found', { bookingId, requestId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    logPayment('Booking found', { bookingId, requestId, bookingData: bookingDoc.data() });

    // 3. Generate Transaction ID (TXN + Timestamp)
    const transactionId = `TXN${Date.now()}`;
    logPayment('Transaction ID generated', { transactionId, requestId });
    
    // 4. Prepare Payment Parameters
    const formattedAmount = parseFloat(amount).toFixed(2);
    const userPhone = phone || '9999999999';
    const nameParts = (firstName || 'Guest').trim().split(' ');
    const userFirstName = nameParts[0].substring(0, 60);

    const paymentParams = {
      key: PAYU_MERCHANT_KEY,
      txnid: transactionId,
      amount: formattedAmount,
      productinfo: (productInfo || `Booking ${bookingId}`).substring(0, 100),
      firstname: userFirstName,
      email: email,
      phone: userPhone, // Phone is passed to PayU but excluded from hash
      surl: `${BACKEND_URL}/payments/success`,
      furl: `${BACKEND_URL}/payments/failure`,
      curl: `${BACKEND_URL}/payments/cancel`,
      service_provider: 'payu_paisa'
    };

    logPayment('Payment parameters prepared', {
      requestId,
      transactionId,
      amount: formattedAmount,
      email,
      firstName: userFirstName,
      phone: userPhone,
      callbackUrls: {
        success: paymentParams.surl,
        failure: paymentParams.furl,
        cancel: paymentParams.curl
      }
    });

    // 5. Generate Secure Hash
    paymentParams.hash = generatePaymentHash(paymentParams);
    logPayment('Hash generated successfully', { requestId, transactionId });

    // 6. Update Booking in DB (Set to Pending)
    logPayment('Updating booking status to pending', { bookingId, transactionId, requestId });
    await db.collection('bookings').doc(bookingId).update({
      paymentTransactionId: transactionId,
      paymentStatus: 'pending',
      updatedAt: new Date()
    });
    logPayment('Booking updated successfully', { bookingId, transactionId, requestId });

    // 7. Generate HTML Form and Return
    logPayment('Generating HTML payment form', {
      requestId,
      transactionId,
      bookingId,
      amount: formattedAmount
    });

    const formHtml = `<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta charset="UTF-8">
  <title>Processing Payment</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      padding: 40px;
      border-radius: 16px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
      text-align: center;
      max-width: 400px;
    }
    .spinner {
      width: 50px;
      height: 50px;
      border: 4px solid #f3f3f3;
      border-top: 4px solid #667eea;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 20px;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    h2 { color: #333; margin-bottom: 16px; font-size: 24px; }
    p { color: #666; line-height: 1.6; }
    .amount { 
      font-size: 32px; 
      font-weight: bold; 
      color: #667eea; 
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="spinner"></div>
    <h2>Redirecting to Payment Gateway</h2>
    <div class="amount">₹${formattedAmount}</div>
    <p>Please wait while we redirect you to PayU secure payment page...</p>
    <p style="font-size: 12px; margin-top: 20px; color: #999;">
      Do not close this window or press back button
    </p>
  </div>
  
  <form id="payuForm" action="${PAYU_BASE_URL}/_payment" method="post" style="display: none;">
    <input type="hidden" name="key" value="${paymentParams.key}" />
    <input type="hidden" name="txnid" value="${paymentParams.txnid}" />
    <input type="hidden" name="amount" value="${paymentParams.amount}" />
    <input type="hidden" name="productinfo" value="${paymentParams.productinfo}" />
    <input type="hidden" name="firstname" value="${paymentParams.firstname}" />
    <input type="hidden" name="email" value="${paymentParams.email}" />
    <input type="hidden" name="phone" value="${paymentParams.phone}" />
    <input type="hidden" name="surl" value="${paymentParams.surl}" />
    <input type="hidden" name="furl" value="${paymentParams.furl}" />
    <input type="hidden" name="curl" value="${paymentParams.curl}" />
    <input type="hidden" name="hash" value="${paymentParams.hash}" />
    <input type="hidden" name="service_provider" value="${paymentParams.service_provider}" />
  </form>
  
  <script>
    setTimeout(() => {
      document.getElementById('payuForm').submit();
    }, 1500);
  </script>
</body>
</html>`;

    logPayment('✅ CREATE PAYMENT SUCCESS - HTML Form Generated', {
      requestId,
      transactionId,
      bookingId,
      amount: formattedAmount,
      paymentUrl: `${PAYU_BASE_URL}/_payment`
    });
    
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(formHtml);

  } catch (error) {
    logPaymentError('❌ CREATE PAYMENT FAILED', {
      requestId,
      error: error.message,
      stack: error.stack,
      bookingId: req.body?.bookingId
    });
    res.status(500).json({ success: false, message: 'Failed to create payment' });
  }
};

/**
 * @desc    Verify Payment Callback (Success)
 * @route   POST /api/payments/success
 */
const verifyPayment = async (req, res) => {
  const requestId = `SUCCESS-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== PAYMENT SUCCESS CALLBACK ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'user-agent': req.headers['user-agent'],
      'origin': req.headers['origin'],
      'referer': req.headers['referer']
    });
    logPayment('Request Body (Full)', req.body);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);
    
    const { txnid, mihpayid, status, hash, productinfo, amount, email, firstname } = req.body;
    
    logPayment('Extracted Callback Data', {
      requestId,
      txnid,
      mihpayid,
      status,
      hash: hash ? `${hash.substring(0, 20)}...` : 'MISSING',
      productinfo,
      amount,
      email,
      firstname
    });

    // 1. Find Booking by Transaction ID
    logPayment('Searching for booking by transaction ID', { txnid, requestId });
    let bookingId = null;
    const bookingsQuery = await db.collection('bookings').where('paymentTransactionId', '==', txnid).limit(1).get();
    
    if (!bookingsQuery.empty) {
      bookingId = bookingsQuery.docs[0].id;
      logPayment('✅ Booking found by transaction ID', { bookingId, txnid, requestId });
    } else {
       logPayment('Booking not found by transaction ID, trying fallback', { txnid, requestId });
       // Fallback: Extract from product info if needed
       const match = productinfo?.match(/Booking\s+(\w+)/i);
       if (match) {
         bookingId = match[1];
         logPayment('✅ Booking found via productinfo fallback', { bookingId, requestId });
       }
    }

    if (!bookingId) {
      logPaymentError('❌ Booking not found for callback', { txnid, requestId, productinfo });
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=booking_not_found`);
    }

    // 2. Verify Security Hash (Crucial Step)
    logPayment('Verifying payment hash', { requestId, bookingId, txnid });
    const generatedHash = generateResponseHash(req.body);
    
    logPayment('Hash comparison', {
      requestId,
      receivedHash: hash ? `${hash.substring(0, 20)}...` : 'MISSING',
      generatedHash: `${generatedHash.substring(0, 20)}...`,
      match: generatedHash === hash
    });
    
    if (generatedHash !== hash) {
       logPaymentError('❌ Hash Mismatch - Potential Tampering', {
         requestId,
         bookingId,
         txnid,
         received: hash ? `${hash.substring(0, 30)}...` : 'MISSING',
         generated: `${generatedHash.substring(0, 30)}...`
       });
       await db.collection('bookings').doc(bookingId).update({ 
         paymentStatus: 'failed_hash_mismatch',
         updatedAt: new Date()
       });
       logPayment('Booking updated with hash mismatch status', { bookingId, requestId });
       return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=hash_mismatch`);
    }

    logPayment('✅ Hash verification passed', { requestId, bookingId, txnid });

    // 3. Mark Booking as Paid
    logPayment('Updating booking to paid status', { bookingId, mihpayid, requestId });
    await db.collection('bookings').doc(bookingId).update({
      paymentId: mihpayid,
      paymentStatus: 'paid',
      status: 'confirmed',
      paidAt: new Date(),
      updatedAt: new Date()
    });

    logPayment('✅ Payment Verified & Booking Confirmed', {
      requestId,
      bookingId,
      transactionId: txnid,
      paymentId: mihpayid,
      amount,
      status
    });

    // 4. Redirect to App Signal URL
    const redirectUrl = `${FRONTEND_URL}/payment-result?status=success&bookingId=${bookingId}`;
    logPayment('Redirecting to frontend', { requestId, redirectUrl });
    return res.redirect(redirectUrl);

  } catch (error) {
    logPaymentError('❌ VERIFY PAYMENT ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    res.redirect(`${FRONTEND_URL}/payment-result?status=failure`);
  }
};

/**
 * @desc    Handle Payment Failure
 * @route   POST /api/payments/failure
 */
const handlePaymentFailure = async (req, res) => {
  const requestId = `FAILURE-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== PAYMENT FAILURE CALLBACK ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'user-agent': req.headers['user-agent'],
      'origin': req.headers['origin'],
      'referer': req.headers['referer']
    });
    logPayment('Request Body (Full)', req.body);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);
    
    const { txnid, status, error, error_Message, productinfo, amount } = req.body;
    
    logPayment('Extracted Failure Data', {
      requestId,
      txnid,
      status,
      error,
      error_Message,
      productinfo,
      amount
    });
  
    // Attempt to find and update booking
    if (txnid) {
      logPayment('Searching for booking by transaction ID', { txnid, requestId });
      const bookingsQuery = await db.collection('bookings').where('paymentTransactionId', '==', txnid).limit(1).get();
      if (!bookingsQuery.empty) {
        const bookingId = bookingsQuery.docs[0].id;
        logPayment('✅ Booking found, updating to failed status', { bookingId, txnid, requestId });
        await bookingsQuery.docs[0].ref.update({ 
          paymentStatus: 'failed',
          paymentError: error_Message || error || 'Payment failed',
          updatedAt: new Date()
        });
        logPayment('✅ Booking updated to failed status', { bookingId, requestId });
      } else {
        logPaymentError('⚠️ Booking not found for failure callback', { txnid, requestId });
      }
    } else {
      logPaymentError('⚠️ No transaction ID in failure callback', { requestId, body: req.body });
    }

    const redirectUrl = `${FRONTEND_URL}/payment-result?status=failure`;
    logPayment('❌ PAYMENT FAILURE - Redirecting to frontend', { requestId, redirectUrl });
    res.redirect(redirectUrl);
  } catch (error) {
    logPaymentError('❌ HANDLE PAYMENT FAILURE ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    res.redirect(`${FRONTEND_URL}/payment-result?status=failure`);
  }
};

/**
 * @desc    Handle Payment Cancellation
 * @route   POST /api/payments/cancel
 */
const handlePaymentCancel = async (req, res) => {
  const requestId = `CANCEL-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== PAYMENT CANCEL CALLBACK ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'user-agent': req.headers['user-agent'],
      'origin': req.headers['origin'],
      'referer': req.headers['referer']
    });
    logPayment('Request Body (Full)', req.body);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);
    
    const { txnid, productinfo } = req.body;
    
    logPayment('Extracted Cancel Data', {
      requestId,
      txnid,
      productinfo
    });
  
    // Attempt to find and update booking (optional - cancellation might not have txnid)
    if (txnid) {
      logPayment('Searching for booking by transaction ID', { txnid, requestId });
      const bookingsQuery = await db.collection('bookings').where('paymentTransactionId', '==', txnid).limit(1).get();
      if (!bookingsQuery.empty) {
        const bookingId = bookingsQuery.docs[0].id;
        logPayment('✅ Booking found, updating to cancelled status', { bookingId, txnid, requestId });
        await bookingsQuery.docs[0].ref.update({ 
          paymentStatus: 'cancelled',
          updatedAt: new Date()
        });
        logPayment('✅ Booking updated to cancelled status', { bookingId, requestId });
      } else {
        logPayment('⚠️ Booking not found for cancel callback', { txnid, requestId });
      }
    } else {
      logPayment('⚠️ No transaction ID in cancel callback', { requestId, body: req.body });
    }

    const redirectUrl = `${FRONTEND_URL}/payment-result?status=cancel`;
    logPayment('⚠️ PAYMENT CANCELLED - Redirecting to frontend', { requestId, redirectUrl });
    res.redirect(redirectUrl);
  } catch (error) {
    logPaymentError('❌ HANDLE PAYMENT CANCEL ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    res.redirect(`${FRONTEND_URL}/payment-result?status=cancel`);
  }
};

module.exports = {
  createPayment,
  verifyPayment,
  handlePaymentFailure,
  handlePaymentCancel
};