import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/api_client.dart';
import '../core/logger.dart';
import '../models/cafe_model.dart';

/// Cafe Service - Handles all cafe-related API calls
class CafeService {
  final ApiClient _apiClient;

  CafeService(this._apiClient);

  /// Get all cafes with optional filters
  Future<CafeListResponse> getAllCafes({
    String? city,
    double? minRate,
    double? maxRate,
    String? game,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (city != null) queryParams['city'] = city;
    if (minRate != null) queryParams['minRate'] = minRate;
    if (maxRate != null) queryParams['maxRate'] = maxRate;
    if (game != null) queryParams['game'] = game;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.cafes,
      queryParameters: queryParams,
    );

    if (response.isSuccess && response.data != null) {
      return CafeListResponse.fromJson(response.data!);
    }

    return CafeListResponse(success: false, cafes: []);
  }

  /// Get nearby cafes using GPS location
  Future<CafeListResponse> getNearbyCafes({
    required double latitude,
    required double longitude,
    double radius = 10.0, // km
    String? game,
  }) async {
    final queryParams = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };

    if (game != null) queryParams['game'] = game;

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.nearbyCafes,
      queryParameters: queryParams,
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      List<Cafe> cafes = [];
      
      if (data['data'] != null && data['data']['cafes'] != null) {
        cafes = (data['data']['cafes'] as List)
            .map((c) => Cafe.fromJson(c))
            .toList();
      }

      return CafeListResponse(
        success: data['success'] ?? false,
        cafes: cafes,
      );
    }

    return CafeListResponse(success: false, cafes: []);
  }

  /// Get single cafe by ID
  Future<Cafe?> getCafeById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.cafes}/$id',
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      if (data['success'] == true && data['data']?['cafe'] != null) {
        return Cafe.fromJson(data['data']['cafe']);
      }
    }

    return null;
  }

  /// Get cafe availability for a specific date
  Future<CafeAvailability?> getCafeAvailability(
    String cafeId,
    String date,
  ) async {
    AppLogger.d('📅 [CAFE_SERVICE] getCafeAvailability called - cafeId: $cafeId, date: $date');
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiConstants.cafes}/$cafeId/availability',
      queryParameters: {'date': date},
    );

    AppLogger.d('📅 [CAFE_SERVICE] Response isSuccess: ${response.isSuccess}');
    AppLogger.d('📅 [CAFE_SERVICE] Response data: ${response.data}');

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      AppLogger.d('📅 [CAFE_SERVICE] Data success: ${data['success']}');
      AppLogger.d('📅 [CAFE_SERVICE] Data has "data" field: ${data['data'] != null}');
      
      if (data['success'] == true && data['data'] != null) {
        AppLogger.d('📅 [CAFE_SERVICE] Parsing CafeAvailability from JSON...');
        try {
          final availability = CafeAvailability.fromJson(data['data']);
          AppLogger.d('📅 [CAFE_SERVICE] Successfully parsed availability!');
          return availability;
        } catch (e, stackTrace) {
          AppLogger.e('📅 [CAFE_SERVICE] ERROR parsing availability', e, stackTrace);
          return null;
        }
      }
    }

    AppLogger.d('📅 [CAFE_SERVICE] Returning null - no valid data');
    return null;
  }

  // ============ Owner Methods ============

  /// Get owner's cafes
  Future<CafeListResponse> getMyCafes() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.myCafes,
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      List<Cafe> cafes = [];
      
      if (data['data'] != null && data['data']['cafes'] != null) {
        cafes = (data['data']['cafes'] as List)
            .map((c) => Cafe.fromJson(c))
            .toList();
      }

      return CafeListResponse(
        success: data['success'] ?? false,
        cafes: cafes,
      );
    }

    return CafeListResponse(success: false, cafes: []);
  }

  /// Create a new cafe (Owner only)
  Future<CafeResponse> createCafe(Map<String, dynamic> cafeData) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.cafes,
      data: cafeData,
    );

    if (response.isSuccess && response.data != null) {
      return CafeResponse.fromJson(response.data!);
    }

    return CafeResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Update cafe (Owner only)
  Future<CafeResponse> updateCafe(
    String cafeId,
    Map<String, dynamic> cafeData,
  ) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '${ApiConstants.cafes}/$cafeId',
      data: cafeData,
    );

    if (response.isSuccess && response.data != null) {
      return CafeResponse.fromJson(response.data!);
    }

    return CafeResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Delete cafe (Owner only)
  Future<bool> deleteCafe(String cafeId) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '${ApiConstants.cafes}/$cafeId',
    );

    return response.isSuccess;
  }
}

