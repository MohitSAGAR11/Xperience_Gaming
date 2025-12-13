const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require('../../firebase-service-account.json');
  
  // Get storage bucket from service account or use project ID
  const storageBucket = process.env.FIREBASE_STORAGE_BUCKET || 
                        serviceAccount.project_id + '.appspot.com';
  
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

