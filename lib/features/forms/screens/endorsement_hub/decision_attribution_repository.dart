import 'package:flutter/foundation.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Attribution for the locked baseline decisions: WHO can honestly be said to
/// stand behind each decision, and how far that can be pushed.
///
/// Reads two read-only views created by
/// moyd-ops/endorsement-round-2/sql/030_meeting_attribution.sql:
///
///  * `public.v_endorsement_decision_attribution`: one row per
///    (decided candidate, meeting attendee). It already carries the
///    per-candidate ballot summary from `v_endorsement_decision_ballot`, so
///    this client makes no third call.
///  * `public.v_endorsement_decision_meeting`: one row per source meeting with
///    the header counts (attendees present, exec roster size, and how many of
///    the decisions have a record running against them), so the client never
///    hardcodes "8 of 16" or "4 with a countervailing record".
///
/// WHY THIS FILE IS SHAPED THE WAY IT IS. An earlier version of the migration
/// stamped one uniform basis on all 23 decisions and this client rendered it as
/// "Committee consensus". Re-reading the meeting transcript showed that was
/// false: there was no per-candidate roll call at all, and on at least one row
/// (Hans Peter) three named attendees are on record wanting to ENDORSE a
/// candidate whose stored decision is DECLINE, which the chair carried on an AI
/// alignment score the room itself called unreliable. Rendering those people
/// under that decision as agreeing with it is the worst outcome this surface
/// can produce, so:
///
///  * [DecisionBasis] carries the real per-decision distinctions, and
///    [CandidateAttribution.contested] is the single flag a caller must honour
///    before presenting anybody as a supporter;
///  * an unrecognised basis value degrades to [DecisionBasis.unrecorded],
///    which claims NOTHING, never to the friendliest reading;
///  * presence is evaluated PER DECISION ([DecisionPresence]), because "was in
///    the meeting at some point" is not the claim "was in the room when this
///    candidate was dealt with".
///
/// HONESTY CONTRACT, mirrored from the SQL comments. Five axes are kept
/// separate and must never be collapsed by a consumer:
///  * `attributionSource`: a Zoom-reported attendance record versus a
///    transcript-based assertion this project made after our own ingest filter
///    destroyed the chair's platform record.
///  * `confidence`: how strongly we know the row is this person (full-name
///    match, partial-name match, or transcript reconstruction). It is NOT a
///    duration measure.
///  * `presenceFor(memberId)`: whether that person was in the room at the point
///    THIS candidate was disposed of.
///  * `basis`: what the transcript supports about the decision itself.
///  * the ballot axis (`ballotsRecorded`, `ballotsOpposing`, `ballotFor`):
///    what `public.endorsement_votes` separately records, which is a DIFFERENT
///    record from a DIFFERENT time.
///
/// THE SECOND THING THIS FILE GOT WRONG, fixed in the same spirit. The sheet
/// used to pin one sentence over all 23 rows ending "so nobody below is
/// recorded as having voted either way." That is false on 9 of the 23.
/// endorsement_votes holds 18 individual ballots on these exact decisions, from
/// Chloé Ray (2026-07-17 UTC) and Elmedin Karamovic (2026-07-18 UTC, which is
/// the evening of Jul 17 in Missouri and renders as Jul 17), both of whom are
/// listed by name and photo in the sheet, and four of those ballots run
/// AGAINST the stored decision
/// (Tara Childress Lopez Hallmark and Don Crozier, both stored decline, both
/// voted yes by both people). So the blanket sentence is gone and the claim is
/// now made per candidate from the data.
///
/// [contested] is therefore the OR of two different kinds of contradiction, and
/// the two are kept addressable separately ([transcriptContested],
/// [ballotContested]) because the honest sentence differs: one is about a room
/// whose members were never individually polled, the other is about two named
/// execs who are on record.
///
/// DEGRADATION, two separate cases, both required:
///  * Migration not applied at all (or any load failure): the maps stay empty,
///    `attributionFor` returns null for everything, and the baseline renders
///    byte-identically to how it did before this feature existed.
///  * OLD migration applied (uniform basis, no evidence or ballot columns):
///    every added column is read defensively, so the sheet still renders,
///    presence falls back to [DecisionPresence.unknown], the basis falls back
///    to [DecisionBasis.unrecorded] and the ballot block renders NOTHING rather
///    than reporting a zero it cannot back. It states less; it never states
///    more.
class DecisionAttributionRepository extends ChangeNotifier {
  DecisionAttributionRepository();

  /// Shared instance. The provenance is one meeting shared by all 23 decided
  /// rows and it changes only via migration (no realtime channel exists for
  /// it), so a single fetch per app session is correct and keeps the
  /// RosterBoard call site to the one-argument change the build spec asks for.
  static final DecisionAttributionRepository instance =
      DecisionAttributionRepository();

  static const _attributionView = 'v_endorsement_decision_attribution';
  static const _meetingView = 'v_endorsement_decision_meeting';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  final Map<String, CandidateAttribution> _byCandidate = {};
  bool _loaded = false;
  bool _loading = false;
  bool _loadFailed = false;

  bool get loaded => _loaded;
  bool get loadFailed => _loadFailed;

  /// Attribution for one decided candidate, or null when none exists (row was
  /// decided outside any attributed meeting, or the migration is not applied,
  /// or the load failed). Null MUST render as the pre-feature baseline row.
  CandidateAttribution? attributionFor(String candidateId) =>
      _byCandidate[candidateId];

  /// One-shot load; safe to call from every BaselineSection initState. On
  /// failure the maps stay empty (degraded render, fully usable) but _loaded
  /// stays false so the NEXT mount of the hub retries; only initState calls
  /// this, never build, so a persistent outage cannot retry-loop.
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final attRows = await _supabase.client.from(_attributionView).select();
      final meetingRows = await _supabase.client.from(_meetingView).select();

