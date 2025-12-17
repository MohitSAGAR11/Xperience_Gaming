const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require('../../firebase-service-account.json');
  
  // Get storage bucket from environment variable or use default
  // Default bucket name matches frontend configuration
  const storageBucket = process.env.APP_STORAGE_BUCKET || 
                       'xperience-gaming.firebasestorage.app';
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: storageBucket
  });

  const db = admin.firestore();
  const auth = admin.auth();

  console.log('✅ Firebase Admin SDK initialized successfully');
  console.log('✅ Firestore connected');
  console.log('✅ Storage bucket configured:', storageBucket);

  module.exports = { db, auth, admin };
} catch (error) {
  console.error('❌ Firebase initialization failed:', error.message);
  console.error('Make sure firebase-service-account.json exists in backend/ directory');
  process.exit(1);
}

