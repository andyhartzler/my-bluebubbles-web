import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/submission_review_model.dart';
import '../../../../theme/moyd_brand.dart';
import '../../decision_attribution_repository.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';

/// "Who was in the room": the provenance sheet behind a locked baseline
/// decision, in the [showDistrictMapSheet] idiom (solid navy surface, never
/// Theme.cardColor; white on navy is ~11:1, white-90 body text ~9:1, gold
/// accents carry navy text, and every pill is a self-contained MoydBrand
/// Fg-on-Bg pair that is legible on any surface).
///
/// THIS SHEET IS WHERE THE HONESTY LIVES, AND IT USED TO GET IT WRONG.
///
/// The previous version pinned the sentence "These decisions reflect the
/// consensus of the people present" above a list of named, photographed execs.
/// For at least two of the 23 decisions that was false. On Hans Peter the
/// meeting transcript has Elmedin Karamovic saying "I'm going based off of
/// vibes and saying we endorse him", Chloé Ray saying "Hans is cool, though"
/// and James Skaggs saying "he's a good Democrat", after which the chair says
/// "he got a low score" and "I already filtered him out. There's nothing we can
/// do." The stored decision is DECLINE. That sheet would have put three real
/// people's names and faces under a decision they audibly opposed.
///
/// AND THE SECOND VERSION GOT A SECOND SENTENCE WRONG THE SAME WAY.
///
/// It replaced the consensus claim with a pinned, non-scrolling subtitle ending
/// "so nobody below is recorded as having voted either way", shown above the
/// attendee list on all 23 sheets. That is false on 9 of them.
/// public.endorsement_votes holds 18 individual ballots on these exact
/// decisions, cast by Chloé Ray on 2026-07-17 and Elmedin Karamovic on
/// 2026-07-18 (both UTC; both the evening of Jul 17 in Missouri, which is the
/// date the tiles render), and both of them appear by name and photo in the
/// list directly underneath that sentence. On Tara Childress Lopez Hallmark
/// and Don Crozier they are both recorded voting YES against a stored DECLINE,
/// so the sentence
/// did not merely overreach, it concealed the one record that contradicts the
/// decision the reader was looking at.
///
/// So this sheet now:
///  * never claims consensus anywhere, for any row;
///  * pins ONLY what is true of every one of the 23 rows, and says nothing
///    about voting in the pinned area at all;
///  * leads with a per-decision basis block that states what the recording
///    actually supports, including "the room wanted the opposite";
///  * follows it with a per-decision BALLOT block generated from the data,
///    which names the people who later recorded an individual position and the
///    people who recorded the opposite one, and which says "nobody has recorded
///    an individual position" only on the rows where that is true;
///  * on a contested decision, on either axis, says in as many words that the
///    people listed below must not be read as agreeing, and repeats the ballot
///    fact on that person's own tile;
///  * splits the attendee list by whether each person was in the room WHEN
///    THIS CANDIDATE was dealt with, renders "uncertain" as uncertain rather
///    than rounding it into a claim, and gives "could not be established" its
///    own neutral heading rather than folding it under a positive one;
///  * keeps identity confidence, attendance duration, per-decision presence and
///    the later ballot as four separate things, because collapsing them is how
///    both earlier versions went wrong.
/// The typist is rendered last and visually secondary, so "whose account the
/// app last stamped" can never read as "who authored the judgment".
Future<void> showAttributionSheet(
  BuildContext context, {
  required CandidateEntry entry,
  required String displayName,
  required DecisionRecord record,
  required CandidateAttribution attribution,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _AttributionSheet(
      entry: entry,
      displayName: displayName,
      record: record,
      attribution: attribution,
    ),
  );
}

// On-navy text colors, matching the district sheet's treatment.
const _white90 = Color(0xE6FFFFFF);
const _white70 = Color(0xB3FFFFFF);

class _AttributionSheet extends StatelessWidget {
  final CandidateEntry entry;
  final String displayName;
  final DecisionRecord record;
  final CandidateAttribution attribution;

