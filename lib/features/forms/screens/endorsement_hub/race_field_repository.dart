import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

// Race identity + "other Democrats in this race" data for the endorsement
// hub, read from two Postgres views:
//
//   * `public.v_endorsement_applicant_race`: one row per questionnaire with
//     the resolved race key. The office/district resolution (synonym folding,
//     digit extraction, spelled-out ordinals, SoS-outranks-self-report) lives
//     entirely in SQL so there is exactly one implementation of it; the
//     client never re-derives a race key from the free-text answers.
//   * `public.v_endorsement_race_field`: THE WHOLE 2026 Democratic legislative
//     field, not just the races we have an applicant in, deduplicated across
//     import sources. Two booleans slice it, and the client only ever fetches
//     `is_applicant = false`, because the applicants themselves already come
//     through FormsService:
//
//       is_applicant=false, race_has_applicant=true   -> THE TOGGLE payload.
//           The other filed Democrats in a race one of our applicants is in.
//           Hangs off that applicant's ballot row. 30 rows / 14 races.
//       is_applicant=false, race_has_applicant=false  -> THE BOTTOM SECTION.
//           Races where NOBODY returned our questionnaire. There is no
//           applicant row to hang these off, so they get their own collapsed
//           disclosure per race, rendered below everyone we heard from.
//           146 rows / 125 races.
//       is_applicant=true                             -> already on the ballot.
//           Never rendered from here.
//
// RACE KEY. Both views key on the canonical
// `moyd_office_code(office) || '-' || coalesce(district_num,
// digits(district))`, scoped to 2026 / primary / filed / Democrat. Measured
// on 2026-07-28 that resolves all 253 filed Democrat rows across the six live
// office spellings ('State Representative', 'State representative', 'State
// House of Representatives', 'State Senator', 'State Senate',
// 'U.S. Representative') into 243 distinct people in 184 races: US_HOUSE 8
// races, MO_SEN 18, MO_HOUSE 158. All three offices the chair named are
// covered, and none of that folding happens on this side of the wire.
//
// SHAPE DRIFT IS SURVIVABLE, ON PURPOSE. `race_label` and `race_has_applicant`
// arrive with 182_endorsement_race_field_full_field.sql, and this code ships
// BEFORE that migration is applied. A build that selected them unconditionally
// would take a 42703 between deploy and migration and lose the toggles that
// work today. So [_fetchField] tries the full column list, and on a
// column-level error ONLY it retries the pre-182 list and reports
// [RaceDataSnapshot.fullFieldAvailable] = false. The toggle keeps working; the
// bottom section is absent rather than wrongly rendered as empty. A missing
// VIEW is still `schemaMissing`, because no column list rescues that.
//
// DEGRADATION CONTRACT. There are two ways in, differing only in how they
// report failure:
//
//   * [EndorsementRaceRepository.loadRaceData] NEVER throws. It returns a
//     [RaceDataSnapshot] whose [RaceDataSnapshot.status] separates "the views
//     are not applied yet" from "the fetch failed" from "it worked and this
//     race really has nobody else in it". This is the API to use.
//   * [EndorsementRaceRepository.loadApplicantRaces] and
//     [EndorsementRaceRepository.loadRaceField] still THROW, because
//     SlateController catches them and flips `raceLoadFailed`, and that flag
//     is what stops the board turning an empty map into the sentence "only
//     Democrat filed in this race". They are unchanged so that contract holds
//     until the controller is rewired to the snapshot.
//
// Either way, an empty field must never be rendered as a claim. Read the
// status (or the flag) before rendering a sentence: "we did not find out" and
// "there is nobody" are different statements and only one of them is safe to
// print next to a real person's name.

/// How the last race fetch ended. The board MUST branch on this rather than
/// on "is the map empty", because an empty map has three different meanings
/// and only one of them is safe to say out loud.
enum RaceDataStatus {
  /// Both views answered. An empty list for a race now means, truthfully,
  /// "we read the Secretary of State filing list and nobody else is on it".
  ok,

