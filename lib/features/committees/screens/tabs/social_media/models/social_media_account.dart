/// Represents a connected social media account
class SocialMediaAccount {
  final String id;
  final String platform;
  final String accountName;
  final String? accountId;
  final bool isActive;
  final DateTime? lastSyncedAt;
  final Map<String, dynamic> metadata;

  const SocialMediaAccount({
    required this.id,
    required this.platform,
    required this.accountName,
    this.accountId,
    this.isActive = true,
    this.lastSyncedAt,
    this.metadata = const {},
  });

  /// Safely parse a value that should be a Map
  static Map<String, dynamic> _safeParseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  factory SocialMediaAccount.fromJson(Map<String, dynamic> json) {
    return SocialMediaAccount(
      id: json['id'] as String,
      platform: json['platform'] as String,
      accountName: json['account_name'] as String,
      accountId: json['account_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
      metadata: _safeParseMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform,
      'account_name': accountName,
      'account_id': accountId,
      'is_active': isActive,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  SocialMediaAccount copyWith({
    String? id,
    String? platform,
    String? accountName,
    String? accountId,
    bool? isActive,
    DateTime? lastSyncedAt,
    Map<String, dynamic>? metadata,
  }) {
    return SocialMediaAccount(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      accountName: accountName ?? this.accountName,
      accountId: accountId ?? this.accountId,
      isActive: isActive ?? this.isActive,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
