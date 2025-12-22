import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logger.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/cafe_provider.dart';

/// Background Refresh Service
/// Silently refreshes all providers every minute without showing loading states
class BackgroundRefreshService {
  Timer? _refreshTimer;
  final Ref ref;
  bool _isRunning = false;

  BackgroundRefreshService(this.ref);

  /// Start the background refresh service
  void start() {
    if (_isRunning) {
      AppLogger.d('🔄 [BACKGROUND_REFRESH] Service already running');
      return;
    }

    AppLogger.d('🔄 [BACKGROUND_REFRESH] Starting background refresh service');
    _isRunning = true;

    // Refresh immediately on start
    _refreshAll();

    // Then refresh every minute
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshAll(),
    );
  }

  /// Stop the background refresh service
  void stop() {
    if (!_isRunning) {
      return;
    }

    AppLogger.d('🔄 [BACKGROUND_REFRESH] Stopping background refresh service');
    _isRunning = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresh all providers silently
  void _refreshAll() {
    try {
      // Check if user is authenticated before refreshing
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        AppLogger.d('🔄 [BACKGROUND_REFRESH] User not authenticated, skipping refresh');
        return;
      }

      AppLogger.d('🔄 [BACKGROUND_REFRESH] Starting silent refresh of all providers');

      // Refresh auth profile (silently - no loading state)
      _refreshAuth();

      // Refresh bookings (silently)
      _refreshBookings();

      // Refresh cafes (silently)
      _refreshCafes();

      // Refresh reviews (silently)
      _refreshReviews();

      // Refresh community (silently)
      _refreshCommunity();

      AppLogger.d('🔄 [BACKGROUND_REFRESH] Silent refresh completed');
    } catch (e) {
      AppLogger.e('🔄 [BACKGROUND_REFRESH] Error during refresh', e);
      // Don't stop the service on error, just log it
    }
  }

  /// Refresh auth profile silently
  void _refreshAuth() {
    try {
      // Auth state doesn't change frequently, so we skip it in background refresh
      // It will refresh automatically when the user performs actions
      // This prevents unnecessary API calls
      AppLogger.d('🔄 [BACKGROUND_REFRESH] Auth refresh skipped (low priority)');
    } catch (e) {
      AppLogger.e('🔄 [BACKGROUND_REFRESH] Error refreshing auth', e);
    }
  }

  /// Refresh bookings silently
  void _refreshBookings() {
    try {
      final authState = ref.read(authProvider);
      
      if (authState.isClient) {
        // Refresh my bookings for clients (silently - keeps existing data while fetching new)
        // The refresh happens in the background, we don't need the return value
        // ignore: unused_result
        ref.refresh(myBookingsProvider);
        AppLogger.d('🔄 [BACKGROUND_REFRESH] Client bookings refreshed');
      }
      // Note: Owner cafe bookings are family providers (require cafeId),
      // so they refresh when accessed. This is fine as they don't change frequently.
    } catch (e) {
      AppLogger.e('🔄 [BACKGROUND_REFRESH] Error refreshing bookings', e);
    }
  }

  /// Refresh cafes silently
  void _refreshCafes() {
    try {
      // Refresh nearby cafes
      // ignore: unused_result
      ref.refresh(nearbyCafesProvider);
      
      // Refresh my cafes (if owner)
      final authState = ref.read(authProvider);
      if (authState.isOwner) {
        // ignore: unused_result
        ref.refresh(myCafesProvider);
      }
      
      // Refresh featured cafes
      // ignore: unused_result
      ref.refresh(featuredCafesProvider);
      
      AppLogger.d('🔄 [BACKGROUND_REFRESH] Cafes refreshed');
    } catch (e) {
      AppLogger.e('🔄 [BACKGROUND_REFRESH] Error refreshing cafes', e);
    }
  }

  /// Refresh reviews silently
  void _refreshReviews() {
    try {
      // Note: Review providers are family providers, so we can't refresh all
      // They will refresh when accessed. This is fine as reviews don't change frequently.
      AppLogger.d('🔄 [BACKGROUND_REFRESH] Reviews refresh skipped (family providers)');
    } catch (e) {
      AppLogger.e('🔄 [BACKGROUND_REFRESH] Error refreshing reviews', e);
    }
  }

  /// Refresh community silently
  void _refreshCommunity() {
    try {
      // Note: Community feed is a family provider, so we can't refresh all instances
      // They will refresh when accessed. This is fine as community posts don't change frequently.
      AppLogger.d('🔄 [BACKGROUND_REFRESH] Community refresh skipped (family providers)');
    } catch (e) {
      AppLogger.e('🔄 [BACKGROUND_REFRESH] Error refreshing community', e);
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

/// Background Refresh Service Provider
final backgroundRefreshServiceProvider = Provider<BackgroundRefreshService>((ref) {
  final service = BackgroundRefreshService(ref);
  
  // Auto-start when authenticated
  ref.listen<bool>(isAuthenticatedProvider, (previous, next) {
    if (next) {
      // User just authenticated, start the service
      service.start();
    } else {
      // User logged out, stop the service
      service.stop();
    }
  });
  
  // Start if already authenticated
  if (ref.read(isAuthenticatedProvider)) {
    service.start();
  }
  
  // Cleanup on dispose
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