  const _AttributionSheet({
    required this.entry,
    required this.displayName,
    required this.record,
    required this.attribution,
  });

  /// The out-of-band recovery burst: all 23 states were written between
  /// 2026-07-15 15:40:33 and 15:40:47 UTC. Copy may only narrate that event for
  /// a row whose timestamp still falls inside it. The moment anyone edits one
  /// of these rows through the app, updated_at moves out of the window and the
  /// narrative becomes false, so it is gated rather than assumed.
  static final DateTime _recoveryStart = DateTime.utc(2026, 7, 15, 15, 40);
  static final DateTime _recoveryEnd = DateTime.utc(2026, 7, 15, 15, 41);

  bool get _inRecoveryBurst {
    final d = record.updatedAt?.toUtc();
    if (d == null) return false;
    return !d.isBefore(_recoveryStart) && d.isBefore(_recoveryEnd);
  }

  @override
  Widget build(BuildContext context) {
    final meeting = attribution.meeting;
    final inRoom = attribution.attendeesInRoom;
    final uncertain =
        attribution.attendeesWhere(DecisionPresence.uncertain);
    final absent = attribution.attendeesWhere(DecisionPresence.absent);
    final unestablished = attribution.attendeesPresenceNotEstablished;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.40,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: HubTheme.navy,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: HubTheme.gold.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.50),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Title + close. The subtitle stays pinned above the scroll area,
            // so whatever it says is said over every row without exception.
            // That is exactly why it may now say only the two things that are
            // true of all 23: no roll call was taken in the meeting, and the
            // states were typed in afterwards from the video.
            //
            // IT USED TO CARRY A THIRD CLAUSE, "so nobody below is recorded as
            // having voted either way", and that clause was false on 9 of the
            // 23 and actively concealing on 2 of them. It is not softened here,
            // it is REMOVED: the truth about voting differs per candidate and
            // per person, so it belongs in _ballotBlock and on the tiles, where
            // it is generated from public.endorsement_votes, and nowhere else.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Where this decision came from',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text(
                          'No per-candidate roll call was taken in the '
                          'meeting. These states were entered from the '
                          'recording afterwards.',
                          style: TextStyle(
                              color: _white90, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _candidateContext(),
                  const SizedBox(height: 12),
                  _basisBlock(),
                  const SizedBox(height: 12),
                  _ballotBlock(),
                  const SizedBox(height: 12),
                  _meetingCard(meeting),
                  const SizedBox(height: 16),
                  if (inRoom.isNotEmpty) ...[
                    // The stronger label is used ONLY when the view actually
                    // answered the per-decision presence question. Against an
                    // older migration it falls back to "on the call", which is
                    // all that data can support. Attendees whose presence could
                    // not be computed are NOT in this list; they have their own
                    // heading below, so a positive claim is never made over a
                    // row that did not resolve.
                    _sectionLabel(attribution.hasPerDecisionPresence
                        ? 'IN THE ROOM WHEN THIS CAME UP · ${inRoom.length}'
                        : 'ON THE CALL · ${inRoom.length}'),
                    if (attribution.contested) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Listed because they were on the call, not because '
                        'they agreed.',
                        style: TextStyle(
                            color: _white90, fontSize: 11.5, height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 4),
                    for (final a in inRoom) _tile(a, meeting),
                  ],
                  if (uncertain.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionLabel('PRESENCE UNCERTAIN · ${uncertain.length}'),
                    const SizedBox(height: 4),
                    // Two different truths hide in this group. Someone whose
                    // secondsStayedAfterStart is POSITIVE was demonstrably in
                    // the room when the candidate came up, and only the tail
                    // edge is inside the calibration margin. Saying nothing
                    // can be established about them under-claims what the
                    // recording actually shows, so the two cases get their
                    // own sentences.
                    Text(
                      uncertain.every((a) =>
                              (attribution
                                      .presenceFor(a.memberId)
                                      .secondsStayedAfterStart ??
                                  0) >
                              0)
                          ? 'The recording places them in the room when this '
                              'candidate came up, but cannot say whether they '
                              'were still there when it finished. It carries '
                              'no timestamps, so the edges are estimated.'
                          : 'Their join or leave time lands within the margin '
                              'of error of the recording, which carries no '
                              'timestamps. For some of them, whether they '
                              'heard this candidate discussed cannot be '
                              'established either way.',
                      style: const TextStyle(
                          color: _white90, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    for (final a in uncertain) _tile(a, meeting),
                  ],
                  if (absent.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionLabel('NOT IN THE ROOM FOR THIS · ${absent.length}'),
                    const SizedBox(height: 4),
                    const Text(
                      'On the call, but not while this candidate was dealt '
                      'with. This decision is not attributed to them.',
                      style: TextStyle(
                          color: _white90, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    for (final a in absent) _tile(a, meeting),
                  ],
                  if (unestablished.isNotEmpty) ...[
                    // Its own group, deliberately. Folding these in above would
                    // put a person under "IN THE ROOM WHEN THIS CAME UP" on the
                    // strength of the OTHER attendees having resolved. Not
                    // reachable on today's data, since all seven Zoom rows
                    // carry both times, but it is one missing timestamp away.
                    const SizedBox(height: 14),
                    _sectionLabel(
                        'PRESENCE NOT ESTABLISHED · ${unestablished.length}'),
                    const SizedBox(height: 4),
                    const Text(
                      'On the call, but their join or leave time is not '
                      'recorded, so whether they were in the room for this '
                      'candidate cannot be worked out at all. Not a claim '
                      'either way.',
                      style: TextStyle(
                          color: _white90, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    for (final a in unestablished) _tile(a, meeting),
                  ],
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  _entryBlock(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AttributionAttendee a, MeetingAttribution meeting) =>
      _AttendeeTile(
        attendee: a,
        meeting: meeting,
        presence: attribution.presenceFor(a.memberId),
        ballot: attribution.ballotFor(a.memberId),
      );

  /// Which decision this sheet is about: candidate face, name and the locked
  /// state chip (self-contained Fg-on-Bg, legible on navy).
  Widget _candidateContext() {
    return Row(
      children: [
        HeadshotAvatar(file: entry.headshot, name: displayName, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        DecisionChip(state: record.state, compact: true),
      ],
    );
  }

  /// The new load-bearing block: what the recording actually supports about
  /// THIS decision. Contested rows get a red-tinted card and an explicit
  /// warning; rows where the outcome was never spoken get amber; rows the room
  /// stated out loud get neutral slate. Every pairing is a self-contained
  /// MoydBrand Fg-on-Bg, so it is legible on navy and would remain legible on
  /// a light surface if this block is ever reused.
  ///
  /// COLOURED BY `basis.contested`, NOT BY THE UNION, AND THAT IS DELIBERATE.
  /// This block is the transcript's answer and only the transcript's. On Tara
  /// Childress Lopez Hallmark and Don Crozier it correctly renders amber
  /// ("the reason was stated, the outcome was not"), which is exactly what the
  /// recording shows, and the red ballot block immediately below carries the
  /// contradiction that comes from the other record. Painting this block red on
  /// those two rows would attribute the ballots' disagreement to the recording
  /// and lose the distinction the whole file is built to keep. Do not "fix"
  /// this to [CandidateAttribution.contested].
  Widget _basisBlock() {
    final basis = attribution.basis;
    final (fg, bg, icon) = basis.contested
        ? (MoydBrand.opposeFg, MoydBrand.opposeBg, Icons.report_problem_rounded)
        : basis.outcomeUnspoken
            ? (MoydBrand.qualifiedFg, MoydBrand.qualifiedBg,
                Icons.help_outline_rounded)
            : (MoydBrand.neutralFg, MoydBrand.neutralBg,
                Icons.record_voice_over_rounded);

    final evidence = attribution.basisEvidence;
    final turnLine = attribution.evidenceTurnLine;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 7),
              Expanded(
                child: Text(basis.headline,
                    style: TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(basis.detail,
              style: TextStyle(color: fg, fontSize: 12, height: 1.4)),
          if (evidence != null) ...[
            const SizedBox(height: 8),
            Container(
                height: 1, width: double.infinity, color: fg.withOpacity(0.20)),
            const SizedBox(height: 8),
            Text('FROM THE RECORDING',
                style: TextStyle(
                    color: fg.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
            const SizedBox(height: 4),
            Text(evidence,
                style: TextStyle(color: fg, fontSize: 11.5, height: 1.42)),
          ],
          if (turnLine != null) ...[
            const SizedBox(height: 6),
            Text('Dispositive passage: $turnLine.',
                style: TextStyle(
                    color: fg.withOpacity(0.85),
                    fontSize: 11,
                    height: 1.35,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  /// THE BLOCK THAT REPLACED THE FALSE PINNED SENTENCE.
  ///
  /// Every word of it is generated from public.endorsement_votes for THIS
  /// candidate, so it cannot be true of some rows and false of others the way
  /// one hard-coded sentence over 23 rows was. Three shapes:
  ///
  ///  * nobody has voted (14 of the 23): neutral slate, and it says so plainly
  ///    rather than the sheet staying silent, because "no individual ballot
  ///    exists" is itself the honest answer to "did these people agree";
  ///  * people voted and all matched (7 of the 23): neutral slate, named. NOT
  ///    green: agreement in a later ballot is corroboration of the decision,
  ///    not evidence that the room agreed at the time, and a support colour
  ///    here would quietly re-import the consensus claim this surface exists
  ///    to remove;
  ///  * someone voted the other way (2 of the 23, Tara Childress Lopez
  ///    Hallmark and Don Crozier): opposeFg on opposeBg with the warning glyph,
  ///    the dissenters named, and the explicit instruction not to read anybody
  ///    below as agreeing.
  ///
  /// Renders nothing at all against a migration that predates the ballot
  /// columns. Saying less is always allowed; a zero we cannot back is not.
  Widget _ballotBlock() {
    final b = attribution.ballotSummary;
    if (b == null) return const SizedBox.shrink();

    final (fg, bg, icon) = b.anyOpposing
        ? (MoydBrand.opposeFg, MoydBrand.opposeBg, Icons.report_problem_rounded)
        : (
            MoydBrand.neutralFg,
            MoydBrand.neutralBg,
            b.anyRecorded
                ? Icons.how_to_vote_rounded
                : Icons.remove_circle_outline
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 7),
              Expanded(
                child: Text(b.headline,
                    style: TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(b.detail,
              style: TextStyle(color: fg, fontSize: 12, height: 1.4)),
          if (b.anyRecorded) ...[
            const SizedBox(height: 6),
            Text(
              'Individual ballots are a separate record from the meeting. '
              'These were cast in the app days afterwards, not in the room.',
              style: TextStyle(
                  color: fg.withOpacity(0.85),
                  fontSize: 11,
                  height: 1.35,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meetingCard(MeetingAttribution meeting) {
    final parts = <String>[
      meeting.dateLabel,
      if (meeting.durationMinutes != null)
        '${meeting.durationMinutes} minutes',
    ];
    final presence = meeting.presenceLine;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meeting.meetingTitle ?? 'Executive Committee Meeting',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            presence == null
                ? parts.join(' · ')
                : '${parts.join(' · ')} · $presence',
            style: const TextStyle(color: _white90, fontSize: 12.5),
          ),
          if (meeting.recordingUrl != null) ...[
            const SizedBox(height: 6),
            // Gold text on navy (~6.5:1). 44px min target for phone taps.
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _launch(meeting.recordingUrl!),
                  style: TextButton.styleFrom(
                    foregroundColor: HubTheme.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Watch the recording'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: _white70,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1));

  /// "How this was entered", visually secondary by design: the typist must
  /// never be mistaken for the author of the judgment.
  ///
  /// The out-of-band recovery narrative is GATED on the row's timestamp still
  /// falling inside the known Jul 15 burst. An earlier version asserted it for
  /// any row carrying an app account stamp, which would have started lying the
  /// first time anyone edited a locked row through the app (both the note edit
  /// and the chair re-confirm paths restamp updated_at and updated_by).
  Widget _entryBlock() {
    final lines = <String>[];
    final appliedDate = _appliedDateLabel();
    final burst = _inRecoveryBurst;
    final writer = attribution.lastAppWriterName;

    if (attribution.entryAuthorUnrecorded) {
      lines.add(burst && appliedDate != null
          ? 'Entry author unrecorded. Applied $appliedDate from the meeting '
              'recording, outside the app.'
          : 'Entry author unrecorded. No account is stamped on this row, so it '
              'was not saved through the app.');
    } else if (writer != null) {
      lines.add(burst
          ? "Last saved under $writer's account, and this row's timestamp "
              'falls inside the recovery entry that ran outside the app. '
              'Whether that account entered this decision or was simply the '
              'last stamp left on the row is not recorded.'
          : "Last saved under $writer's account"
              "${appliedDate == null ? '' : ' on $appliedDate'}. Whether that "
              'is the original entry or a later edit is not recorded.');
      lines.add('No audit trail exists for these rows, so neither reading can '
          'be confirmed.');
    }

    final note = record.note.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('HOW THIS WAS ENTERED'),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line,
                style: const TextStyle(
                    color: _white90, fontSize: 12, height: 1.35)),
          ),
        if (note.isNotEmpty)
          Text('Source note: "$note"',
              style: const TextStyle(
                  color: _white70,
                  fontSize: 12,
                  height: 1.35,
                  fontStyle: FontStyle.italic)),
        if (lines.isEmpty && note.isEmpty)
          const Text('No entry metadata recorded.',
              style: TextStyle(color: _white70, fontSize: 12)),
      ],
    );
  }

  /// 'Jul 15' from the decision row's own updated_at, so the copy never
  /// hardcodes a date the data does not carry. Pinned to the committee's own
  /// zone, like every other date on this surface: these rows were typed in on a
  /// Missouri morning, and a viewer east of UTC read the following day.
  String? _appliedDateLabel() {
    final d = record.updatedAt;
    if (d == null) return null;
    return CommitteeLocalDate.short(d);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// One attendee: face, name, exec role, minutes present and the identity
/// confidence pill, with the hedge lines directly under the rows they qualify.
///
/// Four independent caveats can stack here and none may be folded into another:
/// identity ([AttributionAttendee.confidence]), whole-meeting attendance
/// ([AttributionAttendee.leftBeforeEnd] /
/// [AttributionAttendee.joinedAfterStart]), presence for THIS decision
/// ([AttendeePresence]) and this person's own later ballot on this candidate
/// ([AttendeeBallot]).
///
/// THE BALLOT LINE IS WHY THIS TILE MATTERS. Two of the people who appear here
/// are on record voting against two of the decisions their face sits under. The
/// paragraph above the list names them, and so does their own tile, because a
/// reader scanning faces should not have to scroll back up to find out that the
/// person they are looking at voted the other way.
class _AttendeeTile extends StatelessWidget {
  final AttributionAttendee attendee;
  final MeetingAttribution meeting;
  final AttendeePresence presence;

  /// This person's own later ballot on the candidate this sheet is about, or
  /// null when they never recorded one.
  final AttendeeBallot? ballot;

  const _AttendeeTile({
    required this.attendee,
    required this.meeting,
    required this.presence,
    required this.ballot,
  });

  @override
  Widget build(BuildContext context) {
    final a = attendee;
    // (line, flagged). A flagged line takes the self-contained oppose pair so
    // it cannot be skimmed past as one more footnote: it is the fact that this
    // named person is on record against the decision above it.
    final hedges = <(String, bool)>[];

    // Most specific first: what this tile is actually claiming about THIS
    // decision, then this person's own later ballot on it, then the
    // whole-meeting facts, then the identity caveat.
    final gap = presence.gapLine;
    if (gap != null) hedges.add((gap, false));

    if (presence.state == DecisionPresence.uncertain && gap == null) {
      hedges.add((
        'Joined or left close enough to this passage that the recording '
            'cannot place them either side of it.',
        false
      ));
    }

    final b = ballot;
    if (b != null) hedges.add((b.tileLine, b.opposes));

    if (a.joinedAfterStart) {
      final late = meeting.minutesAfterStart(a);
      hedges.add((
        late == null || late <= 0
            ? 'Joined after the meeting started.'
            : 'Joined $late minutes after the meeting started.',
        false
      ));
    }
    if (a.leftBeforeEnd) {
      final early = meeting.minutesBeforeEnd(a);
      hedges.add((
        early == null
            ? 'Left before the end of the meeting.'
            : 'Left $early minutes before the end of the meeting.',
        false
      ));
    }
    if (a.isTranscriptAssertion) {
      hedges.add((
        'Presence reconstructed from the recording. The Zoom record was lost '
            'to a defect in our own ingest, so the join and leave times shown '
            'are lower bounds, not measurements.',
        false
      ));
    }

    final minutes = a.minutesPresent;
    final total = meeting.durationMinutes;
    final String? minutesLabel;
    if (minutes == null) {
      minutesLabel = null;
    } else if ((a.leftBeforeEnd || a.joinedAfterStart) && total != null) {
      minutesLabel = '$minutes of $total min';
    } else {
      minutesLabel = '$minutes min';
    }

    final file = a.avatarUrl == null
        ? null
        : ReviewFile(url: a.avatarUrl!, name: a.name);

    // Absent and uncertain rows are visually de-emphasised so a glance at the
    // sheet cannot read them as part of the supporting group, but they stay
    // fully legible: 0.72 opacity of white-90 on navy still clears AA.
    final dim = presence.state == DecisionPresence.absent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Opacity(
                  opacity: dim ? 0.75 : 1,
                  child: HeadshotAvatar(file: file, name: a.name, size: 36),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: dim ? _white90 : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (a.roleLine.isNotEmpty)
                        Text(a.roleLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _white90, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (minutesLabel != null) ...[
                  Text(minutesLabel,
                      style:
                          const TextStyle(color: _white90, fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                _PresencePill(confidence: a.confidence),
              ],
            ),
          ),
          // Hedges sit inset under the identity column so they read as
          // qualifying THIS person, at white-90 (not dimmed: the caveat is
          // the payload, not a footnote). A flagged line gets the MoydBrand
          // oppose pair, which is AA on its own background regardless of the
          // navy behind it and holds if this tile is ever reused on a light
          // surface.
          for (final (hedge, flagged) in hedges)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 2, bottom: 2),
              child: flagged
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: MoydBrand.opposeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: MoydBrand.opposeFg.withOpacity(0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.report_problem_rounded,
                              size: 13, color: MoydBrand.opposeFg),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(hedge,
                                style: const TextStyle(
                                    color: MoydBrand.opposeFg,
                                    fontSize: 11.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    )
                  : Text(hedge,
                      style: const TextStyle(
                          color: _white90, fontSize: 11.5, height: 1.35)),
            ),
        ],
      ),
    );
  }
}

/// Self-contained identity-confidence pill. This grades HOW SURE WE ARE THAT
/// THIS ROW IS THIS PERSON, and nothing else: not how long they stayed, and not
/// whether they were there for the decision in front of you. MoydBrand Fg-on-Bg
/// pairs are AA on their own bg regardless of the surface behind them, so they
/// hold on navy:
///  * confirmed: supportFg on supportBg (green)
///  * reported:  neutralFg on neutralBg (slate)
///  * inferred:  qualifiedFg on qualifiedBg (amber)
class _PresencePill extends StatelessWidget {
  final PresenceConfidence confidence;
  const _PresencePill({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (confidence) {
      PresenceConfidence.confirmed =>
        (MoydBrand.supportFg, MoydBrand.supportBg),
      PresenceConfidence.reported => (MoydBrand.neutralFg, MoydBrand.neutralBg),
      PresenceConfidence.inferred =>
        (MoydBrand.qualifiedFg, MoydBrand.qualifiedBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.22)),
      ),
      child: Text(confidence.label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
