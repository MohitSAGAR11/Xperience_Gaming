const { db } = require('../config/firebase');
const { validationResult } = require('express-validator');

/**
 * Calculate distance between two points using Haversine formula
 * @param {number} lat1 - Latitude of point 1
 * @param {number} lon1 - Longitude of point 1
 * @param {number} lat2 - Latitude of point 2
 * @param {number} lon2 - Longitude of point 2
 * @returns {number} Distance in kilometers
 */
const haversineDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth's radius in kilometers
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * 
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

const toRad = (deg) => deg * (Math.PI / 180);

/**
 * Helper function to convert Firestore timestamp to ISO string
 */
const convertTimestamp = (timestamp) => {
  if (!timestamp) return null;
  if (timestamp.toDate) return timestamp.toDate().toISOString();
  if (timestamp instanceof Date) return timestamp.toISOString();
  return timestamp;
};

/**
 * Helper function to get owner data
 */
const getOwnerData = async (ownerId) => {
  try {
    const ownerDoc = await db.collection('users').doc(ownerId).get();
    if (!ownerDoc.exists) return null;
    return {
      id: ownerDoc.id,
      name: ownerDoc.data().name,
      email: ownerDoc.data().email,
      phone: ownerDoc.data().phone
    };
  } catch (error) {
    console.error('Error fetching owner:', error);
    return null;
  }
};

/**
 * @desc    Create a new cafe (Owner only)
 * @route   POST /api/cafes
 * @access  Private/Owner
 */
const createCafe = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const cafeData = {
      ...req.body,
      ownerId: req.user.id,
      isActive: true,
      rating: 0,
      totalReviews: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    console.log('📍 Creating cafe with mapsLink:', cafeData.mapsLink);

    const docRef = await db.collection('cafes').add(cafeData);
    const cafeDoc = await docRef.get();
    const cafeDocData = cafeDoc.data();
    const cafe = {
      id: cafeDoc.id,
      ...cafeDocData,
      createdAt: convertTimestamp(cafeDocData.createdAt),
      updatedAt: convertTimestamp(cafeDocData.updatedAt)
    };

    console.log('📍 Cafe created, mapsLink saved:', cafe.mapsLink);

    res.status(201).json({
      success: true,
      message: 'Cafe created successfully',
      data: { cafe }
    });
  } catch (error) {
    console.error('Create cafe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while creating cafe',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Get all cafes with optional filters
 * @route   GET /api/cafes
 * @access  Public
 */
const getAllCafes = async (req, res) => {
  try {
    const { 
      city, 
      minRate, 
      maxRate, 
      game,
      search,
      page = 1, 
      limit = 10 
    } = req.query;

    let query = db.collection('cafes').where('isActive', '==', true);

    // Filter by city (Firestore supports exact match)
    if (city) {
      query = query.where('city', '==', city);
    }

    // Get all cafes (we'll filter client-side for complex queries)
    const snapshot = await query.get();
    let cafes = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: convertTimestamp(doc.data().createdAt),
      updatedAt: convertTimestamp(doc.data().updatedAt)
    }));

    // Client-side filtering for complex queries
    if (minRate || maxRate) {
      cafes = cafes.filter(cafe => {
        const rate = cafe.pcHourlyRate || cafe.hourlyRate || 0;
        if (minRate && rate < parseFloat(minRate)) return false;
        if (maxRate && rate > parseFloat(maxRate)) return false;
        return true;
      });
    }

    // Filter by game in availableGames or pcGames array
    if (game) {
      cafes = cafes.filter(cafe => {
        const allGames = [
          ...(cafe.availableGames || []),
          ...(cafe.pcGames || [])
        ];
        return allGames.some(g => g.toLowerCase().includes(game.toLowerCase()));
      });
    }

    // Search by cafe name or game title
    if (search) {
      const searchLower = search.toLowerCase();
      cafes = cafes.filter(cafe => {
        const nameMatch = cafe.name?.toLowerCase().includes(searchLower);
        const allGames = [
          ...(cafe.availableGames || []),
          ...(cafe.pcGames || [])
        ];
        const gameMatch = allGames.some(g => g.toLowerCase().includes(searchLower));
        return nameMatch || gameMatch;
      });
    }

    // Sort by createdAt (newest first)
    cafes.sort((a, b) => {
      const dateA = a.createdAt || new Date(0);
      const dateB = b.createdAt || new Date(0);
      return dateB - dateA;
    });

    // Pagination
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    const total = cafes.length;
    const paginatedCafes = cafes.slice(offset, offset + limitNum);

    // Fetch owner data for each cafe
    const cafesWithOwner = await Promise.all(
      paginatedCafes.map(async (cafe) => {
        const owner = await getOwnerData(cafe.ownerId);
        return {
          ...cafe,
          owner: owner || { id: cafe.ownerId }
        };
      })
    );

    res.json({
      success: true,
      data: {
        cafes: cafesWithOwner,
        pagination: {
          total,
          page: pageNum,
          pages: Math.ceil(total / limitNum),
          limit: limitNum
        }
      }
    });
  } catch (error) {
    console.error('Get cafes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching cafes'
    });
  }
};

