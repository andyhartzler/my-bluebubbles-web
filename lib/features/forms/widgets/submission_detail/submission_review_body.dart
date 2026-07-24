import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../models/form_schema.dart';
import '../../models/form_submission.dart';
import '../../models/submission_review_model.dart';
import 'candidate_hero_header.dart';
import 'documents_card.dart';
import 'hero_stat_band.dart';
import 'policy_positions_grid.dart';
import 'references_card.dart';
import 'section_card.dart';
import 'section_nav_bar.dart';
import 'verdict_block.dart';

/// The candidate-review content, shared between [SubmissionDetailScreen] and
/// the Questionnaire tab on `CandidateDetailScreen` so both surfaces render
/// the identical redesigned review: hero, navy stat band, sticky section
/// navigator, verdict block, then the questionnaire sections flowed into two
/// columns on wide screens.
///
/// A plain Column (no scroll view of its own) so hosts can embed it in
/// whatever scrolling context they already have. The section navigator syncs
/// to the nearest ancestor [Scrollable] (Host A's CustomScrollView, Host B's
/// ListView) and pins a duplicate of itself through an [OverlayPortal] once
/// the in-flow row scrolls past the viewport top — no host-specific code.
class SubmissionReviewBody extends StatefulWidget {
  final FormSchema form;
  final FormSubmission submission;
  final AiAlignmentScore? aiAlignment;

  /// Show the MOYD hero header. The candidate-profile tab hides it (the
  /// profile already renders the candidate's identity above the tabs).
  final bool showHero;

  final VoidCallback? onOpenLinkedProfile;
  final String? linkedProfileLabel;

  const SubmissionReviewBody({
    super.key,
    required this.form,
    required this.submission,
    this.aiAlignment,
    this.showHero = true,
    this.onOpenLinkedProfile,
    this.linkedProfileLabel,
  });

  @override
  State<SubmissionReviewBody> createState() => _SubmissionReviewBodyState();
}

class _SubmissionReviewBodyState extends State<SubmissionReviewBody> {
  /// Stable scroll-target key per nav id; the key rides its card into
  /// whichever column the dealer picks.
  final Map<String, GlobalKey> _keys = {};
  final GlobalKey _navAnchorKey = GlobalKey();
  final GlobalKey _bodyKey = GlobalKey();
  final OverlayPortalController _pinController = OverlayPortalController();

  /// Both nav instances (in-flow + pinned) listen; only the pill rows
  /// rebuild on scroll, never the body.
  final ValueNotifier<String?> _activeId = ValueNotifier<String?>(null);

  /// Pinned bar placement in root-overlay coordinates, recomputed whenever
  /// pinning engages or geometry changes.
  Rect? _pinnedRect;

  ScrollPosition? _position;

  /// Latched during animated jumps so the tracker doesn't flicker through
  /// intermediate pills mid-animation.
  String? _programmaticTargetId;

  /// Coalesces scroll-listener ticks to one geometry pass per frame.
  bool _frameScheduled = false;

