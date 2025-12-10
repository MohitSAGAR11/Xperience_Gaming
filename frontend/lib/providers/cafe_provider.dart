import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cafe_model.dart';
import '../services/cafe_service.dart';
import 'location_provider.dart';

/// Nearby Cafes Provider
final nearbyCafesProvider = FutureProvider.autoDispose<List<Cafe>>((ref) async {
  final cafeService = ref.watch(cafeServiceProvider);
  final locationState = ref.watch(locationProvider);

  if (locationState.location == null) {
    return [];
  }

  final response = await cafeService.getNearbyCafes(
    latitude: locationState.location!.latitude,
    longitude: locationState.location!.longitude,
    radius: 10.0,
  );

  return response.cafes;
});

/// All Cafes Provider
final allCafesProvider = FutureProvider.autoDispose
    .family<CafeListResponse, CafeSearchParams>((ref, params) async {
  final cafeService = ref.watch(cafeServiceProvider);

  return await cafeService.getAllCafes(
    city: params.city,
    minRate: params.minRate,
    maxRate: params.maxRate,
    game: params.game,
    search: params.search,
    page: params.page,
    limit: params.limit,
  );
});

/// Search Cafes Provider
final searchCafesProvider = FutureProvider.autoDispose
    .family<List<Cafe>, String>((ref, query) async {
  final cafeService = ref.watch(cafeServiceProvider);

  if (query.isEmpty) {
    return [];
  }

  final response = await cafeService.getAllCafes(search: query);
  return response.cafes;
});

/// All Cafes with Distance Provider - Shows all cafes sorted by distance from user
/// When search query is provided, filters by cafe name
final allCafesWithDistanceProvider = FutureProvider.autoDispose
    .family<List<Cafe>, String>((ref, searchQuery) async {
  final cafeService = ref.watch(cafeServiceProvider);
  final locationState = ref.watch(locationProvider);

  // If no location, return empty list
  if (locationState.location == null) {
    return [];
  }

  final userLat = locationState.location!.latitude;
  final userLon = locationState.location!.longitude;

  // If searching, get filtered cafes
  if (searchQuery.isNotEmpty) {
    final response = await cafeService.getAllCafes(search: searchQuery);
    final cafes = response.cafes;
    
    // Calculate distance for each cafe and sort by distance
    for (var cafe in cafes) {
      final distance = _calculateDistance(
        userLat,
        userLon,
        cafe.latitude,
        cafe.longitude,
      );
      // Note: We can't modify the cafe object directly, but the distance
      // will be calculated by the cafe card when needed
    }
    
    // Sort by distance (closest first)
    cafes.sort((a, b) {
      final distA = _calculateDistance(userLat, userLon, a.latitude, a.longitude);
      final distB = _calculateDistance(userLat, userLon, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });
    
    return cafes;
  }

  // If not searching, get all nearby cafes (already sorted by distance)
  final response = await cafeService.getNearbyCafes(
    latitude: userLat,
    longitude: userLon,
    radius: 50.0, // Increased radius to show more cafes
  );

  return response.cafes;
});

/// Helper function to calculate distance between two points (Haversine formula)
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // Earth's radius in kilometers
  
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
  
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  
  return earthRadius * c;
}

double _toRadians(double degrees) {
  return degrees * math.pi / 180;
}

/// Single Cafe Provider
final cafeProvider = FutureProvider.autoDispose
    .family<Cafe?, String>((ref, cafeId) async {
  final cafeService = ref.watch(cafeServiceProvider);
  return await cafeService.getCafeById(cafeId);
});

/// Cafe Availability Provider
final cafeAvailabilityProvider = FutureProvider.autoDispose
    .family<CafeAvailability?, CafeAvailabilityParams>((ref, params) async {
  final cafeService = ref.watch(cafeServiceProvider);
  return await cafeService.getCafeAvailability(params.cafeId, params.date);
});

/// My Cafes Provider (for owners)
final myCafesProvider = FutureProvider.autoDispose<List<Cafe>>((ref) async {
  final cafeService = ref.watch(cafeServiceProvider);
  final response = await cafeService.getMyCafes();
  return response.cafes;
});

/// Featured Cafes Provider (top rated)
final featuredCafesProvider = FutureProvider.autoDispose<List<Cafe>>((ref) async {
  final cafeService = ref.watch(cafeServiceProvider);
  final response = await cafeService.getAllCafes(limit: 5);
  
  // Sort by rating
  final cafes = response.cafes;
  cafes.sort((a, b) => b.rating.compareTo(a.rating));
  
  return cafes.take(5).toList();
});

/// Cafe Search Params
class CafeSearchParams {
  final String? city;
  final double? minRate;
  final double? maxRate;
  final String? game;
  final String? search;
  final int page;
  final int limit;

  CafeSearchParams({
    this.city,
    this.minRate,
    this.maxRate,
    this.game,
    this.search,
    this.page = 1,
    this.limit = 10,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CafeSearchParams &&
        other.city == city &&
        other.minRate == minRate &&
        other.maxRate == maxRate &&
        other.game == game &&
        other.search == search &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    return Object.hash(city, minRate, maxRate, game, search, page, limit);
  }
}

/// Cafe Availability Params
class CafeAvailabilityParams {
  final String cafeId;
  final String date;

  CafeAvailabilityParams({
    required this.cafeId,
    required this.date,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CafeAvailabilityParams &&
        other.cafeId == cafeId &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(cafeId, date);
}

