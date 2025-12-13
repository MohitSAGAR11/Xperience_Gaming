const admin = require('firebase-admin');
const { db } = require('../config/firebase');
const multer = require('multer');
const path = require('path');

// Configure multer for memory storage
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    console.log('📸 [FILE_FILTER] Checking file:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      fieldname: file.fieldname,
    });

    const allowedTypes = /jpeg|jpg|png|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    console.log('📸 [FILE_FILTER] Extension check:', extname);
    console.log('📸 [FILE_FILTER] Mimetype check:', mimetype);

    if (mimetype && extname) {
      console.log('📸 [FILE_FILTER] ✅ File accepted');
      return cb(null, true);
    } else {
      console.log('📸 [FILE_FILTER] ❌ File rejected');
      cb(new Error('Only image files (JPEG, JPG, PNG, WEBP) are allowed!'));
    }
  },
});

/**
 * @desc    Upload cafe image to Firebase Storage
 * @route   POST /api/upload/cafe-image/:cafeId
 * @access  Private/Owner
 */
const uploadCafeImage = async (req, res) => {
  try {
    console.log('📸 [UPLOAD] Starting image upload for cafe:', req.params.cafeId);

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    const cafeId = req.params.cafeId;
    const userId = req.user.id;

    // Verify cafe ownership
    const cafeDoc = await db.collection('cafes').doc(cafeId).get();
    
    if (!cafeDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    const cafe = cafeDoc.data();
    
    if (cafe.ownerId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to upload images for this cafe'
      });
    }

    // Generate unique filename
    const timestamp = Date.now();
    const filename = `${cafeId}_${timestamp}${path.extname(req.file.originalname)}`;
    const filepath = `cafes/${cafeId}/${filename}`;

    console.log('📸 [UPLOAD] Uploading to path:', filepath);

    // Get Firebase Storage bucket
    const bucket = admin.storage().bucket();
    const file = bucket.file(filepath);

    // Create write stream
    const stream = file.createWriteStream({
      metadata: {
        contentType: req.file.mimetype,
        metadata: {
          cafeId: cafeId,
          uploadedBy: userId,
          uploadedAt: new Date().toISOString()
        }
      }
    });

    // Handle upload completion
    await new Promise((resolve, reject) => {
      stream.on('error', (error) => {
        console.error('📸 [UPLOAD] Error:', error);
        reject(error);
      });

      stream.on('finish', () => {
        console.log('📸 [UPLOAD] File uploaded successfully');
        resolve();
      });

      stream.end(req.file.buffer);
    });

    // Make file publicly accessible
    await file.makePublic();

    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filepath}`;
    console.log('📸 [UPLOAD] Public URL:', publicUrl);

    // Add URL to cafe's photos array
    const currentPhotos = cafe.photos || [];
    const updatedPhotos = [...currentPhotos, publicUrl];

    await db.collection('cafes').doc(cafeId).update({
      photos: updatedPhotos,
      updatedAt: new Date()
    });

    console.log('📸 [UPLOAD] Cafe photos updated. Total:', updatedPhotos.length);

    res.json({
      success: true,
      message: 'Image uploaded successfully',
      data: {
        url: publicUrl,
        totalPhotos: updatedPhotos.length
      }
    });

  } catch (error) {
    console.error('📸 [UPLOAD] Error:', error);
    res.status(500).json({
      success: false,
      message: 'Error uploading image',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * @desc    Delete cafe image from Firebase Storage
 * @route   DELETE /api/upload/cafe-image/:cafeId
 * @access  Private/Owner
 */
const deleteCafeImage = async (req, res) => {
  try {
    const { imageUrl } = req.body;
    const cafeId = req.params.cafeId;
    const userId = req.user.id;

    console.log('📸 [DELETE] Deleting image for cafe:', cafeId);

    if (!imageUrl) {
      return res.status(400).json({
        success: false,
        message: 'Image URL is required'
      });
    }

    // Verify cafe ownership
    const cafeDoc = await db.collection('cafes').doc(cafeId).get();
    
    if (!cafeDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Cafe not found'
      });
    }

    const cafe = cafeDoc.data();
    
    if (cafe.ownerId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete images for this cafe'
      });
    }

    // Extract file path from URL
    const bucket = admin.storage().bucket();
    const urlParts = imageUrl.split(`${bucket.name}/`);
    
    if (urlParts.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Invalid image URL'
      });
    }

    const filepath = urlParts[1];
    console.log('📸 [DELETE] Deleting file:', filepath);

    // Delete file from Storage
    try {
      await bucket.file(filepath).delete();
      console.log('📸 [DELETE] File deleted from Storage');
    } catch (storageError) {
      console.warn('📸 [DELETE] File not found in Storage, continuing...');
    }

    // Remove URL from cafe's photos array
    const currentPhotos = cafe.photos || [];
    const updatedPhotos = currentPhotos.filter(url => url !== imageUrl);

    await db.collection('cafes').doc(cafeId).update({
      photos: updatedPhotos,
      updatedAt: new Date()
    });

    console.log('📸 [DELETE] Photo removed from cafe. Remaining:', updatedPhotos.length);

    res.json({
      success: true,
      message: 'Image deleted successfully',
      data: {
        totalPhotos: updatedPhotos.length
      }
    });

  } catch (error) {
    console.error('📸 [DELETE] Error:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting image',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  upload,
  uploadCafeImage,
  deleteCafeImage
};

