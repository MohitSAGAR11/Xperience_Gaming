/// API Configuration
class ApiConstants {
  // Base URL - Change based on environment
  // Android Emulator: 10.0.2.2
  // iOS Simulator: localhost
  // Physical Device: Your PC's IP (e.g., 192.168.4.128)
  // IMPORTANT: For physical device, use your PC's IP address!
  // 
  // TO UPDATE IP:
  // 1. Run: ipconfig
  // 2. Find your IPv4 Address (e.g., 192.168.1.100)
  // 3. Update baseUrl below with YOUR IP
  // 4. Hot reload/restart app
  //
  // Current IP: 192.168.11.212 (updated automatically)
  static const String baseUrl = 'http://192.168.11.212:5000/api';
  
  // Auth Endpoints
  // Note: register/login are handled by Firebase Auth, backend endpoints are:
  static const String createProfile = '/auth/create-profile'; // Called after Firebase registration
  static const String logout = '/auth/logout';
  static const String profile = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String changePassword = '/auth/password'; // Can use Firebase Auth directly
  
  // Cafe Endpoints
  static const String cafes = '/cafes';
  static const String nearbyCafes = '/cafes/nearby';
  static const String myCafes = '/cafes/owner/my-cafes';
  
  // Booking Endpoints
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my-bookings';
  static const String checkAvailability = '/bookings/check-availability';
}

/// App-wide Constants
class AppConstants {
  // App Info
  static const String appName = 'XPerience Gaming';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
  static const String roleKey = 'user_role';
  static const String onboardingKey = 'onboarding_complete';
  
  // User Roles
  static const String roleClient = 'client';
  static const String roleOwner = 'owner';
  
  // Station Types
  static const String stationTypePc = 'pc';
  
  // Booking Status
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusCancelled = 'cancelled';
  static const String statusCompleted = 'completed';
  
  // Payment Status
  static const String paymentUnpaid = 'unpaid';
  static const String paymentPaid = 'paid';
  static const String paymentRefunded = 'refunded';
  
  // Default Values
  static const double defaultSearchRadius = 10.0; // km
  static const int defaultPageSize = 10;
  
  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
}

/// Error Messages
class ErrorMessages {
  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String emailExists = 'Email already registered.';
  static const String unknownError = 'Something went wrong. Please try again.';
}

/// Success Messages
class SuccessMessages {
  static const String loginSuccess = 'Welcome back!';
  static const String registerSuccess = 'Account created successfully!';
  static const String bookingSuccess = 'Booking confirmed!';
  static const String profileUpdated = 'Profile updated successfully!';
  static const String passwordChanged = 'Password changed successfully!';
}

