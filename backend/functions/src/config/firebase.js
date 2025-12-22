const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
try {
  console.log('🔧 [FIREBASE_INIT] ========================================');
  console.log('🔧 [FIREBASE_INIT] Starting Firebase Admin SDK initialization...');
  
  // Log environment variables (before loading service account)
  console.log('🔧 [FIREBASE_INIT] Environment Variables:');
  console.log('🔧 [FIREBASE_INIT] - NODE_ENV:', process.env.NODE_ENV || 'not set');
  console.log('🔧 [FIREBASE_INIT] - APP_STORAGE_BUCKET:', process.env.APP_STORAGE_BUCKET || 'not set (will use default)');
  console.log('🔧 [FIREBASE_INIT] - FUNCTIONS_EMULATOR:', process.env.FUNCTIONS_EMULATOR || 'not set (production mode)');
  
  const serviceAccount = require('../../firebase-service-account.json');
  
  // Log service account info (masked for security)
  console.log('🔧 [FIREBASE_INIT] Service Account Loaded:');
  console.log('🔧 [FIREBASE_INIT] - Project ID:', serviceAccount.project_id || 'not found');
  console.log('🔧 [FIREBASE_INIT] - Client Email:', serviceAccount.client_email || 'not found');
  console.log('🔧 [FIREBASE_INIT] - Private Key:', serviceAccount.private_key ? `***SET (${serviceAccount.private_key.length} chars)***` : '❌ MISSING');
  
  // Get storage bucket from environment variable or use default
  // Default bucket name matches frontend configuration
  const storageBucket = process.env.APP_STORAGE_BUCKET || 
                       'xperience-gaming.firebasestorage.app';
  
  console.log('🔧 [FIREBASE_INIT] Initializing Firebase Admin with:');
  console.log('🔧 [FIREBASE_INIT] - Storage Bucket:', storageBucket);
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: storageBucket
  });

  const db = admin.firestore();
  const auth = admin.auth();

  // Verify initialization
  const app = admin.app();
  const projectId = app.options.projectId;
  const credentialProjectId = serviceAccount.project_id;

  console.log('🔧 [FIREBASE_INIT] ========================================');
  console.log('✅ Firebase Admin SDK initialized successfully');
  console.log('✅ Firestore connected');
  console.log('✅ Storage bucket configured:', storageBucket);
  console.log('✅ Project ID:', projectId);
  console.log('✅ Service account project ID:', credentialProjectId);
  
  if (projectId !== credentialProjectId) {
    console.warn('⚠️  WARNING: Project ID mismatch!');
    console.warn('⚠️  App project ID:', projectId);
    console.warn('⚠️  Service account project ID:', credentialProjectId);
  }

  // Test auth initialization
  try {
    console.log('✅ Auth service initialized');
    console.log('✅ Auth app name:', auth.app.name);
  } catch (authError) {
    console.error('❌ Auth service initialization error:', authError);
  }
  
  console.log('🔧 [FIREBASE_INIT] ========================================');

  module.exports = { db, auth, admin };
} catch (error) {
  console.error('🔧 [FIREBASE_INIT] ========================================');
  console.error('❌ Firebase initialization failed:', error.message);
  console.error('❌ Error stack:', error.stack);
  console.error('Make sure firebase-service-account.json exists in backend/ directory');
  console.error('🔧 [FIREBASE_INIT] ========================================');
  process.exit(1);
}