  /// The views are not in the database yet (or a column was renamed under us).
  /// 182_endorsement_race_field_full_field.sql has not been applied. Not an
  /// outage, not a permissions problem, and not something a retry fixes.
  ///
  /// NOT the same as a view that exists but is missing only the two columns
  /// 182 appends: that is caught in [EndorsementRaceRepository] and reported as
  /// `ok` with `fullFieldAvailable = false`, because the toggle still works.
  schemaMissing,

  /// Transport, timeout, RLS rejection, anything else. A retry may help.
  failed,
}

/// Everything the roster needs about races, fetched once, never throwing.
///
/// THE HONESTY CONTRACT. `fieldByRace` is empty in all three failure states
/// and in the (common) happy case where nobody else filed. [status] is the
/// only thing that separates them, so any surface that renders this must read
/// [status] before it renders a sentence. Saying "only Democrat filed in this
/// race" when the truth is "the view is missing" is a false statement printed
/// next to a real person's name on a voting night.
@immutable
class RaceDataSnapshot {
  /// Resolved race identity per questionnaire, keyed by submission id.
  final Map<String, RaceInfo> applicantRaces;

  /// Non-applicant filed Democrats, keyed by race key, each list already
  /// sorted alphabetically. The order is alphabetical and nothing else: no
  /// score, no money rank, no incumbency first. We have not vetted these
  /// people and any ordering that looked like a ranking would imply we had.
  ///
  /// This holds EVERY non-applicant, both the 30 in races we have an applicant
  /// in and the 146 in races we do not. Looking up an applicant's race key can
  /// only ever return the first kind, because `race_has_applicant` is a
  /// property of the whole race: a race is either entirely toggle rows or
  /// entirely bottom-section rows, never mixed. The 125 bottom-section keys are
  /// disjoint additions that [othersInRace] will never be asked for.
  final Map<String, List<RaceFieldCandidate>> fieldByRace;

  /// THE BOTTOM SECTION. One entry per race where nobody returned our
  /// questionnaire, already ordered (see [OrphanRace]). Empty when
  /// [fullFieldAvailable] is false, which is NOT the same statement as "every
  /// race has an applicant" and must not be rendered as one.
  final List<OrphanRace> racesWithoutApplicants;

  /// False when the view answered but predates
  /// 182_endorsement_race_field_full_field.sql, so it carries neither
  /// `race_label` nor `race_has_applicant` and cannot describe a race we have
  /// no applicant in. [fieldByRace] is still trustworthy in that state;
  /// [racesWithoutApplicants] is empty for lack of data, not for lack of
  /// races, so the bottom section must be OMITTED rather than shown empty.
  final bool fullFieldAvailable;

  final RaceDataStatus status;

  /// True when a fetch came back at exactly its row cap, so the payload may
  /// have been silently truncated by PostgREST. Never true at today's volumes
  /// (see [kApplicantRaceRowCap]); it exists so that if the data grows past
  /// the cap the board finds out instead of quietly showing a short list.
  final bool possiblyTruncated;

  /// Raw error text for the debug console. Never rendered to an exec.
  final String? diagnostic;

  const RaceDataSnapshot({
    required this.applicantRaces,
    required this.fieldByRace,
    required this.status,
    this.racesWithoutApplicants = const [],
    this.fullFieldAvailable = true,
    this.possiblyTruncated = false,
    this.diagnostic,
  });

  /// The degraded snapshot: no data, and [status] says why.
  const RaceDataSnapshot.unavailable(this.status, {this.diagnostic})
      : applicantRaces = const {},
        fieldByRace = const {},
        racesWithoutApplicants = const [],
        fullFieldAvailable = false,
        possiblyTruncated = false;

  /// True only when both views answered. The single flag every renderer
  /// should gate its wording on.
  bool get available => status == RaceDataStatus.ok;

