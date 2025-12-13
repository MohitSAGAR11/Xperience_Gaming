import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../core/api_client.dart';
import '../models/review_model.dart';

/// Review Service - Handles all review-related API calls
class ReviewService {
  final ApiClient _apiClient;

  ReviewService(this._apiClient);

  /// Create a new review
  Future<ReviewResponse> createReview(CreateReviewRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/reviews',
      data: request.toJson(),
    );

    if (response.isSuccess && response.data != null) {
      return ReviewResponse.fromJson(response.data!);
    }

    return ReviewResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Get all reviews for a cafe
  Future<CafeReviewsResponse> getCafeReviews(
    String cafeId, {
    int page = 1,
    int limit = 10,
    String sort = 'recent',
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/reviews/cafe/$cafeId',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sort': sort,
      },
    );

    if (response.isSuccess && response.data != null) {
      return CafeReviewsResponse.fromJson(response.data!);
    }

    return CafeReviewsResponse(
      success: false,
      reviews: [],
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    );
  }

  /// Update a review
  Future<ReviewResponse> updateReview(
    String reviewId, {
    int? rating,
    String? comment,
    String? title,
  }) async {
    final data = <String, dynamic>{};
    if (rating != null) data['rating'] = rating;
    if (comment != null) data['comment'] = comment;
    if (title != null) data['title'] = title;

    final response = await _apiClient.put<Map<String, dynamic>>(
      '/reviews/$reviewId',
      data: data,
    );

    if (response.isSuccess && response.data != null) {
      return ReviewResponse.fromJson(response.data!);
    }

    return ReviewResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }

  /// Delete a review
  Future<bool> deleteReview(String reviewId) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '/reviews/$reviewId',
    );
    return response.isSuccess;
  }

  /// Get user's reviews
  Future<List<Review>> getMyReviews() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/reviews/my-reviews',
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!['data'];
      if (data != null && data['reviews'] != null) {
        return (data['reviews'] as List)
            .map((r) => Review.fromJson(r))
            .toList();
      }
    }

    return [];
  }

  /// Check if user has reviewed a cafe
  Future<CheckUserReviewResponse> checkUserReview(String cafeId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/reviews/check/$cafeId',
    );

    if (response.isSuccess && response.data != null) {
      return CheckUserReviewResponse.fromJson(response.data!);
    }

    return CheckUserReviewResponse(hasReviewed: false);
  }

  /// Owner responds to a review
  Future<ReviewResponse> respondToReview(
    String reviewId,
    String responseText,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/reviews/$reviewId/respond',
      data: {'response': responseText},
    );

    if (response.isSuccess && response.data != null) {
      return ReviewResponse.fromJson(response.data!);
    }

    return ReviewResponse(
      success: false,
      message: response.message ?? ErrorMessages.unknownError,
    );
  }
}

/// Review Service Provider
final reviewServiceProvider = Provider<ReviewService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReviewService(apiClient);
});

