const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { 
  createPayment, 
  verifyPayment, 
  handlePaymentFailure, 
  handlePaymentCancel 
} = require('../controllers/paymentController');
const { initiateRefund, getRefundStatus } = require('../controllers/refundController');

// Payment routes
router.post('/create-payment', protect, createPayment);
router.post('/success', verifyPayment); // PayU success callback (no auth needed)
router.post('/failure', handlePaymentFailure); // PayU failure callback
router.post('/cancel', handlePaymentCancel); // PayU cancel callback
router.post('/:bookingId/refund', protect, initiateRefund);
router.get('/:bookingId/refund-status', protect, getRefundStatus);

module.exports = router;

