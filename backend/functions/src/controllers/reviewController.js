const { db } = require('../config/firebase');
const { validationResult } = require('express-validator');

/**
 * Helper function to calculate and update cafe rating
 */
const updateCafeRating = async (cafeId) => {
  try {
    console.log('⭐ [UPDATE_RATING] Starting rating calculation for cafe:', cafeId);
    
    // Longer delay to ensure Firestore consistency across all regions
    await new Promise(resolve => setTimeout(resolve, 300));
    
    const reviewsSnapshot = await db.collection('reviews')
      .where('cafeId', '==', cafeId)
      .where('isVisible', '==', true)
      .get();

    const reviews = reviewsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    console.log('⭐ [UPDATE_RATING] Found', reviews.length, 'visible reviews');
    
    // Log each review for debugging
    reviews.forEach((review, index) => {
      console.log(`⭐ [UPDATE_RATING] Review ${index + 1}:`, {
        id: review.id,
        rating: review.rating,
        isVisible: review.isVisible,
        userId: review.userId
      });
    });
    
    if (reviews.length === 0) {
      console.log('⭐ [UPDATE_RATING] No reviews found, setting rating to 0');
      await db.collection('cafes').doc(cafeId).update({
        rating: 0,
        totalReviews: 0
      });
      return;
    }

    const totalRating = reviews.reduce((sum, review) => sum + (review.rating || 0), 0);
    const avgRating = totalRating / reviews.length;
    const totalReviews = reviews.length;

    console.log('⭐ [UPDATE_RATING] Calculated:', {
      totalRating,
      avgRating,
      totalReviews,
      finalRating: Math.round(avgRating * 10) / 10
    });

    await db.collection('cafes').doc(cafeId).update({
      rating: Math.round(avgRating * 10) / 10, // Round to 1 decimal place
      totalReviews
    });
    
    console.log('⭐ [UPDATE_RATING] Rating updated successfully');
    
    // Verify the update
    const cafeDoc = await db.collection('cafes').doc(cafeId).get();
    const cafeData = cafeDoc.data();
    console.log('⭐ [UPDATE_RATING] Verified cafe data:', {
      rating: cafeData.rating,
      totalReviews: cafeData.totalReviews
    });
  } catch (error) {
    console.error('⭐ [UPDATE_RATING] Error updating cafe rating:', error);
    throw error;
  }
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
 * @desc    Create a review for a cafe
 * @route   POST /api/reviews
 * @access  Private (Client only)
 */
const createReview = async (req, res) => {
  try {
    console.log('📝 [CREATE_REVIEW] ========================================');
    console.log('📝 [CREATE_REVIEW] Request body:', JSON.stringify(req.body, null, 2));
    console.log('📝 [CREATE_REVIEW] User ID:', req.user.id);
    
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('📝 [CREATE_REVIEW] Validation errors:', errors.array());
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { cafeId, rating, comment, title } = req.body;
    const userId = req.user.id;
    
    console.log('📝 [CREATE_REVIEW] Extracted data:', { cafeId, rating, userId, hasComment: !!comment, hasTitle: !!title });

    // Validate rating
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5'
      });
    }

    // Check if cafe exists
    const cafe = await getCafeData(cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    // Check if user has already reviewed this cafe
    const existingReviewSnapshot = await db.collection('reviews')
      .where('userId', '==', userId)
      .where('cafeId', '==', cafeId)
      .limit(1)
      .get();

    if (!existingReviewSnapshot.empty) {
      return res.status(400).json({
        success: false,
        message: 'You have already reviewed this cafe. You can update your existing review.'
      });
    }

    // Optional: Check if user has visited (booked) the cafe
    const bookingSnapshot = await db.collection('bookings')
      .where('userId', '==', userId)
      .where('cafeId', '==', cafeId)
      .where('status', '==', 'completed')
      .limit(1)
      .get();
    const hasBooking = !bookingSnapshot.empty;

    // Use transaction to create review and update cafe rating atomically
    const reviewRef = db.collection('reviews').doc();
    
    console.log('📝 [CREATE_REVIEW] Creating review for cafe:', cafeId, 'by user:', userId);
    console.log('📝 [CREATE_REVIEW] Rating:', rating, 'Comment length:', comment?.length || 0);
    
    await db.runTransaction(async (transaction) => {
      // Create the review
      const reviewData = {
        userId,
        cafeId,
        rating: parseInt(rating),
        comment: comment || null,
        title: title || null,
        isVisible: true,
        helpfulCount: 0,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      console.log('📝 [CREATE_REVIEW] Review data prepared:', {
        ...reviewData,
        reviewId: reviewRef.id
      });

      transaction.set(reviewRef, reviewData);
    });

    console.log('📝 [CREATE_REVIEW] Transaction completed, review ID:', reviewRef.id);

    // Small delay to ensure transaction is fully committed
    await new Promise(resolve => setTimeout(resolve, 200));
    
    // Verify review was created
    const verifyDoc = await reviewRef.get();
    if (!verifyDoc.exists) {
      console.error('📝 [CREATE_REVIEW] ERROR: Review not found immediately after transaction!');
      throw new Error('Review transaction failed - document not found');
    }
    console.log('📝 [CREATE_REVIEW] Review verified in database:', {
      id: verifyDoc.id,
      isVisible: verifyDoc.data().isVisible,
      rating: verifyDoc.data().rating
    });

    // Recalculate cafe rating after transaction
    await updateCafeRating(cafeId);

    // Fetch the created review with user info
    const reviewDoc = await reviewRef.get();
    
    if (!reviewDoc.exists) {
      console.error('📝 [CREATE_REVIEW] ERROR: Review document not found after creation!');
      throw new Error('Review created but not found');
    }
    
    const reviewData = reviewDoc.data();
    console.log('📝 [CREATE_REVIEW] Review fetched successfully:', {
      id: reviewDoc.id,
      isVisible: reviewData.isVisible,
      rating: reviewData.rating,
      comment: reviewData.comment ? 'Yes' : 'No'
    });
    
    const user = await getUserData(userId);

    const review = {
      id: reviewDoc.id,
      ...reviewData,
      createdAt: reviewData.createdAt?.toDate ? reviewData.createdAt.toDate().toISOString() : reviewData.createdAt,
      updatedAt: reviewData.updatedAt?.toDate ? reviewData.updatedAt.toDate().toISOString() : reviewData.updatedAt,
      ownerResponseAt: reviewData.ownerResponseAt?.toDate ? reviewData.ownerResponseAt.toDate().toISOString() : reviewData.ownerResponseAt,
      user: user ? {
        id: user.id,
        name: user.name,
        avatar: user.avatar
      } : null
    };

    console.log('📝 [CREATE_REVIEW] Review created successfully:', review.id);

    res.status(201).json({
      success: true,
      message: 'Review submitted successfully',
      data: {
        review,
        hasVerifiedBooking: hasBooking
      }
    });

  } catch (error) {
    console.error('Create review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error creating review',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
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

    console.log('📖 [GET_REVIEWS] ========================================');
    console.log('📖 [GET_REVIEWS] Fetching reviews for cafe:', cafeId);
    console.log('📖 [GET_REVIEWS] Query params:', { page, limit, sort });

    // First, check ALL reviews for this cafe (debug)
    const allReviewsDebug = await db.collection('reviews')
      .where('cafeId', '==', cafeId)
      .get();
    
    console.log('📖 [GET_REVIEWS] DEBUG: Total reviews in DB for this cafe (no filters):', allReviewsDebug.docs.length);
    allReviewsDebug.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`📖 [GET_REVIEWS] DEBUG Review ${index + 1}:`, {
        id: doc.id,
        cafeId: data.cafeId,
        rating: data.rating,
        isVisible: data.isVisible,
        userId: data.userId,
        createdAt: data.createdAt
      });
    });

    let query = db.collection('reviews')
      .where('cafeId', '==', cafeId)
      .where('isVisible', '==', true);
    
    console.log('📖 [GET_REVIEWS] Now querying with isVisible filter...');

    let snapshot;
    let needsClientSort = false;
    let sortField = 'createdAt';
    let sortDirection = 'desc';

    try {
      // Apply sorting (requires composite indexes)
      if (sort === 'highest') {
        query = query.orderBy('rating', 'desc');
        sortField = 'rating';
      } else if (sort === 'lowest') {
        query = query.orderBy('rating', 'asc');
        sortField = 'rating';
        sortDirection = 'asc';
      } else if (sort === 'helpful') {
        query = query.orderBy('helpfulCount', 'desc');
        sortField = 'helpfulCount';
      } else {
        // Default: most recent
        query = query.orderBy('createdAt', 'desc');
      }
      
      snapshot = await query.get();
    } catch (indexError) {
      // Fallback: Query without orderBy and sort client-side
      console.log('Index not ready for getCafeReviews, using fallback query');
      snapshot = await db.collection('reviews')
        .where('cafeId', '==', cafeId)
        .where('isVisible', '==', true)
        .get();
      needsClientSort = true;
    }

    let reviews = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate ? doc.data().createdAt.toDate().toISOString() : doc.data().createdAt,
      updatedAt: doc.data().updatedAt?.toDate ? doc.data().updatedAt.toDate().toISOString() : doc.data().updatedAt,
      ownerResponseAt: doc.data().ownerResponseAt?.toDate ? doc.data().ownerResponseAt.toDate().toISOString() : doc.data().ownerResponseAt
    }));

    console.log('📖 [GET_REVIEWS] Found', reviews.length, 'reviews (before pagination)');
    if (reviews.length > 0) {
      console.log('📖 [GET_REVIEWS] First review:', {
        id: reviews[0].id,
        rating: reviews[0].rating,
        isVisible: reviews[0].isVisible
      });
    }

    // Sort client-side if index wasn't available
    if (needsClientSort) {
      reviews.sort((a, b) => {
        const aVal = a[sortField] || 0;
        const bVal = b[sortField] || 0;
        if (sortDirection === 'desc') {
          return bVal > aVal ? 1 : bVal < aVal ? -1 : 0;
        } else {
          return aVal > bVal ? 1 : aVal < bVal ? -1 : 0;
        }
      });
    }

    // Pagination
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    const total = reviews.length;
    reviews = reviews.slice(offset, offset + limitNum);

    // Fetch user data for each review
    const reviewsWithUser = await Promise.all(
      reviews.map(async (review) => {
        const user = await getUserData(review.userId);
        return {
          ...review,
          user: user ? {
            id: user.id,
            name: user.name,
            avatar: user.avatar
          } : null
        };
      })
    );

    // Get rating distribution
    const allReviewsSnapshot = await db.collection('reviews')
      .where('cafeId', '==', cafeId)
      .where('isVisible', '==', true)
      .get();

    const allReviews = allReviewsSnapshot.docs.map(doc => doc.data());
    const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    allReviews.forEach(review => {
      const rating = review.rating;
      if (rating >= 1 && rating <= 5) {
        distribution[rating] = (distribution[rating] || 0) + 1;
      }
    });

    console.log('📖 [GET_REVIEWS] Sending response:', {
      totalReviews: total,
      reviewsInPage: reviewsWithUser.length,
      page: pageNum,
      distribution
    });

    res.json({
      success: true,
      data: {
        reviews: reviewsWithUser,
        ratingDistribution: distribution,
        pagination: {
          total,
          page: pageNum,
          pages: Math.ceil(total / limitNum),
          limit: limitNum
        }
      }
    });

  } catch (error) {
    console.error('📖 [GET_REVIEWS] Error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching reviews',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Update a review
 * @route   PUT /api/reviews/:id
 * @access  Private (Review owner only)
 */
const updateReview = async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment, title } = req.body;
    const userId = req.user.id;

    const reviewDoc = await db.collection('reviews').doc(id).get();

    if (!reviewDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Review not found'
      });
    }

    const review = reviewDoc.data();

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
    const updateData = {
      updatedAt: new Date()
    };

    if (rating !== undefined) updateData.rating = parseInt(rating);
    if (comment !== undefined) updateData.comment = comment;
    if (title !== undefined) updateData.title = title;

    console.log('✏️ [UPDATE_REVIEW] Updating review:', id);
    console.log('✏️ [UPDATE_REVIEW] Update data:', updateData);

    await db.collection('reviews').doc(id).update(updateData);

    console.log('✏️ [UPDATE_REVIEW] Review updated, recalculating cafe rating');

    // Update cafe's average rating
    await updateCafeRating(review.cafeId);

    // Fetch updated review
    const updatedDoc = await db.collection('reviews').doc(id).get();
    
    if (!updatedDoc.exists) {
      console.error('✏️ [UPDATE_REVIEW] ERROR: Review not found after update!');
      throw new Error('Review updated but not found');
    }
    
    const updatedReviewData = updatedDoc.data();
    console.log('✏️ [UPDATE_REVIEW] Updated review data:', {
      id: updatedDoc.id,
      rating: updatedReviewData.rating,
      isVisible: updatedReviewData.isVisible
    });
    
    const user = await getUserData(userId);

    const updatedReview = {
      id: updatedDoc.id,
      ...updatedReviewData,
      createdAt: updatedReviewData.createdAt?.toDate ? updatedReviewData.createdAt.toDate().toISOString() : updatedReviewData.createdAt,
      updatedAt: updatedReviewData.updatedAt?.toDate ? updatedReviewData.updatedAt.toDate().toISOString() : updatedReviewData.updatedAt,
      ownerResponseAt: updatedReviewData.ownerResponseAt?.toDate ? updatedReviewData.ownerResponseAt.toDate().toISOString() : updatedReviewData.ownerResponseAt,
      user: user ? {
        id: user.id,
        name: user.name,
        avatar: user.avatar
      } : null
    };

    console.log('✏️ [UPDATE_REVIEW] Review update completed successfully');

    res.json({
      success: true,
      message: 'Review updated successfully',
      data: { review: updatedReview }
    });

  } catch (error) {
    console.error('Update review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating review',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Delete a review
 * @route   DELETE /api/reviews/:id
 * @access  Private (Review owner or Admin)
 */
const deleteReview = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const reviewDoc = await db.collection('reviews').doc(id).get();

    if (!reviewDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Review not found'
      });
    }

    const review = reviewDoc.data();

    // Check ownership
    if (review.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this review'
      });
    }

    const cafeId = review.cafeId;

    // Soft delete by setting isVisible to false
    await db.collection('reviews').doc(id).update({
      isVisible: false,
      updatedAt: new Date()
    });

    // Update cafe's average rating
    await updateCafeRating(cafeId);

    res.json({
      success: true,
      message: 'Review deleted successfully'
    });

  } catch (error) {
    console.error('Delete review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting review',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
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

    let snapshot;
    let needsClientSort = false;

    try {
      // Try with orderBy first (requires composite index)
      snapshot = await db.collection('reviews')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .get();
    } catch (indexError) {
      // Fallback: Query without orderBy and sort client-side
      console.log('Index not ready for getMyReviews, using fallback query');
      snapshot = await db.collection('reviews')
        .where('userId', '==', userId)
        .get();
      needsClientSort = true;
    }

    let reviews = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate ? doc.data().createdAt.toDate().toISOString() : doc.data().createdAt,
      updatedAt: doc.data().updatedAt?.toDate ? doc.data().updatedAt.toDate().toISOString() : doc.data().updatedAt,
      ownerResponseAt: doc.data().ownerResponseAt?.toDate ? doc.data().ownerResponseAt.toDate().toISOString() : doc.data().ownerResponseAt
    }));

    // Sort client-side if index wasn't available
    if (needsClientSort) {
      reviews.sort((a, b) => {
        const dateA = a.createdAt || new Date(0);
        const dateB = b.createdAt || new Date(0);
        return dateB - dateA; // Descending order
      });
    }

    // Fetch cafe data for each review
    const reviewsWithCafe = await Promise.all(
      reviews.map(async (review) => {
        const cafe = await getCafeData(review.cafeId);
        return {
          ...review,
          cafe: cafe ? {
            id: cafe.id,
            name: cafe.name,
            city: cafe.city,
            photos: cafe.photos || []
          } : null
        };
      })
    );

    res.json({
      success: true,
      data: { reviews: reviewsWithCafe }
    });

  } catch (error) {
    console.error('Get my reviews error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching reviews',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
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

    const snapshot = await db.collection('reviews')
      .where('userId', '==', userId)
      .where('cafeId', '==', cafeId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.json({
        success: true,
        data: {
          hasReviewed: false,
          review: null
        }
      });
    }

    const reviewDoc = snapshot.docs[0];
    const reviewData = reviewDoc.data();
    const user = await getUserData(userId);

    const review = {
      id: reviewDoc.id,
      ...reviewData,
      createdAt: reviewData.createdAt?.toDate ? reviewData.createdAt.toDate().toISOString() : reviewData.createdAt,
      updatedAt: reviewData.updatedAt?.toDate ? reviewData.updatedAt.toDate().toISOString() : reviewData.updatedAt,
      ownerResponseAt: reviewData.ownerResponseAt?.toDate ? reviewData.ownerResponseAt.toDate().toISOString() : reviewData.ownerResponseAt,
      user: user ? {
        id: user.id,
        name: user.name,
        avatar: user.avatar
      } : null
    };

    res.json({
      success: true,
      data: {
        hasReviewed: true,
        review
      }
    });

  } catch (error) {
    console.error('Check user review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error checking review',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
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

    const reviewDoc = await db.collection('reviews').doc(id).get();

    if (!reviewDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Review not found'
      });
    }

    const review = reviewDoc.data();

    // Check if user is the cafe owner
    const cafe = await getCafeData(review.cafeId);
    if (!cafe || cafe.ownerId !== ownerId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to respond to this review'
      });
    }

    await db.collection('reviews').doc(id).update({
      ownerResponse: response,
      ownerResponseAt: new Date(),
      updatedAt: new Date()
    });

    const updatedDoc = await db.collection('reviews').doc(id).get();
    const updatedReviewData = updatedDoc.data();
    const updatedReview = {
      id: updatedDoc.id,
      ...updatedReviewData,
      createdAt: updatedReviewData.createdAt?.toDate ? updatedReviewData.createdAt.toDate().toISOString() : updatedReviewData.createdAt,
      updatedAt: updatedReviewData.updatedAt?.toDate ? updatedReviewData.updatedAt.toDate().toISOString() : updatedReviewData.updatedAt,
      ownerResponseAt: updatedReviewData.ownerResponseAt?.toDate ? updatedReviewData.ownerResponseAt.toDate().toISOString() : updatedReviewData.ownerResponseAt
    };

    res.json({
      success: true,
      message: 'Response added successfully',
      data: { review: updatedReview }
    });

  } catch (error) {
    console.error('Respond to review error:', error);
    res.status(500).json({
      success: false,
      message: 'Error responding to review',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Debug endpoint - Get ALL reviews (no filters)
 * @route   GET /api/reviews/debug/all
 * @access  Private (for debugging)
 */
const debugGetAllReviews = async (req, res) => {
  try {
    console.log('🔍 [DEBUG] Fetching ALL reviews from database...');
    
    const allReviews = await db.collection('reviews').get();
    
    console.log('🔍 [DEBUG] Total reviews in database:', allReviews.docs.length);
    
    const reviews = allReviews.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        cafeId: data.cafeId,
        userId: data.userId,
        rating: data.rating,
        isVisible: data.isVisible,
        comment: data.comment ? data.comment.substring(0, 50) : null,
        createdAt: data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : data.createdAt
      };
    });
    
    // Group by cafeId
    const groupedByCafe = reviews.reduce((acc, review) => {
      if (!acc[review.cafeId]) {
        acc[review.cafeId] = [];
      }
      acc[review.cafeId].push(review);
      return acc;
    }, {});
    
    console.log('🔍 [DEBUG] Reviews grouped by cafe:', Object.keys(groupedByCafe).length, 'cafes');
    
    res.json({
      success: true,
      data: {
        totalReviews: reviews.length,
        reviews: reviews,
        groupedByCafe: groupedByCafe
      }
    });
  } catch (error) {
    console.error('🔍 [DEBUG] Error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching reviews',
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
  respondToReview,
  debugGetAllReviews
};
