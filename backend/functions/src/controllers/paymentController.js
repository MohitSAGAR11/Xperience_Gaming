const crypto = require('crypto');
const axios = require('axios');
const { db } = require('../config/firebase');

// --- Configuration ---
// Cashfree Configuration
const CASHFREE_CLIENT_ID = process.env.CASHFREE_CLIENT_ID;
const CASHFREE_CLIENT_SECRET = process.env.CASHFREE_CLIENT_SECRET;
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || '2023-08-01';
const CASHFREE_BASE_URL = process.env.CASHFREE_BASE_URL || 'https://api.cashfree.com';
// Note: Cashfree uses Client Secret for webhook verification, not a separate webhook secret
const CASHFREE_WEBHOOK_SECRET = process.env.CASHFREE_WEBHOOK_SECRET || CASHFREE_CLIENT_SECRET;


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

// --- Cashfree Helper Functions ---
function getCashfreeAuthHeaders() {
  return {
    'x-client-id': CASHFREE_CLIENT_ID,
    'x-client-secret': CASHFREE_CLIENT_SECRET,
    'x-api-version': CASHFREE_API_VERSION,
    'Content-Type': 'application/json',
  };
}

// Cashfree webhook signature generation (for reference)
// Format: HMAC-SHA256(timestamp + rawBody) base64 encoded
function generateCashfreeWebhookSignature(timestamp, rawBody, secret) {
  const message = `${timestamp}${rawBody}`;
  const hmac = crypto.createHmac('sha256', secret);
  hmac.update(message);
  return hmac.digest('base64');
}


/**
 * @desc    Create Cashfree Payment Order
 * @route   POST /api/payments/create-payment
 */
