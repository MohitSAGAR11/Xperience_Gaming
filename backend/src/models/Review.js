const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

/**
 * Review Model - For cafe ratings and comments
 */
const Review = sequelize.define('Review', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  
  // Foreign Keys (defined in associations)
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  
  cafeId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'cafes',
      key: 'id'
    }
  },
  
  // Rating (1-5 stars)
  rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 5
    }
  },
  
  // Review comment
  comment: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  
  // Optional: Title for the review
  title: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  
  // Owner's response to the review
  ownerResponse: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  
  ownerResponseAt: {
    type: DataTypes.DATE,
    allowNull: true
  },
  
  // Helpful votes count
  helpfulCount: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  
  // Is the review visible
  isVisible: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'reviews',
  timestamps: true,
  indexes: [
    // Ensure one review per user per cafe
    {
      unique: true,
      fields: ['userId', 'cafeId'],
      name: 'unique_user_cafe_review'
    },
    // Index for fetching cafe reviews
    {
      fields: ['cafeId', 'createdAt'],
      name: 'idx_reviews_cafe_date'
    },
    // Index for user's reviews
    {
      fields: ['userId'],
      name: 'idx_reviews_user'
    }
  ]
});

module.exports = Review;

