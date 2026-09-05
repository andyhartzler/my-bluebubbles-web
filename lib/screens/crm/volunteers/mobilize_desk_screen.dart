import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/bulk_send_result.dart';
import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/candidate_member_link.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/models/crm/outreach_touchpoint.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/candidate_member_link_repository.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';
import 'package:bluebubbles/services/crm/touchpoint_repository.dart';

import 'candidate_volunteers_map.dart' show DeskChanges;
import 'activity_detail_screen.dart';
import 'add_to_activity_sheet.dart';
import 'mobilize_composer.dart';
import 'mobilize_models.dart';
import 'organizing_toolkit_sheet.dart';
import 'volunteers_map_models.dart';
import 'volunteers_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  MOBILIZE DESK (Tab 2 of the War Room workspace)
//
//  Everything that sends or schedules used to hang off the map's members
//  action bar, which meant a bulk text was a full-screen route away from the
//  people it was going to and a plan was a modal on top of a map. The Desk is
//  where all of it lands instead: pick people on the map, press MOBILIZE, and
//  write the text, plan the canvass and work the audience in ONE scroll.
//
//  Three columns on a wide window: MY DESK (the exec's own work), the WORK
//  AREA (stacked sections, not sub-tabs), and the AUDIENCE. The sections are
//  stacked deliberately: nesting tabs inside a tab inside the CRM's own nav
//  would undo the whole point of bringing these surfaces together.
//
//  The Desk is a sibling of the map inside the workspace's IndexedStack, so
//  it stays MOUNTED across tab flips and an in-progress audience survives a
//  trip back to the map for ten more people. [active] is what keeps that from
//  costing a query on first frame: nothing is fetched until the Desk is first
//  shown or first handed an audience.
//
//  The WORDS are not written here. [MobilizeComposer] drives the composer,
//  the draft row's lifecycle and the send; this file owns the audience, the
//  nominees, the region, the acting exec and the geo those produce. The two
//  meet at [_draftFor], which is the only function that knows both halves.
//
//  What this file does HOLD of the composer's is [_draft], the words and the
//  row id themselves. The composer is a collapsible section body, so the
//  framework unmounts it for reasons that are not an exec abandoning the
//  message; keeping the draft here for the life of the Desk is what stops an
//  unmount losing it. See [MobilizeDraftState].
//
//  Every color resolves from [VolunteersTheme]. Never Theme.of(context).
// ═══════════════════════════════════════════════════════════════

/// Three columns fit above this; below it MY DESK collapses to an icon rail.
const double _kThreeColumnWidth = 1200;

/// Below this the Desk is a single column: the audience becomes a bottom
/// sheet and MY DESK opens from the header.
const double _kTwoColumnWidth = 840;

const double _kRailWidth = 300;
const double _kRailIconWidth = 56;
const double _kAudienceWideWidth = 340;
const double _kAudienceMediumWidth = 300;

/// The stacked sections of the work area, in render order.
enum _DeskSection { send, plan, connect }

/// A nominee somebody has linked members to, and how many. The Desk names
/// nominees this way rather than re-deriving November status from the
/// election results: the MAP owns that classification, and a second copy of
/// it would be free to disagree with the first.
typedef _LinkedNominee = ({Candidate candidate, int linkCount});

/// The collapsible groups of the MY DESK rail, in render order (spec 4.4).
enum _DeskGroup { drafts, sends, activities }

/// What the exec chose on a touchpoint's record card. An enum rather than a
/// bool because the card now carries up to four follow-ups and a bool would
/// have to grow a second one beside it.
enum _TouchpointAction {
  dismiss,
  retry,
  promote,
  openActivity,

  /// Interrupted sends only: the exec says what the send path never got to.
  markSent,
  markFailed,
}

class MobilizeDeskScreen extends StatefulWidget {
  const MobilizeDeskScreen({
    super.key,
    required this.handoff,
    required this.active,
    required this.onOpenMap,
    required this.onOpenActivities,
  });

  /// The map's one-way channel into the Desk. A new value is an audience
  /// arriving; the Desk consumes it and clears it so a later tab flip does
  /// not re-apply a stale audience.
  final ValueNotifier<MobilizeRequest?> handoff;

  /// Whether the Desk is the workspace's visible tab. The Desk is built on
  /// first frame whether or not it is opened, so this is what makes its data
  /// loads lazy.
  final bool active;

  final VoidCallback onOpenMap;
  final VoidCallback onOpenActivities;

  @override
  State<MobilizeDeskScreen> createState() => _MobilizeDeskScreenState();
}

class _MobilizeDeskScreenState extends State<MobilizeDeskScreen> {
  final OutreachRepository _outreach = OutreachRepository();
  final MemberRepository _memberRepo = MemberRepository();
  final TouchpointRepository _touchpoints = TouchpointRepository();
  final CandidateRepository _candidateRepo = CandidateRepository();
  final CandidateMemberLinkRepository _links =
      CandidateMemberLinkRepository();

  final ScrollController _workScroll = ScrollController();
  final Map<_DeskSection, GlobalKey> _sectionKeys = <_DeskSection, GlobalKey>{
    for (final s in _DeskSection.values) s: GlobalKey(),
  };

  // ── The audience ──────────────────────────────────────────────
  // Order is meaningful (it is the order the map handed them over in), so
  // this is a list with an id set for de-duping rather than a set.
  final List<Member> _audience = <Member>[];
  final List<Candidate> _nominees = <Candidate>[];
  MapMode? _regionMode;
  String? _regionId;
  String? _seedKind;
  String? _seedTitle;

  BulkSendChannel _channel = BulkSendChannel.sms;
  final Set<_DeskSection> _expanded = <_DeskSection>{_DeskSection.send};

  // ── The composer's draft ──────────────────────────────────────
  /// The words, the attachments and the draft row's id, held HERE rather than
  /// inside [MobilizeComposer]'s State.
  ///
  /// The composer is the body of a collapsible section inside a scrolling
  /// list, so the framework destroys its element whenever the SEND section is
  /// collapsed, the audience goes empty and the sections give way to the empty
  /// state, the section scrolls out of the viewport, or the window crosses a
  /// layout breakpoint into a different column tree. None of those is an exec
  /// abandoning a message, but while the draft lived in that State every one
  /// of them silently threw it away, and the next keystroke minted a second
  /// draft row for the same message and orphaned the first. Owning it for the
  /// life of the Desk is what makes that impossible rather than unlikely: the
  /// SEND section still collapses, it just no longer has anything to lose.
  final MobilizeDraftState _draft = MobilizeDraftState();

  /// Set when this audience came from "Retry the N that failed". A retry never
  /// mutates the original: it writes a new row pointing back at it (3.6). The
  /// composer never sees the id, it only reads [_retryOf] as a caption; the
  /// lineage is stamped here, at insert, by [_draftFor].
  String? _retryOf;

  /// A stored touchpoint waiting to be loaded into the composer. Handed over
  /// once and then cleared through [_onResumeConsumed], so a later rebuild
  /// cannot re-apply a draft the exec has moved on from.
  ComposerResume? _resume;

  // ── MY DESK ───────────────────────────────────────────────────
  bool _deskLoaded = false;
  bool _loadingMine = false;
  bool _mineErrored = false;
  List<OutreachActivity> _myActivities = const <OutreachActivity>[];

  bool _loadingTouchpoints = false;
  bool _touchpointsErrored = false;

  /// Unsent composer state plus interrupted sends, which the rail sorts above
  /// the drafts because they need a human decision (3.5).
  List<OutreachTouchpoint> _drafts = const <OutreachTouchpoint>[];
  List<OutreachTouchpoint> _recent = const <OutreachTouchpoint>[];

  /// Groups the exec has folded shut. Absent means open.
  final Set<_DeskGroup> _collapsed = <_DeskGroup>{};

  /// The rail's "Show the whole committee" toggle (4.4). Default is mine.
  ///
  /// It is a VIEW, not a permission: the RLS on outreach_touchpoints and
  /// outreach_activities is committee-wide already, deliberately, because
  /// Andrew asked that this work be tracked and monitored. All this does is
  /// drop the actor filter from the three rail queries, which is why one flag
  /// drives all three rather than each group carrying its own.
  bool _wholeCommittee = false;

  /// Open state of the medium-width overlay drawer.
  bool _railOpen = false;

  /// Planned/in-progress activities in the audience's region, for PLAN's
  /// "or add them to an existing activity (3 here)" line. Null until fetched.
  int? _regionActivityCount;

  // ── CONNECT ───────────────────────────────────────────────────
  /// Every stored link for each attached nominee, keyed by candidate id. The
  /// rows themselves rather than a count, because CONNECT renders the batches
  /// they group into and a second query for the same data would only give the
  /// two views a way to disagree.
  final Map<String, List<CandidateMemberLink>> _linksByNominee =
      <String, List<CandidateMemberLink>>{};

  /// members.id to name, for "by Andrew" on a batch line and for the author
  /// line the rail shows once it is scoped to the whole committee. ONE cache
  /// for both: they resolve the same ids from the same table, and two would
  /// only give the two surfaces a way to name the same exec differently.
  /// Cached across loads because the same handful of execs make every row.
  final Map<String, String> _memberNames = <String, String>{};

  bool _loadingLinks = false;
  bool _linksErrored = false;

  /// The nominee a link write is in flight for. One at a time, so a double
  /// tap cannot fire the same bulk insert twice.
  String? _linkBusyId;

  /// Nominees that already carry links, with their counts, for the audience
  /// source and the attach picker. Loaded on demand and dropped after any
  /// write, since a write is exactly what changes it.
  List<_LinkedNominee>? _linkedNomineeCache;

