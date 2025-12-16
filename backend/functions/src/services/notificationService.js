const admin = require('firebase-admin');
const { db } = require('../config/firebase');

/**
 * Send push notification to a user
 * @param {string} userId - User ID to send notification to
 * @param {Object} notification - Notification data
 * @param {string} notification.title - Notification title
 * @param {string} notification.body - Notification body
 * @param {Object} notification.data - Additional data payload
 */
const sendNotificationToUser = async (userId, notification) => {
  try {
    console.log('📬 [NOTIFICATION] Sending to user:', userId);
    
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log('📬 [NOTIFICATION] User not found:', userId);
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log('📬 [NOTIFICATION] User has no FCM token:', userId);
      return { success: false, error: 'No FCM token' };
    }

    // Prepare the message
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data || {},
      // Android specific options
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'booking_notifications',
          priority: 'high',
        },
      },
      // iOS specific options
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send the notification
    const response = await admin.messaging().send(message);
    
    console.log('📬 [NOTIFICATION] Sent successfully:', response);
    return { success: true, messageId: response };
    
  } catch (error) {
    console.error('📬 [NOTIFICATION] Error:', error.message);
    
    // If token is invalid, remove it from user document
    if (error.code === 'messaging/invalid-registration-token' || 
        error.code === 'messaging/registration-token-not-registered') {
      console.log('📬 [NOTIFICATION] Removing invalid token for user:', userId);
      await db.collection('users').doc(userId).update({
        fcmToken: null
      });
    }
    
    return { success: false, error: error.message };
  }
};

/**
 * Send notification to multiple users
 */
const sendNotificationToMultipleUsers = async (userIds, notification) => {
  console.log('📬 [NOTIFICATION] Sending to multiple users:', userIds.length);
  const results = await Promise.all(
    userIds.map(userId => sendNotificationToUser(userId, notification))
  );
  return results;
};

/**
 * Create booking notification for cafe owner
 */
const sendBookingNotification = async (booking, cafe, user) => {
  try {
    const ownerId = cafe.ownerId;
    
    console.log('📬 [BOOKING_NOTIFICATION] Creating notification for owner:', ownerId);
    console.log('📬 [BOOKING_NOTIFICATION] Booking details:', {
      bookingId: booking.id,
      cafeId: cafe.id,
      cafeName: cafe.name,
      userName: user.name,
      date: booking.bookingDate
    });
    
    const stationType = booking.stationType === 'pc' 
      ? 'PC' 
      : booking.consoleType?.toUpperCase() || 'Console';
    
    const notification = {
      title: `🎮 New Booking at ${cafe.name}`,
      body: `${user.name} booked ${stationType} #${booking.stationNumber} for ${booking.bookingDate} at ${booking.startTime}`,
      data: {
        type: 'NEW_BOOKING',
        bookingId: booking.id,
        cafeId: cafe.id,
        userId: user.id,
        bookingDate: booking.bookingDate,
        startTime: booking.startTime,
        endTime: booking.endTime,
        stationType: booking.stationType,
      },
    };

    return await sendNotificationToUser(ownerId, notification);
  } catch (error) {
    console.error('📬 [BOOKING_NOTIFICATION] Error:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Create booking cancellation notification
 */
const sendBookingCancellationNotification = async (booking, cafe, user) => {
  try {
    const ownerId = cafe.ownerId;
    
    console.log('📬 [CANCELLATION_NOTIFICATION] Creating notification for owner:', ownerId);
    
    const stationType = booking.stationType === 'pc' 
      ? 'PC' 
      : booking.consoleType?.toUpperCase() || 'Console';
    
    const notification = {
      title: `❌ Booking Cancelled at ${cafe.name}`,
      body: `${user.name} cancelled ${stationType} #${booking.stationNumber} booking for ${booking.bookingDate}`,
      data: {
        type: 'BOOKING_CANCELLED',
        bookingId: booking.id,
        cafeId: cafe.id,
        userId: user.id,
        bookingDate: booking.bookingDate,
      },
    };

    return await sendNotificationToUser(ownerId, notification);
  } catch (error) {
    console.error('📬 [CANCELLATION_NOTIFICATION] Error:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Create booking status update notification for client
 */
const sendBookingStatusUpdateNotification = async (booking, cafe, newStatus) => {
  try {
    const userId = booking.userId;
    
    console.log('📬 [STATUS_UPDATE_NOTIFICATION] Creating notification for user:', userId);
    
    let title, body;
    
    switch (newStatus) {
      case 'confirmed':
        title = `✅ Booking Confirmed`;
        body = `Your booking at ${cafe.name} for ${booking.bookingDate} is confirmed!`;
        break;
      case 'cancelled':
        title = `❌ Booking Cancelled`;
        body = `Your booking at ${cafe.name} for ${booking.bookingDate} has been cancelled.`;
        break;
      case 'completed':
        title = `🎉 Booking Completed`;
        body = `Thanks for visiting ${cafe.name}! How was your experience?`;
        break;
      default:
        title = `📋 Booking Update`;
        body = `Your booking at ${cafe.name} status: ${newStatus}`;
    }
    
    const notification = {
      title,
      body,
      data: {
        type: 'BOOKING_STATUS_UPDATE',
        bookingId: booking.id,
        cafeId: cafe.id,
        status: newStatus,
        bookingDate: booking.bookingDate,
      },
    };

    return await sendNotificationToUser(userId, notification);
  } catch (error) {
    console.error('📬 [STATUS_UPDATE_NOTIFICATION] Error:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Create review notification for cafe owner
 */
const sendReviewNotification = async (review, cafe, user) => {
  try {
    const ownerId = cafe.ownerId;
    
    console.log('📬 [REVIEW_NOTIFICATION] Creating notification for owner:', ownerId);
    
    const stars = '⭐'.repeat(review.rating);
    
    const notification = {
      title: `${stars} New Review for ${cafe.name}`,
      body: `${user.name} left a ${review.rating}-star review${review.comment ? ': ' + review.comment.substring(0, 50) + '...' : ''}`,
      data: {
        type: 'NEW_REVIEW',
        reviewId: review.id,
        cafeId: cafe.id,
        userId: user.id,
        rating: review.rating.toString(),
      },
    };

    return await sendNotificationToUser(ownerId, notification);
  } catch (error) {
    console.error('📬 [REVIEW_NOTIFICATION] Error:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  sendNotificationToUser,
  sendNotificationToMultipleUsers,
  sendBookingNotification,
  sendBookingCancellationNotification,
  sendBookingStatusUpdateNotification,
  sendReviewNotification,
};

