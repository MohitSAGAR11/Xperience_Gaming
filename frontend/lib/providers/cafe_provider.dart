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

