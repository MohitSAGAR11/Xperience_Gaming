const axios = require('axios');
const { db } = require('../config/firebase');

// Cashfree Configuration
const CASHFREE_CLIENT_ID = process.env.CASHFREE_CLIENT_ID;
const CASHFREE_CLIENT_SECRET = process.env.CASHFREE_CLIENT_SECRET;
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || '2023-08-01';
const CASHFREE_BASE_URL = process.env.CASHFREE_BASE_URL || 'https://api.cashfree.com';

// Cashfree Auth Headers
function getCashfreeAuthHeaders() {
  return {
    'x-client-id': CASHFREE_CLIENT_ID,
    'x-client-secret': CASHFREE_CLIENT_SECRET,
    'x-api-version': CASHFREE_API_VERSION,
    'Content-Type': 'application/json',
  };
}

// Logging helper
const logRefund = (message, data = null) => {
  console.log(`💰 [REFUND] ${message}`);
  if (data) {
    console.log(`💰 [REFUND] Data:`, JSON.stringify(data, null, 2));
  }
};

const logRefundError = (message, error = null) => {
  console.error(`💰 [REFUND_ERROR] ${message}`);
  if (error) {
    console.error(`💰 [REFUND_ERROR] Details:`, error);
    if (error.stack) {
      console.error(`💰 [REFUND_ERROR] Stack:`, error.stack);
    }
  }
};


/**
 * Calculate refund amount based on cancellation policy
 * Full refund if cancelled before 1 hour of booking slot, otherwise no refund
 */
function calculateRefundAmount(booking) {
  const bookingDateTime = new Date(`${booking.bookingDate}T${booking.startTime}`);
  const now = new Date();
  const hoursUntilBooking = (bookingDateTime - now) / (1000 * 60 * 60);
  
  logRefund('Calculating refund amount', {
    bookingDate: booking.bookingDate,
    startTime: booking.startTime,
    bookingDateTime: bookingDateTime.toISOString(),
    currentTime: now.toISOString(),
    hoursUntilBooking: hoursUntilBooking.toFixed(2),
    totalAmount: booking.totalAmount
  });
  
  // Full refund if cancelled 1+ hours before booking start time
  if (hoursUntilBooking >= 1) {
    logRefund('Full refund eligible', { refundAmount: booking.totalAmount });
    return booking.totalAmount;
  }
  
  // No refund if cancelled less than 1 hour before booking
  logRefund('No refund eligible - within 1 hour', { hoursUntilBooking: hoursUntilBooking.toFixed(2) });
  return 0;
}

/**
 * @desc    Initiate refund
 * @route   POST /api/payments/:bookingId/refund
 * @access  Private
 */
