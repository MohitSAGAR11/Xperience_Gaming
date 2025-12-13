const { db, auth } = require('../config/firebase');
const { validationResult } = require('express-validator');

/**
 * @desc    Create user profile in Firestore after Firebase Auth registration
 * @route   POST /api/auth/create-profile
 * @access  Private (requires Firebase token)
 * @note    Called after Firebase Auth registration to create user document
 */
const createProfile = async (req, res) => {
  try {
    console.log('🔐 [CREATE_PROFILE] Request received');
    console.log('🔐 [CREATE_PROFILE] User ID:', req.user.id);
    console.log('🔐 [CREATE_PROFILE] User Email:', req.user.email);
    console.log('🔐 [CREATE_PROFILE] Request Body:', req.body);

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('🔐 [CREATE_PROFILE] Validation errors:', errors.array());
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { name, role, phone } = req.body;
    const userId = req.user.id;
    const email = req.user.email;

    // Check if user profile already exists
    console.log('🔐 [CREATE_PROFILE] Checking if profile already exists...');
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      console.log('🔐 [CREATE_PROFILE] Profile already exists, returning existing data');
      const existingData = userDoc.data();
      // Return existing profile instead of error (idempotent behavior)
      return res.status(200).json({
        success: true,
        message: 'Profile already exists',
        data: {
          user: {
            id: userId,
            ...existingData,
            createdAt: existingData.createdAt?.toDate ? existingData.createdAt.toDate().toISOString() : existingData.createdAt,
            updatedAt: existingData.updatedAt?.toDate ? existingData.updatedAt.toDate().toISOString() : existingData.updatedAt
          }
        }
      });
    }

    // Create user profile in Firestore
    console.log('🔐 [CREATE_PROFILE] Creating new profile...');
    const userData = {
      name,
      email,
      role: role || 'client',
      phone: phone || null,
      avatar: null,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await db.collection('users').doc(userId).set(userData);
    console.log('🔐 [CREATE_PROFILE] Profile created successfully!');

    res.status(201).json({
      success: true,
      message: 'Profile created successfully',
      data: {
        user: {
          id: userId,
          ...userData,
          createdAt: userData.createdAt?.toDate ? userData.createdAt.toDate().toISOString() : userData.createdAt,
          updatedAt: userData.updatedAt?.toDate ? userData.updatedAt.toDate().toISOString() : userData.updatedAt
        }
      }
    });
  } catch (error) {
    console.error('🔐 [CREATE_PROFILE] ERROR:', error);
    console.error('🔐 [CREATE_PROFILE] ERROR Stack:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Server error during profile creation',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Get current logged in user
 * @route   GET /api/auth/me
 * @access  Private
 */

const getMe = async (req, res) => {
  try {
    console.log('🔐 [GET_ME] Request for user:', req.user.id);
    const userDoc = await db.collection('users').doc(req.user.id).get();

    if (!userDoc.exists) {
      console.log('🔐 [GET_ME] Profile not found for user:', req.user.id);
      return res.status(404).json({
        success: false,
        message: 'User profile not found'
      });
    }

    const userData = userDoc.data();
    console.log('🔐 [GET_ME] Profile found! Role:', userData.role);

    res.json({
      success: true,
      data: {
        user: {
          id: userDoc.id,  // ✅ Add this line
          ...userData,
          createdAt: userData.createdAt?.toDate ? userData.createdAt.toDate().toISOString() : userData.createdAt,
          updatedAt: userData.updatedAt?.toDate ? userData.updatedAt.toDate().toISOString() : userData.updatedAt
        }
      }
    });
  } catch (error) {
    console.error('🔐 [GET_ME] ERROR:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Update user profile
 * @route   PUT /api/auth/profile
 * @access  Private
 */
const updateProfile = async (req, res) => {
  try {
    const { name, phone, avatar } = req.body;
    const userId = req.user.id;

    const updateData = {
      updatedAt: new Date()
    };

    if (name !== undefined) updateData.name = name;
    if (phone !== undefined) updateData.phone = phone;
    if (avatar !== undefined) updateData.avatar = avatar;

    await db.collection('users').doc(userId).update(updateData);

    // Get updated user data
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        user: {
          id: userDoc.id,
          ...userData,
          createdAt: userData.createdAt?.toDate ? userData.createdAt.toDate().toISOString() : userData.createdAt,
          updatedAt: userData.updatedAt?.toDate ? userData.updatedAt.toDate().toISOString() : userData.updatedAt
        }
      }
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

/**
 * @desc    Change password
 * @route   PUT /api/auth/password
 * @access  Private
 * @note    Password changes are handled by Firebase Auth on frontend
 *          This endpoint is kept for consistency but frontend should use Firebase Auth directly
 */
const changePassword = async (req, res) => {
  try {
    const { newPassword } = req.body;
    const userId = req.user.id;

    // Update password using Firebase Admin SDK
    await auth.updateUser(userId, {
      password: newPassword
    });

    res.json({
      success: true,
      message: 'Password changed successfully'
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Logout user (invalidate token on client side)
 * @route   POST /api/auth/logout
 * @access  Private
 * @note    JWT tokens are stateless, so actual invalidation happens client-side
 *          For enhanced security, implement token blacklisting with Redis
 */
const logout = async (req, res) => {
  try {
    // In JWT auth, the client removes the token
    // Server can log the logout event if needed
    console.log(`User ${req.user.id} logged out at ${new Date().toISOString()}`);

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during logout'
    });
  }
};

/**
 * @desc    Register FCM token for push notifications
 * @route   POST /api/auth/register-fcm-token
 * @access  Private
 */
const registerFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user.id;

    console.log('📱 [FCM_TOKEN] Registering token for user:', userId);

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required'
      });
    }

    // Update user document with FCM token
    await db.collection('users').doc(userId).update({
      fcmToken,
      fcmTokenUpdatedAt: new Date()
    });

    console.log('📱 [FCM_TOKEN] Token registered successfully for user:', userId);

    res.json({
      success: true,
      message: 'FCM token registered successfully'
    });

  } catch (error) {
    console.error('📱 [FCM_TOKEN] Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Error registering FCM token',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  createProfile,
  logout,
  getMe,
  updateProfile,
  changePassword,
  registerFcmToken
};

