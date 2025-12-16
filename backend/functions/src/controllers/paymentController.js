const crypto = require('crypto');
const { db } = require('../config/firebase');

const PAYU_MERCHANT_KEY = process.env.PAYU_MERCHANT_KEY;
const PAYU_MERCHANT_SALT = process.env.PAYU_MERCHANT_SALT;
const PAYU_BASE_URL = process.env.PAYU_BASE_URL || 'https://test.payu.in';
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5000';
const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3000';

// Logging helper
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

// Generate PayU payment hash
function generatePaymentHash(params) {
  const hashString = `${PAYU_MERCHANT_KEY}|${params.txnid}|${params.amount}|${params.productinfo}|${params.firstname}|${params.email}|||||||||||${PAYU_MERCHANT_SALT}`;
  const hash = crypto.createHash('sha512').update(hashString).digest('hex');
  logPayment('Hash Generated', {
    hashString: hashString.replace(PAYU_MERCHANT_SALT, '[SALT_HIDDEN]'),
    hashLength: hash.length,
    hashPrefix: hash.substring(0, 20) + '...'
  });
  return hash;
}

// Generate PayU response hash for verification
function generateResponseHash(params) {
  const hashString = `${PAYU_MERCHANT_SALT}|${params.status}|||||||||||${params.email}|${params.firstname}|${params.productinfo}|${params.amount}|${params.txnid}|${PAYU_MERCHANT_KEY}`;
  return crypto.createHash('sha512').update(hashString).digest('hex');
}

/**
 * @desc    Create PayU payment
 * @route   POST /api/payments/create-payment
 * @access  Private
 */
