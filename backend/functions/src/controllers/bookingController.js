const { db } = require('../config/firebase');
const { validationResult } = require('express-validator');
const { createCommunityPost, deleteCommunityPost } = require('./communityController');
const notificationService = require('../services/notificationService');

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
  let endMinutes = timeToMinutes(endTime);
  
  // Handle midnight crossing: if end is before start, add 24 hours
  if (endMinutes < startMinutes) {
    endMinutes += 24 * 60;
  }
  
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
 * @param {Object|null} transaction - Firestore transaction object (for atomic reads)
 * @returns {Array<number>} Array of available station numbers
 */
const getAvailableStations = async (cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations, transaction = null) => {
  const reqStartMins = timeToMinutes(startTime);
  let reqEndMins = timeToMinutes(endTime);
  
  // Handle midnight crossing for requested time
  // If end time is before start time, booking crosses midnight
  if (reqEndMins < reqStartMins) {
    reqEndMins += 24 * 60; // Add 24 hours
    console.log('🎯 [GET_AVAILABLE] Requested booking crosses midnight:', startTime, 'to', endTime);
    console.log('🎯 [GET_AVAILABLE] Adjusted end mins:', reqEndMins);
  }
  
  let query = db.collection('bookings')
    .where('cafeId', '==', cafeId)
    .where('stationType', '==', stationType)
    .where('bookingDate', '==', bookingDate);

  if (stationType === 'console' && consoleType) {
    query = query.where('consoleType', '==', consoleType);
  }

  // Use transaction.get() if transaction is provided for atomic reads
  // This ensures we read a consistent snapshot and prevents race conditions
  const snapshot = transaction 
    ? await transaction.get(query)
    : await query.get();
    
  const existingBookings = snapshot.docs
    .map(doc => ({ id: doc.id, ...doc.data() }))
    .filter(b => ['pending', 'confirmed'].includes(b.status));

  console.log('🎯 [GET_AVAILABLE] Checking', maxStations, 'stations against', existingBookings.length, 'bookings');

  const availableStations = [];

  for (let station = 1; station <= maxStations; station++) {
    const stationBookings = existingBookings.filter(b => b.stationNumber === station);
    
    let hasConflict = false;
    for (const booking of stationBookings) {
      let bookedStartMins = timeToMinutes(booking.startTime);
      let bookedEndMins = timeToMinutes(booking.endTime);
      
      // Handle midnight crossing for existing booking
      if (bookedEndMins < bookedStartMins) {
        bookedEndMins += 24 * 60;
      }
      
      // Check for overlap with adjusted times
      // Overlap exists if: reqStart < bookedEnd AND reqEnd > bookedStart
      if (reqStartMins < bookedEndMins && reqEndMins > bookedStartMins) {
        console.log(`🎯 [GET_AVAILABLE] Station ${station} CONFLICT: Req(${reqStartMins}-${reqEndMins}) vs Booked(${bookedStartMins}-${bookedEndMins})`);
        hasConflict = true;
        break;
      }
    }
    
    if (!hasConflict) {
      availableStations.push(station);
    }
  }

  console.log('🎯 [GET_AVAILABLE] Available stations found:', availableStations.length);
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

    // Validate booking time with midnight crossing support
    const bookingStartMins = timeToMinutes(startTime);
    let bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    let cafeCloseMins = timeToMinutes(cafe.closingTime);
    
    console.log('⏰ [CREATE_BOOKING] Time validation:');
    console.log(`⏰   Booking: ${startTime} (${bookingStartMins}m) → ${endTime} (${bookingEndMins}m)`);
    console.log(`⏰   Cafe: ${cafe.openingTime} (${cafeOpenMins}m) → ${cafe.closingTime} (${cafeCloseMins}m)`);
    
    // Detect if cafe crosses midnight (e.g., 09:00 to 01:00)
    const crossesMidnight = cafeCloseMins < cafeOpenMins;
    
    if (crossesMidnight) {
      // Adjust closing time to next day
      cafeCloseMins += 24 * 60;
      console.log(`⏰   Cafe crosses midnight, adjusted close: ${cafeCloseMins}m`);
      
      // Adjust booking end if it crosses midnight too
      if (bookingEndMins < bookingStartMins) {
        bookingEndMins += 24 * 60;
        console.log(`⏰   Booking crosses midnight, adjusted end: ${bookingEndMins}m`);
      }
      
      // Adjust booking start if it's after midnight (e.g., 00:30)
      if (bookingStartMins < cafeOpenMins) {
        const adjustedStartMins = bookingStartMins + 24 * 60;
        console.log(`⏰   Booking starts after midnight, adjusted start: ${adjustedStartMins}m`);
        
        // Check if adjusted start is within cafe hours
        if (adjustedStartMins < cafeOpenMins || adjustedStartMins >= cafeCloseMins) {
          const formatTime = (t) => t ? t.substring(0, 5) : '';
          return res.status(400).json({
            success: false,
            message: `Booking time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`
          });
        }
        
        // Also adjust end time for after-midnight bookings
        if (bookingEndMins < adjustedStartMins) {
          bookingEndMins += 24 * 60;
        }
        
        // Validate end time
        if (bookingEndMins > cafeCloseMins) {
          const formatTime = (t) => t ? t.substring(0, 5) : '';
          return res.status(400).json({
            success: false,
            message: `Booking time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`
          });
        }
        
        console.log('⏰   Validation passed for after-midnight booking!');
        // Continue with booking creation
      } else {
        // Normal validation for before-midnight start times
        if (bookingStartMins < cafeOpenMins || bookingEndMins > cafeCloseMins) {
          const formatTime = (t) => t ? t.substring(0, 5) : '';
          return res.status(400).json({
            success: false,
            message: `Booking time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`
          });
        }
      }
    } else {
      // Normal same-day operation (e.g., 09:00 to 22:00)
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
    }
    
    console.log('⏰   Time validation PASSED!');


    // Calculate duration and total amount
    const durationHours = calculateDuration(startTime, endTime);
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);
    const totalAmount = durationHours * hourlyRate;

    // Use Firestore transaction to prevent race conditions
    const bookingRef = db.collection('bookings').doc();
    
    try {
      await db.runTransaction(async (transaction) => {
        // Re-check for conflicts inside transaction using transaction.get() for atomic reads
        // This ensures we read a consistent snapshot and prevents double-booking
        const availableStations = await getAvailableStations(
          cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations, transaction
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
          status: 'pending', // Changed to pending - will be confirmed after payment
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
        createdAt: bookingData.createdAt?.toDate ? bookingData.createdAt.toDate().toISOString() : bookingData.createdAt,
        updatedAt: bookingData.updatedAt?.toDate ? bookingData.updatedAt.toDate().toISOString() : bookingData.updatedAt,
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

      // Create community post (show booking activity in community feed)
      try {
        await createCommunityPost(booking, cafeData, userData);
        console.log('🌐 Community post created for booking');
      } catch (communityError) {
        // Don't fail booking if community post fails
        console.error('🌐 Failed to create community post:', communityError);
      }

      // Send notification to cafe owner
      try {
        await notificationService.sendBookingNotification(
          booking,
          cafeData,
          userData
        );
        console.log('📬 Notification sent to cafe owner');
      } catch (notificationError) {
        // Don't fail booking if notification fails
        console.error('📬 Failed to send notification:', notificationError);
      }

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

    console.log('🎯 [AVAILABLE_STATIONS] ========================================');
    console.log('🎯 [AVAILABLE_STATIONS] Request:', { cafeId, stationType, bookingDate, startTime, endTime });

    if (!cafeId || !stationType || !bookingDate || !startTime || !endTime) {
      console.log('🎯 [AVAILABLE_STATIONS] ERROR: Missing required fields');
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: cafeId, stationType, bookingDate, startTime, endTime'
      });
    }

    const cafe = await getCafeData(cafeId);
    if (!cafe) {
      console.log('🎯 [AVAILABLE_STATIONS] ERROR: Cafe not found');
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }
    console.log('🎯 [AVAILABLE_STATIONS] Cafe found:', cafe.name);
    console.log('🎯 [AVAILABLE_STATIONS] Cafe hours:', cafe.openingTime, 'to', cafe.closingTime);

    // Validate time is within cafe hours with proper midnight crossing support
    let bookingStartMins = timeToMinutes(startTime);
    let bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    let cafeCloseMins = timeToMinutes(cafe.closingTime);

    console.log('🎯 [AVAILABLE_STATIONS] Time validation:');
    console.log(`🎯   Booking: ${startTime} (${bookingStartMins}m) → ${endTime} (${bookingEndMins}m)`);
    console.log(`🎯   Cafe: ${cafe.openingTime} (${cafeOpenMins}m) → ${cafe.closingTime} (${cafeCloseMins}m)`);

    // Detect if cafe crosses midnight (e.g., 09:00 to 01:00)
    const crossesMidnight = cafeCloseMins < cafeOpenMins;
    
    if (crossesMidnight) {
      // Adjust closing time to next day
      cafeCloseMins += 24 * 60;
      console.log(`🎯   Cafe crosses midnight, adjusted close: ${cafeCloseMins}m`);
      
      // If booking start is after midnight (e.g., 00:30 = 30 mins)
      // and less than opening time, it's likely an after-midnight booking
      if (bookingStartMins < cafeOpenMins) {
        bookingStartMins += 24 * 60;
        console.log(`🎯   Booking starts after midnight, adjusted start: ${bookingStartMins}m`);
      }
      
      // If booking end is less than adjusted start, it needs adjustment too
      if (bookingEndMins < timeToMinutes(startTime)) {
        bookingEndMins += 24 * 60;
        console.log(`🎯   Booking end crosses midnight, adjusted end: ${bookingEndMins}m`);
      } else if (bookingStartMins >= 24 * 60 && bookingEndMins < bookingStartMins) {
        // Both start and end are after midnight
        bookingEndMins += 24 * 60;
        console.log(`🎯   Booking end also after midnight, adjusted end: ${bookingEndMins}m`);
      }
    } else {
      // Normal same-day operation - adjust end if it crosses midnight
      if (bookingEndMins < bookingStartMins) {
        bookingEndMins += 24 * 60;
        console.log(`🎯   Booking crosses midnight, adjusted end: ${bookingEndMins}m`);
      }
    }

    // Now validate with adjusted times
    if (bookingStartMins < cafeOpenMins) {
      console.log(`🎯 [AVAILABLE_STATIONS] ERROR: Start time before opening (${bookingStartMins} < ${cafeOpenMins})`);
      const formatTime = (t) => t ? t.substring(0, 5) : '';
      return res.status(400).json({
        success: false,
        message: `Time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`,
        availableStations: [],
        totalStations: 0
      });
    }

    if (bookingEndMins > cafeCloseMins) {
      console.log(`🎯 [AVAILABLE_STATIONS] ERROR: End time after closing (${bookingEndMins} > ${cafeCloseMins})`);
      const formatTime = (t) => t ? t.substring(0, 5) : '';
      return res.status(400).json({
        success: false,
        message: `Time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`,
        availableStations: [],
        totalStations: 0
      });
    }
    
    console.log('🎯 [AVAILABLE_STATIONS] Time validation PASSED!');

    const maxStations = getMaxStations(cafe, stationType, consoleType);
    console.log('🎯 [AVAILABLE_STATIONS] Max stations:', maxStations);
    
    if (maxStations === 0) {
      console.log('🎯 [AVAILABLE_STATIONS] No stations of this type');
      return res.json({
        success: true,
        data: {
          availableStations: [],
          totalStations: 0,
          availableCount: 0
        }
      });
    }

    console.log('🎯 [AVAILABLE_STATIONS] Checking availability...');
    const availableStations = await getAvailableStations(
      cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations
    );

    console.log('🎯 [AVAILABLE_STATIONS] Available stations:', availableStations);
    console.log('🎯 [AVAILABLE_STATIONS] Available count:', availableStations.length);

    const durationHours = calculateDuration(startTime, endTime);
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);

    const response = {
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
    };

    console.log('🎯 [AVAILABLE_STATIONS] Sending response:', JSON.stringify(response, null, 2));
    console.log('🎯 [AVAILABLE_STATIONS] ========================================');
    res.json(response);
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
      createdAt: doc.data().createdAt?.toDate ? doc.data().createdAt.toDate().toISOString() : doc.data().createdAt,
      updatedAt: doc.data().updatedAt?.toDate ? doc.data().updatedAt.toDate().toISOString() : doc.data().updatedAt
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
      ...bookingData,
      createdAt: bookingData.createdAt?.toDate ? bookingData.createdAt.toDate().toISOString() : bookingData.createdAt,
      updatedAt: bookingData.updatedAt?.toDate ? bookingData.updatedAt.toDate().toISOString() : bookingData.updatedAt
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

    // Check if payment was made and initiate refund
    if (booking.paymentStatus === 'paid' && booking.paymentId) {
      try {
        const { initiateRefund } = require('./refundController');
        const refundReq = {
          params: { bookingId: req.params.id },
          body: { reason: 'Booking cancelled by user' },
          user: req.user
        };
        const refundRes = {
          json: (data) => {
            console.log('Refund initiated:', data);
          },
          status: (code) => ({ json: (data) => {} })
        };
        await initiateRefund(refundReq, refundRes);
      } catch (refundError) {
        console.error('Refund error during cancellation:', refundError);
        // Continue with cancellation even if refund fails
      }
    }

    await db.collection('bookings').doc(req.params.id).update({
      status: 'cancelled',
      updatedAt: new Date()
    });

    const updatedDoc = await db.collection('bookings').doc(req.params.id).get();
    const updatedBookingData = updatedDoc.data();
    const updatedBooking = {
      id: updatedDoc.id,
      ...updatedBookingData,
      createdAt: updatedBookingData.createdAt?.toDate ? updatedBookingData.createdAt.toDate().toISOString() : updatedBookingData.createdAt,
      updatedAt: updatedBookingData.updatedAt?.toDate ? updatedBookingData.updatedAt.toDate().toISOString() : updatedBookingData.updatedAt
    };

    // Delete community post (remove from community feed)
    try {
      await deleteCommunityPost(req.params.id);
      console.log('🌐 Community post deleted for cancelled booking');
    } catch (communityError) {
      // Don't fail cancellation if community post deletion fails
      console.error('🌐 Failed to delete community post:', communityError);
    }

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

    let snapshot;
    let needsClientSort = false;

    try {
      // Try with orderBy first (requires composite index)
      snapshot = await query
        .orderBy('bookingDate', 'asc')
        .orderBy('startTime', 'asc')
        .get();
    } catch (indexError) {
      // Fallback: Query without orderBy and sort client-side
      console.log('Index not ready for getCafeBookings, using fallback query');
      snapshot = await query.get();
      needsClientSort = true;
    }

    let bookings = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate ? doc.data().createdAt.toDate().toISOString() : doc.data().createdAt,
      updatedAt: doc.data().updatedAt?.toDate ? doc.data().updatedAt.toDate().toISOString() : doc.data().updatedAt
    }));

    // Sort client-side if index wasn't available
    if (needsClientSort) {
      bookings.sort((a, b) => {
        // Sort by bookingDate asc, then startTime asc
        const dateCompare = (a.bookingDate || '').localeCompare(b.bookingDate || '');
        if (dateCompare !== 0) return dateCompare;
        return (a.startTime || '').localeCompare(b.startTime || '');
      });
    }

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
    const updatedBookingData = updatedDoc.data();
    const updatedBooking = {
      id: updatedDoc.id,
      ...updatedBookingData,
      createdAt: updatedBookingData.createdAt?.toDate ? updatedBookingData.createdAt.toDate().toISOString() : updatedBookingData.createdAt,
      updatedAt: updatedBookingData.updatedAt?.toDate ? updatedBookingData.updatedAt.toDate().toISOString() : updatedBookingData.updatedAt
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
