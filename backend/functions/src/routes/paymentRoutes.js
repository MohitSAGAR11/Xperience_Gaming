const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { 
  createPayment, 
  verifyPayment, 
  verifyPaymentPost,
  handleWebhook
} = require('../controllers/paymentController');
const { initiateRefund, getRefundStatus } = require('../controllers/refundController');

// Payment routes
router.post('/create-payment', protect, createPayment);
router.get('/callback', verifyPayment); // Cashfree callback (GET request with query params)
router.post('/verify', protect, verifyPaymentPost); // Client-side payment verification (POST)
router.post('/webhook', handleWebhook); // Cashfree webhook (POST request with signature)

// Refund routes
router.post('/:bookingId/refund', protect, initiateRefund);
router.get('/:bookingId/refund-status', protect, getRefundStatus);

module.exports = router;