      final meetings = <String, MeetingAttribution>{};
      for (final row in (meetingRows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['meeting_id']?.toString();
        if (id == null || id.isEmpty) continue;
        meetings[id] = MeetingAttribution._fromMeetingRow(m);
      }

      _byCandidate.clear();
      for (final row in (attRows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final candidateId = m['candidate_id']?.toString();
        final meetingId = m['meeting_id']?.toString();
        if (candidateId == null || candidateId.isEmpty) continue;
        if (meetingId == null || meetingId.isEmpty) continue;

        // The meeting summary row should always exist (same source table);
        // if it does not, synthesize a shell from the per-person row so the
        // attendee list still renders and only the roster fraction is lost.
        final meeting = meetings.putIfAbsent(
            meetingId, () => MeetingAttribution._fromAttributionRow(m));

        final attendee = AttributionAttendee._fromRow(m);
        if (attendee != null) meeting._addAttendee(attendee);

        final existing = _byCandidate[candidateId];
        final cand = existing ??
            CandidateAttribution._(
              candidateId: candidateId,
              basisRaw: (m['basis'] as String?) ?? '',
              basisEvidence:
                  (m['basis_evidence'] as String?)?.trim().isNotEmpty == true
                      ? (m['basis_evidence'] as String).trim()
                      : null,
              evidenceFirstTurn: _toInt(m['evidence_first_turn']),
              evidenceLastTurn: _toInt(m['evidence_last_turn']),
              entryAuthorUnrecorded: m['entry_author_unrecorded'] == true,
              decisionState: (m['state'] as String?)?.trim() ?? '',
              // Ballot axis. Read defensively: an older migration has no such
              // columns, and 0 recorded ballots is the claim-nothing default,
              // which renders as "we hold no individual position on this",
              // never as "nobody voted".
              ballotsRecorded: _toInt(m['ballots_recorded']) ?? 0,
              ballotsOpposing: _toInt(m['ballots_opposing']) ?? 0,
              ballotsAgreeing: _toInt(m['ballots_agreeing']) ?? 0,
              ballotsUndecided: _toInt(m['ballots_undecided']) ?? 0,
              opposingVoterNames: _toStringList(m['opposing_voter_names']),
              ballotVoterNames: _toStringList(m['ballot_voter_names']),
              hasBallotColumns: m.containsKey('ballots_recorded'),
              meeting: meeting,
            );

        // presence_vs_evidence is per (candidate, attendee), unlike everything
        // else on the attendee, which is per attendee. It lives here so the
        // shared attendee objects stay shared.
        if (attendee != null) {
          cand._presence[attendee.memberId] = AttendeePresence._fromRow(m);
          // Same shape: this attendee's OWN later ballot on THIS candidate.
          final ballot = AttendeeBallot._fromRow(m);
          if (ballot != null) cand._ballots[attendee.memberId] = ballot;
        }

        // last_app_writer is per (candidate, attendee): true on the attendee
        // whose account the app last stamped on this row. See the SQL comment:
        // this does NOT mean they authored the stored decision.
        if (m['last_app_writer'] == true && attendee != null) {
          cand._lastAppWriterName = attendee.name;
        }
        _byCandidate[candidateId] = cand;
      }
      for (final mt in meetings.values) {
        mt._sortAttendees();
      }
      _loaded = true;
      _loadFailed = false;
    } catch (e) {
      // Includes "relation does not exist" while the migration is pending.
      debugPrint('DecisionAttributionRepository.ensureLoaded error: $e');
      _byCandidate.clear();
      _loadFailed = true;
    } finally {
      _loading = false;
    }
    notifyListeners();
  }
}

/// What the stored meeting transcript supports about how one decision was
/// reached. Mirrors the `basis` vocabulary in
/// `public.endorsement_decision_source`; see that column's comment for the
/// quoted turns behind every value.
///
/// [contested] here means the TRANSCRIPT runs against the stored decision. It
/// is one of two ways a decision can be contradicted; the other is a later
/// individual ballot, which is not part of the transcript and is therefore not
/// part of this vocabulary. Callers must gate on
/// [CandidateAttribution.contested], which is the union of both, and not on
/// this flag alone.
enum DecisionBasis {
  /// Someone in the room stated a position matching this outcome out loud and
  /// nothing contradicts it. Still not a vote: no per-candidate roll call was
  /// ever taken.
  ///
  /// The copy says "stated a position matching this outcome" rather than "said
  /// this outcome" because it renders over all 15 rows graded this way and the
  /// weakest three do not carry the stronger claim. Missi Hesketh rests on turn
  /// 171, "Yeah, no, she's good on"; Wick Thomas on turn 226, "that's easy",
  /// and 229, "Wick is my goat"; Jeanette Cass on turn 367, "I, I veto her, if
  /// I can", with the chair's turn 368, "No, she...", truncated mid-sentence
  /// and unreadable either way. All three run the same direction as the stored
  /// decision, so nobody is shown under a decision they opposed, but a shared
  /// label may not be stronger than the weakest row it covers. The alternative
  /// was splitting the value in two and re-grading 15 rows; the softening says
  /// something true of all 15, and the per-row evidence paragraph rendered
  /// directly underneath carries each row's own nuance verbatim.
  roomVerdict(
    'room_verdict',
    short: 'Decided out loud',
    headline: 'Stated out loud in the meeting',
    detail: 'Someone on the call stated a position matching this outcome, and '
        'nothing in the recording contradicts it. This was not a counted vote; '
        'the committee took no roll call on any candidate.',
  ),

  /// The room read out a disqualifying answer but never spoke the outcome.
  roomDisqualifier(
    'room_disqualifier',
    short: 'Reason stated, outcome not',
    headline: 'The reason was stated, the outcome was not',
    detail: 'The room read out an answer of this candidate\'s that falls under '
        'one of the disqualifiers the meeting set for itself. Nobody said the '
        'outcome out loud, so this decision follows the rule rather than a '
        'spoken decision.',
    outcomeUnspoken: true,
  ),

