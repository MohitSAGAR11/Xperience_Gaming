const express = require('express');
const router = express.Router();
const { protect, ownerOnly } = require('../middleware/authMiddleware');
const { 
  upload, 
  uploadCafeImage, 
  deleteCafeImage 
} = require('../controllers/uploadController');

// All routes require authentication and owner role
router.use(protect);
router.use(ownerOnly);

// Upload cafe image
router.post('/cafe-image/:cafeId', upload.single('image'), uploadCafeImage);

// Delete cafe image
router.delete('/cafe-image/:cafeId', deleteCafeImage);

module.exports = router;

