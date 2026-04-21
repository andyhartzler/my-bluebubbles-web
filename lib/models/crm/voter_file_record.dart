import 'package:intl/intl.dart';

/// VoterFileRecord — maps a row from `public.mo_voter_file`.
///
/// The MO voter file only exposes `birth_year` (int) — there is no month/day
/// available. Any callers rendering a DOB must display the year only.
class VoterFileRecord {
  final String voterId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? suffix;
  final String? county;
  final String? residentialCity;
  final String? residentialZip5;
  final String? voterStatus; // Active / Inactive / Cancelled
  final DateTime? registrationDate;
  final int? birthYear;
  final String? congressionalDistrict;
  final String? legislativeDistrict;
  final String? senateDistrict;
  final String? precinct;
  final String? ward;
  final String? township;
  final List<VoterHistoryEntry> voterHistory;

  const VoterFileRecord({
    required this.voterId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.suffix,
    this.county,
    this.residentialCity,
    this.residentialZip5,
    this.voterStatus,
    this.registrationDate,
    this.birthYear,
    this.congressionalDistrict,
    this.legislativeDistrict,
    this.senateDistrict,
    this.precinct,
    this.ward,
    this.township,
    this.voterHistory = const [],
  });

  /// Approximate current age derived from birth year only.
  /// MO voter file does not publish month/day, so this is accurate to ±1 year.
  int? get estimatedAge =>
      birthYear != null ? DateTime.now().year - birthYear! : null;

  bool get isActive =>
      (voterStatus ?? '').toLowerCase() == 'active';

  int get electionCount => voterHistory.length;

  /// Full name assembled from parts, omitting nulls.
  String get fullName {
    final parts = <String>[
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName!,
      lastName,
      if (suffix != null && suffix!.isNotEmpty) suffix!,
    ];
    return parts.join(' ').trim();
  }

  /// Year-only DOB display — never synthesize a full date.
  String? get birthYearDisplay =>
      birthYear != null ? 'born $birthYear' : null;

  factory VoterFileRecord.fromJson(Map<String, dynamic> json) {
    // voter_history is a jsonb array of strings like "11/05/2024 General".
    // Sometimes Supabase deserializes it as List<dynamic>, sometimes already
    // typed; handle both.
    final rawHistory = json['voter_history'];
    final historyEntries = <VoterHistoryEntry>[];
    if (rawHistory is List) {
      for (final raw in rawHistory) {
        final s = raw?.toString();
        if (s == null || s.isEmpty) continue;
        final parsed = VoterHistoryEntry.tryParse(s);
        if (parsed != null) historyEntries.add(parsed);
      }
    }

    return VoterFileRecord(
      voterId: json['voter_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      middleName: json['middle_name'] as String?,
      lastName: json['last_name']?.toString() ?? '',
      suffix: json['suffix'] as String?,
      county: json['county'] as String?,
      residentialCity: json['residential_city'] as String?,
      residentialZip5: json['residential_zip5'] as String?,
      voterStatus: json['voter_status'] as String?,
      registrationDate: json['registration_date'] != null
          ? DateTime.tryParse(json['registration_date'].toString())
          : null,
      birthYear: (json['birth_year'] as num?)?.toInt(),
      congressionalDistrict: json['congressional_district'] as String?,
      legislativeDistrict: json['legislative_district'] as String?,
      senateDistrict: json['senate_district'] as String?,
      precinct: json['precinct'] as String?,
      ward: json['ward'] as String?,
      township: json['township'] as String?,
      voterHistory: historyEntries,
    );
  }
}

/// Single entry in `mo_voter_file.voter_history`.
/// Raw format is "MM/DD/YYYY ElectionType" e.g. "11/05/2024 General".
class VoterHistoryEntry {
  final DateTime date;
  final String electionType; // General, Primary, Municipal, etc.

  const VoterHistoryEntry({
    required this.date,
    required this.electionType,
  });

  /// Single-letter abbreviation for compact UI display.
  String get typeAbbreviation {
    final lower = electionType.toLowerCase();
    if (lower.contains('general')) return 'G';
    if (lower.contains('primary')) return 'P';
    if (lower.contains('municipal')) return 'M';
    if (lower.contains('special')) return 'S';
    if (lower.contains('runoff')) return 'R';
    return electionType.isNotEmpty ? electionType[0].toUpperCase() : '?';
  }

  /// Human-readable label, e.g. "11/05/2024 General".
  String get label {
    final f = DateFormat('MM/dd/yyyy');
    return '${f.format(date)} $electionType'.trim();
  }

  static VoterHistoryEntry? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    final datePart = parts.first;
    final typePart = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    try {
      final date = DateFormat('MM/dd/yyyy').parseStrict(datePart);
      return VoterHistoryEntry(date: date, electionType: typePart);
    } catch (_) {
      // Fallback — try generic ISO parse
      final iso = DateTime.tryParse(datePart);
      if (iso == null) return null;
      return VoterHistoryEntry(date: iso, electionType: typePart);
    }
  }
}
