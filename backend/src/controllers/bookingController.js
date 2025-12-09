const { Op } = require('sequelize');
const { Booking, Cafe, User, sequelize } = require('../models');
const { validationResult } = require('express-validator');

/**
 * Convert time string to minutes since midnight for accurate comparison
 * Handles both "HH:MM" and "HH:MM:SS" formats
 * @param {string} time - Time string
 * @returns {number} Minutes since midnight
 */
const timeToMinutes = (time) => {
  if (!time) return 0;
  const parts = time.split(':').map(Number);
  return parts[0] * 60 + (parts[1] || 0);
};

/**
 * Calculate duration in hours between two times
 * @param {string} startTime - Start time (HH:MM:SS)
 * @param {string} endTime - End time (HH:MM:SS)
 * @returns {number} Duration in hours
 */
const calculateDuration = (startTime, endTime) => {
  const startMinutes = timeToMinutes(startTime);
  const endMinutes = timeToMinutes(endTime);
  
  return (endMinutes - startMinutes) / 60;
};

/**
 * Check for booking conflicts (supports both PC and console bookings)
 * @param {string} cafeId - Cafe ID
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type (required if stationType is 'console')
 * @param {number} stationNumber - Station/unit number
 * @param {string} bookingDate - Booking date
 * @param {string} startTime - Requested start time
 * @param {string} endTime - Requested end time
 * @param {string} excludeBookingId - Booking ID to exclude (for updates)
 * @returns {boolean} True if conflict exists
 */
const checkBookingConflict = async (cafeId, stationType, consoleType, stationNumber, bookingDate, startTime, endTime, excludeBookingId = null) => {
  const where = {
    cafeId,
    stationType,
    stationNumber,
    bookingDate,
    status: { [Op.in]: ['pending', 'confirmed'] },
    [Op.or]: [
      // New booking starts during existing booking
      {
        startTime: { [Op.lte]: startTime },
        endTime: { [Op.gt]: startTime }
      },
      // New booking ends during existing booking
      {
        startTime: { [Op.lt]: endTime },
        endTime: { [Op.gte]: endTime }
      },
      // New booking completely contains existing booking
      {
        startTime: { [Op.gte]: startTime },
        endTime: { [Op.lte]: endTime }
      }
    ]
  };

  // For console bookings, also match console type
  if (stationType === 'console' && consoleType) {
    where.consoleType = consoleType;
  }

  if (excludeBookingId) {
    where.id = { [Op.ne]: excludeBookingId };
  }

  const conflictingBooking = await Booking.findOne({ where });
  return !!conflictingBooking;
};

/**
 * Get hourly rate based on station type
 * @param {Object} cafe - Cafe model instance
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type
 * @returns {number} Hourly rate
 */
const getHourlyRate = (cafe, stationType, consoleType) => {
  if (stationType === 'pc') {
    return parseFloat(cafe.pcHourlyRate || cafe.hourlyRate);
  }
  
  if (stationType === 'console' && consoleType && cafe.consoles && cafe.consoles[consoleType]) {
    const consoleRate = cafe.consoles[consoleType].hourlyRate;
    return parseFloat(consoleRate > 0 ? consoleRate : cafe.hourlyRate);
  }
  
  return parseFloat(cafe.hourlyRate);
};

/**
 * Get max station/unit number based on type
 * @param {Object} cafe - Cafe model instance
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type
 * @returns {number} Max station number
 */
const getMaxStations = (cafe, stationType, consoleType) => {
  if (stationType === 'pc') {
    return cafe.totalPcStations;
  }
  
  if (stationType === 'console' && consoleType && cafe.consoles && cafe.consoles[consoleType]) {
    return cafe.consoles[consoleType].quantity || 0;
  }
  
  return 0;
};

/**
 * OPTIMIZED: Get available stations for a specific time slot (server-side calculation)
 * This reduces network payload and prevents race conditions
 * @param {string} cafeId - Cafe ID
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type
 * @param {string} bookingDate - Booking date
 * @param {string} startTime - Requested start time
 * @param {string} endTime - Requested end time
 * @param {number} maxStations - Total stations available
 * @param {Object} transaction - Optional Sequelize transaction
 * @returns {Array<number>} Array of available station numbers
 */
