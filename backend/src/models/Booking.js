const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

const Booking = sequelize.define('Booking', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
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
  // Type of station being booked
  stationType: {
    type: DataTypes.ENUM('pc', 'console'),
    allowNull: false,
    defaultValue: 'pc'
  },
  // Console type (only required when stationType is 'console')
  consoleType: {
    type: DataTypes.ENUM('ps5', 'ps4', 'xbox_series_x', 'xbox_series_s', 'xbox_one', 'nintendo_switch'),
    allowNull: true
  },
  // Station/Console unit number
  stationNumber: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1
    }
  },
  bookingDate: {
    type: DataTypes.DATEONLY,
    allowNull: false
  },
  startTime: {
    type: DataTypes.TIME,
    allowNull: false
  },
  endTime: {
    type: DataTypes.TIME,
    allowNull: false
  },
  durationHours: {
    type: DataTypes.DECIMAL(4, 2),
    allowNull: false
  },
  hourlyRate: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  totalAmount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  status: {
    type: DataTypes.ENUM('pending', 'confirmed', 'cancelled', 'completed'),
    defaultValue: 'pending'
  },
  paymentStatus: {
    type: DataTypes.ENUM('unpaid', 'paid', 'refunded'),
    defaultValue: 'unpaid'
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  tableName: 'bookings',
  timestamps: true,
  indexes: [
    { fields: ['userId'] },
    { fields: ['cafeId'] },
    { fields: ['bookingDate'] },
    { fields: ['status'] },
    { fields: ['stationType'] },
    { 
      fields: ['cafeId', 'bookingDate', 'stationType', 'consoleType', 'stationNumber', 'startTime', 'endTime'],
      name: 'booking_conflict_check'
    }
  ],
  validate: {
    endAfterStart() {
      if (this.startTime >= this.endTime) {
        throw new Error('End time must be after start time');
      }
    }
  }
});

module.exports = Booking;

