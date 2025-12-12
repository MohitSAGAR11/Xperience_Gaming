import 'package:flutter/foundation.dart';

/// Cafe Model - Matches backend Cafe schema
class Cafe {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String address;
  final String city;
  final String? state;
  final String? zipCode;
  final double latitude;
  final double longitude;
  final String mapsLink;
  final double hourlyRate;
  final String openingTime;
  final String closingTime;
  final int totalPcStations;
  final double? pcHourlyRate;
  final PcSpecs? pcSpecs;
  final List<String> pcGames;
  final List<String> photos;
  final List<String> amenities;
  final List<String> availableGames;
  final bool isActive;
  final double rating;
  final int totalReviews;
  final double? distance; // Only when fetching nearby cafes
  final CafeOwner? owner;

  Cafe({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.address,
    required this.city,
    this.state,
    this.zipCode,
    required this.latitude,
    required this.longitude,
    required this.mapsLink,
    required this.hourlyRate,
    required this.openingTime,
    required this.closingTime,
    required this.totalPcStations,
    this.pcHourlyRate,
    this.pcSpecs,
    this.pcGames = const [],
    this.photos = const [],
    this.amenities = const [],
    this.availableGames = const [],
    this.isActive = true,
    this.rating = 0,
    this.totalReviews = 0,
    this.distance,
    this.owner,
  });

  factory Cafe.fromJson(Map<String, dynamic> json) {
    // Warn if mapsLink is missing
    if (json['mapsLink'] == null || (json['mapsLink'] as String).isEmpty) {
      debugPrint('⚠️ [CAFE_MODEL] WARNING: Cafe "${json['name']}" (${json['id']}) has no mapsLink!');
    }
    
    return Cafe(
      id: json['id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'],
      zipCode: json['zipCode'],
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      mapsLink: json['mapsLink'] ?? '',
      hourlyRate: _parseDouble(json['hourlyRate']),
      openingTime: json['openingTime'] ?? '09:00:00',
      closingTime: json['closingTime'] ?? '23:00:00',
      totalPcStations: json['totalPcStations'] ?? 0,
      pcHourlyRate: json['pcHourlyRate'] != null
          ? _parseDouble(json['pcHourlyRate'])
          : null,
      pcSpecs: json['pcSpecs'] != null
          ? PcSpecs.fromJson(json['pcSpecs'])
          : null,
      pcGames: _parseStringList(json['pcGames']),
      photos: _parseStringList(json['photos']),
      amenities: _parseStringList(json['amenities']),
      availableGames: _parseStringList(json['availableGames']),
      isActive: json['isActive'] ?? true,
      rating: _parseDouble(json['rating']),
      totalReviews: json['totalReviews'] ?? 0,
      distance: json['distance'] != null ? _parseDouble(json['distance']) : null,
      owner: json['owner'] != null ? CafeOwner.fromJson(json['owner']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'mapsLink': mapsLink,
      'hourlyRate': hourlyRate,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'totalPcStations': totalPcStations,
      'pcHourlyRate': pcHourlyRate,
      'pcSpecs': pcSpecs?.toJson(),
      'pcGames': pcGames,
      'photos': photos,
      'amenities': amenities,
      'availableGames': availableGames,
      'isActive': isActive,
    };
  }

  /// Get effective PC hourly rate
  double get effectivePcRate => pcHourlyRate ?? hourlyRate;

  /// Get first photo or placeholder
  String get primaryPhoto =>
      photos.isNotEmpty ? photos.first : 'https://via.placeholder.com/400x200';

  /// Get full address
  String get fullAddress {
    final parts = [address, city];
    if (state != null) parts.add(state!);
    if (zipCode != null) parts.add(zipCode!);
    return parts.join(', ');
  }

  /// Get distance display
  String get distanceDisplay {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).round()}m away';
    }
    return '${distance!.toStringAsFixed(1)}km away';
  }

  /// Has PCs available
  bool get hasPcs => totalPcStations > 0;

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

/// PC Specifications
class PcSpecs {
  final String cpu;
  final String gpu;
  final String ram;
  final String storage;
  final String monitors;
  final List<String> peripherals;

  PcSpecs({
    this.cpu = '',
    this.gpu = '',
    this.ram = '',
    this.storage = '',
    this.monitors = '',
    this.peripherals = const [],
  });

  factory PcSpecs.fromJson(Map<String, dynamic> json) {
    return PcSpecs(
      cpu: json['cpu'] ?? '',
      gpu: json['gpu'] ?? '',
      ram: json['ram'] ?? '',
      storage: json['storage'] ?? '',
      monitors: json['monitors'] ?? '',
      peripherals: json['peripherals'] != null
          ? List<String>.from(json['peripherals'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpu': cpu,
      'gpu': gpu,
      'ram': ram,
      'storage': storage,
      'monitors': monitors,
      'peripherals': peripherals,
    };
  }

  /// Check if specs are available
  bool get hasSpecs => cpu.isNotEmpty || gpu.isNotEmpty || ram.isNotEmpty;
}

/// Cafe Owner (simplified)
class CafeOwner {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  CafeOwner({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory CafeOwner.fromJson(Map<String, dynamic> json) {
    return CafeOwner(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
    );
  }
}

/// Cafe List Response
class CafeListResponse {
  final bool success;
  final List<Cafe> cafes;
  final PaginationInfo? pagination;

  CafeListResponse({
    required this.success,
    required this.cafes,
    this.pagination,
  });

  factory CafeListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<Cafe> cafeList = [];
    
    if (data != null && data['cafes'] != null) {
      cafeList = (data['cafes'] as List)
          .map((c) => Cafe.fromJson(c))
          .toList();
    }

    return CafeListResponse(
      success: json['success'] ?? false,
      cafes: cafeList,
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

