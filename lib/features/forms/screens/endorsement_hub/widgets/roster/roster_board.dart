import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/moyd_brand.dart';
import '../../decision_attribution_repository.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../../theme/hub_theme.dart';
import '../decisions/ballot_row.dart';
import '../decisions/race_field_disclosure.dart';
import '../decisions/baseline_row.dart';
import '../decisions/board_toolbar.dart';
import '../decisions/decision_activity.dart';
import '../decisions/decision_chip.dart';
import '../decisions/decision_repository.dart';
import '../decisions/district_ref.dart';
import '../decisions/endorsement_vote_repository.dart';
import '../decisions/final_call_panel.dart';
import '../decisions/vote_scoreboard.dart';
import 'roster_gallery.dart';

/// Which face of the merged Roster tab is showing: the exec's meeting-night
/// ballot, or the research-oriented candidate gallery.
enum HubMode { ballot, browse }

/// The merged Roster + Decisions tab: one tab, two modes.
///
/// Ballot mode is the landing mode and carries the full committee voting
/// pipeline (scoreboard, pinned toolbar, [BallotRow] list, locked baseline)
/// transplanted from the retired DecisionBoard. Browse mode hosts the
/// existing [RosterGallery] untouched. Search is the ONE query surface the
/// two modes share (via [SlateController.search]); the browse-side research
/// filters (office / district / alignment range / flags) are deliberately
/// never consulted by the ballot, so a stale histogram drill-in can never
/// silently shrink tonight's ballot.
class RosterBoard extends StatefulWidget {
  final SlateController controller;
  final DecisionRepository repository;
  final EndorsementVoteRepository votes;
  final bool isChair;
  final void Function(CandidateEntry) onOpen;

  const RosterBoard({
    super.key,
    required this.controller,
    required this.repository,
    required this.votes,
    required this.isChair,
    required this.onOpen,
  });

  @override
  State<RosterBoard> createState() => RosterBoardState();
}