const createPayment = async (req, res) => {
  try {
    logPayment('=== CREATE PAYMENT REQUEST ===');
    logPayment('Request received', {
      bookingId: req.body.bookingId,
      amount: req.body.amount,
      firstName: req.body.firstName,
      email: req.body.email,
      userId: req.user?.id
    });

    // Validate environment variables
    if (!PAYU_MERCHANT_KEY) {
      logPaymentError('PAYU_MERCHANT_KEY is missing from environment variables');
      return res.status(500).json({ 
        success: false, 
        message: 'Payment gateway configuration error. Please contact support.' 
      });
    }

    if (!PAYU_MERCHANT_SALT) {
      logPaymentError('PAYU_MERCHANT_SALT is missing from environment variables');
      return res.status(500).json({ 
        success: false, 
        message: 'Payment gateway configuration error. Please contact support.' 
      });
    }

    logPayment('Environment check passed', {
      hasMerchantKey: !!PAYU_MERCHANT_KEY,
      hasMerchantSalt: !!PAYU_MERCHANT_SALT,
      payuBaseUrl: PAYU_BASE_URL,
      backendUrl: BACKEND_URL
    });

    const { bookingId, amount, firstName, email, phone, productInfo } = req.body;
    
    // Validate required fields
    if (!bookingId) {
      logPaymentError('Booking ID is missing');
      return res.status(400).json({ success: false, message: 'Booking ID is required' });
    }

    if (!amount || amount <= 0) {
      logPaymentError('Invalid amount', { amount });
      return res.status(400).json({ success: false, message: 'Invalid payment amount' });
    }

    if (!email) {
      logPaymentError('Email is missing');
      return res.status(400).json({ success: false, message: 'Email is required' });
    }
    
    // Verify booking exists and belongs to user
    logPayment('Fetching booking from database', { bookingId });
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    
    if (!bookingDoc.exists) {
      logPaymentError('Booking not found', { bookingId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    const booking = bookingDoc.data();
    logPayment('Booking found', {
      bookingId,
      userId: booking.userId,
      paymentStatus: booking.paymentStatus,
      status: booking.status
    });
    
    if (booking.userId !== req.user.id) {
      logPaymentError('Unauthorized access attempt', {
        bookingUserId: booking.userId,
        requestUserId: req.user.id
      });
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    
    // Check if booking is already paid
    if (booking.paymentStatus === 'paid') {
      logPaymentError('Booking already paid', { bookingId, paymentStatus: booking.paymentStatus });
      return res.status(400).json({ success: false, message: 'Booking is already paid' });
    }
    
    // Generate unique transaction ID
    const transactionId = `TXN_${bookingId}_${Date.now()}`;
    logPayment('Transaction ID generated', { transactionId });
    
    // Prepare payment parameters
    const paymentParams = {
      key: PAYU_MERCHANT_KEY,
      txnid: transactionId,
      amount: amount.toString(),
      productinfo: productInfo || `Booking ${bookingId}`,
      firstname: firstName || req.user.name || 'Guest',
      email: email || req.user.email,
      phone: phone || req.user.phone || '',
      surl: `${BACKEND_URL}/api/payments/success`,
      furl: `${BACKEND_URL}/api/payments/failure`,
      curl: `${BACKEND_URL}/api/payments/cancel`,
      hash: '',
      service_provider: 'payu_paisa'
    };

    logPayment('Payment parameters prepared', {
      txnid: paymentParams.txnid,
      amount: paymentParams.amount,
      email: paymentParams.email,
      firstname: paymentParams.firstname,
      surl: paymentParams.surl,
      furl: paymentParams.furl,
      curl: paymentParams.curl
    });
    
    // Generate hash
    paymentParams.hash = generatePaymentHash(paymentParams);
    logPayment('Hash generated successfully', { hashLength: paymentParams.hash.length });
    
    // Update booking with transaction ID
    logPayment('Updating booking with transaction ID', { bookingId, transactionId });
    await db.collection('bookings').doc(bookingId).update({
      paymentTransactionId: transactionId,
      paymentStatus: 'pending',
      updatedAt: new Date()
    });
    logPayment('Booking updated successfully');
    
    const responseData = {
      ...paymentParams,
      paymentUrl: `${PAYU_BASE_URL}/_payment`,
      bookingId: bookingId
    };

    logPayment('=== PAYMENT CREATED SUCCESSFULLY ===', {
      transactionId,
      paymentUrl: responseData.paymentUrl,
      bookingId
    });
    
    res.json({
      success: true,
      data: responseData
    });
  } catch (error) {
    logPaymentError('Create payment failed', error);
    res.status(500).json({ success: false, message: 'Failed to create payment' });
  }
};

/**
 * @desc    Verify payment (called from PayU success URL)
 * @route   POST /api/payments/success
 * @access  Public (PayU callback)
 */
const verifyPayment = async (req, res) => {
  try {
    logPayment('=== PAYMENT VERIFICATION CALLBACK ===');
    logPayment('PayU callback received', {
      body: req.body,
      headers: req.headers
    });

    const { txnid, mihpayid, status, hash, productinfo } = req.body;
    
    logPayment('Extracting booking ID', { txnid, productinfo });
    
    // Get booking ID from productinfo or transaction ID
    const bookingIdMatch = productinfo?.match(/Booking\s+(\w+)/i) || txnid?.match(/TXN_(\w+)_/);
    const bookingId = bookingIdMatch ? bookingIdMatch[1] : null;
    
    if (!bookingId) {
      logPaymentError('Could not extract booking ID from payment response', {
        txnid,
        productinfo,
        body: req.body
      });
      return res.redirect(`${FRONTEND_URL}/payment/failure?reason=invalid_booking`);
    }

    logPayment('Booking ID extracted', { bookingId });
    
    // Verify hash
    logPayment('Verifying payment hash');
    const generatedHash = generateResponseHash(req.body);
    
    logPayment('Hash comparison', {
      receivedHash: hash?.substring(0, 20) + '...',
      generatedHash: generatedHash.substring(0, 20) + '...',
      match: generatedHash === hash
    });
    
    if (generatedHash !== hash) {
      logPaymentError('Invalid payment hash - SECURITY ALERT', {
        bookingId,
        receivedHash: hash,
        generatedHash: generatedHash,
        txnid,
        status
      });
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        updatedAt: new Date()
      });
      return res.redirect(`${FRONTEND_URL}/payment/failure?bookingId=${bookingId}&reason=hash_mismatch`);
    }

    logPayment('Hash verified successfully');
    
    // Get booking
    logPayment('Fetching booking from database', { bookingId });
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      logPaymentError('Booking not found after hash verification', { bookingId });
      return res.redirect(`${FRONTEND_URL}/payment/failure?reason=booking_not_found`);
    }

    const booking = bookingDoc.data();
    logPayment('Booking found', {
      bookingId,
      currentStatus: booking.status,
      currentPaymentStatus: booking.paymentStatus
    });
    
    // Update booking based on status
    if (status === 'success') {
      logPayment('Payment successful - updating booking', {
        bookingId,
        paymentId: mihpayid,
        transactionId: txnid
      });

      await db.collection('bookings').doc(bookingId).update({
        paymentId: mihpayid,
        paymentHash: hash,
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date()
      });

      logPayment('=== PAYMENT VERIFIED SUCCESSFULLY ===', {
        bookingId,
        paymentId: mihpayid,
        transactionId: txnid
      });
      
      // Redirect to success page
      return res.redirect(`${FRONTEND_URL}/booking/${bookingId}/success?paymentId=${mihpayid}`);
    } else {
      logPaymentError('Payment failed', {
        bookingId,
        status,
        transactionId: txnid,
        paymentId: mihpayid
      });

      // Payment failed
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        updatedAt: new Date()
      });
      
      return res.redirect(`${FRONTEND_URL}/payment/failure?bookingId=${bookingId}&reason=${status}`);
    }
  } catch (error) {
    logPaymentError('Verify payment error', error);
    res.redirect(`${FRONTEND_URL}/payment/failure?reason=server_error`);
  }
};

