const admin = require('firebase-admin');
const { db } = require('../config/firebase');
const busboy = require('busboy');
const path = require('path');

/**
 * Middleware to parse multipart/form-data using busboy
 * This works even when Firebase Functions has already consumed the body stream
 * by using req.rawBody if available, or reconstructing from req.body
 */
const parseMultipart = (req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  
  if (!contentType.includes('multipart/form-data')) {
    return next();
  }

  // Get the raw body - Firebase Functions v2 may provide this
  let bodyBuffer = null;
  
  if (req.rawBody) {
    // Use rawBody if available (Firebase Functions v2 sometimes provides this)
    bodyBuffer = Buffer.isBuffer(req.rawBody) ? req.rawBody : Buffer.from(req.rawBody);
  } else if (req.body && typeof req.body === 'string') {
    // If body was parsed as string, convert back to buffer
    bodyBuffer = Buffer.from(req.body, 'binary');
  } else {
    // Last resort: try to get from readable stream (unlikely to work if already consumed)
    console.error('No raw body available and stream already consumed');
    return res.status(400).json({
      success: false,
      message: 'Unable to process file upload: request body was already consumed'
    });
  }

  const bb = busboy({
    headers: req.headers,
    limits: {
      fileSize: 10 * 1024 * 1024, // 10MB limit
    }
  });

  const fileData = {
    buffer: null,
    filename: null,
    mimetype: null,
    encoding: null,
  };

  let fileReceived = false;

  bb.on('file', (name, file, info) => {
    const { filename, encoding, mimeType } = info;

    // Validate file type
    const allowedTypes = /jpeg|jpg|png|webp/i;
    const extname = allowedTypes.test(path.extname(filename).toLowerCase());
    const mimetype = allowedTypes.test(mimeType);

    if (!mimetype || !extname) {
      file.resume(); // Drain the file stream
      return res.status(400).json({
        success: false,
        message: 'Only image files (JPEG, JPG, PNG, WEBP) are allowed!'
      });
    }

    fileReceived = true;
    fileData.filename = filename;
    fileData.mimetype = mimeType;
    fileData.encoding = encoding;

    const chunks = [];
    file.on('data', (chunk) => {
      chunks.push(chunk);
    });

    file.on('end', () => {
      fileData.buffer = Buffer.concat(chunks);
    });
  });

  bb.on('finish', () => {
    if (!fileReceived || !fileData.buffer) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    // Attach file to request object (Multer-compatible format)
    req.file = {
      fieldname: 'image',
      originalname: fileData.filename,
      encoding: fileData.encoding,
      mimetype: fileData.mimetype,
      buffer: fileData.buffer,
      size: fileData.buffer.length,
    };

    next();
  });

  bb.on('error', (err) => {
    console.error('Busboy parsing error:', err);
    res.status(400).json({
      success: false,
      message: `Upload error: ${err.message}`
    });
  });

  // Write the body buffer to busboy
  bb.end(bodyBuffer);
};

/**
 * @desc    Upload cafe image to Firebase Storage
 * @route   POST /api/upload/cafe-image/:cafeId
 * @access  Private/Owner
 */
const uploadCafeImage = async (req, res) => {
  try {

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
        console.error('Upload error:', error);
        reject(error);
      });

      stream.on('finish', () => {
        resolve();
      });

      stream.end(req.file.buffer);
    });

    // Make file publicly accessible
    await file.makePublic();

    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filepath}`;

    // Add URL to cafe's photos array
    const currentPhotos = cafe.photos || [];
    const updatedPhotos = [...currentPhotos, publicUrl];

    await db.collection('cafes').doc(cafeId).update({
      photos: updatedPhotos,
      updatedAt: new Date()
    });

    res.json({
      success: true,
      message: 'Image uploaded successfully',
      data: {
        url: publicUrl,
        totalPhotos: updatedPhotos.length
      }
    });

  } catch (error) {
    console.error('Upload error:', error);
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

    // Delete file from Storage
    try {
      await bucket.file(filepath).delete();
    } catch (storageError) {
      // File may not exist, continue with removing from database
    }

    // Remove URL from cafe's photos array
    const currentPhotos = cafe.photos || [];
    const updatedPhotos = currentPhotos.filter(url => url !== imageUrl);

    await db.collection('cafes').doc(cafeId).update({
      photos: updatedPhotos,
      updatedAt: new Date()
    });

    res.json({
      success: true,
      message: 'Image deleted successfully',
      data: {
        totalPhotos: updatedPhotos.length
      }
    });

  } catch (error) {
    console.error('Delete image error:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting image',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  parseMultipart,
  uploadCafeImage,
  deleteCafeImage
};

