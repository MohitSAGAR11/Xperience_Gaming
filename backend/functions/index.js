// Load environment variables for local development
if (process.env.FUNCTIONS_EMULATOR === 'true') {
  require('dotenv').config({ path: '.env.local' });
}

const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineString, defineSecret } = require('firebase-functions/params');
const express = require('express');
const cors = require('cors');

// Set global options
setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 10,
  timeoutSeconds: 540,
  memory: '2GiB'
});

const nodeEnv = defineString('NODE_ENV', { default: 'production' });
const corsOrigin = defineString('CORS_ORIGIN', { default: '*' });
const frontendUrl = defineString('FRONTEND_URL');
const jwtSecret = defineSecret('JWT_SECRET');
const jwtExpiresIn = defineString('JWT_EXPIRES_IN', { default: '7d' });
const firebaseStorageBucket = defineString('APP_STORAGE_BUCKET', { 
  default: 'xperience-gaming.firebasestorage.app' 
});
// Cashfree Configuration
const cashfreeClientId = defineString('CASHFREE_CLIENT_ID');
const cashfreeClientSecret = defineSecret('CASHFREE_CLIENT_SECRET');
const cashfreeApiVersion = defineString('CASHFREE_API_VERSION', { default: '2023-08-01' });
const cashfreeBaseUrl = defineString('CASHFREE_BASE_URL', { default: 'https://sandbox.cashfree.com' });
const backendUrl = defineString('BACKEND_URL', {
  default: 'https://asia-south1-xperience-gaming.cloudfunctions.net/api'
});

// Set storage bucket env variable BEFORE Firebase initialization
// Use default value for initialization (param will be resolved at runtime in middleware)
// The actual runtime value will be set in middleware below (line 78)
process.env.APP_STORAGE_BUCKET = 'xperience-gaming.firebasestorage.app';

// Initialize Firebase
require('./src/config/firebase');

// Import routes
const authRoutes = require('./src/routes/authRoutes');
const cafeRoutes = require('./src/routes/cafeRoutes');
const bookingRoutes = require('./src/routes/bookingRoutes');
const reviewRoutes = require('./src/routes/reviewRoutes');
const communityRoutes = require('./src/routes/communityRoutes');
const uploadRoutes = require('./src/routes/uploadRoutes');
const paymentRoutes = require('./src/routes/paymentRoutes');

// Initialize express app
const app = express();

// Middleware
app.use((req, res, next) => {
  cors({
    origin: corsOrigin.value(), // Now this runs only when a request hits
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    exposedHeaders: ['Content-Type', 'Authorization'],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    preflightContinue: false,
    optionsSuccessStatus: 204
  })(req, res, next);
});

// Body parsers - SKIP multipart/form-data AND upload routes (let busboy handle it)
// This prevents "Unexpected end of form" errors when uploading files
// Create parser instances once for efficiency
const jsonParser = express.json({ limit: '10mb' });
const urlencodedParser = express.urlencoded({ extended: true });
// Raw body parser for upload routes - preserves raw buffer for busboy
// Note: We use raw() without type restriction to capture all body data as buffer
const rawParser = express.raw({ limit: '10mb' });

