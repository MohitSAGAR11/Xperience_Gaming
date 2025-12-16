const crypto = require('crypto');
const { db } = require('../config/firebase');

const PAYU_MERCHANT_KEY = process.env.PAYU_MERCHANT_KEY;
const PAYU_MERCHANT_SALT = process.env.PAYU_MERCHANT_SALT;
const PAYU_BASE_URL = process.env.PAYU_BASE_URL;

// Ensure BACKEND_URL includes /api
let BACKEND_URL = process.env.BACKEND_URL || 'https://asia-south1-xperience-gaming.cloudfunctions.net/api';
if (BACKEND_URL && !BACKEND_URL.includes('/api')) {
  BACKEND_URL = BACKEND_URL.endsWith('/') 
    ? `${BACKEND_URL}api` 
    : `${BACKEND_URL}/api`;
}
const FRONTEND_URL = process.env.FRONTEND_URL;

// --- Helper Logs ---
const logPayment = (message, data = null) => {
  console.log(`💳 [PAYMENT] ${message}`);
  if (data) console.log(`💳 [PAYMENT] Data:`, JSON.stringify(data, null, 2));
};

const logPaymentError = (message, error = null) => {
  console.error(`💳 [PAYMENT_ERROR] ${message}`);
  if (error) console.error(`💳 [PAYMENT_ERROR] Details:`, error);
};

// --- HASH GENERATION (FIXED) ---
function generatePaymentHash(params) {
  // FIXED: Removed 'phone' from the hash string.
  // Standard PayU Format: key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt
  // We leave UDF1-UDF5 empty (|||||).
  // Total 11 pipes (|) between email and salt.
  
  const hashString = `${PAYU_MERCHANT_KEY}|${params.txnid}|${params.amount}|${params.productinfo}|${params.firstname}|${params.email}|||||||||||${PAYU_MERCHANT_SALT}`;
  
  const hash = crypto.createHash('sha512').update(hashString).digest('hex');
  
  logPayment('Hash Generated', {
    hashString: hashString.replace(PAYU_MERCHANT_SALT, '[SALT_HIDDEN]'),
    hashLength: hash.length,
    hashFormat: 'Standard (Phone Excluded)', 
    hashPipeCount: (hashString.match(/\|/g) || []).length
  });
  
  return hash;
}

function generateResponseHash(params) {
  // Response hash logic remains the same
  const hashString = `${PAYU_MERCHANT_SALT}|${params.status}|||||||||||${params.email}|${params.firstname}|${params.productinfo}|${params.amount}|${params.txnid}|${PAYU_MERCHANT_KEY}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
}

/**
 * @desc    Create PayU payment
 * @route   POST /api/payments/create-payment
 */
const createPayment = async (req, res) => {
  try {
    logPayment('=== CREATE PAYMENT REQUEST ===');

    if (!PAYU_MERCHANT_KEY || !PAYU_MERCHANT_SALT) {
      logPaymentError('Missing Merchant Config');
      return res.status(500).json({ success: false, message: 'Server config error' });
    }

    const { bookingId, amount, firstName, email, phone, productInfo } = req.body;
    
    // 1. Validation
    if (!bookingId || !amount || !email) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    // 2. Booking Check
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    // 3. Generate Transaction ID
    const transactionId = `TXN${Date.now()}`;
    
    // 4. Prepare Params
    const formattedAmount = parseFloat(amount).toFixed(2);
    const userPhone = phone || '9999999999'; // Default fallback
    const nameParts = (firstName || 'Guest').trim().split(' ');
    const userFirstName = nameParts[0].substring(0, 60);

    const paymentParams = {
      key: PAYU_MERCHANT_KEY,
      txnid: transactionId,
      amount: formattedAmount,
      productinfo: (productInfo || `Booking ${bookingId}`).substring(0, 100),
      firstname: userFirstName,
      email: email,
      phone: userPhone, // Phone is SENT but NOT HASHED
      surl: `${BACKEND_URL}/payments/success`,
      furl: `${BACKEND_URL}/payments/failure`,
      curl: `${BACKEND_URL}/payments/cancel`,
      service_provider: 'payu_paisa'
    };

    // 5. Generate Hash (Using the FIXED function)
    paymentParams.hash = generatePaymentHash(paymentParams);

    // 6. Update Database
    await db.collection('bookings').doc(bookingId).update({
      paymentTransactionId: transactionId,
      paymentStatus: 'pending',
      updatedAt: new Date()
    });

    // 7. Send Response
    res.json({
      success: true,
      data: {
        ...paymentParams,
        paymentUrl: `${PAYU_BASE_URL}/_payment`,
        bookingId: bookingId
      }
    });

  } catch (error) {
    logPaymentError('Create payment failed', error);
    res.status(500).json({ success: false, message: 'Failed to create payment' });
  }
};

/**
 * @desc    Verify payment (Success Callback)
 */
const verifyPayment = async (req, res) => {
  try {
    logPayment('=== PAYMENT SUCCESS CALLBACK ===', req.body);
    const { txnid, mihpayid, status, hash, productinfo } = req.body;

    // 1. Find Booking
    let bookingId = null;
    const bookingsQuery = await db.collection('bookings').where('paymentTransactionId', '==', txnid).limit(1).get();
    
    if (!bookingsQuery.empty) {
      bookingId = bookingsQuery.docs[0].id;
    } else {
       // Fallback for testing/manual hits
       const match = productinfo?.match(/Booking\s+(\w+)/i);
       if (match) bookingId = match[1];
    }

    if (!bookingId) {
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=booking_not_found`);
    }

    // 2. Verify Hash (Security Check)
    const generatedHash = generateResponseHash(req.body);
    if (generatedHash !== hash) {
       logPaymentError('Hash Mismatch', { received: hash, generated: generatedHash });
       await db.collection('bookings').doc(bookingId).update({ paymentStatus: 'failed_hash_mismatch' });
       return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=hash_mismatch`);
    }

    // 3. Update DB & Redirect
    await db.collection('bookings').doc(bookingId).update({
      paymentId: mihpayid,
      paymentStatus: 'paid',
      status: 'confirmed',
      paidAt: new Date()
    });

    // Redirect to your "Signal" URL so Flutter intercepts it
    return res.redirect(`${FRONTEND_URL}/payment-result?status=success&bookingId=${bookingId}`);

  } catch (error) {
    logPaymentError('Verify Error', error);
    res.redirect(`${FRONTEND_URL}/payment-result?status=failure`);
  }
};

const handlePaymentFailure = async (req, res) => {
  logPayment('=== PAYMENT FAILURE CALLBACK ===', req.body);
  const { txnid } = req.body;
  
  // Try to update DB to failed
  const bookingsQuery = await db.collection('bookings').where('paymentTransactionId', '==', txnid).limit(1).get();
  if (!bookingsQuery.empty) {
     await bookingsQuery.docs[0].ref.update({ paymentStatus: 'failed' });
  }

  res.redirect(`${FRONTEND_URL}/payment-result?status=failure`);
};

const handlePaymentCancel = async (req, res) => {
  logPayment('=== PAYMENT CANCEL CALLBACK ===', req.body);
  res.redirect(`${FRONTEND_URL}/payment-result?status=cancel`);
};

module.exports = {
  createPayment,
  verifyPayment,
  handlePaymentFailure,
  handlePaymentCancel
};