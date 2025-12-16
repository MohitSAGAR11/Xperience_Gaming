import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide Logger Utility
/// Only logs in debug mode to avoid performance issues in production
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  /// Debug log - for development debugging
  static void d(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  /// Info log - for informational messages
  static void i(String message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  /// Warning log - for warnings with optional error
  static void w(String message, [Object? error]) {
    if (kDebugMode) {
      if (error != null) {
        _logger.w(message, error: error);
      } else {
        _logger.w(message);
      }
    }
  }

  /// Error log - for errors with optional stack trace
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }
}

