/// Community Post Model - Represents a booking activity in the community feed
class CommunityPost {
  final String id;
  final String bookingId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String cafeId;
  final String cafeName;
  final String? cafePhoto;
  final String? cafeCity;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final String stationType; // 'pc' or 'console'
  final String? consoleType;
  final int stationNumber;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.cafeId,
    required this.cafeName,
    this.cafePhoto,
    this.cafeCity,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.stationType,
    this.consoleType,
    required this.stationNumber,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] ?? '',
      bookingId: json['bookingId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonymous',
      userAvatar: json['userAvatar'],
      cafeId: json['cafeId'] ?? '',
      cafeName: json['cafeName'] ?? '',
      cafePhoto: json['cafePhoto'],
      cafeCity: json['cafeCity'],
      bookingDate: json['bookingDate'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      stationType: json['stationType'] ?? 'pc',
      consoleType: json['consoleType'],
      stationNumber: json['stationNumber'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Get time ago string (e.g., "2 hours ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} week(s) ago';
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

  /// Get formatted booking time (e.g., "10:00 AM")
  String get formattedStartTime {
    try {
      final time = DateTime.parse('2000-01-01 $startTime');
      final hour = time.hour;
      final minute = time.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return startTime;
    }
  }

  /// Get station/console label (e.g., "PC #5" or "PS5 #2")
  String get stationLabel {
    if (stationType == 'pc') {
      return 'PC #$stationNumber';
    } else if (consoleType != null) {
      return '${consoleType!.toUpperCase().replaceAll('_', ' ')} #$stationNumber';
    } else {
      return 'Console #$stationNumber';
    }
  }

  /// Get user initials for avatar
  String get userInitials {
    final parts = userName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return userName.substring(0, 2).toUpperCase();
  }
}

/// Community Feed Response
class CommunityFeedResponse {
  final bool success;
  final List<CommunityPost> posts;
  final PaginationInfo? pagination;

  CommunityFeedResponse({
    required this.success,
    required this.posts,
    this.pagination,
  });

  factory CommunityFeedResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<CommunityPost> postList = [];

    if (data != null && data['posts'] != null) {
      postList = (data['posts'] as List)
          .map((p) => CommunityPost.fromJson(p))
          .toList();
    }

    return CommunityFeedResponse(
      success: json['success'] ?? false,
      posts: postList,
      pagination: data != null && data['pagination'] != null
          ? PaginationInfo.fromJson(data['pagination'])
          : null,
    );
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
      limit: json['limit'] ?? 20,
    );
  }
}