app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  const isUploadRoute = req.path.startsWith('/upload');
  
  // Log request details for debugging
  if (contentType.includes('multipart') || isUploadRoute) {
    console.log('📸 [BODY_PARSER] Upload-related request detected:', {
      method: req.method,
      path: req.path,
      contentType: contentType,
      contentLength: req.headers['content-length'],
      isUploadRoute: isUploadRoute,
      bodyAlreadyParsed: !!req.body && Object.keys(req.body).length > 0,
      readable: req.readable,
      readableEnded: req.readableEnded,
    });
    
    // WARNING: If body is already parsed, Multer won't work
    if (req.body && Object.keys(req.body).length > 0) {
      console.error('📸 [BODY_PARSER] ⚠️ WARNING: Body already parsed! This will break Multer.');
    }
  }
  
  // CRITICAL: For upload routes, use raw parser to preserve body buffer for busboy
  // BUT: DELETE requests on upload routes need JSON parsing (for image deletion)
  if (isUploadRoute) {
    // DELETE requests should use JSON parser, not raw parser
    if (req.method === 'DELETE') {
      return jsonParser(req, res, next);
    }
    
    console.log('📸 [BODY_PARSER] Using raw parser for upload route to preserve body buffer');
    // Use raw parser to get body as buffer, then store it for busboy
    return rawParser(req, res, () => {
      // req.body will be a Buffer when using express.raw()
      if (Buffer.isBuffer(req.body)) {
        req.rawBody = req.body; // Store raw buffer for busboy
        req.body = {}; // Clear to avoid confusion
        console.log('📸 [BODY_PARSER] Raw body buffer preserved, size:', req.rawBody.length);
      } else {
        console.error('📸 [BODY_PARSER] ⚠️ Body is not a buffer! Type:', typeof req.body);
        // Try to convert to buffer if it's a string
        if (typeof req.body === 'string') {
          req.rawBody = Buffer.from(req.body, 'binary');
          req.body = {};
          console.log('📸 [BODY_PARSER] Converted string to buffer, size:', req.rawBody.length);
        } else {
          return res.status(400).json({
            success: false,
            message: 'Unable to process file upload: body format not supported'
          });
        }
      }
      next();
    });
  }
  
  // Skip body parsing for multipart/form-data - Multer will handle it
  if (contentType.includes('multipart/form-data')) {
    console.log('📸 [BODY_PARSER] Skipping body parsing for multipart request');
    return next();
  }
  
  // Skip parsing for GET, HEAD, OPTIONS requests (no body)
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }
  
  // For JSON requests, use JSON parser
  if (contentType.includes('application/json')) {
    return jsonParser(req, res, next);
  }
  
  // For URL-encoded requests, use URL-encoded parser
  if (contentType.includes('application/x-www-form-urlencoded')) {
    return urlencodedParser(req, res, next);
  }
  
  // For requests without explicit content-type but with body, try JSON parser
  // (This handles cases where Content-Type header is missing but body is JSON)
  if (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH') {
    return jsonParser(req, res, next);
  }
  
  // No body parsing needed
  next();
});

// Set environment variables from params (for backward compatibility)
app.use((req, res, next) => {
  process.env.NODE_ENV = nodeEnv.value();
  process.env.CORS_ORIGIN = corsOrigin.value();
  process.env.FRONTEND_URL = frontendUrl.value();
  process.env.JWT_SECRET = jwtSecret.value();
  process.env.JWT_EXPIRES_IN = jwtExpiresIn.value();
  process.env.APP_STORAGE_BUCKET = firebaseStorageBucket.value();
  // Cashfree Environment Variables
  process.env.CASHFREE_CLIENT_ID = cashfreeClientId.value();
  process.env.CASHFREE_CLIENT_SECRET = cashfreeClientSecret.value();
  process.env.CASHFREE_API_VERSION = cashfreeApiVersion.value();
  process.env.CASHFREE_BASE_URL = cashfreeBaseUrl.value();
  process.env.BACKEND_URL = backendUrl.value();
  
  // Log Payment Gateway configuration on first request (for debugging)
  if (!global.paymentConfigLogged) {
    console.log('💳 [PAYMENT_CONFIG] ========================================');
    console.log('💳 [PAYMENT_CONFIG] Cashfree Configuration Status:');
    console.log('💳 [PAYMENT_CONFIG] CASHFREE_CLIENT_ID:', cashfreeClientId.value() ? `${cashfreeClientId.value().substring(0, 4)}...` : '❌ MISSING');
    console.log('💳 [PAYMENT_CONFIG] CASHFREE_CLIENT_SECRET:', cashfreeClientSecret.value() ? '✅ SET' : '❌ MISSING');
    console.log('💳 [PAYMENT_CONFIG] CASHFREE_BASE_URL:', cashfreeBaseUrl.value() || '❌ MISSING');
    console.log('💳 [PAYMENT_CONFIG] CASHFREE_API_VERSION:', cashfreeApiVersion.value() || '2023-08-01 (default)');
    console.log('💳 [PAYMENT_CONFIG] Environment:', cashfreeBaseUrl.value()?.includes('sandbox') ? '🟡 SANDBOX' : cashfreeBaseUrl.value()?.includes('api.cashfree.com') ? '🟢 PRODUCTION' : '❓ UNKNOWN');
    console.log('💳 [PAYMENT_CONFIG] ========================================');
    global.paymentConfigLogged = true;
  }
  
  next();
});

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} | ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Gaming Cafe API is running on Firebase Functions',
    timestamp: new Date().toISOString(),
    environment: nodeEnv.value()
  });
});

// API Routes
app.use('/auth', authRoutes);
app.use('/cafes', cafeRoutes);
app.use('/bookings', bookingRoutes);
app.use('/reviews', reviewRoutes);
app.use('/community', communityRoutes);
app.use('/upload', uploadRoutes);
app.use('/payments', paymentRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} not found`
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Server Error:', err);

  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// Export the Express app as a Firebase Function (Gen 2)
exports.api = onRequest(
  {
    secrets: [jwtSecret, cashfreeClientSecret]
  },
  app
);