  /// Race identity for one questionnaire, or null when the applicant filed
  /// for an office with no numbered-district filing list (County Clerk,
  /// County Executive, County Legislator, State Auditor: 5 of 77 today).
  RaceInfo? raceInfoFor(String submissionId) => applicantRaces[submissionId];

  /// The other filed Democrats in [raceKey], alphabetical. Empty for a null
  /// key and for the applicants who genuinely have no other Democrat on the
  /// filing list: 14 of the 59 races we have an applicant in contain a
  /// non-respondent, so the other 45 races correctly get an empty list.
  /// Empty is only ever "nobody else filed" when [available] is true.
  List<RaceFieldCandidate> othersInRace(String? raceKey) =>
      raceKey == null ? const [] : (fieldByRace[raceKey] ?? const []);

  /// How many other Democrats [raceKey] has. Safe to put on a collapsed
  /// toggle: it is a count of filings, not a judgment about anybody.
  int otherCountIn(String? raceKey) => othersInRace(raceKey).length;

  /// True only when it is safe to render the bottom section at all: the views
  /// answered AND they are new enough to describe races we have no applicant
  /// in. The section may still legitimately be empty when this is true, which
  /// would mean every race in the state has an applicant. It does not today.
  bool get bottomSectionRenderable =>
      status == RaceDataStatus.ok && fullFieldAvailable;

  /// Total people in the bottom section, across all its races. 146 today.
  int get racesWithoutApplicantsPeopleCount => racesWithoutApplicants
      .fold<int>(0, (sum, race) => sum + race.candidates.length);
}

/// One race where NOBODY returned our questionnaire, and the Democrats filed
/// in it.
///
/// This is the chair's added requirement, and it is a different shape from the
/// toggle: there is no applicant here, so there is no row to hang a disclosure
/// off and no "us" for these people to be OTHER than. Copy that says "N other
/// Democrats" is wrong on this object. They are simply the Democrats who filed
/// in this district, and we have heard from none of them.
///
/// SAME HONESTY RULE AS THE TOGGLE. Nobody in [candidates] has been vetted,
/// scored, contacted or judged by MOYD. [candidates] is sorted alphabetically
/// and by nothing else.
@immutable
class OrphanRace {
  /// `MO_HOUSE-42` style canonical key, disjoint from every applicant race key.
  final String raceKey;

  /// `US_HOUSE` | `MO_SEN` | `MO_HOUSE`.
  final String officeCode;

  final int? districtNum;

  /// 'Missouri House, District 42', built in SQL so there is one spelling of
  /// it. Falls back to a client-side reconstruction only if the view ever
  /// returns null, which it does not today (0 of 245 rows).
  final String raceLabel;

  /// The filed Democrats in this race, alphabetical. Never empty: a race only
  /// exists in this list because somebody filed in it. 1 person in 109 of the
  /// 125 races, 2 in 13, 3 in 1, 4 in 2.
  final List<RaceFieldCandidate> candidates;

  const OrphanRace({
    required this.raceKey,
    required this.officeCode,
    required this.districtNum,
    required this.raceLabel,
    required this.candidates,
  });

  /// Never-null label for a header. Reconstructs from the office code and
  /// district if `race_label` was null, and falls back to the raw key rather
  /// than inventing an office name.
  String get displayLabel {
    if (raceLabel.isNotEmpty) return raceLabel;
    final d = districtNum;
    if (d == null) return raceKey;
    return switch (officeCode) {
      'US_HOUSE' => 'U.S. House, District $d',
      'MO_SEN' => 'Missouri Senate, District $d',
      'MO_HOUSE' => 'Missouri House, District $d',
      _ => raceKey,
    };
  }