/**
 * @desc    Find cafes near a location (Geospatial search)
 * @route   GET /api/cafes/nearby
 * @access  Public
 */
const getNearbyCafes = async (req, res) => {
  try {
    const { latitude, longitude, radius = 10, game } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: 'Latitude and longitude are required'
      });
    }

    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);
    const searchRadius = parseFloat(radius); // in kilometers

    // Get all active cafes
    const snapshot = await db.collection('cafes')
      .where('isActive', '==', true)
      .get();

    let cafes = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: convertTimestamp(doc.data().createdAt),
      updatedAt: convertTimestamp(doc.data().updatedAt)
    }));

    // Filter by game if provided
    if (game) {
      cafes = cafes.filter(cafe => {
        const allGames = [
          ...(cafe.availableGames || []),
          ...(cafe.pcGames || [])
        ];
        return allGames.some(g => g.toLowerCase().includes(game.toLowerCase()));
      });
    }

    // Filter cafes by distance using Haversine formula
    const nearbyCafes = cafes
      .map(cafe => {
        const cafeLat = parseFloat(cafe.latitude);
        const cafeLon = parseFloat(cafe.longitude);
        const distance = haversineDistance(lat, lon, cafeLat, cafeLon);
        return {
          ...cafe,
          distance: Math.round(distance * 100) / 100 // Round to 2 decimal places
        };
      })
      .filter(cafe => cafe.distance <= searchRadius)
      .sort((a, b) => a.distance - b.distance);

    // Fetch owner data
    const cafesWithOwner = await Promise.all(
      nearbyCafes.map(async (cafe) => {
        const owner = await getOwnerData(cafe.ownerId);
        return {
          ...cafe,
          owner: owner || { id: cafe.ownerId, name: 'Unknown' }
        };
      })
    );

    res.json({
      success: true,
      data: {
        cafes: cafesWithOwner,
        searchParams: {
          latitude: lat,
          longitude: lon,
          radiusKm: searchRadius
        },
        total: cafesWithOwner.length
      }
    });
  } catch (error) {
    console.error('Get nearby cafes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while searching nearby cafes'
    });
  }
};

/**
 * @desc    Get single cafe by ID
 * @route   GET /api/cafes/:id
 * @access  Public
 */
