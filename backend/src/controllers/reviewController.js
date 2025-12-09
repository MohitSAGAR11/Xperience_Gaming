const { Review, Cafe, User, Booking } = require('../models');
const { Op } = require('sequelize');
const { sequelize } = require('../config/db');

/**
 * @desc    Create a review for a cafe
 * @route   POST /api/reviews
 * @access  Private (Client only)
 */
const createReview = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const { cafeId, rating, comment, title } = req.body;
    const userId = req.user.id;

    // Validate rating
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5'
      });
    }

    // Check if cafe exists
    const cafe = await Cafe.findByPk(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Check if user has already reviewed this cafe
    const existingReview = await Review.findOne({
      where: { userId, cafeId }
    });

    if (existingReview) {
      return res.status(400).json({
        success: false,
        message: 'You have already reviewed this cafe. You can update your existing review.'
      });
    }

    // Optional: Check if user has visited (booked) the cafe
    const hasBooking = await Booking.findOne({
      where: {
        userId,
        cafeId,
        status: 'completed'
      }
    });

    // Create the review
    const review = await Review.create({
      userId,
      cafeId,
      rating,
      comment: comment || null,
      title: title || null
    }, { transaction });

    // Update cafe's average rating and total reviews
    const reviewStats = await Review.findOne({
      where: { cafeId, isVisible: true },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('rating')), 'avgRating'],
        [sequelize.fn('COUNT', sequelize.col('id')), 'totalReviews']
      ],
      transaction
    });

    await Cafe.update({
      rating: parseFloat(reviewStats.dataValues.avgRating) || 0,
      totalReviews: parseInt(reviewStats.dataValues.totalReviews) || 0
    }, {
      where: { id: cafeId },
      transaction
    });

    await transaction.commit();

    // Fetch the created review with user info
    const createdReview = await Review.findByPk(review.id, {
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'avatar']
      }]
    });

    res.status(201).json({
      success: true,
      message: 'Review submitted successfully',
      data: {
        review: createdReview,
        hasVerifiedBooking: !!hasBooking
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Create review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error creating review',
      error: error.message
    });
  }
};

/**
 * @desc    Get all reviews for a cafe
 * @route   GET /api/reviews/cafe/:cafeId
 * @access  Public
 */
const getCafeReviews = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const { page = 1, limit = 10, sort = 'recent' } = req.query;

    // Build sort order
    let order = [['createdAt', 'DESC']]; // Default: most recent
    if (sort === 'highest') order = [['rating', 'DESC']];
    if (sort === 'lowest') order = [['rating', 'ASC']];
    if (sort === 'helpful') order = [['helpfulCount', 'DESC']];

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows: reviews } = await Review.findAndCountAll({
      where: {
        cafeId,
        isVisible: true
      },
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'avatar']
      }],
      order,
      limit: parseInt(limit),
      offset
    });

    // Get rating distribution
    const ratingDistribution = await Review.findAll({
      where: { cafeId, isVisible: true },
      attributes: [
        'rating',
        [sequelize.fn('COUNT', sequelize.col('rating')), 'count']
      ],
      group: ['rating'],
      raw: true
    });

    // Format distribution
    const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    ratingDistribution.forEach(r => {
      distribution[r.rating] = parseInt(r.count);
    });

    res.json({
      success: true,
      data: {
        reviews,
        ratingDistribution: distribution,
        pagination: {
          total: count,
          page: parseInt(page),
          pages: Math.ceil(count / parseInt(limit)),
          limit: parseInt(limit)
        }
      }
    });

  } catch (error) {
    console.error('Get cafe reviews error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching reviews',
      error: error.message
    });
  }
};

/**
 * @desc    Update a review
 * @route   PUT /api/reviews/:id
 * @access  Private (Review owner only)
 */
