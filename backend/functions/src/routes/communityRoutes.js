const express = require('express');
const router = express.Router();
const {
  getCommunityFeed,
  getCommunityStats
} = require('../controllers/communityController');

// Public routes (anyone can see community feed)
router.get('/feed', getCommunityFeed);
router.get('/stats', getCommunityStats);

module.exports = router;

