import 'package:flutter/foundation.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Race identity + "other Democrats in this race" data for the endorsement
/// hub, read from two Postgres views:
///
///   * `public.v_endorsement_applicant_race`: one row per questionnaire with
///     the resolved race key. The office/district resolution (synonym folding,
///     digit extraction, spelled-out ordinals, SoS-outranks-self-report) lives
///     entirely in SQL so there is exactly one implementation of it; the
///     client never re-derives a race key from the free-text answers.
///   * `public.v_endorsement_race_field`: every 2026 Democrat sharing a race
///     with an applicant, deduplicated across import sources, with
///     `is_applicant` separating our respondents from the Democrats who never
///     applied. The client only fetches `is_applicant = false` here: the
///     applicants themselves already come through FormsService.
///
/// DEGRADATION CONTRACT: both loads THROW on failure instead of swallowing
/// (deliberately unlike EndorsementAiScoreRepository). SlateController catches
/// and flips `raceLoadFailed`, because the board must distinguish "this race
/// is uncontested" from "we could not find out". Those are different
/// statements, only one of them is safe to imply, and a silently-empty map
/// would collapse them into each other. Until the views are applied in
/// production the fetch fails, the flag flips, and every disclosure renders
/// "Race field unavailable" rather than a false "Only Democrat filed".
class EndorsementRaceRepository {
  static const _applicantView = 'v_endorsement_applicant_race';
  static const _fieldView = 'v_endorsement_race_field';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// Race identity for every applicant, keyed by submission id.
  Future<Map<String, RaceInfo>> loadApplicantRaces() async {
    final rows = await _supabase.client.from(_applicantView).select(
        'submission_id, candidate_id, display_name, office_code, '
        'district_num, race_key, race_label, office_source, '
        'office_self_report_conflict, filed_office_label, '
        'self_reported_office_label, self_reported_district_label');
    final out = <String, RaceInfo>{};
    for (final row in (rows as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final sid = m['submission_id']?.toString();
      if (sid == null || sid.isEmpty) continue;
      out[sid] = RaceInfo.fromRow(m);
    }
    return out;
  }

  /// The non-applicant Democrats, grouped by race key, each list already
  /// sorted alphabetically. The block that renders these never sorts, scores
  /// or ranks them any other way, so the UI cannot be read as a judgment.
  Future<Map<String, List<RaceFieldCandidate>>> loadRaceField() async {
    final rows = await _supabase.client
        .from(_fieldView)
        .select('race_key, office_code, name, incumbent, '
            'photo_url, campaign_website, ballotpedia_url, social_twitter, '
            'social_instagram, social_facebook, social_tiktok, social_bluesky, '
            'city, county, birth_year, total_raised, mec_committee_count, '
            'fec_receipts')
        .eq('is_applicant', false);
    final out = <String, List<RaceFieldCandidate>>{};
    for (final row in (rows as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final c = RaceFieldCandidate.fromRow(m);
      if (c.raceKey.isEmpty) continue;
      (out[c.raceKey] ??= <RaceFieldCandidate>[]).add(c);
    }
    for (final list in out.values) {
      list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }
}

/// One applicant's resolved race identity, immutable, held in a side map on
/// SlateController keyed by submission id (CandidateEntry itself stays
/// untouched, exactly the aiScores pattern).
@immutable
class RaceInfo {
  /// `US_HOUSE-4` style key; null for the county/statewide applicants whose
  /// contests have no reliable numeric district.
  final String? raceKey;

  /// `US_HOUSE` | `MO_SEN` | `MO_HOUSE`, or null for non-legislative offices.
  final String? officeCode;
  final int? districtNum;

  /// Human label: `Missouri House, District 39`, or the filed/self-reported
  /// office text for keyless rows.
  final String raceLabel;

  /// 'filed' when candidates.office decided the office, 'self_reported' when
  /// only the questionnaire answer was available. Provenance for copy that
  /// must say "per the SoS filing" rather than implying the candidate did.
  final String officeSource;

  /// True where the candidate's own office_sought answer contradicts her SoS
  /// filing (Bekki Brewer, Virginia Staabs, Shereka Barnes). The board sorts
  /// by the FILED race and shows a visible conflict pill; it never silently
  /// reassigns.
  final bool officeSelfReportConflict;

  /// Short vocabulary for the two halves of the conflict pill
  /// ("Filed: Senate 34 · Said: House 34").
  final String? filedOfficeLabel;
  final String? selfReportedOfficeLabel;
  final String? selfReportedDistrictLabel;

  /// Name coalesced in SQL from data->>'name' / data->>'full_name' /
  /// candidates.name. The last arm is what names Hope Tinker (587c32d7),
  /// whose submission carries no name at all.
  final String? displayName;

  const RaceInfo({
    required this.raceKey,
    required this.officeCode,
    required this.districtNum,
    required this.raceLabel,
    required this.officeSource,
    required this.officeSelfReportConflict,
    required this.filedOfficeLabel,
    required this.selfReportedOfficeLabel,
    required this.selfReportedDistrictLabel,
    required this.displayName,
  });

  factory RaceInfo.fromRow(Map<String, dynamic> m) {
    String? str(String k) {
      final v = m[k]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    return RaceInfo(
      raceKey: str('race_key'),
      officeCode: str('office_code'),
      districtNum: int.tryParse(m['district_num']?.toString() ?? ''),
      raceLabel: str('race_label') ?? '',
      officeSource: str('office_source') ?? 'self_reported',
      officeSelfReportConflict: m['office_self_report_conflict'] == true,
      filedOfficeLabel: str('filed_office_label'),
      selfReportedOfficeLabel: str('self_reported_office_label'),
      selfReportedDistrictLabel: str('self_reported_district_label'),
      displayName: str('display_name'),
    );
  }

  /// `Missouri House 39` style compact label for the race cap (the view's
  /// label spells out ", District ").
  String get shortLabel => raceLabel.replaceFirst(', District ', ' ');
}

/// One filed Democrat who never answered the questionnaire. Fields chosen
/// strictly by measured fill rate on the real 32-row set (see BUILD-SPEC C2);
/// filing_status / party_confidence are deliberately absent because both are
/// the constant 'filed' on every row and carry zero information.
@immutable
class RaceFieldCandidate {
  final String raceKey;
  final String officeCode;

  /// Rendered as stored. FEC-sourced rows (the Summers CD2 and Province CD4
  /// supplements) arrive as "LAST, FIRST MIDDLE MR." and stay that way:
  /// guessing at a person's preferred name form is how you print something
  /// wrong next to their face.
  final String name;

  /// True on exactly one row today (Wesley Bell). Rendered as a plain factual
  /// chip when true and nothing otherwise; a badge that appears once is not a
  /// visual system.
  final bool incumbent;
  final String? photoUrl;

  /// Link-bearing fields below are SANITIZED AT PARSE TIME by
  /// [sanitizeWebLink] / [sanitizeSocialLink]: a non-null value here is
  /// guaranteed to be URL-shaped or an '@handle', never questionnaire prose.
  /// See those functions for the measured junk this defends against.
  final String? campaignWebsite;
  final String? ballotpediaUrl;
  final String? socialTwitter;
  final String? socialInstagram;
  final String? socialFacebook;
  final String? socialTiktok;
  final String? socialBluesky;
  final String? city;
  final String? county;

  /// Year only. date_of_birth in this data carries a literal 07-01 month-day
  /// placeholder on 352 of 354 voter-file rows and must never render as a
  /// birthday; the UI computes an approximate age band from this.
  final int? birthYear;

  /// MEC-only money. Wrong by an order of magnitude for federal candidates
  /// and fabricated by fuzzy over-linking when mecCommitteeCount is large;
  /// [gatedMoneyLabel] is the only sanctioned way to render it.
  final num? totalRaised;
  final int mecCommitteeCount;

  /// FEC cycle-2026 receipts via the principal committee, the only correct
  /// money figure for a federal race.
  final num? fecReceipts;

  const RaceFieldCandidate({
    required this.raceKey,
    required this.officeCode,
    required this.name,
    required this.incumbent,
    required this.photoUrl,
    required this.campaignWebsite,
    required this.ballotpediaUrl,
    required this.socialTwitter,
    required this.socialInstagram,
    required this.socialFacebook,
    required this.socialTiktok,
    required this.socialBluesky,
    required this.city,
    required this.county,
    required this.birthYear,
    required this.totalRaised,
    required this.mecCommitteeCount,
    required this.fecReceipts,
  });

  factory RaceFieldCandidate.fromRow(Map<String, dynamic> m) {
    String? str(String k) {
      final v = m[k]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    num? number(String k) {
      final v = m[k];
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '');
    }

    return RaceFieldCandidate(
      raceKey: str('race_key') ?? '',
      officeCode: str('office_code') ?? '',
      name: str('name') ?? 'Name not provided',
      incumbent: m['incumbent'] == true,
      photoUrl: str('photo_url'),
      campaignWebsite: sanitizeWebLink(str('campaign_website')),
      ballotpediaUrl: sanitizeWebLink(str('ballotpedia_url')),
      socialTwitter: sanitizeSocialLink(str('social_twitter')),
      socialInstagram: sanitizeSocialLink(str('social_instagram')),
      socialFacebook: sanitizeSocialLink(str('social_facebook')),
      socialTiktok: sanitizeSocialLink(str('social_tiktok')),
      socialBluesky: sanitizeSocialLink(str('social_bluesky')),
      city: str('city'),
      county: str('county'),
      birthYear: int.tryParse(m['birth_year']?.toString() ?? ''),
      totalRaised: number('total_raised'),
      mecCommitteeCount:
          int.tryParse(m['mec_committee_count']?.toString() ?? '') ?? 0,
      fecReceipts: number('fec_receipts'),
    );
  }

  /// Approximate age from the year-only DOB: "about 41", or null.
  String? get ageBand {
    final y = birthYear;
    if (y == null) return null;
    final age = DateTime.now().year - y;
    if (age < 18 || age > 110) return null; // junk year, say nothing
    return 'about $age';
  }

  /// THE MONEY RULE (BUILD-SPEC C2). Federal race: FEC receipts only,
  /// labelled as such. State race: MEC total only when the committee linkage
  /// is sane (<= 3 committees; 30 fuzzy-linked committees fabricated a total
  /// for "G Rick"). Otherwise NOTHING, not zero: a wrong number next to a
  /// name on a meeting-night board is worse than an absent one.
  String? get gatedMoneyLabel {
    if (officeCode == 'US_HOUSE') {
      final r = fecReceipts;
      if (r == null || r <= 0) return null;
      return 'Raised (FEC, cycle to date): ${formatApproxMoney(r)}';
    }
    final t = totalRaised;
    if (t == null || t <= 0 || mecCommitteeCount > 3) return null;
    return 'Raised (MEC): ${formatApproxMoney(t)}';
  }
}

// ===========================================================================
// Link hygiene for the unvetted-Democrat rows.
//
// The social_* and campaign_website columns on public.candidates are
// questionnaire prose, not links. Measured against the live table on
// 2026-07-25, restricted to the non-applicant rows that actually populate
// v_endorsement_race_field, the junk is real: Charles Slider carries
// tw 'No', ig 'Yes', tt 'Yes', bs 'None', web 'None' and fb 'Charles Slider';
// Sidney Clark carries 'N/A' on four networks and web 'in progress';
// Shawna Ackerson ig 'Ackersonformussouri' and fb 'Shawna Ackerson for
// Missouri'; John Leykamp ig/fb 'John Leykamp for Missouri Senate District
// 18'. The wider 2026 Democrat pool adds emails in link columns
// ('Arellanesformissouri@gmail.com'), invisible bidi characters wrapping a
// real handle, and the literal placeholder '@candidate'.
//
// RULES, applied at parse time so junk never becomes a tappable button:
//   * keep http(s) URLs with a dotted host and no userinfo;
//   * keep '@handle' (letters, digits, dot, underscore, hyphen; no spaces);
//   * keep bare dotted domains ('VoteTori.com', 'facebook.com/druryformo');
//   * drop everything else: yes/no/none/n-a style refusals, anything with
//     whitespace (page titles, human names, sentences), emails, and the
//     '@candidate' placeholder.
// A link must never be offered for a value that is not a handle or a URL:
// 'Yes' rendered as an icon asserts the person has that account, and
// https://x.com/<instagram-handle> opens a stranger's profile next to an
// unvetted candidate's face.
//
// The same rules are mirrored in SQL (013_endorsement_race_field_link_hygiene
// .sql), but this client-side pass is authoritative because the view may not
// be updated when the app ships.
// ===========================================================================

/// Which network's icon was tapped. Profile-URL resolution is PER NETWORK:
/// an '@' handle stored in the Instagram column must never be routed to
/// x.com, where the same handle can belong to someone else entirely.
enum SocialNetwork { twitter, instagram, facebook, tiktok, bluesky }

/// Zero-width and bidi-control characters seen wrapping real handles in the
/// live data (a stored Bluesky handle arrives as U+202A '@hutch4mo.bsky.
/// social' U+202C, which would otherwise fail the '@' prefix check).
final RegExp _invisibleChars =
    RegExp('[\\u200B-\\u200F\\u202A-\\u202E\\u2060\\uFEFF]');

/// Refusal / placeholder tokens observed verbatim in the live columns.
const Set<String> _junkTokens = {
  'yes', 'no', 'none', 'na', 'n/a', 'n.a.', 'tbd',
  'unknown', 'pending', 'candidate',
};

final RegExp _handleShape = RegExp(r'^@[A-Za-z0-9._-]+$');
final RegExp _bareDomainShape =
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(/\S*)?$');
final RegExp _emailShape = RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$');

String? _normalizeLink(String? raw) {
  if (raw == null) return null;
  final v = raw.replaceAll(_invisibleChars, '').trim();
  if (v.isEmpty) return null;
  // Whitespace inside the value means prose, a page title, or a bare human
  // name. None of those are launchable, and a human name rendered as a link
  // is a wrong-person risk.
  if (v.contains(RegExp(r'\s'))) return null;
  if (_junkTokens.contains(v.toLowerCase())) return null;
  if (_emailShape.hasMatch(v)) return null;
  return v;
}

bool _isHttpUrl(String v) {
  final lower = v.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return false;
  }
  final uri = Uri.tryParse(v);
  // A dotted host and no userinfo: 'https://user@gmail.com' style values are
  // emails in disguise and navigate to the mail host, not a profile.
  return uri != null && uri.host.contains('.') && uri.userInfo.isEmpty;
}

/// Sanitize a social column value: returns an http(s) URL, an '@handle', or a
/// bare dotted domain, else null. Null means "offer no link at all".
String? sanitizeSocialLink(String? raw) {
  final v = _normalizeLink(raw);
  if (v == null) return null;
  if (_isHttpUrl(v)) return v;
  if (_handleShape.hasMatch(v)) {
    // '@candidate' is a live placeholder value in the table.
    if (_junkTokens.contains(v.substring(1).toLowerCase())) return null;
    return v;
  }
  if (_bareDomainShape.hasMatch(v)) return v;
  return null;
}

/// Sanitize a website / Ballotpedia value: same rules minus the handle form,
/// because '@something' is not a website.
String? sanitizeWebLink(String? raw) {
  final v = _normalizeLink(raw);
  if (v == null) return null;
  if (_isHttpUrl(v)) return v;
  if (_bareDomainShape.hasMatch(v)) return v;
  return null;
}

/// Resolve a SANITIZED social value to a launchable profile URL for the
/// network whose icon was tapped, or null when no safe resolution exists
/// (the icon is then not rendered at all: a dead button is a false
/// statement that the account exists).
String? socialProfileUrl(SocialNetwork network, String value) {
  if (network == SocialNetwork.bluesky) return _blueskyUrl(value);
  if (_isHttpUrl(value)) return value; // launch exactly what was recorded
  if (value.startsWith('@')) {
    final h = value.substring(1);
    return switch (network) {
      SocialNetwork.twitter => 'https://x.com/$h',
      SocialNetwork.instagram => 'https://instagram.com/$h',
      SocialNetwork.facebook => 'https://facebook.com/$h',
      SocialNetwork.tiktok => 'https://www.tiktok.com/@$h',
      SocialNetwork.bluesky => _blueskyUrl(value), // unreachable, exhaustive
    };
  }
  return 'https://$value'; // bare domain, e.g. 'facebook.com/druryformo'
}

/// Bluesky is the one network where a bare domain is NOT a website: a stored
/// handle like 'mcneeceformissouri.bsky.social' does not resolve in a
/// browser and must go through bsky.app/profile/. Handles without a dot get
/// the default '.bsky.social' suffix ('@dan4mo' is live data). Anything that
/// is neither a bsky.app URL, a handle, nor a *.bsky.social domain returns
/// null rather than a guess.
String? _blueskyUrl(String value) {
  if (_isHttpUrl(value)) {
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    return (host == 'bsky.app' || host.endsWith('.bsky.social'))
        ? value
        : null;
  }
  var h = value.startsWith('@') ? value.substring(1) : value;
  h = h.toLowerCase();
  if (h.endsWith('.bsky.social')) return 'https://bsky.app/profile/$h';
  if (!h.contains('.')) return 'https://bsky.app/profile/$h.bsky.social';
  return null;
}

/// Resolve a SANITIZED website / Ballotpedia value to a launchable URL.
String webLinkUrl(String value) =>
    _isHttpUrl(value) ? value : 'https://$value';

/// Compact money formatting for glance lines: $3.6M / $352K / $4,500.
String formatApproxMoney(num v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return '\$${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
  }
  if (v >= 10000) return '\$${(v / 1000).round()}K';
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '\$$buf';
}