class RosterBoardState extends State<RosterBoard>
    with AutomaticKeepAliveClientMixin {
  late final DecisionActivity _activity = DecisionActivity(widget.repository);
  Timer? _clock;

  HubMode _mode = HubMode.ballot;

  /// True once the exec has ever chosen a mode by hand (mode switch, emerald
  /// card, failed-card escape, decided pill, or [focusBrowse]). The landing
  /// computation never overrides a manual pick.
  bool _userPickedMode = false;

  /// One-shot guard for the landing computation (see [_maybeResolveLanding]).
  bool _landingResolved = false;
  bool _votesLoaded = false;

  /// Browse is built lazily: the grid never lays out offstage on the common
  /// meeting-night path where the exec lands on Ballot and stays there.
  bool _browseVisited = false;

  // Meeting default: show each exec what still needs their ballot. These are
  // deliberately NOT shared with SlateController: VoteFilter/VoteSort
  // describe votes, SlateSort and the filter shelf describe candidates, and
  // merging those vocabularies is the silent-ballot-narrowing failure mode
  // this design exists to avoid.
  VoteFilter _filter = VoteFilter.needsMyVote;
  VoteSort _sort = VoteSort.yesShare;
  bool _baselineExpanded = false;

  /// Ballot toolbar text field, bound to [SlateController.search] (the single
  /// shared query brain). Seeded here, synced back on external changes.
  late final TextEditingController _search =
      TextEditingController(text: widget.controller.search);

  /// Expanded candidate ids (multi-expand). Keyed by id so expansion survives
  /// re-sort, re-filter and realtime rebuilds; filtered-out ids just don't
  /// render. Ids that leave the ballot partition are pruned each build.
  final Set<String> _expanded = <String>{};

  /// Parsed district refs, memoized per candidate (entries are immutable per
  /// load, so the parse never needs to re-run).
  final Map<String, DistrictRef?> _districtRefs = {};

  late final Listenable _landingListen;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSearchFromController);
    // The landing computation needs all three loads: decisions (partition),
    // votes (myVote), and the slate itself (the candidate universe).
    _landingListen = Listenable.merge(
        [widget.repository, widget.votes, widget.controller]);
    _landingListen.addListener(_maybeResolveLanding);
    _startClock();
    // Everything may already be loaded (e.g. the board remounting after a
    // keep-alive eviction); resolve immediately after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeResolveLanding());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSearchFromController);
    _landingListen.removeListener(_maybeResolveLanding);
    _stopClock();
    _activity.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Keep the relative "2m ago" attributions fresh. Only runs while Ballot
  /// mode is visible; Browse has no relative times, so the tick is cancelled
  /// on flip and restarted on flip back.
  void _startClock() {
    _clock ??= Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  // Keep the ballot search field text in sync when the controller changes
  // externally (typed in Browse, or clearFilters), exactly the
  // RosterFilterShelf sync pattern: only rewrite when the text differs to
  // avoid cursor jumps and notify loops.
  void _syncSearchFromController() {
    if (!mounted) return;
    if (_search.text != widget.controller.search) {
      _search.text = widget.controller.search;
    }
  }

  /// One-shot landing computation, raced pinned shut behind
  /// [DecisionLoadState.ready], a completed votes load, and a completed slate
  /// load. If the exec has zero open ballots and never picked a mode, land on
  /// Browse with the filter widened to All. On a failed decisions load
  /// `_landingResolved` stays false and the tab stays on Ballot showing the
  /// inline retry card: the board never silently slides to Browse and hides
  /// the outage.
  void _maybeResolveLanding() {
    if (!mounted || _landingResolved) return;
    if (widget.controller.loading || widget.controller.error != null) return;
    if (widget.repository.loadState != DecisionLoadState.ready) return;
    // Strictly the repository's own completion flag. `currentUserId` is set
    // synchronously as the first statement of load(), so testing it here
    // would pass before a single ballot row had arrived and land an exec who
    // is already done straight onto an empty-looking Ballot.
    if (!_votesLoaded) {
      _votesLoaded = widget.votes.loaded;
      if (!_votesLoaded) return;
    }
    final landOnBrowse = !_userPickedMode && _needsMyVoteCount() == 0;
    setState(() {
      _landingResolved = true;
      if (landOnBrowse) {
        _mode = HubMode.browse;
        _browseVisited = true;
        _filter = VoteFilter.all;
      }
    });
    if (landOnBrowse) _stopClock();
  }

  /// FULL-BALLOT AGGREGATE INVARIANT: this count, the scoreboard, quorum,
  /// the progress pill, the tab and segment badges, and the copy summary all
  /// compute from the unfiltered ballot partition of [SlateController.all],
  /// never from the search-filtered visible list. The numbers never lie even
  /// when the list is narrowed.
  int _needsMyVoteCount() {
    var n = 0;
    for (final e in widget.controller.all) {
      if (widget.repository.stateFor(e.id) == DecisionState.undecided &&
          widget.votes.myVote(e.id) == null) {
        n++;
      }
    }
    return n;
  }

  void _setMode(HubMode m, {bool userPicked = false}) {
    setState(() {
      if (userPicked) _userPickedMode = true;
      _mode = m;
      if (m == HubMode.browse) _browseVisited = true;
    });
    if (m == HubMode.ballot) {
      _startClock();
    } else {
      _stopClock();
    }
  }

  /// Hub-to-board hook: the analytics histogram drill-in is a browsing
  /// intent (it narrows the research alignment range), so the hub flips the
  /// board to Browse before animating to this tab.
  void focusBrowse() {
    if (!mounted) return;
    setState(() {
      _mode = HubMode.browse;
      _userPickedMode = true;
      _browseVisited = true;
    });
    _stopClock();
  }

  DistrictRef? _districtRefFor(CandidateEntry e) => _districtRefs.putIfAbsent(
      e.id,
      () => parseDistrictRef(
          office: e.model.office, district: e.model.district));

  /// Race key for clustering: the VIEW-resolved key only, never the client
  /// parse. parseDistrictRef reads the self-reported answers, which is
  /// exactly the data the view exists to outrank (a self-reported "House 34"
  /// would falsely cluster a filed Senate 34 candidate with the House 34
  /// field). A row the view does not cover renders solo, as today.
  String? _raceKeyOf(CandidateEntry e) =>
      widget.controller.raceInfoFor(e.id)?.raceKey;

  /// The two halves of an office self-report conflict as one pill string
  /// ("Filed: Senate 34 · Said: House 34"), or null when filing and answer
  /// agree (the overwhelmingly common case).
  String? _conflictLabelFor(CandidateEntry e) {
    final info = widget.controller.raceInfoFor(e.id);
    if (info == null || !info.officeSelfReportConflict) return null;
    final filed = info.filedOfficeLabel;
    final said = info.selfReportedOfficeLabel;
    if (filed == null || said == null) return null;
    final filedNum = info.districtNum?.toString() ?? '';
    // The self-reported district is free text; keep it compact by taking the
    // first digit run, falling back to the raw string.
    final rawSaid = info.selfReportedDistrictLabel ?? '';
    final saidNum =
        RegExp(r'\d{1,3}').firstMatch(rawSaid)?.group(0) ?? rawSaid;
    final filedPart = filedNum.isEmpty ? filed : '$filed $filedNum';
    final saidPart = saidNum.isEmpty ? said : '$said $saidNum';
    return 'Filed: $filedPart · Said: $saidPart';
  }

  /// Per-row "other Democrats in this race" disclosure for the expansion.
  Widget _raceDisclosureFor(CandidateEntry e) {
    final info = widget.controller.raceInfoFor(e.id);
    return RaceFieldDisclosure(
      raceInfo: info,
      others: widget.controller.raceFieldFor(info?.raceKey),
      loaded: widget.controller.raceDataLoaded,
      failed: widget.controller.raceLoadFailed,
    );
  }

  bool _matches(CandidateEntry e) {
    final q = widget.controller.search.trim().toLowerCase();
    // displayNameFor, not e.name: the one nameless submission (Hope Tinker,
    // 587c32d7) renders everywhere under the race view's coalesced name, so
    // the name the search must match is the name the board shows.
    return q.isEmpty ||
        widget.controller.displayNameFor(e).toLowerCase().contains(q) ||
        e.officeLine.toLowerCase().contains(q);
  }

  List<CandidateEntry> _visibleBallot(
      List<CandidateEntry> ballot, VoteBuckets buckets) {
    var entries = ballot.toList();
    int byName(CandidateEntry a, CandidateEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (_filter == VoteFilter.needsMyVote) {
      entries =
          entries.where((e) => widget.votes.myVote(e.id) == null).toList();
    }
    if (_filter == VoteFilter.splits) {
      // The chair reads the splits aloud: Split first, then consensus-ready
      // (one Confirm tap each), then whatever is still open.
      int rank(String id) => switch (buckets.bucketOf(id)) {
            VoteBucket.split => 0,
            VoteBucket.consensusReady => 1,
            VoteBucket.stillOpen => 2,
          };
      entries.sort((a, b) {
        final r = rank(a.id).compareTo(rank(b.id));
        return r != 0 ? r : byName(a, b);
      });
      return entries;
    }
    switch (_sort) {
      case VoteSort.name:
        entries.sort(byName);
      case VoteSort.alignment:
        entries.sort((a, b) {
          final av = a.alignmentPct ?? -1;
          final bv = b.alignmentPct ?? -1;
          final c = bv.compareTo(av);
          return c != 0 ? c : byName(a, b);
        });
      case VoteSort.yesShare:
        entries.sort((a, b) {
          final ta = widget.votes.tallyFor(a.id);
          final tb = widget.votes.tallyFor(b.id);
          // Voted-on candidates first, highest yes share first, then most
          // ballots cast, then name.
          final c = (tb.yesShare ?? -1).compareTo(ta.yesShare ?? -1);
          if (c != 0) return c;
          final d = tb.cast.compareTo(ta.cast);
          return d != 0 ? d : byName(a, b);
        });
      case VoteSort.race:
        // District run-through: office rank (US House, State Senate, State
        // House, keyless rows last), then numeric district, then name.
        // View-resolved identity first; the memoized client parse covers
        // rows the view does not. Presentation-only, and the cluster pass
        // runs under this sort exactly as under every other.
        int rank(CandidateEntry e) {
          final code = widget.controller.raceInfoFor(e.id)?.officeCode ??
              switch (_districtRefFor(e)?.mapOffice) {
                'US Congress' => 'US_HOUSE',
                'State Senate' => 'MO_SEN',
                'State House' => 'MO_HOUSE',
                _ => null,
              };
          return switch (code) {
            'US_HOUSE' => 0,
            'MO_SEN' => 1,
            'MO_HOUSE' => 2,
            _ => 3,
          };
        }
        int dist(CandidateEntry e) {
          final n = widget.controller.raceInfoFor(e.id)?.districtNum;
          if (n != null) return n;
          return int.tryParse(_districtRefFor(e)?.districtNum ?? '') ??
              1 << 20;
        }
        entries.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          if (r != 0) return r;
          final d = dist(a).compareTo(dist(b));
          return d != 0 ? d : byName(a, b);
        });
    }
    return entries;
  }

  /// The cluster pass: groups the contested races' still-visible members
  /// behind a race cap, leaving every solo row in its exact position.
  ///
  /// Pure presentation over the already filtered + sorted + searched
  /// [visible] list; the unfiltered [ballot] / [baseline] partitions are read
  /// only to compute the cap's honest counts and its decided-mates suffix.
  ///
  /// KNOWN, DELIBERATE SORT PERTURBATION. Do not "fix" this: race mates are
  /// spliced up to their best-sorted member (the anchor), so a
  /// yesShare-sorted list is no longer strictly monotonic across cluster
  /// boundaries. That trade is the point: the 7 contested races read as
  /// contests, it touches at most ~8 of ~50 rows, the cap explains why the
  /// rows sit together, and anchoring at the best-sorted member keeps the
  /// list stable under re-sorts. Restoring strict sort order would scatter
  /// race mates again, which is the exact failure this pass exists to end.
  List<_BallotItem> _clusterContested(
    List<CandidateEntry> visible,
    List<CandidateEntry> ballot,
    List<CandidateEntry> baseline,
    Map<String, int> unfilteredRaceCounts,
  ) {
    final items = <_BallotItem>[];
    final splicedRaces = <String>{};
    for (final e in visible) {
      final k = _raceKeyOf(e);
      // Solo (or keyless, or view-uncovered) rows pass through untouched:
      // same order, same wrapper, byte-identical rendering.
      if (k == null || (unfilteredRaceCounts[k] ?? 0) < 2) {
        items.add(_BallotRowItem(e, inCluster: false, lastInCluster: false));
        continue;
      }
      if (splicedRaces.contains(k)) continue; // already spliced upward
      splicedRaces.add(k);
      final mates = [
        for (final v in visible)
          if (_raceKeyOf(v) == k) v // preserves their relative sort order
      ];
      items.add(_RaceCapItem(
        raceKey: k,
        raceLabel:
            widget.controller.raceInfoFor(e.id)?.shortLabel ?? k,
        applicantCount: unfilteredRaceCounts[k]!,
        visibleCount: mates.length,
        unfilteredBallotCount:
            ballot.where((b) => _raceKeyOf(b) == k).length,
        decidedMates: [
          for (final b in baseline)
            if (_raceKeyOf(b) == k) b
        ],
      ));
      for (var i = 0; i < mates.length; i++) {
        items.add(_BallotRowItem(mates[i],
            inCluster: true, lastInCluster: i == mates.length - 1));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    // ONE breakpoint drives the ballot row layout and the toolbar's extent,
    // exactly the constants the old DecisionBoard used.
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 720;
      final toolbarExtent = narrow ? 116.0 : 64.0;
      return Column(
        children: [
          _modeStrip(context, narrow),
          Expanded(
            // The mode swap keeps BOTH subtrees mounted once built (Offstage,
            // not AnimatedSwitcher: AnimatedSwitcher disposes the outgoing
            // child regardless of KeyedSubtree, which would wipe scroll
            // offsets, both search controllers, the gallery's shelf state and
            // the expansion Set on every flip). TickerMode freezes the hidden
            // side's animations; _browseVisited defers building the gallery
            // until Browse is first shown.
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: _mode != HubMode.ballot,
                  child: TickerMode(
                    enabled: _mode == HubMode.ballot,
                    child: _ballotBody(context, narrow, toolbarExtent),
                  ),
                ),
                if (_browseVisited)
                  Offstage(
                    offstage: _mode != HubMode.browse,
                    child: TickerMode(
                      enabled: _mode == HubMode.browse,
                      child: _browseBody(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ---------------- mode strip ----------------

  Widget _modeStrip(BuildContext context, bool narrow) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _constrain(
        AnimatedBuilder(
          animation: Listenable.merge(
              [widget.repository, widget.votes, widget.controller]),
          builder: (context, _) {
            final ready =
                widget.repository.loadState == DecisionLoadState.ready;
            // Badge and decided count both hide unless the decisions load is
            // ready: never show a number computed against an unverified
            // baseline.
            final needs = ready ? _needsMyVoteCount() : 0;
            var decided = 0;
            if (ready) {
              for (final e in widget.controller.all) {
                if (widget.repository.stateFor(e.id) !=
                    DecisionState.undecided) {
                  decided++;
                }
              }
            }
            final pill = _ModeSwitch(
              mode: _mode,
              onChanged: (m) => _setMode(m, userPicked: true),
              ballotBadge: ready && needs > 0 ? needs : null,
            );
            if (narrow || !ready || decided == 0) {
              return Row(children: [pill]);
            }
            return Row(
              children: [
                pill,
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    _setMode(HubMode.ballot, userPicked: true);
                    setState(() => _baselineExpanded = true);
                  },
                  child: HubCountPill(
                    icon: Icons.lock_clock,
                    text: '$decided decided',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- browse mode ----------------

  Widget _browseBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: RosterGallery(
        controller: widget.controller,
        onOpen: widget.onOpen,
        decisionChipBuilder: _decisionChip,
      ),
    );
  }

  /// Per-card status chips for the gallery. Their own AnimatedBuilder keeps
  /// realtime decision/vote updates from forcing a full grid rebuild. The
  /// [DecisionChip] is gated on a ready decisions load so a failed load never
  /// mislabels decided candidates as Undecided; browsing itself renders
  /// regardless of loadState.
  Widget _decisionChip(CandidateEntry e) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.repository, widget.votes]),
      builder: (context, _) {
        final my = widget.votes.myVote(e.id);
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (widget.repository.loadState == DecisionLoadState.ready)
              DecisionChip(
                  state: widget.repository.stateFor(e.id), compact: true),
            if (my != null) _MyVotePill(vote: my),
          ],
        );
      },
    );
  }

  // ---------------- ballot mode ----------------

  Widget _ballotBody(
      BuildContext context, bool narrow, double toolbarExtent) {
    if (!widget.controller.hasSubmissions) return _empty();
    return AnimatedBuilder(
      // The controller is merged in because search (the shared query
      // surface) and the slate itself live there.
      animation: Listenable.merge(
          [widget.repository, widget.votes, _activity, widget.controller]),
      builder: (context, _) {
        // Load gate FIRST: `stateFor` defaults missing entries to undecided,
        // so rendering before a SUCCESSFUL decisions load would put every
        // already-decided candidate back on tonight's ballot. No vote
        // controls, tallies, banners, or Confirm until the load is ready.
        switch (widget.repository.loadState) {
          case DecisionLoadState.loading:
            return _loading(context);
          case DecisionLoadState.failed:
            return _failed(context);
          case DecisionLoadState.ready:
            break;
        }
        // SECOND load gate, on the ballots themselves. A failed vote fetch
        // used to fall through to a fully rendered board on which nobody had
        // voted: every row "No ballots yet", the pill "0 / 50 voted", the
        // badge showing the whole ballot. That is indistinguishable from the
        // truth, and an exec would rationally respond by re-voting
        // everything, which (castVote always writes reason_codes: []) would
        // wipe their own captured reasons. Never render a tally we do not
        // have.
        switch (widget.votes.loadState) {
          case VoteLoadState.loading:
            return _loading(context, label: 'Loading ballots…');
          case VoteLoadState.failed:
            return _votesFailed(context);
          case VoteLoadState.ready:
            break;
        }

        final all = widget.controller.all;
        // Partition by decision STATE, not row existence: undecided (or
        // missing) = on the ballot; endorse/decline = locked baseline.
        // FULL-BALLOT AGGREGATE INVARIANT: every aggregate below (scoreboard,
        // quorum, progress pill, needsMyVoteCount, badges, copy summary)
        // computes from this unfiltered partition, never from the
        // search-filtered `visible`. And the ballot never consults the
        // browse-side research filters: a stale histogram drill-in
        // (focusAlignmentRange narrows the range AND clears unscored) must
        // never shrink tonight's ballot.
        final ballot = <CandidateEntry>[];
        final baseline = <CandidateEntry>[];
        for (final e in all) {
          (widget.repository.stateFor(e.id) == DecisionState.undecided
                  ? ballot
                  : baseline)
              .add(e);
        }
        final ballotIds = [for (final e in ballot) e.id];
        // Stale-expansion prune: a realtime decision landing mid-meeting
        // must not leave a locked candidate's row expanded.
        final ballotIdSet = ballotIds.toSet();
        _expanded.removeWhere((id) => !ballotIdSet.contains(id));
        final buckets = widget.votes.buckets(ballotIds);
        final query = widget.controller.search.trim().toLowerCase();
        // Search is the final pipeline step, after filter + sort.
        final visible =
            _visibleBallot(ballot, buckets).where(_matches).toList();
        // Search also covers the locked baseline so decided candidates
        // stay findable.
        final filteredBaseline = baseline.where(_matches).toList();
        final needsMyVoteCount =
            ballot.where((e) => widget.votes.myVote(e.id) == null).length;
        // Applicants per race across the UNION of the ballot and baseline
        // partitions, because a race can straddle the partition (House 39
        // does today: Lakins declined, Lloyd still open). This is the number
        // the race cap shows and the anchor of its self-defense; contested
        // detection (>= 2) keys on it too.
        final unfilteredRaceCounts = <String, int>{};
        for (final e in all) {
          final k = _raceKeyOf(e);
          if (k != null) {
            unfilteredRaceCounts[k] = (unfilteredRaceCounts[k] ?? 0) + 1;
          }
        }
        // The cluster pass: presentation-only regrouping of the already
        // filtered + sorted + searched `visible` list. Every aggregate above
        // and below keeps reading the unfiltered partitions.
        final items =
            _clusterContested(visible, ballot, baseline, unfilteredRaceCounts);

        final live =
            widget.repository.realtimeHealthy && widget.votes.realtimeHealthy;

        return RefreshIndicator(
          // BOTH repositories, not just votes. Pull-to-refresh used to cover
          // ballots only, which left the decision baseline as the one thing
          // an exec could not resync by hand after a phone sleep, and a stale
          // baseline is the worse of the two: stateFor defaults a missing row
          // to undecided, so a candidate decided while the phone was locked
          // stays on that exec's ballot and every count on their screen is
          // measured against a baseline that no longer exists.
          onRefresh: () => Future.wait([
            widget.votes.refresh(),
            widget.repository.refresh(),
          ]),
          edgeOffset: toolbarExtent,
          child: CustomScrollView(
            // Always scrollable so pull-to-refresh works on a short list.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _constrain(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VoteScoreboard(
                          ballot: ballot,
                          votes: widget.votes,
                          buckets: buckets,
                          onCopy: () =>
                              _copySummary(context, ballot, baseline, buckets),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          // The live-sync promise is CONDITIONAL now. The
                          // board used to assert "Every ballot syncs live to
                          // all execs" unconditionally while never checking
                          // the channel, so a dead subscription looked
                          // exactly like a healthy one.
                          'Yes, No or Undecided on each ballot candidate. '
                          'Tap your current choice again to withdraw it. '
                          '${live ? 'Every ballot syncs live to all execs.' : 'Live sync is reconnecting; pull down to refresh.'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                        if (!live) ...[
                          const SizedBox(height: 8),
                          const _ReconnectingBanner(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: BoardToolbarDelegate(
                  extent: toolbarExtent,
                  narrow: narrow,
                  searchController: _search,
                  query: query,
                  onQueryChanged: widget.controller.setSearch,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  showSplits: widget.isChair,
                  needsMyVoteCount: needsMyVoteCount,
                  sort: _sort,
                  onSortChanged: (s) => setState(() => _sort = s),
                  votedCount: ballot.length - needsMyVoteCount,
                  ballotTotal: ballot.length,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _constrain(
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: HubCardHeader(
                        icon: Icons.how_to_vote,
                        title: 'On the ballot tonight · ${ballot.length}',
                        // Search is the only shared query surface, so it is
                        // the only way this list can be narrowed, and the
                        // header self-defends against it.
                        subtitle: query.isNotEmpty &&
                                visible.length < ballot.length
                            ? '${visible.length} of ${ballot.length} shown '
                                '· search active'
                            : '${buckets.stillOpen.length} still open',
                        tileGradient: HubTheme.gradNavy,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final cs = Theme.of(context).colorScheme;
                    switch (items[i]) {
                      case final _RaceCapItem cap:
                        return _constrain(
                          _RaceCap(
                            key: ValueKey('race-cap-${cap.raceKey}'),
                            item: cap,
                            narrow: narrow,
                            query: query,
                            filter: _filter,
                            displayNameFor:
                                widget.controller.displayNameFor,
                            stateFor: widget.repository.stateFor,
                            onOpen: widget.onOpen,
                          ),
                        );
                      case final _BallotRowItem it:
                        final e = it.entry;
                        final row = RepaintBoundary(
                          child: BallotRow(
                            key: ValueKey(e.id),
                            entry: e,
                            votes: widget.votes,
                            repository: widget.repository,
                            isChair: widget.isChair,
                            bucket: buckets.bucketOf(e.id),
                            suggestion: buckets.suggestionFor[e.id],
                            expanded: _expanded.contains(e.id),
                            onToggleExpand: () => setState(() {
                              if (!_expanded.remove(e.id)) {
                                _expanded.add(e.id);
                              }
                            }),
                            onOpen: () => widget.onOpen(e),
                            onFinalCall: () => _openPanel(context, e),
                            districtRef: _districtRefFor(e),
                            narrow: narrow,
                            toolbarExtent: toolbarExtent,
                            displayName: widget.controller.displayNameFor(e),
                            conflictLabel: _conflictLabelFor(e),
                            raceDisclosure: _raceDisclosureFor(e),
                          ),
                        );
                        if (!it.inCluster) {
                          // Solo row: byte-identical wrapper to the
                          // pre-cluster board (8px gap, no rail, no indent).
                          return _constrain(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: row,
                            ),
                          );
                        }
                        // Cluster member: 2px connector rail + 4px gutter in
                        // the left margin OUTSIDE the card (the card's own
                        // 3px consensus accent strip is inside its border and
                        // untouched), inter-row gap tightened 8 -> 4. The
                        // rail is decorative reinforcement only; the race cap
                        // text above is the accessible signal.
                        //
                        // THE RAIL MUST BE A BORDER, NEVER A STRETCHED ROW.
                        // READ THIS BEFORE YOU "TIDY" IT BACK.
                        //
                        // af1ca855e drew this rail as
                        //   Row(crossAxisAlignment: CrossAxisAlignment.stretch,
                        //       children: [Container(width: 2), ..., Expanded(row)])
                        // and that single line silently truncated the whole
                        // ballot to the rows before the first contested race.
                        // The chair saw ONE candidate out of 26 on 2026-07-26.
                        // The chain, verified against Flutter 3.41.8 source:
                        //
                        //  1. A SliverList lays each child out with
                        //     `constraints.asBoxConstraints()`, whose
                        //     `maxExtent` defaults to double.infinity
                        //     (rendering/sliver.dart:483). So every ballot item
                        //     arrives with maxHeight == infinity.
                        //  2. `_constrain` below is Center + ConstrainedBox
                        //     (maxWidth only). Center calls
                        //     `constraints.loosen()`, so maxHeight stays
                        //     infinite all the way down to the Row.
                        //  3. CrossAxisAlignment.stretch on a horizontal
                        //     RenderFlex sets fillCrossAxis, which hands the
                        //     non-flex rail `BoxConstraints.tightFor(height:
                        //     constraints.maxHeight)` and the Expanded child
                        //     `minHeight: constraints.maxHeight`
                        //     (rendering/flex.dart:881-897 and 900-930). With
                        //     an infinite maxHeight that is a TIGHT INFINITE
                        //     HEIGHT, so the row's height came back infinity.
                        //  4. RenderSliverList fills forward with
                        //     `while (endScrollOffset < targetEndScrollOffset)`
                        //     (rendering/sliver_list.dart:276). Once
                        //     endScrollOffset is infinity that test is false
                        //     immediately: the loop exits, NO further index is
                        //     ever built, and scrollExtent extrapolates to
                        //     infinity, which is why the black area below
                        //     scrolled forever and never yielded a row.
                        //  5. The offending row itself painted nothing because
                        //     BallotRow's ClipRRect is built from a non-finite
                        //     size, so the card never reached the canvas.
                        //
                        // The assert that would have caught this ("RenderFlex
                        // object was given an infinite size during layout",
                        // rendering/box.dart) lives inside an `assert`, which
                        // is stripped from the release bundle Netlify ships.
                        // That is why it reached production silently.
                        //
                        // A left BorderSide has no such failure mode: a
                        // DecoratedBox sizes to its child, so the rail spans
                        // exactly the row's own height and the sliver keeps a
                        // finite extent. Geometry is unchanged: the border
                        // contributes 2px of inset (BoxDecoration.padding ->
                        // Border.dimensions) and the padding adds 4px, so the
                        // card still starts 6px in, exactly as before.
                        //
                        // The 4px inter-row gap sits INSIDE the bordered box
                        // (not outside it) so the rail spans the gap too and
                        // consecutive cluster members read as one continuous
                        // line, which is what the stretched Row was reaching
                        // for. The last member drops the gap so the rail ends
                        // flush with its card.
                        final railed = Container(
                          padding: EdgeInsets.only(
                              left: 4, bottom: it.lastInCluster ? 0 : 4),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: cs.primary.withOpacity(0.35),
                                width: 2,
                              ),
                            ),
                          ),
                          child: row,
                        );
                        return _constrain(
                          it.lastInCluster
                              ? Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: railed,
                                )
                              : railed,
                        );
                    }
                  },
                ),
              ),
              if (visible.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _constrain(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _emptyBallotState(
                            context, ballot, query, needsMyVoteCount),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _constrain(
                    BaselineSection(
                      entries: filteredBaseline,
                      totalCount: baseline.length,
                      // A matching search query forces the section open for
                      // that build so decided candidates surface.
                      expanded: _baselineExpanded ||
                          (query.isNotEmpty && filteredBaseline.isNotEmpty),
                      onToggle: () => setState(
                          () => _baselineExpanded = !_baselineExpanded),
                      stateFor: widget.repository.stateFor,
                      recordFor: widget.repository.recordFor,
                      attribution: DecisionAttributionRepository.instance,
                      displayNameFor: widget.controller.displayNameFor,
                      onOpen: widget.onOpen,
                      onChangeState: _changeDecision,
                    ),
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        );
      },
    );
  }

  Widget _loading(BuildContext context, {String label = 'Loading decisions…'}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 14),
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Failed decisions load: an inline retry card instead of a full-tab dead
  /// end. Browsing stays alive one tap away; voting stays gated behind the
  /// reload; every badge is hidden.
  Widget _failed(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _constrain(
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HubCardHeader(
                  icon: Icons.cloud_off,
                  tileGradient: HubTheme.gradAmber,
                  title: 'Could not load the decision baseline',
                  subtitle:
                      'Voting is paused until it reloads. Browsing still works.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.repository.reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                          backgroundColor: HubTheme.navy,
                          foregroundColor: Colors.white),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _setMode(HubMode.browse, userPicked: true),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text('Browse the roster'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Failed BALLOT load: the same inline retry card as the decisions failure,
  /// for the same reason. The alternative is a board that renders every
  /// tally as zero, which reads as "nobody has voted yet" and is the one
  /// wrong answer an exec would act on.
  Widget _votesFailed(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _constrain(
          HubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HubCardHeader(
                  icon: Icons.cloud_off,
                  tileGradient: HubTheme.gradAmber,
                  title: "Could not load tonight's ballots",
                  subtitle: 'Your votes are safe. Nothing is shown until the '
                      'tallies load, so the board cannot understate them.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.votes.reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                          backgroundColor: HubTheme.navy,
                          foregroundColor: Colors.white),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _setMode(HubMode.browse, userPicked: true),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text('Browse the roster'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyBallotState(BuildContext context, List<CandidateEntry> ballot,
      String query, int needsMyVoteCount) {
    if (ballot.isEmpty) {
      return const HubEmptyState(
        icon: Icons.verified_outlined,
        title: 'Every candidate is decided',
        message: "The locked baseline below is the committee's full slate.",
      );
    }
    if (_filter == VoteFilter.needsMyVote && needsMyVoteCount == 0) {
      return _allInCard(context);
    }
    return Center(
      child: Text(
        // An active search empties the list regardless of filter or ballot
        // state, so it owns the message.
        query.isNotEmpty
            ? 'No candidates match your search.'
            : 'Nothing on the ballot right now.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  /// The finished-voting card: the one earned gradient beyond the hero.
  /// White-on-gradEmerald is AA end to end by the HubTheme contract.
  Widget _allInCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: HubTheme.gradEmerald,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.verified, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("You're all in", style: HubTheme.onGradientTitle),
                    SizedBox(height: 2),
                    Text(
                        'Every ballot has your vote. Watch the room below or '
                        'browse the slate.',
                        style: HubTheme.onGradientSub),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _setMode(HubMode.browse, userPicked: true),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Browse the roster'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _filter = VoteFilter.all),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Show all ballots'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Change or reopen an already decided candidate.
  ///
  /// The baseline used to be frozen, on the theory that a recorded decision
  /// should not move. The chair's ruling on 2026-07-26 is the opposite: "it
  /// shouldn't be locked, if they want to go in and change those decisions
  /// that's fine". Choosing Undecided here drops the candidate back onto
  /// tonight's ballot on every device.
  ///
  /// Uses the CHECKED write path, so a failed write leaves the row exactly
  /// where it was on every device rather than showing a change that did not
  /// persist. endorsement_decisions records updated_by and updated_at, so who
  /// moved it stays on the record either way.
  Future<void> _changeDecision(CandidateEntry e, DecisionState next) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.repository.trySetState(e.id, next);
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(SnackBar(
        content: const Text("That didn't save. Nothing was changed."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
            label: 'Retry', onPressed: () => _changeDecision(e, next)),
      ));
      return;
    }
    if (next == DecisionState.undecided) {
      messenger.showSnackBar(SnackBar(
        content: Text('${widget.controller.displayNameFor(e)} is back on the '
            'ballot.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Every sliver child reads best at a bounded width: single full-width
  /// column, centered past 1040.
  Widget _constrain(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: child,
        ),
      );

  void _openPanel(BuildContext context, CandidateEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FinalCallPanel(
        entry: e,
        repository: widget.repository,
        votes: widget.votes,
        activity: _activity,
        onOpen: () {
          Navigator.pop(ctx);
          widget.onOpen(e);
        },
      ),
    );
  }

  void _copySummary(
    BuildContext context,
    List<CandidateEntry> ballot,
    List<CandidateEntry> baseline,
    VoteBuckets buckets,
  ) {
    String bucketLabel(String id) => switch (buckets.bucketOf(id)) {
          VoteBucket.consensusReady => buckets.suggestionFor[id] == 'yes'
              ? 'Consensus: Endorse'
              : 'Consensus: Decline',
          VoteBucket.split => 'Split',
          VoteBucket.stillOpen => 'Still open',
        };
    final buf = StringBuffer();
    buf.writeln('# Endorsement committee vote');
    buf.writeln();
    buf.writeln(
        quorumSentence(buckets.effectiveQuorum, buckets.participants));
    buf.writeln();
    buf.writeln('## On the ballot (${ballot.length})');
    buf.writeln();
    buf.writeln('| Candidate | Office | Yes | No | Undecided | Status |');
    buf.writeln('| --- | --- | --- | --- | --- | --- |');
    final sorted = ballot.toList()
      ..sort((a, b) {
        final ta = widget.votes.tallyFor(a.id);
        final tb = widget.votes.tallyFor(b.id);
        return (tb.yesShare ?? -1).compareTo(ta.yesShare ?? -1);
      });
    for (final e in sorted) {
      final t = widget.votes.tallyFor(e.id);
      buf.writeln('| ${widget.controller.displayNameFor(e)} '
          '| ${e.officeLine.isEmpty ? '-' : e.officeLine} '
          '| ${t.yes} | ${t.no} | ${t.undecided} | ${bucketLabel(e.id)} |');
    }
    if (baseline.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Already decided (${baseline.length})');
      buf.writeln();
      buf.writeln('| Candidate | Office | Final call |');
      buf.writeln('| --- | --- | --- |');
      for (final e in baseline) {
        buf.writeln('| ${widget.controller.displayNameFor(e)} '
            '| ${e.officeLine.isEmpty ? '-' : e.officeLine} '
            '| ${widget.repository.stateFor(e.id).label} |');
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Vote summary copied (markdown)'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _empty() {
    return const HubEmptyState(
      icon: Icons.how_to_vote_outlined,
      title: 'No candidates to vote on yet',
      message: 'Once submissions arrive, every exec casts Yes, No or '
          'Undecided on each candidate. Ballots sync live to the whole '
          'committee.',
    );
  }
}

/// Item model for the ballot sliver once the cluster pass has run: a small
/// sealed union so the single SliverList can interleave race caps with
/// [BallotRow]s. Rows keep `ValueKey(e.id)`, so `_expanded` (keyed by id) and
/// the reveal-on-expand scroll survive regrouping for free.
sealed class _BallotItem {
  const _BallotItem();
}

class _RaceCapItem extends _BallotItem {
  final String raceKey;

  /// Compact race label ("Missouri House 39").
  final String raceLabel;

  /// Applicants in this race across the unfiltered ballot + baseline union.
  final int applicantCount;

  /// Still-visible ballot members under the current filter + search.
  final int visibleCount;

  /// Ballot-partition members regardless of filter/search: the number
  /// [visibleCount] is compared against for the cap's self-defense.
  final int unfilteredBallotCount;

  /// Race mates already decided (locked baseline): surfaced as a tappable
  /// suffix because that context must sit next to the live opponent.
  final List<CandidateEntry> decidedMates;

  const _RaceCapItem({
    required this.raceKey,
    required this.raceLabel,
    required this.applicantCount,
    required this.visibleCount,
    required this.unfilteredBallotCount,
    required this.decidedMates,
  });
}

class _BallotRowItem extends _BallotItem {
  final CandidateEntry entry;
  final bool inCluster;
  final bool lastInCluster;
  const _BallotRowItem(this.entry,
      {required this.inCluster, required this.lastInCluster});
}

/// The one-line race cap above a contested cluster: gradient icon tile,
/// "Same race · Missouri House 39", applicant-count pill, an honest
/// "1 of 2 shown" whenever filtering or search hides a race mate, and the
/// decided-mates suffix.
///
/// SELF-DEFENSE IS KEYED ON THE COUNT MISMATCH ITSELF, not on
/// query.isNotEmpty: the needsMyVote filter and the chair-only splits filter
/// also hide race mates, and a filtered cluster must never masquerade as a
/// solo race. The cause is appended only when it is known.
class _RaceCap extends StatelessWidget {
  final _RaceCapItem item;
  final bool narrow;
  final String query;
  final VoteFilter filter;
  final String Function(CandidateEntry) displayNameFor;
  final DecisionState Function(String candidateId) stateFor;
  final void Function(CandidateEntry) onOpen;

  const _RaceCap({
    super.key,
    required this.item,
    required this.narrow,
    required this.query,
    required this.filter,
    required this.displayNameFor,
    required this.stateFor,
    required this.onOpen,
  });

  String _pastTense(DecisionState s) => switch (s) {
        DecisionState.endorse => 'Endorsed',
        DecisionState.decline => 'Declined',
        DecisionState.undecided => 'Undecided',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.labelSmall
        ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700);

    final hidden = item.visibleCount < item.unfilteredBallotCount;
    String? cause;
    if (hidden) {
      cause = query.isNotEmpty
          ? 'search active'
          : (filter != VoteFilter.all ? 'filtered' : null);
    }

    final children = <Widget>[
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          gradient: HubTheme.chip,
          borderRadius: BorderRadius.circular(6),
        ),
        child:
            const Icon(Icons.compare_arrows, size: 14, color: Colors.white),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text('Same race · ${item.raceLabel}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
      ),
      const SizedBox(width: 6),
      // Always plural: caps only exist for races with 2+ applicants (the
      // cluster pass passes solo rows through without a cap).
      HubCountPill(text: '${item.applicantCount} applicants'),
      if (hidden) ...[
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${item.visibleCount} of ${item.unfilteredBallotCount} shown'
            '${cause != null ? ' · $cause' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    ];

    if (item.decidedMates.isNotEmpty) {
      if (narrow) {
        // The suffix collapses to one compact pill so the cap never wraps
        // and never pushes a BallotRow below the fold mid-meeting. Opens the
        // first decided mate (there is one in the real data: Tanya Lakins).
        final n = item.decidedMates.length;
        children.addAll([
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onOpen(item.decidedMates.first),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: MoydBrand.neutralBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('+$n decided',
                  style: const TextStyle(
                      color: MoydBrand.neutralFg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]);
      } else {
        for (final mate in item.decidedMates) {
          children.addAll([
            const SizedBox(width: 8),
            Flexible(
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onOpen(mate),
                child: Text(
                  '${displayNameFor(mate)} · '
                  '${_pastTense(stateFor(mate.id))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.outlineVariant),
                ),
              ),
            ),
          ]);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: ConstrainedBox(
        // 28, not 24: HubCountPill's intrinsic height is ~27px (10px of
        // vertical padding plus a 12px-font text line), and 24 vertically
        // compresses the pill so descenders clip in both themes.
        //
        // minHeight, not a fixed SizedBox(height: 28): 28 leaves ~1px of
        // slack at textScale 1.0, so any exec running a bumped OS/browser
        // font size overflowed a hard 28 and clipped the pill's descenders
        // in the release build (which shows no overflow stripes). A minimum
        // keeps the cap's resting height identical while letting it grow.
        constraints: const BoxConstraints(minHeight: 28),
        child: Row(children: children),
      ),
    );
  }
}

/// Shown when either realtime channel is not currently joined.
///
/// Before this existed, a dead subscription was completely invisible: both
/// repositories called `.subscribe()` with no status callback, so
/// CHANNEL_ERROR, TIMED_OUT and CLOSED were all swallowed, and the board went
/// on promising "Every ballot syncs live to all execs" while receiving
/// nothing. An exec had no way to know their board had gone stale, and
/// therefore no reason to pull to refresh.
///
/// Colours are the documented self-contained MoydBrand warning pair
/// (qualifiedFg #8A5A00 on qualifiedBg #FBEDD1, 5.1:1), which is
/// theme-independent by construction: a light chip with dark text reads the
/// same on the OLED dark surface the chair uses and on the light one. Never
/// colour alone: the word "Reconnecting" and an icon both carry the state.
class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MoydBrand.qualifiedBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.sync_problem, size: 16, color: MoydBrand.qualifiedFg),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reconnecting. This board may be behind: pull down to refresh.',
              style: TextStyle(
                color: MoydBrand.qualifiedFg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The My ballot / Browse segmented pill, cloned from the hub's compare-mode
/// switch: neutral surfaceContainerHighest container, chip gradient only on
/// the active segment. Both states derive from ColorScheme roles or a
/// gradient proven for white text, so the pill is legible in both themes.
class _ModeSwitch extends StatelessWidget {
  final HubMode mode;
  final ValueChanged<HubMode> onChanged;

  /// Open-ballot count for the gold badge on the My ballot segment; null
  /// hides the badge (zero open, or the decisions load is not ready).
  final int? ballotBadge;

  const _ModeSwitch({
    required this.mode,
    required this.onChanged,
    required this.ballotBadge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(HubMode m, IconData icon, String label, {int? badge}) {
      final active = mode == m;
      return InkWell(
        onTap: () => onChanged(m),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? HubTheme.chip : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16, color: active ? Colors.white : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : cs.onSurface)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    // Gold pill with navy text (~6.5:1): AA on the neutral
                    // pill AND on the active chip gradient in both themes.
                    color: HubTheme.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: HubTheme.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(HubMode.ballot, Icons.how_to_vote_outlined, 'My ballot',
              badge: ballotBadge),
          const SizedBox(width: 2),
          seg(HubMode.browse, Icons.grid_view_rounded, 'Browse'),
        ],
      ),
    );
  }
}

/// "You: Yes / No / Undecided" pill for the gallery cards, using the
/// documented self-contained MoydBrand stance pairs (light bg, dark fg, AA on
/// cs.surface in both themes).
class _MyVotePill extends StatelessWidget {
  final String vote; // 'yes' | 'no' | 'undecided'
  const _MyVotePill({required this.vote});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (vote) {
      'yes' => ('You: Yes', MoydBrand.supportFg, MoydBrand.supportBg),
      'no' => ('You: No', MoydBrand.opposeFg, MoydBrand.opposeBg),
      _ => ('You: Undecided', MoydBrand.neutralFg, MoydBrand.neutralBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}