const initiateRefund = async (req, res) => {
  try {
    logRefund('=== INITIATE REFUND REQUEST ===');
    logRefund('Refund request received', {
      bookingId: req.params.bookingId,
      reason: req.body.reason,
      amount: req.body.amount,
      userId: req.user?.id
    });

    const { bookingId } = req.params;
    const { reason, amount } = req.body;
    
    // Get booking
    logRefund('Fetching booking from database', { bookingId });
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      logRefundError('Booking not found', { bookingId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    const booking = bookingDoc.data();
    logRefund('Booking found', {
      bookingId,
      paymentStatus: booking.paymentStatus,
      paymentId: booking.paymentId,
      totalAmount: booking.totalAmount
    });
    
    // Check if payment was made
    if (booking.paymentStatus !== 'paid' || !booking.paymentId) {
      logRefundError('No payment found to refund', {
        bookingId,
        paymentStatus: booking.paymentStatus,
        hasPaymentId: !!booking.paymentId
      });
      return res.status(400).json({ 
        success: false, 
        message: 'No payment found to refund' 
      });
    }
    
    // Calculate refund amount based on cancellation policy
    logRefund('Calculating refund amount');
    const refundAmount = amount !== undefined ? amount : calculateRefundAmount(booking);
    logRefund('Refund amount calculated', { refundAmount });
    
    if (refundAmount === 0) {
      logRefund('No refund eligible - updating booking status');
      // No refund eligible - update booking status but don't process refund
      await db.collection('bookings').doc(bookingId).update({
        refundStatus: 'not_eligible',
        refundAmount: 0,
        refundReason: reason || 'Cancelled within 1 hour of booking - no refund eligible',
        updatedAt: new Date()
      });
      
      logRefund('=== REFUND NOT ELIGIBLE ===', {
        bookingId,
        reason: 'Cancellation within 1 hour'
      });
      
      return res.json({
        success: true,
        message: 'Booking cancelled. No refund eligible as cancellation is within 1 hour of booking.',
        data: {
          refundAmount: 0,
          refundStatus: 'not_eligible',
          reason: 'Cancellation within 1 hour - no refund policy'
        }
      });
    }
    
    // Validate Cashfree Configuration
    if (!CASHFREE_CLIENT_ID || !CASHFREE_CLIENT_SECRET) {
      logRefundError('Missing Cashfree credentials', { bookingId });
      return res.status(500).json({ 
        success: false, 
        message: 'Server configuration error - Missing Cashfree credentials' 
      });
    }

    // Get order_id from booking (stored as paymentTransactionId)
    const orderId = booking.paymentTransactionId;
    if (!orderId) {
      logRefundError('Order ID not found in booking', { bookingId });
      return res.status(400).json({ 
        success: false, 
        message: 'Order ID not found' 
      });
    }

    // Create Cashfree refund payload
    const refundPayload = {
      refund_amount: parseFloat(refundAmount.toFixed(2)),
      refund_id: `REF_${bookingId}_${Date.now()}`,
      refund_note: reason || 'Booking cancelled',
      refund_splits: []
    };

    logRefund('Calling Cashfree refund API', {
      url: `${CASHFREE_BASE_URL}/pg/orders/${orderId}/refund`,
      orderId,
      paymentId: booking.paymentId,
      refundAmount: refundPayload.refund_amount,
      refundId: refundPayload.refund_id
    });
    
    // Call Cashfree Refund API
    let refundResponse;
    try {
      refundResponse = await axios.post(
        `${CASHFREE_BASE_URL}/pg/orders/${orderId}/refund`,
        refundPayload,
        {
          headers: getCashfreeAuthHeaders(),
        }
      );
      
      logRefund('Cashfree refund API response received', {
        status: refundResponse.status,
        data: refundResponse.data
      });
    } catch (apiError) {
      logRefundError('Cashfree refund API call failed', {
        bookingId,
        orderId,
        error: apiError.message,
        response: apiError.response?.data,
        status: apiError.response?.status
      });
      
      const errorMessage = apiError.response?.data?.message || 
                          apiError.response?.data?.error?.message ||
                          'Failed to process refund with Cashfree';
      
      await db.collection('bookings').doc(bookingId).update({
        refundStatus: 'failed',
        updatedAt: new Date()
      });
      
      return res.status(apiError.response?.status || 500).json({
        success: false,
        message: errorMessage,
        data: apiError.response?.data
      });
    }
    
    const refundResult = refundResponse.data;
    
    // Check if refund was successful
    if (refundResult.refund_status === 'SUCCESS' || refundResult.refund_status === 'PENDING') {
      logRefund('Refund initiated successfully - updating booking', {
        refundId: refundResult.refund_id,
        refundStatus: refundResult.refund_status,
        refundAmount
      });

      // Update booking
      await db.collection('bookings').doc(bookingId).update({
        refundId: refundResult.refund_id || refundPayload.refund_id,
        refundAmount: refundAmount,
        refundStatus: refundResult.refund_status === 'SUCCESS' ? 'processed' : 'pending',
        paymentStatus: refundResult.refund_status === 'SUCCESS' ? 'refunded' : booking.paymentStatus,
        refundReason: reason || 'Booking cancelled',
        refundedAt: new Date(),
        updatedAt: new Date()
      });
      
      logRefund('=== REFUND PROCESSED SUCCESSFULLY ===', {
        bookingId,
        refundId: refundResult.refund_id,
        refundAmount,
        refundStatus: refundResult.refund_status
      });
      
      res.json({
        success: true,
        message: 'Refund initiated successfully',
        data: {
          refundId: refundResult.refund_id || refundPayload.refund_id,
          refundAmount: refundAmount,
          refundStatus: refundResult.refund_status === 'SUCCESS' ? 'processed' : 'pending'
        }
      });
    } else {
      logRefundError('Refund failed from Cashfree', {
        bookingId,
        refundResult,
        refundStatus: refundResult.refund_status,
        message: refundResult.message || refundResult.error_message
      });

      // Refund failed
      await db.collection('bookings').doc(bookingId).update({
        refundStatus: 'failed',
        updatedAt: new Date()
      });
      
      res.status(400).json({
        success: false,
        message: refundResult.message || refundResult.error_message || 'Refund failed',
        data: refundResult
      });
    }
  } catch (error) {
    logRefundError('Refund exception', error);
    res.status(500).json({ 
      success: false, 
      message: 'Refund failed', 
      error: error.message 
    });
  }
};

/**
 * @desc    Get refund status
 * @route   GET /api/payments/:bookingId/refund-status
 * @access  Private
 */
const getRefundStatus = async (req, res) => {
  try {
    logRefund('=== GET REFUND STATUS ===');
    logRefund('Request received', { bookingId: req.params.bookingId });

    const { bookingId } = req.params;
    
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      logRefundError('Booking not found', { bookingId });
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    
    const booking = bookingDoc.data();
    
    logRefund('Refund status retrieved', {
      bookingId,
      refundStatus: booking.refundStatus,
      refundId: booking.refundId,
      refundAmount: booking.refundAmount
    });
    
    res.json({
      success: true,
      data: {
        refundStatus: booking.refundStatus || null,
        refundId: booking.refundId || null,
        refundAmount: booking.refundAmount || 0,
        refundReason: booking.refundReason || null,
        refundedAt: booking.refundedAt || null
      }
    });
  } catch (error) {
    logRefundError('Get refund status error', error);
    res.status(500).json({ success: false, message: 'Failed to get refund status' });
  }
};

module.exports = {
  initiateRefund,
  getRefundStatus,
  calculateRefundAmount
};