  List<ReviewNavTarget> _targets = const [];

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Host A yields the CustomScrollView position, Host B the ListView
    // position. When neither exists the nav renders in-flow only and taps
    // fall back to Scrollable.ensureVisible — no crash, pinning never engages.
    final pos = Scrollable.maybeOf(context)?.position;
    if (!identical(pos, _position)) {
      _position?.removeListener(_onScrollTick);
      _position = pos;
      _position?.addListener(_onScrollTick);
      _scheduleTick();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScrollTick);
    _activeId.dispose();
    super.dispose();
  }

  void _onScrollTick() => _scheduleTick();

  void _scheduleTick() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (mounted) _updatePinAndActive();
    });
  }

  // ── geometry ──────────────────────────────────────────────────────────────

  /// The scroll offset at which [k]'s top touches the viewport top. Works
  /// identically in box (ListView) and sliver (CustomScrollView) hosts.
  double? _revealOffset(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro == null || !ro.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    if (viewport == null) return null;
    return viewport.getOffsetToReveal(ro, 0.0).offset;
  }

  /// Pinned bar placement: viewport top from the scrollable's own render box
  /// (lands below Host A's AppBar and Host B's tab chrome automatically),
  /// left/width from the body's box (respects Host A's centered column and
  /// Host B's list padding), all converted into root-overlay coordinates.
  void _computePinnedRect() {
    _pinnedRect = null;
    final pos = _position;
    if (pos == null) return;
    final scrollCtx = pos.context.notificationContext;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (scrollCtx == null || overlay == null) return;
    final scrollRo = scrollCtx.findRenderObject();
    final bodyRo = _bodyKey.currentContext?.findRenderObject();
    final overlayRo = overlay.context.findRenderObject();
    if (scrollRo is! RenderBox || bodyRo is! RenderBox || overlayRo is! RenderBox) {
      return;
    }
    if (!scrollRo.hasSize || !bodyRo.hasSize || !overlayRo.hasSize) return;
    final top = scrollRo.localToGlobal(Offset.zero, ancestor: overlayRo).dy;
    final left = bodyRo.localToGlobal(Offset.zero, ancestor: overlayRo).dx;
    _pinnedRect =
        Rect.fromLTWH(left, top, bodyRo.size.width, ReviewSectionNav.height);
  }

  void _updatePinAndActive() {
    final pos = _position;
    final navMounted =
        _targets.length >= 2 && _navAnchorKey.currentContext != null;
    if (pos == null ||
        !pos.hasPixels ||
        !pos.hasContentDimensions ||
        !navMounted) {
      if (_pinController.isShowing) _pinController.hide();
      return;
    }

    final navOffset = _revealOffset(_navAnchorKey);
    if (navOffset == null) {
      if (_pinController.isShowing) _pinController.hide();
      return;
    }

    // Pin while the in-flow row is scrolled past AND the body's bottom edge
    // is still below viewportTop + bar height (stop pinning once the whole
    // review has scrolled past).
    var pinNow = pos.pixels > navOffset;
    if (pinNow) {
      final bodyRo = _bodyKey.currentContext?.findRenderObject();
      final bodyTop = _revealOffset(_bodyKey);
      if (bodyRo is RenderBox && bodyRo.hasSize && bodyTop != null) {
        final bodyBottom = bodyTop + bodyRo.size.height;
        if (pos.pixels + ReviewSectionNav.height >= bodyBottom) pinNow = false;
      }
    }

    if (pinNow) {
      final prev = _pinnedRect;
      _computePinnedRect();
      if (_pinnedRect == null) {
        if (_pinController.isShowing) _pinController.hide();
      } else if (!_pinController.isShowing) {
        _pinController.show();
      } else if (prev != _pinnedRect) {
        // Rare (window resize / host chrome change): rebuild the overlay
        // child with the fresh rect.
        setState(() {});
      }
    } else if (_pinController.isShowing) {
      // Hide is instant — avoids ghost bars during fast flings.
      _pinController.hide();
    }

    // Active tracking: last target whose top is above the anchor line just
    // below the pinned bar. Skipped while an animated jump is in flight.
    if (_programmaticTargetId == null && _targets.isNotEmpty) {
      final anchor = pos.pixels + ReviewSectionNav.height + 24;
      var active = _targets.first.id;
      for (final t in _targets) {
        final off = _revealOffset(_keys[t.id]!);
        if (off != null && off <= anchor) active = t.id;
      }
      // End-of-scroll clamp so short tail sections can win. Only when the
      // content actually scrolls: with maxScrollExtent 0 the comparison is
      // vacuously true and would pin the last pill while the user sits at
      // the top.
      if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 4) {
        active = _targets.last.id;
      }
      _activeId.value = active;
    }
  }

  // ── navigation ────────────────────────────────────────────────────────────

  Future<void> _jumpTo(String id) async {
    final key = _keys[id];
    if (key == null) return;
    final pos = _position;
    if (pos == null) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
      return;
    }
    final reveal = _revealOffset(key);
    if (reveal == null) return;
    // Land the section header just below the pinned bar, never underneath it.
    final target = (reveal - ReviewSectionNav.height - 8)
        .clamp(0.0, pos.maxScrollExtent)
        .toDouble();
    setState(() => _programmaticTargetId = id);
    _activeId.value = id;
    await pos.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    if (mounted) setState(() => _programmaticTargetId = null);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  List<ReviewNavTarget> _buildTargets(SubmissionReviewModel model) {
    return [
      if (model.aiAlignment != null)
        const ReviewNavTarget(id: '_verdict', label: 'Alignment'),
      for (final section in model.sections)
        ReviewNavTarget(
          id: section.id,
          label: section.title.isEmpty ? 'Overview' : section.title,
        ),
      if (model.hasDocuments)
        const ReviewNavTarget(id: '_documents', label: 'Documents'),
      if (model.references.isNotEmpty)
        const ReviewNavTarget(id: '_references', label: 'References'),
    ];
  }

  Widget _pinnedNav(BuildContext context) {
    final rect = _pinnedRect;
    if (rect == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Positioned.fromRect(
      rect: rect,
      child: _PinnedNavEnter(
        child: Container(
          // Not a branded navy surface, so M3 tokens are correct here.
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ReviewSectionNav(
            targets: _targets,
            activeId: _activeId,
            onTap: _jumpTo,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = SubmissionReviewModel.from(widget.form, widget.submission,
        aiAlignment: widget.aiAlignment);

    _targets = _buildTargets(model);
    for (final t in _targets) {
      _keys.putIfAbsent(t.id, () => GlobalKey());
    }
    final showNav = _targets.length >= 2;

    // Wrap each card BEFORE dealing so the key rides the card into whichever
    // column the dealer picks; both columns share one scroll axis, so
    // getOffsetToReveal reports the true offset regardless of column.
    Widget keyed(String id, Widget child) =>
        KeyedSubtree(key: _keys[id], child: child);

    final sectionCards = <Widget>[
      for (final section in model.sections)
        keyed(
          section.id,
          SectionCard(
            section: section,
            leading: section.isPolicyGrid
                ? PolicyPositionsGrid(positions: section.policyPositions)
                : null,
          ),
        ),
    ];
    final tailCards = <Widget>[
      if (model.hasDocuments) keyed('_documents', DocumentsCard(model: model)),
      if (model.references.isNotEmpty)
        keyed('_references', ReferencesCard(references: model.references)),
      ReviewMetadataTile(submission: widget.submission, form: widget.form),
    ];

    final band = HeroStatBand(model: model);

    // The LayoutBuilder wrap makes window resizes rebuild geometry (pinned
    // rect + pin state re-derive on the next frame).
    return LayoutBuilder(builder: (context, constraints) {
      _scheduleTick();
      return Column(
        key: _bodyKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHero)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CandidateHeroHeader(
                model: model,
                status: widget.submission.status,
                onOpenLinkedProfile: widget.onOpenLinkedProfile,
                linkedProfileLabel: widget.linkedProfileLabel,
              ),
            ),
          if (band.hasContent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: band,
            ),
          if (showNav)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OverlayPortal(
                controller: _pinController,
                overlayChildBuilder: _pinnedNav,
                child: KeyedSubtree(
                  key: _navAnchorKey,
                  child: ReviewSectionNav(
                    targets: _targets,
                    activeId: _activeId,
                    onTap: _jumpTo,
                  ),
                ),
              ),
            ),
          if (model.aiAlignment != null)
            keyed(
              '_verdict',
              VerdictBlock(
                  ai: model.aiAlignment!, rulePct: model.ruleAlignmentPct),
            ),
          _SectionsFlow(cards: [...sectionCards, ...tailCards]),
        ],
      );
    });
  }
}