  /// Sort rank for the office. Federal, then state senate, then state house.
  ///
  /// This is a legislative-chamber ordering, the same one a ballot uses, and
  /// combined with ascending district number it is purely positional. It is
  /// deliberately NOT by size, money, or how interesting a race looks, because
  /// any of those would read as MOYD ranking races it has not looked at.
  int get _officeRank => switch (officeCode) {
        'US_HOUSE' => 0,
        'MO_SEN' => 1,
        'MO_HOUSE' => 2,
        _ => 3,
      };

  /// Chamber, then district number ascending, then key. Total and stable.
  static int compare(OrphanRace a, OrphanRace b) {
    final o = a._officeRank.compareTo(b._officeRank);
    if (o != 0) return o;
    final d = (a.districtNum ?? 1 << 30).compareTo(b.districtNum ?? 1 << 30);
    if (d != 0) return d;
    return a.raceKey.compareTo(b.raceKey);
  }
}

/// The two halves of one `is_applicant = false` fetch, split in Dart so the
/// bottom section costs no extra round trip.
@immutable
class RaceFieldSplit {
  /// Every non-applicant, keyed by race. See [RaceDataSnapshot.fieldByRace].
  final Map<String, List<RaceFieldCandidate>> fieldByRace;

  /// Only the races with no applicant, ordered by [OrphanRace.compare].
  final List<OrphanRace> racesWithoutApplicants;

  /// False when the view predates 182 and could not report `race_label` /
  /// `race_has_applicant`.
  final bool fullFieldAvailable;

  const RaceFieldSplit({
    required this.fieldByRace,
    required this.racesWithoutApplicants,
    required this.fullFieldAvailable,
  });

  static const empty = RaceFieldSplit(
    fieldByRace: {},
    racesWithoutApplicants: [],
    fullFieldAvailable: false,
  );
}

/// Row caps for the two fetches.
///
/// PostgREST caps EVERY response at the project's `db-max-rows` and does it
/// SILENTLY: HTTP 200, no error field, just fewer rows. The default is 1000.
/// Neither fetch here is close, but neither is allowed to rely on that:
///
///   * [kApplicantRaceRowCap] bounds `v_endorsement_applicant_race`, one row
///     per endorsement questionnaire. 77 rows on 2026-07-28. The natural
///     ceiling is the number of submissions to one form in one cycle.
///   * [kRaceFieldRowCap] bounds `v_endorsement_race_field` filtered to
///     `is_applicant = false`. MEASURED 2026-07-28 by running the view body
///     against production as a read-only SELECT: **176 rows**, being 30 toggle
///     rows across 14 races plus 146 bottom-section rows across 125 races. The
///     view in full is 245 rows (176 + 69 applicants), and 245 is the entire
///     2026 Democratic legislative universe: 243 people from
///     `public.candidates` after the same-race person merge, plus the 2
///     FEC-only federal filers. There is no larger number to fetch.
///
/// THE FILTER IS WHAT MAKES THIS SAFE, not the cap. `public.candidates` is
/// 2753 rows and a bare select on it would be silently cut to 1000. Neither
/// fetch here touches it. The view itself does the filtering in SQL
/// (party ILIKE 'democrat%', election_year 2026, election_type 'primary',
/// filing_status 'filed', and an office that folds to one of the three
/// legislative codes), which is what turns 2753 into 245, and `.eq(
/// 'is_applicant', false)` turns 245 into 176.
///
/// 500 therefore sits at 2.8x the live value and half the PostgREST cap, so
/// hitting it is a real signal rather than routine, and `possiblyTruncated`
/// makes even that loud. The value is also close to frozen for this cycle:
/// every row carries `filing_status = 'filed'` and Missouri candidate filing
/// for 2026 has closed, so the field can shrink through withdrawals but has no
/// ordinary way to grow.
const int kApplicantRaceRowCap = 500;
const int kRaceFieldRowCap = 500;

