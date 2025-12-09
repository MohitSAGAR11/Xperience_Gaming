const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require('../../firebase-service-account.json');
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });

  const db = admin.firestore();
  const auth = admin.auth();

  console.log('✅ Firebase Admin SDK initialized successfully');
  console.log('✅ Firestore connected');

  module.exports = { db, auth, admin };
} catch (error) {
  console.error('❌ Firebase initialization failed:', error.message);
  console.error('Make sure firebase-service-account.json exists in backend/ directory');
  process.exit(1);
}

