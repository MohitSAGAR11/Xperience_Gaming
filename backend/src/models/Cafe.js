const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/db');

const Cafe = sequelize.define('Cafe', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  ownerId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  name: {
    type: DataTypes.STRING(200),
    allowNull: false,
    validate: {
      notEmpty: { msg: 'Cafe name is required' }
    }
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  address: {
    type: DataTypes.STRING(500),
    allowNull: false
  },
  city: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  state: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  zipCode: {
    type: DataTypes.STRING(20),
    allowNull: true
  },
  latitude: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: false,
    validate: {
      min: -90,
      max: 90
    }
  },
  longitude: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: false,
    validate: {
      min: -180,
      max: 180
    }
  },
  // Default hourly rate (fallback if PC/console specific rates not set)
  hourlyRate: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    validate: {
      min: 0
    }
  },
  openingTime: {
    type: DataTypes.TIME,
    allowNull: false,
    defaultValue: '09:00:00'
  },
  closingTime: {
    type: DataTypes.TIME,
    allowNull: false,
    defaultValue: '23:00:00'
  },
  // PC Stations
  totalPcStations: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 10,
    validate: {
      min: 0
    }
  },
  pcHourlyRate: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true
  },
  // PC Hardware specifications
  pcSpecs: {
    type: DataTypes.JSONB,
    defaultValue: {
      cpu: '',
      gpu: '',
      ram: '',
      storage: '',
      monitors: '',
      peripherals: []
    }
  },
  // PC Games
  pcGames: {
    type: DataTypes.ARRAY(DataTypes.STRING),
    defaultValue: []
  },
  
  // Console Inventory - detailed per console type
  consoles: {
    type: DataTypes.JSONB,
    defaultValue: {
      ps5: { quantity: 0, hourlyRate: 0, games: [] },
      ps4: { quantity: 0, hourlyRate: 0, games: [] },
      xbox_series_x: { quantity: 0, hourlyRate: 0, games: [] },
      xbox_series_s: { quantity: 0, hourlyRate: 0, games: [] },
      xbox_one: { quantity: 0, hourlyRate: 0, games: [] },
      nintendo_switch: { quantity: 0, hourlyRate: 0, games: [] }
    }
  },
  // Total console units (computed from consoles object)
  totalConsoles: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
    validate: {
      min: 0
    }
  },
  
  photos: {
    type: DataTypes.ARRAY(DataTypes.STRING),
    defaultValue: []
  },
  amenities: {
    type: DataTypes.ARRAY(DataTypes.STRING),
    defaultValue: []
  },
  // Legacy field - kept for backward compatibility, combines all games
  availableGames: {
    type: DataTypes.ARRAY(DataTypes.STRING),
    defaultValue: []
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  rating: {
    type: DataTypes.DECIMAL(2, 1),
    defaultValue: 0,
    validate: {
      min: 0,
      max: 5
    }
  },
  totalReviews: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'cafes',
  timestamps: true,
  indexes: [
    { fields: ['ownerId'] },
    { fields: ['latitude', 'longitude'] },
    { fields: ['city'] },
    { fields: ['isActive'] }
  ]
});

module.exports = Cafe;