class EndorsementRaceRepository {
  static const _applicantView = 'v_endorsement_applicant_race';
  static const _fieldView = 'v_endorsement_race_field';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// Load both views in parallel and NEVER throw.
  ///
  /// This is the API to use. On any failure it returns a snapshot whose
  /// [RaceDataSnapshot.status] explains what happened and whose maps are
  /// empty, so the caller degrades to "we could not find out" instead of
  /// crashing or, worse, silently asserting that a race is uncontested.
  ///
  /// The `schemaMissing` branch exists specifically because this code ships
  /// before 182_endorsement_race_field_full_field.sql is applied: in that
  /// window the views may not exist at all, and it must render an honest
  /// "unavailable", not an exception and not a claim. The narrower case where
  /// the views DO exist but predate 182 is handled one level down, in
  /// [_fetchField], and does not degrade the toggle.
  Future<RaceDataSnapshot> loadRaceData({Duration? timeout}) async {
    // Started before the first await, so the two round trips overlap. The old
    // call path awaited them one after the other, which cost a full extra RTT
    // on venue wifi for no reason.
    final applicantFuture = _fetchApplicantRaces();
    final fieldFuture = _fetchField();
    // If the first await throws we return without ever listening to the
    // second. Register a no-op handler now so that future cannot surface as
    // an uncaught async error later.
    unawaited(applicantFuture.then((_) {}, onError: (Object _) {}));
    unawaited(fieldFuture.then((_) {}, onError: (Object _) {}));
    try {
      final applicants = await applicantFuture.timeoutOrNull(timeout);
      final field = await fieldFuture.timeoutOrNull(timeout);
      return RaceDataSnapshot(
        applicantRaces: applicants.value,
        fieldByRace: field.value.fieldByRace,
        racesWithoutApplicants: field.value.racesWithoutApplicants,
        fullFieldAvailable: field.value.fullFieldAvailable,
        status: RaceDataStatus.ok,
        possiblyTruncated: applicants.truncated || field.truncated,
      );
    } catch (e) {
      final status = _isSchemaMissing(e)
          ? RaceDataStatus.schemaMissing
          : RaceDataStatus.failed;
      debugPrint('EndorsementRaceRepository.loadRaceData $status: $e');
      return RaceDataSnapshot.unavailable(status, diagnostic: '$e');
    }
  }

  /// Race identity for every applicant, keyed by submission id.
  ///
  /// THROWS on failure, deliberately. SlateController wraps this in a try that
  /// flips `raceLoadFailed`, and the board reads that flag to distinguish
  /// "this race is uncontested" from "we could not find out". Prefer
  /// [loadRaceData], which draws the same distinction without an exception.
  Future<Map<String, RaceInfo>> loadApplicantRaces() async =>
      (await _fetchApplicantRaces()).value;

  /// The non-applicant Democrats, grouped by race key, each list already
  /// sorted alphabetically. The block that renders these never sorts, scores
  /// or ranks them any other way, so the UI cannot be read as a judgment.
  ///
  /// THROWS on failure; see [loadApplicantRaces].
  Future<Map<String, List<RaceFieldCandidate>>> loadRaceField() async =>
      (await _fetchField()).value.fieldByRace;

  /// Both halves of the field from ONE round trip: the toggle payload keyed by
  /// race, and the bottom-section races we heard nothing from.
  ///
  /// Prefer this over [loadRaceField] when you need the bottom section, which
  /// is everywhere the roster is built. Calling [loadRaceField] and then a
  /// separate orphan fetch would be two queries for one result set.
  ///
  /// THROWS on failure; see [loadApplicantRaces]. The column-level fallback for
  /// a pre-182 view is handled INSIDE this call and is not a failure: it comes
  /// back with `fullFieldAvailable = false` and an empty
  /// `racesWithoutApplicants`, which the caller must render as "no bottom
  /// section" and never as "no races without applicants".
  Future<RaceFieldSplit> loadRaceFieldSplit() async =>
      (await _fetchField()).value;

