const { db } = require('../config/firebase');
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
  let query = db.collection('bookings')
    .where('cafeId', '==', cafeId)
    .where('stationType', '==', stationType)
    .where('stationNumber', '==', stationNumber)
    .where('bookingDate', '==', bookingDate);

  if (stationType === 'console' && consoleType) {
    query = query.where('consoleType', '==', consoleType);
  }

  const snapshot = await query.get();
  const bookings = snapshot.docs
    .map(doc => ({ id: doc.id, ...doc.data() }))
    .filter(b => ['pending', 'confirmed'].includes(b.status))
    .filter(b => !excludeBookingId || b.id !== excludeBookingId);

  const reqStartMins = timeToMinutes(startTime);
  const reqEndMins = timeToMinutes(endTime);

  // Check for time overlap
  for (const booking of bookings) {
    const bookedStartMins = timeToMinutes(booking.startTime);
    const bookedEndMins = timeToMinutes(booking.endTime);

    // Overlap detection: requested starts before booked ends AND requested ends after booked starts
    if (reqStartMins < bookedEndMins && reqEndMins > bookedStartMins) {
      return true;
    }
  }

  return false;
};

/**
 * Get hourly rate based on station type
 * @param {Object} cafe - Cafe data
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type
 * @returns {number} Hourly rate
 */
const getHourlyRate = (cafe, stationType, consoleType) => {
  if (stationType === 'pc') {
    return parseFloat(cafe.pcHourlyRate || cafe.hourlyRate || 0);
  }
  
  if (stationType === 'console' && consoleType && cafe.consoles && cafe.consoles[consoleType]) {
    const consoleRate = cafe.consoles[consoleType].hourlyRate;
    return parseFloat(consoleRate > 0 ? consoleRate : cafe.hourlyRate || 0);
  }
  
  return parseFloat(cafe.hourlyRate || 0);
};

/**
 * Get max station/unit number based on type
 * @param {Object} cafe - Cafe data
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type
 * @returns {number} Max station number
 */
const getMaxStations = (cafe, stationType, consoleType) => {
  if (stationType === 'pc') {
    return cafe.totalPcStations || 0;
  }
  
  if (stationType === 'console' && consoleType && cafe.consoles && cafe.consoles[consoleType]) {
    return cafe.consoles[consoleType].quantity || 0;
  }
  
  return 0;
};

/**
 * Get available stations for a specific time slot
 * @param {string} cafeId - Cafe ID
 * @param {string} stationType - 'pc' or 'console'
 * @param {string|null} consoleType - Console type
 * @param {string} bookingDate - Booking date
 * @param {string} startTime - Requested start time
 * @param {string} endTime - Requested end time
 * @param {number} maxStations - Total stations available
 * @returns {Array<number>} Array of available station numbers
 */
