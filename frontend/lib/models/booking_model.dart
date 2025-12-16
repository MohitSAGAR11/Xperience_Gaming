import 'cafe_model.dart';
import 'user_model.dart';

/// Booking Model - Matches backend Booking schema
class Booking {
  final String id;
  final String userId;
  final String cafeId;
  final String stationType; // 'pc' or 'console'
  final String? consoleType;
  final int stationNumber;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final double durationHours;
  final double hourlyRate;
  final double totalAmount;
  final String status; // 'pending', 'confirmed', 'cancelled', 'completed'
  final String paymentStatus; // 'unpaid', 'pending', 'paid', 'failed', 'refunded'
  final String? paymentTransactionId; // PayU txnid
  final String? paymentId; // PayU mihpayid
  final String? paymentHash; // PayU hash
  final String? paymentMethod; // 'payu', 'cash', etc.
  final DateTime? paidAt;
  final String? refundId;
  final double? refundAmount;
  final String? refundStatus; // 'pending', 'processed', 'failed', 'not_eligible'
  final DateTime? refundedAt;
  final String? refundReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Cafe? cafe;
  final User? user;

  Booking({
    required this.id,
    required this.userId,
    required this.cafeId,
    required this.stationType,
    this.consoleType,
    required this.stationNumber,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.hourlyRate,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.paymentTransactionId,
    this.paymentId,
    this.paymentHash,
    this.paymentMethod,
    this.paidAt,
    this.refundId,
    this.refundAmount,
    this.refundStatus,
    this.refundedAt,
    this.refundReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.cafe,
    this.user,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      cafeId: json['cafeId'] ?? '',
      stationType: json['stationType'] ?? 'pc',
      consoleType: json['consoleType'],
      stationNumber: json['stationNumber'] ?? 1,
      bookingDate: json['bookingDate'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      durationHours: _parseDouble(json['durationHours']),
      hourlyRate: _parseDouble(json['hourlyRate']),
      totalAmount: _parseDouble(json['totalAmount']),
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      paymentTransactionId: json['paymentTransactionId'],
      paymentId: json['paymentId'],
      paymentHash: json['paymentHash'],
      paymentMethod: json['paymentMethod'],
      paidAt: json['paidAt'] != null ? _parseDateTime(json['paidAt']) : null,
      refundId: json['refundId'],
      refundAmount: json['refundAmount'] != null ? _parseDouble(json['refundAmount']) : null,
      refundStatus: json['refundStatus'],
      refundedAt: json['refundedAt'] != null ? _parseDateTime(json['refundedAt']) : null,
      refundReason: json['refundReason'],
      notes: json['notes'],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      cafe: json['cafe'] != null ? Cafe.fromJson(json['cafe']) : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'cafeId': cafeId,
      'stationType': stationType,
      'consoleType': consoleType,
      'stationNumber': stationNumber,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'durationHours': durationHours,
      'hourlyRate': hourlyRate,
      'totalAmount': totalAmount,
      'status': status,
      'paymentStatus': paymentStatus,
      'notes': notes,
    };
  }

  /// Check if booking is for PC
  bool get isPcBooking => stationType == 'pc';

  /// Check if booking is for console
  bool get isConsoleBooking => stationType == 'console';

  /// Check if booking is upcoming
  bool get isUpcoming {
    final date = DateTime.parse(bookingDate);
    final today = DateTime.now();
    return date.isAfter(today) ||
        (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day);
  }

  /// Check if booking can be cancelled
  bool get canCancel {
    return status == 'pending' || status == 'confirmed';
  }

  /// Get station display name
  String get stationDisplay {
    if (isConsoleBooking && consoleType != null) {
      return '${_getConsoleDisplayName(consoleType!)} #$stationNumber';
    }
    return 'PC Station #$stationNumber';
  }

  /// Get status display color hex
  int get statusColorHex {
    switch (status) {
      case 'confirmed':
        return 0xFF39FF14; // Green
      case 'pending':
        return 0xFFFFE600; // Yellow
      case 'cancelled':
        return 0xFFFF003C; // Red
      case 'completed':
        return 0xFF00E5FF; // Cyan
      default:
        return 0xFFB3B3B3; // Grey
    }
  }

  String _getConsoleDisplayName(String type) {
    const names = {
      'ps5': 'PS5',
      'ps4': 'PS4',
      'xbox_series_x': 'Xbox X',
      'xbox_series_s': 'Xbox S',
      'xbox_one': 'Xbox One',
      'nintendo_switch': 'Switch',
    };
    return names[type] ?? type;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    // Handle Firestore Timestamp object: {"_seconds": 123, "_nanoseconds": 456}
    if (value is Map) {
      final seconds = value['_seconds'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    
    // Handle string dates
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }
}

/// Booking Request - For creating new bookings
class BookingRequest {
  final String cafeId;
  final String stationType;
  final String? consoleType;
  final int stationNumber;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final String? notes;

  BookingRequest({
    required this.cafeId,
    required this.stationType,
    this.consoleType,
    required this.stationNumber,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'cafeId': cafeId,
      'stationType': stationType,
      if (consoleType != null) 'consoleType': consoleType,
      'stationNumber': stationNumber,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      if (notes != null) 'notes': notes,
    };
  }
}

/// Booking Response
class BookingResponse {
  final bool success;
  final String message;
  final Booking? booking;
  final BillingInfo? billing;

  BookingResponse({
    required this.success,
    required this.message,
    this.booking,
    this.billing,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return BookingResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      booking: data != null && data['booking'] != null
          ? Booking.fromJson(data['booking'])
          : null,
      billing: data != null && data['billing'] != null
          ? BillingInfo.fromJson(data['billing'])
          : null,
    );
  }
}

/// Billing Info
class BillingInfo {
  final String stationType;
  final String? consoleType;
  final double durationHours;
  final double hourlyRate;
  final double totalAmount;

  BillingInfo({
    required this.stationType,
    this.consoleType,
    required this.durationHours,
    required this.hourlyRate,
    required this.totalAmount,
  });

  factory BillingInfo.fromJson(Map<String, dynamic> json) {
    return BillingInfo(
      stationType: json['stationType'] ?? 'pc',
      consoleType: json['consoleType'],
      durationHours: Booking._parseDouble(json['durationHours']),
      hourlyRate: Booking._parseDouble(json['hourlyRate']),
      totalAmount: Booking._parseDouble(json['totalAmount']),
    );
  }
}

/// Availability Check Request
class AvailabilityRequest {
  final String cafeId;
  final String stationType;
  final String? consoleType;
  final int stationNumber;
  final String bookingDate;
  final String startTime;
  final String endTime;

  AvailabilityRequest({
    required this.cafeId,
    required this.stationType,
    this.consoleType,
    required this.stationNumber,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'cafeId': cafeId,
      'stationType': stationType,
      if (consoleType != null) 'consoleType': consoleType,
      'stationNumber': stationNumber,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

/// Availability Response
class AvailabilityResponse {
  final bool success;
  final bool available;
  final double estimatedCost;
  final double durationHours;
  final double hourlyRate;

  AvailabilityResponse({
    required this.success,
    required this.available,
    required this.estimatedCost,
    required this.durationHours,
    required this.hourlyRate,
  });

  factory AvailabilityResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AvailabilityResponse(
      success: json['success'] ?? false,
      available: data?['available'] ?? false,
      estimatedCost: Booking._parseDouble(data?['estimatedCost']),
      durationHours: Booking._parseDouble(data?['durationHours']),
      hourlyRate: Booking._parseDouble(data?['hourlyRate']),
    );
  }
}

/// My Bookings Response
class MyBookingsResponse {
  final bool success;
  final List<Booking> bookings;
  final CategorizedBookings? categorized;

  MyBookingsResponse({
    required this.success,
    required this.bookings,
    this.categorized,
  });

  factory MyBookingsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<Booking> bookingList = [];
    
    if (data != null && data['bookings'] != null) {
      bookingList = (data['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();
    }

    return MyBookingsResponse(
      success: json['success'] ?? false,
      bookings: bookingList,
      categorized: data != null && data['categorized'] != null
          ? CategorizedBookings.fromJson(data['categorized'])
          : null,
    );
  }
}

/// Categorized Bookings
class CategorizedBookings {
  final List<Booking> upcoming;
  final List<Booking> past;

  CategorizedBookings({
    required this.upcoming,
    required this.past,
  });

  factory CategorizedBookings.fromJson(Map<String, dynamic> json) {
    return CategorizedBookings(
      upcoming: json['upcoming'] != null
          ? (json['upcoming'] as List).map((b) => Booking.fromJson(b)).toList()
          : [],
      past: json['past'] != null
          ? (json['past'] as List).map((b) => Booking.fromJson(b)).toList()
          : [],
    );
  }
}

/// OPTIMIZED: Available Stations Response (Server-side calculation)
class AvailableStationsResponse {
  final bool success;
  final List<int> availableStations;
  final int totalStations;
  final int availableCount;
  final int? firstAvailable;
  final StationPricing? pricing;
  final String? message;

  AvailableStationsResponse({
    required this.success,
    required this.availableStations,
    required this.totalStations,
    required this.availableCount,
    this.firstAvailable,
    this.pricing,
    this.message,
  });

  factory AvailableStationsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    
    List<int> stations = [];
    if (data != null && data['availableStations'] != null) {
      stations = (data['availableStations'] as List)
          .map((s) => s is int ? s : int.tryParse(s.toString()) ?? 0)
          .toList();
    }

    return AvailableStationsResponse(
      success: json['success'] ?? false,
      availableStations: stations,
      totalStations: data?['totalStations'] ?? 0,
      availableCount: data?['availableCount'] ?? 0,
      firstAvailable: data?['firstAvailable'],
      pricing: data?['pricing'] != null 
          ? StationPricing.fromJson(data['pricing']) 
          : null,
      message: json['message'],
    );
  }
}

/// Station Pricing Info
class StationPricing {
  final double durationHours;
  final double hourlyRate;
  final double estimatedTotal;

  StationPricing({
    required this.durationHours,
    required this.hourlyRate,
    required this.estimatedTotal,
  });

  factory StationPricing.fromJson(Map<String, dynamic> json) {
    return StationPricing(
      durationHours: Booking._parseDouble(json['durationHours']),
      hourlyRate: Booking._parseDouble(json['hourlyRate']),
      estimatedTotal: Booking._parseDouble(json['estimatedTotal']),
    );
  }
}

