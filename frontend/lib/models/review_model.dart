import 'cafe_model.dart';

/// Review Model
class Review {
  final String id;
  final String userId;
  final String cafeId;
  final int rating;
  final String? comment;
  final String? title;
  final String? ownerResponse;
  final DateTime? ownerResponseAt;
  final int helpfulCount;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReviewUser? user;
  final Cafe? cafe;

  Review({
    required this.id,
    required this.userId,
    required this.cafeId,
    required this.rating,
    this.comment,
    this.title,
    this.ownerResponse,
    this.ownerResponseAt,
    this.helpfulCount = 0,
    this.isVisible = true,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.cafe,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      cafeId: json['cafeId'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      title: json['title'],
      ownerResponse: json['ownerResponse'],
      ownerResponseAt: json['ownerResponseAt'] != null
          ? DateTime.parse(json['ownerResponseAt'])
          : null,
      helpfulCount: json['helpfulCount'] ?? 0,
      isVisible: json['isVisible'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      user: json['user'] != null ? ReviewUser.fromJson(json['user']) : null,
      cafe: json['cafe'] != null ? Cafe.fromJson(json['cafe']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'cafeId': cafeId,
      'rating': rating,
      'comment': comment,
      'title': title,
    };
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year(s) ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }
}

/// Simplified User for Review
class ReviewUser {
  final String id;
  final String name;
  final String? avatar;

  ReviewUser({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Anonymous',
      avatar: json['avatar'],
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
}

/// Create Review Request
class CreateReviewRequest {
  final String cafeId;
  final int rating;
  final String? comment;
  final String? title;

  CreateReviewRequest({
    required this.cafeId,
    required this.rating,
    this.comment,
    this.title,
  });

  Map<String, dynamic> toJson() {
    return {
      'cafeId': cafeId,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      if (title != null && title!.isNotEmpty) 'title': title,
    };
  }
}

/// Cafe Reviews Response
class CafeReviewsResponse {
  final bool success;
  final List<Review> reviews;
  final Map<int, int> ratingDistribution;
  final PaginationInfo? pagination;

  CafeReviewsResponse({
    required this.success,
    required this.reviews,
    required this.ratingDistribution,
    this.pagination,
  });

  factory CafeReviewsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<Review> reviewList = [];

    if (data != null && data['reviews'] != null) {
      reviewList = (data['reviews'] as List)
          .map((r) => Review.fromJson(r))
          .toList();
    }

    // Parse rating distribution
    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    if (data != null && data['ratingDistribution'] != null) {
      final dist = data['ratingDistribution'] as Map<String, dynamic>;
      dist.forEach((key, value) {
        distribution[int.parse(key)] = value as int;
      });
    }

    return CafeReviewsResponse(
      success: json['success'] ?? false,
      reviews: reviewList,
      ratingDistribution: distribution,
      pagination: data != null && data['pagination'] != null
          ? PaginationInfo.fromJson(data['pagination'])
          : null,
    );
  }

  /// Get average rating from distribution
  double get averageRating {
    int totalReviews = 0;
    int totalRating = 0;

    ratingDistribution.forEach((rating, count) {
      totalReviews += count;
      totalRating += rating * count;
    });

    if (totalReviews == 0) return 0;
    return totalRating / totalReviews;
  }

  /// Get total reviews count
  int get totalReviews {
    return ratingDistribution.values.fold(0, (sum, count) => sum + count);
  }
}

/// Pagination Info
class PaginationInfo {
  final int total;
  final int page;
  final int pages;
  final int limit;

  PaginationInfo({
    required this.total,
    required this.page,
    required this.pages,
    required this.limit,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['pages'] ?? 1,
      limit: json['limit'] ?? 10,
    );
  }
}

/// Check User Review Response
class CheckUserReviewResponse {
  final bool hasReviewed;
  final Review? review;

  CheckUserReviewResponse({
    required this.hasReviewed,
    this.review,
  });

  factory CheckUserReviewResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return CheckUserReviewResponse(
      hasReviewed: data?['hasReviewed'] ?? false,
      review: data?['review'] != null
          ? Review.fromJson(data['review'])
          : null,
    );
  }
}

