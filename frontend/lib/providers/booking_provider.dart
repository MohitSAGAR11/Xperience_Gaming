import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking_model.dart';
import '../services/booking_service.dart';

/// My Bookings Provider
final myBookingsProvider = FutureProvider.autoDispose<MyBookingsResponse>((ref) async {
  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getMyBookings();
});

/// Upcoming Bookings Provider (independent, no circular dependency)
final upcomingBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final bookingService = ref.watch(bookingServiceProvider);
  final response = await bookingService.getMyBookings();
  return response.categorized?.upcoming ?? [];
});

/// Past Bookings Provider (independent, no circular dependency)
final pastBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final bookingService = ref.watch(bookingServiceProvider);
  final response = await bookingService.getMyBookings();
  return response.categorized?.past ?? [];
});

/// Single Booking Provider
final bookingProvider = FutureProvider.autoDispose
    .family<Booking?, String>((ref, bookingId) async {
  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getBookingById(bookingId);
});

/// Availability Check Provider
final availabilityProvider = FutureProvider.autoDispose
    .family<AvailabilityResponse, AvailabilityRequest>((ref, request) async {
  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.checkAvailability(request);
});

/// Cafe Bookings Provider (for owners)
final cafeBookingsProvider = FutureProvider.autoDispose
    .family<CafeBookingsResponse, CafeBookingsParams>((ref, params) async {
  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getCafeBookings(
    params.cafeId,
    date: params.date,
    status: params.status,
    page: params.page,
    limit: params.limit,
  );
});

/// Cafe Bookings Params
class CafeBookingsParams {
  final String cafeId;
  final String? date;
  final String? status;
  final int page;
  final int limit;

  CafeBookingsParams({
    required this.cafeId,
    this.date,
    this.status,
    this.page = 1,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CafeBookingsParams &&
        other.cafeId == cafeId &&
        other.date == date &&
        other.status == status &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(cafeId, date, status, page, limit);
}

/// Booking Draft State - For building a booking
class BookingDraft {
  final String? cafeId;
  final String? cafeName;
  final String stationType;
  final String? consoleType;
  final int? stationNumber;
  final DateTime? selectedDate;
  final String? startTime;
  final String? endTime;
  final double? hourlyRate;
  final double? estimatedCost;
  final double? durationHours;

  BookingDraft({
    this.cafeId,
    this.cafeName,
    this.stationType = 'pc',
    this.consoleType,
    this.stationNumber,
    this.selectedDate,
    this.startTime,
    this.endTime,
    this.hourlyRate,
    this.estimatedCost,
    this.durationHours,
  });

  BookingDraft copyWith({
    String? cafeId,
    String? cafeName,
    String? stationType,
    String? consoleType,
    int? stationNumber,
    DateTime? selectedDate,
    String? startTime,
    String? endTime,
    double? hourlyRate,
    double? estimatedCost,
    double? durationHours,
  }) {
    return BookingDraft(
      cafeId: cafeId ?? this.cafeId,
      cafeName: cafeName ?? this.cafeName,
      stationType: stationType ?? this.stationType,
      consoleType: consoleType ?? this.consoleType,
      stationNumber: stationNumber ?? this.stationNumber,
      selectedDate: selectedDate ?? this.selectedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      durationHours: durationHours ?? this.durationHours,
    );
  }

  /// Check if draft is complete
  bool get isComplete {
    return cafeId != null &&
        stationNumber != null &&
        selectedDate != null &&
        startTime != null &&
        endTime != null;
  }

  /// Convert to booking request
  BookingRequest toRequest() {
    return BookingRequest(
      cafeId: cafeId!,
      stationType: stationType,
      consoleType: stationType == 'console' ? consoleType : null,
      stationNumber: stationNumber!,
      bookingDate: _formatDate(selectedDate!),
      startTime: startTime!,
      endTime: endTime!,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Booking Draft Notifier
class BookingDraftNotifier extends StateNotifier<BookingDraft> {
  BookingDraftNotifier() : super(BookingDraft());

  void setCafe(String cafeId, String cafeName) {
    state = BookingDraft(cafeId: cafeId, cafeName: cafeName);
  }

  void setStationType(String stationType, {String? consoleType}) {
    state = state.copyWith(
      stationType: stationType,
      consoleType: consoleType,
      stationNumber: null, // Reset station when type changes
    );
  }

  void setStation(int stationNumber) {
    state = state.copyWith(stationNumber: stationNumber);
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void setTimeSlot(String startTime, String endTime) {
    state = state.copyWith(startTime: startTime, endTime: endTime);
  }

  void setEstimate(double hourlyRate, double durationHours, double estimatedCost) {
    state = state.copyWith(
      hourlyRate: hourlyRate,
      durationHours: durationHours,
      estimatedCost: estimatedCost,
    );
  }

  void clear() {
    state = BookingDraft();
  }
}

/// Booking Draft Provider
final bookingDraftProvider = StateNotifierProvider<BookingDraftNotifier, BookingDraft>((ref) {
  return BookingDraftNotifier();
});

