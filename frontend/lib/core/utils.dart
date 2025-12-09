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
  static String formatTimeString(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final dt = DateTime(2024, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(dt);
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
  /// Format amount as "₹1,500"
  static String formatINR(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
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
}

/// Console Type Utilities
class ConsoleUtils {
  /// Get display name for console type
  static String getDisplayName(String consoleType) {
    return AppConstants.consoleDisplayNames[consoleType] ?? consoleType;
  }

  /// Get icon for console type
  static IconData getIcon(String consoleType) {
    switch (consoleType) {
      case 'ps5':
      case 'ps4':
        return Icons.sports_esports;
      case 'xbox_series_x':
      case 'xbox_series_s':
      case 'xbox_one':
        return Icons.gamepad;
      case 'nintendo_switch':
        return Icons.videogame_asset;
      default:
        return Icons.games;
    }
  }

  /// Get color for console type
  static Color getColor(String consoleType) {
    switch (consoleType) {
      case 'ps5':
      case 'ps4':
        return const Color(0xFF003087); // PlayStation Blue
      case 'xbox_series_x':
      case 'xbox_series_s':
      case 'xbox_one':
        return const Color(0xFF107C10); // Xbox Green
      case 'nintendo_switch':
        return const Color(0xFFE60012); // Nintendo Red
      default:
        return Colors.grey;
    }
  }
}

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
        return const Color(0xFF00E5FF); // Cyber Cyan
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
            const Icon(Icons.info, color: Color(0xFF00E5FF)),
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

