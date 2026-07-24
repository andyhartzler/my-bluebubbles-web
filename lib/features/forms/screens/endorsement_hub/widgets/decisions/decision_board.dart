import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../../theme/hub_theme.dart';
import 'ballot_row.dart';
import 'baseline_row.dart';
import 'board_toolbar.dart';
import 'decision_activity.dart';
import 'decision_repository.dart';
import 'district_ref.dart';
import 'endorsement_vote_repository.dart';
import 'final_call_panel.dart';
import 'vote_scoreboard.dart';

/// Chair identity. The uid is primary (verified against auth.users
/// last_sign_in 2026-07-21: andrew@hartzler.us); the email set is a safety
/// net so a stale uid can never lock the chair out of Confirm / final call
/// on meeting night. Not user-configurable tonight.
const String kChairUserId = 'f1ac8208-ad64-405f-8b55-8284ddef51cf';
const Set<String> kChairEmails = {
  'andrew@hartzler.us',
  'andrew@moyoungdemocrats.org',
};

/// Whether the signed-in auth user is the committee chair.
bool isChairUser(User? u) {
  if (u == null) return false;
  if (u.id == kChairUserId) return true;
  final email = u.email?.toLowerCase();
  if (email != null && kChairEmails.contains(email)) {
    debugPrint(
        'CHAIR FALLBACK: uid ${u.id} matched by email $email, kChairUserId is wrong');
    return true; // email fallback so a stale uid does not brick the meeting
  }
  return false;
}

/// The committee VOTING board for meeting night.
///
/// Candidates are partitioned by decision STATE, never by row existence:
/// anything the committee has already endorsed/declined renders as a locked,
/// read-only baseline; everything else is "on the ballot" as one compact
/// [BallotRow] (vote from the row, tap to expand in place) under a sticky
/// [BoardToolbar] with search / filters / sort / ballot progress. Only the
/// chair can turn a ballot into a shared decision (Confirm on
/// consensus-ready rows, or the final-call panel).
class DecisionBoard extends StatefulWidget {
  final SlateController controller;
  final DecisionRepository repository;
  final EndorsementVoteRepository votes;
  final bool isChair;
  final void Function(CandidateEntry) onOpen;

  const DecisionBoard({
    super.key,
    required this.controller,
    required this.repository,
    required this.votes,
    required this.isChair,
    required this.onOpen,
  });

  @override
  State<DecisionBoard> createState() => _DecisionBoardState();
}

class _DecisionBoardState extends State<DecisionBoard> {
  late final DecisionActivity _activity = DecisionActivity(widget.repository);
  Timer? _clock;

  // Meeting default: show each exec what still needs their ballot.
  VoteFilter _filter = VoteFilter.needsMyVote;
  VoteSort _sort = VoteSort.yesShare;
  bool _baselineExpanded = false;

  final TextEditingController _search = TextEditingController();
  String _query = ''; // lowercased, trimmed

  /// Expanded candidate ids (multi-expand). Keyed by id so expansion survives
  /// re-sort, re-filter and realtime rebuilds; filtered-out ids just don't
  /// render.
  final Set<String> _expanded = <String>{};

  /// Parsed district refs, memoized per candidate (entries are immutable per
  /// load, so the parse never needs to re-run).
  final Map<String, DistrictRef?> _districtRefs = {};

  @override
  void initState() {
    super.initState();
    // Keep the relative "2m ago" attributions fresh.
    _clock = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _activity.dispose();
    _search.dispose();
    super.dispose();
  }

  DistrictRef? _districtRefFor(CandidateEntry e) => _districtRefs.putIfAbsent(
      e.id,
      () => parseDistrictRef(
          office: e.model.office, district: e.model.district));

  bool _matches(CandidateEntry e) =>
      _query.isEmpty ||
      e.name.toLowerCase().contains(_query) ||
      e.officeLine.toLowerCase().contains(_query);

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
    if (!widget.controller.hasSubmissions) {
      return _empty();
    }
    // ONE breakpoint drives the row layout and the toolbar's extent.
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 720;
      final toolbarExtent = narrow ? 116.0 : 64.0;
      return AnimatedBuilder(
        animation:
            Listenable.merge([widget.repository, widget.votes, _activity]),
        builder: (context, _) {
          // Load gate: `stateFor` defaults missing entries to undecided, so
          // rendering before a SUCCESSFUL decisions load would put every
          // already-decided candidate back on tonight's ballot. No vote
          // controls, tallies, banners, or Confirm until the load is ready.
          switch (widget.repository.loadState) {
            case DecisionLoadState.loading:
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 14),
                    Text('Loading decisions…',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            case DecisionLoadState.failed:
              return HubEmptyState(
                icon: Icons.cloud_off,
                title: 'Could not load the decision baseline',
                message:
                    'The shared endorse/decline record did not load, so the '
                    'ballot cannot be trusted yet. Retry before voting.',
                action: FilledButton.icon(
                  onPressed: widget.repository.reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                      backgroundColor: HubTheme.navy,
                      foregroundColor: Colors.white),
                ),
              );
            case DecisionLoadState.ready:
              break;
          }

          final all = widget.controller.all;
          // Partition by decision STATE, not row existence: undecided (or
          // missing) = on the ballot; endorse/decline = locked baseline.
          final ballot = <CandidateEntry>[];
          final baseline = <CandidateEntry>[];
          for (final e in all) {
            (widget.repository.stateFor(e.id) == DecisionState.undecided
                    ? ballot
                    : baseline)
                .add(e);
          }
          final ballotIds = [for (final e in ballot) e.id];
          final buckets = widget.votes.buckets(ballotIds);
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
                SliverToBoxAdapter(
                  child: _constrain(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VoteScoreboard(
                          ballot: ballot,
                          votes: widget.votes,
                          buckets: buckets,
                          onCopy: () => _copySummary(
                              context, ballot, baseline, buckets),
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
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BoardToolbarDelegate(
                    extent: toolbarExtent,
                    narrow: narrow,
                    searchController: _search,
                    query: _query,
                    onQueryChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
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
                SliverToBoxAdapter(
                  child: _constrain(
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: HubCardHeader(
                        icon: Icons.how_to_vote,
                        title: 'On the ballot tonight · ${ballot.length}',
                        subtitle: '${buckets.stillOpen.length} still open',
                        tileGradient: HubTheme.gradNavy,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 10),
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
                  SliverToBoxAdapter(
                    child: _constrain(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            // An active search empties the list regardless of
                            // filter or ballot state, so it owns the message.
                            _query.isNotEmpty
                                ? 'No candidates match your search.'
                                : _filter == VoteFilter.needsMyVote &&
                                        ballot.isNotEmpty
                                    ? 'You have voted on every ballot '
                                        'candidate. Nice work.'
                                    : 'Nothing on the ballot right now.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _constrain(
                    BaselineSection(
                      entries: filteredBaseline,
                      totalCount: baseline.length,
                      // A matching search query forces the section open for
                      // that build so decided candidates surface.
                      expanded: _baselineExpanded ||
                          (_query.isNotEmpty && filteredBaseline.isNotEmpty),
                      onToggle: () => setState(
                          () => _baselineExpanded = !_baselineExpanded),
                      stateFor: widget.repository.stateFor,
                      onOpen: widget.onOpen,
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      );
    });
  }

  /// Every sliver child reads best at a bounded width: single full-width
  /// column, centered past 1040 (the old 2-up desktop grid is retired).
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
