const crypto = require('crypto');
const axios = require('axios');
const { db } = require('../config/firebase');

const CASHFREE_CLIENT_ID = process.env.CASHFREE_CLIENT_ID;
const CASHFREE_CLIENT_SECRET = process.env.CASHFREE_CLIENT_SECRET;
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || '2023-08-01';
const CASHFREE_BASE_URL = process.env.CASHFREE_BASE_URL || 'https://api.cashfree.com';
const CASHFREE_WEBHOOK_SECRET = process.env.CASHFREE_WEBHOOK_SECRET || CASHFREE_CLIENT_SECRET;

let BACKEND_URL = process.env.BACKEND_URL || 'https://asia-south1-xperience-gaming.cloudfunctions.net/api';
if (BACKEND_URL && !BACKEND_URL.includes('/api')) {
  BACKEND_URL = BACKEND_URL.endsWith('/') ? `${BACKEND_URL}api` : `${BACKEND_URL}/api`;
}
const FRONTEND_URL = process.env.FRONTEND_URL;

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

function getCashfreeAuthHeaders() {
  return {
    'x-client-id': CASHFREE_CLIENT_ID,
    'x-client-secret': CASHFREE_CLIENT_SECRET,
    'x-api-version': CASHFREE_API_VERSION,
    'Content-Type': 'application/json',
  };
}

