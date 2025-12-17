import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/constants.dart';

/// Date & Time Utilities
class DateTimeUtils {
  /// Format date as "Mon, Dec 25, 2024"
  static String formatDate(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  /// Format date as "25 Dec 2024"
  static String formatDateShort(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Format date as "2024-12-25" (for API)
  static String formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format time as "2:30 PM"
  static String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  /// Format time from string "14:30:00" to "2:30 PM"
  /// Handles 12:00 correctly (12:00 = noon = 12:00 PM, 00:00 = midnight = 12:00 AM)
  static String formatTimeString(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    // Handle 12-hour format conversion
    // 00:00 = 12:00 AM (midnight)
    // 12:00 = 12:00 PM (noon)
    // 13:00 = 1:00 PM
    // etc.
    int displayHour = hour;
    String period = 'AM';
    
    if (hour == 0) {
      // Midnight: 00:00 → 12:00 AM
      displayHour = 12;
      period = 'AM';
    } else if (hour == 12) {
      // Noon: 12:00 → 12:00 PM
      displayHour = 12;
      period = 'PM';
    } else if (hour > 12) {
      // Afternoon: 13:00 → 1:00 PM, 14:00 → 2:00 PM, etc.
      displayHour = hour - 12;
      period = 'PM';
    } else {
      // Morning: 1:00 → 1:00 AM, 11:00 → 11:00 AM
      displayHour = hour;
      period = 'AM';
    }
    
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  /// Parse time string "14:30" to TimeOfDay
  static TimeOfDay parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  /// Format duration as "2h 30m"
  static String formatDuration(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (m == 0) return '${h}h';
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Get relative date string
  static String getRelativeDate(DateTime date) {
    if (isToday(date)) return 'Today';
    if (isTomorrow(date)) return 'Tomorrow';
    return formatDateShort(date);
  }
}

/// Currency Utilities
class CurrencyUtils {
  /// Format amount as "₹1,500" (rounded for display)
  static String formatINR(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Format amount as "₹1,500.50" (with decimals for exact amounts)
  static String formatINRExact(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format amount with decimals as "₹1,500.00"
  static String formatINRWithDecimals(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}

/// Validation Utilities
class Validators {
  /// Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Phone validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// URL validation
  static String? validateUrl(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return 'Please enter a valid URL starting with http:// or https://';
    }
    return null;
  }
}

/// Console Type Utilities
/// Booking Status Utilities
class BookingStatusUtils {
  /// Get status color
  static Color getColor(String status) {
    switch (status) {
      case AppConstants.statusConfirmed:
        return const Color(0xFF39FF14); // Matrix Green
      case AppConstants.statusPending:
        return const Color(0xFFFFE600); // Electric Yellow
      case AppConstants.statusCancelled:
        return const Color(0xFFFF003C); // Cyber Red
      case AppConstants.statusCompleted:
        return const Color(0x803B82F6); // rgba(59, 130, 246, 0.5) - 0x80 = 50% alpha
      default:
        return Colors.grey;
    }
  }

  /// Get status display text
  static String getDisplayText(String status) {
    switch (status) {
      case AppConstants.statusConfirmed:
        return 'Confirmed';
      case AppConstants.statusPending:
        return 'Pending';
      case AppConstants.statusCancelled:
        return 'Cancelled';
      case AppConstants.statusCompleted:
        return 'Completed';
      default:
        return status;
    }
  }

  /// Get status icon
  static IconData getIcon(String status) {
    switch (status) {
      case AppConstants.statusConfirmed:
        return Icons.check_circle;
      case AppConstants.statusPending:
        return Icons.schedule;
      case AppConstants.statusCancelled:
        return Icons.cancel;
      case AppConstants.statusCompleted:
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }
}

/// Maps Link Utilities
class MapsLinkUtils {
  /// Extract latitude and longitude from Google Maps link
  /// Supports multiple formats:
  /// - https://www.google.com/maps/place/.../@lat,lng,zoom
  /// - https://maps.google.com/?q=lat,lng
  /// - https://www.google.com/maps/search/?api=1&query=lat,lng
  static Map<String, double>? extractCoordinates(String mapsLink) {
    try {
      // Format 1: /@lat,lng,zoom
      final atPattern = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)');
      final atMatch = atPattern.firstMatch(mapsLink);
      if (atMatch != null) {
        final lat = double.tryParse(atMatch.group(1)!);
        final lng = double.tryParse(atMatch.group(2)!);
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 2: ?q=lat,lng
      final qPattern = RegExp(r'[?&]q=(-?\d+\.?\d*),(-?\d+\.?\d*)');
      final qMatch = qPattern.firstMatch(mapsLink);
      if (qMatch != null) {
        final lat = double.tryParse(qMatch.group(1)!);
        final lng = double.tryParse(qMatch.group(2)!);
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 3: &query=lat,lng
      final queryPattern = RegExp(r'[?&]query=(-?\d+\.?\d*),(-?\d+\.?\d*)');
      final queryMatch = queryPattern.firstMatch(mapsLink);
      if (queryMatch != null) {
        final lat = double.tryParse(queryMatch.group(1)!);
        final lng = double.tryParse(queryMatch.group(2)!);
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Snackbar Utilities
class SnackbarUtils {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF39FF14)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Color(0xFFFF003C)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Color(0x803B82F6)), // rgba(59, 130, 246, 0.5) as hex with alpha
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
}