  /// The decision follows the chair's AI-score filtering and the room wanted
  /// the opposite.
  chairFilterOverride(
    'chair_filter_override',
    short: 'The room wanted the opposite',
    headline: 'The room wanted the opposite',
    detail: 'Several people on this call argued for the opposite outcome. The '
        'stored decision follows the chair\'s filtering on the AI alignment '
        'score, which the room itself called unreliable later in the same '
        'meeting. Nobody listed below should be read as agreeing with this.',
    contested: true,
  ),

  /// Everything audible ran the other way and no verdict was ever spoken.
  transcriptContradicts(
    'transcript_contradicts',
    short: 'Transcript does not support this',
    headline: 'The recording does not support this',
    detail: 'Nothing in the recording disposes of this candidate, and every '
        'opinion anyone voiced ran the other way. Nobody listed below should '
        'be read as agreeing with this.',
    contested: true,
  ),

  /// Discussed, but the transcript neither states nor contradicts the outcome.
  noTranscriptDisposition(
    'no_transcript_disposition',
    short: 'Basis not recorded',
    headline: 'How this was decided is not recorded',
    detail: 'This candidate was discussed, but the recording neither states '
        'this outcome nor clearly contradicts it. Treat the stored decision as '
        'unexplained.',
    outcomeUnspoken: true,
  ),

  /// Reserved values, present so a future migration that starts using them
  /// renders something true rather than falling through to "not recorded".
  recordedVote(
    'recorded_vote',
    short: 'Recorded committee vote',
    headline: 'A counted vote was taken',
    detail: 'The recording shows a motion, a second and a counted vote on '
        'this.',
  ),
  asyncBallot(
    'async_ballot',
    short: 'Async exec ballot',
    headline: 'Decided by ballot after the meeting',
    detail: 'This was decided in the individual ballot record rather than in '
        'the room.',
  ),
  delegatedDisposition(
    'delegated_disposition',
    short: 'Delegated to one member',
    headline: 'The call was handed to one member',
    detail: 'The chair asked one named member to decide this candidate rather '
        'than putting it to the room. It is one person\'s call, not the '
        'room\'s.',
    outcomeUnspoken: true,
  ),

  /// Fallback for a missing or unrecognised value, including a database still
  /// carrying the retired uniform basis. Claims nothing.
  unrecorded(
    '',
    short: 'Basis not recorded',
    headline: 'How this was decided is not recorded',
    detail: 'This decision is linked to the meeting below. Nothing recorded '
        'says how it was reached.',
  );

  const DecisionBasis(
    this.wire, {
    required this.short,
    required this.headline,
    required this.detail,
    this.contested = false,
    this.outcomeUnspoken = false,
  });

  /// The exact value stored in `endorsement_decision_source.basis`.
  final String wire;

  /// One-line label for the compact baseline row.
  final String short;

  /// Heading for the attribution sheet's basis block.
  final String headline;

  /// Body copy for the attribution sheet's basis block.
  final String detail;

  /// TRUE means the RECORDING runs against the stored decision. A caller must
  /// gate on [CandidateAttribution.contested], which also covers the rows
  /// contradicted only by a later ballot.
  final bool contested;

  /// The reasoning is on the record but the outcome itself never was.
  final bool outcomeUnspoken;

  /// Unknown and absent values resolve to [unrecorded], which claims nothing.
  /// Never resolve an unknown value to a friendlier reading.
  static DecisionBasis fromWire(String? w) {
    if (w == null || w.isEmpty) return DecisionBasis.unrecorded;
    for (final b in DecisionBasis.values) {
      if (b.wire == w) return b;
    }
    return DecisionBasis.unrecorded;
  }
}

/// Whether one attendee was in the room at the point one specific candidate was
/// disposed of. Mirrors `presence_vs_evidence`.
///
/// The transcript carries no timestamps, so this is a calibrated estimate with
/// a documented margin of error; [uncertain] exists precisely so the margin is
/// never silently rounded into a claim.
enum DecisionPresence {
  present('In the room for this'),
  uncertain('Presence uncertain'),
  absent('Not in the room for this'),

  /// No join or leave time recorded, or the migration predates the per-decision
  /// evidence window. Renders as an unqualified attendee, same as before this
  /// feature existed.
  unknown('Presence not established');

  const DecisionPresence(this.label);
  final String label;

  static DecisionPresence fromName(String? n) {
    for (final p in DecisionPresence.values) {
      if (p.name == n) return p;
    }
    return DecisionPresence.unknown;
  }
}

/// One attendee's presence relative to ONE decision's evidence window.
///
/// THE WINDOW IS A SPAN, NOT AN INSTANT, and on the wide rows it is 23 minutes
/// long (Les Majors, transcript turns 691 to 1051). That is why four signed
/// gaps are carried rather than two. The earlier version measured a departure
/// only against the END of the span and captioned it "Left about N minutes
/// before this candidate came up", which for Gannon Seyer on Les Majors was a
/// false sentence about a named person: he was in the room when Les Majors came
/// up and left 21 minutes later.
@immutable
class AttendeePresence {
  final DecisionPresence state;

  /// Seconds between this person joining and the candidate FIRST coming up.
  /// Negative means the discussion had already started when they joined.
  final int? secondsJoinedBefore;

  /// Seconds between the candidate being FINISHED with and this person leaving.
  /// Negative means they left before the discussion finished.
  final int? secondsStayedAfter;

  /// Seconds between the candidate first coming up and this person leaving.
  /// Negative means they had already left before it came up at all.
  final int? secondsStayedAfterStart;

  /// Seconds between this person joining and the candidate being finished with.
  /// Negative means they joined after it was over.
  final int? secondsJoinedBeforeEnd;

