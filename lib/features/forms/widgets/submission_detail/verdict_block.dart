import 'package:flutter/material.dart';

import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import '../review/stance_visuals.dart';
import 'review_text.dart';

/// The Gemini verdict on a candidate, styled as a case ruling.
///
/// This is the review screen's signature element and the first thing a
/// committee member reads. Two faces:
///  - Clean candidate: navy->royal->sky banner, a large score numeral with a
///    graded ring gauge, the verdict word, then the rationale, the itemized
///    "where the points went" deductions (sub-100 scores) and a per-issue
///    ledger whose rows open by default on wide screens.
///  - Disqualified candidate: crimson banner stamped DISQUALIFIED, then one
///    indictment row per core-value break leading with the candidate's own
///    words: the quote is the evidence, so the design gives it the floor.
class VerdictBlock extends StatefulWidget {
  final AiAlignmentScore ai;

  /// Optional rule-based score for the labeled comparison chip.
  final double? rulePct;

  /// The candidate's own stance per issue id ({field id: chosen option
  /// label}), so a deduction can lead with the answer that cost the points
  /// instead of only the scorer's paraphrase of it. Empty is survivable: the
  /// row falls back to the quote.
  final Map<String, String>? selectedOptions;

  /// Superseded scoring runs for this submission, newest first. Empty on 73
  /// of 74 scored candidates today, and empty renders nothing at all.
  final List<AiScoreHistoryEntry> history;

  const VerdictBlock({
    super.key,
    required this.ai,
    this.rulePct,
    this.selectedOptions,
    this.history = const [],
  });

  @override
  State<VerdictBlock> createState() => _VerdictBlockState();
}

class _VerdictBlockState extends State<VerdictBlock> {
  /// Ledger rows the user has flipped away from the width-based default.
  final Set<String> _userToggled = {};

  /// Prior-scores disclosure, collapsed until asked for.
  bool _historyOpen = false;

  /// Latched on the ledger's first layout: rows open by default on wide
  /// screens (the verdict renders full-width above the two-column flow, so
  /// this engages on desktop), tap-to-expand on phones.
  bool? _defaultOpen;

  AiAlignmentScore get ai => widget.ai;

  static const _crimson = [Color(0xFFB91C1C), Color(0xFF7F1D1D)];
  static const _hero = [Color(0xFF263351), Color(0xFF2B4B8C), Color(0xFF1D6FA8)];
  static const _gold = Color(0xFFE8B54A);

  /// Graded ring color. Bright-on-navy values: non-text UI graphics need 3:1
  /// against the banner and all three clear it by a wide margin at every
  /// gradient stop; the numeral stays white (> 8:1).
  Color get _ringColor {
    if (ai.disqualified) return Colors.white; // crimson banner keeps white
    final s = ai.overallScore;
    if (s >= 85) return const Color(0xFF4ADE80); // green
    if (s >= 50) return const Color(0xFFFBBF24); // amber
    return const Color(0xFFF87171); // red
  }

  String get _verdictWord {
    if (ai.disqualified) return 'DISQUALIFIED';
    final s = ai.overallScore;
    if (s >= 85) return 'CHAMPION';
    if (s >= 70) return 'ALIGNED';
    if (s >= 40) return 'MIXED';
    return 'MISALIGNED';
  }

  String get _verdictLine {
    if (ai.disqualified) {
      final n = ai.disqualifiers.length;
      return n == 1
          ? 'One answer breaks a core MOYD value'
          : '$n answers break core MOYD values';
    }
    final s = ai.overallScore;
    if (s >= 85) return 'Fights for the platform, not just with it';
    if (s >= 70) return 'Substantively with MOYD on what matters';
    if (s >= 40) return 'Real agreement, real breaks: read the ledger';
    return 'At odds with the platform on most of what matters';
  }