/**
 * @desc    Handle payment failure
 * @route   POST /api/payments/failure
 * @access  Public (PayU callback)
 */
const handlePaymentFailure = async (req, res) => {
  try {
    logPayment('=== PAYMENT FAILURE CALLBACK ===');
    logPayment('Failure callback received', { body: req.body });

    const { txnid, productinfo } = req.body;
    
    // Extract booking ID
    const bookingIdMatch = productinfo?.match(/Booking\s+(\w+)/i) || txnid?.match(/TXN_(\w+)_/);
    const bookingId = bookingIdMatch ? bookingIdMatch[1] : null;
    
    logPayment('Booking ID extracted from failure callback', { bookingId, txnid });
    
    if (bookingId) {
      logPayment('Updating booking status to failed', { bookingId });
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        updatedAt: new Date()
      });
      logPayment('Booking updated to failed status');
    } else {
      logPaymentError('Could not extract booking ID from failure callback', {
        txnid,
        productinfo
      });
    }
    
    return res.redirect(`${FRONTEND_URL}/payment/failure${bookingId ? `?bookingId=${bookingId}` : ''}`);
  } catch (error) {
    logPaymentError('Payment failure handler error', error);
    res.redirect(`${FRONTEND_URL}/payment/failure`);
  }
};

/**
 * @desc    Handle payment cancellation
 * @route   POST /api/payments/cancel
 * @access  Public (PayU callback)
 */
const handlePaymentCancel = async (req, res) => {
  try {
    logPayment('=== PAYMENT CANCELLATION CALLBACK ===');
    logPayment('Cancel callback received', { body: req.body });

    const { txnid, productinfo } = req.body;
    
    // Extract booking ID
    const bookingIdMatch = productinfo?.match(/Booking\s+(\w+)/i) || txnid?.match(/TXN_(\w+)_/);
    const bookingId = bookingIdMatch ? bookingIdMatch[1] : null;
    
    logPayment('Booking ID extracted from cancel callback', { bookingId, txnid });
    
    if (bookingId) {
      logPayment('Updating booking status to failed (cancelled)', { bookingId });
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        updatedAt: new Date()
      });
      logPayment('Booking updated to failed status (cancelled)');
    } else {
      logPaymentError('Could not extract booking ID from cancel callback', {
        txnid,
        productinfo
      });
    }
    
    return res.redirect(`${FRONTEND_URL}/payment/cancel${bookingId ? `?bookingId=${bookingId}` : ''}`);
  } catch (error) {
    logPaymentError('Payment cancel handler error', error);
    res.redirect(`${FRONTEND_URL}/payment/cancel`);
  }
};

module.exports = {
  createPayment,
  verifyPayment,
  handlePaymentFailure,
  handlePaymentCancel
};