  const AttendeePresence._({
    required this.state,
    required this.secondsJoinedBefore,
    required this.secondsStayedAfter,
    required this.secondsStayedAfterStart,
    required this.secondsJoinedBeforeEnd,
  });

  static const unknown = AttendeePresence._(
    state: DecisionPresence.unknown,
    secondsJoinedBefore: null,
    secondsStayedAfter: null,
    secondsStayedAfterStart: null,
    secondsJoinedBeforeEnd: null,
  );

  static AttendeePresence _fromRow(Map<String, dynamic> m) => AttendeePresence._(
        state: DecisionPresence.fromName(m['presence_vs_evidence'] as String?),
        secondsJoinedBefore: _toInt(m['seconds_joined_before_evidence']),
        secondsStayedAfter: _toInt(m['seconds_stayed_after_evidence']),
        secondsStayedAfterStart:
            _toInt(m['seconds_stayed_after_evidence_start']),
        secondsJoinedBeforeEnd: _toInt(m['seconds_joined_before_evidence_end']),
      );

  /// "Left about 8 minutes before this candidate came up", or the joined-late
  /// equivalent, or null. Rounded to whole minutes and always hedged with
  /// "about", because the underlying turn-to-clock mapping is an estimate with
  /// a roughly four minute margin.
  ///
  /// TWO RULES, both of which the earlier version broke.
  ///
  /// 1. NEVER RENDERED ON AN UNCERTAIN ROW. On an uncertain row the gap is by
  ///    definition inside the calibration margin, and the tile already sits
  ///    under copy saying the recording cannot place the person either side of
  ///    the passage. Printing "Joined about a minute after this candidate was
  ///    dealt with" next to that contradicted it. Gannon Seyer against Wick
  ///    Thomas is 3 seconds on the wrong side of a 250 second margin; there is
  ///    no honest minute figure to print.
  /// 2. MEASURED AGAINST THE END OF THE WINDOW THE SENTENCE IS ABOUT. Leaving
  ///    before the discussion STARTED and leaving before it FINISHED are
  ///    different facts and get different sentences, and only the first one may
  ///    say "before this candidate came up".
  String? get gapLine {
    if (state == DecisionPresence.uncertain) return null;

    String mins(int seconds) {
      final m = (seconds.abs() / 60).round();
      return m <= 1 ? 'about a minute' : 'about $m minutes';
    }

    // Left before the candidate was ever raised.
    final afterStart = secondsStayedAfterStart;
    if (afterStart != null && afterStart < 0) {
      return 'Left ${mins(afterStart)} before this candidate came up.';
    }
    // Was there when it came up, but left before it was finished with.
    final after = secondsStayedAfter;
    if (after != null && after < 0) {
      return 'Left before this candidate had finished being discussed.';
    }
    // Joined after the candidate had already been dealt with entirely.
    final beforeEnd = secondsJoinedBeforeEnd;
    if (beforeEnd != null && beforeEnd < 0) {
      return 'Joined ${mins(beforeEnd)} after this candidate was dealt with.';
    }
    // Joined partway through the discussion.
    final before = secondsJoinedBefore;
    if (before != null && before < 0) {
      return 'Joined after this candidate had already come up.';
    }
    return null;
  }
}

/// One attendee's own later ballot on ONE candidate, from
/// `public.endorsement_votes`.
///
/// This is NOT evidence about the meeting. Every ballot on the 23 locked rows
/// was cast two or three days after they were locked. It is here so a tile can
/// carry the fact about the person it names, instead of the sheet asserting
/// something about voting over a list of people it is false for.
@immutable
class AttendeeBallot {
  /// 'yes', 'no' or 'undecided', verbatim from the vote row.
  final String vote;
  final DateTime? castAt;

  /// True when this ballot is the straight opposite of the stored decision.
  final bool opposes;

  const AttendeeBallot._({
    required this.vote,
    required this.castAt,
    required this.opposes,
  });

  static AttendeeBallot? _fromRow(Map<String, dynamic> m) {
    final v = (m['attendee_ballot'] as String?)?.trim();
    if (v == null || v.isEmpty) return null;
    return AttendeeBallot._(
      vote: v,
      castAt: _toTime(m['attendee_ballot_at']),
      opposes: m['attendee_ballot_opposes'] == true,
    );
  }

  /// 'voted to endorse' / 'voted to decline' / 'recorded no position either
  /// way'. Unknown vote strings degrade to the weakest phrasing rather than
  /// being guessed into a direction.
  String get verbPhrase => switch (vote) {
        'yes' => 'voted to endorse',
        'no' => 'voted to decline',
        'undecided' => 'recorded no position either way',
        _ => 'recorded a position',
      };

  /// The line rendered under this person's name on this candidate's sheet.
  String get tileLine {
    final on = castAt == null
        ? ''
        : ' on ${CommitteeLocalDate.short(castAt!)}';
    if (opposes) {
      return 'After the meeting they $verbPhrase$on. That is the opposite of '
          'this decision.';
    }
    if (vote == 'undecided') {
      return 'After the meeting they $verbPhrase$on.';
    }
    return 'After the meeting they $verbPhrase$on, matching this decision.';
  }
}

/// How strongly the attendance row is known to be this person, and where the
/// row came from. NOT a duration measure; duration is [AttributionAttendee]'s
/// `leftBeforeEnd` / `joinedAfterStart` / `minutesMissed`, and presence for a
/// specific decision is [AttendeePresence].
enum PresenceConfidence {
  /// Zoom participant record matched to a member by full name.
  confirmed('Confirmed'),

  /// Zoom participant record matched only on a partial name; the mapping to
  /// this member is a judgement call.
  reported('Reported'),

  /// No Zoom record survives; presence reconstructed from the transcript.
  inferred('Inferred');

  const PresenceConfidence(this.label);
  final String label;

  static PresenceConfidence fromName(String? n) =>
      PresenceConfidence.values.firstWhere(
        (c) => c.name == n,
        // Unknown values read as the weakest claim, never the strongest.
        orElse: () => PresenceConfidence.inferred,
      );
}