  Future<_Fetched<Map<String, RaceInfo>>> _fetchApplicantRaces() async {
    final rows = await _supabase.client
        .from(_applicantView)
        .select('submission_id, candidate_id, display_name, office_code, '
            'district_num, race_key, race_label, office_source, '
            'office_self_report_conflict, filed_office_label, '
            'self_reported_office_label, self_reported_district_label')
        // Ordered so that a truncation, if the cap is ever hit, is at least
        // deterministic instead of whatever the planner happened to emit.
        .order('submission_id', ascending: true)
        .limit(kApplicantRaceRowCap) as List;
    final out = <String, RaceInfo>{};
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map);
      final sid = m['submission_id']?.toString();
      if (sid == null || sid.isEmpty) continue;
      out[sid] = RaceInfo.fromRow(m);
    }
    return _Fetched(out, rows.length >= kApplicantRaceRowCap);
  }

  /// Columns present on `v_endorsement_race_field` BEFORE 182.
  ///
  /// Every one was chosen by measured fill rate over the 174 candidates-sourced
  /// non-applicants (2026-07-28, counted AFTER the SQL link sanitizers so these
  /// are usable-link rates, not raw-string rates): ballotpedia_url 167 (96%),
  /// filing_date 170 (98%), birth_year 170 (98%), any usable link at all 168
  /// (97%), city 164 (94%), county 160 (92%), photo_url 123 (71%),
  /// social_facebook 73 (42%), campaign_website 67 (39%), occupation 58 (33%),
  /// social_twitter 38 (22%), incumbent true on 27 (16%), social_instagram 27,
  /// social_tiktok 19, social_bluesky 9, money passing `gatedMoneyLabel` 139
  /// (80%).
  ///
  /// `campaign_committee` is NOT selected: it is null on all 174, so it would
  /// cost bytes on every row and render on none. `incumbent_party` is not
  /// selected either (populated on 1 of 174). `party_confidence` and
  /// `filing_status` are not selected because they are the same constant on
  /// every row and carry no information.
  static const _fieldColumnsLegacy = 'race_key, office_code, '
      'race_district_num, name, incumbent, '
      'photo_url, campaign_website, ballotpedia_url, social_twitter, '
      'social_instagram, social_facebook, social_tiktok, social_bluesky, '
      'city, county, birth_year, occupation, filing_date, '
      'total_raised, mec_committee_count, fec_receipts';

  /// The same list plus the two columns 182 appends. `race_has_applicant` is
  /// what splits the toggle from the bottom section; `race_label` is the
  /// bottom section's header and exists so the office/district wording has one
  /// spelling, in SQL, rather than one per surface.
  static const _fieldColumnsFull =
      '$_fieldColumnsLegacy, race_label, race_has_applicant';

  Future<_Fetched<RaceFieldSplit>> _fetchField() async {
    try {
      return _parseField(
        await _selectField(_fieldColumnsFull),
        fullFieldAvailable: true,
      );
    } on PostgrestException catch (e) {
      // A MISSING COLUMN is recoverable; a missing view is not. Between the
      // deploy of this build and the apply of 182 the view exists but is 31
      // columns wide, and losing the working toggles for that window would be
      // a self-inflicted outage. Anything that is not specifically "this
      // column is not there" rethrows so loadRaceData can classify it.
      if (!_isMissingColumn(e)) rethrow;
      debugPrint('EndorsementRaceRepository: v_endorsement_race_field predates '
          '182 (${e.code} ${e.message}); falling back to the toggle-only '
          'column set. The bottom section will be omitted, NOT shown empty.');
      return _parseField(
        await _selectField(_fieldColumnsLegacy),
        fullFieldAvailable: false,
      );
    }
  }

  Future<List<dynamic>> _selectField(String columns) async =>
      await _supabase.client
          .from(_fieldView)
          .select(columns)
          // The applicants already come through FormsService. This filter is
          // also what keeps the payload at 176 rows instead of 245.
          .eq('is_applicant', false)
          // Alphabetical, and alphabetical only. Nobody in this payload has
          // been vetted by anyone, so any other order would read as a ranking
          // we have not earned. It also makes a truncation deterministic.
          .order('name', ascending: true)
          .limit(kRaceFieldRowCap) as List;

  _Fetched<RaceFieldSplit> _parseField(
    List<dynamic> rows, {
    required bool fullFieldAvailable,
  }) {
    final byRace = <String, List<RaceFieldCandidate>>{};
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map);
      final c = RaceFieldCandidate.fromRow(m);
      if (c.raceKey.isEmpty) continue;
      (byRace[c.raceKey] ??= <RaceFieldCandidate>[]).add(c);
    }
    for (final list in byRace.values) {
      list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    // The bottom section. `race_has_applicant` is a property of the RACE, so
    // every row in a given race agrees on it; reading it off the first row is
    // not a sample, it is the value. When the column was not selected at all
    // it parses to false everywhere, which is why the orphan list is built
    // only when fullFieldAvailable, rather than confidently declaring all 14
    // toggle races to be applicant-free.
    final orphans = <OrphanRace>[];
    if (fullFieldAvailable) {
      for (final entry in byRace.entries) {
        final first = entry.value.first;
        if (first.raceHasApplicant) continue;
        orphans.add(OrphanRace(
          raceKey: entry.key,
          officeCode: first.officeCode,
          districtNum: first.districtNum,
          raceLabel: first.raceLabel ?? '',
          candidates: List.unmodifiable(entry.value),
        ));
      }
      orphans.sort(OrphanRace.compare);
    }

    return _Fetched(
      RaceFieldSplit(
        fieldByRace: byRace,
        racesWithoutApplicants: List.unmodifiable(orphans),
        fullFieldAvailable: fullFieldAvailable,
      ),
      rows.length >= kRaceFieldRowCap,
    );
  }
}