const getCafeById = async (req, res) => {
  try {
    const cafeDoc = await db.collection('cafes').doc(req.params.id).get();

    if (!cafeDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    const cafeData = cafeDoc.data();
    const cafe = {
      id: cafeDoc.id,
      ...cafeData,
      createdAt: convertTimestamp(cafeData.createdAt),
      updatedAt: convertTimestamp(cafeData.updatedAt)
    };

    // Fetch owner data
    const owner = await getOwnerData(cafe.ownerId);
    cafe.owner = owner || { id: cafe.ownerId };

    res.json({
      success: true,
      data: { cafe }
    });
  } catch (error) {
    console.error('Get cafe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Update cafe (Owner only - own cafe)
 * @route   PUT /api/cafes/:id
 * @access  Private/Owner
 */
const updateCafe = async (req, res) => {
  try {
    const cafeDoc = await db.collection('cafes').doc(req.params.id).get();

    if (!cafeDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    const cafeData = cafeDoc.data();

    // Check ownership
    if (cafeData.ownerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this cafe'
      });
    }

    // Fields that can be updated
    const allowedUpdates = [
      'name', 'description', 'address', 'city', 'state', 'zipCode',
      'latitude', 'longitude', 'hourlyRate', 'openingTime', 'closingTime',
      'totalPcStations', 'pcHourlyRate', 'pcSpecs', 'pcGames',
      'photos', 'amenities', 'availableGames', 'isActive', 'mapsLink'
    ];

    const updateData = {
      updatedAt: new Date()
    };

    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        updateData[field] = req.body[field];
      }
    });

    console.log('📍 Updating cafe with mapsLink:', updateData.mapsLink);

    await db.collection('cafes').doc(req.params.id).update(updateData);

    // Get updated cafe
    const updatedDoc = await db.collection('cafes').doc(req.params.id).get();
    const updatedCafe = {
      id: updatedDoc.id,
      ...updatedDoc.data(),
      createdAt: convertTimestamp(updatedDoc.data().createdAt),
      updatedAt: convertTimestamp(updatedDoc.data().updatedAt)
    };

    res.json({
      success: true,
      message: 'Cafe updated successfully',
      data: { cafe: updatedCafe }
    });
  } catch (error) {
    console.error('Update cafe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Delete cafe (Owner only - own cafe)
 * @route   DELETE /api/cafes/:id
 * @access  Private/Owner
 */
const deleteCafe = async (req, res) => {
  try {
    const cafeDoc = await db.collection('cafes').doc(req.params.id).get();

    if (!cafeDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    const cafeData = cafeDoc.data();

    // Check ownership
    if (cafeData.ownerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this cafe'
      });
    }

    // Soft delete by setting isActive to false
    await db.collection('cafes').doc(req.params.id).update({
      isActive: false,
      updatedAt: new Date()
    });

    res.json({
      success: true,
      message: 'Cafe deleted successfully'
    });
  } catch (error) {
    console.error('Delete cafe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Get owner's cafes
 * @route   GET /api/cafes/owner/my-cafes
 * @access  Private/Owner
 */
const getMyCafes = async (req, res) => {
  try {
    let snapshot;
    let needsClientSort = false;

    try {
      // Try with orderBy first (requires composite index)
      snapshot = await db.collection('cafes')
        .where('ownerId', '==', req.user.id)
        .orderBy('createdAt', 'desc')
        .get();
    } catch (indexError) {
      // Fallback: If index doesn't exist, query without orderBy and sort client-side
      console.log('Index not ready, using fallback query for getMyCafes');
      snapshot = await db.collection('cafes')
        .where('ownerId', '==', req.user.id)
        .get();
      needsClientSort = true;
    }

    let cafes = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: convertTimestamp(doc.data().createdAt),
      updatedAt: convertTimestamp(doc.data().updatedAt)
    }));

    // Sort client-side if index wasn't available
    if (needsClientSort) {
      cafes.sort((a, b) => {
        const dateA = a.createdAt || new Date(0);
        const dateB = b.createdAt || new Date(0);
        return dateB - dateA; // Descending order
      });
    }

    res.json({
      success: true,
      data: { cafes, total: cafes.length }
    });
  } catch (error) {
    console.error('Get my cafes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching your cafes'
    });
  }
};

/**
 * @desc    Get available time slots for a cafe on a specific date (PC only)
 * @route   GET /api/cafes/:id/availability
 * @access  Public
 */
const getCafeAvailability = async (req, res) => {
  try {
    const { date } = req.query;
    const cafeId = req.params.id;

    console.log('📅 [GET_AVAILABILITY] Request received');
    console.log('📅 [GET_AVAILABILITY] Cafe ID:', cafeId);
    console.log('📅 [GET_AVAILABILITY] Date param:', date);
    console.log('📅 [GET_AVAILABILITY] Query params:', req.query);

    if (!date) {
      console.log('📅 [GET_AVAILABILITY] ERROR: Date parameter missing!');
      return res.status(400).json({
        success: false,
        message: 'Date is required'
      });
    }

    console.log('📅 [GET_AVAILABILITY] Fetching cafe from Firestore...');
    const cafeDoc = await db.collection('cafes').doc(cafeId).get();
    
    if (!cafeDoc.exists) {
      console.log('📅 [GET_AVAILABILITY] ERROR: Cafe not found!');
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    const cafe = {
      id: cafeDoc.id,
      ...cafeDoc.data()
    };
    console.log('📅 [GET_AVAILABILITY] Cafe found:', cafe.name);
    console.log('📅 [GET_AVAILABILITY] Total PC stations:', cafe.totalPcStations);

    // Get all bookings for the cafe on that date
    console.log('📅 [GET_AVAILABILITY] Fetching bookings...');
    const bookingsSnapshot = await db.collection('bookings')
      .where('cafeId', '==', cafeId)
      .where('bookingDate', '==', date)
      .get();

    const bookings = bookingsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })).filter(b => ['pending', 'confirmed'].includes(b.status));
    console.log('📅 [GET_AVAILABILITY] Found', bookings.length, 'bookings');

    // Create PC availability map
    const pcAvailability = {};
    const totalPcStations = cafe.totalPcStations || 0;
    console.log('📅 [GET_AVAILABILITY] Building PC availability map...');
    
    for (let i = 1; i <= totalPcStations; i++) {
      pcAvailability[i] = {
        station: i,
        bookedSlots: bookings
          .filter(b => b.stationType === 'pc' && b.stationNumber === i)
          .map(b => ({
            startTime: b.startTime,
            endTime: b.endTime
          }))
      };
    }

    console.log('📅 [GET_AVAILABILITY] Sending response...');
    const response = {
      success: true,
      data: {
        cafeId,
        date,
        openingTime: cafe.openingTime,
        closingTime: cafe.closingTime,
        pc: {
          totalStations: totalPcStations,
          hourlyRate: cafe.pcHourlyRate || cafe.hourlyRate,
          availability: pcAvailability
        }
      }
    };
    console.log('📅 [GET_AVAILABILITY] Response data:', JSON.stringify(response, null, 2));
    res.json(response);
    console.log('📅 [GET_AVAILABILITY] Response sent successfully!');
  } catch (error) {
    console.error('Get availability error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

module.exports = {
  createCafe,
  getAllCafes,
  getNearbyCafes,
  getCafeById,
  updateCafe,
  deleteCafe,
  getMyCafes,
  getCafeAvailability
};