/// Enter motion for the pinned bar: 120ms fade with a 4px settle. Hiding is
/// instant (the portal just unmounts).
class _PinnedNavEnter extends StatefulWidget {
  final Widget child;
  const _PinnedNavEnter({required this.child});

  @override
  State<_PinnedNavEnter> createState() => _PinnedNavEnterState();
}

class _PinnedNavEnterState extends State<_PinnedNavEnter> {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _entered ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedSlide(
        offset: _entered ? Offset.zero : const Offset(0, -4 / ReviewSectionNav.height),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Flows review cards into two balanced columns when the host is wide enough
/// to hold them at a readable measure; single column otherwise. Cards are
/// dealt greedily left/right by order so the reading sequence stays roughly
/// top-to-bottom.
class _SectionsFlow extends StatelessWidget {
  final List<Widget> cards;
  const _SectionsFlow({required this.cards});

  static const double _twoColumnMin = 980;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _twoColumnMin || cards.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }
        final left = <Widget>[];
        final right = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          (i.isEven ? left : right).add(cards[i]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            const SizedBox(width: 16),
            Expanded(child: Column(children: right)),
          ],
        );
      },
    );
  }
}

/// Collapsed submission-metadata tile (moved out of the detail screen so the
/// embedded review shows the same provenance).
class ReviewMetadataTile extends StatelessWidget {
  final FormSubmission submission;
  final FormSchema form;

  const ReviewMetadataTile({
    super.key,
    required this.submission,
    required this.form,
  });

  String _fmt(DateTime d) =>
      '${d.month}/${d.day}/${d.year} at ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(
                child: SelectableText(value,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          title: Text('Submission info',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Submission ID', submission.id),
            row('Form ID', submission.formId),
            if (submission.memberId != null)
              row('Member ID', submission.memberId!),
            if (submission.candidateId != null)
              row('Candidate ID', submission.candidateId!),
            row('Submitted at', _fmt(submission.createdAt)),
            row('Status', submission.status),
          ],
        ),
      ),
    );
  }
}
