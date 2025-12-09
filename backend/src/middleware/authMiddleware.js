const { auth, db } = require('../config/firebase');

/**
 * Middleware to protect routes - verifies Firebase ID token
 */
const protect = async (req, res, next) => {
  try {
    let token;

    // Check for token in Authorization header
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized, no token provided'
      });
    }

    // Verify Firebase ID token
    const decodedToken = await auth.verifyIdToken(token);

    // Get user data from Firestore
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();

    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        message: 'User not found in database'
      });
    }

    const userData = userDoc.data();
    
    // Attach user info to request
    req.user = {
      id: decodedToken.uid,
      email: decodedToken.email,
      ...userData
    };
    
    next();
  } catch (error) {
    console.error('Auth middleware error:', error.message);
    return res.status(401).json({
      success: false,
      message: 'Not authorized, token invalid'
    });
  }
};

/**
 * Middleware for new user registration - only verifies Firebase token
 * Does NOT check if user exists in Firestore (since we're creating them)
 */
const protectNewUser = async (req, res, next) => {
  try {
    let token;

    // Check for token in Authorization header
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized, no token provided'
      });
    }

    // Verify Firebase ID token only - don't check Firestore
    const decodedToken = await auth.verifyIdToken(token);
    
    // Attach basic user info from token
    req.user = {
      id: decodedToken.uid,
      email: decodedToken.email
    };
    
    next();
  } catch (error) {
    console.error('Auth middleware error:', error.message);
    return res.status(401).json({
      success: false,
      message: 'Not authorized, token invalid'
    });
  }
};

/**
 * Middleware to restrict access to owners only
 */
const ownerOnly = (req, res, next) => {
  if (req.user && req.user.role === 'owner') {
    next();
  } else {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Owner role required.'
    });
  }
};

/**
 * Middleware to restrict access to clients only
 */
const clientOnly = (req, res, next) => {
  if (req.user && req.user.role === 'client') {
    next();
  } else {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Client role required.'
    });
  }
};

/**
 * Middleware to allow both owners and clients
 */
const authenticated = (req, res, next) => {
  if (req.user) {
    next();
  } else {
    return res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
  }
};

module.exports = {
  protect,
  protectNewUser,
  ownerOnly,
  clientOnly,
  authenticated
};

