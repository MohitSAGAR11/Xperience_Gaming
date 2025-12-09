const { sequelize } = require('../config/db');
const User = require('./User');
const Cafe = require('./Cafe');
const Booking = require('./Booking');
const Review = require('./Review');

// Define Relationships

// User hasMany Cafes (An owner can have multiple cafes)
User.hasMany(Cafe, {
  foreignKey: 'ownerId',
  as: 'cafes',
  onDelete: 'CASCADE'
});

Cafe.belongsTo(User, {
  foreignKey: 'ownerId',
  as: 'owner'
});

// User hasMany Bookings (A client can have multiple bookings)
User.hasMany(Booking, {
  foreignKey: 'userId',
  as: 'bookings',
  onDelete: 'CASCADE'
});

Booking.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user'
});

// Cafe hasMany Bookings (A cafe can have multiple bookings)
Cafe.hasMany(Booking, {
  foreignKey: 'cafeId',
  as: 'bookings',
  onDelete: 'CASCADE'
});

Booking.belongsTo(Cafe, {
  foreignKey: 'cafeId',
  as: 'cafe'
});

// User hasMany Reviews (A user can review multiple cafes)
User.hasMany(Review, {
  foreignKey: 'userId',
  as: 'reviews',
  onDelete: 'CASCADE'
});

Review.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user'
});

// Cafe hasMany Reviews (A cafe can have multiple reviews)
Cafe.hasMany(Review, {
  foreignKey: 'cafeId',
  as: 'reviews',
  onDelete: 'CASCADE'
});

Review.belongsTo(Cafe, {
  foreignKey: 'cafeId',
  as: 'cafe'
});

module.exports = {
  sequelize,
  User,
  Cafe,
  Booking,
  Review
};

