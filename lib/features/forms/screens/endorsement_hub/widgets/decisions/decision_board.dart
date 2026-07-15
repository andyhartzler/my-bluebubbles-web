import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// The committee VOTING board: every exec casts a simple Yes or No on each
/// candidate, everyone sees everyone's ballots live, and each card shows the
/// running tally. A branded summary header (majority-yes count, my ballot
/// progress, live-sync indicator) sits over a responsive grid of vote cards.
///
/// Voting is the primary mechanism here. A lightweight shared "final call"
/// (endorse / decline, plus the shared working note) is still available from
/// each card for recording where the committee formally lands; it syncs live
/// via the same shared repository as before.
class DecisionBoard extends StatefulWidget {
  final SlateController controller;
  final DecisionRepository repository;
  final EndorsementVoteRepository votes;
  final void Function(CandidateEntry) onOpen;

  const DecisionBoard({
    super.key,
    required this.controller,
    required this.repository,
    required this.votes,
    required this.onOpen,
  });

  @override
  State<DecisionBoard> createState() => _DecisionBoardState();
}

enum _VoteFilter { all, needsMyVote }

enum _VoteSort { yesShare, name, alignment }

class _DecisionBoardState extends State<DecisionBoard> {
  late final DecisionActivity _activity = DecisionActivity(widget.repository);
  Timer? _clock;

  _VoteFilter _filter = _VoteFilter.all;
  _VoteSort _sort = _VoteSort.yesShare;

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

