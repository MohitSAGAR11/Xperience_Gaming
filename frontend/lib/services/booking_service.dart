import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/api_client.dart';
import '../core/logger.dart';
import '../models/booking_model.dart';

/// Booking Service - Handles all booking-related API calls
class BookingService {
  final ApiClient _apiClient;

  BookingService(this._apiClient);

  /// Check slot availability before booking
  Future<AvailabilityResponse> checkAvailability(
    AvailabilityRequest request,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.checkAvailability,
      data: request.toJson(),
    );

    if (response.isSuccess && response.data != null) {
      return AvailabilityResponse.fromJson(response.data!);
    }

    return AvailabilityResponse(
      success: false,
      available: false,
      estimatedCost: 0,
      durationHours: 0,
      hourlyRate: 0,
    );
  }

  /// OPTIMIZED: Get available stations for a time slot (server-side calculation)
  /// Returns list of available station numbers and first available station
  Future<AvailableStationsResponse> getAvailableStations({
    required String cafeId,
    required String stationType,
    String? consoleType,
    required String bookingDate,
    required String startTime,
    required String endTime,
  }) async {
    AppLogger.d('🎫 [BOOKING_SERVICE] ========================================');
    AppLogger.d('🎫 [BOOKING_SERVICE] getAvailableStations called');
    AppLogger.d('🎫 [BOOKING_SERVICE] Parameters: cafeId=$cafeId, stationType=$stationType, consoleType=$consoleType, bookingDate=$bookingDate, startTime=$startTime, endTime=$endTime');
    
    final queryParams = <String, dynamic>{
      'cafeId': cafeId,
      'stationType': stationType,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
    };
    
    if (consoleType != null) {
      queryParams['consoleType'] = consoleType;
    }

    AppLogger.d('🎫 [BOOKING_SERVICE] Calling API: ${ApiConstants.bookings}/available-stations');
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.bookings}/available-stations',
      queryParameters: queryParams,
    );

    AppLogger.d('🎫 [BOOKING_SERVICE] API response received');
    AppLogger.d('🎫 [BOOKING_SERVICE] Response success: ${response.isSuccess}');
    AppLogger.d('🎫 [BOOKING_SERVICE] Has data: ${response.data != null}');

    if (response.isSuccess && response.data != null) {
      final result = AvailableStationsResponse.fromJson(response.data!);
      AppLogger.d('🎫 [BOOKING_SERVICE] Parsed response: availableCount=${result.availableCount}, totalStations=${result.totalStations}, firstAvailable=${result.firstAvailable}');
      AppLogger.d('🎫 [BOOKING_SERVICE] ========================================');
      return result;
    }

    AppLogger.w('🎫 [BOOKING_SERVICE] API call failed or no data');
    AppLogger.d('🎫 [BOOKING_SERVICE] ========================================');
    return AvailableStationsResponse(
      success: false,
      availableStations: [],
      totalStations: 0,
      availableCount: 0,
    );
  }

  /// Create a new booking
  Future<BookingResponse> createBooking(BookingRequest request) async {
    AppLogger.d('🎫 [BOOKING_SERVICE] ========================================');
    AppLogger.d('🎫 [BOOKING_SERVICE] createBooking method called!');
    AppLogger.d('🎫 [BOOKING_SERVICE] Request data: ${request.toJson()}');
    AppLogger.d('🎫 [BOOKING_SERVICE] API endpoint: ${ApiConstants.bookings}');
    AppLogger.d('🎫 [BOOKING_SERVICE] ========================================');
    
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.bookings,
      data: request.toJson(),
    );

    AppLogger.d('🎫 [BOOKING_SERVICE] Response received: isSuccess=${response.isSuccess}');
    AppLogger.d('🎫 [BOOKING_SERVICE] Response message: ${response.message}');

    if (response.isSuccess && response.data != null) {
      AppLogger.d('🎫 [BOOKING_SERVICE] Parsing success response...');
      return BookingResponse.fromJson(response.data!);
    }

    AppLogger.d('🎫 [BOOKING_SERVICE] Returning error response');
    return BookingResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Get user's bookings (history)
  Future<MyBookingsResponse> getMyBookings({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.myBookings,
      queryParameters: queryParams,
    );

    if (response.isSuccess && response.data != null) {
      return MyBookingsResponse.fromJson(response.data!);
    }

    return MyBookingsResponse(success: false, bookings: []);
  }

  /// Get single booking by ID
  Future<Booking?> getBookingById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$id',
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      if (data['success'] == true && data['data']?['booking'] != null) {
        return Booking.fromJson(data['data']['booking']);
      }
    }

    return null;
  }

  /// Get single booking by ID with group bookings (if applicable)
  Future<BookingWithGroupResponse?> getBookingWithGroup(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$id',
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      if (data['success'] == true && data['data']?['booking'] != null) {
        final booking = Booking.fromJson(data['data']['booking']);
        List<Booking>? groupBookings;
        
        if (data['data']?['groupBookings'] != null) {
          groupBookings = (data['data']['groupBookings'] as List)
              .map((b) => Booking.fromJson(b))
              .toList();
        }
        
        return BookingWithGroupResponse(
          booking: booking,
          groupBookings: groupBookings,
        );
      }
    }

    return null;
  }

  /// Cancel a booking
  Future<BookingResponse> cancelBooking(String bookingId) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$bookingId/cancel',
    );

    if (response.isSuccess && response.data != null) {
      return BookingResponse.fromJson(response.data!);
    }

    return BookingResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  // ============ Owner Methods ============

  /// Get bookings for a specific cafe (Owner only)
  Future<CafeBookingsResponse> getCafeBookings(
    String cafeId, {
    String? date,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (date != null) queryParams['date'] = date;
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.bookings}/cafe/$cafeId',
      queryParameters: queryParams,
    );

    if (response.isSuccess && response.data != null) {
      return CafeBookingsResponse.fromJson(response.data!);
    }

    return CafeBookingsResponse(success: false, bookings: []);
  }

  /// Update booking status (Owner only)
  Future<BookingResponse> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '${ApiConstants.bookings}/$bookingId/status',
      data: {'status': status},
    );

    if (response.isSuccess && response.data != null) {
      return BookingResponse.fromJson(response.data!);
    }

    return BookingResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }
}

/// Cafe Bookings Response (for owners)
class CafeBookingsResponse {
  final bool success;
  final List<Booking> bookings;
  final PaginationInfo? pagination;

  CafeBookingsResponse({
    required this.success,
    required this.bookings,
    this.pagination,
  });

  factory CafeBookingsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<Booking> bookingList = [];
    
    if (data != null && data['bookings'] != null) {
      bookingList = (data['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();
    }

    return CafeBookingsResponse(
      success: json['success'] ?? false,
      bookings: bookingList,
      pagination: data != null && data['pagination'] != null
          ? PaginationInfo.fromJson(data['pagination'])
          : null,
    );
  }
}

/// Pagination Info
class PaginationInfo {
  final int total;
  final int page;
  final int pages;
  final int limit;

  PaginationInfo({
    required this.total,
    required this.page,
    required this.pages,
    required this.limit,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['pages'] ?? 1,
      limit: json['limit'] ?? 10,
    );
  }
}

/// Booking with Group Response
class BookingWithGroupResponse {
  final Booking booking;
  final List<Booking>? groupBookings;

  BookingWithGroupResponse({
    required this.booking,
    this.groupBookings,
  });
}

/// Booking Service Provider
final bookingServiceProvider = Provider<BookingService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BookingService(apiClient);
});

