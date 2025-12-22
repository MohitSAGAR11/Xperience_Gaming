const express = require('express');
const { body } = require('express-validator');
const {
  createCafe,
  getAllCafes,
  getNearbyCafes,
  getCafeById,
  updateCafe,
  deleteCafe,
  getMyCafes,
  getCafeAvailability
} = require('../controllers/cafeController');
const { protect, ownerOnly } = require('../middleware/authMiddleware');

const router = express.Router();

// Validation rules for creating/updating cafe
const cafeValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Cafe name is required')
    .isLength({ max: 200 }).withMessage('Name cannot exceed 200 characters'),
  body('address')
    .trim()
    .notEmpty().withMessage('Address is required'),
  body('city')
    .trim()
    .notEmpty().withMessage('City is required'),
  body('mapsLink')
    .trim()
    .notEmpty().withMessage('Google Maps link is required')
    .isURL().withMessage('Please provide a valid URL'),
  body('phoneNumber')
    .trim()
    .notEmpty().withMessage('Cafe phone number is required')
    .matches(/^[\+]?[(]?[0-9]{1,4}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,9}$/)
    .withMessage('Please provide a valid phone number')
    .isLength({ min: 10, max: 15 }).withMessage('Phone number must be between 10 and 15 digits'),
  body('latitude')
    .notEmpty().withMessage('Latitude is required')
    .isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
  body('longitude')
    .notEmpty().withMessage('Longitude is required')
    .isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
  body('hourlyRate')
    .notEmpty().withMessage('Default hourly rate is required')
    .isFloat({ min: 0 }).withMessage('Hourly rate must be a positive number'),
  // PC Station fields
  body('totalPcStations')
    .optional()
    .isInt({ min: 0 }).withMessage('Total PC stations must be 0 or more'),
  body('pcHourlyRate')
    .optional()
    .isFloat({ min: 0 }).withMessage('PC hourly rate must be a positive number'),
  body('pcSpecs')
    .optional()
    .isObject().withMessage('PC specs must be an object'),
  body('pcGames')
    .optional()
    .isArray().withMessage('PC games must be an array'),
  // Time fields
  body('openingTime')
    .optional()
    .matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/)
    .withMessage('Invalid opening time format (HH:MM or HH:MM:SS)'),
  body('closingTime')
    .optional()
    .matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/)
    .withMessage('Invalid closing time format (HH:MM or HH:MM:SS)'),
  // Other fields
  body('photos')
    .optional()
    .isArray().withMessage('Photos must be an array'),
  body('amenities')
    .optional()
    .isArray().withMessage('Amenities must be an array'),
  body('availableGames')
    .optional()
    .isArray().withMessage('Available games must be an array')
];

// Public routes
router.get('/', getAllCafes);
router.get('/nearby', getNearbyCafes);
router.get('/:id', getCafeById);
router.get('/:id/availability', getCafeAvailability);

// Protected Owner routes
router.post('/', protect, ownerOnly, cafeValidation, createCafe);
router.get('/owner/my-cafes', protect, ownerOnly, getMyCafes);
router.put('/:id', protect, ownerOnly, updateCafe);
router.delete('/:id', protect, ownerOnly, deleteCafe);

module.exports = router;

