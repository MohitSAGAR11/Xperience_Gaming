import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../core/utils.dart';
import '../../../providers/cafe_provider.dart';
import '../../../providers/review_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/review_service.dart';
import '../../../models/review_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/cafe_card.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/review_widgets.dart';

/// Cafe Details Screen
class CafeDetailsScreen extends ConsumerWidget {
  final String cafeId;

  const CafeDetailsScreen({super.key, required this.cafeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafeAsync = ref.watch(cafeProvider(cafeId));

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      body: cafeAsync.when(
        data: (cafe) {
          if (cafe == null) {
            return const ErrorDisplay(message: 'Cafe not found');
          }

          return CustomScrollView(
            slivers: [
              // Image Header
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppColors.surfaceDark,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'cafe_image_${cafe.id}',
                        child: CachedNetworkImage(
                          imageUrl: cafe.primaryPhoto,
                          fit: BoxFit.cover,
                          memCacheHeight: 500,
                          memCacheWidth: 1000,
                          maxHeightDiskCache: 500,
                          maxWidthDiskCache: 1000,
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceDark,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surfaceDark,
                            child: const Icon(Icons.image, size: 64),
                          ),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.trueBlack.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              cafe.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              RatingBarIndicator(
                                rating: cafe.rating,
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: AppColors.warning,
                                ),
                                itemCount: 5,
                                itemSize: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${cafe.rating.toStringAsFixed(1)} (${cafe.totalReviews})',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Address - Clickable
                      InkWell(
                        onTap: () async {
                          try {
                            debugPrint('🗺️ [MAP_LINK] Attempting to open map');
                            debugPrint('🗺️ [MAP_LINK] mapsLink value: "${cafe.mapsLink}"');
                            debugPrint('🗺️ [MAP_LINK] isEmpty: ${cafe.mapsLink.isEmpty}');
                            
                            if (cafe.mapsLink.isEmpty) {
                              debugPrint('🗺️ [MAP_LINK] ERROR: mapsLink is empty!');
                              return;
                            }
                            
                            final uri = Uri.parse(cafe.mapsLink);
                            debugPrint('🗺️ [MAP_LINK] Parsed URI: $uri');
                            
                            final canLaunch = await canLaunchUrl(uri);
                            debugPrint('🗺️ [MAP_LINK] canLaunchUrl result: $canLaunch');
                            
                            if (canLaunch) {
                              debugPrint('🗺️ [MAP_LINK] Launching with externalApplication mode...');
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              debugPrint('🗺️ [MAP_LINK] Launch successful!');
                            } else {
                              debugPrint('🗺️ [MAP_LINK] Trying platformDefault mode...');
                              await launchUrl(uri);
                            }
                          } catch (e) {
                            debugPrint('🗺️ [MAP_LINK] ERROR: $e');
                            // Try alternative URL format
                            try {
                              debugPrint('🗺️ [MAP_LINK] Trying fallback URL...');
                              final fallbackUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cafe.fullAddress)}');
                              await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
                              debugPrint('🗺️ [MAP_LINK] Fallback successful!');
                            } catch (fallbackError) {
                              debugPrint('🗺️ [MAP_LINK] Fallback failed: $fallbackError');
                            }
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.cyberCyan, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cafe.fullAddress,
                                style: const TextStyle(
                                  color: AppColors.cyberCyan,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new, color: AppColors.cyberCyan, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Timing
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppColors.cyberCyan, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${DateTimeUtils.formatTimeString(cafe.openingTime)} - ${DateTimeUtils.formatTimeString(cafe.closingTime)}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      if (cafe.description != null && cafe.description!.isNotEmpty) ...[
                        const Text(
                          'About',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cafe.description!,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Pricing
                      const Text(
                        'Pricing',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PricingCard(
                        icon: Icons.computer,
                        title: 'PC Gaming',
                        subtitle: '${cafe.totalPcStations} stations available',
                        price: cafe.effectivePcRate,
                      ),
                      const SizedBox(height: 24),

                      // PC Specs
                      if (cafe.pcSpecs != null && cafe.pcSpecs!.hasSpecs) ...[
                        const Text(
                          'PC Specifications',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (cafe.pcSpecs!.cpu.isNotEmpty)
                                _SpecRow(label: 'CPU', value: cafe.pcSpecs!.cpu),
                              if (cafe.pcSpecs!.gpu.isNotEmpty)
                                _SpecRow(label: 'GPU', value: cafe.pcSpecs!.gpu),
                              if (cafe.pcSpecs!.ram.isNotEmpty)
                                _SpecRow(label: 'RAM', value: cafe.pcSpecs!.ram),
                              if (cafe.pcSpecs!.monitors.isNotEmpty)
                                _SpecRow(label: 'Monitor', value: cafe.pcSpecs!.monitors),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Available Games
                      if (cafe.pcGames.isNotEmpty || cafe.availableGames.isNotEmpty) ...[
                        const Text(
                          'Available Games',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...cafe.pcGames.map((g) => GameBadge(game: g)),
                            ...cafe.availableGames
                                .where((g) => !cafe.pcGames.contains(g))
                                .map((g) => GameBadge(game: g)),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Amenities
                      if (cafe.amenities.isNotEmpty) ...[
                        const Text(
                          'Amenities',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: cafe.amenities
                              .map((a) => _AmenityChip(label: a))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Reviews Section
                      _ReviewsSection(
                        cafeId: cafe.id,
                        cafeName: cafe.name,
                      ),

                      // Bottom spacing for button
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: NeonLoader()),
        error: (error, stack) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(cafeProvider(cafeId)),
        ),
      ),
      // Book Now Button
      bottomSheet: cafeAsync.whenOrNull(
        data: (cafe) => cafe != null
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPurple.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Starting from',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${CurrencyUtils.formatINR(cafe.hourlyRate)}/hr',
                            style: const TextStyle(
                              color: AppColors.cyberCyan,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: GlowButton(
                          text: 'BOOK NOW',
                          onPressed: () => context.push('/client/cafe/${cafe.id}/book'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double price;

  const _PricingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.neonPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.neonPurple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${CurrencyUtils.formatINR(price)}/hr',
            style: const TextStyle(
              color: AppColors.cyberCyan,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final String label;

  const _AmenityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Reviews Section Widget
class _ReviewsSection extends ConsumerWidget {
  final String cafeId;
  final String cafeName;

  const _ReviewsSection({
    required this.cafeId,
    required this.cafeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(cafeReviewsProvider(
      CafeReviewsParams(cafeId: cafeId, limit: 5),
    ));
    final userReviewAsync = ref.watch(checkUserReviewProvider(cafeId));
    final currentUser = ref.watch(currentUserProvider);
    final reviewService = ref.watch(reviewServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews & Ratings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Rate this Cafe Button
        if (currentUser != null && currentUser.role == 'client')
          GlowButton(
            text: userReviewAsync.when(
              data: (checkResponse) => checkResponse.hasReviewed
                  ? 'UPDATE YOUR REVIEW'
                  : 'RATE THIS CAFE',
              loading: () => 'LOADING...',
              error: (_, __) => 'RATE THIS CAFE',
            ),
            onPressed: () async {
              final checkResponse = await userReviewAsync.value;
              if (checkResponse != null) {
                await _showReviewDialog(
                  context,
                  ref,
                  reviewService,
                  checkResponse.review,
                );
              }
            },
            icon: Icons.star_border,
          ),
        const SizedBox(height: 24),

        // Reviews List
        reviewsAsync.when(
          data: (reviewsResponse) {
            if (reviewsResponse.reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Be the first to review this cafe!',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reviews Summary
                if (reviewsResponse.ratingDistribution != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: AppColors.warning, size: 32),
                                    const SizedBox(width: 8),
                                    Text(
                                      reviewsResponse.reviews.isNotEmpty
                                          ? (reviewsResponse.reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviewsResponse.reviews.length).toStringAsFixed(1)
                                          : '0.0',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${reviewsResponse.pagination?.total ?? reviewsResponse.reviews.length} reviews',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Individual Reviews
                ...reviewsResponse.reviews.map((review) {
                  final isOwnReview = currentUser?.id == review.userId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info and rating
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.neonPurple,
                                child: Text(
                                  review.user?.initials ?? 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      review.user?.name ?? 'Anonymous',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        RatingBarIndicator(
                                          rating: review.rating.toDouble(),
                                          itemBuilder: (context, _) => const Icon(
                                            Icons.star,
                                            color: AppColors.warning,
                                          ),
                                          itemCount: 5,
                                          itemSize: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          review.timeAgo,
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
                              if (isOwnReview)
                                PopupMenuButton(
                                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                      onTap: () async {
                                        await Future.delayed(Duration.zero);
                                        await _showReviewDialog(
                                          context,
                                          ref,
                                          reviewService,
                                          review,
                                        );
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: AppColors.error),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: AppColors.error)),
                                        ],
                                      ),
                                      onTap: () async {
                                        await _deleteReview(context, ref, reviewService, review.id);
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (review.title != null && review.title!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              review.title!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                          if (review.comment != null && review.comment!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              review.comment!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (review.ownerResponse != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.store, size: 16, color: AppColors.cyberCyan),
                                      SizedBox(width: 6),
                                      Text(
                                        'Owner Response',
                                        style: TextStyle(
                                          color: AppColors.cyberCyan,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    review.ownerResponse!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),

                // Show more reviews link
                if ((reviewsResponse.pagination?.total ?? 0) > 5)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // TODO: Navigate to all reviews screen
                      },
                      child: Text(
                        'View all ${reviewsResponse.pagination?.total ?? 0} reviews',
                        style: const TextStyle(color: AppColors.cyberCyan),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: NeonLoader()),
          error: (error, stack) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to load reviews',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    ReviewService reviewService,
    Review? existingReview,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddReviewDialog(
        cafeId: cafeId,
        cafeName: cafeName,
        existingReview: existingReview,
        onSubmit: (rating, comment, title) async {
          if (existingReview != null) {
            // Update existing review
            final response = await reviewService.updateReview(
              existingReview.id,
              rating: rating,
              comment: comment.isEmpty ? null : comment,
              title: title.isEmpty ? null : title,
            );
            if (!response.success) {
              throw Exception(response.message ?? 'Failed to update review');
            }
          } else {
            // Create new review
            final response = await reviewService.createReview(
              CreateReviewRequest(
                cafeId: cafeId,
                rating: rating,
                comment: comment.isEmpty ? null : comment,
                title: title.isEmpty ? null : title,
              ),
            );
            if (!response.success) {
              throw Exception(response.message ?? 'Failed to create review');
            }
          }
        },
      ),
    );

    if (result == true && context.mounted) {
      // Refresh reviews
      ref.invalidate(cafeReviewsProvider);
      ref.invalidate(checkUserReviewProvider);
      ref.invalidate(cafeProvider);
      
      SnackbarUtils.showSuccess(
        context,
        existingReview != null ? 'Review updated successfully!' : 'Review submitted successfully!',
      );
    }
  }

  Future<void> _deleteReview(
    BuildContext context,
    WidgetRef ref,
    ReviewService reviewService,
    String reviewId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Delete Review?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to delete your review? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await reviewService.deleteReview(reviewId);
      if (success && context.mounted) {
        ref.invalidate(cafeReviewsProvider);
        ref.invalidate(checkUserReviewProvider);
        ref.invalidate(cafeProvider);
        
        SnackbarUtils.showSuccess(context, 'Review deleted successfully');
      } else if (context.mounted) {
        SnackbarUtils.showError(context, 'Failed to delete review');
      }
    }
  }
}