/// One exec who attended the meeting, with the facts that are true of them
/// across the whole meeting. Per-decision presence is NOT here; it is on
/// [CandidateAttribution.presenceFor].
@immutable
class AttributionAttendee {
  final String memberId;
  final String name;

  /// "Representative · 7th Congressional District" style line, or '' when the
  /// member row carries no exec title.
  final String roleLine;
  final String? avatarUrl;
  final int? minutesPresent;
  final DateTime? firstJoin;
  final DateTime? lastLeave;
  final bool isHost;
  final PresenceConfidence confidence;

  /// 'zoom_attendance_record' or 'chair_assertion_from_transcript'. Kept
  /// verbatim so a consumer can distinguish platform data from our assertion
  /// even if new confidence values appear.
  final String attributionSource;
  final bool leftBeforeEnd;

  /// Symmetric counterpart of [leftBeforeEnd], added because analysing only
  /// early departure rendered a nine minute late arrival with no hedge at all.
  final bool joinedAfterStart;
  final int minutesMissed;

  const AttributionAttendee._({
    required this.memberId,
    required this.name,
    required this.roleLine,
    required this.avatarUrl,
    required this.minutesPresent,
    required this.firstJoin,
    required this.lastLeave,
    required this.isHost,
    required this.confidence,
    required this.attributionSource,
    required this.leftBeforeEnd,
    required this.joinedAfterStart,
    required this.minutesMissed,
  });

  bool get isTranscriptAssertion =>
      attributionSource == 'chair_assertion_from_transcript';

  static AttributionAttendee? _fromRow(Map<String, dynamic> m) {
    final memberId = m['member_id']?.toString();
    if (memberId == null || memberId.isEmpty) return null;
    final title = (m['executive_title'] as String?)?.trim() ?? '';
    final role = (m['executive_role'] as String?)?.trim() ?? '';
    return AttributionAttendee._(
      memberId: memberId,
      name: (m['member_name'] as String?)?.trim().isNotEmpty == true
          ? (m['member_name'] as String).trim()
          : 'Unnamed member',
      roleLine: [title, role].where((s) => s.isNotEmpty).join(' · '),
      avatarUrl: (m['member_avatar_url'] as String?)?.trim().isNotEmpty == true
          ? (m['member_avatar_url'] as String).trim()
          : null,
      minutesPresent: _toInt(m['minutes_present']),
      firstJoin: _toTime(m['first_join_time']),
      lastLeave: _toTime(m['last_leave_time']),
      isHost: m['is_host'] == true,
      confidence: PresenceConfidence.fromName(m['presence_confidence'] as String?),
      attributionSource:
          (m['attribution_source'] as String?) ?? 'zoom_attendance_record',
      leftBeforeEnd: m['left_before_end'] == true,
      joinedAfterStart: m['joined_after_start'] == true,
      minutesMissed: _toInt(m['minutes_missed']) ?? 0,
    );
  }
}

/// The shared provenance object: one meeting, its attendee list and the header
/// counts. All decided rows from the same meeting point at ONE instance, so
/// eight names are never duplicated 23 times.
class MeetingAttribution {
  final String meetingId;
  final DateTime? meetingDate;
  final String? meetingTitle;
  final int? durationMinutes;
  final String? recordingUrl;

  /// From v_endorsement_decision_meeting; null when only the per-person view
  /// answered (shell path).
  final int? execRosterSize;
  final int? attendeesPresentReported;

  /// How many of this meeting's attributed decisions have SOMETHING on record
  /// running against them, on either axis. Comes from the view so the header
  /// cannot silently stay at zero if a later grading pass moves a row or a new
  /// ballot lands. Null on the shell path or on an older migration.
  ///
  /// 4 as measured on 2026-07-25, not 2: the previous version counted only the
  /// transcript axis and captioned the whole locked-baseline card "2 need
  /// review".
  final int? decisionsContested;

  /// The two components of [decisionsContested], for anything that needs to
  /// explain the number rather than just print it. Null on older migrations.
  final int? decisionsTranscriptContested;
  final int? decisionsBallotContested;

  final List<AttributionAttendee> _attendees = [];
  final Set<String> _attendeeIds = {};

  MeetingAttribution._({
    required this.meetingId,
    required this.meetingDate,
    required this.meetingTitle,
    required this.durationMinutes,
    required this.recordingUrl,
    required this.execRosterSize,
    required this.attendeesPresentReported,
    required this.decisionsContested,
    required this.decisionsTranscriptContested,
    required this.decisionsBallotContested,
  });

  static MeetingAttribution _fromMeetingRow(Map<String, dynamic> m) =>
      MeetingAttribution._(
        meetingId: m['meeting_id'].toString(),
        meetingDate: _toTime(m['meeting_date']),
        meetingTitle: m['meeting_title'] as String?,
        durationMinutes: _toInt(m['duration_minutes']),
        recordingUrl: (m['recording_url'] as String?)?.trim().isNotEmpty == true
            ? (m['recording_url'] as String).trim()
            : null,
        execRosterSize: _toInt(m['exec_roster_size']),
        attendeesPresentReported: _toInt(m['attendees_present']),
        decisionsContested: _toInt(m['decisions_contested']),
        decisionsTranscriptContested:
            _toInt(m['decisions_transcript_contested']),
        decisionsBallotContested: _toInt(m['decisions_ballot_contested']),
      );

  static MeetingAttribution _fromAttributionRow(Map<String, dynamic> m) =>
      MeetingAttribution._(
        meetingId: m['meeting_id'].toString(),
        meetingDate: _toTime(m['meeting_date']),
        meetingTitle: m['meeting_title'] as String?,
        durationMinutes: _toInt(m['meeting_duration_minutes']),
        recordingUrl: (m['recording_url'] as String?)?.trim().isNotEmpty == true
            ? (m['recording_url'] as String).trim()
            : null,
        execRosterSize: null,
        attendeesPresentReported: null,
        decisionsContested: null,
        decisionsTranscriptContested: null,
        decisionsBallotContested: null,
      );

