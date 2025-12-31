const { auth, db } = require('../config/firebase');

/**
 * Middleware to protect routes - verifies Firebase ID token
 */
const protect = async (req, res, next) => {
  try {
    console.log('🔐 [AUTH_MIDDLEWARE] ========================================');
    console.log('🔐 [AUTH_MIDDLEWARE] Starting authentication check');
    
    // 1. Extract Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      console.log('🔐 [AUTH_MIDDLEWARE] No authorization header present');
      return res.status(401).json({
        success: false,
        message: 'No authorization header'
      });
    }

    // 2. Check Bearer format (with space after "Bearer")
    if (!authHeader.startsWith('Bearer ')) {
      console.error('🔐 [AUTH_MIDDLEWARE] Invalid authorization format');
      console.error('🔐 [AUTH_MIDDLEWARE] Header (first 30 chars):', authHeader.substring(0, 30));
      return res.status(401).json({
        success: false,
        message: 'Invalid authorization format. Expected "Bearer <token>"'
      });
    }

    // 3. Extract and clean token (remove "Bearer " prefix and trim whitespace)
    const token = authHeader.split('Bearer ')[1]?.trim();
    
    if (!token) {
      console.error('🔐 [AUTH_MIDDLEWARE] Token is empty after Bearer');
      return res.status(401).json({
        success: false,
        message: 'Token is empty'
      });
    }

    // 4. Log token details (first/last chars for debugging, not full token)
    console.log('🔐 [AUTH_MIDDLEWARE] Token received (first 20 chars):', token.substring(0, 20));
    console.log('🔐 [AUTH_MIDDLEWARE] Token length:', token.length);

    // 5. Verify Firebase Admin SDK is initialized
    if (!auth) {
      console.error('🔐 [AUTH_MIDDLEWARE] Firebase Admin auth is not initialized!');
      return res.status(500).json({
        success: false,
        message: 'Server configuration error',
        errorCode: 'auth-not-initialized'
      });
    }

    // 6. Verify token with Firebase Admin
    // Note: We use false for checkRevoked to avoid propagation delays and clock skew issues
    // Revoked tokens are still checked by Firebase, but we don't force immediate revocation checks
    console.log('🔐 [AUTH_MIDDLEWARE] Verifying Firebase token...');
    console.log('🔐 [AUTH_MIDDLEWARE] Backend project ID:', auth.app?.options?.projectId);
    console.log('🔐 [AUTH_MIDDLEWARE] Server time:', new Date().toISOString());
    
    let decodedToken;
    let lastError;
    const maxRetries = 3;
    const retryDelays = [0, 500, 1000]; // Immediate, 500ms, 1s
    
    // Retry logic to handle clock skew and token propagation delays
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          console.log(`🔐 [AUTH_MIDDLEWARE] Retry attempt ${attempt + 1}/${maxRetries} after ${retryDelays[attempt]}ms delay`);
          await new Promise(resolve => setTimeout(resolve, retryDelays[attempt]));
        }
        
        // First attempt: don't check revoked (faster, avoids propagation delays)
        // Subsequent attempts: check revoked (in case token was actually revoked)
        const checkRevoked = attempt > 0;
        decodedToken = await auth.verifyIdToken(token, checkRevoked);
        
        // Success - break out of retry loop
        break;
      } catch (verifyError) {
        lastError = verifyError;
        console.error(`🔐 [AUTH_MIDDLEWARE] verifyIdToken attempt ${attempt + 1} failed:`, verifyError.code);
        console.error(`🔐 [AUTH_MIDDLEWARE] Error message:`, verifyError.message);
        
        // Don't retry for certain errors (invalid format, wrong project, etc.)
        if (verifyError.code === 'auth/argument-error' || 
            verifyError.code === 'auth/invalid-credential' ||
            verifyError.code === 'auth/project-not-found') {
          console.error('🔐 [AUTH_MIDDLEWARE] Non-retryable error, stopping retries');
          throw verifyError;
        }
        
        // For clock skew or propagation issues, retry
        if (attempt < maxRetries - 1) {
          console.log(`🔐 [AUTH_MIDDLEWARE] Retrying due to: ${verifyError.code}`);
        } else {
          // Last attempt failed
          console.error('🔐 [AUTH_MIDDLEWARE] All retry attempts exhausted');
          throw verifyError;
        }
      }
    }
    
    if (!decodedToken) {
      throw lastError || new Error('Token verification failed after retries');
    }
    
    console.log('🔐 [AUTH_MIDDLEWARE] Token verified successfully!');
    console.log('🔐 [AUTH_MIDDLEWARE] UID:', decodedToken.uid);
    console.log('🔐 [AUTH_MIDDLEWARE] Email:', decodedToken.email);
    console.log('🔐 [AUTH_MIDDLEWARE] Token project (aud):', decodedToken.aud);
    console.log('🔐 [AUTH_MIDDLEWARE] Token issuer (iss):', decodedToken.iss);
    
    // Clock skew detection
    const serverTime = Date.now();
    const tokenIssuedTime = decodedToken.iat * 1000;
    const tokenExpiresTime = decodedToken.exp * 1000;
    const timeDiff = serverTime - tokenIssuedTime;
    const timeUntilExpiry = tokenExpiresTime - serverTime;
    
    console.log('🔐 [AUTH_MIDDLEWARE] Server time:', new Date(serverTime).toISOString());
    console.log('🔐 [AUTH_MIDDLEWARE] Token issued at:', new Date(tokenIssuedTime).toISOString());
    console.log('🔐 [AUTH_MIDDLEWARE] Token expires at:', new Date(tokenExpiresTime).toISOString());
    console.log('🔐 [AUTH_MIDDLEWARE] Time difference (server - issued):', timeDiff, 'ms');
    console.log('🔐 [AUTH_MIDDLEWARE] Time until expiry:', timeUntilExpiry, 'ms');
    
    // Warn if clock skew detected (more than 5 seconds difference)
    if (Math.abs(timeDiff) > 5000) {
      console.warn('⚠️  [AUTH_MIDDLEWARE] CLOCK SKEW DETECTED!');
      console.warn('⚠️  [AUTH_MIDDLEWARE] Server time differs from token time by:', Math.abs(timeDiff), 'ms');
      if (timeDiff < 0) {
        console.warn('⚠️  [AUTH_MIDDLEWARE] Server clock is BEHIND token time (token appears to be from future)');
      } else {
        console.warn('⚠️  [AUTH_MIDDLEWARE] Server clock is AHEAD of token time');
      }
    }
    
    // Verify project ID matches
    const backendProjectId = auth.app?.options?.projectId;
    if (decodedToken.aud && backendProjectId && decodedToken.aud !== backendProjectId) {
      console.error('🔐 [AUTH_MIDDLEWARE] PROJECT ID MISMATCH!');
      console.error('🔐 [AUTH_MIDDLEWARE] Token project (aud):', decodedToken.aud);
      console.error('🔐 [AUTH_MIDDLEWARE] Backend project ID:', backendProjectId);
      return res.status(401).json({
        success: false,
        message: 'Token from different Firebase project',
        errorCode: 'project-id-mismatch'
      });
    }

    // 7. Get user data from Firestore
    console.log('🔐 [AUTH_MIDDLEWARE] Fetching user from Firestore...');
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();

    if (!userDoc.exists) {
      console.error('🔐 [AUTH_MIDDLEWARE] User not found in Firestore:', decodedToken.uid);
      return res.status(401).json({
        success: false,
        message: 'User not found in database'
      });
    }

    const userData = userDoc.data();
    console.log('🔐 [AUTH_MIDDLEWARE] User authenticated! Role:', userData.role);
    
    // CRITICAL: Validate email matches between token and Firestore
    // This prevents attaching wrong user data if Firestore document is corrupted
    const tokenEmail = decodedToken.email;
    const firestoreEmail = userData.email;
    
    if (tokenEmail && firestoreEmail && tokenEmail.toLowerCase() !== firestoreEmail.toLowerCase()) {
      console.error('🔐 [AUTH_MIDDLEWARE] EMAIL MISMATCH DETECTED!');
      console.error('🔐 [AUTH_MIDDLEWARE] Token email:', tokenEmail);
      console.error('🔐 [AUTH_MIDDLEWARE] Firestore email:', firestoreEmail);
      console.error('🔐 [AUTH_MIDDLEWARE] User ID:', decodedToken.uid);
      console.error('🔐 [AUTH_MIDDLEWARE] This indicates data corruption - updating Firestore with correct email from token');
      
      // Update Firestore document with correct email from token
      await db.collection('users').doc(decodedToken.uid).update({
        email: tokenEmail,
        updatedAt: new Date()
      });
      
      // Update userData with corrected email
      userData.email = tokenEmail;
      
      console.log('🔐 [AUTH_MIDDLEWARE] Firestore document updated with correct email');
    }
    
    // 8. Attach user info to request
    req.user = {
      id: decodedToken.uid,
      email: decodedToken.email,
      ...userData
    };
    
    console.log('🔐 [AUTH_MIDDLEWARE] Authentication successful');
    console.log('🔐 [AUTH_MIDDLEWARE] ========================================');
    next();
  } catch (error) {
    // 9. Detailed error logging
    console.error('🔐 [AUTH_MIDDLEWARE] ========================================');
    console.error('🔐 [AUTH_MIDDLEWARE] Authentication failed');
    console.error('🔐 [AUTH_MIDDLEWARE] Error type:', typeof error);
    console.error('🔐 [AUTH_MIDDLEWARE] Error code:', error.code);
    console.error('🔐 [AUTH_MIDDLEWARE] Error message:', error.message);
    console.error('🔐 [AUTH_MIDDLEWARE] Error name:', error.name);
    console.error('🔐 [AUTH_MIDDLEWARE] Error stack:', error.stack);
    console.error('🔐 [AUTH_MIDDLEWARE] Full error object:', JSON.stringify(error, Object.getOwnPropertyNames(error)));
    
    // Check if auth object is properly initialized
    try {
      console.error('🔐 [AUTH_MIDDLEWARE] Checking auth object...');
      console.error('🔐 [AUTH_MIDDLEWARE] Auth object type:', typeof auth);
      console.error('🔐 [AUTH_MIDDLEWARE] Auth object exists:', !!auth);
      if (auth && auth.app) {
        console.error('🔐 [AUTH_MIDDLEWARE] Firebase app name:', auth.app.name);
        console.error('🔐 [AUTH_MIDDLEWARE] Firebase project ID:', auth.app.options?.projectId);
      }
    } catch (checkError) {
      console.error('🔐 [AUTH_MIDDLEWARE] Error checking auth object:', checkError);
    }
    
    console.error('🔐 [AUTH_MIDDLEWARE] ========================================');

    // 10. Return appropriate error message based on error type
    let message = 'authentication Failed';
    let errorCode = error.code || 'unknown';

    if (error.code === 'auth/id-token-expired') {
      message = 'Token expired';
    } else if (error.code === 'auth/id-token-revoked') {
      message = 'Token revoked';
    } else if (error.code === 'auth/argument-error') {
      message = 'Invalid token format';
    } else if (error.code === 'auth/insufficient-permission') {
      message = 'Insufficient permissions';
    } else if (error.code === 'auth/project-not-found') {
      message = 'Firebase project not found';
    } else if (error.code === 'auth/invalid-credential') {
      message = 'Invalid Firebase credentials';
    } else if (error.message && error.message.includes('project')) {
      message = 'Firebase project configuration error';
    } else if (error.message && (error.message.includes('future') || error.message.includes('clock'))) {
      // Clock skew detected
      message = 'Token validation failed due to clock synchronization issue';
      errorCode = 'clock-skew';
      console.error('🔐 [AUTH_MIDDLEWARE] CLOCK SKEW DETECTED in error message');
    }

    return res.status(401).json({
      success: false,
      message: message,
      errorCode: errorCode,
      // Include error message in development for debugging
      ...(process.env.NODE_ENV !== 'production' && { debugMessage: error.message })
    });
  }
};

