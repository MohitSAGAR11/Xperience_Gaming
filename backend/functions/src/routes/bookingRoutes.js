const express = require('express');
const { body } = require('express-validator');
const {
  createBooking,
  getMyBookings,
  getBookingById,
  cancelBooking,
  getCafeBookings,
  updateBookingStatus,
  checkAvailability,
  getAvailableStationsAPI
} = require('../controllers/bookingController');
const { protect, ownerOnly, clientOnly } = require('../middleware/authMiddleware');

const router = express.Router();

// Valid console types
const validConsoleTypes = ['ps5', 'ps4', 'xbox_series_x', 'xbox_series_s', 'xbox_one', 'nintendo_switch'];

// Validation rules for creating booking (PC or Console)
const bookingValidation = [
  body('cafeId')
    .notEmpty().withMessage('Cafe ID is required')
    .isString().withMessage('Cafe ID must be a string'),
  body('stationType')
    .optional()
    .isIn(['pc', 'console']).withMessage('Station type must be "pc" or "console"'),
  body('consoleType')
    .optional()
    .isIn(validConsoleTypes).withMessage(`Console type must be one of: ${validConsoleTypes.join(', ')}`),
  body('stationNumber')
    .notEmpty().withMessage('Station/unit number is required')
    .isInt({ min: 1 }).withMessage('Station/unit number must be at least 1'),
  body('numberOfPcs')
    .optional()
    .isInt({ min: 1, max: 20 }).withMessage('Number of PCs must be between 1 and 20'),
  body('bookingDate')
    .notEmpty().withMessage('Booking date is required')
    .isDate().withMessage('Invalid date format (YYYY-MM-DD)'),
  body('startTime')
    .notEmpty().withMessage('Start time is required')
    .matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/)
    .withMessage('Invalid start time format (HH:MM or HH:MM:SS)'),
  body('endTime')
    .notEmpty().withMessage('End time is required')
    .matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/)
    .withMessage('Invalid end time format (HH:MM or HH:MM:SS)'),
  body('notes')
    .optional()
    .trim()
];

// Check availability validation (PC or Console)
const checkAvailabilityValidation = [
  body('cafeId')
    .notEmpty().withMessage('Cafe ID is required')
    .isString().withMessage('Cafe ID must be a string'),
  body('stationType')
    .optional()
    .isIn(['pc', 'console']).withMessage('Station type must be "pc" or "console"'),
  body('consoleType')
    .optional()
    .isIn(validConsoleTypes).withMessage(`Console type must be one of: ${validConsoleTypes.join(', ')}`),
  body('stationNumber')
    .notEmpty().withMessage('Station/unit number is required')
    .isInt({ min: 1 }).withMessage('Station/unit number must be at least 1'),
  body('bookingDate')
    .notEmpty().withMessage('Booking date is required')
    .isDate().withMessage('Invalid date format'),
  body('startTime')
    .notEmpty().withMessage('Start time is required'),
  body('endTime')
    .notEmpty().withMessage('End time is required')
];

// Public route - check availability before booking
router.post('/check-availability', checkAvailabilityValidation, checkAvailability);

// OPTIMIZED: Get available stations for a time slot (server-side calculation)
router.get('/available-stations', protect, getAvailableStationsAPI);

// Client routes
router.post('/', protect, clientOnly, bookingValidation, createBooking);
router.get('/my-bookings', protect, getMyBookings);
router.get('/:id', protect, getBookingById);
router.put('/:id/cancel', protect, cancelBooking);

// Owner routes
router.get('/cafe/:cafeId', protect, ownerOnly, getCafeBookings);
router.put('/:id/status', protect, ownerOnly, updateBookingStatus);

module.exports = router;

