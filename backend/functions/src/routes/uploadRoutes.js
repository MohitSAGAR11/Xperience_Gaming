const express = require('express');
const router = express.Router();
const { protect, ownerOnly } = require('../middleware/authMiddleware');
const { 
  parseMultipart,
  uploadCafeImage, 
  deleteCafeImage
} = require('../controllers/uploadController');

// All routes require authentication and owner role
router.use(protect);
router.use(ownerOnly);

// Upload cafe image
// Using busboy directly instead of Multer to handle Firebase Functions v2 body consumption
router.post('/cafe-image/:cafeId', parseMultipart, uploadCafeImage);

// Delete cafe image
router.delete('/cafe-image/:cafeId', deleteCafeImage);

module.exports = router;