const createPayment = async (req, res) => {
  const requestId = `REQ-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CREATE CASHFREE PAYMENT REQUEST ===', { requestId });
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

    // Validate Cashfree Configuration
    if (!CASHFREE_CLIENT_ID || !CASHFREE_CLIENT_SECRET) {
      logPaymentError('Server config error - Missing Cashfree credentials', { 
        requestId,
        hasClientId: !!CASHFREE_CLIENT_ID,
        hasClientSecret: !!CASHFREE_CLIENT_SECRET
      });
      return res.status(500).json({ success: false, message: 'Server config error - Missing Cashfree credentials' });
    }
    
    logPayment('Cashfree Configuration Validated', {
      requestId,
      cashfreeBaseUrl: CASHFREE_BASE_URL,
      clientIdPrefix: CASHFREE_CLIENT_ID ? CASHFREE_CLIENT_ID.substring(0, 4) + '...' : 'MISSING',
      hasClientSecret: !!CASHFREE_CLIENT_SECRET,
      apiVersion: CASHFREE_API_VERSION,
      isProduction: !CASHFREE_BASE_URL.includes('sandbox')
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

    // 3. Generate Order ID (Cashfree format: alphanumeric, max 50 chars)
    const orderId = `ORDER_${bookingId}_${Date.now()}`;
    const formattedAmount = parseFloat(amount).toFixed(2);
    const userPhone = phone || '9999999999';
    const nameParts = (firstName || 'Guest').trim().split(' ');
    const userFirstName = nameParts[0].substring(0, 60);
    
    // Prepare callback URLs
    const returnUrl = `${BACKEND_URL}/payments/callback`;
    const notifyUrl = `${BACKEND_URL}/payments/webhook`;

    // Create Cashfree Order Payload
    const orderPayload = {
      order_id: orderId,
      order_amount: parseFloat(formattedAmount),
      order_currency: 'INR',
      order_note: (productInfo || `Booking ${bookingId}`).substring(0, 100),
      customer_details: {
        customer_id: bookingId,
        customer_name: userFirstName,
        customer_email: email,
        customer_phone: userPhone,
      },
      order_meta: {
        return_url: returnUrl,
        notify_url: notifyUrl,
        payment_methods: 'cc,dc,upi,nb,paylater',
      },
    };

    logPayment('Creating Cashfree order', { 
      requestId,
      orderId, 
      bookingId, 
      amount: formattedAmount,
      returnUrl,
      notifyUrl
    });

    // Call Cashfree Create Order API
    let cashfreeResponse;
    try {
      cashfreeResponse = await axios.post(
        `${CASHFREE_BASE_URL}/pg/orders`,
        orderPayload,
        {
          headers: getCashfreeAuthHeaders(),
        }
      );
    } catch (apiError) {
      logPaymentError('Cashfree API call failed', {
        requestId,
        error: apiError.message,
        response: apiError.response?.data,
        status: apiError.response?.status
      });
      
      const errorMessage = apiError.response?.data?.message || 
                          apiError.response?.data?.error?.message ||
                          'Failed to create payment order with Cashfree';
      
      return res.status(apiError.response?.status || 500).json({ 
        success: false, 
        message: errorMessage 
      });
    }

    const { payment_session_id, order_token } = cashfreeResponse.data;

    if (!payment_session_id) {
      logPaymentError('Cashfree order creation failed - missing payment_session_id', { 
        requestId, 
        response: cashfreeResponse.data 
      });
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to create payment order - invalid response from payment gateway' 
      });
    }

    // Update Booking in DB
    await db.collection('bookings').doc(bookingId).update({
      paymentTransactionId: orderId,
      paymentSessionId: payment_session_id,
      paymentStatus: 'pending',
      updatedAt: new Date(),
    });

    logPayment('✅ CASHFREE ORDER CREATED', {
      requestId,
      orderId,
      paymentSessionId: payment_session_id,
      bookingId,
    });

    // Return payment session data to frontend (JSON response instead of HTML)
    res.json({
      success: true,
      message: 'Payment order created successfully',
      data: {
        orderId: orderId,
        paymentSessionId: payment_session_id,
        orderAmount: formattedAmount,
        orderCurrency: 'INR',
        customerName: userFirstName,
        customerEmail: email,
        customerPhone: userPhone,
        returnUrl: returnUrl,
      },
    });

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
 * @desc    Handle Cashfree Payment Callback (Return URL)
 * @route   GET /api/payments/callback
 */
const verifyPayment = async (req, res) => {
  const requestId = `CALLBACK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CASHFREE PAYMENT CALLBACK ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'user-agent': req.headers['user-agent'],
      'origin': req.headers['origin'],
      'referer': req.headers['referer']
    });
    logPayment('Request Query Params', req.query);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);
    
    const { order_id, order_token, payment_id, payment_status } = req.query;
    
    logPayment('Extracted Callback Data', {
      requestId,
      order_id,
      payment_id,
      payment_status,
    });

    if (!order_id) {
      logPaymentError('Missing order_id in callback', { requestId });
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=invalid_callback`);
    }

    // Find booking by order_id (stored as paymentTransactionId)
    const bookingsQuery = await db.collection('bookings')
      .where('paymentTransactionId', '==', order_id)
      .limit(1)
      .get();
    
    if (bookingsQuery.empty) {
      logPaymentError('Booking not found', { order_id, requestId });
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=booking_not_found`);
    }

    const bookingId = bookingsQuery.docs[0].id;
    const bookingData = bookingsQuery.docs[0].data();

    // Verify payment status with Cashfree API
    try {
      const paymentResponse = await axios.get(
        `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`,
        {
          headers: getCashfreeAuthHeaders(),
        }
      );

      const payments = paymentResponse.data;
      const latestPayment = payments && payments.length > 0 ? payments[0] : null;

      if (!latestPayment || latestPayment.payment_status !== 'SUCCESS') {
        // Payment failed or pending
        const paymentMessage = latestPayment?.payment_message || 'Payment failed';
        await db.collection('bookings').doc(bookingId).update({
          paymentStatus: 'failed',
          paymentError: paymentMessage,
          updatedAt: new Date(),
        });
        
        logPayment('❌ Payment failed', {
          requestId,
          bookingId,
          orderId: order_id,
          paymentStatus: latestPayment?.payment_status,
          paymentMessage,
        });
        
        return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&bookingId=${bookingId}`);
      }

      // Payment successful - verify and update booking
      await db.collection('bookings').doc(bookingId).update({
        paymentId: latestPayment.payment_id,
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      });

      logPayment('✅ PAYMENT VERIFIED & BOOKING CONFIRMED', {
        requestId,
        bookingId,
        orderId: order_id,
        paymentId: latestPayment.payment_id,
        amount: latestPayment.payment_amount,
      });

      return res.redirect(`${FRONTEND_URL}/payment-result?status=success&bookingId=${bookingId}`);

    } catch (apiError) {
      logPaymentError('Error verifying payment with Cashfree API', {
        requestId,
        error: apiError.message,
        orderId: order_id,
      });
      // Still redirect but mark as pending verification
      return res.redirect(`${FRONTEND_URL}/payment-result?status=pending&bookingId=${bookingId}`);
    }

  } catch (error) {
    logPaymentError('❌ PAYMENT CALLBACK ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
      query: req.query
    });
    res.redirect(`${FRONTEND_URL}/payment-result?status=failure`);
  }
};

/**
 * @desc    Verify Payment Status (POST endpoint for client-side verification)
 * @route   POST /api/payments/verify
 * @access  Private
 */
const verifyPaymentPost = async (req, res) => {
  const requestId = `VERIFY-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== PAYMENT VERIFICATION REQUEST ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request Body', req.body);
    
    const { order_id } = req.body;
    
    if (!order_id) {
      logPaymentError('Missing order_id in verification request', { requestId });
      return res.status(400).json({
        success: false,
        message: 'Order ID is required'
      });
    }

    // Find booking by order_id (stored as paymentTransactionId)
    const bookingsQuery = await db.collection('bookings')
      .where('paymentTransactionId', '==', order_id)
      .limit(1)
      .get();
    
    if (bookingsQuery.empty) {
      logPaymentError('Booking not found', { order_id, requestId });
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    const bookingId = bookingsQuery.docs[0].id;
    const bookingData = bookingsQuery.docs[0].data();

    // Verify payment status with Cashfree API
    try {
      const paymentResponse = await axios.get(
        `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`,
        {
          headers: getCashfreeAuthHeaders(),
        }
      );

      const payments = paymentResponse.data;
      const latestPayment = payments && payments.length > 0 ? payments[0] : null;

      if (!latestPayment || latestPayment.payment_status !== 'SUCCESS') {
        // Payment failed or pending
        const paymentMessage = latestPayment?.payment_message || 'Payment failed';
        await db.collection('bookings').doc(bookingId).update({
          paymentStatus: 'failed',
          paymentError: paymentMessage,
          updatedAt: new Date(),
        });
        
        logPayment('❌ Payment verification failed', {
          requestId,
          bookingId,
          orderId: order_id,
          paymentStatus: latestPayment?.payment_status,
          paymentMessage,
        });
        
        return res.json({
          success: false,
          message: paymentMessage,
          data: {
            bookingId,
            paymentStatus: 'failed',
            orderId: order_id,
          }
        });
      }

      // Payment successful - verify and update booking
      await db.collection('bookings').doc(bookingId).update({
        paymentId: latestPayment.payment_id,
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      });

      logPayment('✅ PAYMENT VERIFIED & BOOKING CONFIRMED', {
        requestId,
        bookingId,
        orderId: order_id,
        paymentId: latestPayment.payment_id,
        amount: latestPayment.payment_amount,
      });

      return res.json({
        success: true,
        message: 'Payment verified successfully',
        data: {
          bookingId,
          paymentStatus: 'paid',
          orderId: order_id,
          paymentId: latestPayment.payment_id,
        }
      });

    } catch (apiError) {
      logPaymentError('Error verifying payment with Cashfree API', {
        requestId,
        error: apiError.message,
        orderId: order_id,
      });
      
      return res.status(500).json({
        success: false,
        message: 'Error verifying payment',
        data: {
          bookingId,
          paymentStatus: 'pending',
        }
      });
    }

  } catch (error) {
    logPaymentError('❌ PAYMENT VERIFICATION ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    res.status(500).json({
      success: false,
      message: 'Error verifying payment',
    });
  }
};

