import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_model.dart';
import '../services/community_service.dart';

/// Community Feed Provider
final communityFeedProvider = FutureProvider.autoDispose
    .family<CommunityFeedResponse, CommunityFeedParams>((ref, params) async {
  final communityService = ref.watch(communityServiceProvider);
  return await communityService.getCommunityFeed(
    page: params.page,
    limit: params.limit,
  );
});

/// Community Feed Params
class CommunityFeedParams {
  final int page;
  final int limit;

  CommunityFeedParams({
    this.page = 1,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityFeedParams &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(page, limit);
}

/// Community Stats Provider (optional)
final communityStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final communityService = ref.watch(communityServiceProvider);
  return await communityService.getCommunityStats();
});

