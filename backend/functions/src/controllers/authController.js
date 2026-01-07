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
    const userRole = role || 'client';
    const userData = {
      name,
      email,
      role: userRole,
      phone: phone || null,
      avatar: null,
      // Set verified to false for owners (default), null/undefined for clients
      verified: userRole === 'owner' ? false : undefined,
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
    console.log('🔐 [GET_ME] Verified status (raw from Firestore):', userData.verified);
    console.log('🔐 [GET_ME] Verified type:', typeof userData.verified);

    // CRITICAL: Validate email matches between token and Firestore
    // This prevents returning wrong user data if Firestore document is corrupted
    const tokenEmail = req.user.email;
    const firestoreEmail = userData.email;
    
    if (tokenEmail && firestoreEmail && tokenEmail.toLowerCase() !== firestoreEmail.toLowerCase()) {
      console.error('🔐 [GET_ME] EMAIL MISMATCH DETECTED!');
      console.error('🔐 [GET_ME] Token email:', tokenEmail);
      console.error('🔐 [GET_ME] Firestore email:', firestoreEmail);
      console.error('🔐 [GET_ME] User ID:', req.user.id);
      console.error('🔐 [GET_ME] This indicates data corruption - updating Firestore with correct email from token');
      
      // Update Firestore document with correct email from token
      await db.collection('users').doc(req.user.id).update({
        email: tokenEmail,
        updatedAt: new Date()
      });
      
      // Update userData with corrected email
      userData.email = tokenEmail;
      
      console.log('🔐 [GET_ME] Firestore document updated with correct email');
    }

    // CRITICAL: Parse verified field correctly - handle boolean, string, null, undefined
    // Firestore might return boolean true/false, string "true"/"false", or null/undefined
    let verifiedValue;
    if (userData.role === 'owner') {
      // For owners, verified should be a boolean
      if (userData.verified === true || userData.verified === 'true' || userData.verified === 1) {
        verifiedValue = true;
      } else if (userData.verified === false || userData.verified === 'false' || userData.verified === 0) {
        verifiedValue = false;
      } else {
        // If verified is null, undefined, or any other value, default to false
        verifiedValue = false;
      }
      console.log('🔐 [GET_ME] Parsed verified value for owner:', verifiedValue);
    } else {
      // For clients, verified should be undefined
      verifiedValue = undefined;
    }

    res.json({
      success: true,
      data: {
        user: {
          id: userDoc.id,
          ...userData,
          verified: verifiedValue, // Explicitly set verified field (boolean for owners, undefined for clients)
          createdAt: userData.createdAt?.toDate ? userData.createdAt.toDate().toISOString() : userData.createdAt,
          updatedAt: userData.updatedAt?.toDate ? userData.updatedAt.toDate().toISOString() : userData.updatedAt
        }
      }
    });
    
    console.log('🔐 [GET_ME] Response sent with verified:', verifiedValue);
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

/**
 * @desc    Handle Google Sign-In
 * @route   POST /api/auth/google-signin
 * @access  Private (requires Firebase token from Google Sign-In)
 */
const googleSignIn = async (req, res) => {
  try {
    console.log('🔐 [GOOGLE_SIGNIN] Request received');
    console.log('🔐 [GOOGLE_SIGNIN] User ID:', req.user.id);
    console.log('🔐 [GOOGLE_SIGNIN] User Email:', req.user.email);
    console.log('🔐 [GOOGLE_SIGNIN] Request Body:', req.body);

    const { role, isNewUser, name, email, avatar } = req.body;
    const userId = req.user.id;
    
    // SECURITY: Always use email from token (req.user.email) as source of truth
    // The email from request body is only used for logging/comparison
    const tokenEmail = req.user.email; // This is from the verified Firebase token
    const requestEmail = email; // From request body (for reference only)
    
    // Validate that request email matches token email (if provided)
    if (requestEmail && tokenEmail && requestEmail.toLowerCase() !== tokenEmail.toLowerCase()) {
      console.warn('🔐 [GOOGLE_SIGNIN] Request email does not match token email - using token email');
      console.warn('🔐 [GOOGLE_SIGNIN] Token email:', tokenEmail);
      console.warn('🔐 [GOOGLE_SIGNIN] Request email:', requestEmail);
    }

    // Validate role
    if (!role || !['client', 'owner'].includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid role. Must be "client" or "owner"'
      });
    }

    // Check if user profile exists
    console.log('🔐 [GOOGLE_SIGNIN] Checking if profile exists...');
    const userDoc = await db.collection('users').doc(userId).get();

    if (userDoc.exists) {
      // Existing user - return their profile
      console.log('🔐 [GOOGLE_SIGNIN] Existing user found');
      const userData = userDoc.data();
      
      // CRITICAL: Validate email matches between token and Firestore
      // This prevents returning wrong user data if Firestore document is corrupted
      const firestoreEmail = userData.email;
      
      if (tokenEmail && firestoreEmail && tokenEmail.toLowerCase() !== firestoreEmail.toLowerCase()) {
        console.error('🔐 [GOOGLE_SIGNIN] EMAIL MISMATCH DETECTED!');
        console.error('🔐 [GOOGLE_SIGNIN] Token email:', tokenEmail);
        console.error('🔐 [GOOGLE_SIGNIN] Firestore email:', firestoreEmail);
        console.error('🔐 [GOOGLE_SIGNIN] User ID:', userId);
        console.error('🔐 [GOOGLE_SIGNIN] This indicates data corruption - updating Firestore with correct email from token');
        
        // Update Firestore document with correct email, name, and avatar from token
        const updateData = {
          email: tokenEmail, // Always use token email as source of truth
          updatedAt: new Date()
        };
        
        // Update name if provided and different
        if (name && name !== userData.name) {
          updateData.name = name;
          userData.name = name;
        }
        
        // Update avatar if provided (Google profile picture)
        if (avatar && avatar !== userData.avatar) {
          updateData.avatar = avatar;
          userData.avatar = avatar;
        }
        
        await db.collection('users').doc(userId).update(updateData);
        
        // Update userData with corrected email
        userData.email = tokenEmail;
        
        console.log('🔐 [GOOGLE_SIGNIN] Firestore document updated with correct email, name, and avatar');
      } else {
        // Email matches - check if name or avatar needs updating
        const updateData = {};
        let needsUpdate = false;
        
        if (name && name !== userData.name) {
          updateData.name = name;
          userData.name = name;
          needsUpdate = true;
          console.log('🔐 [GOOGLE_SIGNIN] Name changed in Google profile');
        }
        
        if (avatar && avatar !== userData.avatar) {
          updateData.avatar = avatar;
          userData.avatar = avatar;
          needsUpdate = true;
          console.log('🔐 [GOOGLE_SIGNIN] Avatar changed in Google profile');
        }
        
        if (needsUpdate) {
          updateData.updatedAt = new Date();
          await db.collection('users').doc(userId).update(updateData);
          console.log('🔐 [GOOGLE_SIGNIN] Profile updated with latest Google data');
        }
      }
      
      // Check if role matches (allow users to sign in with their existing role)
      if (userData.role && userData.role !== role) {
        console.log(`🔐 [GOOGLE_SIGNIN] Role mismatch: existing role is ${userData.role}, requested role is ${role}`);
        return res.status(400).json({
          success: false,
          message: `This account is registered as ${userData.role === 'owner' ? 'an owner' : 'a client'}. Please sign in with the correct account type.`
        });
      }
      
      // CRITICAL: Parse verified field correctly - handle boolean, string, null, undefined
      // Firestore might return boolean true/false, string "true"/"false", or null/undefined
      let verifiedValue;
      if (userData.role === 'owner') {
        // For owners, verified should be a boolean
        if (userData.verified === true || userData.verified === 'true' || userData.verified === 1) {
          verifiedValue = true;
        } else if (userData.verified === false || userData.verified === 'false' || userData.verified === 0) {
          verifiedValue = false;
        } else {
          // If verified is null, undefined, or any other value, default to false
          verifiedValue = false;
        }
        console.log('🔐 [GOOGLE_SIGNIN] Parsed verified value for owner:', verifiedValue);
        console.log('🔐 [GOOGLE_SIGNIN] Original verified value from Firestore:', userData.verified, 'Type:', typeof userData.verified);
      } else {
        // For clients, verified should be undefined
        verifiedValue = undefined;
      }
      
      return res.status(200).json({
        success: true,
        message: 'Welcome back!',
        data: {
          user: {
            id: userId,
            ...userData,
            verified: verifiedValue, // Explicitly set verified field (boolean for owners, undefined for clients)
            createdAt: userData.createdAt?.toDate ? userData.createdAt.toDate().toISOString() : userData.createdAt,
            updatedAt: userData.updatedAt?.toDate ? userData.updatedAt.toDate().toISOString() : userData.updatedAt
          }
        }
      });
    } else {
      // New user - create profile
      console.log('🔐 [GOOGLE_SIGNIN] New user, creating profile...');
      
      // SECURITY: Always use email from token (req.user.email) as source of truth
      // Use name from request body if provided, otherwise fallback to 'User'
      const userData = {
        name: name || 'User',
        email: tokenEmail, // Always use token email (verified by Firebase)
        role: role,
        phone: null,
        avatar: avatar || null, // Use Google profile picture if available
        createdAt: new Date(),
        updatedAt: new Date()
      };
      
      // Only set verified field for owners (Firestore doesn't store undefined)
      if (role === 'owner') {
        userData.verified = false;
      }

      await db.collection('users').doc(userId).set(userData);
      console.log('🔐 [GOOGLE_SIGNIN] Profile created successfully');

      // Prepare response data (ensure verified is undefined for clients in response)
      const responseUserData = {
        id: userId,
        ...userData,
        verified: role === 'owner' ? false : undefined,
        createdAt: userData.createdAt.toISOString(),
        updatedAt: userData.updatedAt.toISOString()
      };

      return res.status(201).json({
        success: true,
        message: 'Account created successfully',
        data: {
          user: responseUserData
        }
      });
    }

  } catch (error) {
    console.error('🔐 [GOOGLE_SIGNIN] Error:', error);
    console.error('🔐 [GOOGLE_SIGNIN] Error stack:', error.stack);
    console.error('🔐 [GOOGLE_SIGNIN] Request role:', req.body?.role);
    console.error('🔐 [GOOGLE_SIGNIN] User ID:', req.user?.id);
    
    res.status(500).json({
      success: false,
      message: 'Server error during Google Sign-In',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Delete user account and all associated data
 * @route   DELETE /api/auth/account
 * @access  Private
 */
const deleteAccount = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role || 'client';

    console.log('🗑️ [DELETE_ACCOUNT] Request received for user:', userId);
    console.log('🗑️ [DELETE_ACCOUNT] User role:', userRole);

    // Delete user's bookings
    console.log('🗑️ [DELETE_ACCOUNT] Deleting bookings...');
    const bookingsSnapshot = await db.collection('bookings')
      .where('userId', '==', userId)
      .get();
    
    const bookingDeletes = [];
    bookingsSnapshot.forEach((doc) => {
      bookingDeletes.push(doc.ref.delete());
    });
    await Promise.all(bookingDeletes);
    console.log(`🗑️ [DELETE_ACCOUNT] Deleted ${bookingDeletes.length} bookings`);

    // If owner, delete cafes and their bookings
    if (userRole === 'owner') {
      console.log('🗑️ [DELETE_ACCOUNT] Deleting owner cafes...');
      const cafesSnapshot = await db.collection('cafes')
        .where('ownerId', '==', userId)
        .get();
      
      const cafeDeletes = [];
      const cafeBookingDeletes = [];
      
      for (const cafeDoc of cafesSnapshot.docs) {
        cafeDeletes.push(cafeDoc.ref.delete());
        
        // Delete bookings for this cafe
        const cafeBookingsSnapshot = await db.collection('bookings')
          .where('cafeId', '==', cafeDoc.id)
          .get();
        
        cafeBookingsSnapshot.forEach((bookingDoc) => {
          cafeBookingDeletes.push(bookingDoc.ref.delete());
        });
      }
      
      await Promise.all([...cafeDeletes, ...cafeBookingDeletes]);
      console.log(`🗑️ [DELETE_ACCOUNT] Deleted ${cafeDeletes.length} cafes and ${cafeBookingDeletes.length} cafe bookings`);
    }

    // Delete user's reviews
    console.log('🗑️ [DELETE_ACCOUNT] Deleting reviews...');
    const reviewsSnapshot = await db.collection('reviews')
      .where('userId', '==', userId)
      .get();
    
    const reviewDeletes = [];
    reviewsSnapshot.forEach((doc) => {
      reviewDeletes.push(doc.ref.delete());
    });
    await Promise.all(reviewDeletes);
    console.log(`🗑️ [DELETE_ACCOUNT] Deleted ${reviewDeletes.length} reviews`);

    // Delete user document
    console.log('🗑️ [DELETE_ACCOUNT] Deleting user document...');
    await db.collection('users').doc(userId).delete();
    console.log('🗑️ [DELETE_ACCOUNT] User document deleted');

    // Delete Firebase Auth user (this will be handled by frontend, but we can try)
    try {
      await auth.deleteUser(userId);
      console.log('🗑️ [DELETE_ACCOUNT] Firebase Auth user deleted');
    } catch (error) {
      console.warn('🗑️ [DELETE_ACCOUNT] Could not delete Firebase Auth user (frontend will handle):', error.message);
      // Frontend will handle Firebase Auth deletion
    }

    console.log('🗑️ [DELETE_ACCOUNT] Account deletion completed successfully');

    res.json({
      success: true,
      message: 'Account deleted successfully'
    });
  } catch (error) {
    console.error('🗑️ [DELETE_ACCOUNT] Error:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting account',
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
  registerFcmToken,
  googleSignIn,
  deleteAccount
};