  String _issueLabel(String issueId) {
    for (final i in ai.perIssue) {
      if (i.id == issueId && i.label.isNotEmpty) return i.label;
    }
    // pos_trans_youth -> "Trans youth"
    final raw = issueId.replaceFirst('pos_', '').replaceAll('_', ' ');
    return raw.isEmpty
        ? issueId
        : raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ReviewCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      borderColor: ai.disqualified
          ? _crimson.first.withValues(alpha: 0.45)
          : cs.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _banner(context),
          if (ai.isProvisional) _provisionalBand(context),
          if (ai.disqualifiers.isNotEmpty) _indictments(context),
          if (ai.rationale.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                ai.rationale.trim(),
                style: ReviewText.body(context),
              ),
            ),
          // The gate is the deductions themselves, nothing else. It used to
          // also require overallScore < 100, which hid real itemized content
          // from every candidate the scorer gave a 100 while still recording
          // where points would have gone.
          if (ai.deductions.isNotEmpty) _deductions(context),
          if (ai.perIssue.isNotEmpty) _ledger(context),
          _footer(context),
          if (widget.history.isNotEmpty) _historyDisclosure(context),
        ],
      ),
    );
  }

  // ── provisional basis band ───────────────────────────────────────────────

  /// The live trust defect this page shipped with: a verdict computed from a
  /// half-finished draft rendered identically to one computed from a
  /// submitted questionnaire, with nothing on screen to tell them apart.
  ///
  /// Amber, not crimson. It must be unmissable, and it must not compete with
  /// a DISQUALIFIED banner, which stays the loudest thing on the card. The
  /// qualifiedFg/qualifiedBg pair is self-contained and AA in both themes.
  Widget _provisionalBand(BuildContext context) {
    final partial = ai.scoreBasis == 'partial_draft';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      decoration: const BoxDecoration(
        color: MoydBrand.qualifiedBg,
        border: Border(
          left: BorderSide(color: MoydBrand.qualifiedFg, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 15, color: MoydBrand.qualifiedFg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  partial
                      ? 'SCORED FROM A PARTIAL DRAFT'
                      : 'SCORED FROM AN UNFINISHED SUBMISSION',
                  style: const TextStyle(
                    color: MoydBrand.qualifiedFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This verdict was computed before the candidate finished the '
            'questionnaire (status: ${ai.sourceStatusLabel}). Treat the score '
            'as provisional.',
            style: const TextStyle(
              color: MoydBrand.qualifiedFg,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── banner ────────────────────────────────────────────────────────────────

  Widget _banner(BuildContext context) {
    final dq = ai.disqualified;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dq ? _crimson : _hero,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: LayoutBuilder(builder: (context, c) {
        // Phone-width banner: smaller dial, tighter verdict type, so
        // DISQUALIFIED never wraps on a 375pt screen.
        final narrow = c.maxWidth < 420;
        return Row(
          children: [
            _scoreDial(narrow ? 64.0 : 84.0),
            SizedBox(width: narrow ? 14 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GEMINI VERDICT',
                    style: TextStyle(
                      color: dq ? Colors.white.withValues(alpha: 0.85) : _gold,
                      fontSize: narrow ? 10 : 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _verdictWord,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: narrow ? 22 : 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _verdictLine,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _scoreDial(double size) {
    final narrow = size < 70;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            // Sweep-in on load: the one hero motion on the page.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ai.overallScore / 100),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: narrow ? 5 : 6,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation(_ringColor),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ai.overallScore}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 22 : 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: narrow ? 9 : 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── disqualifier indictments ─────────────────────────────────────────────

  Widget _indictments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in ai.disqualifiers)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: MoydBrand.opposeBg,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: _crimson.first, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded,
                        size: 15, color: MoydBrand.opposeFg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_issueLabel(d.issueId).toUpperCase()}'
                        '${d.position.isNotEmpty ? '  ·  ${d.position}' : ''}',
                        style: const TextStyle(
                          color: MoydBrand.opposeFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (d.quote.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“${d.quote.trim()}”',
                    style: const TextStyle(
                      color: MoydBrand.opposeFg,
                      fontSize: 14.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
                if (d.whyDisqualifying.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    d.whyDisqualifying.trim(),
                    style: TextStyle(
                      color: MoydBrand.opposeFg.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ── where the points went ────────────────────────────────────────────────

  /// Itemized deductions for sub-100 scores: how many points each issue cost
  /// and the candidate's own words that cost them. Disqualified candidates
  /// render these below their indictments. Absent/empty deductions (older
  /// rows, 100-scorers) skip the block entirely.
  /// The candidate's chosen option for a deduction's issue id, or null when
  /// the id does not resolve to a question on this form.
  String? _answerFor(String issueId) {
    if (issueId.isEmpty) return null;
    final v = widget.selectedOptions?[issueId]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Widget _deductions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHERE THE POINTS WENT', style: ReviewText.overline(context)),
          const SizedBox(height: 6),
          for (final d in ai.deductions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Self-contained oppose pair (shipped AA: dark red on the
                  // light red fill in both themes).
                  Container(
                    width: 56,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MoydBrand.opposeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-${d.pointsLost} pts',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: MoydBrand.opposeFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.label, style: ReviewText.bodyStrong(context)),
                        // The candidate's own stance, joined back by issue id.
                        // The answer is the thing that actually cost the
                        // points, and it was always in the submission; the
                        // verdict just was not looking it up.
                        if (_answerFor(d.issueId) != null)
                          Text.rich(
                            TextSpan(
                              style: ReviewText.secondary(context),
                              children: [
                                const TextSpan(text: 'Their answer: '),
                                TextSpan(
                                  text: _answerFor(d.issueId),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        if (d.quote.trim().isNotEmpty)
                          Text(
                            '“${d.quote.trim()}”',
                            style: ReviewText.secondary(context)
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        Text(d.explanation,
                            style: ReviewText.secondary(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── per-issue ledger ─────────────────────────────────────────────────────

  Widget _ledger(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: LayoutBuilder(builder: (context, c) {
        // Phone width: the score bar moves to its own full-width line under
        // the label instead of squeezing beside it.
        final narrow = c.maxWidth < 480;
        // Latch the default-open ruling on first layout.
        if (_defaultOpen == null) {
          final wide = c.maxWidth >= 700;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _defaultOpen == null) {
              setState(() => _defaultOpen = wide);
            }
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ISSUE LEDGER', style: ReviewText.overline(context)),
            const SizedBox(height: 6),
            for (final issue in ai.perIssue)
              _ledgerRow(context, issue, narrow),
          ],
        );
      }),
    );
  }

  Widget _bar(ColorScheme cs, Color fg, int score) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: score / 100,
        minHeight: 5,
        backgroundColor: cs.outlineVariant.withValues(alpha: 0.35),
        valueColor: AlwaysStoppedAnimation(fg),
      ),
    );
  }

  Widget _ledgerRow(BuildContext context, AiIssueScore issue, bool narrow) {
    final cs = Theme.of(context).colorScheme;
    // fg colors are safe only on their matching light bg, never bare on the
    // ambient surface (opposeFg lands ~2.8:1 on a dark card), so the dot and
    // the score numeral each carry their own bg like the deductions chip.
    final fg = AlignmentVisuals.fg(issue.score.toDouble());
    final bg = AlignmentVisuals.bg(issue.score.toDouble());
    // Open = the width default XOR a user toggle away from it.
    final open = (_defaultOpen ?? false)
        ? !_userToggled.contains(issue.id)
        : _userToggled.contains(issue.id);
    final hasRationale = issue.rationale.trim().isNotEmpty;
    return InkWell(
      onTap: hasRationale
          ? () => setState(() => _userToggled.contains(issue.id)
              ? _userToggled.remove(issue.id)
              : _userToggled.add(issue.id))
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        // A hair more vertical room on touch screens: rows stay comfortably
        // tappable without a visible size jump.
        padding: EdgeInsets.symmetric(vertical: narrow ? 9 : 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: fg, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Text(
                    issue.label.isNotEmpty ? issue.label : issue.id,
                    maxLines: narrow ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _bar(cs, fg, issue.score)),
                ],
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${issue.score}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
                if (hasRationale)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (narrow)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 0, 0),
                child: _bar(cs, fg, issue.score),
              ),
            if (open && hasRationale)
              Padding(
                padding: EdgeInsets.fromLTRB(22, 4, narrow ? 0 : 52, 2),
                child: Text(
                  issue.rationale.trim(),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── footer ───────────────────────────────────────────────────────────────

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Jul 25" or "Jul 25, 2026". The date always carries its year in the
  /// footer: a bare month/day silently ambiguates across scoring years, and
  /// this corpus already spans a re-scoring campaign.
  static String _fmtDate(DateTime d, {bool withYear = false}) {
    final l = d.toLocal();
    final base = '${_months[l.month - 1]} ${l.day}';
    return withYear ? '$base, ${l.year}' : base;
  }

  /// Everything the scorer recorded about how this verdict was produced.
  ///
  /// The model id used to be suppressed here on the grounds that execs kept
  /// asking about it. It is shown now because "show all the AI output" is the
  /// instruction this page was rebuilt under, and a verdict whose provenance
  /// is partly hidden is harder to trust than one where all of it is on the
  /// table. `scorer_host` is the one field still withheld: a machine hostname
  /// carries no decision value.
  Widget _footer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rubric = ai.rubricVersion;
    final bits = <({String text, IconData? icon})>[
      if (widget.rulePct != null)
        (text: 'Rule-based: ${widget.rulePct!.round()}%', icon: null),
      if (ai.scoredAt != null)
        (text: 'Scored ${_fmtDate(ai.scoredAt!, withYear: true)}', icon: null),
      if (ai.model != null && ai.model!.isNotEmpty)
        (text: 'Model: ${ai.model}', icon: null),
      // Null rubric is not a gap to hide. 73 of 77 rows predate rubric
      // versioning, and saying so is what stops those scores being read as
      // comparable with the four that carry one.
      if (rubric != null && rubric.isNotEmpty)
        (
          text: 'Rubric ${rubric.length > 8 ? rubric.substring(0, 8) : rubric}',
          icon: null
        )
      else
        (text: 'Pre-rubric scoring run', icon: null),
      if (ai.scoreBasis != null)
        (
          text: 'Basis: ${ai.scoreBasis!.replaceAll('_', ' ')}',
          icon: null
        ),
      if (ai.answeredScoredRadios != null && ai.answeredKeyCount != null)
        (
          text: '${ai.answeredScoredRadios} scored answers · '
              '${ai.answeredKeyCount} keys',
          icon: null
        ),
      if (ai.promotedFromBasis != null)
        (
          text: 'Promoted from ${ai.promotedFromBasis!.replaceAll('_', ' ')}'
              '${ai.promotedAt == null ? '' : ' ${_fmtDate(ai.promotedAt!)}'}',
          icon: null
        ),
      if (ai.supersededCount > 0)
        (
          text: ai.supersededCount == 1
              ? 'Re-scored once'
              : 'Re-scored ${ai.supersededCount} times',
          icon: null
        ),
      if (ai.reviewLocked)
        (text: 'Review locked', icon: Icons.lock_outline),
    ];
    if (bits.isEmpty) return const SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final bit in bits)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bit.icon != null) ...[
                    Icon(bit.icon, size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    bit.text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── prior scores ─────────────────────────────────────────────────────────

  /// Superseded scoring runs, collapsed. One of 74 scored candidates has any,
  /// so the caller renders this only when the list is non-empty and the
  /// default page carries nothing here at all. A list, not a timeline: the
  /// corpus does not support one.
  Widget _historyDisclosure(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = widget.history;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _historyOpen = !_historyOpen),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Prior scores (${rows.length})',
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _historyOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(Icons.expand_more,
                        size: 18, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            sizeCurve: Curves.easeOut,
            crossFadeState: _historyOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final h in rows) _historyRow(context, h)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, AiScoreHistoryEntry h) {
    final cs = Theme.of(context).colorScheme;
    final fg = AlignmentVisuals.fg(h.overallScore.toDouble());
    final bg = AlignmentVisuals.bg(h.overallScore.toDouble());
    final suffix = <String>[
      if (h.scoreBasis != null) h.scoreBasis!.replaceAll('_', ' '),
      if (h.scoredAt != null) _fmtDate(h.scoredAt!, withYear: true),
      if (h.archivedReason != null)
        'archived: ${h.archivedReason}'
      else if (h.applied)
        'applied',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${h.overallScore}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              suffix.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