/// A fetch result plus whether it came back at its row cap.
@immutable
class _Fetched<T> {
  final T value;
  final bool truncated;
  const _Fetched(this.value, this.truncated);
}

extension _OptionalTimeout<T> on Future<T> {
  Future<T> timeoutOrNull(Duration? d) => d == null ? this : timeout(d);
}

/// True when the failure means "the view or column is not in the database",
/// which is what a deploy that lands before its migration looks like.
///
/// `42P01` is Postgres undefined_table. `PGRST205` is PostgREST's
/// "could not find the table in the schema cache", which is what actually
/// comes back when the relation has never existed. `42703` / `PGRST204` are
/// the column-level equivalents and are treated the same way: a view that is
/// present but predates a column this build selects is still "schema behind
/// the code", and no retry will fix it.
/// True when the failure is specifically "that COLUMN is not on the view",
/// which is the narrow case a shorter select list actually fixes.
///
/// `42703` is Postgres undefined_column. `PGRST204` is PostgREST's column-level
/// schema-cache miss. Deliberately narrower than [_isSchemaMissing]: that one
/// also matches these codes, because from the snapshot's point of view a stale
/// column IS a stale schema, but here we want to retry rather than give up, and
/// retrying a missing TABLE with fewer columns would just fail twice.
bool _isMissingColumn(PostgrestException e) {
  if (e.code == '42703' || e.code == 'PGRST204') return true;
  // Some PostgREST versions return the table-level code with a column-level
  // message. Match on the message only when it names a column, so a genuinely
  // absent view is never mistaken for a column drift.
  final msg = e.message.toLowerCase();
  return msg.contains('column') &&
      (msg.contains('does not exist') || msg.contains('schema cache'));
}