  @override
  void initState() {
    super.initState();
    widget.handoff.addListener(_onHandoff);
    // initState and didUpdateWidget both run inside the build phase, where
    // setState is illegal, so every first-load path leaves the frame first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onHandoff();
      if (widget.active) _requestDeskLoad();
    });
  }

  @override
  void didUpdateWidget(covariant MobilizeDeskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handoff != widget.handoff) {
      oldWidget.handoff.removeListener(_onHandoff);
      widget.handoff.addListener(_onHandoff);
    }
    if (widget.active) _requestDeskLoad();
  }

  @override
  void dispose() {
    widget.handoff.removeListener(_onHandoff);
    _workScroll.dispose();
    // The Desk is going for good, so the draft goes with it. Only here: the
    // composer detaches from these controllers on unmount, it never disposes
    // them.
    _draft.dispose();
    super.dispose();
  }

  // ── Handoff ───────────────────────────────────────────────────
  void _onHandoff() {
    final request = widget.handoff.value;
    if (request == null) return;

    setState(() {
      _audience
        ..clear()
        ..addAll(_deduped(request.members));
      _nominees
        ..clear()
        ..addAll(request.candidates);
      _regionMode = request.regionMode;
      _regionId = request.regionId;
      _seedKind = request.seedKind;
      _seedTitle = request.seedTitle;
      _regionActivityCount = null;
      // The words survive a trip back to the map: a handoff replaces WHO, not
      // WHAT, and the composer treats the new audience as a flush point rather
      // than a new row. What does not survive is the retry lineage, because a
      // fresh map selection is no longer a retry of anything.
      _retryOf = null;
      _expanded
        ..clear()
        ..add(_focusFor(request.intent));
      // A handoff of textable-only people should not land on a channel that
      // excludes half of them. Aim at the channel that reaches the most.
      _channel = _emailable.length > _textable.length
          ? BulkSendChannel.email
          : BulkSendChannel.sms;
    });

    _requestDeskLoad();
    _loadRegionActivityCount();
    unawaited(_syncLinks());

    // Clearing inside the listener would re-enter notifyListeners; do it once
    // the frame that consumed it is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(widget.handoff.value, request)) widget.handoff.value = null;
      _scrollTo(_focusFor(request.intent));
    });
  }

  _DeskSection _focusFor(MobilizeIntent intent) {
    switch (intent) {
      case MobilizeIntent.send:
        return _DeskSection.send;
      case MobilizeIntent.plan:
        return _DeskSection.plan;
      case MobilizeIntent.connect:
        return _DeskSection.connect;
    }
  }

  void _scrollTo(_DeskSection section) {
    final ctx = _sectionKeys[section]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 240), alignment: 0.02);
  }

  // ── Data ──────────────────────────────────────────────────────
  /// The lazy load, fired at most once: the Desk is mounted on the
  /// workspace's first frame whether or not anyone opens it, so this waits
  /// for the tab to be shown or for an audience to arrive.
  void _requestDeskLoad() {
    if (_deskLoaded) return;
    _deskLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDesk();
    });
  }

  /// Everything the rail shows: the exec's activities and their touchpoints.
  Future<void> _loadDesk() =>
      Future.wait(<Future<void>>[_loadMine(), _loadTouchpoints()]);

  bool get _loadingDesk => _loadingMine || _loadingTouchpoints;

  /// What the collapsed rail badges: work waiting on this exec.
  int get _deskBadge => _drafts.length + _myActivities.length;

  /// The acting exec, or null while the session is still resolving. Read from
  /// [UserSessionProvider] and nowhere else: a second session lookup path is
  /// how organizer_member_id ended up never being set on activities (4.1).
  MobilizeActor? _actorFrom(UserSessionProvider session) {
    final memberId = session.currentMember?.id;
    final userId = session.authUserId;
    if (memberId == null || userId == null) return null;
    return (memberId: memberId, userId: userId);
  }

  MobilizeActor? _actor() => _actorFrom(context.read<UserSessionProvider>());

  /// Whose work the rail is showing. Null is the whole committee (4.4).
  ///
  /// One definition, read by all three loads and by the rows themselves, so a
  /// group can never end up scoped differently from the toggle above it.
  String? _railScope(MobilizeActor actor) =>
      _wholeCommittee ? null : actor.memberId;

  Future<void> _loadTouchpoints() async {
    final actor = _actor();
    if (actor == null) return;
    if (!mounted) return;
    setState(() {
      _loadingTouchpoints = true;
      _touchpointsErrored = false;
    });
    try {
      final scope = _railScope(actor);
      final results = await Future.wait(<Future<List<OutreachTouchpoint>>>[
        _touchpoints.drafts(actorMemberId: scope),
        _touchpoints.recent(actorMemberId: scope),
      ]);
      final drafts = results[0]..sort(_interruptedFirst);
      final recent = results[1];
      // Only the committee view needs an author line, and only then is the
      // extra lookup worth making.
      if (scope == null) {
        await _cacheMemberNames(<String>{
          for (final t in drafts) t.actorMemberId,
          for (final t in recent) t.actorMemberId,
        });
      }
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _recent = recent;
        _loadingTouchpoints = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _drafts = const <OutreachTouchpoint>[];
        _recent = const <OutreachTouchpoint>[];
        _loadingTouchpoints = false;
        _touchpointsErrored = true;
      });
    }
  }

  /// Fill [_memberNames] for ids it does not already hold. One query, whatever
  /// the caller asks for, and a no-op once the handful of execs are cached.
  Future<void> _cacheMemberNames(Set<String> ids) async {
    final missing =
        ids.where((id) => id.isNotEmpty && !_memberNames.containsKey(id)).toList();
    if (missing.isEmpty) return;
    for (final m in await _memberRepo.membersByIds(missing)) {
      _memberNames[m.id] = m.name;
    }
  }

  /// The author line a rail row carries in the committee view. Empty in the
  /// "mine" view, where every row is the reader's own and saying so is noise.
  String _authorLine(String actorMemberId) {
    if (!_wholeCommittee) return '';
    return _memberNames[actorMemberId] ?? '';
  }

  /// Interrupted sends first, then the newest edit. An interrupted row is a
  /// send whose tab went away mid-flight, so it outranks everything.
  static int _interruptedFirst(OutreachTouchpoint a, OutreachTouchpoint b) {
    if (a.isInterrupted != b.isInterrupted) return a.isInterrupted ? -1 : 1;
    final ax = a.lastEditedAt;
    final bx = b.lastEditedAt;
    if (ax == null || bx == null) return 0;
    return bx.compareTo(ax);
  }

  Future<void> _loadMine() async {
    if (!mounted) return;
    setState(() {
      _loadingMine = true;
      _mineErrored = false;
    });
    try {
      // "Mine" means I RAN it, not "I was on the roster": the rail's job is to
      // show the exec their own work. organizer_member_id is stamped on every
      // create path now (4.2), so this is the column filter the spec asks for
      // rather than the participants join it used to stand in with. Inside the
      // try because a missing provider must land on the error note rather than
      // escape into the frame callback.
      final actor = _actorFrom(context.read<UserSessionProvider>());
      final rows = await _outreach.listActivities(
        organizerMemberId: actor == null ? null : _railScope(actor),
        limit: 100,
      );
      rows.sort(_upcomingFirst);
      if (_wholeCommittee) {
        await _cacheMemberNames(<String>{
          for (final a in rows)
            if (a.organizerMemberId != null) a.organizerMemberId!,
        });
      }
      if (!mounted) return;
      setState(() {
        _myActivities = rows;
        _loadingMine = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myActivities = const <OutreachActivity>[];
        _loadingMine = false;
        _mineErrored = true;
      });
    }
  }

  /// Soonest first, undated last.
  static int _upcomingFirst(OutreachActivity a, OutreachActivity b) {
    final ax = a.scheduledOn;
    final bx = b.scheduledOn;
    if (ax == null && bx == null) return 0;
    if (ax == null) return 1;
    if (bx == null) return -1;
    return ax.compareTo(bx);
  }

  Future<void> _loadRegionActivityCount() async {
    final mode = _regionMode;
    final id = _regionId;
    if (mode == null || id == null) return;
    try {
      final rows = await _outreach.activitiesForRegion(mode, id);
      if (!mounted) return;
      setState(() {
        _regionActivityCount = rows
            .where((a) => a.status == 'planned' || a.status == 'in_progress')
            .length;
      });
    } catch (_) {
      // A missing count only costs the "(3 here)" hint; the picker itself
      // still loads and reports for itself.
    }
  }

  // ── CONNECT data (5.5) ────────────────────────────────────────
  /// Reload every attached nominee's links. Called whenever [_nominees]
  /// changes and after every write, so the counts on screen are the counts in
  /// the table rather than an optimistic guess that survives a failed insert.
  Future<void> _syncLinks() async {
    final ids = _nominees.map((c) => c.id).toList();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _linksByNominee.clear();
        _linksErrored = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadingLinks = true;
      _linksErrored = false;
    });
    try {
      // One query per nominee, and a region carries a handful at most. A
      // single count query would still need a second one for the batches.
      final rows = await Future.wait(ids.map(_links.linksForCandidate));
      await _cacheMemberNames(<String>{
        for (final list in rows)
          for (final link in list)
            if (link.createdByMemberId != null) link.createdByMemberId!,
      });
      if (!mounted) return;
      setState(() {
        _linksByNominee
          ..clear()
          ..addEntries(<MapEntry<String, List<CandidateMemberLink>>>[
            for (var i = 0; i < ids.length; i++) MapEntry(ids[i], rows[i]),
          ]);
        _loadingLinks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLinks = false;
        _linksErrored = true;
      });
    }
  }

  int _linkCount(Candidate c) =>
      (_linksByNominee[c.id] ?? const <CandidateMemberLink>[]).length;

  List<CandidateMemberLinkBatch> _batchesFor(Candidate c) =>
      CandidateMemberLinkBatch.groupFrom(
          _linksByNominee[c.id] ?? const <CandidateMemberLink>[]);

  /// "Boone County, Sep 1, by Andrew". A batch made member by member has no
  /// region, so it reads "Picked by hand" rather than inventing one.
  String _batchLabel(CandidateMemberLinkBatch batch) {
    final mode = candidateLinkSourceMode(batch.sourceRegionMode);
    final regionId = batch.sourceRegionId;
    final author = _memberNames[batch.createdByMemberId];
    return <String>[
      mode != null && regionId != null
          ? mode.regionTitle(regionId)
          : 'Picked by hand',
      if (batch.createdAt != null) _fmtDate(batch.createdAt!.toLocal()),
      if (author != null) 'by $author',
      '${batch.memberCount} '
          '${batch.memberCount == 1 ? 'member' : 'members'}',
    ].join(' · ');
  }

  /// Run one link write, holding the nominee busy so a second tap cannot fire
  /// the same bulk insert, and reloading from the table afterwards.
  Future<void> _runLinkWrite(
      Candidate nominee, Future<String> Function(MobilizeActor) write) async {
    if (_linkBusyId != null) return;
    final actor = _actor();
    if (actor == null) {
      _snack('Your session is still loading. Try again in a moment.');
      return;
    }
    setState(() => _linkBusyId = nominee.id);
    try {
      final message = await write(actor);
      await _syncLinks();
      if (!mounted) return;
      _linkedNomineeCache = null;
      _snack(message);
    } catch (_) {
      if (mounted) _snack('That did not save. Please try again.');
    } finally {
      if (mounted) setState(() => _linkBusyId = null);
    }
  }

  /// "Link these 12 to Jane": the audience as it stands, individually sourced,
  /// so no region is stamped on the rows (spec 5.4).
  Future<void> _linkAudience(Candidate nominee) async {
    final people = List<Member>.from(_audience);
    if (people.isEmpty) return;
    await _runLinkWrite(nominee, (actor) async {
      final added = await _links.linkMembers(
        candidateId: nominee.id,
        memberIds: people.map((m) => m.id).toList(),
        actorUserId: actor.userId,
        actorMemberId: actor.memberId,
      );
      return added == 0
          ? 'Everyone on the audience was already linked to ${nominee.name}.'
          : 'Linked $added to ${nominee.name}.';
    });
  }

  /// "Link all of Boone County to Jane": the region's WHOLE member list, not
  /// the selection, stamped with the region that produced it.
  Future<void> _linkRegion(Candidate nominee) async {
    final mode = _regionMode;
    final id = _regionId;
    if (mode == null || id == null) return;
    await _runLinkWrite(nominee, (actor) async {
      final people = await _regionMembers(mode, id);
      if (people.isEmpty) return 'No members live in ${mode.regionTitle(id)}.';
      final added = await _links.linkMembers(
        candidateId: nominee.id,
        memberIds: people.map((m) => m.id).toList(),
        sourceMode: mode,
        sourceRegionId: id,
        actorUserId: actor.userId,
        actorMemberId: actor.memberId,
      );
      return added == 0
          ? 'All of ${mode.regionTitle(id)} was already linked to '
              '${nominee.name}.'
          : 'Linked $added from ${mode.regionTitle(id)} to ${nominee.name}.';
    });
  }

  /// "Refresh from Boone County". It cannot tell a member who was removed on
  /// purpose from one who was never added, so the confirm says so plainly
  /// rather than promising a merge it cannot perform (spec 5.4).
  Future<void> _refreshBatch(
      Candidate nominee, CandidateMemberLinkBatch batch) async {
    final mode = candidateLinkSourceMode(batch.sourceRegionMode);
    final id = batch.sourceRegionId;
    if (mode == null || id == null) return;
    final region = mode.regionTitle(id);
    final ok = await _confirm(
      title: 'Refresh from $region?',
      body: 'This adds members who have joined $region since. Anyone you '
          'removed by hand will come back.',
      confirmLabel: 'Refresh',
    );
    if (ok != true) return;
    await _runLinkWrite(nominee, (actor) async {
      final people = await _regionMembers(mode, id);
      if (people.isEmpty) return 'No members live in $region.';
      final added = await _links.linkMembers(
        candidateId: nominee.id,
        memberIds: people.map((m) => m.id).toList(),
        sourceMode: mode,
        sourceRegionId: id,
        actorUserId: actor.userId,
        actorMemberId: actor.memberId,
      );
      return added == 0
          ? 'Nobody new in $region.'
          : 'Added $added from $region to ${nominee.name}.';
    });
  }

  Future<void> _unlinkBatch(
      Candidate nominee, CandidateMemberLinkBatch batch) async {
    final ok = await _confirm(
      title: 'Unlink this batch?',
      body: '${_batchLabel(batch)} stops being part of '
          "${nominee.name}'s volunteer base. Anyone linked to them another "
          'way stays linked.',
      confirmLabel: 'Unlink',
    );
    if (ok != true) return;
    await _runLinkWrite(nominee, (_) async {
      final gone = await _links.unlinkBatch(batch.batchId);
      return gone == 1
          ? 'Unlinked 1 member from ${nominee.name}.'
          : 'Unlinked $gone members from ${nominee.name}.';
    });
  }

  /// The linked base, one row per member, with the single-row unlink on it.
  /// It is a dialog rather than an inline list because a linked county is
  /// hundreds of people and the section is one card in a scroll.
  Future<void> _reviewLinked(Candidate nominee) async {
    List<Member> people;
    try {
      people = await _links.linkedMembers(nominee.id);
    } catch (_) {
      _snack('Could not load who is linked to ${nominee.name}.');
      return;
    }
    if (!mounted) return;
    people.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    var changed = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          backgroundColor: BrandColors.unityBlue,
          shape: _dialogShape,
          titleTextStyle: BrandTextStyles.title,
          contentTextStyle: BrandTextStyles.bodySecondary,
          title: Text('Linked to ${nominee.name}'),
          content: SizedBox(
            width: 400,
            height: MediaQuery.of(dialogContext).size.height * 0.5,
            child: people.isEmpty
                ? const Text('Nobody is linked any more.',
                    style: BrandTextStyles.bodySecondary)
                : ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (_, i) {
                      final m = people[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.name, style: BrandTextStyles.body),
                        subtitle: Text(_memberSubline(m),
                            style: BrandTextStyles.caption),
                        trailing: IconButton(
                          tooltip: 'Unlink ${m.name}',
                          icon: const Icon(Icons.link_off,
                              size: 18, color: Colors.white70),
                          onPressed: () async {
                            try {
                              await _links.unlink(nominee.id, m.id);
                            } catch (_) {
                              _snack('Could not unlink ${m.name}.');
                              return;
                            }
                            changed = true;
                            setDialogState(() => people.removeAt(i));
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: BrandColors.sunriseGold),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );

    if (!changed || !mounted) return;
    _linkedNomineeCache = null;
    await _syncLinks();
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        shape: _dialogShape,
        titleTextStyle: BrandTextStyles.title,
        contentTextStyle: BrandTextStyles.bodySecondary,
        title: Text(title),
        content: SizedBox(width: 380, child: Text(body)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: BrandColors.sunriseGold),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Every nominee somebody has already linked members to, with the count.
  ///
  /// Nominee status is the MAP's classification: a nominee reaches the Desk
  /// attached to a handoff, and only an attached nominee can be linked to. So
  /// a candidate carrying links IS a nominee, and reading the link table back
  /// is how the Desk names nominees without a second copy of the map's
  /// result-row-to-profile matching, which would be free to drift from it.
  Future<List<_LinkedNominee>> _loadLinkedNominees() async {
    final cached = _linkedNomineeCache;
    if (cached != null) return cached;
    final all = await _candidateRepo.fetchAllCandidates();
    final counts =
        await _links.linkCountsForCandidates(all.map((c) => c.id).toList());
    final out = <_LinkedNominee>[
      for (final c in all)
        if ((counts[c.id] ?? 0) > 0)
          (candidate: c, linkCount: counts[c.id] ?? 0),
    ]..sort((a, b) => a.candidate.name
        .toLowerCase()
        .compareTo(b.candidate.name.toLowerCase()));
    _linkedNomineeCache = out;
    return out;
  }

  Future<Candidate?> _pickLinkedNominee(String title) async {
    List<_LinkedNominee> options;
    try {
      options = await _loadLinkedNominees();
    } catch (_) {
      _snack('Could not load the nominees.');
      return null;
    }
    if (!mounted) return null;
    if (options.isEmpty) {
      _snack('Nobody is linked to a nominee yet. Attach one from the map, '
          'then link this audience to them.');
      return null;
    }
    return showDialog<Candidate>(
      context: context,
      builder: (dialogContext) =>
          _LinkedNomineeDialog(title: title, options: options),
    );
  }

  /// Attach a nominee the exec has already linked members to, so CONNECT can
  /// work on a base without a trip through the map.
  Future<void> _attachNominee() async {
    final picked = await _pickLinkedNominee('Attach a nominee');
    if (picked == null || !mounted) return;
    if (_nominees.any((c) => c.id == picked.id)) {
      _snack('${picked.name} is already attached.');
      return;
    }
    setState(() => _nominees.add(picked));
    await _syncLinks();
  }

  // ── Audience maths ────────────────────────────────────────────
  List<Member> _deduped(Iterable<Member> people) {
    final seen = <String>{};
    return people.where((m) => seen.add(m.id)).toList();
  }

  void _appendToAudience(Iterable<Member> people) {
    final seen = _audience.map((m) => m.id).toSet();
    final fresh = people.where((m) => seen.add(m.id)).toList();
    if (fresh.isEmpty) {
      _snack('Everyone there is already on the audience.');
      return;
    }
    setState(() => _audience.addAll(fresh));
    _snack('Added ${fresh.length} to the audience.');
  }

  List<Member> get _textable => _audience
      .where((m) => ComposerSkip.eligible(m, BulkSendChannel.sms))
      .toList();

  List<Member> get _emailable => _audience
      .where((m) => ComposerSkip.eligible(m, BulkSendChannel.email))
      .toList();

  List<Member> get _eligible =>
      _channel == BulkSendChannel.sms ? _textable : _emailable;

  String? get _regionLabel {
    final mode = _regionMode;
    final id = _regionId;
    if (mode == null || id == null) return null;
    return mode.regionTitle(id);
  }

  MobilizeRequest get _currentRequest => MobilizeRequest(
        members: List<Member>.unmodifiable(_audience),
        candidates: List<Candidate>.unmodifiable(_nominees),
        regionMode: _regionMode,
        regionId: _regionId,
        seedKind: _seedKind,
        seedTitle: _seedTitle,
      );

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Actions ───────────────────────────────────────────────────
  /// The composer's row, built from the two halves that only meet here: what
  /// the exec wrote and who it is going to (the composer's), and where those
  /// people are, which nominees it is for and what it retries (the Desk's).
  ///
  /// There is no prompt anywhere on this path. The row is written because the
  /// exec is writing, and resolved because the send happened (spec 3.7).
  TouchpointDraft _draftFor(
    ComposerContent content,
    List<Member> recipients,
    MobilizeActor actor,
  ) {
    final counties = <String>[];
    final congressional = <String>[];
    final senate = <String>[];
    final house = <String>[];

    // The map's own selected key first.
    final mode = _regionMode;
    final regionId = _regionId;
    if (mode != null && regionId != null && regionId.isNotEmpty) {
      switch (mode) {
        case MapMode.county:
          counties.add(regionId);
          break;
        case MapMode.congressional:
          congressional.add(regionId);
          break;
        case MapMode.senate:
          senate.add(regionId);
          break;
        case MapMode.house:
          house.add(regionId);
          break;
      }
    }

    // Then everywhere the recipients themselves sit, so an ad-hoc
    // cross-region audience still reaches the region sections the map
    // selection alone could never describe (3.4). TouchpointDraft dedupes
    // these and caps each array at 25.
    for (final m in recipients) {
      final county = Member.normalizeCountyLabel(m.county);
      if (county != null && county.isNotEmpty) counties.add(county);
      _addDistrictKey(congressional, m.congressionalDistrict);
      _addDistrictKey(senate, m.senateDistrict);
      _addDistrictKey(house, m.houseDistrict);
    }

    return TouchpointDraft(
      // BulkSendChannel.name is exactly the stored value the column checks, so
      // the enum travels rather than a hand-written label.
      channel: content.channel.name,
      actorMemberId: actor.memberId,
      actorUserId: actor.userId,
      subject: content.subject,
      bodyText: content.bodyText,
      bodyHtml: content.bodyHtml,
      recipientMemberIds: recipients.map((m) => m.id).toList(),
      candidateIds: _nominees.map((c) => c.id).toList(),
      counties: counties,
      congressionalDistricts: congressional,
      senateDistricts: senate,
      houseDistricts: house,
      retryOf: _retryOf,
    );
  }

  /// A member's district string in the map's own key form. [bareDigits] is the
  /// normalizer the GeoJSON ids and the member-count keys already share, so a
  /// key written here matches a RegionData.id in all four modes. A value with
  /// no digit in it cannot be a district key and is dropped rather than
  /// written as junk the GIN index will never be asked for.
  static void _addDistrictKey(List<String> into, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || !RegExp(r'\d').hasMatch(value)) return;
    final key = bareDigits(value);
    if (key.isNotEmpty) into.add(key);
  }

  /// Member rows for a stored id list, in the stored order. Ids already on the
  /// audience cost nothing; only the rest are fetched. An id that no longer
  /// resolves is dropped, never rendered as an "Unknown member" row (4.3).
  Future<List<Member>> _resolveRecipients(List<String> ids) async {
    if (ids.isEmpty) return const <Member>[];
    final known = <String, Member>{for (final m in _audience) m.id: m};
    final missing = ids.where((id) => !known.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      for (final m in await _memberRepo.membersByIds(missing)) {
        known[m.id] = m;
      }
    }
    return ids.map((id) => known[id]).whereType<Member>().toList();
  }

  /// Nominees for a stored id list. A draft carries a handful at most, so
  /// single fetches beat a second list query, and resolving them is what stops
  /// a resumed draft from silently dropping its candidate_ids on the next save.
  Future<List<Candidate>> _resolveNominees(List<String> ids) async {
    if (ids.isEmpty) return const <Candidate>[];
    final known = <String, Candidate>{for (final c in _nominees) c.id: c};
    final out = <Candidate>[];
    for (final id in ids) {
      final have = known[id];
      if (have != null) {
        out.add(have);
        continue;
      }
      final fetched = await _candidateRepo.fetchCandidate(id);
      if (fetched != null) out.add(fetched);
    }
    return out;
  }

  /// Pick a draft back up. The Desk's own region selection is left alone: a
  /// draft's geo arrays are a UNION of a map selection and every recipient's
  /// own districts, so there is no single region key to reconstruct from them.
  ///
  /// The recipients are RE-FETCHED rather than trusted, because the point of
  /// resumption is that the world moved: somebody opted out, lost a phone
  /// number or left the roster while the draft sat. Ids that no longer resolve
  /// are dropped and counted; the composer reports both that count and anyone
  /// who can no longer be reached on the channel (spec 4.3).
  Future<void> _continueDraft(OutreachTouchpoint touchpoint) async {
    await _loadResume(touchpoint, ComposerResumeMode.continueDraft);
  }

  /// Load the failures of a resolved send as a fresh audience. The original is
  /// never mutated: the next Send writes a new row that points back at it, so
  /// the trail stays two honest records rather than one rewritten one (3.6).
  Future<void> _retryFailures(OutreachTouchpoint touchpoint) async {
    await _loadResume(touchpoint, ComposerResumeMode.retry);
  }

  // ── Promotion (spec 3.1, Phase 6) ─────────────────────────────
  /// "Log this as an activity". THE promotion path: the composer's result card
  /// and the rail's send card both come here, so there is one definition of
  /// what promoting means and one place it can be wrong.
  ///
  /// The RPC does the whole thing in one transaction and is idempotent, so a
  /// second press on a stale card returns the activity the first press wrote
  /// rather than a duplicate. Nothing is copied: the words stay on the
  /// touchpoint and the activity carries its id.
  ///
  /// Offered only on the acting exec's OWN sends. The activity is stamped with
  /// the caller as both organizer and creator, and stamping one exec as the
  /// organizer of another's outreach would be a lie in the audit trail.
  Future<bool> _promote(OutreachTouchpoint touchpoint) async {
    final actor = _actor();
    if (actor == null) {
      _snack('Still signing you in. Try again in a moment.');
      return false;
    }

    String? activityId;
    try {
      activityId = await _touchpoints.promoteToActivity(
        touchpoint.id,
        actorUserId: actor.userId,
        actorMemberId: actor.memberId,
      );
    } catch (_) {
      if (mounted) _snack('Could not log that as an activity. Try again.');
      return false;
    }
    if (!mounted) return false;
    if (activityId == null) {
      _snack('Could not log that as an activity. Try again.');
      return false;
    }

    await _loadDesk();
    if (!mounted) return true;
    _snack('Logged as an activity.');
    await _openActivityById(activityId);
    return true;
  }

  /// The composer's "Log this as an activity", which arrives as an id rather
  /// than a row because the composer holds the outcome and not the record.
  /// Returns whether the activity was written, so the card can settle.
  Future<bool> _promoteById(String touchpointId) async {
    final match =
        _recent.where((t) => t.id == touchpointId).toList(growable: false);
    if (match.isNotEmpty) return _promote(match.first);

    // The rail has not caught up with the send yet. Reload once, then look
    // again rather than inventing a second promotion path off the raw id.
    await _loadTouchpoints();
    final refreshed =
        _recent.where((t) => t.id == touchpointId).toList(growable: false);
    if (refreshed.isEmpty) {
      if (mounted) _snack('That send is not on your desk yet. Try again.');
      return false;
    }
    return _promote(refreshed.first);
  }

  /// Open an activity the Desk knows only the id of. A promotion returns an
  /// id, and the detail screen takes a row.
  Future<void> _openActivityById(String activityId) async {
    OutreachActivity? activity;
    try {
      activity = await _outreach.activityById(activityId);
    } catch (_) {
      activity = null;
    }
    if (!mounted) return;
    if (activity == null) {
      _snack('The activity was saved. Open it from MY ACTIVITIES.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ActivityDetailScreen(activity: activity!),
    ));
    if (mounted) await _loadMine();
  }

  /// Close out a send whose tab went away mid-flight (3.5). Nothing in the
  /// system knows what the provider did, and nothing ever will, so the exec
  /// says and the row records that a human said it. Never automatic: an
  /// automatic resend of an unknown-state bulk text is how members get the
  /// same message twice.
  Future<void> _resolveInterrupted(
      OutreachTouchpoint touchpoint, bool reached) async {
    try {
      await _touchpoints.resolveInterrupted(
        touchpoint.id,
        TouchpointSendOutcome.recordedByHand(
          reached: reached,
          recipientMemberIds: touchpoint.recipientMemberIds,
        ),
      );
    } catch (_) {
      if (mounted) _snack('Could not close that out. Try again.');
      return;
    }
    if (!mounted) return;
    _snack(reached
        ? 'Recorded as sent.'
        : 'Recorded as failed. You can retry it from MY DESK.');
    await _loadTouchpoints();
  }

  /// The composer's own "Retry the N that failed", which arrives as ids rather
  /// than as a row because the composer holds the outcome and not the record.
  Future<void> _retryFailedIds(
      String touchpointId, List<String> failedMemberIds) async {
    final people = await _resolveRecipients(failedMemberIds);
    if (!mounted) return;
    if (people.isEmpty) {
      _snack('None of the failed recipients are still on file.');
      return;
    }
    setState(() {
      _audience
        ..clear()
        ..addAll(people);
      // The lineage, not the row: the composer starts a NEW draft and the next
      // insert stamps retry_of from here.
      _retryOf = touchpointId;
    });
    _scrollTo(_DeskSection.send);
  }

  Future<void> _loadResume(
      OutreachTouchpoint touchpoint, ComposerResumeMode mode) async {
    final ids = mode == ComposerResumeMode.retry
        ? touchpoint.failedMemberIds
        : touchpoint.recipientMemberIds;
    final people = await _resolveRecipients(ids);
    final nominees = await _resolveNominees(touchpoint.candidateIds);
    if (!mounted) return;

    if (mode == ComposerResumeMode.retry && people.isEmpty) {
      _snack('None of the failed recipients are still on file.');
      return;
    }

    setState(() {
      _audience
        ..clear()
        ..addAll(people);
      _nominees
        ..clear()
        ..addAll(nominees);
      _channel = touchpoint.channel == BulkSendChannel.email.name
          ? BulkSendChannel.email
          : BulkSendChannel.sms;
      _retryOf =
          mode == ComposerResumeMode.retry ? touchpoint.id : touchpoint.retryOf;
      _resume = ComposerResume(
        touchpoint: touchpoint,
        mode: mode,
        droppedCount: ids.length - people.length,
      );
      _expanded
        ..clear()
        ..add(_DeskSection.send);
    });
    _scrollTo(_DeskSection.send);
    unawaited(_syncLinks());
  }

  /// The composer has taken the resume; clearing it stops a later rebuild
  /// re-applying a draft the exec has moved on from.
  void _onResumeConsumed() {
    if (_resume == null) return;
    setState(() => _resume = null);
  }

  /// The inline PLAN form saved. Same follow-up whichever container it was in.
  Future<void> _onActivitySaved() async {
    if (!mounted) return;
    _deskLoaded = true;
    _snack('Activity saved.');
    // Re-pointing the Organizing Plays at the Desk removed the map's old
    // "if saved, reload coverage" path, so without this the activity dots, the
    // region chip and the This Week rail stay stale.
    DeskChanges.notifyWritten();
    await _loadMine();
    await _loadRegionActivityCount();
  }

  Future<void> _addToExistingActivity() async {
    final mode = _regionMode;
    final id = _regionId;
    if (mode == null || id == null || _audience.isEmpty) return;

    final choice = await AddToActivitySheet.show(
      context,
      mode: mode,
      regionId: id,
      members: _audience,
    );
    if (!mounted || choice == null) return;

    switch (choice.kind) {
      case AddToActivityKind.added:
        _snack(choice.addedCount > 0
            ? 'Added ${choice.addedCount} to ${choice.title}'
            : 'Everyone on the audience was already on ${choice.title}');
        await _loadMine();
        break;
      case AddToActivityKind.failed:
        _snack('Could not add to ${choice.title}. Please try again.');
        break;
      case AddToActivityKind.newActivity:
        // The sheet's "none of these, start a new one". The form is already on
        // the page below; scroll to it rather than raising a second one.
        setState(() => _expanded.add(_DeskSection.plan));
        _scrollTo(_DeskSection.plan);
        break;
    }
  }

  // ── Audience sources (6.5) ────────────────────────────────────
  Future<void> _addEveryoneInRegion() async {
    final mode = _regionMode;
    final id = _regionId;
    if (mode == null || id == null) return;
    try {
      final people = await _regionMembers(mode, id);
      if (!mounted) return;
      _appendToAudience(people);
    } catch (_) {
      _snack('Could not load that region.');
    }
  }

  Future<List<Member>> _regionMembers(MapMode mode, String id) async {
    switch (mode) {
      case MapMode.county:
        return _memberRepo.getMembersInCounties(<String>[id]);
      case MapMode.house:
        return _memberRepo.getMembersInHouseDistricts(<String>[id]);
      case MapMode.senate:
        return _memberRepo.getMembersInSenateDistricts(<String>[id]);
      case MapMode.congressional:
        final result =
            await _memberRepo.getAllMembers(congressionalDistrict: 'CD-$id');
        return result.members;
    }
  }

  /// "Everyone linked to {nominee}" (5.5). The nominee is attached as well as
  /// consumed, because an exec who pulled a base up is about to work on it.
  Future<void> _addLinkedToNominee() async {
    final picked = await _pickLinkedNominee('Everyone linked to a nominee');
    if (picked == null || !mounted) return;
    List<Member> people;
    try {
      people = await _links.linkedMembers(picked.id);
    } catch (_) {
      _snack('Could not load who is linked to ${picked.name}.');
      return;
    }
    if (!mounted) return;
    if (people.isEmpty) {
      _snack('Nobody is linked to ${picked.name} any more.');
      return;
    }
    if (!_nominees.any((c) => c.id == picked.id)) {
      setState(() => _nominees.add(picked));
    }
    _appendToAudience(people);
    await _syncLinks();
  }

  Future<void> _addCommittee() async {
    final committees = await _memberRepo.getUniqueCommittees();
    if (!mounted) return;
    if (committees.isEmpty) {
      _snack('No committees on file.');
      return;
    }
    final picked = await _pickOne<String>(
      title: 'Members of a committee',
      options: committees,
      labelOf: (c) => c,
    );
    if (picked == null || !mounted) return;
    final result = await _memberRepo
        .getAllMembers(committees: <String>[picked], fetchAll: true);
    if (!mounted) return;
    _appendToAudience(result.members);
  }

  Future<void> _addActivityRoster() async {
    final activities = await _outreach.listActivities(limit: 60);
    if (!mounted) return;
    if (activities.isEmpty) {
      _snack('No activities to pull a roster from.');
      return;
    }
    activities.sort(_upcomingFirst);
    final picked = await _pickOne<OutreachActivity>(
      title: 'The roster of an activity',
      options: activities,
      labelOf: (a) => a.title,
      subtitleOf: (a) => a.scheduledOn == null
          ? a.kindLabel
          : '${_fmtDate(a.scheduledOn!)} · ${a.kindLabel}',
    );
    if (picked == null || !mounted) return;
    final roster = await _outreach.getRoster(picked.id);
    if (!mounted) return;
    if (roster.isEmpty) {
      _snack('${picked.title} has nobody on its roster.');
      return;
    }
    final people =
        await _memberRepo.membersByIds(roster.map((e) => e.memberId).toList());
    if (!mounted) return;
    _appendToAudience(people);
  }

  Future<T?> _pickOne<T>({
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    String Function(T)? subtitleOf,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: BrandColors.unityBlue,
        shape: _dialogShape,
        title: Text(title, style: BrandTextStyles.title),
        children: [
          SizedBox(
            width: 380,
            // A fixed height would overflow a short window; half the viewport
            // leaves room for the dialog's own chrome on every screen.
            height: MediaQuery.of(dialogContext).size.height * 0.5,
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (_, i) {
                final option = options[i];
                final subtitle = subtitleOf?.call(option);
                return ListTile(
                  dense: true,
                  title:
                      Text(labelOf(option), style: BrandTextStyles.body),
                  subtitle: subtitle == null
                      ? null
                      : Text(subtitle, style: BrandTextStyles.caption),
                  onTap: () => Navigator.pop(dialogContext, option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSkipDetails() async {
    final isText = _channel == BulkSendChannel.sms;
    final skipped = _audience
        .where((m) => !ComposerSkip.eligible(m, _channel))
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        shape: _dialogShape,
        titleTextStyle: BrandTextStyles.title,
        contentTextStyle: BrandTextStyles.bodySecondary,
        title: Text(isText ? "Can't be texted" : "Can't be emailed"),
        content: SizedBox(
          width: double.maxFinite,
          child: skipped.isEmpty
              ? const Text('Nobody is skipped.')
              : ListView(
                  shrinkWrap: true,
                  children: skipped
                      .map((m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title:
                                Text(m.name, style: BrandTextStyles.body),
                            subtitle: Text(
                                ComposerSkip.reason(m, _channel),
                                style: BrandTextStyles.caption),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: BrandColors.sunriseGold),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);
    return Container(
      color: vt.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _kThreeColumnWidth) return _wide(vt);
          if (constraints.maxWidth >= _kTwoColumnWidth) return _medium(vt);
          return _narrow(vt);
        },
      ),
    );
  }

  Widget _seam(VolunteersTheme vt) => Container(width: 1, color: vt.divider);

  Widget _wide(VolunteersTheme vt) => Row(
        children: [
          SizedBox(width: _kRailWidth, child: _rail(vt)),
          _seam(vt),
          Expanded(child: _workArea(vt, narrow: false)),
          _seam(vt),
          SizedBox(
            width: _kAudienceWideWidth,
            child: _audiencePanel(vt),
          ),
        ],
      );

  Widget _medium(VolunteersTheme vt) => Stack(
        children: [
          Row(
            children: [
              SizedBox(width: _kRailIconWidth, child: _railIcons(vt)),
              _seam(vt),
              Expanded(child: _workArea(vt, narrow: false)),
              _seam(vt),
              SizedBox(
                width: _kAudienceMediumWidth,
                child: _audiencePanel(vt),
              ),
            ],
          ),
          if (_railOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _railOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _kRailWidth,
              child: Material(
                color: vt.surface,
                elevation: 8,
                child: _rail(vt, onClose: () => setState(() => _railOpen = false)),
              ),
            ),
          ],
        ],
      );

  Widget _narrow(VolunteersTheme vt) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _workHeader(vt, narrow: true),
          _audienceSummaryBar(vt),
          Expanded(
            child: _audience.isEmpty ? _emptyState(vt) : _sections(vt),
          ),
        ],
      );

  // ── Work area ─────────────────────────────────────────────────
  Widget _workArea(VolunteersTheme vt, {required bool narrow}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _workHeader(vt, narrow: narrow),
          Expanded(child: _audience.isEmpty ? _emptyState(vt) : _sections(vt)),
        ],
      );

  Widget _workHeader(VolunteersTheme vt, {required bool narrow}) {
    final region = _regionLabel;
    final counts = _audience.isEmpty
        ? 'No audience yet'
        : '${_audience.length} ${_audience.length == 1 ? 'member' : 'members'}'
            ' · ${_textable.length} textable · ${_emailable.length} emailable';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: Row(
        children: [
          if (narrow) ...[
            _headerIconButton(
              icon: Icons.inbox_outlined,
              tooltip: 'My desk',
              onTap: _openRailSheet,
              badge: _deskBadge,
            ),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_outlined,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region == null ? 'Mobilize' : 'Mobilize · $region',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTextStyles.title,
                ),
                const SizedBox(height: 2),
                Text(counts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrandTextStyles.caption),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: widget.onOpenMap,
            icon: const Icon(Icons.map_outlined, size: 17),
            label: const Text('Change'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white, size: 21),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: _countPill(badge),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gold well with navy digits: the emphasis pair, 7.17:1, and the only
  /// filled pairing in this palette that may carry a label.
  Widget _countPill(int value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: BrandColors.sunriseGold,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$value',
            style: const TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      );

  Widget _emptyState(VolunteersTheme vt) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined,
                  size: 44, color: vt.secondary.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              Text('Nothing on the desk yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: vt.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _drafts.isEmpty
                    ? 'Pick a region on the map, select the members you want, '
                        'then press Mobilize.'
                    : 'Pick a region on the map, select the members you want, '
                        'then press Mobilize, or continue a draft from MY '
                        'DESK.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: vt.secondary, fontSize: 13.5, height: 1.45),
              ),
              const SizedBox(height: 20),
              _primaryButton(
                vt,
                icon: Icons.map_outlined,
                label: 'Open the map',
                enabled: true,
                onTap: widget.onOpenMap,
              ),
            ],
          ),
        ),
      );

  Widget _sections(VolunteersTheme vt) => ListView(
        controller: _workScroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _sendSection(vt),
          const SizedBox(height: 14),
          _planSection(vt),
          const SizedBox(height: 14),
          _connectSection(vt),
        ],
      );

  // ── Section chrome ────────────────────────────────────────────
  Widget _section(
    VolunteersTheme vt, {
    required _DeskSection id,
    required IconData icon,
    required String label,
    required String summary,
    required Widget body,
  }) {
    final open = _expanded.contains(id);
    return Container(
      key: _sectionKeys[id],
      decoration: BoxDecoration(
        color: vt.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vt.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                if (open) {
                  _expanded.remove(id);
                } else {
                  _expanded.add(id);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: vt.text),
                    const SizedBox(width: 10),
                    Text(label,
                        style: TextStyle(
                            color: vt.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: vt.secondary, fontSize: 12.5)),
                    ),
                    Icon(open ? Icons.expand_less : Icons.expand_more,
                        size: 20, color: vt.secondary),
                  ],
                ),
              ),
            ),
          ),
          if (open) ...[
            Container(height: 1, color: vt.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: body,
            ),
          ],
        ],
      ),
    );
  }

  // ── SEND ──────────────────────────────────────────────────────
  /// The composer, mounted in place. Everything about the WORDS belongs to
  /// [MobilizeComposer]; what the Desk supplies is the audience, the acting
  /// exec, and the geo builder that turns the two halves into a row.
  Widget _sendSection(VolunteersTheme vt) {
    final isText = _channel == BulkSendChannel.sms;
    final eligible = _eligible.length;
    // Watched, not read: the session resolves after first frame and Send has
    // to become live the moment it does.
    final actor = _actorFrom(context.watch<UserSessionProvider>());

    return _section(
      vt,
      id: _DeskSection.send,
      icon: Icons.send_outlined,
      label: 'SEND',
      summary: isText ? 'Text $eligible' : 'Email $eligible',
      body: MobilizeComposer(
        draft: _draft,
        audience: List<Member>.unmodifiable(_audience),
        nomineeIds: _nominees.map((c) => c.id).toList(growable: false),
        channel: _channel,
        onChannelChanged: (next) => setState(() => _channel = next),
        actor: actor,
        active: widget.active,
        isRetry: _retryOf != null,
        resume: _resume,
        onResumeConsumed: _onResumeConsumed,
        draftBuilder: _draftFor,
        onRowResolved: _onRowResolved,
        onRetryFailures: _retryFailedIds,
        onLogAsActivity: _promoteById,
        onShowSkipDetails: _showSkipDetails,
      ),
    );
  }

  /// The composer finished with its row: it sent, or it discarded. The rail
  /// reloads, and the retry lineage is spent either way, since the row it
  /// pointed at has been written.
  void _onRowResolved() {
    if (mounted) setState(() => _retryOf = null);
    unawaited(_loadTouchpoints());
  }


  // ── PLAN ──────────────────────────────────────────────────────
  Widget _planSection(VolunteersTheme vt) {
    final n = _audience.length;
    final here = _regionActivityCount ?? 0;
    final region = _regionLabel;

    return _section(
      vt,
      id: _DeskSection.plan,
      icon: Icons.event_note_outlined,
      label: 'PLAN',
      summary: 'Plan an activity with these $n',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            region == null
                ? 'The audience goes on the roster, with any attached '
                    'nominees.'
                : 'The audience goes on the roster, with $region and any '
                    'attached nominees.',
            style: TextStyle(color: vt.secondary, fontSize: 12),
          ),
          if (here > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addToExistingActivity,
                icon: const Icon(Icons.playlist_add_outlined, size: 18),
                label: Text(
                    'or add them to an existing activity ($here here)'),
                style: TextButton.styleFrom(
                  foregroundColor: vt.highlight,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: vt.divider),
          const SizedBox(height: 12),
          // THE SAME FORM the rest of the CRM plans with, mounted inline
          // instead of on top of the page (spec 6.3). Not a fork of it: the
          // sheet and this share one widget, so a field added to one is a
          // field added to both.
          //
          // Keyed on the audience so a trip back to the map for ten more
          // people gives a form seeded with the audience actually on screen.
          // The key holds still while the exec types, because the signature
          // only moves when WHO changes.
          OrganizingToolkitForm(
            key: ValueKey<String>(_planSeedSignature()),
            seed: OrganizingSeed.forAudience(_currentRequest),
            mount: OrganizingToolkitMount.inline,
            onSaved: (_) => _onActivitySaved(),
          ),
        ],
      ),
    );
  }

  /// What a re-seed of the inline PLAN form depends on: who is on the
  /// audience, which nominees are attached, and the region. Not the words the
  /// exec has typed into it, which is the point.
  String _planSeedSignature() => <String>[
        _regionMode?.name ?? '',
        _regionId ?? '',
        _seedKind ?? '',
        for (final m in _audience) m.id,
        '|',
        for (final c in _nominees) c.id,
      ].join(',');

  // ── CONNECT (6.4) ─────────────────────────────────────────────
  /// Who this audience is FOR. The link is not a status on the send and not a
  /// live region filter: it is a materialized row per member, so the count
  /// holds still, one person can be dropped from it, and it says who linked
  /// them and when (spec 5.2).
  Widget _connectSection(VolunteersTheme vt) {
    return _section(
      vt,
      id: _DeskSection.connect,
      icon: Icons.link_outlined,
      label: 'CONNECT',
      summary: _connectSummary(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_linksErrored) ...[
            _railNote(vt, 'Could not load who is linked. The counts below may '
                'be out of date.'),
            const SizedBox(height: 12),
          ],
          if (_nominees.isEmpty)
            _railNote(
              vt,
              'No nominee attached. Pick a region on the map and its November '
              'nominees come across with the audience, or attach one you have '
              'already linked members to.',
            )
          else
            for (final c in _nominees) ...[
              _nomineeLinkCard(vt, c),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _linkBusyId == null ? _attachNominee : null,
              icon: const Icon(Icons.person_add_alt_outlined, size: 18),
              label: Text(_nominees.isEmpty
                  ? 'Attach a nominee'
                  : 'Attach another nominee'),
              style: TextButton.styleFrom(
                foregroundColor: vt.highlight,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _connectSummary() {
    if (_nominees.isEmpty) return 'Link these members to a nominee';
    if (_loadingLinks && _linksByNominee.isEmpty) {
      return 'Checking who is linked';
    }
    if (_nominees.length == 1) {
      final c = _nominees.first;
      final n = _linkCount(c);
      return n == 0
          ? 'Nobody linked to ${c.name} yet'
          : '$n linked to ${c.name}';
    }
    final total =
        _nominees.fold<int>(0, (sum, c) => sum + _linkCount(c));
    return '$total linked across ${_nominees.length} nominees';
  }

  /// One attached nominee: who is linked to them, the two link gestures, and
  /// the batches those gestures wrote. No vote counts, no percentages.
  Widget _nomineeLinkCard(VolunteersTheme vt, Candidate c) {
    final n = _audience.length;
    final linked = _linkCount(c);
    final region = _regionLabel;
    final busy = _linkBusyId == c.id;
    final locked = _linkBusyId != null;
    final firstName = c.firstName.isNotEmpty ? c.firstName : c.name;
    final batches = _batchesFor(c);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vt.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _partyLetter(c.partyShort),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: vt.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              _nomineeBadge(c.partyShort),
            ],
          ),
          if (c.officeDisplay.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(c.officeDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: vt.secondary, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 15, color: vt.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  linked == 0
                      ? 'Nobody linked yet'
                      : '$linked ${linked == 1 ? 'member' : 'members'} linked',
                  style: TextStyle(color: vt.secondary, fontSize: 12.5),
                ),
              ),
              if (busy || (_loadingLinks && linked == 0))
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: vt.accent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _primaryButton(
            vt,
            icon: Icons.link,
            label: 'Link these $n to $firstName',
            enabled: n > 0 && !locked,
            onTap: () => _linkAudience(c),
          ),
          if (region != null)
            _connectAction(
              vt,
              icon: Icons.place_outlined,
              label: 'Link all of $region to $firstName',
              enabled: !locked,
              onTap: () => _linkRegion(c),
            ),
          if (linked > 0)
            _connectAction(
              vt,
              icon: Icons.fact_check_outlined,
              label: 'Review the $linked linked',
              enabled: !locked,
              onTap: () => _reviewLinked(c),
            ),
          if (batches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: vt.divider),
            const SizedBox(height: 10),
            for (final batch in batches) _batchRow(vt, c, batch, locked: locked),
          ],
        ],
      ),
    );
  }

  Widget _connectAction(
    VolunteersTheme vt, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          // sunriseGold on the section body reads 5.32:1; the accent would be
          // 2.75:1 and is never allowed to carry a label.
          foregroundColor: vt.highlight,
          disabledForegroundColor: vt.secondary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }

  /// One link gesture, named by the region and the exec who made it. Refresh
  /// only appears on a batch that came from a region, because there is nothing
  /// to re-read for a batch picked by hand.
  Widget _batchRow(
    VolunteersTheme vt,
    Candidate c,
    CandidateMemberLinkBatch batch, {
    required bool locked,
  }) {
    final fromRegion = candidateLinkSourceMode(batch.sourceRegionMode) != null &&
        batch.sourceRegionId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(_batchLabel(batch),
                maxLines: 2,
                style: TextStyle(
                    color: vt.secondary, fontSize: 12, height: 1.35)),
          ),
          if (fromRegion)
            IconButton(
              onPressed: locked ? null : () => _refreshBatch(c, batch),
              tooltip: 'Refresh from the region',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Icon(Icons.refresh, size: 17, color: vt.secondary),
            ),
          IconButton(
            onPressed: locked ? null : () => _unlinkBatch(c, batch),
            tooltip: 'Unlink this batch',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Icon(Icons.link_off, size: 17, color: vt.secondary),
          ),
        ],
      ),
    );
  }

  /// The same party-coded NOMINEE pill the map's candidate cards carry. The
  /// word is always "NOMINEE", never "our nominee", and it never sits beside a
  /// vote count.
  Widget _nomineeBadge(String partyShort) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MapPalette.partyChipColor(partyShort),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text('NOMINEE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
      );

  // ── MY DESK rail ──────────────────────────────────────────────
  Widget _railIcons(VolunteersTheme vt) => Container(
        color: vt.surface,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Tooltip(
              message: 'My desk',
              child: Material(
                color: vt.inset,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _railOpen = true),
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 21, color: vt.text),
                        if (_deskBadge > 0)
                          Positioned(
                            right: 2,
                            top: 4,
                            child: _countPill(_deskBadge),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _openRailSheet() async {
    final vt = VolunteersTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The sheet is its own route, so the Desk's setState does not reach it.
      // StatefulBuilder gives the rail a way to repaint itself after a load.
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => FractionallySizedBox(
          heightFactor: 0.9,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _rail(
              vt,
              onClose: () => Navigator.of(sheetContext).pop(),
              onChanged: () => setSheetState(() {}),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rail(VolunteersTheme vt,
      {VoidCallback? onClose, VoidCallback? onChanged}) {
    return Container(
      color: vt.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
            child: Row(
              children: [
                Expanded(
                  child: Text(_wholeCommittee ? 'THE COMMITTEE' : 'MY DESK',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
                IconButton(
                  onPressed: _loadingDesk
                      ? null
                      : () async {
                          await _loadDesk();
                          onChanged?.call();
                        },
                  tooltip: 'Refresh',
                  icon: _loadingDesk
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh, color: Colors.white, size: 19),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Colors.white, size: 19),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _deskList(vt, onChanged: onChanged, onDismiss: onClose),
          ),
        ],
      ),
    );
  }

  /// The three groups of 4.4: what the exec is still writing, what they have
  /// sent, and what they have planned.
  Widget _deskList(
    VolunteersTheme vt, {
    VoidCallback? onChanged,
    VoidCallback? onDismiss,
  }) {
    final empty =
        _myActivities.isEmpty && _drafts.isEmpty && _recent.isEmpty;
    if (_loadingDesk && empty) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child:
              CircularProgressIndicator(strokeWidth: 2.4, color: vt.accent),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        _groupHeader(vt,
            group: _DeskGroup.drafts,
            label: 'DRAFTS',
            count: _drafts.length,
            onChanged: onChanged),
        if (!_collapsed.contains(_DeskGroup.drafts)) ...[
          if (_touchpointsErrored)
            _railNote(vt, 'Could not load drafts.')
          else if (_drafts.isEmpty)
            _railNote(
                vt,
                _wholeCommittee
                    ? 'Nobody on the committee has a draft open.'
                    : 'No drafts. One is written for you the moment you start '
                        'writing on the Desk.')
          else
            ..._drafts.map((t) => _draftRow(vt, t,
                onChanged: onChanged, onDismiss: onDismiss)),
          const SizedBox(height: 10),
        ],
        _groupHeader(vt,
            group: _DeskGroup.sends,
            label: 'RECENT SENDS',
            count: _recent.length,
            onChanged: onChanged),
        if (!_collapsed.contains(_DeskGroup.sends)) ...[
          if (_touchpointsErrored)
            _railNote(vt, 'Could not load recent sends.')
          else if (_recent.isEmpty)
            _railNote(
                vt,
                _wholeCommittee
                    ? 'Nobody on the committee has sent anything yet.'
                    : 'Nothing sent yet. Every send from the Desk lands here '
                        'and on the region it covered.')
          else
            ..._recent.map((t) => _sentRow(vt, t,
                onChanged: onChanged, onDismiss: onDismiss)),
          const SizedBox(height: 10),
        ],
        _groupHeader(vt,
            group: _DeskGroup.activities,
            label: _wholeCommittee ? 'ACTIVITIES' : 'MY ACTIVITIES',
            count: _myActivities.length,
            onChanged: onChanged),
        if (!_collapsed.contains(_DeskGroup.activities)) ...[
          if (_mineErrored)
            _railNote(vt, 'Could not load activities.')
          else if (_myActivities.isEmpty)
            _railNote(
                vt,
                _wholeCommittee
                    ? 'Nobody on the committee is running an activity yet.'
                    : 'Nothing yet. Plan an activity below and it shows up '
                        'here.')
          else
            ..._myActivities
                .map((a) => _myActivityRow(vt, a, onChanged: onChanged)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onOpenActivities,
              icon: const Icon(Icons.event_note_outlined, size: 17),
              label: const Text('All activities'),
              style: TextButton.styleFrom(
                foregroundColor: vt.highlight,
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _scopeToggle(vt, onChanged: onChanged),
      ],
    );
  }

  /// "Show the whole committee" (4.4). The rail defaults to the reader's own
  /// work, because the Desk is theirs; the toggle exists because the exec
  /// committee can already see each other's outreach by policy and Andrew
  /// asked that this work be tracked and monitored, not siloed.
  ///
  /// One switch drives all three groups. Three switches would let the rail sit
  /// in a state where "drafts" and "recent sends" answer different questions,
  /// which is the drift this workspace has been bitten by before.
  Widget _scopeToggle(VolunteersTheme vt, {VoidCallback? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: vt.divider)),
      ),
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loadingDesk
              ? null
              : () async {
                  setState(() => _wholeCommittee = !_wholeCommittee);
                  onChanged?.call();
                  await _loadDesk();
                  onChanged?.call();
                },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Checkbox(
                    value: _wholeCommittee,
                    // The emphasis pair: a white tick on the accent is 2.75:1
                    // and fails even the 3:1 graphical-object floor.
                    activeColor: vt.emphasisFill,
                    checkColor: vt.onEmphasis,
                    // The rail is a navy surface, so the empty box needs an
                    // explicit light edge; the Material default is a dark
                    // outline that disappears here.
                    side: const BorderSide(color: Colors.white70, width: 1.5),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: _loadingDesk
                        ? null
                        : (_) async {
                            setState(
                                () => _wholeCommittee = !_wholeCommittee);
                            onChanged?.call();
                            await _loadDesk();
                            onChanged?.call();
                          },
                  ),
                ),
                Expanded(
                  child: Text('Show the whole committee',
                      style: TextStyle(
                          color: vt.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupHeader(
    VolunteersTheme vt, {
    required _DeskGroup group,
    required String label,
    required int count,
    VoidCallback? onChanged,
  }) {
    final open = !_collapsed.contains(group);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (open) {
              _collapsed.add(group);
            } else {
              _collapsed.remove(group);
            }
          });
          onChanged?.call();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: vt.highlight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: vt.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9)),
              const SizedBox(width: 8),
              if (count > 0) _countPill(count),
              const Spacer(),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: vt.secondary),
            ],
          ),
        ),
      ),
    );
  }

  /// A draft, or an interrupted send sorted above the drafts. Continue picks
  /// the audience and channel back up; an interrupted row opens its card
  /// instead, because a send that never resolved needs a human decision and
  /// the Desk never resends one on its own (3.5).
  ///
  /// Somebody else's draft is READ ONLY, even in the committee view. Two execs
  /// composing into one row would have the second debounce overwrite the
  /// first's words with no trace, which is not a conflict the record can
  /// represent. Their card still opens, so the work is visible.
  Widget _draftRow(
    VolunteersTheme vt,
    OutreachTouchpoint touchpoint, {
    VoidCallback? onChanged,
    VoidCallback? onDismiss,
  }) {
    final count = touchpoint.recipientMemberIds.length;
    final actor = _actor();
    final mine = actor != null && touchpoint.actorMemberId == actor.memberId;
    final resumable = mine && !touchpoint.isInterrupted;
    return BrandedActivityFeedItem(
      primaryText: touchpoint.preview.isEmpty
          ? '${touchpoint.channelLabel} to $count'
          : touchpoint.preview,
      secondaryText: <String>[
        _authorLine(touchpoint.actorMemberId),
        'to $count',
        _ago(touchpoint.lastEditedAt),
      ].where((s) => s.isNotEmpty).join(' · '),
      leadingIcon: touchpoint.channelIcon,
      actionLabel: resumable ? 'Continue' : touchpoint.statusLabel,
      actionColor: touchpoint.statusColor,
      showChevron: false,
      onTap: () async {
        if (!resumable) {
          await _showTouchpointCard(touchpoint, onDismiss: onDismiss);
          onChanged?.call();
          return;
        }
        onDismiss?.call();
        await _continueDraft(touchpoint);
        onChanged?.call();
      },
    );
  }

  Widget _sentRow(
    VolunteersTheme vt,
    OutreachTouchpoint touchpoint, {
    VoidCallback? onChanged,
    VoidCallback? onDismiss,
  }) {
    return BrandedActivityFeedItem(
      primaryText: touchpoint.preview.isEmpty
          ? '${touchpoint.channelLabel} to ${touchpoint.attemptedCount}'
          : touchpoint.preview,
      secondaryText: <String>[
        _authorLine(touchpoint.actorMemberId),
        touchpoint.outcomeSummary,
        if (touchpoint.isPromoted) 'logged',
        _ago(touchpoint.sentAt),
      ].where((s) => s.isNotEmpty).join(' · '),
      leadingIcon: touchpoint.channelIcon,
      actionLabel: touchpoint.statusLabel,
      actionColor: touchpoint.statusColor,
      showChevron: false,
      onTap: () async {
        await _showTouchpointCard(touchpoint, onDismiss: onDismiss);
        onChanged?.call();
      },
    );
  }

  /// The record of one send, and what can still be done with it.
  ///
  /// It reports first: a send is history, not a form. The actions under it are
  /// the four honest follow-ups, and which of them appear is decided by the
  /// row, never by the reader's mood: retry the failures, log it as an
  /// activity (or open the activity it already became), and, for an
  /// interrupted send only, close it out.
  Future<void> _showTouchpointCard(
    OutreachTouchpoint touchpoint, {
    VoidCallback? onDismiss,
  }) async {
    final actor = _actor();
    final mine = actor != null && touchpoint.actorMemberId == actor.memberId;
    final author = _memberNames[touchpoint.actorMemberId];

    final lines = <String>[
      '${touchpoint.channelLabel} · ${touchpoint.outcomeSummary}',
      if (!mine && author != null && author.isNotEmpty)
        touchpoint.isDraft ? 'Being written by $author' : 'Sent by $author',
      // A read-only draft has no outcome to report, so the words are the whole
      // record. Elsewhere the preview is already the row's own headline.
      if (touchpoint.isDraft && touchpoint.preview.isNotEmpty)
        touchpoint.preview,
      if (touchpoint.isDraft)
        'To ${touchpoint.recipientMemberIds.length}.',
      if (touchpoint.attemptedCount > 0)
        '${touchpoint.deliveredCount} delivered of '
            '${touchpoint.attemptedCount} attempted',
      if (touchpoint.failedMemberIds.isNotEmpty)
        '${touchpoint.failedMemberIds.length} failed',
      if (touchpoint.sentAt != null) 'Sent ${_fmtDate(touchpoint.sentAt!)}',
      if (touchpoint.isInterrupted)
        'This send was interrupted: the tab went away before the result came '
            'back. What went out cannot be known from here, so nothing is '
            'resent automatically. Close it out below once you know.',
      if (touchpoint.isPromoted)
        'This is already logged as an activity.',
      if ((touchpoint.errorDetail ?? '').isNotEmpty) touchpoint.errorDetail!,
    ];

    // Promotion stamps the caller as the activity's organizer, so it is
    // offered only on the reader's own send. Naming one exec as the organizer
    // of another's outreach would be a lie in the audit trail.
    final canPromote =
        mine && !touchpoint.isPromoted && !touchpoint.isInterrupted &&
            (touchpoint.status == 'sent' || touchpoint.status == 'partial');

    final choice = await showDialog<_TouchpointAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        shape: _dialogShape,
        titleTextStyle: BrandTextStyles.title,
        contentTextStyle: BrandTextStyles.bodySecondary,
        title: Text(touchpoint.statusLabel),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines) ...[
                Text(line, style: BrandTextStyles.bodySecondary),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        // Wrapped rather than rowed: up to three actions plus Close will not
        // fit a 380px dialog on one line, and an overflowing action bar drops
        // the button on the end.
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (touchpoint.isInterrupted) ...[
                _dialogAction(dialogContext, 'It went out',
                    _TouchpointAction.markSent),
                _dialogAction(dialogContext, 'It did not go out',
                    _TouchpointAction.markFailed),
              ],
              if (touchpoint.hasFailures)
                _dialogAction(
                    dialogContext,
                    'Retry the ${touchpoint.failedMemberIds.length} that failed',
                    _TouchpointAction.retry),
              if (canPromote)
                _dialogAction(dialogContext, 'Log this as an activity',
                    _TouchpointAction.promote),
              if (touchpoint.isPromoted)
                _dialogAction(dialogContext, 'Open the activity',
                    _TouchpointAction.openActivity),
              _dialogAction(
                  dialogContext, 'Close', _TouchpointAction.dismiss),
            ],
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case _TouchpointAction.dismiss:
        return;
      case _TouchpointAction.retry:
        onDismiss?.call();
        await _retryFailures(touchpoint);
        return;
      case _TouchpointAction.promote:
        onDismiss?.call();
        await _promote(touchpoint);
        return;
      case _TouchpointAction.openActivity:
        onDismiss?.call();
        await _openActivityById(touchpoint.activityId!);
        return;
      case _TouchpointAction.markSent:
        await _resolveInterrupted(touchpoint, true);
        return;
      case _TouchpointAction.markFailed:
        await _resolveInterrupted(touchpoint, false);
        return;
    }
  }

  /// Gold on the navy dialog surface, 7.17:1. One helper so five buttons
  /// cannot drift into five styles.
  Widget _dialogAction(
          BuildContext dialogContext, String label, _TouchpointAction value) =>
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.sunriseGold,
          minimumSize: const Size(0, 44),
        ),
        onPressed: () => Navigator.pop(dialogContext, value),
        child: Text(label),
      );

  Widget _railNote(VolunteersTheme vt, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: vt.inset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vt.divider),
        ),
        child: Text(text,
            style: TextStyle(color: vt.secondary, fontSize: 12, height: 1.4)),
      );

  Widget _myActivityRow(VolunteersTheme vt, OutreachActivity a,
      {VoidCallback? onChanged}) {
    return BrandedActivityFeedItem(
      primaryText: a.title,
      secondaryText: <String>[
        if (a.organizerMemberId != null) _authorLine(a.organizerMemberId!),
        a.scheduledOn == null ? 'No date' : _fmtDate(a.scheduledOn!),
        a.kindLabel,
      ].where((s) => s.isNotEmpty).join(' · '),
      leadingIcon: a.kindIcon,
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(activity: a),
        ));
        await _loadMine();
        onChanged?.call();
      },
    );
  }

  // ── AUDIENCE panel ────────────────────────────────────────────
  Widget _audienceSummaryBar(VolunteersTheme vt) {
    final n = _audience.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: vt.surface,
        border: Border(bottom: BorderSide(color: vt.divider)),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, size: 18, color: vt.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              n == 0 ? 'No audience yet' : '$n selected',
              style: TextStyle(
                  color: vt.text, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _openAudienceSheet,
            style: TextButton.styleFrom(
              foregroundColor: vt.highlight,
              minimumSize: const Size(0, 44),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAudienceSheet() async {
    final vt = VolunteersTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _audiencePanel(
              vt,
              onChanged: () => setSheetState(() {}),
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _audiencePanel(
    VolunteersTheme vt, {
    VoidCallback? onChanged,
    VoidCallback? onClose,
  }) {
    return Container(
      color: vt.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _audienceHeader(vt, onChanged: onChanged, onClose: onClose),
          Expanded(child: _audienceBody(vt, onChanged: onChanged)),
        ],
      ),
    );
  }

  Widget _audienceHeader(
    VolunteersTheme vt, {
    VoidCallback? onChanged,
    VoidCallback? onClose,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: Row(
        children: [
          Expanded(
            child: Text('AUDIENCE · ${_audience.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          TextButton(
            onPressed: widget.onOpenMap,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            child: const Text('Change'),
          ),
          _addMenu(vt, onChanged: onChanged),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: Colors.white, size: 19),
            ),
        ],
      ),
    );
  }

  Widget _addMenu(VolunteersTheme vt, {VoidCallback? onChanged}) {
    final region = _regionLabel;
    return PopupMenuButton<String>(
      tooltip: 'Add to the audience',
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        switch (value) {
          case 'region':
            await _addEveryoneInRegion();
            break;
          case 'committee':
            await _addCommittee();
            break;
          case 'roster':
            await _addActivityRoster();
            break;
          case 'linked':
            await _addLinkedToNominee();
            break;
        }
        onChanged?.call();
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (region != null)
          PopupMenuItem<String>(
            value: 'region',
            child: _menuRow(Icons.place_outlined, 'Everyone in $region'),
          ),
        PopupMenuItem<String>(
          value: 'linked',
          child: _menuRow(Icons.link_outlined, 'Everyone linked to a nominee'),
        ),
        PopupMenuItem<String>(
          value: 'committee',
          child: _menuRow(Icons.groups_outlined, 'Members of a committee'),
        ),
        PopupMenuItem<String>(
          value: 'roster',
          child:
              _menuRow(Icons.event_note_outlined, 'The roster of an activity'),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text('Add',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
            Icon(Icons.expand_more, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      );

  Widget _audienceBody(VolunteersTheme vt, {VoidCallback? onChanged}) {
    if (_audience.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _railNote(
          vt,
          'No audience yet. Select members on the map and press Mobilize, or '
          'use Add above.',
        ),
      );
    }

    final skipped =
        _audience.where((m) => !ComposerSkip.eligible(m, _channel)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
      children: [
        if (skipped.isNotEmpty)
          ComposerSkipLine(
            text: _channel == BulkSendChannel.sms
                ? "${skipped.length} can't be texted: "
                    '${ComposerSkip.reasonSummary(skipped, _channel)}'
                : "${skipped.length} can't be emailed: no email on file",
            onDetails: _showSkipDetails,
          ),
        ..._audience.map((m) => _audienceRow(vt, m, onChanged: onChanged)),
        if (_nominees.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: vt.divider),
          const SizedBox(height: 14),
          Text('NOMINEES',
              style: TextStyle(
                  color: vt.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _nominees
                .map((c) => _nomineeChip(vt, c, onChanged: onChanged))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _audienceRow(VolunteersTheme vt, Member m,
      {VoidCallback? onChanged}) {
    final canText = m.canContact;
    final canEmail = (m.preferredEmail ?? '').isNotEmpty;
    final sub = _memberSubline(m);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Checkbox(
              value: true,
              // Gold well, navy tick: the emphasis pair at 7.17:1. Unchecking
              // is the remove gesture, which is why every row reads checked.
              activeColor: vt.emphasisFill,
              checkColor: vt.onEmphasis,
              side: const BorderSide(color: Colors.white70, width: 1.5),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) {
                setState(() => _audience.removeWhere((x) => x.id == m.id));
                onChanged?.call();
              },
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(member: m),
                )),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: vt.inset,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _memberAvatar(m),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: vt.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            if (sub.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: vt.secondary, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: canText ? 'Textable' : 'No phone / opted out',
                        child: Icon(Icons.sms_outlined,
                            size: 16,
                            color: vt.secondary
                                .withValues(alpha: canText ? 0.9 : 0.5)),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: canEmail ? 'Emailable' : 'No email on file',
                        child: Icon(Icons.email_outlined,
                            size: 16,
                            color: vt.secondary
                                .withValues(alpha: canEmail ? 0.9 : 0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _memberSubline(Member m) {
    final mode = _regionMode;
    String? district;
    switch (mode) {
      case MapMode.house:
        final hd = m.houseDistrict;
        district = (hd ?? '').isNotEmpty ? 'HD $hd' : null;
        break;
      case MapMode.senate:
        final sd = m.senateDistrict;
        district = (sd ?? '').isNotEmpty ? 'SD $sd' : null;
        break;
      case MapMode.county:
      case MapMode.congressional:
      case null:
        final cd = m.congressionalDistrict;
        district = (cd ?? '').isNotEmpty ? cd : null;
        break;
    }
    return <String>[
      if ((m.county ?? '').isNotEmpty) '${m.county} County',
      if (district != null) district,
    ].join(' · ');
  }

  Widget _memberAvatar(Member m) {
    final url = m.effectiveAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _memberInitials(m)),
      );
    }
    return _memberInitials(m);
  }

  Widget _memberInitials(Member m) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.avatarColorFor(m.id),
          shape: BoxShape.circle,
        ),
        child: Text(_initials(m.name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  /// Removable nominee chip. Party letter on its party color, the name in
  /// white on the inset pill. No vote counts, no percentages, ever.
  Widget _nomineeChip(VolunteersTheme vt, Candidate c,
      {VoidCallback? onChanged}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
      decoration: BoxDecoration(
        color: vt.inset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: vt.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _partyLetter(c.partyShort),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: vt.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _nominees.removeWhere((x) => x.id == c.id);
                _linksByNominee.remove(c.id);
              });
              onChanged?.call();
            },
            tooltip: 'Detach ${c.name}',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close, size: 15, color: vt.secondary),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ───────────────────────────────────────────────
  /// The workspace's one filled action: sunriseGold under unityBlue, 7.17:1.
  Widget _primaryButton(
    VolunteersTheme vt, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: vt.emphasisFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: vt.onEmphasis),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: vt.onEmphasis,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final RoundedRectangleBorder _dialogShape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

/// The party letter square carried by the nominee chip, the CONNECT card and
/// the nominee picker. One definition so the three cannot drift.
Widget _partyLetter(String letter, {double size = 22}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MapPalette.partyChipColor(letter),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(letter,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w800)),
    );

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Rail timestamps. Anything older than a week reads as a date: "43d ago" is
/// arithmetic the reader should not have to do.
String _ago(DateTime? when) {
  if (when == null) return '';
  final local = when.toLocal();
  final gap = DateTime.now().difference(local);
  if (gap.isNegative || gap.inMinutes < 1) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  if (gap.inDays < 7) return '${gap.inDays}d ago';
  return _fmtDate(local);
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Picks one of the nominees that already carry links. Local filtering over a
/// list the Desk loaded once, so typing never fires a query.
class _LinkedNomineeDialog extends StatefulWidget {
  const _LinkedNomineeDialog({required this.title, required this.options});

  final String title;
  final List<_LinkedNominee> options;

  @override
  State<_LinkedNomineeDialog> createState() => _LinkedNomineeDialogState();
}

class _LinkedNomineeDialogState extends State<_LinkedNomineeDialog> {
  String _query = '';

  List<_LinkedNominee> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) =>
            o.candidate.name.toLowerCase().contains(q) ||
            o.candidate.officeDisplay.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return AlertDialog(
      backgroundColor: BrandColors.unityBlue,
      shape: _dialogShape,
      titleTextStyle: BrandTextStyles.title,
      contentTextStyle: BrandTextStyles.bodySecondary,
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              style: BrandTextStyles.body,
              cursorColor: BrandColors.sunriseGold,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search nominees',
                hintStyle: BrandTextStyles.caption,
                prefixIcon:
                    Icon(Icons.search, size: 18, color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: BrandColors.sunriseGold)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? const Center(
                      child: Text('No nominee matches that.',
                          style: BrandTextStyles.bodySecondary))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final option = shown[i];
                        final c = option.candidate;
                        final office = c.officeDisplay;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: _partyLetter(c.partyShort, size: 26),
                          title: Text(c.name, style: BrandTextStyles.body),
                          subtitle: Text(
                            <String>[
                              if (office.isNotEmpty) office,
                              '${option.linkCount} linked',
                            ].join(' · '),
                            style: BrandTextStyles.caption,
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