/**
 * Middleware for new user registration - only verifies Firebase token
 * Does NOT check if user exists in Firestore (since we're creating them)
 */
const protectNewUser = async (req, res, next) => {
  try {
    console.log('🔐 [AUTH_MIDDLEWARE] Starting new user authentication check');
    
    // 1. Extract Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      console.log('🔐 [AUTH_MIDDLEWARE] No authorization header present');
      return res.status(401).json({
        success: false,
        message: 'No authorization header'
      });
    }

    // 2. Check Bearer format (with space after "Bearer")
    if (!authHeader.startsWith('Bearer ')) {
      console.error('🔐 [AUTH_MIDDLEWARE] Invalid authorization format');
      return res.status(401).json({
        success: false,
        message: 'Invalid authorization format. Expected "Bearer <token>"'
      });
    }

    // 3. Extract and clean token (remove "Bearer " prefix and trim whitespace)
    const token = authHeader.split('Bearer ')[1]?.trim();
    
    if (!token) {
      console.error('🔐 [AUTH_MIDDLEWARE] Token is empty after Bearer');
      return res.status(401).json({
        success: false,
        message: 'Token is empty'
      });
    }

    console.log('🔐 [AUTH_MIDDLEWARE] Token received (first 20 chars):', token.substring(0, 20));
    console.log('🔐 [AUTH_MIDDLEWARE] Token length:', token.length);
    console.log('🔐 [AUTH_MIDDLEWARE] Verifying Firebase token for new user...');
    console.log('🔐 [AUTH_MIDDLEWARE] Server time:', new Date().toISOString());
    
    // 4. Verify Firebase ID token with retry logic (handles clock skew and propagation delays)
    let decodedToken;
    let lastError;
    const maxRetries = 3;
    const retryDelays = [0, 500, 1000]; // Immediate, 500ms, 1s
    
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          console.log(`🔐 [AUTH_MIDDLEWARE] Retry attempt ${attempt + 1}/${maxRetries} after ${retryDelays[attempt]}ms delay`);
          await new Promise(resolve => setTimeout(resolve, retryDelays[attempt]));
        }
        
        // First attempt: don't check revoked (faster, avoids propagation delays)
        // Subsequent attempts: check revoked
        const checkRevoked = attempt > 0;
        decodedToken = await auth.verifyIdToken(token, checkRevoked);
        break; // Success
      } catch (verifyError) {
        lastError = verifyError;
        console.error(`🔐 [AUTH_MIDDLEWARE] verifyIdToken attempt ${attempt + 1} failed:`, verifyError.code);
        
        // Don't retry for certain errors
        if (verifyError.code === 'auth/argument-error' || 
            verifyError.code === 'auth/invalid-credential' ||
            verifyError.code === 'auth/project-not-found') {
          throw verifyError;
        }
        
        if (attempt < maxRetries - 1) {
          console.log(`🔐 [AUTH_MIDDLEWARE] Retrying due to: ${verifyError.code}`);
        } else {
          throw verifyError;
        }
      }
    }
    
    if (!decodedToken) {
      throw lastError || new Error('Token verification failed after retries');
    }
    
    console.log('🔐 [AUTH_MIDDLEWARE] Token verified! UID:', decodedToken.uid);
    
    // 5. Attach basic user info from token
    req.user = {
      id: decodedToken.uid,
      email: decodedToken.email
    };
    
    next();
  } catch (error) {
    console.error('🔐 [AUTH_MIDDLEWARE] ========================================');
    console.error('🔐 [AUTH_MIDDLEWARE] New user authentication failed');
    console.error('🔐 [AUTH_MIDDLEWARE] Error code:', error.code);
    console.error('🔐 [AUTH_MIDDLEWARE] Error message:', error.message);
    console.error('🔐 [AUTH_MIDDLEWARE] ========================================');

    // Return appropriate error message based on error type
    let message = 'authentication Failed';
    let errorCode = error.code || 'unknown';

    if (error.code === 'auth/id-token-expired') {
      message = 'Token expired';
    } else if (error.code === 'auth/id-token-revoked') {
      message = 'Token revoked';
    } else if (error.code === 'auth/argument-error') {
      message = 'Invalid token format';
    }

    return res.status(401).json({
      success: false,
      message: message,
      errorCode: errorCode
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

