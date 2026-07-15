import 'package:flutter/material.dart';

import '../../models/form_submission.dart';
import '../../widgets/review/compare_matrix.dart';
import '../../widgets/review/policy_stance_bars.dart';
import '../submission_detail_screen.dart';
import 'models/candidate_entry.dart';
import 'slate_controller.dart';
import 'theme/hub_theme.dart';
import 'widgets/analytics/alignment_histogram.dart';
import 'widgets/analytics/battleground_card.dart';
import 'widgets/analytics/question_breakdown.dart';
import 'widgets/analytics/slate_scoreboard.dart';
import 'widgets/compare/compare_tray.dart';
import 'widgets/compare/side_by_side_compare.dart';
import 'journey/journey_tab.dart';
import 'journey/live_journey_controller.dart';
import 'widgets/decisions/decision_board.dart';
import 'widgets/decisions/decision_chip.dart';
import 'widgets/decisions/decision_repository.dart';
import 'widgets/decisions/endorsement_vote_repository.dart';
import 'widgets/roster/roster_gallery.dart';

/// "Endorsement HQ 2026" — the candidate survey intelligence hub. A gradient
/// hero banner with live KPIs sits over four tabs: Roster, Compare, Analytics,
/// Decisions.
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
  // Per-member yes/no ballots, shared live via public.endorsement_votes.
  final EndorsementVoteRepository _votes = EndorsementVoteRepository();
  // Live candidate-journey feed (in-flight submissions + realtime updates).
  final LiveJourneyController _journey = LiveJourneyController(
    formId: SlateController.endorsementFormId,
    slug: SlateController.endorsementSlug,
  );
  late final TabController _tabs = TabController(length: 5, vsync: this);

  _CompareMode _compareMode = _CompareMode.matrix;

  @override
  void initState() {
    super.initState();
    _controller.load();
    _decisions.load();
    _votes.load();
    _journey.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _controller.dispose();
    _votes.dispose();
    _journey.dispose();
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
    _tabs.animateTo(2);
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
                  return _loadingState(context);
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
                    _padded(JourneyTab(
                      controller: _journey,
                      onOpenSubmission: _openBySubmission,
                    )),
                    _padded(_compareTab(context)),
                    _padded(_analyticsTab(context)),
                    _padded(DecisionBoard(
                      controller: _controller,
                      repository: _decisions,
                      votes: _votes,
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
    // Below ~680px the KPI cluster leaves the title row and becomes a
    // full-width, horizontally scrollable strip so all four KPIs stay
    // visible on a phone without squeezing the title.
    final narrow = MediaQuery.of(context).size.width < 680;
    return Container(
      decoration: const BoxDecoration(gradient: HubTheme.hero),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  narrow ? 16 : 20, 14, narrow ? 16 : 20, narrow ? 6 : 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: HubTheme.gold.withOpacity(0.55), width: 1.4),
                    ),
                    child: const Icon(Icons.workspace_premium,
                        color: HubTheme.gold, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Endorsement HQ 2026',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: narrow ? 19 : 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 3,
                              decoration: BoxDecoration(
                                color: HubTheme.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text('Candidate survey intelligence',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Color(0xE6FFFFFF), fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!narrow) _bannerKpis(),
                ],
              ),
            ),
            if (narrow) _mobileKpiStrip(),
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
        final kpis = _kpiData();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white.withOpacity(0.18),
                  ),
                _kpi(kpis[i].$1, kpis[i].$2),
              ],
            ],
          ),
        );
      },
    );
  }

  List<(String, String)> _kpiData() {
    final s = _controller.stats;
    final mean = s.meanAlignment;
    return <(String, String)>[
      ('${s.total}', 'Applicants'),
      (mean == null ? '—' : '${mean.round()}%', 'Mean align'),
      ('${s.youngDemCount}', 'Young Dems'),
      ('${s.unscoredCount}', 'Unscored'),
    ];
  }

  /// Phone-width KPI strip: all four KPIs in a contained horizontal scroll
  /// (the strip scrolls inside itself; the page never scrolls sideways).
  Widget _mobileKpiStrip() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.loading || _controller.error != null) {
          return const SizedBox.shrink();
        }
        final kpis = _kpiData();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  for (var i = 0; i < kpis.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: Colors.white.withOpacity(0.18),
                      ),
                    _kpi(kpis[i].$1, kpis[i].$2),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _kpi(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.0)),
        const SizedBox(height: 3),
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: HubTheme.goldBright,
                fontSize: 9.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _tabBar() {
    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: HubTheme.gold,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: Colors.white,
      unselectedLabelColor: const Color(0xCCFFFFFF),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      tabs: [
        const Tab(icon: Icon(Icons.groups_2_outlined, size: 19), text: 'Roster'),
        Tab(icon: const Icon(Icons.sensors, size: 19), child: _liveTabLabel()),
        const Tab(icon: Icon(Icons.compare_arrows, size: 19), text: 'Compare'),
        const Tab(icon: Icon(Icons.insights_outlined, size: 19), text: 'Analytics'),
        const Tab(
            icon: Icon(Icons.how_to_vote_outlined, size: 19),
            text: 'Decisions'),
      ],
    );
  }

  /// "Live" tab label with a green count badge whenever someone is actively
  /// filling the questionnaire right now.
  Widget _liveTabLabel() {
    return AnimatedBuilder(
      animation: _journey,
      builder: (context, _) {
        final n = _journey.liveCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Live'),
            if (n > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$n',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        );
      },
    );
  }

  // ---------------- compare tab ----------------

  Widget _compareTab(BuildContext context) {
    if (!_controller.hasSubmissions) {
      return const HubEmptyState(
        icon: Icons.compare_arrows,
        title: 'Nothing to compare yet',
        message:
            'Candidate submissions will appear here for side-by-side review '
            'the moment the first questionnaire lands.',
      );
    }
    final submissions =
        _controller.all.map((e) => e.submission).toList(growable: false);
    final modeSwitch = _CompareModeSwitch(
      mode: _compareMode,
      onChanged: (m) => setState(() => _compareMode = m),
    );
    final countPill = _compareMode == _CompareMode.sideBySide
        ? HubCountPill(
            icon: Icons.person_outline,
            text: '${_controller.selectedCount} selected',
          )
        : HubCountPill(
            icon: Icons.grid_on,
            text: '${submissions.length} candidates',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone widths: the mode switch and count pill wrap onto separate
        // lines instead of overflowing a single fixed row.
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [modeSwitch, countPill],
            );
          }
          return Row(children: [modeSwitch, const Spacer(), countPill]);
        }),
        const SizedBox(height: 12),
        Expanded(
          child: _compareMode == _CompareMode.matrix
              ? CompareMatrix(
                  form: _controller.form!,
                  submissions: submissions,
                  onOpenCandidate: _openBySubmission,
                )
              : SideBySideCompare(
                  selected: _controller.selectedEntries,
                  all: _controller.all,
                  onToggleSelect: _controller.toggleSelected,
                  onOpen: _openCandidate,
                ),
        ),
      ],
    );
  }

  // ---------------- analytics tab ----------------

  Widget _analyticsTab(BuildContext context) {
    if (!_controller.hasSubmissions) {
      return const HubEmptyState(
        icon: Icons.insights,
        title: 'No analytics yet',
        message:
            'Distributions, battleground questions and the slate scoreboard '
            'populate as submissions arrive.',
      );
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
        // Per-question response analytics, including the "No answer" count
        // (and drill-down to exactly who skipped each question).
        QuestionBreakdown(
          form: _controller.form!,
          entries: _controller.all,
          onOpen: _openCandidate,
        ),
        const SizedBox(height: 16),
        PolicyStanceBars(form: _controller.form!, submissions: submissions),
      ],
    );
  }

  // ---------------- loading / error ----------------

  Widget _loadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: HubTheme.hero,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: HubTheme.royal.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading the slate…',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    return HubEmptyState(
      icon: Icons.error_outline,
      title: 'Could not load the endorsement slate',
      message: _controller.error ?? 'Something went wrong.',
      action: FilledButton.icon(
        onPressed: _controller.load,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
        style: FilledButton.styleFrom(
          backgroundColor: HubTheme.navy,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// The Matrix / Side-by-side mode switch, styled as a navy segmented pill.
class _CompareModeSwitch extends StatelessWidget {
  final _CompareMode mode;
  final ValueChanged<_CompareMode> onChanged;
  const _CompareModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(_CompareMode m, IconData icon, String label) {
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
          seg(_CompareMode.matrix, Icons.grid_on, 'Matrix'),
          const SizedBox(width: 2),
          seg(_CompareMode.sideBySide, Icons.view_column, 'Side-by-side'),
        ],
      ),
    );
  }
}