function generateCashfreeWebhookSignature(timestamp, rawBody, secret) {
  const message = `${timestamp}${rawBody}`;
  const hmac = crypto.createHmac('sha256', secret);
  hmac.update(message);
  return hmac.digest('base64');
}

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
      clientIdLength: CASHFREE_CLIENT_ID?.length || 0,
      hasClientSecret: !!CASHFREE_CLIENT_SECRET,
      clientSecretLength: CASHFREE_CLIENT_SECRET?.length || 0,
      apiVersion: CASHFREE_API_VERSION,
      environment: 'PRODUCTION'
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

    logPayment('Checking booking existence', { bookingId, requestId });
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      logPaymentError('Booking not found', { bookingId, requestId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    logPayment('Booking found', { bookingId, requestId, bookingData: bookingDoc.data() });

    const orderId = `ORDER_${bookingId}_${Date.now()}`;
    const formattedAmount = parseFloat(amount).toFixed(2);
    const userPhone = phone || '9999999999';
    const nameParts = (firstName || 'Guest').trim().split(' ');
    const userFirstName = nameParts[0].substring(0, 60);
    
    const returnUrl = `${BACKEND_URL}/payments/callback`;
    const notifyUrl = `${BACKEND_URL}/payments/webhook`;

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

    let cashfreeResponse;
    try {
      const authHeaders = getCashfreeAuthHeaders();
      
      logPayment('Calling Cashfree API', {
        requestId,
        url: `${CASHFREE_BASE_URL}/pg/orders`,
        method: 'POST',
        headers: {
          'x-client-id': authHeaders['x-client-id'] ? `${authHeaders['x-client-id'].substring(0, 4)}...` : 'MISSING',
          'x-client-secret': authHeaders['x-client-secret'] ? '***SET***' : 'MISSING',
          'x-api-version': authHeaders['x-api-version'],
          'Content-Type': authHeaders['Content-Type']
        },
        payload: orderPayload
      });
      
      cashfreeResponse = await axios.post(
        `${CASHFREE_BASE_URL}/pg/orders`,
        orderPayload,
        {
          headers: authHeaders,
        }
      );
      
      logPayment('Cashfree API call successful', {
        requestId,
        status: cashfreeResponse.status,
        hasPaymentSessionId: !!cashfreeResponse.data?.payment_session_id
      });
    } catch (apiError) {
      logPaymentError('Cashfree API call failed', {
        requestId,
        error: apiError.message,
        status: apiError.response?.status,
        statusText: apiError.response?.statusText,
        responseHeaders: apiError.response?.headers,
        responseData: apiError.response?.data,
        requestUrl: `${CASHFREE_BASE_URL}/pg/orders`,
        requestMethod: 'POST',
        requestHeaders: {
          'x-client-id': apiError.config?.headers?.['x-client-id'] ? `${apiError.config.headers['x-client-id'].substring(0, 4)}...` : 'MISSING',
          'x-client-secret': apiError.config?.headers?.['x-client-secret'] ? '***SET***' : 'MISSING',
          'x-api-version': apiError.config?.headers?.['x-api-version'],
        }
      });
      
      let errorMessage = 'Failed to create payment order with Cashfree';
      if (apiError.response?.data) {
        const cashfreeError = apiError.response.data;
        errorMessage = cashfreeError.message || 
                      cashfreeError.error?.message ||
                      cashfreeError.error_description ||
                      `Cashfree API error: ${cashfreeError.type || 'unknown'}`;
        
        if (apiError.response.status === 401) {
          errorMessage = `Cashfree authentication failed. ${errorMessage}`;
          logPaymentError('Cashfree 401 Error - Possible causes:', {
            requestId,
            causes: [
              'Invalid Client ID or Client Secret',
              'Credentials expired or revoked',
              'API version mismatch',
              'Account suspended or inactive'
            ]
          });
        }
      }
      
      return res.status(apiError.response?.status || 500).json({ 
        success: false, 
        message: errorMessage,
        errorCode: apiError.response?.data?.code || apiError.response?.data?.type || 'cashfree_api_error'
      });
    }

    logPayment('Extracting payment session from Cashfree response', {
      requestId,
      responseKeys: Object.keys(cashfreeResponse.data || {}),
      hasPaymentSessionId: !!cashfreeResponse.data?.payment_session_id,
      hasOrderToken: !!cashfreeResponse.data?.order_token,
      fullResponse: cashfreeResponse.data
    });

    const { payment_session_id, order_token } = cashfreeResponse.data;

    logPayment('Payment session extraction result', {
      requestId,
      payment_session_id: payment_session_id ? `${payment_session_id.substring(0, 20)}... (${payment_session_id.length} chars)` : 'MISSING',
      order_token: order_token ? `${order_token.substring(0, 20)}... (${order_token.length} chars)` : 'MISSING',
      payment_session_id_empty: !payment_session_id || payment_session_id.length === 0
    });

    if (!payment_session_id) {
      logPaymentError('Cashfree order creation failed - missing payment_session_id', { 
        requestId, 
        response: cashfreeResponse.data,
        responseKeys: Object.keys(cashfreeResponse.data || {}),
        responseStatus: cashfreeResponse.status,
        responseHeaders: cashfreeResponse.headers
      });
      return res.status(500).json({ 
        success: false, 
        message: 'Failed to create payment order - invalid response from payment gateway' 
      });
    }

    logPayment('Updating booking in Firestore', {
      requestId,
      bookingId,
      orderId,
      paymentSessionId: payment_session_id.substring(0, 20) + '...',
      paymentStatus: 'pending'
    });

    try {
      // Update the primary booking
      await db.collection('bookings').doc(bookingId).update({
        paymentTransactionId: orderId,
        paymentSessionId: payment_session_id,
        paymentStatus: 'pending',
        updatedAt: new Date(),
      });
      
      // If this is a group booking, update all bookings in the group
      const bookingData = bookingDoc.data();
      if (bookingData.groupBookingId) {
        logPayment('Group booking detected - updating all bookings in group', {
          requestId,
          groupBookingId: bookingData.groupBookingId,
          bookingId
        });
        
        const groupBookingsQuery = await db.collection('bookings')
          .where('groupBookingId', '==', bookingData.groupBookingId)
          .get();
        
        logPayment('Found bookings in group', {
          requestId,
          groupBookingId: bookingData.groupBookingId,
          count: groupBookingsQuery.docs.length
        });
        
        // Update all bookings in the group with payment transaction info
        const updatePromises = groupBookingsQuery.docs.map(doc => 
          doc.ref.update({
            paymentTransactionId: orderId,
            paymentSessionId: payment_session_id,
            paymentStatus: 'pending',
            updatedAt: new Date(),
          })
        );
        
        await Promise.all(updatePromises);
        logPayment('✅ All bookings in group updated in Firestore', { 
          requestId, 
          groupBookingId: bookingData.groupBookingId,
          updatedCount: groupBookingsQuery.docs.length
        });
      } else {
        logPayment('✅ Booking updated in Firestore (single booking)', { requestId, bookingId });
      }
    } catch (dbError) {
      logPaymentError('Failed to update booking in Firestore', {
        requestId,
        bookingId,
        error: dbError.message,
        stack: dbError.stack
      });
    }

    logPayment('✅ CASHFREE ORDER CREATED', {
      requestId,
      orderId,
      paymentSessionId: payment_session_id.substring(0, 20) + '...',
      paymentSessionIdLength: payment_session_id.length,
      bookingId,
      amount: formattedAmount,
      currency: 'INR'
    });

    const responsePayload = {
      success: true,
      payment_session_id: payment_session_id,
      order_id: orderId,
      order_amount: formattedAmount,
      order_currency: 'INR',
      bookingId: bookingId,
      message: 'Payment order created successfully',
    };

    logPayment('Sending response to frontend (SDK format)', {
      requestId,
      responseSuccess: responsePayload.success,
      orderId: responsePayload.order_id,
      paymentSessionId: responsePayload.payment_session_id ? `${responsePayload.payment_session_id.substring(0, 20)}...` : 'MISSING',
      paymentSessionIdLength: responsePayload.payment_session_id?.length || 0
    });

    res.json(responsePayload);

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

const verifyPayment = async (req, res) => {
  const requestId = `CALLBACK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const callbackStartTime = Date.now();
  try {
    logPayment('=== CASHFREE PAYMENT CALLBACK ===', { requestId });
    logPayment('Callback received at', new Date().toISOString());
    logPayment('Request Method', req.method);
    logPayment('Request URL', req.originalUrl || req.url);
    logPayment('Full URL', `${req.protocol}://${req.get('host')}${req.originalUrl}`);
    logPayment('Request Headers', {
      'content-type': req.headers['content-type'],
      'user-agent': req.headers['user-agent'],
      'origin': req.headers['origin'],
      'referer': req.headers['referer'],
      'accept': req.headers['accept']
    });
    logPayment('Request Query Params', req.query);
    logPayment('Query Params Count', Object.keys(req.query || {}).length);
    logPayment('Request IP', req.ip || req.connection.remoteAddress);
    
    const { order_id, order_token, payment_id, payment_status } = req.query;
    
    logPayment('Extracted Callback Data', {
      requestId,
      order_id: order_id || 'MISSING',
      order_token: order_token ? `${order_token.substring(0, 20)}...` : 'MISSING',
      payment_id: payment_id || 'MISSING',
      payment_status: payment_status || 'MISSING',
      allQueryKeys: Object.keys(req.query || {})
    });

    if (!order_id) {
      logPaymentError('Missing order_id in callback', { requestId });
      return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&reason=invalid_callback`);
    }

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

    try {
      const verifyApiStartTime = Date.now();
      logPayment('Calling Cashfree payment verification API', {
        requestId,
        order_id,
        apiUrl: `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`,
        method: 'GET'
      });

      const paymentResponse = await axios.get(
        `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`,
        {
          headers: getCashfreeAuthHeaders(),
        }
      );

      const verifyApiDuration = Date.now() - verifyApiStartTime;
      logPayment('Cashfree verification API response received', {
        requestId,
        order_id,
        apiDuration: `${verifyApiDuration}ms`,
        responseStatus: paymentResponse.status,
        responseStatusText: paymentResponse.statusText,
        hasData: !!paymentResponse.data,
        dataType: Array.isArray(paymentResponse.data) ? 'array' : typeof paymentResponse.data,
        dataLength: Array.isArray(paymentResponse.data) ? paymentResponse.data.length : 'N/A'
      });

      const payments = paymentResponse.data;
      logPayment('Processing payment data', {
        requestId,
        order_id,
        paymentsCount: Array.isArray(payments) ? payments.length : 0,
        paymentsData: payments
      });

      const latestPayment = payments && payments.length > 0 ? payments[0] : null;

      logPayment('Latest payment extracted', {
        requestId,
        order_id,
        hasLatestPayment: !!latestPayment,
        paymentStatus: latestPayment?.payment_status || 'N/A',
        paymentId: latestPayment?.payment_id || 'N/A',
        paymentAmount: latestPayment?.payment_amount || 'N/A',
        paymentMessage: latestPayment?.payment_message || 'N/A',
        fullPaymentData: latestPayment
      });

      if (!latestPayment || latestPayment.payment_status !== 'SUCCESS') {
        const paymentMessage = latestPayment?.payment_message || 'Payment failed';
        logPayment('Payment status is not SUCCESS', {
          requestId,
          bookingId,
          orderId: order_id,
          paymentStatus: latestPayment?.payment_status || 'NO_PAYMENT',
          paymentMessage,
          willUpdateBookingToFailed: true
        });

        const failUpdateData = {
          paymentStatus: 'failed',
          paymentError: paymentMessage,
          updatedAt: new Date(),
        };
        
        // Update the primary booking
        await db.collection('bookings').doc(bookingId).update(failUpdateData);
        
        // If this is a group booking, update all bookings in the group
        if (bookingData.groupBookingId) {
          logPayment('Group booking detected - updating all bookings in group (payment failed)', {
            requestId,
            groupBookingId: bookingData.groupBookingId,
            bookingId
          });
          
          const groupBookingsQuery = await db.collection('bookings')
            .where('groupBookingId', '==', bookingData.groupBookingId)
            .get();
          
          const groupUpdatePromises = groupBookingsQuery.docs.map(doc => 
            doc.ref.update(failUpdateData)
          );
          
          await Promise.all(groupUpdatePromises);
          logPayment('❌ All bookings in group updated to failed', { 
            requestId, 
            groupBookingId: bookingData.groupBookingId,
            updatedCount: groupBookingsQuery.docs.length
          });
        }
        
        logPayment('❌ Payment failed - Booking updated', {
          requestId,
          bookingId,
          orderId: order_id,
          paymentStatus: latestPayment?.payment_status,
          paymentMessage,
          bookingUpdated: true,
          isGroupBooking: !!bookingData.groupBookingId
        });
        
        return res.redirect(`${FRONTEND_URL}/payment-result?status=failure&bookingId=${bookingId}`);
      }

      logPayment('Payment is SUCCESS - Updating booking', {
        requestId,
        bookingId,
        orderId: order_id,
        paymentId: latestPayment.payment_id,
        paymentAmount: latestPayment.payment_amount,
        willUpdateBookingToPaid: true
      });

      const paymentId = latestPayment.payment_id || latestPayment.cf_payment_id;
      
      logPayment('DEBUG - Payment ID extraction', {
        requestId,
        orderId: order_id,
        payment_id_field: latestPayment.payment_id,
        cf_payment_id_field: latestPayment.cf_payment_id,
        extractedPaymentId: paymentId,
        paymentIdType: typeof paymentId,
        paymentIdIsUndefined: paymentId === undefined,
        paymentIdIsNull: paymentId === null,
        allPaymentKeys: Object.keys(latestPayment)
      });
      
      const updateData = {
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      };
      
      if (paymentId !== undefined && paymentId !== null) {
        updateData.paymentId = String(paymentId);
        logPayment('DEBUG - Adding paymentId to updateData', {
          requestId,
          paymentId: updateData.paymentId,
          paymentIdLength: updateData.paymentId.length
        });
      } else {
        logPayment('DEBUG - Skipping paymentId (undefined/null)', {
          requestId,
          orderId: order_id,
          paymentIdValue: paymentId
        });
      }
      
      logPayment('DEBUG - Final updateData before Firestore', {
        requestId,
        updateData: updateData,
        updateDataKeys: Object.keys(updateData),
        hasPaymentId: 'paymentId' in updateData
      });
      
      // Update the primary booking
      await db.collection('bookings').doc(bookingId).update(updateData);
      
      // If this is a group booking, update all bookings in the group
      if (bookingData.groupBookingId) {
        logPayment('Group booking detected - updating all bookings in group', {
          requestId,
          groupBookingId: bookingData.groupBookingId,
          bookingId
        });
        
        const groupBookingsQuery = await db.collection('bookings')
          .where('groupBookingId', '==', bookingData.groupBookingId)
          .get();
        
        logPayment('Found bookings in group', {
          requestId,
          groupBookingId: bookingData.groupBookingId,
          count: groupBookingsQuery.docs.length
        });
        
        // Update all bookings in the group with payment status
        const groupUpdatePromises = groupBookingsQuery.docs.map(doc => 
          doc.ref.update(updateData)
        );
        
        await Promise.all(groupUpdatePromises);
        logPayment('✅ All bookings in group updated to confirmed', { 
          requestId, 
          groupBookingId: bookingData.groupBookingId,
          updatedCount: groupBookingsQuery.docs.length
        });
      }

      logPayment('✅ PAYMENT VERIFIED & BOOKING CONFIRMED', {
        requestId,
        bookingId,
        orderId: order_id,
        paymentId: paymentId || 'N/A',
        amount: latestPayment.payment_amount,
        bookingUpdated: true,
        bookingStatus: 'confirmed',
        paymentStatus: 'paid',
        isGroupBooking: !!bookingData.groupBookingId
      });

      const callbackDuration = Date.now() - callbackStartTime;
      logPayment('Callback processing complete', {
        requestId,
        totalDuration: `${callbackDuration}ms`,
        redirectingTo: `${FRONTEND_URL}/payment-result?status=success&bookingId=${bookingId}`
      });

      return res.redirect(`${FRONTEND_URL}/payment-result?status=success&bookingId=${bookingId}`);

    } catch (apiError) {
      logPaymentError('Error verifying payment with Cashfree API', {
        requestId,
        error: apiError.message,
        errorCode: apiError.code,
        errorStatus: apiError.response?.status,
        errorStatusText: apiError.response?.statusText,
        errorResponseData: apiError.response?.data,
        errorStack: apiError.stack,
        orderId: order_id,
        apiUrl: `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`
      });
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

    try {
      const verifyApiUrl = `${CASHFREE_BASE_URL}/pg/orders/${order_id}/payments`;
      logPayment('Calling Cashfree verification API', {
        requestId,
        orderId: order_id,
        apiUrl: verifyApiUrl,
        cashfreeBaseUrl: CASHFREE_BASE_URL,
        hasClientId: !!CASHFREE_CLIENT_ID,
        hasClientSecret: !!CASHFREE_CLIENT_SECRET,
      });

      const paymentResponse = await axios.get(
        verifyApiUrl,
        {
          headers: getCashfreeAuthHeaders(),
        }
      );

      logPayment('Cashfree API response received', {
        requestId,
        orderId: order_id,
        responseStatus: paymentResponse.status,
        hasData: !!paymentResponse.data,
        dataType: Array.isArray(paymentResponse.data) ? 'array' : typeof paymentResponse.data,
        dataLength: Array.isArray(paymentResponse.data) ? paymentResponse.data.length : 'N/A',
        fullResponseData: paymentResponse.data
      });

      const payments = paymentResponse.data;
      const latestPayment = payments && payments.length > 0 ? payments[0] : null;

      logPayment('Latest payment extracted', {
        requestId,
        orderId: order_id,
        hasLatestPayment: !!latestPayment,
        paymentStatus: latestPayment?.payment_status || 'N/A',
        paymentId: latestPayment?.payment_id || 'N/A',
        paymentMessage: latestPayment?.payment_message || 'N/A',
        fullLatestPayment: latestPayment
      });

      if (!latestPayment || latestPayment.payment_status !== 'SUCCESS') {
        const paymentMessage = latestPayment?.payment_message || 'Payment failed or pending';
        const paymentStatus = latestPayment?.payment_status || 'NO_PAYMENT';
        
        logPayment('❌ Payment verification failed', {
          requestId,
          bookingId,
          orderId: order_id,
          paymentStatus,
          paymentMessage,
          willUpdateBookingToFailed: true,
        });
        
        const failUpdateData = {
          paymentStatus: 'failed',
          paymentError: paymentMessage,
          updatedAt: new Date(),
        };
        
        // Update the primary booking
        await db.collection('bookings').doc(bookingId).update(failUpdateData);
        
        // If this is a group booking, update all bookings in the group
        if (bookingData.groupBookingId) {
          logPayment('Group booking detected - updating all bookings in group (payment failed POST)', {
            requestId,
            groupBookingId: bookingData.groupBookingId,
            bookingId
          });
          
          const groupBookingsQuery = await db.collection('bookings')
            .where('groupBookingId', '==', bookingData.groupBookingId)
            .get();
          
          const groupUpdatePromises = groupBookingsQuery.docs.map(doc => 
            doc.ref.update(failUpdateData)
          );
          
          await Promise.all(groupUpdatePromises);
        }
        
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

      const paymentId = latestPayment.payment_id || latestPayment.cf_payment_id;
      
      logPayment('DEBUG - Payment ID extraction in POST verify', {
        requestId,
        orderId: order_id,
        payment_id_field: latestPayment.payment_id,
        cf_payment_id_field: latestPayment.cf_payment_id,
        extractedPaymentId: paymentId,
        paymentIdType: typeof paymentId,
        paymentIdIsUndefined: paymentId === undefined,
        paymentIdIsNull: paymentId === null,
        allPaymentKeys: Object.keys(latestPayment),
        fullPaymentObject: latestPayment
      });
      
      const updateData = {
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      };
      
      if (paymentId !== undefined && paymentId !== null) {
        updateData.paymentId = String(paymentId);
        logPayment('DEBUG - Adding paymentId to updateData', {
          requestId,
          paymentId: updateData.paymentId,
          paymentIdLength: updateData.paymentId.length
        });
      } else {
        logPayment('DEBUG - Skipping paymentId (undefined/null)', {
          requestId,
          orderId: order_id,
          paymentIdValue: paymentId,
          reason: 'paymentId is undefined or null'
        });
      }
      
      logPayment('DEBUG - Final updateData before Firestore (POST verify)', {
        requestId,
        updateData: updateData,
        updateDataKeys: Object.keys(updateData),
        hasPaymentId: 'paymentId' in updateData,
        updateDataStringified: JSON.stringify(updateData)
      });
      
      try {
        // Update the primary booking
        await db.collection('bookings').doc(bookingId).update(updateData);
        
        // If this is a group booking, update all bookings in the group
        if (bookingData.groupBookingId) {
          logPayment('Group booking detected - updating all bookings in group (POST verify)', {
            requestId,
            groupBookingId: bookingData.groupBookingId,
            bookingId
          });
          
          const groupBookingsQuery = await db.collection('bookings')
            .where('groupBookingId', '==', bookingData.groupBookingId)
            .get();
          
          logPayment('Found bookings in group (POST verify)', {
            requestId,
            groupBookingId: bookingData.groupBookingId,
            count: groupBookingsQuery.docs.length
          });
          
          // Update all bookings in the group with payment status
          const groupUpdatePromises = groupBookingsQuery.docs.map(doc => 
            doc.ref.update(updateData)
          );
          
          await Promise.all(groupUpdatePromises);
          logPayment('✅ All bookings in group updated to confirmed (POST verify)', { 
            requestId, 
            groupBookingId: bookingData.groupBookingId,
            updatedCount: groupBookingsQuery.docs.length
          });
        }
        
        logPayment('✅ Firestore update successful', {
          requestId,
          bookingId,
          updateData,
          isGroupBooking: !!bookingData.groupBookingId
        });
      } catch (firestoreError) {
        logPaymentError('❌ Firestore update failed', {
          requestId,
          bookingId,
          error: firestoreError.message,
          errorCode: firestoreError.code,
          errorStack: firestoreError.stack,
          updateDataAttempted: updateData
        });
        throw firestoreError;
      }

      logPayment('✅ PAYMENT VERIFIED & BOOKING CONFIRMED', {
        requestId,
        bookingId,
        orderId: order_id,
        paymentId: paymentId || 'N/A',
        amount: latestPayment.payment_amount,
      });

      return res.json({
        success: true,
        message: 'Payment verified successfully',
        data: {
          bookingId,
          paymentStatus: 'paid',
          orderId: order_id,
          paymentId: paymentId || null,
        }
      });

    } catch (apiError) {
      const errorDetails = {
        requestId,
        orderId: order_id,
        bookingId,
        errorMessage: apiError.message,
        errorType: apiError.constructor.name,
      };

      if (apiError.response) {
        errorDetails.responseStatus = apiError.response.status;
        errorDetails.responseStatusText = apiError.response.statusText;
        errorDetails.responseData = apiError.response.data;
        errorDetails.responseHeaders = apiError.response.headers;
      }

      if (apiError.request) {
        errorDetails.requestUrl = apiError.config?.url;
        errorDetails.requestMethod = apiError.config?.method;
      }

      logPaymentError('❌ Error verifying payment with Cashfree API', errorDetails);
      
      return res.status(500).json({
        success: false,
        message: `Error verifying payment: ${apiError.message}`,
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
      data: {
        bookingId: req.body?.order_id ? 'unknown' : undefined,
        paymentStatus: 'pending'
      }
    });
  }
};

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
    
    const signature = req.headers['x-webhook-signature'] || req.headers['x-cashfree-signature'];
    const timestamp = req.headers['x-webhook-timestamp'];
    const rawBody = JSON.stringify(req.body);

    if (CASHFREE_CLIENT_SECRET && signature) {
      try {
        const message = timestamp ? `${timestamp}${rawBody}` : rawBody;
        
        const hmac = crypto.createHmac('sha256', CASHFREE_CLIENT_SECRET);
        hmac.update(message);
        const expectedSignature = hmac.digest('base64');
        
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
        logPayment('⚠️ Continuing webhook processing despite signature error', { requestId });
      }
    } else {
      logPayment('⚠️ Webhook signature verification skipped (Client Secret not configured)', { requestId });
    }

    // Handle test webhooks from Cashfree dashboard
    // Test webhooks may have different payload format
    const isTestWebhook = req.body.type === 'TEST_WEBHOOK' || 
                         req.body.test === true || 
                         req.headers['x-cashfree-test'] === 'true' ||
                         (req.body.data && !req.body.data.order && !req.body.data.payment);
    
    if (isTestWebhook) {
      logPayment('Test webhook received - responding with success', { requestId });
      return res.status(200).json({ 
        success: true, 
        message: 'Webhook endpoint is working',
        test: true
      });
    }

    const { data } = req.body;
    const { order, payment } = data || {};

    if (!order || !payment) {
      logPaymentError('Invalid webhook data', { requestId, body: req.body });
      // Return 200 for invalid data to prevent Cashfree from retrying
      // But log the error for debugging
      return res.status(200).json({ 
        success: false, 
        message: 'Invalid webhook data - missing order or payment',
        received: Object.keys(req.body)
      });
    }

    const orderId = order.order_id;
    const paymentStatus = payment.payment_status;
    const paymentId = payment.payment_id || payment.cf_payment_id;

    logPayment('Webhook data extracted', {
      requestId,
      orderId,
      paymentId: paymentId || 'N/A',
      paymentStatus,
      paymentAmount: payment.payment_amount,
      paymentMessage: payment.payment_message,
    });

    const bookingsQuery = await db.collection('bookings')
      .where('paymentTransactionId', '==', orderId)
      .limit(1)
      .get();

    if (bookingsQuery.empty) {
      logPaymentError('Booking not found for webhook', { orderId, requestId });
      // Return 200 to prevent Cashfree from retrying for non-existent bookings
      // This can happen if webhook is sent before booking is created or for test orders
      return res.status(200).json({ 
        success: false, 
        message: 'Booking not found for this order',
        orderId: orderId
      });
    }

    const bookingId = bookingsQuery.docs[0].id;
    const bookingData = bookingsQuery.docs[0].data();

    if (paymentStatus === 'SUCCESS') {
      const updateData = {
        paymentStatus: 'paid',
        status: 'confirmed',
        paidAt: new Date(),
        updatedAt: new Date(),
      };
      
      if (paymentId !== undefined && paymentId !== null) {
        updateData.paymentId = String(paymentId);
      }
      
      // Update the primary booking
      await db.collection('bookings').doc(bookingId).update(updateData);
      
      // If this is a group booking, update all bookings in the group
      if (bookingData.groupBookingId) {
        logPayment('Group booking detected - updating all bookings in group (webhook)', {
          requestId,
          groupBookingId: bookingData.groupBookingId,
          bookingId
        });
        
        const groupBookingsQuery = await db.collection('bookings')
          .where('groupBookingId', '==', bookingData.groupBookingId)
          .get();
        
        logPayment('Found bookings in group (webhook)', {
          requestId,
          groupBookingId: bookingData.groupBookingId,
          count: groupBookingsQuery.docs.length
        });
        
        // Update all bookings in the group with payment status
        const groupUpdatePromises = groupBookingsQuery.docs.map(doc => 
          doc.ref.update(updateData)
        );
        
        await Promise.all(groupUpdatePromises);
        logPayment('✅ All bookings in group updated to confirmed (webhook)', { 
          requestId, 
          groupBookingId: bookingData.groupBookingId,
          updatedCount: groupBookingsQuery.docs.length
        });
      }
      
      logPayment('✅ Booking updated to paid status via webhook', {
        requestId,
        bookingId,
        orderId,
        paymentId: paymentId || 'N/A',
        isGroupBooking: !!bookingData.groupBookingId
      });
    } else if (paymentStatus === 'FAILED' || paymentStatus === 'USER_DROPPED') {
      const failUpdateData = {
        paymentStatus: 'failed',
        paymentError: payment.payment_message || 'Payment failed',
        updatedAt: new Date(),
      };
      
      // Update the primary booking
      await db.collection('bookings').doc(bookingId).update(failUpdateData);
      
      // If this is a group booking, update all bookings in the group
      if (bookingData.groupBookingId) {
        const groupBookingsQuery = await db.collection('bookings')
          .where('groupBookingId', '==', bookingData.groupBookingId)
          .get();
        
        const groupUpdatePromises = groupBookingsQuery.docs.map(doc => 
          doc.ref.update(failUpdateData)
        );
        
        await Promise.all(groupUpdatePromises);
      }
      
      logPayment('❌ Booking updated to failed status via webhook', {
        requestId,
        bookingId,
        orderId,
        paymentStatus,
        isGroupBooking: !!bookingData.groupBookingId
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