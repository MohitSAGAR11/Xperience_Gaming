import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/client/client_main_screen.dart';
import '../screens/client/home/client_home_screen.dart';
import '../screens/client/search/search_screen.dart';
import '../screens/client/community/community_screen.dart';
import '../screens/client/cafe/cafe_details_screen.dart';
import '../screens/client/booking/slot_selection_screen.dart';
import '../screens/client/booking/booking_confirmation_screen.dart';
import '../screens/client/bookings/my_bookings_screen.dart';
import '../screens/client/profile/client_profile_screen.dart';
import '../screens/client/profile/edit_profile_screen.dart' as client;
import '../screens/client/support/help_support_screen.dart';
import '../screens/owner/owner_main_screen.dart';
import '../screens/owner/dashboard/owner_dashboard_screen.dart';
import '../screens/owner/cafes/my_cafes_screen.dart';
import '../screens/owner/cafes/add_edit_cafe_screen.dart';
import '../screens/owner/bookings/cafe_bookings_screen.dart';
import '../screens/owner/profile/owner_profile_screen.dart';
import '../screens/owner/profile/edit_profile_screen.dart' as owner;
import '../screens/owner/earnings/earnings_analytics_screen.dart';
import '../screens/owner/verification/verification_pending_screen.dart';

/// Route Names
class Routes {
  // Auth Routes
  static const String splash = '/';
  static const String auth = '/auth'; // Single auth screen for Google Sign-In
  
  // Client Routes
  static const String clientHome = '/client';
  static const String search = '/client/search';
  static const String community = '/client/community';
  static const String cafeDetails = '/client/cafe/:id';
  static const String slotSelection = '/client/cafe/:id/book';
  static const String bookingConfirmation = '/client/booking/confirm';
  static const String myBookings = '/client/bookings';
  static const String clientProfile = '/client/profile';
  static const String editClientProfile = '/client/profile/edit';
  static const String helpSupport = '/client/help-support';
  
  // Owner Routes
  static const String ownerDashboard = '/owner';
  static const String myCafes = '/owner/cafes';
  static const String addCafe = '/owner/cafes/add';
  static const String editCafe = '/owner/cafes/:id/edit';
  static const String cafeBookings = '/owner/cafes/:id/bookings';
  static const String ownerProfile = '/owner/profile';
  static const String editOwnerProfile = '/owner/profile/edit';
  static const String earningsAnalytics = '/owner/earnings-analytics';
  static const String ownerHelpSupport = '/owner/help-support';
  static const String verificationPending = '/owner/verification-pending';
}

/// Router Configuration
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth Route - Single screen for Google Sign-In
      GoRoute(
        path: Routes.auth,
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      
      // Client Shell Route (with bottom navigation)
      ShellRoute(
        builder: (context, state, child) => ClientMainScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.clientHome,
            name: 'clientHome',
            builder: (context, state) => const ClientHomeScreen(),
          ),
          GoRoute(
            path: Routes.search,
            name: 'search',
            builder: (context, state) {
              final query = state.uri.queryParameters['q'] ?? '';
              return SearchScreen(initialQuery: query);
            },
          ),
          GoRoute(
            path: Routes.community,
            name: 'community',
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: Routes.myBookings,
            name: 'myBookings',
            builder: (context, state) => const MyBookingsScreen(),
          ),
          GoRoute(
            path: Routes.clientProfile,
            name: 'clientProfile',
            builder: (context, state) => const ClientProfileScreen(),
          ),
        ],
      ),
      
      // Client Detail Routes (outside shell)
      GoRoute(
        path: Routes.editClientProfile,
        name: 'editClientProfile',
        builder: (context, state) => const client.EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.helpSupport,
        name: 'helpSupport',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: Routes.cafeDetails,
        name: 'cafeDetails',
        builder: (context, state) {
          final cafeId = state.pathParameters['id']!;
          return CafeDetailsScreen(cafeId: cafeId);
        },
      ),
      GoRoute(
        path: Routes.slotSelection,
        name: 'slotSelection',
        builder: (context, state) {
          final cafeId = state.pathParameters['id']!;
          return SlotSelectionScreen(cafeId: cafeId);
        },
      ),
      GoRoute(
        path: Routes.bookingConfirmation,
        name: 'bookingConfirmation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BookingConfirmationScreen(bookingData: extra ?? {});
        },
      ),
      
      // Owner Shell Route (with bottom navigation)
      ShellRoute(
        builder: (context, state, child) => OwnerMainScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.ownerDashboard,
            name: 'ownerDashboard',
            builder: (context, state) => const OwnerDashboardScreen(),
          ),
          GoRoute(
            path: Routes.myCafes,
            name: 'myCafes',
            builder: (context, state) => const MyCafesScreen(),
          ),
          GoRoute(
            path: Routes.ownerProfile,
            name: 'ownerProfile',
            builder: (context, state) => const OwnerProfileScreen(),
          ),
        ],
      ),
      
      // Owner Detail Routes (outside shell)
      GoRoute(
        path: Routes.editOwnerProfile,
        name: 'editOwnerProfile',
        builder: (context, state) => const owner.EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.addCafe,
        name: 'addCafe',
        builder: (context, state) => const AddEditCafeScreen(),
      ),
      GoRoute(
        path: Routes.editCafe,
        name: 'editCafe',
        builder: (context, state) {
          final cafeId = state.pathParameters['id']!;
          return AddEditCafeScreen(cafeId: cafeId);
        },
      ),
      GoRoute(
        path: Routes.cafeBookings,
        name: 'cafeBookings',
        builder: (context, state) {
          final cafeId = state.pathParameters['id']!;
          return CafeBookingsScreen(cafeId: cafeId);
        },
      ),
      GoRoute(
        path: Routes.earningsAnalytics,
        name: 'earningsAnalytics',
        builder: (context, state) => const EarningsAnalyticsScreen(),
      ),
      GoRoute(
        path: Routes.ownerHelpSupport,
        name: 'ownerHelpSupport',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: Routes.verificationPending,
        name: 'verificationPending',
        builder: (context, state) => const VerificationPendingScreen(),
      ),
    ],
    
    // Error Page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(Routes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