/// Cafe Response
class CafeResponse {
  final bool success;
  final String message;
  final Cafe? cafe;

  CafeResponse({
    required this.success,
    required this.message,
    this.cafe,
  });

  factory CafeResponse.fromJson(Map<String, dynamic> json) {
    return CafeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      cafe: json['data']?['cafe'] != null
          ? Cafe.fromJson(json['data']['cafe'])
          : null,
    );
  }
}

/// Cafe Availability Model
class CafeAvailability {
  final String cafeId;
  final String date;
  final String openingTime;
  final String closingTime;
  final PcAvailability? pc;
  final Map<String, ConsoleAvailability> consoles;

  CafeAvailability({
    required this.cafeId,
    required this.date,
    required this.openingTime,
    required this.closingTime,
    this.pc,
    this.consoles = const {},
  });

  factory CafeAvailability.fromJson(Map<String, dynamic> json) {
    Map<String, ConsoleAvailability> consolesMap = {};
    
    if (json['consoles'] != null && json['consoles'] is Map) {
      final consolesJson = json['consoles'] as Map<String, dynamic>;
      consolesJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          consolesMap[key] = ConsoleAvailability.fromJson(value);
        }
      });
    }

    return CafeAvailability(
      cafeId: json['cafeId'] ?? '',
      date: json['date'] ?? '',
      openingTime: json['openingTime'] ?? '',
      closingTime: json['closingTime'] ?? '',
      pc: json['pc'] != null ? PcAvailability.fromJson(json['pc']) : null,
      consoles: consolesMap,
    );
  }
}

/// PC Availability
class PcAvailability {
  final int totalStations;
  final double hourlyRate;
  final Map<int, StationAvailability> availability;

  PcAvailability({
    required this.totalStations,
    required this.hourlyRate,
    this.availability = const {},
  });

  factory PcAvailability.fromJson(Map<String, dynamic> json) {
    Map<int, StationAvailability> availMap = {};
    
    if (json['availability'] != null && json['availability'] is Map) {
      final availJson = json['availability'] as Map<String, dynamic>;
      availJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          availMap[int.parse(key)] = StationAvailability.fromJson(value);
        }
      });
    }

    return PcAvailability(
      totalStations: json['totalStations'] ?? 0,
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      availability: availMap,
    );
  }
}

/// Console Availability
class ConsoleAvailability {
  final int quantity;
  final double hourlyRate;
  final List<String> games;
  final Map<int, StationAvailability> units;

  ConsoleAvailability({
    required this.quantity,
    required this.hourlyRate,
    this.games = const [],
    this.units = const {},
  });

  factory ConsoleAvailability.fromJson(Map<String, dynamic> json) {
    Map<int, StationAvailability> unitsMap = {};
    
    if (json['units'] != null && json['units'] is Map) {
      final unitsJson = json['units'] as Map<String, dynamic>;
      unitsJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          unitsMap[int.parse(key)] = StationAvailability.fromJson(value);
        }
      });
    }

    return ConsoleAvailability(
      quantity: json['quantity'] ?? 0,
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      games: json['games'] != null ? List<String>.from(json['games']) : [],
      units: unitsMap,
    );
  }
}

/// Station Availability
class StationAvailability {
  final int station;
  final List<BookedSlot> bookedSlots;

  StationAvailability({
    required this.station,
    this.bookedSlots = const [],
  });

  factory StationAvailability.fromJson(Map<String, dynamic> json) {
    return StationAvailability(
      station: json['station'] ?? json['unit'] ?? 0,
      bookedSlots: json['bookedSlots'] != null
          ? (json['bookedSlots'] as List)
              .map((s) => BookedSlot.fromJson(s))
              .toList()
          : [],
    );
  }
}

/// Booked Slot
class BookedSlot {
  final String startTime;
  final String endTime;

  BookedSlot({
    required this.startTime,
    required this.endTime,
  });

  factory BookedSlot.fromJson(Map<String, dynamic> json) {
    return BookedSlot(
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
    );
  }
}

/// Cafe Service Provider
final cafeServiceProvider = Provider<CafeService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CafeService(apiClient);
});

