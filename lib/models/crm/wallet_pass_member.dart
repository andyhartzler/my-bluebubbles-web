import 'package:bluebubbles/models/crm/member.dart';

/// Lightweight view model that represents a member with their wallet pass
/// metadata and notification registration state.
class WalletPassMember {
  const WalletPassMember({
    required this.cardId,
    required this.member,
    this.cardStatus,
    this.passSerial,
    this.passGeneratedAt,
    this.registrationCount = 0,
  });

  final String cardId;
  final Member member;
  final String? cardStatus;
  final String? passSerial;
  final DateTime? passGeneratedAt;
  final int registrationCount;

  bool get hasPass => (passSerial ?? '').isNotEmpty;

  bool get isActive => (cardStatus ?? '').toLowerCase() == 'active';

  bool get isRegistered => registrationCount > 0;

  WalletPassMember copyWith({
    String? cardId,
    Member? member,
    String? cardStatus,
    String? passSerial,
    DateTime? passGeneratedAt,
    int? registrationCount,
  }) {
    return WalletPassMember(
      cardId: cardId ?? this.cardId,
      member: member ?? this.member,
      cardStatus: cardStatus ?? this.cardStatus,
      passSerial: passSerial ?? this.passSerial,
      passGeneratedAt: passGeneratedAt ?? this.passGeneratedAt,
      registrationCount: registrationCount ?? this.registrationCount,
    );
  }

  factory WalletPassMember.fromJson(Map<String, dynamic> json) {
    final rawMember = json['members'] ?? json['member'];
    if (rawMember is! Map<String, dynamic>) {
      throw const FormatException('wallet pass member missing member record');
    }

    final passGeneratedAt = _parseDate(json['apple_wallet_generated_at']);
    final registrationCount = _parseRegistrationCount(json);

    return WalletPassMember(
      cardId: json['id']?.toString() ?? '',
      member: Member.fromJson(rawMember),
      cardStatus: json['card_status']?.toString(),
      passSerial: json['apple_wallet_pass_serial']?.toString(),
      passGeneratedAt: passGeneratedAt,
      registrationCount: registrationCount,
    );
  }

  static int _parseRegistrationCount(Map<String, dynamic> json) {
    final directCount = json['registration_count'];
    if (directCount is int) {
      return directCount;
    }

    final registrations = json['apple_wallet_registrations'] ??
        json['registrations'] ??
        json['notification_registrations'];

    if (registrations is List) {
      return registrations.length;
    }

    return 0;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
