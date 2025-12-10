import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/cafe_model.dart';
import '../core/utils.dart';

/// Cafe Card for List View
class CafeCard extends StatelessWidget {
  final Cafe cafe;
  final VoidCallback? onTap;
  final bool showDistance;

  const CafeCard({
    super.key,
    required this.cafe,
    this.onTap,
    this.showDistance = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonPurple.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Hero(
                    tag: 'cafe_image_${cafe.id}',
                    child: CachedNetworkImage(
                      imageUrl: cafe.primaryPhoto,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheHeight: 320, // 2x for quality
                      memCacheWidth: 800,
                      maxHeightDiskCache: 320,
                      maxWidthDiskCache: 800,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: AppColors.surfaceDark,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.neonPurple,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: AppColors.surfaceDark,
                        child: const Icon(Icons.image, color: AppColors.textMuted, size: 48),
                      ),
                    ),
                  ),
                  // Distance Badge
                  if (showDistance && cafe.distance != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.trueBlack.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: AppColors.cyberCyan, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              cafe.distanceDisplay,
                              style: const TextStyle(
                                color: AppColors.cyberCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Active Status
                  if (!cafe.isActive)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Text(
                            'CLOSED',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cafe.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: cafe.rating,
                            itemBuilder: (context, _) => const Icon(
                              Icons.star,
                              color: AppColors.warning,
                            ),
                            itemCount: 5,
                            itemSize: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cafe.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          final fallbackUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cafe.address + ' ' + cafe.city)}');
                          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
                          debugPrint('🗺️ [MAP_LINK] Fallback successful!');
                        } catch (fallbackError) {
                          debugPrint('🗺️ [MAP_LINK] Fallback failed: $fallbackError');
                        }
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.cyberCyan, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${cafe.address}, ${cafe.city}',
                            style: const TextStyle(
                              color: AppColors.cyberCyan,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new, color: AppColors.cyberCyan, size: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stats Row
                  Row(
                    children: [
                      _buildStat(Icons.computer, '${cafe.totalPcStations} PCs'),
                      const Spacer(),
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.neonPurple, AppColors.cyberCyan],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${CurrencyUtils.formatINR(cafe.hourlyRate)}/hr',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.cyberCyan, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Compact Cafe Card (Horizontal)
class CafeCardCompact extends StatelessWidget {
  final Cafe cafe;
  final VoidCallback? onTap;

  const CafeCardCompact({
    super.key,
    required this.cafe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Hero(
                tag: 'cafe_image_compact_${cafe.id}',
                child: CachedNetworkImage(
                  imageUrl: cafe.primaryPhoto,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  memCacheHeight: 200,
                  memCacheWidth: 200,
                  maxHeightDiskCache: 200,
                  maxWidthDiskCache: 200,
                  placeholder: (context, url) => Container(
                    width: 100,
                    height: 100,
                    color: AppColors.surfaceDark,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 100,
                    height: 100,
                    color: AppColors.surfaceDark,
                    child: const Icon(Icons.image, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cafe.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.warning, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          cafe.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                        if (cafe.distance != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            cafe.distanceDisplay,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyUtils.formatINR(cafe.hourlyRate)}/hr',
                      style: const TextStyle(
                        color: AppColors.cyberCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Game Badge
class GameBadge extends StatelessWidget {
  final String game;
  final bool isSmall;

  const GameBadge({
    super.key,
    required this.game,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.neonPurple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonPurple.withOpacity(0.5)),
      ),
      child: Text(
        game,
        style: TextStyle(
          color: AppColors.neonPurple,
          fontSize: isSmall ? 11 : 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

