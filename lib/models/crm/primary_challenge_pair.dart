/// One (Young Democrat challenger, incumbent Democrat) pair running in the
/// same (office, district) seat. Surfaced by the `get_yd_primary_challengers()`
/// Postgres RPC and rendered on the Candidates page "YD Primarying Incumbent
/// Dem" view.
class PrimaryChallengePair {
  final String challengerId;
  final String challengerName;
  final String incumbentId;
  final String incumbentName;
  final String office;
  final String district;

  const PrimaryChallengePair({
    required this.challengerId,
    required this.challengerName,
    required this.incumbentId,
    required this.incumbentName,
    required this.office,
    required this.district,
  });

  factory PrimaryChallengePair.fromJson(Map<String, dynamic> json) {
    return PrimaryChallengePair(
      challengerId: json['challenger_id']?.toString() ?? '',
      challengerName: (json['challenger_name'] as String?) ?? '',
      incumbentId: json['incumbent_id']?.toString() ?? '',
      incumbentName: (json['incumbent_name'] as String?) ?? '',
      office: (json['office'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
    );
  }

  /// Human label for the seat — e.g. "State Representative District 68".
  String get seatLabel {
    if (district.isEmpty) return office;
    return '$office District $district';
  }
}