const updateReview = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const { id } = req.params;
    const { rating, comment, title } = req.body;
    const userId = req.user.id;

    const review = await Review.findByPk(id);

    if (!review) {
      return res.status(404).json({
        success: false,
        message: 'Review not found'
      });
    }

    // Check ownership
    if (review.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this review'
      });
    }

    // Validate rating if provided
    if (rating && (rating < 1 || rating > 5)) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5'
      });
    }

    // Update review
    await review.update({
      rating: rating || review.rating,
      comment: comment !== undefined ? comment : review.comment,
      title: title !== undefined ? title : review.title
    }, { transaction });

    // Update cafe's average rating
    const reviewStats = await Review.findOne({
      where: { cafeId: review.cafeId, isVisible: true },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('rating')), 'avgRating'],
        [sequelize.fn('COUNT', sequelize.col('id')), 'totalReviews']
      ],
      transaction
    });

    await Cafe.update({
      rating: parseFloat(reviewStats.dataValues.avgRating) || 0,
      totalReviews: parseInt(reviewStats.dataValues.totalReviews) || 0
    }, {
      where: { id: review.cafeId },
      transaction
    });

    await transaction.commit();

    // Fetch updated review
    const updatedReview = await Review.findByPk(id, {
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'avatar']
      }]
    });

    res.json({
      success: true,
      message: 'Review updated successfully',
      data: { review: updatedReview }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Update review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating review',
      error: error.message
    });
  }
};

/**
 * @desc    Delete a review
 * @route   DELETE /api/reviews/:id
 * @access  Private (Review owner or Admin)
 */
const deleteReview = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const review = await Review.findByPk(id);

    if (!review) {
      return res.status(404).json({
        success: false,
        message: 'Review not found'
      });
    }

    // Check ownership
    if (review.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this review'
      });
    }

    const cafeId = review.cafeId;
    await review.destroy({ transaction });

    // Update cafe's average rating
    const reviewStats = await Review.findOne({
      where: { cafeId, isVisible: true },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('rating')), 'avgRating'],
        [sequelize.fn('COUNT', sequelize.col('id')), 'totalReviews']
      ],
      transaction
    });

    await Cafe.update({
      rating: parseFloat(reviewStats.dataValues.avgRating) || 0,
      totalReviews: parseInt(reviewStats.dataValues.totalReviews) || 0
    }, {
      where: { id: cafeId },
      transaction
    });

    await transaction.commit();

    res.json({
      success: true,
      message: 'Review deleted successfully'
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Delete review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting review',
      error: error.message
    });
  }
};

/**
 * @desc    Get user's reviews
 * @route   GET /api/reviews/my-reviews
 * @access  Private
 */
const getMyReviews = async (req, res) => {
  try {
    const userId = req.user.id;

    const reviews = await Review.findAll({
      where: { userId },
      include: [{
        model: Cafe,
        as: 'cafe',
        attributes: ['id', 'name', 'city', 'photos']
      }],
      order: [['createdAt', 'DESC']]
    });

    res.json({
      success: true,
      data: { reviews }
    });

  } catch (error) {
    console.error('Get my reviews error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching reviews',
      error: error.message
    });
  }
};

/**
 * @desc    Check if user has reviewed a cafe
 * @route   GET /api/reviews/check/:cafeId
 * @access  Private
 */
const checkUserReview = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const userId = req.user.id;

    const review = await Review.findOne({
      where: { userId, cafeId },
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'avatar']
      }]
    });

    res.json({
      success: true,
      data: {
        hasReviewed: !!review,
        review: review || null
      }
    });

  } catch (error) {
    console.error('Check user review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error checking review',
      error: error.message
    });
  }
};

/**
 * @desc    Owner responds to a review
 * @route   POST /api/reviews/:id/respond
 * @access  Private (Cafe owner only)
 */
const respondToReview = async (req, res) => {
  try {
    const { id } = req.params;
    const { response } = req.body;
    const ownerId = req.user.id;

    const review = await Review.findByPk(id, {
      include: [{
        model: Cafe,
        as: 'cafe',
        attributes: ['id', 'ownerId']
      }]
    });

    if (!review) {
      return res.status(404).json({
        success: false,
        message: 'Review not found'
      });
    }

    // Check if user is the cafe owner
    if (review.cafe.ownerId !== ownerId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to respond to this review'
      });
    }

    await review.update({
      ownerResponse: response,
      ownerResponseAt: new Date()
    });

    res.json({
      success: true,
      message: 'Response added successfully',
      data: { review }
    });

  } catch (error) {
    console.error('Respond to review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error responding to review',
      error: error.message
    });
  }
};

module.exports = {
  createReview,
  getCafeReviews,
  updateReview,
  deleteReview,
  getMyReviews,
  checkUserReview,
  respondToReview
};

