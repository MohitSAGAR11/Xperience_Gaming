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
  if (!time) {
    console.log('🕐 [TIME] timeToMinutes: null/undefined time');
    return 0;
  }
  
  const parts = time.split(':').map(Number);
  const hour = parts[0];
  const minute = parts[1] || 0;
  const minutes = hour * 60 + minute;
  
  // Debug logging for 12:00 specifically
  if (hour === 12) {
    console.log(`🕐 [TIME] timeToMinutes: ${time} → hour=${hour}, minute=${minute}, total=${minutes} minutes (12:00 = ${hour === 12 ? 'NOON (12:00 PM)' : 'MIDNIGHT (12:00 AM)'})`);
  } else if (hour === 0) {
    console.log(`🕐 [TIME] timeToMinutes: ${time} → hour=${hour}, minute=${minute}, total=${minutes} minutes (00:00 = MIDNIGHT (12:00 AM))`);
  } else {
    console.log(`🕐 [TIME] timeToMinutes: ${time} → hour=${hour}, minute=${minute}, total=${minutes} minutes (${hour < 12 ? hour + ':00 AM' : (hour === 12 ? '12:00 PM' : (hour - 12) + ':00 PM')})`);
  }
  
  return minutes;
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
  const requestId = `BOOK-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    console.log('🎫 [BOOKING] ========================================');
    console.log('🎫 [BOOKING] === CREATE BOOKING REQUEST ===');
    console.log('🎫 [BOOKING] Request ID:', requestId);
    console.log('🎫 [BOOKING] Request Method:', req.method);
    console.log('🎫 [BOOKING] Request URL:', req.originalUrl || req.url);
    console.log('🎫 [BOOKING] User ID:', req.user?.id);
    console.log('🎫 [BOOKING] Request Body:', JSON.stringify(req.body, null, 2));
    
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('🎫 [BOOKING] Validation errors:', errors.array());
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
      numberOfPcs = 1, // Number of PCs to book (default 1)
      bookingDate, 
      startTime, 
      endTime, 
      notes 
    } = req.body;

    console.log('🎫 [BOOKING] Extracted booking data:', {
      cafeId,
      stationType,
      consoleType,
      stationNumber,
      numberOfPcs,
      bookingDate,
      startTime,
      endTime,
      notes: notes || 'none'
    });

    // Validate numberOfPcs
    if (numberOfPcs < 1 || numberOfPcs > 20) {
      console.log('🎫 [BOOKING] ERROR: Invalid number of PCs');
      return res.status(400).json({
        success: false,
        message: 'Number of PCs must be between 1 and 20'
      });
    }

    // For console bookings, numberOfPcs should be 1
    if (stationType === 'console' && numberOfPcs !== 1) {
      console.log('🎫 [BOOKING] ERROR: Console bookings can only book 1 unit at a time');
      return res.status(400).json({
        success: false,
        message: 'Console bookings can only book 1 unit at a time'
      });
    }

    // Validate console type
    const validConsoleTypes = ['ps5', 'ps4', 'xbox_series_x', 'xbox_series_s', 'xbox_one', 'nintendo_switch'];
    if (stationType === 'console') {
      console.log('🎫 [BOOKING] Validating console type:', consoleType);
      if (!consoleType) {
        console.log('🎫 [BOOKING] ERROR: Console type is required');
        return res.status(400).json({
          success: false,
          message: 'Console type is required for console bookings'
        });
      }
      if (!validConsoleTypes.includes(consoleType)) {
        console.log('🎫 [BOOKING] ERROR: Invalid console type:', consoleType);
        return res.status(400).json({
          success: false,
          message: `Invalid console type. Valid types: ${validConsoleTypes.join(', ')}`
        });
      }
    }

    // Get cafe details
    console.log('🎫 [BOOKING] Fetching cafe data for cafeId:', cafeId);
    const cafe = await getCafeData(cafeId);
    if (!cafe) {
      console.log('🎫 [BOOKING] ERROR: Cafe not found:', cafeId);
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    console.log('🎫 [BOOKING] Cafe found:', {
      cafeId: cafe.id,
      cafeName: cafe.name,
      isActive: cafe.isActive,
      openingTime: cafe.openingTime,
      closingTime: cafe.closingTime
    });

    if (!cafe.isActive) {
      console.log('🎫 [BOOKING] ERROR: Cafe is not active');
      return res.status(400).json({
        success: false,
        message: 'This cafe is currently not accepting bookings'
      });
    }

    // Get max available stations/units
    const maxStations = getMaxStations(cafe, stationType, consoleType);
    console.log('🎫 [BOOKING] Max stations available:', maxStations);
    
    if (maxStations === 0) {
      const typeLabel = stationType === 'pc' ? 'PC stations' : `${consoleType} consoles`;
      console.log('🎫 [BOOKING] ERROR: No stations available');
      return res.status(400).json({
        success: false,
        message: `This cafe does not have any ${typeLabel} available`
      });
    }

    // Validate station/unit number
    console.log('🎫 [BOOKING] Validating station number:', stationNumber, 'against max:', maxStations);
    if (stationNumber < 1 || stationNumber > maxStations) {
      const typeLabel = stationType === 'pc' ? 'PC stations' : `${consoleType} units`;
      console.log('🎫 [BOOKING] ERROR: Invalid station number');
      return res.status(400).json({
        success: false,
        message: `Invalid ${typeLabel} number. Available: 1-${maxStations}`
      });
    }

    // For multiple PCs, validate that we have enough consecutive stations available
    if (numberOfPcs > 1) {
      if (stationNumber + numberOfPcs - 1 > maxStations) {
        console.log('🎫 [BOOKING] ERROR: Not enough consecutive stations available');
        return res.status(400).json({
          success: false,
          message: `Not enough consecutive stations available. Requested ${numberOfPcs} PCs starting from #${stationNumber}, but only ${maxStations} total stations available.`
        });
      }
    }

    // Validate booking time with midnight crossing support
    const bookingStartMins = timeToMinutes(startTime);
    let bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    let cafeCloseMins = timeToMinutes(cafe.closingTime);
    
    // Detect if cafe crosses midnight (e.g., 09:00 to 01:00)
    const crossesMidnight = cafeCloseMins < cafeOpenMins;
    
    if (crossesMidnight) {
      // Adjust closing time to next day
      cafeCloseMins += 24 * 60;
      
      // Adjust booking end if it crosses midnight too
      if (bookingEndMins < bookingStartMins) {
        bookingEndMins += 24 * 60;
      }
      
      // Adjust booking start if it's after midnight (e.g., 00:30)
      if (bookingStartMins < cafeOpenMins) {
        const adjustedStartMins = bookingStartMins + 24 * 60;
        
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


    // Calculate duration and total amount
    const durationHours = calculateDuration(startTime, endTime);
    console.log('🎫 [BOOKING] Calculated duration:', durationHours, 'hours');
    
    // Validate minimum booking duration (1 hour)
    if (durationHours < 1) {
      console.log('🎫 [BOOKING] ERROR: Duration less than 1 hour');
      return res.status(400).json({
        success: false,
        message: 'Minimum booking duration is 1 hour'
      });
    }
    
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);
    console.log('🎫 [BOOKING] Hourly rate:', hourlyRate);
    // Calculate exact amount with decimal precision (no rounding)
    // Example: 1.5 hours * 100/hr = 150.00 (not rounded to 200)
    const totalAmount = parseFloat((durationHours * hourlyRate).toFixed(2));
    console.log('🎫 [BOOKING] Total amount calculated:', totalAmount);

    // Use Firestore transaction to prevent race conditions
    console.log('🎫 [BOOKING] Starting Firestore transaction for booking creation');
    
    // Calculate total amount for all PCs
    const totalAmountForAllPcs = totalAmount * numberOfPcs;
    
    // Generate a unique groupBookingId to link all bookings in this group together
    // This is only set when numberOfPcs > 1 (group booking)
    const groupBookingId = numberOfPcs > 1 ? `GROUP_${Date.now()}_${Math.random().toString(36).substr(2, 9)}` : null;
    
    try {
      const createdBookings = [];
      const bookingRefs = [];
      
      // Create references for all bookings
      for (let i = 0; i < numberOfPcs; i++) {
        bookingRefs.push(db.collection('bookings').doc());
      }
      
      await db.runTransaction(async (transaction) => {
        console.log('🎫 [BOOKING] Inside transaction - checking availability...');
        // Re-check for conflicts inside transaction using transaction.get() for atomic reads
        // This ensures we read a consistent snapshot and prevents double-booking
        const availableStations = await getAvailableStations(
          cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations, transaction
        );

        console.log('🎫 [BOOKING] Available stations in transaction:', availableStations);
        console.log('🎫 [BOOKING] Requested station numbers:', Array.from({length: numberOfPcs}, (_, i) => stationNumber + i));
        
        // Check if all requested stations are available
        const requestedStations = Array.from({length: numberOfPcs}, (_, i) => stationNumber + i);
        const unavailableStations = requestedStations.filter(station => !availableStations.includes(station));
        
        if (unavailableStations.length > 0) {
          const typeLabel = stationType === 'pc' ? 'PC stations' : `${consoleType} consoles`;
          console.log('🎫 [BOOKING] CONFLICT: Some stations not available');
          throw new Error(`CONFLICT:Some ${typeLabel} (${unavailableStations.map(s => '#' + s).join(', ')}) are already booked for the selected time slot. Available: ${availableStations.length > 0 ? '#' + availableStations.join(', #') : 'None'}`);
        }

        // Create all bookings within transaction
        for (let i = 0; i < numberOfPcs; i++) {
          const currentStationNumber = stationNumber + i;
          const bookingRef = bookingRefs[i];
          
          // Each booking has the same totalAmount (per PC), but we'll track the combined total
          const bookingData = {
            userId: req.user.id,
            cafeId,
            stationType,
            consoleType: stationType === 'console' ? consoleType : null,
            stationNumber: currentStationNumber,
            bookingDate,
            startTime,
            endTime,
            durationHours,
            hourlyRate,
            totalAmount, // Per PC amount
            numberOfPcs: numberOfPcs, // Track that this is part of a group booking
            groupBookingIndex: i + 1, // Track position in group (1, 2, 3, ...)
            groupBookingId: groupBookingId, // Link all bookings in the group together
            notes: notes || null,
            status: 'pending', // Changed to pending - will be confirmed after payment
            paymentStatus: 'unpaid',
            createdAt: new Date(),
            updatedAt: new Date()
          };

          console.log('🎫 [BOOKING] Creating booking data for PC #' + currentStationNumber + ':', {
            bookingId: bookingRef.id,
            userId: bookingData.userId,
            cafeId: bookingData.cafeId,
            stationType: bookingData.stationType,
            stationNumber: bookingData.stationNumber,
            bookingDate: bookingData.bookingDate,
            startTime: bookingData.startTime,
            endTime: bookingData.endTime,
            durationHours: bookingData.durationHours,
            totalAmount: bookingData.totalAmount,
            numberOfPcs: bookingData.numberOfPcs,
            status: bookingData.status,
            paymentStatus: bookingData.paymentStatus
          });

          transaction.set(bookingRef, bookingData);
        }
        
        console.log('🎫 [BOOKING] All booking data set in transaction');
      });

      console.log('🎫 [BOOKING] Transaction completed successfully');
      
      // Fetch all created bookings with details
      console.log('🎫 [BOOKING] Fetching created bookings...');
      const bookingDocs = await Promise.all(bookingRefs.map(ref => ref.get()));
      
      console.log('🎫 [BOOKING] Fetching cafe and user data...');
      const cafeData = await getCafeData(cafeId);
      const userData = await getUserData(req.user.id);

      // Process all bookings
      for (const bookingDoc of bookingDocs) {
        const bookingData = bookingDoc.data();
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
        createdBookings.push(booking);
      }

      // Create community post for the first booking (representative of the group)
      console.log('🎫 [BOOKING] Creating community post...');
      try {
        await createCommunityPost(createdBookings[0], cafeData, userData);
        console.log('🎫 [BOOKING] Community post created successfully');
      } catch (communityError) {
        // Don't fail booking if community post fails
        console.error('🎫 [BOOKING] Failed to create community post:', communityError);
      }

      // Send notification to cafe owner (for the group booking)
      console.log('🎫 [BOOKING] Sending notification to cafe owner...');
      try {
        await notificationService.sendBookingNotification(
          createdBookings[0],
          cafeData,
          userData
        );
        console.log('🎫 [BOOKING] Notification sent successfully');
      } catch (notificationError) {
        // Don't fail booking if notification fails
        console.error('🎫 [BOOKING] Failed to send notification:', notificationError);
      }

      console.log('🎫 [BOOKING] ✅ BOOKINGS CREATED SUCCESSFULLY');
      console.log('🎫 [BOOKING] Number of bookings:', createdBookings.length);
      console.log('🎫 [BOOKING] Total Amount (all PCs):', totalAmountForAllPcs);
      console.log('🎫 [BOOKING] ========================================');

      // Update the primary booking's totalAmount to reflect the total for all PCs
      // This is the amount that will be charged for the entire group booking
      const primaryBooking = {
        ...createdBookings[0],
        totalAmount: totalAmountForAllPcs // Use the combined total for payment
      };

      // Return the first booking as primary (for payment), but include all booking IDs
      res.status(201).json({
        success: true,
        message: numberOfPcs > 1 
          ? `${numberOfPcs} bookings created successfully` 
          : 'Booking confirmed successfully',
        data: {
          booking: primaryBooking, // Primary booking for payment (with total for all PCs)
          bookings: createdBookings, // All bookings
          stationNumbers: createdBookings.map(b => b.stationNumber), // All station numbers
          billing: {
            stationType,
            consoleType: stationType === 'console' ? consoleType : null,
            durationHours,
            hourlyRate,
            totalAmount: totalAmountForAllPcs, // Combined total for all PCs
            numberOfPcs: numberOfPcs
          }
        }
      });
    } catch (error) {
      if (error.message && error.message.startsWith('CONFLICT:')) {
        console.log('🎫 [BOOKING] ❌ CONFLICT ERROR:', error.message);
        return res.status(409).json({
          success: false,
          message: error.message.replace('CONFLICT:', '')
        });
      }
      throw error;
    }
  } catch (error) {
    console.error('🎫 [BOOKING] ❌ CREATE BOOKING ERROR:', error);
    console.error('🎫 [BOOKING] Error stack:', error.stack);
    console.error('🎫 [BOOKING] Request ID:', requestId);
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
  const requestId = `AVAIL-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  try {
    console.log('🎫 [AVAILABILITY] ========================================');
    console.log('🎫 [AVAILABILITY] === GET AVAILABLE STATIONS REQUEST ===');
    console.log('🎫 [AVAILABILITY] Request ID:', requestId);
    console.log('🎫 [AVAILABILITY] Query params:', req.query);
    
    const { cafeId, stationType, consoleType, bookingDate, startTime, endTime } = req.query;

    if (!cafeId || !stationType || !bookingDate || !startTime || !endTime) {
      console.log('🎫 [AVAILABILITY] ERROR: Missing required fields');
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: cafeId, stationType, bookingDate, startTime, endTime'
      });
    }

    console.log('🎫 [AVAILABILITY] Checking availability for:', {
      cafeId,
      stationType,
      consoleType,
      bookingDate,
      startTime,
      endTime
    });

    const cafe = await getCafeData(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Validate time is within cafe hours with proper midnight crossing support
    console.log('🎫 [AVAILABILITY] ========================================');
    console.log('🎫 [AVAILABILITY] 🕐 PARSING TIMES');
    console.log('🎫 [AVAILABILITY] Raw startTime from query:', startTime);
    console.log('🎫 [AVAILABILITY] Raw endTime from query:', endTime);
    console.log('🎫 [AVAILABILITY] Raw openingTime from cafe:', cafe.openingTime);
    console.log('🎫 [AVAILABILITY] Raw closingTime from cafe:', cafe.closingTime);
    
    let bookingStartMins = timeToMinutes(startTime);
    let bookingEndMins = timeToMinutes(endTime);
    const cafeOpenMins = timeToMinutes(cafe.openingTime);
    let cafeCloseMins = timeToMinutes(cafe.closingTime);
    
    console.log('🎫 [AVAILABILITY] Parsed times (in minutes):');
    console.log('🎫 [AVAILABILITY] - bookingStartMins:', bookingStartMins, `(${Math.floor(bookingStartMins / 60)}:${String(bookingStartMins % 60).padStart(2, '0')})`);
    console.log('🎫 [AVAILABILITY] - bookingEndMins:', bookingEndMins, `(${Math.floor(bookingEndMins / 60)}:${String(bookingEndMins % 60).padStart(2, '0')})`);
    console.log('🎫 [AVAILABILITY] - cafeOpenMins:', cafeOpenMins, `(${Math.floor(cafeOpenMins / 60)}:${String(cafeOpenMins % 60).padStart(2, '0')})`);
    console.log('🎫 [AVAILABILITY] - cafeCloseMins:', cafeCloseMins, `(${Math.floor(cafeCloseMins / 60)}:${String(cafeCloseMins % 60).padStart(2, '0')})`);
    
    // Check if 12:00 is being interpreted correctly
    if (startTime === '12:00' || startTime.startsWith('12:00')) {
      console.log('🎫 [AVAILABILITY] ⚠️ START TIME IS 12:00 - VERIFYING:');
      console.log('🎫 [AVAILABILITY] - Raw string:', startTime);
      console.log('🎫 [AVAILABILITY] - Parsed minutes:', bookingStartMins);
      console.log('🎫 [AVAILABILITY] - Should be 720 minutes (12:00 PM / NOON)');
      console.log('🎫 [AVAILABILITY] - Is correct (720)?', bookingStartMins === 720);
      if (bookingStartMins !== 720) {
        console.log('🎫 [AVAILABILITY] ❌ ERROR: 12:00 parsed incorrectly!');
      } else {
        console.log('🎫 [AVAILABILITY] ✅ 12:00 parsed correctly as NOON (12:00 PM)');
      }
    }
    console.log('🎫 [AVAILABILITY] ========================================');

    // Detect if cafe crosses midnight (e.g., 09:00 to 01:00)
    const crossesMidnight = cafeCloseMins < cafeOpenMins;
    
    if (crossesMidnight) {
      // Adjust closing time to next day
      cafeCloseMins += 24 * 60;
      
      // If booking start is after midnight (e.g., 00:30 = 30 mins)
      // and less than opening time, it's likely an after-midnight booking
      if (bookingStartMins < cafeOpenMins) {
        bookingStartMins += 24 * 60;
      }
      
      // If booking end is less than adjusted start, it needs adjustment too
      if (bookingEndMins < timeToMinutes(startTime)) {
        bookingEndMins += 24 * 60;
      } else if (bookingStartMins >= 24 * 60 && bookingEndMins < bookingStartMins) {
        // Both start and end are after midnight
        bookingEndMins += 24 * 60;
      }
    } else {
      // Normal same-day operation - adjust end if it crosses midnight
      if (bookingEndMins < bookingStartMins) {
        bookingEndMins += 24 * 60;
      }
    }

    // Now validate with adjusted times
    if (bookingStartMins < cafeOpenMins) {
      const formatTime = (t) => t ? t.substring(0, 5) : '';
      return res.status(400).json({
        success: false,
        message: `Time must be within cafe hours: ${formatTime(cafe.openingTime)} - ${formatTime(cafe.closingTime)}`,
        availableStations: [],
        totalStations: 0
      });
    }

    if (bookingEndMins > cafeCloseMins) {
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

    console.log('🎫 [AVAILABILITY] Calculating available stations...');
    const availableStations = await getAvailableStations(
      cafeId, stationType, consoleType, bookingDate, startTime, endTime, maxStations
    );

    console.log('🎫 [AVAILABILITY] Available stations found:', availableStations);
    console.log('🎫 [AVAILABILITY] Available count:', availableStations.length);
    console.log('🎫 [AVAILABILITY] First available:', availableStations.length > 0 ? availableStations[0] : null);

    const durationHours = calculateDuration(startTime, endTime);
    
    console.log('🎫 [AVAILABILITY] ========================================');
    console.log('🎫 [AVAILABILITY] 📊 DURATION CALCULATION');
    console.log('🎫 [AVAILABILITY] Start Time:', startTime, `(${bookingStartMins} minutes = ${Math.floor(bookingStartMins / 60)}:${String(bookingStartMins % 60).padStart(2, '0')})`);
    console.log('🎫 [AVAILABILITY] End Time:', endTime, `(${bookingEndMins} minutes = ${Math.floor(bookingEndMins / 60)}:${String(bookingEndMins % 60).padStart(2, '0')})`);
    console.log('🎫 [AVAILABILITY] Duration Hours:', durationHours);
    console.log('🎫 [AVAILABILITY] Duration Minutes:', durationHours * 60);
    
    // Verify 12:00 interpretation
    if (startTime === '12:00' || startTime.startsWith('12:00')) {
      console.log('🎫 [AVAILABILITY] ⚠️ VERIFICATION: Start time is 12:00');
      console.log('🎫 [AVAILABILITY] - Raw string:', startTime);
      console.log('🎫 [AVAILABILITY] - Parsed as:', bookingStartMins, 'minutes');
      console.log('🎫 [AVAILABILITY] - This equals:', Math.floor(bookingStartMins / 60), 'hours and', bookingStartMins % 60, 'minutes');
      console.log('🎫 [AVAILABILITY] - Should be 720 minutes (12:00 PM / NOON)');
      console.log('🎫 [AVAILABILITY] - Is correct?', bookingStartMins === 720 ? '✅ YES (12:00 PM)' : '❌ NO (ERROR!)');
    }
    console.log('🎫 [AVAILABILITY] ========================================');
    
    const hourlyRate = getHourlyRate(cafe, stationType, consoleType);
    // Calculate exact amount with decimal precision (no rounding)
    const estimatedTotal = parseFloat((durationHours * hourlyRate).toFixed(2));

    console.log('🎫 [AVAILABILITY] Pricing calculated:', {
      durationHours,
      hourlyRate,
      estimatedTotal
    });

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
          estimatedTotal
        }
      }
    };

    console.log('🎫 [AVAILABILITY] ✅ RESPONSE SENT');
    console.log('🎫 [AVAILABILITY] ========================================');
    res.json(response);
  } catch (error) {
    console.error('🎫 [AVAILABILITY] ❌ ERROR:', error);
    console.error('🎫 [AVAILABILITY] Error stack:', error.stack);
    console.error('🎫 [AVAILABILITY] Request ID:', requestId);
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

    // If this is a group booking, fetch all bookings in the group
    let groupBookings = null;
    if (booking.groupBookingId) {
      console.log('🔍 [GET_BOOKING] Group booking detected. groupBookingId:', booking.groupBookingId);
      let groupBookingsQuery;
      try {
        // Try with orderBy first (requires composite index)
        groupBookingsQuery = await db.collection('bookings')
          .where('groupBookingId', '==', booking.groupBookingId)
          .orderBy('groupBookingIndex', 'asc')
          .get();
        console.log('🔍 [GET_BOOKING] Found', groupBookingsQuery.docs.length, 'bookings in group (with orderBy)');
      } catch (indexError) {
        console.log('🔍 [GET_BOOKING] Index error, trying without orderBy:', indexError.message);
        // Fallback: Query without orderBy and sort client-side
        groupBookingsQuery = await db.collection('bookings')
          .where('groupBookingId', '==', booking.groupBookingId)
          .get();
        console.log('🔍 [GET_BOOKING] Found', groupBookingsQuery.docs.length, 'bookings in group (without orderBy)');
      }

      groupBookings = groupBookingsQuery.docs.map(doc => {
        const groupBookingData = doc.data();
        return {
          id: doc.id,
          ...groupBookingData,
          createdAt: groupBookingData.createdAt?.toDate ? groupBookingData.createdAt.toDate().toISOString() : groupBookingData.createdAt,
          updatedAt: groupBookingData.updatedAt?.toDate ? groupBookingData.updatedAt.toDate().toISOString() : groupBookingData.updatedAt,
          cafe: booking.cafe,
          user: booking.user
        };
      });

      console.log('🔍 [GET_BOOKING] Processed', groupBookings.length, 'group bookings');

      // Sort client-side if orderBy wasn't used or if we want to ensure proper ordering
      if (groupBookings.length > 0 && groupBookings[0].groupBookingIndex != null) {
        groupBookings.sort((a, b) => {
          const indexA = a.groupBookingIndex ?? 0;
          const indexB = b.groupBookingIndex ?? 0;
          return indexA - indexB;
        });
        console.log('🔍 [GET_BOOKING] Sorted group bookings by index');
      }
    } else {
      console.log('🔍 [GET_BOOKING] Not a group booking (no groupBookingId)');
    }

    res.json({
      success: true,
      data: { 
        booking,
        groupBookings: groupBookings || null
      }
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
          json: (data) => {},
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
    } catch (communityError) {
      // Don't fail cancellation if community post deletion fails
      console.error('Failed to delete community post:', communityError);
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
    // Calculate exact amount with decimal precision (no rounding)
    const estimatedCost = parseFloat((durationHours * hourlyRate).toFixed(2));
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
