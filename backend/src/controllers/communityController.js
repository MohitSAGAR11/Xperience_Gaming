const { db } = require('../config/firebase');

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
 * @desc    Get community feed (recent booking activities)
 * @route   GET /api/community/feed
 * @access  Public (or Private - up to you)
 */
const getCommunityFeed = async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;

    console.log('🌐 [COMMUNITY] Fetching feed, page:', page, 'limit:', limit);

    let query = db.collection('community_posts')
      .orderBy('createdAt', 'desc');

    let snapshot;
    try {
      snapshot = await query.get();
    } catch (indexError) {
      // Fallback if index doesn't exist
      console.log('🌐 [COMMUNITY] Index not ready, using fallback');
      snapshot = await db.collection('community_posts').get();
    }

    let posts = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: convertTimestamp(doc.data().createdAt),
      bookingDate: doc.data().bookingDate,
      startTime: doc.data().startTime,
      endTime: doc.data().endTime
    }));

    // Sort by createdAt if fallback was used
    if (posts.length > 0 && !posts[0].createdAt) {
      posts.sort((a, b) => {
        const dateA = a.createdAt || new Date(0);
        const dateB = b.createdAt || new Date(0);
        return new Date(dateB) - new Date(dateA);
      });
    }

    // Pagination
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    const total = posts.length;
    const paginatedPosts = posts.slice(offset, offset + limitNum);

    console.log('🌐 [COMMUNITY] Found', total, 'posts, returning', paginatedPosts.length);

    res.json({
      success: true,
      data: {
        posts: paginatedPosts,
        pagination: {
          total,
          page: pageNum,
          pages: Math.ceil(total / limitNum),
          limit: limitNum
        }
      }
    });

  } catch (error) {
    console.error('🌐 [COMMUNITY] Error fetching feed:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching community feed',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Create a community post (called when booking is made)
 * @param   {Object} booking - Booking object
 * @param   {Object} cafe - Cafe object
 * @param   {Object} user - User object
 */
const createCommunityPost = async (booking, cafe, user) => {
  try {
    console.log('🌐 [COMMUNITY] Creating post for booking:', booking.id);

    const postData = {
      bookingId: booking.id,
      userId: user.id,
      userName: user.name,
      userAvatar: user.avatar || null,
      cafeId: cafe.id,
      cafeName: cafe.name,
      cafePhoto: cafe.photos && cafe.photos.length > 0 ? cafe.photos[0] : null,
      cafeCity: cafe.city || null,
      bookingDate: booking.bookingDate,
      startTime: booking.startTime,
      endTime: booking.endTime,
      stationType: booking.stationType,
      consoleType: booking.consoleType || null,
      stationNumber: booking.stationNumber,
      createdAt: new Date()
    };

    const docRef = await db.collection('community_posts').add(postData);

    console.log('🌐 [COMMUNITY] Post created successfully:', docRef.id);

    return { success: true, postId: docRef.id };
  } catch (error) {
    console.error('🌐 [COMMUNITY] Error creating post:', error);
    return { success: false, error: error.message };
  }
};

/**
 * @desc    Delete community post (when booking is cancelled)
 * @param   {string} bookingId - Booking ID
 */
const deleteCommunityPost = async (bookingId) => {
  try {
    console.log('🌐 [COMMUNITY] Deleting post for booking:', bookingId);

    const snapshot = await db.collection('community_posts')
      .where('bookingId', '==', bookingId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('🌐 [COMMUNITY] No post found for booking:', bookingId);
      return { success: false, error: 'Post not found' };
    }

    const postId = snapshot.docs[0].id;
    await db.collection('community_posts').doc(postId).delete();

    console.log('🌐 [COMMUNITY] Post deleted successfully:', postId);

    return { success: true, postId };
  } catch (error) {
    console.error('🌐 [COMMUNITY] Error deleting post:', error);
    return { success: false, error: error.message };
  }
};

/**
 * @desc    Get community stats (optional - for analytics)
 * @route   GET /api/community/stats
 * @access  Public
 */
const getCommunityStats = async (req, res) => {
  try {
    const postsSnapshot = await db.collection('community_posts').get();
    const totalPosts = postsSnapshot.docs.length;

    // Get unique users
    const uniqueUsers = new Set();
    postsSnapshot.docs.forEach(doc => {
      uniqueUsers.add(doc.data().userId);
    });

    // Get unique cafes
    const uniqueCafes = new Set();
    postsSnapshot.docs.forEach(doc => {
      uniqueCafes.add(doc.data().cafeId);
    });

    // Get posts from last 24 hours
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentPosts = postsSnapshot.docs.filter(doc => {
      const createdAt = doc.data().createdAt?.toDate();
      return createdAt && createdAt > oneDayAgo;
    });

    res.json({
      success: true,
      data: {
        totalPosts,
        uniqueUsers: uniqueUsers.size,
        uniqueCafes: uniqueCafes.size,
        postsLast24Hours: recentPosts.length
      }
    });

  } catch (error) {
    console.error('🌐 [COMMUNITY] Error fetching stats:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching community stats'
    });
  }
};

module.exports = {
  getCommunityFeed,
  createCommunityPost,
  deleteCommunityPost,
  getCommunityStats
};