const getAvailableStations = async (cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations) => {
  const reqStartMins = timeToMinutes(startTime);
  const reqEndMins = timeToMinutes(endTime);
  
  let query = db.collection('bookings')
    .where('cafeId', '==', cafeId)
    .where('stationType', '==', stationType)
    .where('bookingDate', '==', bookingDate);

  if (stationType === 'console' && consoleType) {
    query = query.where('consoleType', '==', consoleType);
  }

  const snapshot = await query.get();
  const existingBookings = snapshot.docs
    .map(doc => ({ id: doc.id, ...doc.data() }))
    .filter(b => ['pending', 'confirmed'].includes(b.status));

  const availableStations = [];

  for (let station = 1; station <= maxStations; station++) {
    const stationBookings = existingBookings.filter(b => b.stationNumber === station);
    
    let hasConflict = false;
    for (const booking of stationBookings) {
      const bookedStartMins = timeToMinutes(booking.startTime);
      const bookedEndMins = timeToMinutes(booking.endTime);
      
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
 * Helper function to get cafe data
 */
const getCafeData = async (cafeId) => {
  const cafeDoc = await db.collection('cafes').doc(cafeId).get();
  if (!cafeDoc.exists) return null;
  return { id: cafeDoc.id, ...cafeDoc.data() };
};

/**
 * Helper function to get user data
 */
const getUserData = async (userId) => {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return null;
  return { id: userDoc.id, ...userDoc.data() };
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
      stationType = 'pc',
      consoleType,
      stationNumber, 
      bookingDate, 
      startTime, 
      endTime, 
      notes 
    } = req.body;

    // Validate console type
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
    const cafe = await getCafeData(cafeId);
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

    // Get max available stations/units
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

    // Validate booking time
    const bookingStartMins = timeToMinutes(startTime);
    const bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    const cafeCloseMins = timeToMinutes(cafe.closingTime);
    
    if (bookingStartMins < cafeOpenMins || bookingEndMins > cafeCloseMins) {
      const formatTime = (t) => t ? t.substring(0, 5) : '';
      return res.status(400).json({
        success: false,
        message: `Booking time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`
      });
    }

    if (bookingEndMins <= bookingStartMins) {
      return res.status(400).json({
        success: false,
        message: 'End time must be after start time'
      });
    }

    // Calculate duration and total amount
    const durationHours = calculateDuration(startTime, endTime);
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);
    const totalAmount = durationHours * hourlyRate;

    // Use Firestore transaction to prevent race conditions
    const bookingRef = db.collection('bookings').doc();
    
    try {
      await db.runTransaction(async (transaction) => {
        // Re-check for conflicts inside transaction
        const availableStations = await getAvailableStations(
          cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations
        );

        if (!availableStations.includes(stationNumber)) {
          const typeLabel = stationType === 'pc' ? 'PC station' : `${consoleType} console`;
          throw new Error(`CONFLICT:This ${typeLabel} #${stationNumber} is already booked for the selected time slot. Available: ${availableStations.length > 0 ? '#' + availableStations.join(', #') : 'None'}`);
        }

        // Create booking within transaction
        const bookingData = {
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
          notes: notes || null,
          status: 'confirmed',
          paymentStatus: 'unpaid',
          createdAt: new Date(),
          updatedAt: new Date()
        };

        transaction.set(bookingRef, bookingData);
      });

      // Fetch booking with details
      const bookingDoc = await bookingRef.get();
      const bookingData = bookingDoc.data();
      
      const cafeData = await getCafeData(cafeId);
      const userData = await getUserData(req.user.id);

      const booking = {
        id: bookingDoc.id,
        ...bookingData,
        cafe: cafeData ? {
          id: cafeData.id,
          name: cafeData.name,
          address: cafeData.address,
          city: cafeData.city
        } : null,
        user: userData ? {
          id: userData.id,
          name: userData.name,
          email: userData.email
        } : null
      };

      res.status(201).json({
        success: true,
        message: 'Booking confirmed successfully',
        data: {
          booking,
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
      if (error.message && error.message.startsWith('CONFLICT:')) {
        return res.status(409).json({
          success: false,
          message: error.message.replace('CONFLICT:', '')
        });
      }
      throw error;
    }
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while creating booking',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Get available stations for a specific time slot
 * @route   GET /api/bookings/available-stations
 * @access  Private
 */
const getAvailableStationsAPI = async (req, res) => {
  try {
    const { cafeId, stationType, consoleType, bookingDate, startTime, endTime } = req.query;

    if (!cafeId || !stationType || !bookingDate || !startTime || !endTime) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: cafeId, stationType, bookingDate, startTime, endTime'
      });
    }

    const cafe = await getCafeData(cafeId);
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

    const availableStations = await getAvailableStations(
      cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations
    );

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
    
    let query = db.collection('bookings')
      .where('userId', '==', req.user.id);

    if (status) {
      query = query.where('status', '==', status);
    }

    let snapshot;
    let needsClientSort = false;

    try {
      // Try with orderBy first (requires composite index)
      snapshot = await query
        .orderBy('bookingDate', 'desc')
        .orderBy('startTime', 'desc')
        .get();
    } catch (indexError) {
      // Fallback: If index doesn't exist, query without orderBy and sort client-side
      console.log('Index not ready, using fallback query for getMyBookings');
      snapshot = await db.collection('bookings')
        .where('userId', '==', req.user.id)
        .get();
      needsClientSort = true;
    }

    let bookings = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate ? doc.data().createdAt.toDate() : doc.data().createdAt,
      updatedAt: doc.data().updatedAt?.toDate ? doc.data().updatedAt.toDate() : doc.data().updatedAt
    }));

    // Filter by status if needed (in case fallback query was used)
    if (needsClientSort && status) {
      bookings = bookings.filter(b => b.status === status);
    }

    // Sort client-side if index wasn't available
    if (needsClientSort) {
      bookings.sort((a, b) => {
        // Sort by bookingDate desc, then startTime desc
        const dateCompare = (b.bookingDate || '').localeCompare(a.bookingDate || '');
        if (dateCompare !== 0) return dateCompare;
        return (b.startTime || '').localeCompare(a.startTime || '');
      });
    }

    // Pagination
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    const total = bookings.length;
    bookings = bookings.slice(offset, offset + limitNum);

    // Fetch cafe data for each booking
    const bookingsWithCafe = await Promise.all(
      bookings.map(async (booking) => {
        const cafe = await getCafeData(booking.cafeId);
        return {
          ...booking,
          cafe: cafe ? {
            id: cafe.id,
            name: cafe.name,
            address: cafe.address,
            city: cafe.city,
            photos: cafe.photos || []
          } : null
        };
      })
    );

    // Categorize bookings
    const today = new Date().toISOString().split('T')[0];
    const categorizedBookings = {
      upcoming: bookingsWithCafe.filter(b => 
        b.bookingDate >= today && ['pending', 'confirmed'].includes(b.status)
      ),
      past: bookingsWithCafe.filter(b => 
        b.bookingDate < today || ['completed', 'cancelled'].includes(b.status)
      )
    };

    res.json({
      success: true,
      data: {
        bookings: bookingsWithCafe,
        categorized: categorizedBookings,
        pagination: {
          total,
          page: pageNum,
          pages: Math.ceil(total / limitNum),
          limit: limitNum
        }
      }
    });
  } catch (error) {
    console.error('Get my bookings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching your bookings'
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
    const bookingDoc = await db.collection('bookings').doc(req.params.id).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    const bookingData = bookingDoc.data();
    const booking = {
      id: bookingDoc.id,
      ...bookingData
    };

    // Check authorization
    const cafe = await getCafeData(booking.cafeId);
    const isOwner = cafe && cafe.ownerId === req.user.id;
    const isBookingUser = booking.userId === req.user.id;

    if (!isOwner && !isBookingUser) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view this booking'
      });
    }

    // Fetch related data
    const cafeData = await getCafeData(booking.cafeId);
    const userData = await getUserData(booking.userId);

    booking.cafe = cafeData ? {
      id: cafeData.id,
      name: cafeData.name,
      address: cafeData.address,
      city: cafeData.city,
      hourlyRate: cafeData.hourlyRate,
      photos: cafeData.photos || []
    } : null;

    booking.user = userData ? {
      id: userData.id,
      name: userData.name,
      email: userData.email,
      phone: userData.phone
    } : null;

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
    const bookingDoc = await db.collection('bookings').doc(req.params.id).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    const booking = bookingDoc.data();

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

    await db.collection('bookings').doc(req.params.id).update({
      status: 'cancelled',
      updatedAt: new Date()
    });

    const updatedDoc = await db.collection('bookings').doc(req.params.id).get();
    const updatedBooking = {
      id: updatedDoc.id,
      ...updatedDoc.data()
    };

    res.json({
      success: true,
      message: 'Booking cancelled successfully',
      data: { booking: updatedBooking }
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
    const cafe = await getCafeData(cafeId);
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

    let query = db.collection('bookings').where('cafeId', '==', cafeId);
    
    if (date) {
      query = query.where('bookingDate', '==', date);
    }
    
    if (status) {
      query = query.where('status', '==', status);
    }

    const snapshot = await query
      .orderBy('bookingDate', 'asc')
      .orderBy('startTime', 'asc')
      .get();

    let bookings = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Pagination
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    const total = bookings.length;
    bookings = bookings.slice(offset, offset + limitNum);

    // Fetch user data for each booking
    const bookingsWithUser = await Promise.all(
      bookings.map(async (booking) => {
        const user = await getUserData(booking.userId);
        return {
          ...booking,
          user: user ? {
            id: user.id,
            name: user.name,
            email: user.email,
            phone: user.phone
          } : null
        };
      })
    );

    res.json({
      success: true,
      data: {
        bookings: bookingsWithUser,
        pagination: {
          total,
          page: pageNum,
          pages: Math.ceil(total / limitNum),
          limit: limitNum
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

    const bookingDoc = await db.collection('bookings').doc(req.params.id).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    const booking = bookingDoc.data();

    // Check if user owns the cafe
    const cafe = await getCafeData(booking.cafeId);
    if (!cafe || cafe.ownerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this booking'
      });
    }

    await db.collection('bookings').doc(req.params.id).update({
      status,
      updatedAt: new Date()
    });

    const updatedDoc = await db.collection('bookings').doc(req.params.id).get();
    const updatedBooking = {
      id: updatedDoc.id,
      ...updatedDoc.data()
    };

    res.json({
      success: true,
      message: `Booking status updated to ${status}`,
      data: { booking: updatedBooking }
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
 * @desc    Check slot availability before booking
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

    const cafe = await getCafeData(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

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
  getAvailableStationsAPI
};
