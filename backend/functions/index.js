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
const payuMerchantKey = defineString('PAYU_MERCHANT_KEY');
const payuMerchantSalt = defineSecret('PAYU_MERCHANT_SALT');
const payuMode = defineString('PAYU_MODE', { default: 'test' });
const payuBaseUrl = defineString('PAYU_BASE_URL');
const backendUrl = defineString('BACKEND_URL', {
  default: 'https://asia-south1-xperience-gaming.cloudfunctions.net/api'
});

// Set storage bucket env variable BEFORE Firebase initialization
// This ensures firebase.js can access it during initialization
process.env.FIREBASE_STORAGE_BUCKET = firebaseStorageBucket.value();

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
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Set environment variables from params (for backward compatibility)
app.use((req, res, next) => {
  process.env.NODE_ENV = nodeEnv.value();
  process.env.CORS_ORIGIN = corsOrigin.value();
  process.env.FRONTEND_URL = frontendUrl.value();
  process.env.JWT_SECRET = jwtSecret.value();
  process.env.JWT_EXPIRES_IN = jwtExpiresIn.value();
  process.env.FIREBASE_STORAGE_BUCKET = firebaseStorageBucket.value();
  process.env.PAYU_MERCHANT_KEY = payuMerchantKey.value();
  process.env.PAYU_MERCHANT_SALT = payuMerchantSalt.value();
  process.env.PAYU_MODE = payuMode.value();
  process.env.PAYU_BASE_URL = payuBaseUrl.value();
  process.env.BACKEND_URL = backendUrl.value();
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
    secrets: [jwtSecret, payuMerchantSalt]
  },
  app
);