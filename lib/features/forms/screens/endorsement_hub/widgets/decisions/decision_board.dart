import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../slate_controller.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'decision_activity.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';
import 'endorsement_vote_repository.dart';
import 'vote_reason_sheet.dart';

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
/// read-only baseline; everything else is "on the ballot" with a per-exec
/// Yes / No / Undecided control, live tallies, and consensus buckets driven
/// by a dynamic quorum. Only the chair can turn a ballot into a shared
/// decision (Confirm on consensus-ready cards, or the final-call panel).
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

enum _VoteFilter { all, needsMyVote, splits }

enum _VoteSort { yesShare, name, alignment }

class _DecisionBoardState extends State<DecisionBoard> {
  late final DecisionActivity _activity = DecisionActivity(widget.repository);
  Timer? _clock;

  // Meeting default: show each exec what still needs their ballot.
  _VoteFilter _filter = _VoteFilter.needsMyVote;
  _VoteSort _sort = _VoteSort.yesShare;
  bool _baselineExpanded = false;

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
    super.dispose();
  }

  List<CandidateEntry> _visibleBallot(
      List<CandidateEntry> ballot, VoteBuckets buckets) {
    var entries = ballot.toList();
    int byName(CandidateEntry a, CandidateEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (_filter == _VoteFilter.needsMyVote) {
      entries =
          entries.where((e) => widget.votes.myVote(e.id) == null).toList();
    }
    if (_filter == _VoteFilter.splits) {
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
      case _VoteSort.name:
        entries.sort(byName);
      case _VoteSort.alignment:
        entries.sort((a, b) {
          final av = a.alignmentPct ?? -1;
          final bv = b.alignmentPct ?? -1;
          final c = bv.compareTo(av);
          return c != 0 ? c : byName(a, b);
        });
      case _VoteSort.yesShare:
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
    final theme = Theme.of(context);
    if (!widget.controller.hasSubmissions) {
      return _empty();
    }
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
        final visible = _visibleBallot(ballot, buckets);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VoteHeader(
              ballot: ballot,
              votes: widget.votes,
              buckets: buckets,
              onCopy: () => _copySummary(context, ballot, baseline, buckets),
            ),
            const SizedBox(height: 10),
            Text(
              'Yes, No or Undecided on each ballot candidate — tap your '
              'current choice again to withdraw it. Every ballot syncs live '
              'to all execs.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            // Filter + sort controls: on phone widths the segmented filter
            // uses compact labels and scrolls inside its own box if it still
            // cannot fit, so this row never overflows the page.
            LayoutBuilder(builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final filterSwitch = _FilterSwitch(
                filter: _filter,
                compact: narrow,
                showSplits: widget.isChair,
                needsMyVoteCount: ballot
                    .where((e) => widget.votes.myVote(e.id) == null)
                    .length,
                onChanged: (f) => setState(() => _filter = f),
              );
              final sortMenu = _SortMenu(
                sort: _sort,
                onChanged: (s) => setState(() => _sort = s),
              );
              if (narrow) {
                return Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: filterSwitch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    sortMenu,
                  ],
                );
              }
              return Row(
                children: [filterSwitch, const Spacer(), sortMenu],
              );
            }),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.votes.refresh,
                child: LayoutBuilder(builder: (context, constraints) {
                  final twoUp = constraints.maxWidth >= 1000;
                  return _boardList(
                    twoUp: twoUp,
                    visible: visible,
                    ballotCount: ballot.length,
                    stillOpen: buckets.stillOpen.length,
                    baseline: baseline,
                    buckets: buckets,
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The scrollable board: ballot header, lazily-built vote cards (1-col on
  /// phones, 2-up rows on wide screens — never an eager Column of all cards),
  /// then the collapsed locked-baseline section.
  Widget _boardList({
    required bool twoUp,
    required List<CandidateEntry> visible,
    required int ballotCount,
    required int stillOpen,
    required List<CandidateEntry> baseline,
    required VoteBuckets buckets,
  }) {
    final cardRows = twoUp ? (visible.length + 1) ~/ 2 : visible.length;
    final showEmpty = visible.isEmpty;
    // items: [ballot header] + [empty note | card rows] + [baseline section]
    final itemCount = 1 + (showEmpty ? 1 : cardRows) + 1;
    return ListView.builder(
      // Always scrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HubCardHeader(
              icon: Icons.how_to_vote,
              title: 'On the ballot tonight · $ballotCount',
              subtitle: '$stillOpen still open',
              tileGradient: HubTheme.gradNavy,
            ),
          );
        }
        if (showEmpty && i == 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _filter == _VoteFilter.needsMyVote && ballotCount > 0
                    ? 'You have voted on every ballot candidate. Nice work.'
                    : 'Nothing on the ballot right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
        final idx = i - 1;
        if (!showEmpty && idx < cardRows) {
          if (!twoUp) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RepaintBoundary(child: _voteCard(visible[idx], buckets)),
            );
          }
          final a = visible[idx * 2];
          final b =
              idx * 2 + 1 < visible.length ? visible[idx * 2 + 1] : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: RepaintBoundary(child: _voteCard(a, buckets))),
                const SizedBox(width: 12),
                Expanded(
                  child: b == null
                      ? const SizedBox.shrink()
                      : RepaintBoundary(child: _voteCard(b, buckets)),
                ),
              ],
            ),
          );
        }
        return _baselineSection(baseline);
      },
    );
  }

  Widget _voteCard(CandidateEntry e, VoteBuckets buckets) {
    return _VoteCard(
      entry: e,
      votes: widget.votes,
      repository: widget.repository,
      isChair: widget.isChair,
      bucket: buckets.bucketOf(e.id),
      suggestion: buckets.suggestionFor[e.id],
      onOpen: () => widget.onOpen(e),
      onFinalCall: () => _openPanel(context, e),
    );
  }

  /// "Locked baseline": the decisions the committee already made, read-only.
  /// Nothing in the vote path can mutate these; a chair Confirm (elsewhere)
  /// is the only way a candidate ever moves in here tonight.
  Widget _baselineSection(List<CandidateEntry> baseline) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (baseline.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _baselineExpanded = !_baselineExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(
                  child: HubCardHeader(
                    icon: Icons.lock_clock,
                    title: 'Locked baseline · ${baseline.length} decided',
                    subtitle: 'Shared decisions already made — read-only',
                    tileGradient: HubTheme.gradAmber,
                  ),
                ),
                Icon(
                  _baselineExpanded ? Icons.expand_less : Icons.expand_more,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _baselineExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in baseline)
                    _BaselineRow(
                      entry: e,
                      state: widget.repository.stateFor(e.id),
                      onOpen: () => widget.onOpen(e),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPanel(BuildContext context, CandidateEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DecisionPanel(
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
          '| ${e.officeLine.isEmpty ? '—' : e.officeLine} '
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
            '| ${e.officeLine.isEmpty ? '—' : e.officeLine} '
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

// ==================== summary header ====================

/// Branded gradient scoreboard: the room's shared consensus buckets
/// (ready / split / still open), the live quorum, and the signed-in member's
/// ballot progress. Dark navy gradient with white/gold text so it reads
/// identically in both themes.
class _VoteHeader extends StatelessWidget {
  final List<CandidateEntry> ballot;
  final EndorsementVoteRepository votes;
  final VoteBuckets buckets;
  final VoidCallback onCopy;

  const _VoteHeader({
    required this.ballot,
    required this.votes,
    required this.buckets,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    var mine = 0;
    for (final e in ballot) {
      if (votes.myVote(e.id) != null) mine++;
    }
    final total = ballot.length;
    final done = total > 0 && mine == total;

    return Container(
      decoration: BoxDecoration(
        gradient: HubTheme.hero,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: HubTheme.royal.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.how_to_vote,
                    color: HubTheme.gold, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Committee vote',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              const _LivePill(),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Copy vote summary (markdown)',
                child: IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy,
                      color: Colors.white, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Quorum tonight: ${buckets.effectiveQuorum} of '
            '${buckets.participants} voting',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryTile(
                icon: Icons.verified,
                iconBg: MoydBrand.supportFg,
                count: buckets.consensusReady.length,
                label: 'CONSENSUS READY',
              ),
              _SummaryTile(
                icon: Icons.forum,
                iconBg: MoydBrand.opposeFg,
                count: buckets.split.length,
                label: 'SPLIT',
              ),
              _SummaryTile(
                icon: Icons.hourglass_empty,
                iconBg: MoydBrand.neutralFg,
                count: buckets.stillOpen.length,
                label: 'STILL OPEN',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : mine / total,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(HubTheme.gold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done
                    ? 'You voted on all $total 🗳️'
                    : 'You voted on $mine of $total',
                style: TextStyle(
                    color: done ? HubTheme.goldBright : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final int count;
  final String label;
  const _SummaryTile({
    required this.icon,
    required this.iconBg,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" pill (white text on navy stays AA; the dot is decorative).
class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ],
      ),
    );
  }
}

// ==================== filter / sort ====================

/// "All" / "Needs my vote" / (chair-only) "Splits" segmented pill, matching
/// the hub's segmented-switch treatment (navy gradient on the active segment).
class _FilterSwitch extends StatelessWidget {
  final _VoteFilter filter;
  final int needsMyVoteCount;
  final bool showSplits;
  final ValueChanged<_VoteFilter> onChanged;

  /// Compact (phone) mode: shorter segment labels so the switch fits a
  /// ~360px viewport beside the sort menu.
  final bool compact;

  const _FilterSwitch({
    required this.filter,
    required this.needsMyVoteCount,
    required this.showSplits,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(_VoteFilter f, IconData icon, String label) {
      final active = filter == f;
      return InkWell(
        onTap: () => onChanged(f),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? HubTheme.chip : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15, color: active ? Colors.white : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : cs.onSurface)),
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
          seg(_VoteFilter.all, Icons.groups_2_outlined,
              compact ? 'All' : 'All candidates'),
          const SizedBox(width: 2),
          seg(
            _VoteFilter.needsMyVote,
            Icons.pending_actions,
            needsMyVoteCount > 0
                ? (compact
                    ? 'Needs vote ($needsMyVoteCount)'
                    : 'Needs my vote ($needsMyVoteCount)')
                : (compact ? 'Needs vote' : 'Needs my vote'),
          ),
          if (showSplits) ...[
            const SizedBox(width: 2),
            seg(_VoteFilter.splits, Icons.call_split, 'Splits'),
          ],
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final _VoteSort sort;
  final ValueChanged<_VoteSort> onChanged;
  const _SortMenu({required this.sort, required this.onChanged});

  String _label(_VoteSort s) => switch (s) {
        _VoteSort.yesShare => 'Yes share',
        _VoteSort.name => 'Name',
        _VoteSort.alignment => 'Alignment',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<_VoteSort>(
      tooltip: 'Sort candidates',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final s in _VoteSort.values)
          PopupMenuItem(value: s, child: Text('Sort by ${_label(s)}')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(_label(sort),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ==================== baseline row ====================

/// One locked, already-decided candidate: compact identity + the shared
/// decision chip + a lock glyph. No vote controls, no tally, no final call.
class _BaselineRow extends StatelessWidget {
  final CandidateEntry entry;
  final DecisionState state;
  final VoidCallback onOpen;
  const _BaselineRow({
    required this.entry,
    required this.state,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: 0.92,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              HeadshotAvatar(file: entry.headshot, name: entry.name, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (entry.officeLine.isNotEmpty)
                      Text(entry.officeLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DecisionChip(state: state, compact: true),
              const SizedBox(width: 8),
              Icon(Icons.lock, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== vote card ====================

/// One ballot candidate's card: identity row, the 3-way Yes / No / Undecided
/// control, the live tally, the voter roster, the caster's own reason echo,
/// and (when consensus is reached) the banner with the chair-only Confirm.
class _VoteCard extends StatefulWidget {
  final CandidateEntry entry;
  final EndorsementVoteRepository votes;
  final DecisionRepository repository;
  final bool isChair;
  final VoteBucket bucket;
  final String? suggestion; // 'yes' | 'no' when bucket == consensusReady
  final VoidCallback onOpen;
  final VoidCallback onFinalCall;

  const _VoteCard({
    required this.entry,
    required this.votes,
    required this.repository,
    required this.isChair,
    required this.bucket,
    required this.suggestion,
    required this.onOpen,
    required this.onFinalCall,
  });

  @override
  State<_VoteCard> createState() => _VoteCardState();
}

class _VoteCardState extends State<_VoteCard> {
  bool _confirming = false;

  Future<void> _handleVote(String choice) async {
    final wasMine = widget.votes.myVote(widget.entry.id);
    final ok = await widget.votes.castVote(widget.entry.id, choice);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Vote didn't save. Check connection."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
            label: 'Retry', onPressed: () => _handleVote(choice)),
      ));
      return;
    }
    final withdrew = wasMine == choice;
    if (!withdrew && (choice == 'no' || choice == 'undecided')) {
      // Non-blocking: the ballot is already recorded; the sheet only offers
      // the optional why.
      showVoteReasonSheet(context,
          entry: widget.entry, vote: choice, votes: widget.votes);
    }
  }

  Future<void> _confirm() async {
    final s = widget.suggestion == 'yes'
        ? DecisionState.endorse
        : DecisionState.decline;
    setState(() => _confirming = true);
    final ok = await widget.repository.trySetState(widget.entry.id, s);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Confirm didn't save. Nothing was recorded."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Retry', onPressed: _confirm),
      ));
    }
    // On success realtime moves this card to the locked baseline everywhere.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.entry;
    final votes = widget.votes;
    final tally = votes.tallyFor(entry.id);
    final myBallot = votes.myBallot(entry.id);
    final mine = myBallot?.vote;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Identity row.
          Row(
            children: [
              HeadshotAvatar(file: entry.headshot, name: entry.name, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (entry.officeLine.isNotEmpty)
                      Text(entry.officeLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (entry.alignmentPct != null) ...[
                const SizedBox(width: 6),
                AlignmentBadge(pct: entry.alignmentPct!, dense: true),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // The 3-way vote control.
          Row(
            children: [
              Expanded(
                child: _VoteButton(
                  label: 'Yes',
                  icon: Icons.check_circle,
                  fg: MoydBrand.supportFg,
                  bg: MoydBrand.supportBg,
                  selected: mine == 'yes',
                  onTap: () => _handleVote('yes'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoteButton(
                  label: 'No',
                  icon: Icons.cancel,
                  fg: MoydBrand.opposeFg,
                  bg: MoydBrand.opposeBg,
                  selected: mine == 'no',
                  onTap: () => _handleVote('no'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoteButton(
                  label: 'Undecided',
                  icon: Icons.help_outline,
                  fg: MoydBrand.neutralFg,
                  bg: MoydBrand.neutralBg,
                  selected: mine == 'undecided',
                  onTap: () => _handleVote('undecided'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TallyBar(tally: tally),
          const SizedBox(height: 4),
          Text('${tally.cast} of ${votes.roomSize} execs in',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _VoterRoster(votes: votes, candidateId: entry.id),
          if (myBallot != null && myBallot.hasReason) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Reason: ${_myReasonText(myBallot)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          if (widget.isChair && widget.bucket == VoteBucket.split)
            _splitDetail(context),
          if (widget.bucket == VoteBucket.consensusReady)
            _consensusBanner(context, tally),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.isChair)
                TextButton.icon(
                  onPressed: widget.onFinalCall,
                  icon:
                      Icon(Icons.gavel, size: 16, color: cs.onSurfaceVariant),
                  label: Text('Final call',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onOpen,
                icon: Icon(Icons.open_in_new,
                    size: 16, color: cs.onSurfaceVariant),
                label: Text('Full review',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _myReasonText(BallotEntry ballot) {
    if (ballot.reasonCodes.contains('other') &&
        (ballot.otherText?.isNotEmpty ?? false)) {
      return ballot.otherText!;
    }
    return ballot.reasonCodes.map(voteReasonLabel).join(', ');
  }

  /// Chair-only rollup on split cards: the reasons behind the No/Undecided
  /// ballots plus who the room is still waiting on — what gets read aloud.
  Widget _splitDetail(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ballots = widget.votes.ballotsFor(widget.entry.id);
    final noReasons = <String, int>{};
    final undecidedReasons = <String, int>{};
    var noOther = 0;
    var undecidedOther = 0;
    for (final b in ballots.values) {
      final target = b.vote == 'no'
          ? noReasons
          : (b.vote == 'undecided' ? undecidedReasons : null);
      if (target == null) continue;
      for (final code in b.reasonCodes) {
        if (code == 'other') {
          if (b.vote == 'no') {
            noOther++;
          } else {
            undecidedOther++;
          }
          continue;
        }
        target[code] = (target[code] ?? 0) + 1;
      }
    }
    String rollup(Map<String, int> m, int others) {
      final parts = [
        for (final e in m.entries) '${e.value}× ${voteReasonLabel(e.key)}',
        if (others > 0) '$others× Other',
      ];
      return parts.join(', ');
    }

    final waiting = [
      for (final entry in widget.votes.knownVoters.entries)
        if (!ballots.containsKey(entry.key)) entry.value,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final noLine = rollup(noReasons, noOther);
    final undecidedLine = rollup(undecidedReasons, undecidedOther);
    final noCount = ballots.values.where((b) => b.vote == 'no').length;
    final undecidedCount =
        ballots.values.where((b) => b.vote == 'undecided').length;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Split — discussion notes',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            if (noCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                noLine.isEmpty
                    ? 'No ($noCount): no reasons given'
                    : 'No ($noCount): $noLine',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurface),
              ),
            ],
            if (undecidedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                undecidedLine.isEmpty
                    ? 'Undecided ($undecidedCount): no reasons given'
                    : 'Undecided ($undecidedCount): $undecidedLine',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurface),
              ),
            ],
            if (waiting.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Waiting on: ${waiting.join(', ')}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  /// Full-width consensus strip. Everyone sees the suggestion; only the chair
  /// gets the Confirm button, and Confirm uses the CHECKED write path — on a
  /// failed write the card stays on the ballot on every device.
  Widget _consensusBanner(BuildContext context, VoteTally tally) {
    final endorse = widget.suggestion == 'yes';
    final fg = endorse ? MoydBrand.supportFg : MoydBrand.opposeFg;
    final bg = endorse ? MoydBrand.supportBg : MoydBrand.opposeBg;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(endorse ? Icons.verified : Icons.block, size: 16, color: fg),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Consensus: ',
                  children: [
                    TextSpan(
                        text: endorse ? 'Endorse' : 'Decline',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: ' (${tally.yes} Yes · ${tally.no} No · '
                            '${tally.undecided} Undecided)'),
                  ],
                ),
                style: TextStyle(
                    color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.isChair) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _confirming ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: HubTheme.navy,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _confirming
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One big vote button. Selected = solid accent fill with white text + icon
/// (all three accents carry white at >= 4.5:1, the slate is ~7:1); unselected
/// = self-contained light bg + dark fg so it reads in both themes. Icon +
/// label together so the choice never relies on color alone.
class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Your vote: $label. Tap to withdraw.' : 'Vote $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44),
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? fg : bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? fg : fg.withOpacity(0.45),
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? Colors.white : fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected ? Colors.white : fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live tally: "5 Yes · 2 No · 1 Undecided · 8 open" with a
/// green/red/slate proportion bar. The bar is decorative reinforcement; the
/// counts are always spelled out beside it.
class _TallyBar extends StatelessWidget {
  final VoteTally tally;
  const _TallyBar({required this.tally});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = StringBuffer(
        '${tally.yes} Yes · ${tally.no} No · ${tally.undecided} Undecided');
    if (tally.pending > 0) {
      label.write(' · ${tally.pending} open');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tally.hasVotes ? label.toString() : 'No ballots yet',
          style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: tally.hasVotes ? cs.onSurface : cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (tally.yes > 0) ...[
                  Expanded(
                    flex: tally.yes,
                    child: const ColoredBox(color: MoydBrand.supportFg),
                  ),
                ],
                if (tally.yes > 0 && (tally.no > 0 || tally.undecided > 0))
                  const SizedBox(width: 2),
                if (tally.no > 0)
                  Expanded(
                    flex: tally.no,
                    child: const ColoredBox(color: MoydBrand.opposeFg),
                  ),
                if (tally.no > 0 && tally.undecided > 0)
                  const SizedBox(width: 2),
                if (tally.undecided > 0)
                  Expanded(
                    flex: tally.undecided,
                    child: const ColoredBox(color: MoydBrand.neutralFg),
                  ),
                if (!tally.hasVotes)
                  Expanded(
                    child: ColoredBox(
                        color: cs.surfaceContainerHighest.withOpacity(0.8)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact roster of who voted what: one pill per known committee voter with
/// a check (yes) / x (no) / question mark (undecided) / hourglass (not yet)
/// marker plus their name, so the ballot never reads by color alone.
class _VoterRoster extends StatelessWidget {
  final EndorsementVoteRepository votes;
  final String candidateId;
  const _VoterRoster({required this.votes, required this.candidateId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ballots = votes.votesFor(candidateId);
    final known = votes.knownVoters;
    if (known.isEmpty) {
      return Text('Ballots will list every exec by name.',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.onSurfaceVariant));
    }

    // Yes, then no, then undecided, then whoever has not voted yet; "You"
    // leads each group so members can always find themselves at a glance.
    final me = votes.currentUserId;
    final ids = known.keys.toList()
      ..sort((a, b) {
        int rank(String uid) => switch (ballots[uid]?.vote) {
              'yes' => 0,
              'no' => 1,
              'undecided' => 2,
              _ => 3,
            };
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        if (a == me) return -1;
        if (b == me) return 1;
        return (known[a] ?? '').toLowerCase().compareTo(
            (known[b] ?? '').toLowerCase());
      });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final uid in ids)
          _voterPill(
            context,
            name: uid == me ? 'You' : (known[uid] ?? 'An exec'),
            vote: ballots[uid]?.vote,
          ),
      ],
    );
  }

  Widget _voterPill(BuildContext context, {required String name, String? vote}) {
    late final Color fg;
    late final Color bg;
    late final IconData icon;
    switch (vote) {
      case 'yes':
        fg = MoydBrand.supportFg;
        bg = MoydBrand.supportBg;
        icon = Icons.check_circle;
      case 'no':
        fg = MoydBrand.opposeFg;
        bg = MoydBrand.opposeBg;
        icon = Icons.cancel;
      case 'undecided':
        fg = MoydBrand.neutralFg;
        bg = MoydBrand.neutralBg;
        icon = Icons.help_outline;
      default:
        fg = MoydBrand.neutralFg;
        bg = MoydBrand.neutralBg;
        icon = Icons.hourglass_empty;
    }
    return Tooltip(
      message: switch (vote) {
        'yes' => '$name voted Yes',
        'no' => '$name voted No',
        'undecided' => '$name voted Undecided',
        _ => '$name has not voted yet',
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(name,
                style: TextStyle(
                    color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ==================== final-call panel ====================

/// The chair's final-outcome panel: where the committee formally lands
/// (endorse / decline / undecided) plus the shared working note. Reachable
/// only from the chair-gated footer button; every state write goes through
/// the CHECKED path so a flaky network can never fake a recorded decision.
class _DecisionPanel extends StatefulWidget {
  final CandidateEntry entry;
  final DecisionRepository repository;
  final EndorsementVoteRepository votes;
  final DecisionActivity activity;
  final VoidCallback onOpen;
  const _DecisionPanel({
    required this.entry,
    required this.repository,
    required this.votes,
    required this.activity,
    required this.onOpen,
  });

  @override
  State<_DecisionPanel> createState() => _DecisionPanelState();
}

class _DecisionPanelState extends State<_DecisionPanel> {
  late final TextEditingController _note = TextEditingController(
      text: widget.repository.recordFor(widget.entry.id).note);
  Timer? _noteDebounce;
  bool _noteDirty = false;

  // Debounce note saves so the shared table (and every exec's realtime feed)
  // gets one upsert per pause instead of one per keystroke.
  void _queueNoteSave(String _) {
    _noteDirty = true;
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 600), _flushNote);
  }

  void _flushNote() {
    _noteDebounce?.cancel();
    if (!_noteDirty) return;
    _noteDirty = false;
    widget.repository.setNote(widget.entry.id, _note.text);
  }

  Future<void> _setState(DecisionState s) async {
    final ok = await widget.repository.trySetState(widget.entry.id, s);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Final call didn't save. Nothing was recorded."),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Retry', onPressed: () => _setState(s)),
      ));
    }
  }

  @override
  void dispose() {
    _flushNote();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = widget.entry;
    // Scrollable so the panel still fits a phone screen with the keyboard
    // open (the working-note field sits low in the sheet).
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [widget.repository, widget.votes, widget.activity]),
        builder: (context, _) {
          final current = widget.repository.stateFor(e.id);
          final who = widget.activity.describe(e.id);
          final tally = widget.votes.tallyFor(e.id);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HeadshotAvatar(
                      file: e.headshot, name: e.name, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (e.officeLine.isNotEmpty)
                          Text(e.officeLine,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (e.alignmentPct != null)
                    AlignmentBadge(pct: e.alignmentPct!, showWord: true),
                ],
              ),
              const SizedBox(height: 14),
              _TallyBar(tally: tally),
              const SizedBox(height: 18),
              Text('Final call (after the vote)',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in DecisionState.values)
                    _StatePill(
                      state: s,
                      selected: current == s,
                      onTap: () => _setState(s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      who == null
                          ? DecisionVisuals.hint(current)
                          : '$who — ${DecisionVisuals.hint(current)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Working note (shared)',
                  hintText: 'Committee notes, follow-ups…',
                  helperText: 'Autosaves and syncs live to every exec.',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: _queueNoteSave,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpen,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open full review'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      _flushNote();
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: HubTheme.navy,
                        foregroundColor: Colors.white),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One selectable final-call pill: solid accent + white text when selected
/// (all accents carry white at >= 4.5:1), self-contained light bg + dark fg
/// otherwise, so the control is legible in both themes.
class _StatePill extends StatelessWidget {
  final DecisionState state;
  final bool selected;
  final VoidCallback onTap;
  const _StatePill({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = DecisionVisuals.fg(state);
    final accent = DecisionVisuals.accent(state);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : DecisionVisuals.bg(state),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : fg.withOpacity(0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(DecisionVisuals.icon(state),
                size: 16, color: selected ? Colors.white : fg),
            const SizedBox(width: 6),
            Text(state.label,
                style: TextStyle(
                    color: selected ? Colors.white : fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
