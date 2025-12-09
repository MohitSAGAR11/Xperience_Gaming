const express = require('express');
const router = express.Router();
const { body, param, query } = require('express-validator');
const { protect, ownerOnly, clientOnly } = require('../middleware/authMiddleware');
const {
  createReview,
  getCafeReviews,
  updateReview,
  deleteReview,
  getMyReviews,
  checkUserReview,
  respondToReview
} = require('../controllers/reviewController');

// Validation rules
const createReviewValidation = [
  body('cafeId')
    .notEmpty().withMessage('Cafe ID is required')
    .isUUID().withMessage('Invalid cafe ID'),
  body('rating')
    .notEmpty().withMessage('Rating is required')
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
  body('comment')
    .optional()
    .isString()
    .isLength({ max: 1000 }).withMessage('Comment must be less than 1000 characters'),
  body('title')
    .optional()
    .isString()
    .isLength({ max: 100 }).withMessage('Title must be less than 100 characters')
];

const updateReviewValidation = [
  param('id').isUUID().withMessage('Invalid review ID'),
  body('rating')
    .optional()
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
  body('comment')
    .optional()
    .isString()
    .isLength({ max: 1000 }).withMessage('Comment must be less than 1000 characters'),
  body('title')
    .optional()
    .isString()
    .isLength({ max: 100 }).withMessage('Title must be less than 100 characters')
];

const respondValidation = [
  param('id').isUUID().withMessage('Invalid review ID'),
  body('response')
    .notEmpty().withMessage('Response is required')
    .isString()
    .isLength({ max: 500 }).withMessage('Response must be less than 500 characters')
];

// Public routes
router.get('/cafe/:cafeId', getCafeReviews);

// Protected routes (require login)
router.use(protect);

// Get my reviews
router.get('/my-reviews', getMyReviews);

// Check if user has reviewed a cafe
router.get('/check/:cafeId', checkUserReview);

// Create a review (clients only)
router.post('/', clientOnly, createReviewValidation, createReview);

// Update a review (review owner only)
router.put('/:id', updateReviewValidation, updateReview);

// Delete a review (review owner only)
router.delete('/:id', deleteReview);

// Owner responds to a review
router.post('/:id/respond', ownerOnly, respondValidation, respondToReview);

module.exports = router;