const getAvailableStations = async (cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations, transaction = null) => {
  // Convert times to minutes for accurate overlap detection
  const reqStartMins = timeToMinutes(startTime);
  const reqEndMins = timeToMinutes(endTime);
  
  // Build query for existing bookings
  const whereClause = {
    cafeId,
    stationType,
    bookingDate,
    status: { [Op.in]: ['pending', 'confirmed'] }
  };
  
  if (stationType === 'console' && consoleType) {
    whereClause.consoleType = consoleType;
  }
  
  // Get all bookings for this cafe/date/type
  const existingBookings = await Booking.findAll({
    where: whereClause,
    attributes: ['stationNumber', 'startTime', 'endTime'],
    ...(transaction && { transaction, lock: transaction.LOCK.UPDATE })
  });
  
  // Check each station for availability
  const availableStations = [];
  
  for (let station = 1; station <= maxStations; station++) {
    // Get bookings for this specific station
    const stationBookings = existingBookings.filter(b => b.stationNumber === station);
    
    // Check if any booking overlaps with requested time
    let hasConflict = false;
    for (const booking of stationBookings) {
      const bookedStartMins = timeToMinutes(booking.startTime);
      const bookedEndMins = timeToMinutes(booking.endTime);
      
      // Overlap detection: requested starts before booked ends AND requested ends after booked starts
      if (reqStartMins < bookedEndMins && reqEndMins > bookedStartMins) {
        hasConflict = true;
        break;
      }
    }
    
    if (!hasConflict) {
      availableStations.push(station);
    }
  }
  
  return availableStations;
};

/**
 * @desc    Create a new booking (PC or Console)
 * @route   POST /api/bookings
 * @access  Private/Client
 */