  /// Attendees, host first, then by minutes present descending, then name.
  List<AttributionAttendee> get attendees => List.unmodifiable(_attendees);

  int get attendeeCount => _attendees.isNotEmpty
      ? _attendees.length
      : (attendeesPresentReported ?? 0);

  void _addAttendee(AttributionAttendee a) {
    if (_attendeeIds.add(a.memberId)) _attendees.add(a);
  }

  void _sortAttendees() {
    _attendees.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      final am = a.minutesPresent ?? 0;
      final bm = b.minutesPresent ?? 0;
      if (am != bm) return bm.compareTo(am);
      return a.name.compareTo(b.name);
    });
  }

  /// 'Jul 14, 2026', in the COMMITTEE's own zone, not the viewer's.
  ///
  /// The meeting instant is 2026-07-15 01:01:26 UTC, which is 8:01 PM Central
  /// on 2026-07-14. `toLocal()` was correct for a Central viewer and wrong for
  /// anyone at or east of UTC, who would have read "From the Jul 15, 2026
  /// meeting" directly above a source note reading "7/14/26" and an evidence
  /// document that says July 14 throughout. This surface describes one specific
  /// committee's one specific evening, so the date is pinned to that committee's
  /// zone. See [CommitteeLocalDate].
  String get dateLabel {
    final d = meetingDate;
    if (d == null) return 'date unrecorded';
    return CommitteeLocalDate.long(d);
  }

  /// 'Jul 14' for the compact per-row line. Same pinning as [dateLabel].
  String get shortDateLabel {
    final d = meetingDate;
    if (d == null) return 'meeting';
    return CommitteeLocalDate.short(d);
  }

  /// '8 of 16 execs present', or null when the roster denominator is unknown.
  /// Counts come from the view so a later attendance correction (for example
  /// the chair's exact Zoom times landing) updates this with zero UI change.
  String? get presenceLine {
    final present = attendeeCount;
    final roster = execRosterSize;
    if (present <= 0) return null;
    if (roster == null || roster <= 0) return '$present execs present';
    return '$present of $roster execs present';
  }

  /// Provenance, not a to-do list.
  ///
  /// This used to read "4 need review". The chair ruled on 2026-07-26 that all
  /// 23 decisions stand: the room had personal knowledge of these candidates
  /// that the recording does not carry, and the AI scores of that week only
  /// read the multiple choice answers and ignored everything candidates wrote.
  /// So "review" was asserting the decisions are open, which is not true and
  /// was never the committee's position.
  ///
  /// What stays true, and is worth a reader knowing, is that some rows have a
  /// record running the other way: on two the recording does not back the
  /// stored outcome, and on two a later individual ballot went the other way.
  /// That is a fact about the paper trail, not a verdict on the decision.
  String? get contestedLine {
    final n = decisionsContested;
    if (n == null || n <= 0) return null;
    return n == 1
        ? '1 with a countervailing record'
        : '$n with a countervailing record';
  }

  /// Minutes between an attendee's last leave and the scheduled meeting end,
  /// or null when either bound is unknown. This is the "left 33 minutes before
  /// the end" number, distinct from minutesMissed (which also counts a late
  /// join).
  int? minutesBeforeEnd(AttributionAttendee a) {
    final start = meetingDate;
    final dur = durationMinutes;
    final leave = a.lastLeave;
    if (start == null || dur == null || leave == null) return null;
    final end = start.add(Duration(minutes: dur));
    final gap = end.difference(leave).inMinutes;
    return gap > 0 ? gap : 0;
  }

  /// Minutes an attendee joined after the meeting started, or null.
  int? minutesAfterStart(AttributionAttendee a) {
    final start = meetingDate;
    final join = a.firstJoin;
    if (start == null || join == null) return null;
    final gap = join.difference(start).inMinutes;
    return gap > 0 ? gap : 0;
  }
}

/// One decided candidate's link to the meeting the decision came out of, plus
/// what the transcript supports about that decision and who was in the room
/// when this particular candidate was dealt with.
class CandidateAttribution {
  final String candidateId;

  /// The raw `basis` string, kept verbatim so a consumer can tell an
  /// unrecognised new value from a genuinely absent one.
  final String basisRaw;

  /// The per-row evidence paragraph from the migration, with transcript turn
  /// numbers cited, or null on an older migration. This is the receipt; render
  /// it rather than paraphrasing it.
  final String? basisEvidence;
  final int? evidenceFirstTurn;
  final int? evidenceLastTurn;

  /// True when endorsement_decisions.updated_by is NULL: the row was written
  /// by an out-of-band script, and nobody's account is stamped on it.
  final bool entryAuthorUnrecorded;

  /// 'endorse' / 'decline' / 'undecided', verbatim, so ballot copy can name the
  /// stored decision without the sheet passing it back down.
  final String decisionState;

  /// THE BALLOT AXIS, per candidate. How many people have ever recorded an
  /// individual position on THIS candidate, how many recorded the opposite of
  /// the stored decision, and who they are. All zero and empty on the 14 of 23
  /// nobody has voted on, and zero-and-empty is a claim of ignorance, not a
  /// claim that nobody voted: see [hasBallotColumns].
  final int ballotsRecorded;
  final int ballotsOpposing;
  final int ballotsAgreeing;
  final int ballotsUndecided;
  final List<String> opposingVoterNames;
  final List<String> ballotVoterNames;

  /// False against a migration that predates the ballot columns. The UI must
  /// then say NOTHING about voting rather than reporting a zero it cannot back.
  final bool hasBallotColumns;

  final MeetingAttribution meeting;

