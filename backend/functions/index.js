const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');

// Initialize Firebase (replaces PostgreSQL connection)
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
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  exposedHeaders: ['Content-Type', 'Authorization'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  preflightContinue: false,
  optionsSuccessStatus: 204
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

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
    timestamp: new Date().toISOString()
  });
});

// API Routes - Remove /api prefix as it will be in the function name
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

// Export the Express app as a Firebase Function
// This will be accessible at: https://REGION-PROJECT_ID.cloudfunctions.net/api
exports.api = functions
  .region('asia-south1') // Change to your preferred region
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .https.onRequest(app);

// Optional: Additional Firebase Functions for specific tasks

// Example: Scheduled function to clean up old bookings
exports.cleanupOldBookings = functions
  .region('asia-south1')
  .pubsub.schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('Running scheduled cleanup...');
    // Add your cleanup logic here
    return null;
  });

// Example: Firestore trigger for new user creation
exports.onUserCreated = functions
  .region('asia-south1')
  .firestore.document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    console.log('New user created:', context.params.userId);
    // Add welcome email or initialization logic here
    return null;
  });