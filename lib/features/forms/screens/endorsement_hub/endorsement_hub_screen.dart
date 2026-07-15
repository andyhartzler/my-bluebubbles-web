import 'package:flutter/material.dart';

import '../../models/form_submission.dart';
import '../../theme/moyd_brand.dart';
import '../../widgets/review/compare_matrix.dart';
import '../../widgets/review/policy_stance_bars.dart';
import '../submission_detail_screen.dart';
import 'models/candidate_entry.dart';
import 'slate_controller.dart';
import 'widgets/analytics/alignment_histogram.dart';
import 'widgets/analytics/battleground_card.dart';
import 'widgets/analytics/slate_scoreboard.dart';
import 'widgets/compare/compare_tray.dart';
import 'widgets/compare/side_by_side_compare.dart';
import 'widgets/decisions/decision_board.dart';
import 'widgets/decisions/decision_chip.dart';
import 'widgets/decisions/decision_repository.dart';
import 'widgets/roster/roster_gallery.dart';

/// "Endorsement HQ 2026" — the candidate survey intelligence hub. A navy banner
/// with live KPIs sits over four tabs: Roster, Compare, Analytics, Decisions.
class EndorsementHubScreen extends StatefulWidget {
  const EndorsementHubScreen({super.key});

  @override
  State<EndorsementHubScreen> createState() => _EndorsementHubScreenState();
}

enum _CompareMode { matrix, sideBySide }

class _EndorsementHubScreenState extends State<EndorsementHubScreen>
    with SingleTickerProviderStateMixin {
  final SlateController _controller = SlateController();
  // Shared across all executive members via public.endorsement_decisions (live
  // sync), so the committee sees one decision board instead of per-device copies.
  final DecisionRepository _decisions = SupabaseDecisionRepository();
  late final TabController _tabs = TabController(length: 4, vsync: this);

  _CompareMode _compareMode = _CompareMode.matrix;

  @override
  void initState() {
    super.initState();
    _controller.load();
    _decisions.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openCandidate(CandidateEntry e) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SubmissionDetailScreen(
        submission: e.submission,
        form: _controller.form,
      ),
    ));
  }

  void _openBySubmission(FormSubmission s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SubmissionDetailScreen(
        submission: s,
        form: _controller.form,
      ),
    ));
  }

  void _startCompare() {
    setState(() => _compareMode = _CompareMode.sideBySide);
    _tabs.animateTo(1);
  }

  void _focusRange(double lo, double hi) {
    _controller.focusAlignmentRange(lo, hi);
    _tabs.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _banner(context),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_controller.error != null) {
                  return _errorState(context);
                }
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _padded(RosterGallery(
                      controller: _controller,
                      onOpen: _openCandidate,
                      decisionChipBuilder: _decisionChip,
                    )),
                    _padded(_compareTab(context)),
                    _padded(_analyticsTab(context)),
                    _padded(DecisionBoard(
                      controller: _controller,
                      repository: _decisions,
                      onOpen: _openCandidate,
                    )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CompareTray(
        controller: _controller,
        onCompare: _startCompare,
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: child,
      );

  Widget _decisionChip(CandidateEntry e) {
    return AnimatedBuilder(
      animation: _decisions,
      builder: (context, _) =>
          DecisionChip(state: _decisions.stateFor(e.id), compact: true),
    );
  }

  // ---------------- banner ----------------

  Widget _banner(BuildContext context) {
    return Material(
      color: MoydBrand.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 96,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium,
                        color: MoydBrand.gold, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Endorsement HQ 2026',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Candidate survey intelligence',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12.5)),
                        ],
                      ),
                    ),
                    _bannerKpis(),
                  ],
                ),
              ),
            ),
            _tabBar(),
          ],
        ),
      ),
    );
  }

  Widget _bannerKpis() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.loading || _controller.error != null) {
          return const SizedBox.shrink();
        }
        final s = _controller.stats;
        final mean = s.meanAlignment;
        final kpis = <(String, String)>[
          ('${s.total}', 'Applicants'),
          (mean == null ? '—' : '${mean.round()}%', 'Mean align'),
          ('${s.youngDemCount}', 'Young Dems'),
          ('${s.unscoredCount}', 'Unscored'),
        ];
        return LayoutBuilder(builder: (context, _) {
          final narrow = MediaQuery.of(context).size.width < 640;
          if (narrow) {
            // Only the headline number on small screens.
            return _kpi(kpis.first.$1, kpis.first.$2);
          }
          return Row(
            children: [
              for (final k in kpis) ...[
                _kpi(k.$1, k.$2),
                const SizedBox(width: 22),
              ],
            ],
          );
        });
      },
    );
  }

  Widget _kpi(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.0)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: MoydBrand.gold.withOpacity(0.95),
                fontSize: 10.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _tabBar() {
    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: MoydBrand.gold,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      tabs: const [
        Tab(text: 'Roster'),
        Tab(text: 'Compare'),
        Tab(text: 'Analytics'),
        Tab(text: 'Decisions'),
      ],
    );
  }

  // ---------------- compare tab ----------------

  Widget _compareTab(BuildContext context) {
    final theme = Theme.of(context);
    if (!_controller.hasSubmissions) {
      return _emptyTab(theme, Icons.compare_arrows, 'Nothing to compare yet',
          'Candidate submissions will appear here for side-by-side review.');
    }
    final submissions =
        _controller.all.map((e) => e.submission).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_CompareMode>(
          segments: const [
            ButtonSegment(
                value: _CompareMode.matrix,
                icon: Icon(Icons.grid_on),
                label: Text('Matrix')),
            ButtonSegment(
                value: _CompareMode.sideBySide,
                icon: Icon(Icons.view_column),
                label: Text('Side-by-side')),
          ],
          selected: {_compareMode},
          onSelectionChanged: (s) =>
              setState(() => _compareMode = s.first),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _compareMode == _CompareMode.matrix
              ? CompareMatrix(
                  form: _controller.form!,
                  submissions: submissions,
                  onOpenCandidate: _openBySubmission,
                )
              : SideBySideCompare(
                  entries: _controller.selectedEntries,
                  onOpen: _openCandidate,
                ),
        ),
      ],
    );
  }

  // ---------------- analytics tab ----------------

  Widget _analyticsTab(BuildContext context) {
    final theme = Theme.of(context);
    if (!_controller.hasSubmissions) {
      return _emptyTab(theme, Icons.insights, 'No analytics yet',
          'Distributions, battleground questions and the slate scoreboard populate as submissions arrive.');
    }
    final submissions =
        _controller.all.map((e) => e.submission).toList(growable: false);
    final stats = _controller.stats;

    final histogram = AlignmentHistogram(
      stats: stats,
      onSelectRange: _focusRange,
      onOpen: _openCandidate,
    );
    final battleground =
        BattlegroundCard(stats: stats, onOpen: _openCandidate);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SlateScoreboard(stats: stats),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: histogram),
                  const SizedBox(width: 16),
                  Expanded(child: battleground),
                ],
              ),
            );
          }
          return Column(
            children: [
              histogram,
              const SizedBox(height: 16),
              battleground,
            ],
          );
        }),
        const SizedBox(height: 16),
        PolicyStanceBars(form: _controller.form!, submissions: submissions),
      ],
    );
  }

  // ---------------- shared ----------------

  Widget _emptyTab(
      ThemeData theme, IconData icon, String title, String message) {
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Could not load the endorsement slate',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(_controller.error ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: MoydBrand.navy),
            ),
          ],
        ),
      ),
    );
  }
}