  final Map<String, AttendeePresence> _presence = {};
  final Map<String, AttendeeBallot> _ballots = {};

  String? _lastAppWriterName;

  /// Name of the attendee whose account the app LAST stamped on this row, or
  /// null. Explicitly not "who typed the decision": audit_log is empty, so the
  /// stamp may predate the out-of-band recovery UPDATE that set the final
  /// state, and it may equally postdate it if anyone edits the row through the
  /// app later. UI copy must hedge accordingly.
  String? get lastAppWriterName => _lastAppWriterName;

  /// What the transcript supports about how this decision was reached.
  DecisionBasis get basis => DecisionBasis.fromWire(basisRaw);

  /// The RECORDING runs against the stored decision. 2 rows: Hans Peter,
  /// Kemp Strickler.
  bool get transcriptContested => basis.contested;

  /// A LATER INDIVIDUAL BALLOT runs against the stored decision. 2 rows: Tara
  /// Childress Lopez Hallmark and Don Crozier, both stored decline, both voted
  /// yes by the only two execs who have ever recorded a position on them.
  ///
  /// Deliberately a separate axis from [transcriptContested] rather than a
  /// basis value: a ballot cast three days later is not in the transcript,
  /// `room_disqualifier` remains the correct and separately useful grade for
  /// both rows, this axis moves whenever somebody votes while basis is a fixed
  /// hand-grade, and the two require different sentences. See the header of
  /// sql/030_meeting_attribution.sql.
  bool get ballotContested => ballotsOpposing > 0;

  /// TRUE when SOMETHING on record runs AGAINST the stored decision. Callers
  /// MUST NOT present any attendee as agreeing with a contested decision. This
  /// is the union of the two axes and is the flag to gate on; 4 of the 23.
  bool get contested => transcriptContested || ballotContested;

  /// The per-candidate ballot summary, or null when there is nothing true to
  /// say (older migration without the columns). [ballotsRecorded] of 0 is a
  /// real, sayable fact and returns a non-null value.
  BallotSummary? get ballotSummary => hasBallotColumns
      ? BallotSummary._(
          recorded: ballotsRecorded,
          opposing: ballotsOpposing,
          agreeing: ballotsAgreeing,
          undecided: ballotsUndecided,
          opposingNames: opposingVoterNames,
          voterNames: ballotVoterNames,
          decisionState: decisionState,
        )
      : null;

  /// This attendee's own later ballot on this candidate, or null.
  AttendeeBallot? ballotFor(String memberId) => _ballots[memberId];

  /// 'turns 890 to 898' for the evidence citation, or null.
  String? get evidenceTurnLine {
    final a = evidenceFirstTurn;
    final b = evidenceLastTurn;
    if (a == null || b == null) return null;
    return a == b ? 'transcript turn $a' : 'transcript turns $a to $b';
  }

  /// Presence of one attendee relative to THIS decision. Falls back to
  /// [DecisionPresence.unknown], which renders as no claim either way.
  AttendeePresence presenceFor(String memberId) =>
      _presence[memberId] ?? AttendeePresence.unknown;

  /// True when the view actually answered the per-decision presence question
  /// for at least one attendee. False against an older migration that has no
  /// evidence window, in which case the UI must fall back to the weaker
  /// "was at the meeting" claim rather than asserting "was in the room when
  /// this came up" on data that cannot support it.
  bool get hasPerDecisionPresence =>
      _presence.values.any((p) => p.state != DecisionPresence.unknown);

  /// Meeting attendees split by whether they were in the room when THIS
  /// candidate was dealt with. Order within each list is the meeting's own
  /// attendee order (host first, then minutes present).
  List<AttributionAttendee> attendeesWhere(DecisionPresence p) => meeting
      .attendees
      .where((a) => presenceFor(a.memberId).state == p)
      .toList(growable: false);

  /// EVERYONE who was on the call, attributed to this decision.
  ///
  /// COMMITTEE RULE, set by the chair on 2026-07-26: being on the call at any
  /// point counts, "even if they were only on for a min or two". The decisions
  /// were reached with personal knowledge of the candidates that the recording
  /// does not capture, so who happened to be speaking when a given name came
  /// up is not what determined the outcome, and it is not what determines
  /// attribution either.
  ///
  /// The per-decision presence data is still computed and still shown per
  /// person, because when someone joined and left is a fact worth having. It
  /// simply no longer PARTITIONS this list. Nobody is dropped from a decision
  /// for having been in the waiting room when a name was read out.
  List<AttributionAttendee> get attendeesInRoom => meeting.attendees;

  /// Retained for callers that want the presence split explicitly. The sheet
  /// no longer uses it to decide who is attributed; see [attendeesInRoom].
  List<AttributionAttendee> get attendeesPresenceNotEstablished => const [];

  /// Short label for the compact baseline row.
  ///
  /// A row contradicted ONLY by later ballots must not render as its basis
  /// label alone in warning red: "Reason stated, outcome not" in red says
  /// nothing about why it is red. It gets its own label naming the ballots.
  String get basisLabel {
    if (!transcriptContested && ballotContested) {
      return ballotsOpposing == 1
          ? '1 exec later voted the other way'
          : '$ballotsOpposing execs later voted the other way';
    }
    return basis.short;
  }

  CandidateAttribution._({
    required this.candidateId,
    required this.basisRaw,
    required this.basisEvidence,
    required this.evidenceFirstTurn,
    required this.evidenceLastTurn,
    required this.entryAuthorUnrecorded,
    required this.decisionState,
    required this.ballotsRecorded,
    required this.ballotsOpposing,
    required this.ballotsAgreeing,
    required this.ballotsUndecided,
    required this.opposingVoterNames,
    required this.ballotVoterNames,
    required this.hasBallotColumns,
    required this.meeting,
  });
}

