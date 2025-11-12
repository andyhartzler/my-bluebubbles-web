import 'package:collection/collection.dart';

/// Identifies the origin of an email address associated with a member.
enum EmailSource {
  /// Email provided manually by an organizer or user.
  manual('manual', {'manual', 'manual_entry', 'manual-entry', 'entered'}),

  /// Email sourced directly from the member's profile or application.
  memberProfile('member', {'member', 'profile', 'member_record', 'member-profile'}),

  /// Email originating from an educational institution record.
  school('school', {'school', 'school_email', 'school-email', 'education'}),

  /// Email gathered from an external organization integration or import.
  organization(
    'organization',
    {
      'organization',
      'org',
      'chapter',
      'chapter_email',
      'chapter-email',
      'external',
    },
  ),

  /// Email provided by automated CRM imports, campaigns, or syncing jobs.
  campaign('campaign', {'campaign', 'crm', 'import', 'sync', 'supabase'}),

  /// Fallback value when the source is unknown or unclassified.
  unknown('unknown', {'unknown', 'other', 'misc', 'unspecified'});

  const EmailSource(this.wireValue, this._aliases);

  /// Canonical string representation used when serializing to APIs.
  final String wireValue;

  final Set<String> _aliases;

  /// Converts a raw value originating from either the API (camelCase) or the
  /// database (snake_case) into a typed [EmailSource].
  static EmailSource fromJson(dynamic value) {
    if (value == null) return EmailSource.unknown;
    if (value is EmailSource) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return EmailSource.unknown;
    for (final source in EmailSource.values) {
      if (normalized == source.wireValue || source._aliases.contains(normalized)) {
        return source;
      }
    }
    return EmailSource.unknown;
  }

  /// Canonical representation for database writes.
  String get databaseValue => wireValue;

  /// Canonical representation for API writes.
  String toJson() => wireValue;

  /// Human-readable label for displaying the source in the UI.
  String get displayName {
    switch (this) {
      case EmailSource.manual:
        return 'Manual entry';
      case EmailSource.memberProfile:
        return 'Member profile';
      case EmailSource.school:
        return 'School record';
      case EmailSource.organization:
        return 'Organization';
      case EmailSource.campaign:
        return 'Campaign import';
      case EmailSource.unknown:
        return 'Unknown';
    }
  }
}

