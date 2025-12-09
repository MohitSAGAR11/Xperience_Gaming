require('dotenv').config();
const express = require('express');
const cors = require('cors');
// Initialize Firebase (replaces PostgreSQL connection)
require('./src/config/firebase');

// Import routes
const authRoutes = require('./src/routes/authRoutes');
const cafeRoutes = require('./src/routes/cafeRoutes');
const bookingRoutes = require('./src/routes/bookingRoutes');
const reviewRoutes = require('./src/routes/reviewRoutes');

// Initialize express app
const app = express();

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging in development
if (process.env.NODE_ENV === 'development') {
  app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} | ${req.method} ${req.path}`);
    next();
  });
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Gaming Cafe API is running',
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/cafes', cafeRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/reviews', reviewRoutes);

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

// Start server
const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    // Firebase is initialized in firebase.js config file
    // No need for database connection with Firestore

    // Listen on all network interfaces (0.0.0.0) for physical device access
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`
╔══════════════════════════════════════════════════╗
║                                                  ║
║   🎮 Gaming Cafe Backend API                     ║
║   ────────────────────────────                   ║
║   Server running on port ${PORT}                    ║
║   Environment: ${process.env.NODE_ENV || 'development'}                    ║
║                                                  ║
║   Endpoints:                                     ║
    ║   • Auth:     /api/auth                          ║
    ║   • Cafes:    /api/cafes                         ║
    ║   • Bookings: /api/bookings                      ║
    ║   • Reviews:  /api/reviews                       ║
    ║   • Health:   /api/health                        ║
║                                                  ║
╚══════════════════════════════════════════════════╝
      `);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

module.exports = app;

