import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review_model.dart';
import '../services/review_service.dart';

/// Cafe Reviews Provider
final cafeReviewsProvider = FutureProvider.autoDispose
    .family<CafeReviewsResponse, CafeReviewsParams>((ref, params) async {
  final reviewService = ref.watch(reviewServiceProvider);
  return await reviewService.getCafeReviews(
    params.cafeId,
    page: params.page,
    limit: params.limit,
    sort: params.sort,
  );
});

/// Cafe Reviews Params
class CafeReviewsParams {
  final String cafeId;
  final int page;
  final int limit;
  final String sort;

  CafeReviewsParams({
    required this.cafeId,
    this.page = 1,
    this.limit = 10,
    this.sort = 'recent',
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CafeReviewsParams &&
        other.cafeId == cafeId &&
        other.page == page &&
        other.limit == limit &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(cafeId, page, limit, sort);
}

/// Check User Review Provider
final checkUserReviewProvider = FutureProvider.autoDispose
    .family<CheckUserReviewResponse, String>((ref, cafeId) async {
  final reviewService = ref.watch(reviewServiceProvider);
  return await reviewService.checkUserReview(cafeId);
});

/// My Reviews Provider
final myReviewsProvider = FutureProvider.autoDispose<List<Review>>((ref) async {
  final reviewService = ref.watch(reviewServiceProvider);
  return await reviewService.getMyReviews();
});

