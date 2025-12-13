import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../providers/community_provider.dart';
import '../../../models/community_model.dart';
import '../../../widgets/loading_widget.dart';

/// Community Screen - Shows recent booking activities
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final communityFeedAsync = ref.watch(communityFeedProvider(
      CommunityFeedParams(page: _currentPage, limit: 20),
    ));

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.people_outline, color: AppColors.cyberCyan),
            SizedBox(width: 8),
            Text(
              'Community',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () {
              ref.invalidate(communityFeedProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communityFeedProvider);
        },
        color: AppColors.cyberCyan,
        backgroundColor: AppColors.surfaceDark,
        child: communityFeedAsync.when(
          data: (feedResponse) {
            if (feedResponse.posts.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feedResponse.posts.length,
              itemBuilder: (context, index) {
                final post = feedResponse.posts[index];
                return _buildCommunityPostCard(post);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.cyberCyan),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                SizedBox(height: 16),
                Text(
                  'Failed to load community feed',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.invalidate(communityFeedProvider);
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 24),
            Text(
              'No Activity Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Booking activities will appear here',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Text(
              'Be the first to book a gaming session!',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPostCard(CommunityPost post) {
    return GestureDetector(
      onTap: () {
        // Navigate to cafe details
        context.push('/client/cafe/${post.cafeId}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardDark, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info and time
            Row(
              children: [
                // User avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.neonPurple,
                  backgroundImage: post.userAvatar != null
                      ? CachedNetworkImageProvider(post.userAvatar!)
                      : null,
                  child: post.userAvatar == null
                      ? Text(
                          post.userInitials,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        post.timeAgo,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // Activity description
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: 'is going to '),
                  TextSpan(
                    text: post.cafeName,
                    style: TextStyle(
                      color: AppColors.cyberCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (post.cafeCity != null) ...[
                    TextSpan(text: ' in '),
                    TextSpan(
                      text: post.cafeCity,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12),

            // Booking details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Station icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      post.stationType == 'pc'
                          ? Icons.computer
                          : Icons.sports_esports,
                      color: AppColors.neonPurple,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.stationLabel,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text(
                              post.bookingDate,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.access_time,
                                size: 12, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text(
                              post.formattedStartTime,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
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

            // Cafe image (if available)
            if (post.cafePhoto != null) ...[
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.cafePhoto!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.cardDark,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.cyberCyan,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.cardDark,
                    child: Icon(Icons.image, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

