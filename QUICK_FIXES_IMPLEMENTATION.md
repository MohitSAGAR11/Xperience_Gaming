# Quick Fixes Implementation Guide

## Fix 1: Remove Debug Prints & Add Logger

### Step 1: Add logger dependency
Add to `pubspec.yaml`:
```yaml
dependencies:
  logger: ^2.0.2
```

### Step 2: Create logger utility
Create `frontend/lib/core/logger.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

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

  static void d(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  static void i(String message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      _logger.w(message);
    }
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }
}
```

### Step 3: Replace all prints
Replace `print('...')` with `AppLogger.d('...')` throughout the codebase.

---

## Fix 2: Conditional LogInterceptor

**File**: `frontend/lib/core/api_client.dart`

**Change**:
```dart
// Add import at top
import 'package:flutter/foundation.dart';

// Replace lines 54-60 with:
if (kDebugMode) {
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ),
  );
}
```

---

## Fix 3: Cache Firebase Token

**File**: `frontend/lib/core/api_client.dart`

**Change**:
```dart
/// Dio HTTP Client Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Token cache
  String? _cachedToken;
  DateTime? _tokenExpiry;

  // Add interceptors
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Refresh token if expired or not cached
        if (_cachedToken == null || 
            _tokenExpiry == null || 
            DateTime.now().isAfter(_tokenExpiry!)) {
          _cachedToken = await FirebaseService.getIdToken();
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
        }
        
        if (_cachedToken != null) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Handle 401 - Token expired or invalid
        if (error.response?.statusCode == 401) {
          // Clear cached token
          _cachedToken = null;
          _tokenExpiry = null;
          // Sign out from Firebase Auth
          await FirebaseService.auth.signOut();
        }
        return handler.next(error);
      },
    ),
  );

  // Add logging in debug mode only
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
});
```

---

## Fix 4: Fix Duplicate Booking Calls

**File**: `frontend/lib/providers/booking_provider.dart`

**Change**:
```dart
/// Upcoming Bookings Provider (derived from myBookingsProvider)
final upcomingBookingsProvider = Provider<List<Booking>>((ref) {
  final bookingsAsync = ref.watch(myBookingsProvider);
  return bookingsAsync.when(
    data: (response) => response.categorized?.upcoming ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Past Bookings Provider (derived from myBookingsProvider)
final pastBookingsProvider = Provider<List<Booking>>((ref) {
  final bookingsAsync = ref.watch(myBookingsProvider);
  return bookingsAsync.when(
    data: (response) => response.categorized?.past ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});
```

**Note**: Update screens that use these providers to handle `AsyncValue`:
```dart
// Instead of:
final upcoming = ref.watch(upcomingBookingsProvider);

// Use:
final bookingsAsync = ref.watch(myBookingsProvider);
final upcoming = bookingsAsync.when(
  data: (response) => response.categorized?.upcoming ?? [],
  loading: () => <Booking>[],
  error: (_, __) => <Booking>[],
);
```

---

## Fix 5: Add Search Debouncing

**File**: `frontend/lib/screens/client/search/search_screen.dart`

**Add import**:
```dart
import 'dart:async';
```

**Add to state class**:
```dart
Timer? _debounceTimer;

void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
    }
  });
}

@override
void dispose() {
  _debounceTimer?.cancel();
  _searchController.dispose();
  super.dispose();
}
```

**Update TextField**:
```dart
TextField(
  controller: _searchController,
  onChanged: _onSearchChanged, // Use debounced handler
  // ... rest of config
)
```

---

## Fix 6: Optimize Distance Calculations

**File**: `frontend/lib/providers/cafe_provider.dart`

**Update `allCafesWithDistanceProvider`**:
```dart
final allCafesWithDistanceProvider = FutureProvider.autoDispose
    .family<List<Cafe>, String>((ref, searchQuery) async {
  final cafeService = ref.watch(cafeServiceProvider);
  final locationState = ref.watch(locationProvider);

  if (locationState.location == null) {
    return [];
  }

  final userLat = locationState.location!.latitude;
  final userLon = locationState.location!.longitude;

  List<Cafe> cafes;
  
  if (searchQuery.isNotEmpty) {
    final response = await cafeService.getAllCafes(search: searchQuery);
    cafes = response.cafes;
  } else {
    final response = await cafeService.getNearbyCafes(
      latitude: userLat,
      longitude: userLon,
      radius: 50.0,
    );
    cafes = response.cafes;
  }
  
  // Calculate distance once and sort
  final cafesWithDistance = cafes.map((cafe) {
    final distance = _calculateDistance(
      userLat,
      userLon,
      cafe.latitude,
      cafe.longitude,
    );
    // Note: You'll need to add a copyWith method to Cafe model
    // or create a wrapper class that includes distance
    return cafe; // For now, distance is calculated in CafeCard
  }).toList();
  
  cafesWithDistance.sort((a, b) {
    final distA = _calculateDistance(userLat, userLon, a.latitude, a.longitude);
    final distB = _calculateDistance(userLat, userLon, b.latitude, b.longitude);
    return distA.compareTo(distB);
  });
  
  return cafesWithDistance;
});
```

**Better solution**: Add distance to Cafe model and calculate once.

---

## Fix 7: Add Const Constructors

**Quick wins** - Add `const` to these widgets:

1. **`frontend/lib/widgets/cafe_card.dart`**:
   - `_buildStat` method return widget
   - Icons, SizedBox widgets

2. **`frontend/lib/widgets/loading_widget.dart`**:
   - All Shimmer widgets
   - ErrorDisplay widget (if message is const)

3. **`frontend/lib/screens/client/home/client_home_screen.dart`**:
   - `_LocationErrorBanner` widget parts

**Example**:
```dart
// Before:
const SizedBox(width: 4),

// After (if already const, no change needed):
const SizedBox(width: 4), // Already const ✅
```

---

## Fix 8: Optimize Image Cache

**File**: `frontend/lib/widgets/cafe_card.dart`

**Change**:
```dart
CachedNetworkImage(
  imageUrl: cafe.primaryPhoto,
  height: 160,
  width: double.infinity,
  fit: BoxFit.cover,
  memCacheHeight: 160, // Match display height (was 320)
  memCacheWidth: 400,  // Match display width (was 800)
  maxHeightDiskCache: 320, // Keep higher for disk cache
  maxWidthDiskCache: 800,
  // ... rest
)
```

---

## Testing Checklist

After implementing fixes:

- [ ] Run app in release mode and verify no debug prints
- [ ] Check network tab - verify token is cached
- [ ] Test search - verify debouncing works
- [ ] Check booking screens - verify no duplicate calls
- [ ] Monitor memory usage - should be lower
- [ ] Test image loading - should be faster
- [ ] Verify app still works correctly

---

## Next Steps

After completing these quick fixes, proceed with Phase 2 optimizations from the main recommendations document.

