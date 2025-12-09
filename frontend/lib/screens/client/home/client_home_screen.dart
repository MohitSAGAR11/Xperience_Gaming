import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/cafe_provider.dart';
import '../../../widgets/cafe_card.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/input_field.dart';

/// Client Home Screen
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Get user location on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final locationState = ref.watch(locationProvider);
    final nearbyCafes = ref.watch(nearbyCafesProvider);

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(locationProvider.notifier).refreshLocation();
            ref.invalidate(nearbyCafesProvider);
          },
          color: AppColors.neonPurple,
          child: CustomScrollView(
            slivers: [
              // App Bar / Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hey ${user?.name.split(' ').first ?? 'Gamer'} 👋',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Ready to game?',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          // Notification Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Search Bar
                      GestureDetector(
                        onTap: () => context.go(Routes.search),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardDark),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: AppColors.cyberCyan),
                              const SizedBox(width: 12),
                              Text(
                                'Search cafes or games...',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Location Status
              if (locationState.error != null)
                SliverToBoxAdapter(
                  child: _LocationErrorBanner(
                    message: locationState.error!,
                    onRetry: () => ref.read(locationProvider.notifier).getCurrentLocation(),
                    onSettings: () => ref.read(locationProvider.notifier).openSettings(),
                  ),
                ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Filters',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _QuickFilter(
                              icon: Icons.computer,
                              label: 'PC Gaming',
                              onTap: () => context.go('${Routes.search}?type=pc'),
                            ),
                            _QuickFilter(
                              icon: Icons.sports_esports,
                              label: 'PS5',
                              onTap: () => context.go('${Routes.search}?console=ps5'),
                            ),
                            _QuickFilter(
                              icon: Icons.gamepad,
                              label: 'Xbox',
                              onTap: () => context.go('${Routes.search}?console=xbox'),
                            ),
                            _QuickFilter(
                              icon: Icons.videogame_asset,
                              label: 'Valorant',
                              onTap: () => context.go('${Routes.search}?q=Valorant'),
                            ),
                            _QuickFilter(
                              icon: Icons.gamepad_outlined,
                              label: 'GTA V',
                              onTap: () => context.go('${Routes.search}?q=GTA'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nearby Cafes Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nearby Cafes',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (locationState.location != null)
                        TextButton(
                          onPressed: () => context.go(Routes.search),
                          child: const Text(
                            'See All',
                            style: TextStyle(color: AppColors.cyberCyan),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Cafe List
              nearbyCafes.when(
                data: (cafes) {
                  if (cafes.isEmpty) {
                    return SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.location_off,
                        title: 'No cafes found nearby',
                        subtitle: locationState.location == null
                            ? 'Enable location to find cafes near you'
                            : 'Try expanding your search radius',
                        action: locationState.location == null
                            ? ElevatedButton(
                                onPressed: () => ref
                                    .read(locationProvider.notifier)
                                    .getCurrentLocation(),
                                child: const Text('Enable Location'),
                              )
                            : null,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final cafe = cafes[index];
                          return CafeCard(
                            cafe: cafe,
                            onTap: () => context.push('/client/cafe/${cafe.id}'),
                          );
                        },
                        childCount: cafes.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const ShimmerCafeCard(),
                      childCount: 3,
                    ),
                  ),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: ErrorDisplay(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(nearbyCafesProvider),
                  ),
                ),
              ),

              // Bottom Padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick Filter Chip
class _QuickFilter extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickFilter({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.cyberCyan),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location Error Banner
class _LocationErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  const _LocationErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

