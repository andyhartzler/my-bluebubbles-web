import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/moyd_brand.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../../theme/hub_theme.dart';
import '../decisions/ballot_row.dart';
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

  bool _matches(CandidateEntry e) {
    final q = widget.controller.search.trim().toLowerCase();
    return q.isEmpty ||
        e.name.toLowerCase().contains(q) ||
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
    }
    return entries;
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

        return RefreshIndicator(
          onRefresh: widget.votes.refresh,
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
                          'Yes, No or Undecided on each ballot candidate. '
                          'Tap your current choice again to withdraw it. '
                          'Every ballot syncs live to all execs.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
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
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final e = visible[i];
                    return _constrain(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RepaintBoundary(
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
                          ),
                        ),
                      ),
                    );
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
                      onOpen: widget.onOpen,
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

  Widget _loading(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 14),
          Text('Loading decisions…',
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
    buf.writeln('Quorum tonight: ${buckets.effectiveQuorum} of '
        '${buckets.participants} voting');
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
      buf.writeln('| ${e.name} '
          '| ${e.officeLine.isEmpty ? '-' : e.officeLine} '
          '| ${t.yes} | ${t.no} | ${t.undecided} | ${bucketLabel(e.id)} |');
    }
    if (baseline.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Locked baseline (${baseline.length})');
      buf.writeln();
      buf.writeln('| Candidate | Office | Final call |');
      buf.writeln('| --- | --- | --- |');
      for (final e in baseline) {
        buf.writeln('| ${e.name} '
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