/// The per-candidate ballot claim, and the copy that states it.
///
/// This type exists so the sentence is generated FROM THE DATA on every row.
/// The thing it replaced was one hard-coded sentence, pinned above the attendee
/// list on all 23 sheets, ending "so nobody below is recorded as having voted
/// either way". Nine of the 23 carry ballots and two of those nine carry
/// ballots against the stored decision, from two people who are named and
/// photographed in the list directly underneath.
@immutable
class BallotSummary {
  final int recorded;
  final int opposing;
  final int agreeing;
  final int undecided;
  final List<String> opposingNames;
  final List<String> voterNames;

  /// 'endorse' / 'decline' / 'undecided'.
  final String decisionState;

  const BallotSummary._({
    required this.recorded,
    required this.opposing,
    required this.agreeing,
    required this.undecided,
    required this.opposingNames,
    required this.voterNames,
    required this.decisionState,
  });

  bool get anyRecorded => recorded > 0;
  bool get anyOpposing => opposing > 0;

  /// 'this decline' / 'this endorsement', for copy that has to refer to the
  /// stored decision. Falls back to the neutral phrase on an unknown state.
  String get decisionPhrase => switch (decisionState) {
        'endorse' => 'this endorsement',
        'decline' => 'this decline',
        _ => 'this decision',
      };

  String get headline {
    if (!anyRecorded) {
      return 'Nobody has recorded an individual position on this candidate';
    }
    if (anyOpposing) {
      return opposing == 1
          ? '1 exec later voted the other way'
          : '$opposing execs later voted the other way';
    }
    // Deliberately NOT "of the people below": endorsement_votes is not
    // restricted to this meeting's attendees, so a voter need not be one of
    // the names rendered underneath. Today both opposers happened to attend,
    // but the copy must stay true if that ever stops being the case.
    return recorded == 1
        ? '1 exec later recorded an individual position'
        : '$recorded execs later recorded an individual position';
  }

  String get detail {
    if (!anyRecorded) {
      return 'No individual ballot exists on this candidate, for or against. '
          'The people listed below are who was on the call. Being listed is '
          'not agreement.';
    }
    final who = joinNames(voterNames);
    if (anyOpposing) {
      final against = joinNames(opposingNames);
      final all = opposing == recorded;
      return '$who recorded an individual position on this candidate after '
          'the meeting. ${all ? 'Both' : '$opposing of them'} recorded the '
          'OPPOSITE of $decisionPhrase: $against. '
          'Nobody listed below should be read as agreeing with this.';
    }
    // opposing is 0 here. Note recorded is NOT always agreeing + opposing +
    // undecided: a yes/no ballot against an 'undecided' decision lands in
    // recorded only. The view restricts to endorse/decline decisions so that
    // case cannot reach this sheet, but do not lean on the identity.
    final String breakdown;
    if (agreeing == 0) {
      breakdown = recorded == 1
          ? 'They did not take a position either way.'
          : 'None of them took a position either way.';
    } else if (undecided == 0) {
      breakdown = recorded == 1
          ? 'It matched $decisionPhrase.'
          : 'All $recorded matched $decisionPhrase.';
    } else {
      breakdown = '$agreeing matched $decisionPhrase and $undecided took no '
          'position either way.';
    }
    return '$who recorded an individual position on this candidate after the '
        'meeting. $breakdown Nobody else has recorded one, either way.';
  }
}

/// Dates on this surface, rendered in the committee's own zone
/// (America/Chicago) rather than the viewer's.
///
/// WHY NOT `toLocal()`. Every date this surface shows is a fact about one
/// Missouri committee: the evening they met, the morning the states were typed
/// in, the days two execs cast their ballots. All three are stored as UTC
/// instants that fall in the small hours or the evening of the neighbouring UTC
/// day, so a viewer east of UTC saw dates one day off, disagreeing with the
/// source note stored on the row itself.
///
/// WHY NOT A TIMEZONE PACKAGE. This needs one zone with a rule that has been
/// stable since 2007 and applies to a fixed set of 2026 instants. The US rule
/// is: CDT (UTC-5) from 02:00 local on the second Sunday in March to 02:00
/// local on the first Sunday in November, CST (UTC-6) otherwise. Expressed as
/// UTC instants those boundaries are 08:00 UTC (2am CST) and 07:00 UTC (2am
/// CDT). Nothing here is date-arithmetic sensitive enough to justify pulling in
/// and initialising a tz database.
abstract final class CommitteeLocalDate {
  /// The wall clock the committee saw, as a naive DateTime. Do not compare it
  /// to other instants; it is for formatting only.
  static DateTime wallClock(DateTime instant) {
    final u = instant.toUtc();
    return u.add(Duration(hours: _isCentralDst(u) ? -5 : -6));
  }

  /// 'Jul 14, 2026'.
  static String long(DateTime instant) {
    final d = wallClock(instant);
    return '${_monthAbbrev(d.month)} ${d.day}, ${d.year}';
  }

  /// 'Jul 14'.
  static String short(DateTime instant) {
    final d = wallClock(instant);
    return '${_monthAbbrev(d.month)} ${d.day}';
  }

  static bool _isCentralDst(DateTime utc) {
    final start = _nthSundayUtc(utc.year, 3, 2).add(const Duration(hours: 8));
    final end = _nthSundayUtc(utc.year, 11, 1).add(const Duration(hours: 7));
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static DateTime _nthSundayUtc(int year, int month, int n) {
    var d = DateTime.utc(year, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (n - 1)));
  }
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? _toTime(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// text[] from PostgREST arrives as a List; anything else claims nothing.
List<String> _toStringList(dynamic v) {
  if (v is! List) return const [];
  return v
      .map((e) => e?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// 'Chloé Ray and Elmedin Karamovic' / 'A, B and C'. Empty for an empty list,
/// so a caller that forgets to guard renders nothing rather than a dangling
/// conjunction.
String joinNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

String _monthAbbrev(int month) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][(month - 1).clamp(0, 11).toInt()];
