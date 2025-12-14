const express = require('express');
const { body } = require('express-validator');
const {
  createProfile,
  logout,
  getMe,
  updateProfile,
  changePassword,
  registerFcmToken,
  googleSignIn
} = require('../controllers/authController');
const { protect, protectNewUser } = require('../middleware/authMiddleware');

const router = express.Router();

// Validation rules
const createProfileValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ min: 2, max: 100 }).withMessage('Name must be between 2 and 100 characters'),
  body('role')
    .optional()
    .isIn(['client', 'owner']).withMessage('Role must be either client or owner'),
  body('phone')
    .optional()
    .trim()
];

const changePasswordValidation = [
  body('newPassword')
    .notEmpty().withMessage('New password is required')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters')
];

// Protected routes
// Note: Authentication (register/login) is handled by Firebase Auth on frontend
// This endpoint creates the user profile in Firestore after Firebase Auth registration
// Uses protectNewUser since the user doesn't exist in Firestore yet
router.post('/create-profile', protectNewUser, createProfileValidation, createProfile);

// Google Sign-In - handles both new and existing users
// Uses protectNewUser because new users won't exist in Firestore yet
router.post('/google-signin', protectNewUser, googleSignIn);

router.get('/me', protect, getMe);
router.post('/logout', protect, logout);
router.put('/profile', protect, updateProfile);
router.put('/password', protect, changePasswordValidation, changePassword);

// FCM Token for push notifications
router.post('/register-fcm-token', protect, registerFcmToken);

module.exports = router;

