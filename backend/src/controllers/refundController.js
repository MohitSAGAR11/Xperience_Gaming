const crypto = require('crypto');
const axios = require('axios');
const { db } = require('../config/firebase');

const PAYU_MERCHANT_KEY = process.env.PAYU_MERCHANT_KEY;
const PAYU_MERCHANT_SALT = process.env.PAYU_MERCHANT_SALT;
const PAYU_BASE_URL = process.env.PAYU_BASE_URL || 'https://test.payu.in';

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

// Generate PayU refund hash
function generateRefundHash(paymentId, amount) {
  const hashString = `${PAYU_MERCHANT_KEY}|${paymentId}|${amount}|${PAYU_MERCHANT_SALT}`;
  const hash = crypto.createHash('sha512').update(hashString).digest('hex');
  logRefund('Refund hash generated', {
    hashString: hashString.replace(PAYU_MERCHANT_SALT, '[SALT_HIDDEN]'),
    hashLength: hash.length,
    hashPrefix: hash.substring(0, 20) + '...'
  });
  return hash;
}

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
    
    // Generate refund hash
    logRefund('Generating refund hash', {
      paymentId: booking.paymentId,
      refundAmount
    });
    const refundHash = generateRefundHash(booking.paymentId, refundAmount);
    
    // Initiate refund via PayU API
    const refundData = {
      key: PAYU_MERCHANT_KEY,
      command: 'cancel_refund_transaction',
      var1: booking.paymentId, // Payment ID
      var2: refundAmount.toString(), // Refund amount
      hash: refundHash
    };
    
    logRefund('Calling PayU refund API', {
      url: `${PAYU_BASE_URL}/merchant/postservice?form=2`,
      paymentId: booking.paymentId,
      refundAmount: refundAmount.toString()
    });
    
    // Call PayU refund API
    const refundResponse = await axios.post(
      `${PAYU_BASE_URL}/merchant/postservice?form=2`,
      new URLSearchParams(refundData).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );
    
    logRefund('PayU refund API response received', {
      status: refundResponse.status,
      statusText: refundResponse.statusText,
      data: refundResponse.data
    });
    
    // Parse PayU response
    const refundResult = refundResponse.data;
    
    if (refundResult.status === 'success' || refundResult.status === 1 || refundResult.status === 'SUCCESS') {
      logRefund('Refund successful - updating booking', {
        refundId: refundResult.refundId,
        refundAmount
      });

      // Update booking
      await db.collection('bookings').doc(bookingId).update({
        refundId: refundResult.refundId || `REF_${Date.now()}`,
        refundAmount: refundAmount,
        refundStatus: 'processed',
        paymentStatus: 'refunded',
        refundReason: reason || 'Booking cancelled',
        refundedAt: new Date(),
        updatedAt: new Date()
      });
      
      logRefund('=== REFUND PROCESSED SUCCESSFULLY ===', {
        bookingId,
        refundId: refundResult.refundId,
        refundAmount
      });
      
      res.json({
        success: true,
        message: 'Refund initiated successfully',
        data: {
          refundId: refundResult.refundId,
          refundAmount: refundAmount,
          refundStatus: 'processed'
        }
      });
    } else {
      logRefundError('Refund failed from PayU', {
        bookingId,
        refundResult,
        status: refundResult.status,
        message: refundResult.message
      });

      // Refund failed
      await db.collection('bookings').doc(bookingId).update({
        refundStatus: 'failed',
        updatedAt: new Date()
      });
      
      res.status(400).json({
        success: false,
        message: refundResult.message || 'Refund failed',
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