  List<CandidateEntry> _visibleEntries() {
    var entries = widget.controller.all.toList();
    if (_filter == _VoteFilter.needsMyVote) {
      entries =
          entries.where((e) => widget.votes.myVote(e.id) == null).toList();
    }
    int byName(CandidateEntry a, CandidateEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
        final all = widget.controller.all;
        final visible = _visibleEntries();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VoteHeader(
              entries: all,
              votes: widget.votes,
              onCopy: () => _copySummary(context, all),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap Yes or No on each candidate to cast your vote. Tap your '
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
                needsMyVoteCount:
                    all.where((e) => widget.votes.myVote(e.id) == null).length,
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
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'You have voted on every candidate. Nice work.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  : LayoutBuilder(builder: (context, constraints) {
                      final twoUp = constraints.maxWidth >= 1000;
                      if (!twoUp) {
                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _voteCard(visible[i]),
                        );
                      }
                      // 2-up masonry-ish grid: two independent columns so
                      // cards keep their natural height.
                      final left = <CandidateEntry>[];
                      final right = <CandidateEntry>[];
                      for (var i = 0; i < visible.length; i++) {
                        (i.isEven ? left : right).add(visible[i]);
                      }
                      Widget column(List<CandidateEntry> list) => Column(
                            children: [
                              for (final e in list) ...[
                                _voteCard(e),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: column(left)),
                            const SizedBox(width: 12),
                            Expanded(child: column(right)),
                          ],
                        ),
                      );
                    }),
            ),
          ],
        );
      },
    );
  }

  Widget _voteCard(CandidateEntry e) {
    return _VoteCard(
      entry: e,
      votes: widget.votes,
      repository: widget.repository,
      onOpen: () => widget.onOpen(e),
      onFinalCall: () => _openPanel(context, e),
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

  void _copySummary(BuildContext context, List<CandidateEntry> entries) {
    final buf = StringBuffer();
    buf.writeln('# Endorsement committee vote');
    buf.writeln();
    buf.writeln('| Candidate | Office | Yes | No | Final call |');
    buf.writeln('| --- | --- | --- | --- | --- |');
    final sorted = entries.toList()
      ..sort((a, b) {
        final ta = widget.votes.tallyFor(a.id);
        final tb = widget.votes.tallyFor(b.id);
        return (tb.yesShare ?? -1).compareTo(ta.yesShare ?? -1);
      });
    for (final e in sorted) {
      final t = widget.votes.tallyFor(e.id);
      final call = widget.repository.stateFor(e.id);
      buf.writeln('| ${e.name} '
          '| ${e.officeLine.isEmpty ? '—' : e.officeLine} '
          '| ${t.yes} | ${t.no} | ${call.label} |');
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
      message: 'Once submissions arrive, every exec casts a simple Yes or No '
          'on each candidate. Ballots sync live to the whole committee.',
    );
  }
}

// ==================== summary header ====================

/// Branded gradient scoreboard for the vote: majority-yes / majority-no /
/// awaiting-votes tiles, the signed-in member's ballot progress and a pulsing
/// LIVE indicator. Dark navy gradient with white/gold text so it reads
/// identically in both themes.
class _VoteHeader extends StatelessWidget {
  final List<CandidateEntry> entries;
  final EndorsementVoteRepository votes;
  final VoidCallback onCopy;

  const _VoteHeader({
    required this.entries,
    required this.votes,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    var majorityYes = 0;
    var majorityNo = 0;
    var noBallots = 0;
    var mine = 0;
    for (final e in entries) {
      final t = votes.tallyFor(e.id);
      if (!t.hasVotes) {
        noBallots++;
      } else if (t.yes > t.no) {
        majorityYes++;
      } else if (t.no > t.yes) {
        majorityNo++;
      }
      if (votes.myVote(e.id) != null) mine++;
    }
    final total = entries.length;
    final voterCount = votes.knownVoters.length;

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
            voterCount <= 1
                ? 'One Yes or No per exec, per candidate · everyone sees every ballot live'
                : '$voterCount execs voting · everyone sees every ballot live',
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
                icon: Icons.thumb_up,
                iconBg: MoydBrand.supportFg,
                count: majorityYes,
                label: 'MAJORITY YES',
              ),
              _SummaryTile(
                icon: Icons.thumb_down,
                iconBg: MoydBrand.opposeFg,
                count: majorityNo,
                label: 'MAJORITY NO',
              ),
              _SummaryTile(
                icon: Icons.hourglass_empty,
                iconBg: MoydBrand.neutralFg,
                count: noBallots,
                label: 'NO BALLOTS YET',
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
              Text('You voted on $mine of $total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
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

/// "All candidates" vs "Needs my vote" segmented pill, matching the hub's
/// segmented-switch treatment (navy gradient on the active segment).
class _FilterSwitch extends StatelessWidget {
  final _VoteFilter filter;
  final int needsMyVoteCount;
  final ValueChanged<_VoteFilter> onChanged;

  /// Compact (phone) mode: shorter segment labels so the switch fits a
  /// ~360px viewport beside the sort menu.
  final bool compact;

  const _FilterSwitch({
    required this.filter,
    required this.needsMyVoteCount,
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

// ==================== vote card ====================

/// One candidate's ballot card: identity row, the big Yes / No control (the
/// signed-in member's choice fills solid), the live tally bar and the roster
/// of who voted what.
class _VoteCard extends StatelessWidget {
  final CandidateEntry entry;
  final EndorsementVoteRepository votes;
  final DecisionRepository repository;
  final VoidCallback onOpen;
  final VoidCallback onFinalCall;

  const _VoteCard({
    required this.entry,
    required this.votes,
    required this.repository,
    required this.onOpen,
    required this.onFinalCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tally = votes.tallyFor(entry.id);
    final mine = votes.myVote(entry.id);
    final call = repository.stateFor(entry.id);

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
              HeadshotAvatar(
                  file: entry.model.headshot, name: entry.name, size: 44),
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
              if (call != DecisionState.undecided) ...[
                const SizedBox(width: 6),
                DecisionChip(state: call, compact: true),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // The vote control: dead-simple Yes / No.
          Row(
            children: [
              Expanded(
                child: _VoteButton(
                  label: 'Yes',
                  icon: Icons.check_circle,
                  fg: MoydBrand.supportFg,
                  bg: MoydBrand.supportBg,
                  selected: mine == 'yes',
                  onTap: () => votes.castVote(entry.id, 'yes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VoteButton(
                  label: 'No',
                  icon: Icons.cancel,
                  fg: MoydBrand.opposeFg,
                  bg: MoydBrand.opposeBg,
                  selected: mine == 'no',
                  onTap: () => votes.castVote(entry.id, 'no'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TallyBar(tally: tally),
          const SizedBox(height: 10),
          _VoterRoster(votes: votes, candidateId: entry.id),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onFinalCall,
                icon: Icon(Icons.gavel, size: 16, color: cs.onSurfaceVariant),
                label: Text('Final call',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpen,
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
}

/// One big vote button. Selected = solid accent fill with white text + icon
/// (both accents carry white at >= 4.5:1); unselected = self-contained light
/// bg + dark fg so it reads in both themes. Icon + label together so the
/// choice never relies on color alone.
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              Icon(icon, size: 19, color: selected ? Colors.white : fg),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              if (selected) ...[
                const SizedBox(width: 7),
                const Icon(Icons.how_to_vote, size: 15, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The live tally: "6 Yes · 2 No" with a green/red proportion bar. The bar is
/// decorative reinforcement; the counts are always spelled out beside it.
class _TallyBar extends StatelessWidget {
  final VoteTally tally;
  const _TallyBar({required this.tally});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = StringBuffer('${tally.yes} Yes · ${tally.no} No');
    if (tally.pending > 0) {
      label.write(' · ${tally.pending} waiting');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tally.hasVotes ? label.toString() : 'No ballots yet',
                style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tally.hasVotes ? cs.onSurface : cs.onSurfaceVariant),
              ),
            ),
            if (tally.hasVotes)
              Text(
                tally.majorityYes
                    ? 'Majority yes'
                    : (tally.no > tally.yes ? 'Majority no' : 'Tied'),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tally.majorityYes
                      ? MoydBrand.supportFg
                      : (tally.no > tally.yes
                          ? MoydBrand.opposeFg
                          : cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (tally.yes > 0)
                  Expanded(
                    flex: tally.yes,
                    child: const ColoredBox(color: MoydBrand.supportFg),
                  ),
                if (tally.yes > 0 && tally.no > 0) const SizedBox(width: 2),
                if (tally.no > 0)
                  Expanded(
                    flex: tally.no,
                    child: const ColoredBox(color: MoydBrand.opposeFg),
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
/// a check (yes) / x (no) / hourglass (not yet) marker plus their name, so
/// the ballot never reads by color alone.
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

    // Yes first, then no, then whoever has not voted yet; "You" leads each
    // group so members can always find themselves at a glance.
    final me = votes.currentUserId;
    final ids = known.keys.toList()
      ..sort((a, b) {
        int rank(String uid) {
          final v = ballots[uid]?.vote;
          if (v == 'yes') return 0;
          if (v == 'no') return 1;
          return 2;
        }

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
      default:
        fg = MoydBrand.neutralFg;
        bg = MoydBrand.neutralBg;
        icon = Icons.hourglass_empty;
    }
    return Tooltip(
      message: switch (vote) {
        'yes' => '$name voted Yes',
        'no' => '$name voted No',
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

/// The lightweight shared final-outcome panel: where the committee formally
/// lands after the vote (endorse / decline / undecided) plus the shared
/// working note. Kept secondary to the Yes/No voting on the cards.
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
                      file: e.model.headshot, name: e.name, size: 50),
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
                      onTap: () => widget.repository.setState(e.id, s),
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