/// Lightweight model describing an email address that belongs to, or is
/// associated with, a CRM member record.
class MemberEmail {
  MemberEmail({
    this.id,
    this.memberId,
    required this.email,
    this.source = EmailSource.unknown,
    this.isPrimary = false,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.lastVerifiedAt,
    this.label,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata == null
            ? const {}
            : Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(metadata));

  /// Unique identifier for the email entry. Optional because API payloads may
  /// omit an id for pending or unsaved addresses.
  final String? id;

  /// Identifier referencing the associated member.
  final String? memberId;

  /// Raw email address value.
  final String email;

  /// Origin of the email, normalized across API/database variations.
  final EmailSource source;

  /// Whether the email is considered the primary address.
  final bool isPrimary;

  /// Whether the email has been verified by the CRM or mail provider.
  final bool isVerified;

  /// Timestamp representing creation of the record.
  final DateTime? createdAt;

  /// Timestamp representing the most recent update.
  final DateTime? updatedAt;

  /// Timestamp representing the most recent verification.
  final DateTime? lastVerifiedAt;

  /// Optional display label for the email (e.g. "Work", "Personal").
  final String? label;

  /// Arbitrary metadata associated with the email record.
  final Map<String, dynamic> metadata;

  /// Provides a normalized (lowercase) version of the email for comparisons.
  String get normalizedEmail => email.trim().toLowerCase();

  /// Convenience flag indicating whether a member relationship exists.
  bool get hasMember => memberId != null && memberId!.trim().isNotEmpty;

  /// True when the record has an optional label present.
  bool get hasLabel => label != null && label!.trim().isNotEmpty;

  /// Returns a user-facing label prioritizing the explicit label, then source.
  String get displayLabel {
    if (hasLabel) {
      return label!.trim();
    }
    return source.displayName;
  }

  /// Returns whether this email can be considered a primary contact method.
  bool get isPrimaryOrVerified => isPrimary || isVerified;

  /// Creates a copy of the email with selectively replaced properties.
  MemberEmail copyWith({
    String? id,
    String? memberId,
    String? email,
    EmailSource? source,
    bool? isPrimary,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastVerifiedAt,
    String? label,
    Map<String, dynamic>? metadata,
  }) {
    return MemberEmail(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      email: email ?? this.email,
      source: source ?? this.source,
      isPrimary: isPrimary ?? this.isPrimary,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Deserializes a [MemberEmail] from a JSON payload returned by either the
  /// REST API (camelCase) or a database row (snake_case).
  factory MemberEmail.fromJson(Map<String, dynamic> json) {
    final emailValue = _readString(
      json,
      const ['email', 'email_address', 'emailAddress', 'address', 'value'],
    );
    if (emailValue == null || emailValue.isEmpty) {
      throw const FormatException('MemberEmail is missing an email value.');
    }

    final metadataValue = json['metadata'] ?? json['meta'] ?? json['details'];

    return MemberEmail(
      id: _readString(json, const ['id', 'email_id', 'emailId', 'uuid']),
      memberId: _readString(json, const ['member_id', 'memberId', 'contact_id', 'contactId']),
      email: emailValue,
      source: EmailSource.fromJson(
        json['source'] ?? json['source_type'] ?? json['origin'] ?? json['sourceType'],
      ),
      isPrimary: _readBool(json, const ['isPrimary', 'is_primary', 'primary']) ?? false,
      isVerified: _readBool(json, const ['isVerified', 'is_verified', 'verified']) ?? false,
      createdAt: _readDate(json, const ['created_at', 'createdAt', 'created', 'inserted_at']),
      updatedAt: _readDate(json, const ['updated_at', 'updatedAt', 'modified', 'modified_at']),
      lastVerifiedAt: _readDate(
        json,
        const ['last_verified_at', 'lastVerifiedAt', 'verified_at'],
      ),
      label: _readString(json, const ['label', 'description', 'name', 'display_name', 'displayName']),
      metadata: metadataValue is Map
          ? Map<String, dynamic>.from(
              metadataValue.map((key, value) => MapEntry(key.toString(), value)),
            )
          : null,
    );
  }

  /// Serializes the model to a JSON structure suitable for API consumption.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (memberId != null) 'memberId': memberId,
      'email': email,
      'source': source.toJson(),
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastVerifiedAt != null) 'lastVerifiedAt': lastVerifiedAt!.toIso8601String(),
      if (label != null) 'label': label,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Serializes the model using snake_case keys for direct database inserts.
  Map<String, dynamic> toDatabaseMap() {
    return {
      if (id != null) 'id': id,
      if (memberId != null) 'member_id': memberId,
      'email': email,
      'source': source.databaseValue,
      'is_primary': isPrimary,
      'is_verified': isVerified,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt!.toIso8601String(),
      if (label != null) 'label': label,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Creates a list of [MemberEmail] instances from a heterogeneous payload.
  static List<MemberEmail> listFromJson(dynamic raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is List<MemberEmail>) {
      return List<MemberEmail>.unmodifiable(raw);
    }
    if (raw is Iterable) {
      final emails = <MemberEmail>[];
      for (final entry in raw) {
        final email = _coerce(entry);
        if (email != null) {
          emails.add(email);
        }
      }
      return List<MemberEmail>.unmodifiable(emails);
    }
    final email = _coerce(raw);
    return email == null ? const [] : List<MemberEmail>.unmodifiable([email]);
  }

  static MemberEmail? _coerce(dynamic raw) {
    if (raw == null) return null;
    if (raw is MemberEmail) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return MemberEmail(email: raw.trim());
    }
    if (raw is Map) {
      return MemberEmail.fromJson(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      } else if (value is num || value is bool) {
        return value.toString();
      }
    }
    return null;
  }

  static bool? _readBool(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final result = _coerceBool(json[key]);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static bool? _coerceBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (normalized == 'true' ||
          normalized == 't' ||
          normalized == 'yes' ||
          normalized == 'y' ||
          normalized == '1') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'f' ||
          normalized == 'no' ||
          normalized == 'n' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static DateTime? _readDate(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final result = _coerceDate(json[key]);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static DateTime? _coerceDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    if (value is int) {
      if (value.abs() > 9999999999999) {
        return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
      }
      if (value.abs() > 9999999999) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).round(), isUtc: true);
    }
    return null;
  }

  @override
  String toString() {
    final identifier = id ?? 'null';
    final member = memberId ?? 'null';
    return 'MemberEmail(id: $identifier, memberId: $member, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MemberEmail) return false;
    final metadataEquals = const DeepCollectionEquality().equals(metadata, other.metadata);
    return other.id == id &&
        other.memberId == memberId &&
        other.email.toLowerCase() == email.toLowerCase() &&
        other.source == source &&
        other.isPrimary == isPrimary &&
        other.isVerified == isVerified &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastVerifiedAt == lastVerifiedAt &&
        other.label == label &&
        metadataEquals;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      memberId,
      email.toLowerCase(),
      source,
      isPrimary,
      isVerified,
      createdAt,
      updatedAt,
      lastVerifiedAt,
      label,
      const DeepCollectionEquality().hash(metadata),
    );
  }
}
