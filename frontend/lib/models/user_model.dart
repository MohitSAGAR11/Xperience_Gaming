class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? avatar;
  final bool? verified; // Only for owners, null for clients
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatar,
    this.verified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // CRITICAL: Parse verified field correctly - handle boolean, string, int, null, undefined
    // Firestore might return boolean true/false, string "true"/"false", int 1/0, or null/undefined
    bool? verified;
    final role = json['role'] ?? 'client';
    
    if (role == 'owner') {
      // For owners, verified should be a boolean
      final verifiedValue = json['verified'];
      if (verifiedValue == null) {
        verified = false; // Default to false if null/undefined
      } else if (verifiedValue is bool) {
        verified = verifiedValue;
      } else if (verifiedValue is String) {
        verified = verifiedValue.toLowerCase() == 'true';
      } else if (verifiedValue is int) {
        verified = verifiedValue == 1;
      } else if (verifiedValue is num) {
        verified = verifiedValue.toInt() == 1;
      } else {
        verified = false; // Default to false for any other type
      }
    } else {
      // For clients, verified should be null/undefined
      verified = null;
    }
    
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: role,
      phone: json['phone'],
      avatar: json['avatar'],
      verified: verified, // null for clients, boolean for owners
      createdAt: _parseTimestamp(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is String) {
      return DateTime.parse(timestamp);
    }

    if (timestamp is Map) {
      final seconds = timestamp['_seconds'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar': avatar,
      'verified': verified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isOwner => role == 'owner';

  bool get isClient => role == 'client';

  bool get isVerifiedOwner => isOwner && (verified == true);

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? avatar,
    bool? verified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AuthResponse {
  final bool success;
  final String message;
  final User? user;
  final String? token;

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: data != null && data['user'] != null
          ? User.fromJson(data['user'])
          : null,
      token: data?['token'],
    );
  }
}