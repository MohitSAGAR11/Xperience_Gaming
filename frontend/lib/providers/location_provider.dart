import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Location State
class LocationState {
  final UserLocation? location;
  final bool isLoading;
  final bool hasPermission;
  final String? error;

  LocationState({
    this.location,
    this.isLoading = false,
    this.hasPermission = false,
    this.error,
  });

  LocationState copyWith({
    UserLocation? location,
    bool? isLoading,
    bool? hasPermission,
    String? error,
  }) {
    return LocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error,
    );
  }
}

/// Location Notifier
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _locationService;

  LocationNotifier(this._locationService) : super(LocationState());

  /// Initialize and get current location
  Future<void> getCurrentLocation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if location is enabled
      final isEnabled = await _locationService.isLocationEnabled();
      if (!isEnabled) {
        state = state.copyWith(
          isLoading: false,
          hasPermission: false,
          error: 'Location services are disabled. Please enable them in settings.',
        );
        return;
      }

      // Check permissions
      final permission = await _locationService.checkPermission();
      
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          isLoading: false,
          hasPermission: false,
          error: 'Location permission denied. Please allow location access.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          hasPermission: false,
          error: 'Location permission permanently denied. Please enable in app settings.',
        );
        return;
      }

      // Get current position
      final position = await _locationService.getCurrentPosition();
      
      if (position != null) {
        state = LocationState(
          location: UserLocation.fromPosition(position),
          isLoading: false,
          hasPermission: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not get your location. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error getting location: ${e.toString()}',
      );
    }
  }

  /// Refresh location
  Future<void> refreshLocation() async {
    await getCurrentLocation();
  }

  /// Open location settings
  Future<void> openSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Set manual location (for testing or when GPS is unavailable)
  void setManualLocation(double latitude, double longitude) {
    state = LocationState(
      location: UserLocation(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      ),
      isLoading: false,
      hasPermission: true,
    );
  }
}

/// Location Provider
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationNotifier(locationService);
});

/// Current Location Provider (just lat/lng)
final currentLocationProvider = Provider<UserLocation?>((ref) {
  return ref.watch(locationProvider).location;
});

/// Has Location Permission Provider
final hasLocationPermissionProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).hasPermission;
});

