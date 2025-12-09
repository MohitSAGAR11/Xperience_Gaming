const { Op } = require('sequelize');
const { Cafe, User, Booking } = require('../models');
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
      ownerId: req.user.id
    };

    const cafe = await Cafe.create(cafeData);

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

    const where = { isActive: true };

    // Filter by city
    if (city) {
      where.city = { [Op.iLike]: `%${city}%` };
    }

    // Filter by hourly rate range
    if (minRate || maxRate) {
      where.hourlyRate = {};
      if (minRate) where.hourlyRate[Op.gte] = parseFloat(minRate);
      if (maxRate) where.hourlyRate[Op.lte] = parseFloat(maxRate);
    }

    // Search by game in availableGames array
    if (game) {
      where.availableGames = { [Op.contains]: [game] };
    }

    // Hybrid search: search by cafe name OR game title
    if (search) {
      where[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { availableGames: { [Op.contains]: [search] } }
      ];
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: cafes } = await Cafe.findAndCountAll({
      where,
      include: [{
        model: User,
        as: 'owner',
        attributes: ['id', 'name', 'email']
      }],
      limit: parseInt(limit),
      offset,
      order: [['createdAt', 'DESC']]
    });

    res.json({
      success: true,
      data: {
        cafes,
        pagination: {
          total: count,
          page: parseInt(page),
          pages: Math.ceil(count / parseInt(limit)),
          limit: parseInt(limit)
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
    const where = { isActive: true };
    
    // Optional game filter
    if (game) {
      where.availableGames = { [Op.contains]: [game] };
    }

    const allCafes = await Cafe.findAll({
      where,
      include: [{
        model: User,
        as: 'owner',
        attributes: ['id', 'name']
      }]
    });

    // Filter cafes by distance using Haversine formula
    const nearbyCafes = allCafes
      .map(cafe => {
        const distance = haversineDistance(
          lat, lon,
          parseFloat(cafe.latitude),
          parseFloat(cafe.longitude)
        );
        return {
          ...cafe.toJSON(),
          distance: Math.round(distance * 100) / 100 // Round to 2 decimal places
        };
      })
      .filter(cafe => cafe.distance <= searchRadius)
      .sort((a, b) => a.distance - b.distance);

    res.json({
      success: true,
      data: {
        cafes: nearbyCafes,
        searchParams: {
          latitude: lat,
          longitude: lon,
          radiusKm: searchRadius
        },
        total: nearbyCafes.length
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
    const cafe = await Cafe.findByPk(req.params.id, {
      include: [{
        model: User,
        as: 'owner',
        attributes: ['id', 'name', 'email', 'phone']
      }]
    });

    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

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
    const cafe = await Cafe.findByPk(req.params.id);

    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Check ownership
    if (cafe.ownerId !== req.user.id) {
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
      'consoles', 'totalConsoles',
      'photos', 'amenities', 'availableGames', 'isActive'
    ];

    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        cafe[field] = req.body[field];
      }
    });

    await cafe.save();

    res.json({
      success: true,
      message: 'Cafe updated successfully',
      data: { cafe }
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
    const cafe = await Cafe.findByPk(req.params.id);

    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Check ownership
    if (cafe.ownerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this cafe'
      });
    }

    await cafe.destroy();

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
    const cafes = await Cafe.findAll({
      where: { ownerId: req.user.id },
      order: [['createdAt', 'DESC']]
    });

    res.json({
      success: true,
      data: { cafes, total: cafes.length }
    });
  } catch (error) {
    console.error('Get my cafes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Get available time slots for a cafe on a specific date (PC and Consoles)
 * @route   GET /api/cafes/:id/availability
 * @access  Public
 */
const getCafeAvailability = async (req, res) => {
  try {
    const { date } = req.query;
    const cafeId = req.params.id;

    if (!date) {
      return res.status(400).json({
        success: false,
        message: 'Date is required'
      });
    }

    const cafe = await Cafe.findByPk(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Get all bookings for the cafe on that date
    const bookings = await Booking.findAll({
      where: {
        cafeId,
        bookingDate: date,
        status: { [Op.in]: ['pending', 'confirmed'] }
      },
      attributes: ['stationType', 'consoleType', 'stationNumber', 'startTime', 'endTime']
    });

    // Create PC availability map
    const pcAvailability = {};
    for (let i = 1; i <= cafe.totalPcStations; i++) {
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

    // Create Console availability map per console type
    const consoleAvailability = {};
    const consoleTypes = ['ps5', 'ps4', 'xbox_series_x', 'xbox_series_s', 'xbox_one', 'nintendo_switch'];
    
    for (const consoleType of consoleTypes) {
      const consoleInfo = cafe.consoles?.[consoleType];
      if (consoleInfo && consoleInfo.quantity > 0) {
        consoleAvailability[consoleType] = {
          quantity: consoleInfo.quantity,
          hourlyRate: consoleInfo.hourlyRate,
          games: consoleInfo.games || [],
          units: {}
        };
        
        for (let i = 1; i <= consoleInfo.quantity; i++) {
          consoleAvailability[consoleType].units[i] = {
            unit: i,
            bookedSlots: bookings
              .filter(b => b.stationType === 'console' && b.consoleType === consoleType && b.stationNumber === i)
              .map(b => ({
                startTime: b.startTime,
                endTime: b.endTime
              }))
          };
        }
      }
    }

    res.json({
      success: true,
      data: {
        cafeId,
        date,
        openingTime: cafe.openingTime,
        closingTime: cafe.closingTime,
        pc: {
          totalStations: cafe.totalPcStations,
          hourlyRate: cafe.pcHourlyRate || cafe.hourlyRate,
          availability: pcAvailability
        },
        consoles: consoleAvailability
      }
    });
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

