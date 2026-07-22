import 'package:flutter/material.dart';

import '../../models/submission_review_model.dart';
import '../../theme/moyd_brand.dart';
import '../review/stance_visuals.dart';

/// The Gemini verdict on a candidate, styled as a case ruling.
///
/// This is the review screen's signature element and the first thing a
/// committee member reads. Two faces:
///  - Clean candidate: navy->royal->sky banner, a large score numeral with a
///    ring gauge, the verdict word, then the rationale and an always-visible
///    per-issue ledger (no hidden expansion: the breakdown IS the content).
///  - Disqualified candidate: crimson banner stamped DISQUALIFIED, then one
///    indictment row per core-value break leading with the candidate's own
///    words: the quote is the evidence, so the design gives it the floor.
class VerdictBlock extends StatefulWidget {
  final AiAlignmentScore ai;

  /// Optional rule-based score for the labeled comparison chip.
  final double? rulePct;

  const VerdictBlock({super.key, required this.ai, this.rulePct});

  @override
  State<VerdictBlock> createState() => _VerdictBlockState();
}

class _VerdictBlockState extends State<VerdictBlock> {
  final Set<String> _expanded = {};

  AiAlignmentScore get ai => widget.ai;

  static const _crimson = [Color(0xFFB91C1C), Color(0xFF7F1D1D)];
  static const _hero = [Color(0xFF263351), Color(0xFF2B4B8C), Color(0xFF1D6FA8)];
  static const _gold = Color(0xFFE8B54A);

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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ai.disqualified
              ? _crimson.first.withValues(alpha: 0.45)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _banner(context),
          if (ai.disqualifiers.isNotEmpty) _indictments(context),
          if (ai.rationale.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                ai.rationale.trim(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ),
          if (ai.perIssue.isNotEmpty) _ledger(context),
          _footer(context),
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
      child: Row(
        children: [
          _scoreDial(),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GEMINI VERDICT',
                  style: TextStyle(
                    color: dq ? Colors.white.withValues(alpha: 0.85) : _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _verdictWord,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1.05,
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
      ),
    );
  }

  Widget _scoreDial() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: ai.overallScore / 100,
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(
                  ai.disqualified ? Colors.white : _gold),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ai.overallScore}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10.5,
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
                    Icon(Icons.gavel_rounded,
                        size: 15, color: MoydBrand.opposeFg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_issueLabel(d.issueId).toUpperCase()}'
                        '${d.position.isNotEmpty ? '  ·  ${d.position}' : ''}',
                        style: TextStyle(
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
                    style: TextStyle(
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

  // ── per-issue ledger ─────────────────────────────────────────────────────

  Widget _ledger(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ISSUE LEDGER',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          for (final issue in ai.perIssue) _ledgerRow(context, issue),
        ],
      ),
    );
  }

  Widget _ledgerRow(BuildContext context, AiIssueScore issue) {
    final cs = Theme.of(context).colorScheme;
    final fg = AlignmentVisuals.fg(issue.score.toDouble());
    final open = _expanded.contains(issue.id);
    final hasRationale = issue.rationale.trim().isNotEmpty;
    return InkWell(
      onTap: hasRationale
          ? () => setState(() =>
              open ? _expanded.remove(issue.id) : _expanded.add(issue.id))
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: fg, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Text(
                    issue.label.isNotEmpty ? issue.label : issue.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: issue.score / 100,
                      minHeight: 5,
                      backgroundColor: cs.outlineVariant.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${issue.score}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
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
            if (open && hasRationale)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 44, 2),
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

  Widget _footer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bits = <String>[
      if (ai.model != null && ai.model!.isNotEmpty) ai.model!,
      if (widget.rulePct != null)
        'old rule-based score ${widget.rulePct!.round()}%',
      if (ai.scoredAt != null)
        'scored ${ai.scoredAt!.toLocal().month}/${ai.scoredAt!.toLocal().day}',
    ];
    if (bits.isEmpty) return const SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Text(
        bits.join('  ·  '),
        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
      ),
    );
  }
}
