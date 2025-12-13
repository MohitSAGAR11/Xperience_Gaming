import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/community_model.dart';

/// Community Service - Handles all community-related API calls
class CommunityService {
  final ApiClient _apiClient;

  CommunityService(this._apiClient);

  /// Get community feed
  Future<CommunityFeedResponse> getCommunityFeed({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/community/feed',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    if (response.isSuccess && response.data != null) {
      return CommunityFeedResponse.fromJson(response.data!);
    }

    return CommunityFeedResponse(
      success: false,
      posts: [],
    );
  }

  /// Get community stats (optional)
  Future<Map<String, dynamic>?> getCommunityStats() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/community/stats',
    );

    if (response.isSuccess && response.data != null) {
      return response.data!['data'];
    }

    return null;
  }
}

/// Community Service Provider
final communityServiceProvider = Provider<CommunityService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CommunityService(apiClient);
});

