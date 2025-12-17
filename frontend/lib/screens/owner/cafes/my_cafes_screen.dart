import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../core/utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cafe_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/custom_button.dart';

/// My Cafes Screen (Owner)
class MyCafesScreen extends ConsumerWidget {
  const MyCafesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafesAsync = ref.watch(myCafesProvider);

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.trueBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.ownerDashboard),
        ),
        title: const Text('My Cafes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final user = ref.read(currentUserProvider);
              if (user != null && user.isOwner && !user.isVerifiedOwner) {
                context.push(Routes.verificationPending);
              } else {
                context.push(Routes.addCafe);
              }
            },
          ),
        ],
      ),
      body: cafesAsync.when(
        data: (cafes) {
          if (cafes.isEmpty) {
            return EmptyState(
              icon: Icons.store_outlined,
              title: 'No cafes yet',
              subtitle: 'Add your first gaming cafe to start accepting bookings',
              action: GlowButton(
                text: 'Add Cafe',
                isExpanded: false,
                onPressed: () => context.push(Routes.addCafe),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myCafesProvider),
            color: AppColors.cyberCyan,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cafes.length,
              itemBuilder: (context, index) {
                final cafe = cafes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Cafe Info
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                image: cafe.photos.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(cafe.primaryPhoto),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: cafe.photos.isEmpty
                                  ? const Icon(
                                      Icons.store,
                                      color: AppColors.textMuted,
                                      size: 40,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cafe.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cafe.city,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: AppColors.warning,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        cafe.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${cafe.totalReviews} reviews)',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cafe.isActive
                                    ? AppColors.success.withOpacity(0.15)
                                    : AppColors.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cafe.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: cafe.isActive
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stats Row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _CafeStat(
                              icon: Icons.computer,
                              value: cafe.totalPcStations.toString(),
                              label: 'PCs',
                            ),
                            _CafeStat(
                              icon: Icons.currency_rupee,
                              value: CurrencyUtils.formatINR(cafe.hourlyRate)
                                  .replaceAll('₹', ''),
                              label: '/hr',
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/owner/cafes/${cafe.id}/edit'),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.cyberCyan,
                                  side: const BorderSide(color: AppColors.cyberCyan),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    context.push('/owner/cafes/${cafe.id}/bookings'),
                                icon: const Icon(Icons.calendar_month, size: 18),
                                label: const Text('Bookings'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: NeonLoader()),
        error: (e, s) => ErrorDisplay(
          message: e.toString(),
          onRetry: () => ref.invalidate(myCafesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final user = ref.read(currentUserProvider);
          if (user != null && user.isOwner && !user.isVerifiedOwner) {
            context.push(Routes.verificationPending);
          } else {
            context.push(Routes.addCafe);
          }
        },
        backgroundColor: AppColors.cyberCyan,
        icon: const Icon(Icons.add),
        label: const Text('Add Cafe'),
      ),
    );
  }
}

class _CafeStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CafeStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.cyberCyan, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