bool _isSchemaMissing(Object e) {
  if (e is PostgrestException) {
    const codes = {'42P01', 'PGRST205', 'PGRST202', '42703', 'PGRST204'};
    if (codes.contains(e.code)) return true;
    final msg = e.message.toLowerCase();
    return msg.contains('does not exist') ||
        msg.contains('schema cache') ||
        msg.contains('could not find the table');
  }
  return false;
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

  /// Numeric district, from the view's `race_district_num`. Used to order the
  /// bottom section by chamber and district rather than by anything that could
  /// read as a ranking.
  final int? districtNum;

  /// 'Missouri House, District 42'. Null only against a pre-182 view, which
  /// does not carry the column. Measured non-null on all 245 rows once 182 is
  /// applied.
  final String? raceLabel;

  /// True when one of OUR applicants is in this race, so this person belongs
  /// under that applicant's toggle. False when nobody in this race returned the
  /// questionnaire, so this person belongs in the bottom section. A property of
  /// the RACE, identical on every row that shares a [raceKey].
  ///
  /// Defaults to false against a pre-182 view. That default is never read as a
  /// claim: [_parseField] only builds the bottom section when the column was
  /// actually selected.
  final bool raceHasApplicant;

  /// Rendered as stored. FEC-sourced rows (the Summers CD2 and Province CD4
  /// supplements) arrive as "LAST, FIRST MIDDLE MR." and stay that way:
  /// guessing at a person's preferred name form is how you print something
  /// wrong next to their face.
  final String name;

  /// True on 27 of the 174 non-applicants (16%) once the field is widened to
  /// the whole state; it was 1 (Wesley Bell) when the field only reached races
  /// we had an applicant in. Rendered as a plain factual chip when true and
  /// nothing otherwise. At 27 it is now a real recurring element rather than a
  /// one-off, and it is a statement about the seat, not an assessment.
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

  /// Free-text US-format filing date as the Secretary of State recorded it
  /// ('2/24/2026' on 151 of the 253 filed Democrats). Populated on 170 of the
  /// 174 candidates-sourced non-applicants (98%), tied with birth_year for the
  /// highest fill rate here. Render [filedOnLabel], never this: the column is
  /// text, not a date, and an unparseable value must produce no line at all.
  final String? filingDate;

  /// Self-reported occupation. Sparse, 58 of 174 (33%). Present so the
  /// row has something human on it when it exists; nothing depends on it.
  final String? occupation;

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
    this.districtNum,
    this.raceLabel,
    this.raceHasApplicant = false,
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
    required this.filingDate,
    required this.occupation,
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
      districtNum: int.tryParse(m['race_district_num']?.toString() ?? ''),
      raceLabel: str('race_label'),
      raceHasApplicant: m['race_has_applicant'] == true,
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
      filingDate: str('filing_date'),
      occupation: str('occupation'),
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

  /// "Filed Feb 24, 2026", or null.
  ///
  /// [filingDate] is a TEXT column holding whatever the scrape recorded, so
  /// this validates before it formats: it accepts `M/D/YYYY` and
  /// `YYYY-MM-DD`, requires a plausible calendar date in 2024..2030, and
  /// returns null for anything else. A date is a factual statement about a
  /// public filing; a misparsed one printed under an unvetted person's name
  /// is a wrong factual statement, so the bar for showing it is that we could
  /// read it, not that a string was present.
  String? get filedOnLabel {
    final raw = filingDate;
    if (raw == null) return null;
    int? y, mo, d;
    final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(raw);
    if (us != null) {
      mo = int.tryParse(us.group(1)!);
      d = int.tryParse(us.group(2)!);
      y = int.tryParse(us.group(3)!);
    } else if (iso != null) {
      y = int.tryParse(iso.group(1)!);
      mo = int.tryParse(iso.group(2)!);
      d = int.tryParse(iso.group(3)!);
    }
    if (y == null || mo == null || d == null) return null;
    if (y < 2024 || y > 2030 || mo < 1 || mo > 12 || d < 1 || d > 31) {
      return null;
    }
    // Round-trip so 2/30/2026 is rejected rather than silently rolled into
    // March by DateTime's overflow behaviour.
    final parsed = DateTime(y, mo, d);
    if (parsed.month != mo || parsed.day != d) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Filed ${months[mo - 1]} $d, $y';
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