const createBooking = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { 
      cafeId, 
      stationType = 'pc',  // 'pc' or 'console'
      consoleType,         // Required if stationType is 'console'
      stationNumber, 
      bookingDate, 
      startTime, 
      endTime, 
      notes 
    } = req.body;

    // Validate console type is provided for console bookings
    const validConsoleTypes = ['ps5', 'ps4', 'xbox_series_x', 'xbox_series_s', 'xbox_one', 'nintendo_switch'];
    if (stationType === 'console') {
      if (!consoleType) {
        return res.status(400).json({
          success: false,
          message: 'Console type is required for console bookings'
        });
      }
      if (!validConsoleTypes.includes(consoleType)) {
        return res.status(400).json({
          success: false,
          message: `Invalid console type. Valid types: ${validConsoleTypes.join(', ')}`
        });
      }
    }

    // Get cafe details
    const cafe = await Cafe.findByPk(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    if (!cafe.isActive) {
      return res.status(400).json({
        success: false,
        message: 'This cafe is currently not accepting bookings'
      });
    }

    // Get max available stations/units for this type
    const maxStations = getMaxStations(cafe, stationType, consoleType);
    
    if (maxStations === 0) {
      const typeLabel = stationType === 'pc' ? 'PC stations' : `${consoleType} consoles`;
      return res.status(400).json({
        success: false,
        message: `This cafe does not have any ${typeLabel} available`
      });
    }

    // Validate station/unit number
    if (stationNumber < 1 || stationNumber > maxStations) {
      const typeLabel = stationType === 'pc' ? 'PC stations' : `${consoleType} units`;
      return res.status(400).json({
        success: false,
        message: `Invalid ${typeLabel} number. Available: 1-${maxStations}`
      });
    }

    // Validate booking time is within cafe hours (using minutes for accurate comparison)
    const bookingStartMins = timeToMinutes(startTime);
    const bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    const cafeCloseMins = timeToMinutes(cafe.closingTime);
    
    if (bookingStartMins < cafeOpenMins || bookingEndMins > cafeCloseMins) {
      const formatTime = (t) => t.substring(0, 5); // "09:00:00" -> "09:00"
      return res.status(400).json({
        success: false,
        message: `Booking time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`
      });
    }

    // Validate end time is after start time (using minutes for accurate comparison)
    if (bookingEndMins <= bookingStartMins) {
      return res.status(400).json({
        success: false,
        message: 'End time must be after start time'
      });
    }

    // Calculate duration and total amount (Automated Billing)
    const durationHours = calculateDuration(startTime, endTime);
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);
    const totalAmount = durationHours * hourlyRate;

    // ========== ATOMIC TRANSACTION (Prevents Race Conditions) ==========
    // Use database transaction to ensure conflict check + booking creation are atomic
    const result = await sequelize.transaction(async (t) => {
      // Re-check for conflicts INSIDE transaction with row locking
      const availableStations = await getAvailableStations(
        cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations, t
      );

      // Check if requested station is available
      if (!availableStations.includes(stationNumber)) {
        const typeLabel = stationType === 'pc' ? 'PC station' : `${consoleType} console`;
        throw new Error(`CONFLICT:This ${typeLabel} #${stationNumber} is already booked for the selected time slot. Available: ${availableStations.length > 0 ? '#' + availableStations.join(', #') : 'None'}`);
      }

      // Create the booking within the transaction
      const booking = await Booking.create({
        userId: req.user.id,
        cafeId,
        stationType,
        consoleType: stationType === 'console' ? consoleType : null,
        stationNumber,
        bookingDate,
        startTime,
        endTime,
        durationHours,
        hourlyRate,
        totalAmount,
        notes,
        status: 'confirmed'
      }, { transaction: t });

      return booking;
    });
    // ========== END TRANSACTION ==========

    // Fetch with associations (outside transaction)
    const bookingWithDetails = await Booking.findByPk(result.id, {
      include: [
        {
          model: Cafe,
          as: 'cafe',
          attributes: ['id', 'name', 'address', 'city']
        },
        {
          model: User,
          as: 'user',
          attributes: ['id', 'name', 'email']
        }
      ]
    });

    res.status(201).json({
      success: true,
      message: 'Booking confirmed successfully',
      data: {
        booking: bookingWithDetails,
        billing: {
          stationType,
          consoleType: stationType === 'console' ? consoleType : null,
          durationHours,
          hourlyRate,
          totalAmount
        }
      }
    });
  } catch (error) {
    console.error('Create booking error:', error);
    
    // Handle conflict errors from transaction
    if (error.message && error.message.startsWith('CONFLICT:')) {
      return res.status(409).json({
        success: false,
        message: error.message.replace('CONFLICT:', '')
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Server error while creating booking',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    OPTIMIZED: Get available stations for a specific time slot
 * @route   GET /api/bookings/available-stations
 * @access  Private
 * @query   cafeId, stationType, consoleType, bookingDate, startTime, endTime
 */
const getAvailableStationsAPI = async (req, res) => {
  try {
    const { cafeId, stationType, consoleType, bookingDate, startTime, endTime } = req.query;

    // Validate required fields
    if (!cafeId || !stationType || !bookingDate || !startTime || !endTime) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: cafeId, stationType, bookingDate, startTime, endTime'
      });
    }

    // Get cafe details
    const cafe = await Cafe.findByPk(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Validate time is within cafe hours
    const bookingStartMins = timeToMinutes(startTime);
    const bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    const cafeCloseMins = timeToMinutes(cafe.closingTime);

    if (bookingStartMins < cafeOpenMins || bookingEndMins > cafeCloseMins) {
      const formatTime = (t) => t ? t.substring(0, 5) : '';
      return res.status(400).json({
        success: false,
        message: `Time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`,
        availableStations: [],
        totalStations: 0
      });
    }

    // Get max stations
    const maxStations = getMaxStations(cafe, stationType, consoleType);
    
    if (maxStations === 0) {
      return res.json({
        success: true,
        data: {
          availableStations: [],
          totalStations: 0,
          availableCount: 0
        }
      });
    }

    // Get available stations (server-side calculation)
    const availableStations = await getAvailableStations(
      cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations
    );

    // Calculate pricing
    const durationHours = calculateDuration(startTime, endTime);
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);

    res.json({
      success: true,
      data: {
        availableStations,
        totalStations: maxStations,
        availableCount: availableStations.length,
        firstAvailable: availableStations.length > 0 ? availableStations[0] : null,
        pricing: {
          durationHours,
          hourlyRate,
          estimatedTotal: durationHours * hourlyRate
        }
      }
    });
  } catch (error) {
    console.error('Get available stations error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Get user's booking history
 * @route   GET /api/bookings/my-bookings
 * @access  Private
 */
const getMyBookings = async (req, res) => {
  try {
    const { status, page = 1, limit = 10 } = req.query;
    
    const where = { userId: req.user.id };
    
    if (status) {
      where.status = status;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: bookings } = await Booking.findAndCountAll({
      where,
      include: [{
        model: Cafe,
        as: 'cafe',
        attributes: ['id', 'name', 'address', 'city', 'photos']
      }],
      limit: parseInt(limit),
      offset,
      order: [['bookingDate', 'DESC'], ['startTime', 'DESC']]
    });

    // Categorize bookings
    const today = new Date().toISOString().split('T')[0];
    const categorizedBookings = {
      upcoming: bookings.filter(b => 
        b.bookingDate >= today && ['pending', 'confirmed'].includes(b.status)
      ),
      past: bookings.filter(b => 
        b.bookingDate < today || ['completed', 'cancelled'].includes(b.status)
      )
    };

    res.json({
      success: true,
      data: {
        bookings,
        categorized: categorizedBookings,
        pagination: {
          total: count,
          page: parseInt(page),
          pages: Math.ceil(count / parseInt(limit)),
          limit: parseInt(limit)
        }
      }
    });
  } catch (error) {
    console.error('Get my bookings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Get single booking by ID
 * @route   GET /api/bookings/:id
 * @access  Private
 */
const getBookingById = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id, {
      include: [
        {
          model: Cafe,
          as: 'cafe',
          attributes: ['id', 'name', 'address', 'city', 'hourlyRate', 'photos']
        },
        {
          model: User,
          as: 'user',
          attributes: ['id', 'name', 'email', 'phone']
        }
      ]
    });

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    // Check if user owns this booking or owns the cafe
    const cafe = await Cafe.findByPk(booking.cafeId);
    const isOwner = cafe && cafe.ownerId === req.user.id;
    const isBookingUser = booking.userId === req.user.id;

    if (!isOwner && !isBookingUser) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view this booking'
      });
    }

    res.json({
      success: true,
      data: { booking }
    });
  } catch (error) {
    console.error('Get booking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Cancel a booking
 * @route   PUT /api/bookings/:id/cancel
 * @access  Private
 */
const cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id);

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    // Check ownership
    if (booking.userId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to cancel this booking'
      });
    }

    // Check if booking can be cancelled
    if (booking.status === 'cancelled') {
      return res.status(400).json({
        success: false,
        message: 'Booking is already cancelled'
      });
    }

    if (booking.status === 'completed') {
      return res.status(400).json({
        success: false,
        message: 'Cannot cancel a completed booking'
      });
    }

    booking.status = 'cancelled';
    await booking.save();

    res.json({
      success: true,
      message: 'Booking cancelled successfully',
      data: { booking }
    });
  } catch (error) {
    console.error('Cancel booking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Get cafe's bookings (Owner only)
 * @route   GET /api/bookings/cafe/:cafeId
 * @access  Private/Owner
 */
const getCafeBookings = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const { date, status, page = 1, limit = 20 } = req.query;

    // Verify ownership
    const cafe = await Cafe.findByPk(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    if (cafe.ownerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view these bookings'
      });
    }

    const where = { cafeId };
    
    if (date) {
      where.bookingDate = date;
    }
    
    if (status) {
      where.status = status;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: bookings } = await Booking.findAndCountAll({
      where,
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'email', 'phone']
      }],
      limit: parseInt(limit),
      offset,
      order: [['bookingDate', 'ASC'], ['startTime', 'ASC']]
    });

    res.json({
      success: true,
      data: {
        bookings,
        pagination: {
          total: count,
          page: parseInt(page),
          pages: Math.ceil(count / parseInt(limit)),
          limit: parseInt(limit)
        }
      }
    });
  } catch (error) {
    console.error('Get cafe bookings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Update booking status (Owner only)
 * @route   PUT /api/bookings/:id/status
 * @access  Private/Owner
 */
const updateBookingStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['pending', 'confirmed', 'cancelled', 'completed'];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status'
      });
    }

    const booking = await Booking.findByPk(req.params.id, {
      include: [{ model: Cafe, as: 'cafe' }]
    });

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    // Check if user owns the cafe
    if (booking.cafe.ownerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this booking'
      });
    }

    booking.status = status;
    await booking.save();

    res.json({
      success: true,
      message: `Booking status updated to ${status}`,
      data: { booking }
    });
  } catch (error) {
    console.error('Update booking status error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Check slot availability before booking (PC or Console)
 * @route   POST /api/bookings/check-availability
 * @access  Public
 */
const checkAvailability = async (req, res) => {
  try {
    const { 
      cafeId, 
      stationType = 'pc',
      consoleType,
      stationNumber, 
      bookingDate, 
      startTime, 
      endTime 
    } = req.body;

    const cafe = await Cafe.findByPk(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Validate console type for console bookings
    if (stationType === 'console' && !consoleType) {
      return res.status(400).json({
        success: false,
        message: 'Console type is required for console availability check'
      });
    }

    const hasConflict = await checkBookingConflict(
      cafeId, stationType, consoleType, stationNumber, bookingDate, startTime, endTime
    );

    const durationHours = calculateDuration(startTime, endTime);
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);
    const estimatedCost = durationHours * hourlyRate;
    const maxStations = getMaxStations(cafe, stationType, consoleType);

    res.json({
      success: true,
      data: {
        available: !hasConflict,
        stationType,
        consoleType: stationType === 'console' ? consoleType : null,
        maxStations,
        estimatedCost,
        durationHours,
        hourlyRate
      }
    });
  } catch (error) {
    console.error('Check availability error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

module.exports = {
  createBooking,
  getMyBookings,
  getBookingById,
  cancelBooking,
  getCafeBookings,
  updateBookingStatus,
  checkAvailability,
  getAvailableStationsAPI  // NEW: Optimized endpoint
};