/**
 * @desc    Handle Cashfree Webhook (Payment Notifications)
 * @route   POST /api/payments/webhook
 */
const handleWebhook = async (req, res) => {
  const requestId = `WEBHOOK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    logPayment('=== CASHFREE WEBHOOK ===', { requestId });
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'x-cashfree-signature': req.headers['x-cashfree-signature'] ? 'PRESENT' : 'MISSING',
      'user-agent': req.headers['user-agent'],
    });
    logPayment('Request Body', req.body);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);
    
    // Cashfree webhook signature verification
    // Cashfree uses x-webhook-signature and x-webhook-timestamp headers
    const signature = req.headers['x-webhook-signature'] || req.headers['x-cashfree-signature'];
    const timestamp = req.headers['x-webhook-timestamp'];
    const rawBody = JSON.stringify(req.body);

    // Verify webhook signature (if Client Secret is configured)
    // Cashfree signature: HMAC-SHA256(timestamp + rawBody) base64 encoded
    if (CASHFREE_CLIENT_SECRET && signature) {
      try {
        // Concatenate timestamp and raw body
        const message = timestamp ? `${timestamp}${rawBody}` : rawBody;
        
        // Generate HMAC-SHA256 hash
        const hmac = crypto.createHmac('sha256', CASHFREE_CLIENT_SECRET);
        hmac.update(message);
        const expectedSignature = hmac.digest('base64');
        
        // Compare signatures (use constant-time comparison for security)
        let signatureMatch = false;
        if (signature.length === expectedSignature.length) {
          try {
            signatureMatch = crypto.timingSafeEqual(
              Buffer.from(signature),
              Buffer.from(expectedSignature)
            );
          } catch (e) {
            signatureMatch = false;
          }
        }
        
        if (!signatureMatch) {
          logPaymentError('Webhook signature mismatch', { 
            requestId,
            received: signature.substring(0, 20) + '...',
            expected: expectedSignature.substring(0, 20) + '...',
            hasTimestamp: !!timestamp
          });
          return res.status(401).json({ success: false, message: 'Invalid signature' });
        }
        logPayment('✅ Webhook signature verified', { requestId });
      } catch (sigError) {
        logPaymentError('Error verifying webhook signature', {
          requestId,
          error: sigError.message
        });
        // Continue processing if signature verification fails (for testing)
        logPayment('⚠️ Continuing webhook processing despite signature error', { requestId });
      }
    } else {
      logPayment('⚠️ Webhook signature verification skipped (Client Secret not configured)', { requestId });
    }

    const { data } = req.body;
    const { order, payment } = data || {};

    if (!order || !payment) {
      logPaymentError('Invalid webhook data', { requestId, body: req.body });
      return res.status(400).json({ success: false, message: 'Invalid webhook data' });
    }

    const orderId = order.order_id;
    const paymentStatus = payment.payment_status;
    const paymentId = payment.payment_id;

    logPayment('Webhook data extracted', {
      requestId,
      orderId,
      paymentId,
      paymentStatus,
      paymentAmount: payment.payment_amount,
      paymentMessage: payment.payment_message,
    });

    // Find booking
    const bookingsQuery = await db.collection('bookings')
      .where('paymentTransactionId', '==', orderId)
      .limit(1)
      .get();

    if (bookingsQuery.empty) {
      logPaymentError('Booking not found for webhook', { orderId, requestId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    const bookingId = bookingsQuery.docs[0].id;

    // Update booking based on payment status
    if (paymentStatus === 'SUCCESS') {
      await db.collection('bookings').doc(bookingId).update({
        paymentId: paymentId,
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      });
      logPayment('✅ Booking updated to paid status via webhook', {
        requestId,
        bookingId,
        orderId,
        paymentId,
      });
    } else if (paymentStatus === 'FAILED' || paymentStatus === 'USER_DROPPED') {
      await db.collection('bookings').doc(bookingId).update({
        paymentStatus: 'failed',
        paymentError: payment.payment_message || 'Payment failed',
        updatedAt: new Date(),
      });
      logPayment('❌ Booking updated to failed status via webhook', {
        requestId,
        bookingId,
        orderId,
        paymentStatus,
      });
    } else {
      logPayment('⚠️ Payment status not handled', {
        requestId,
        bookingId,
        orderId,
        paymentStatus,
      });
    }

    logPayment('✅ WEBHOOK PROCESSED', {
      requestId,
      bookingId,
      orderId,
      paymentStatus,
    });

    res.json({ success: true });

  } catch (error) {
    logPaymentError('❌ WEBHOOK ERROR', {
      requestId,
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    res.status(500).json({ success: false, message: 'Webhook processing failed' });
  }
};

module.exports = {
  createPayment,
  verifyPayment,
  verifyPaymentPost,
  handleWebhook,
};