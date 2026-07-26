import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';

/// One free-text answer the candidate typed, with the question label exactly
/// as the form asked it.
class VoiceAnswer {
  /// Form field id (`why_running`, `pos_top_priority`, ...).
  final String id;

  /// The question as it was put to the candidate. Used verbatim so an exec
  /// reads the answer against the real prompt, never a paraphrase.
  final String question;

  final String text;

  const VoiceAnswer({
    required this.id,
    required this.question,
    required this.text,
  });

  int get length => text.length;
}

/// Harvests everything a candidate wrote in their own words out of a
/// [CandidateEntry].
///
/// Generic-first: it walks the already-parsed `ReviewSection` answers on
/// `entry.model` and keeps the long-form types, so the question labels come
/// from the live form schema rather than being hardcoded here. Policy
/// explanations are excluded automatically because `SubmissionReviewModel`
/// consumes `<id>_explain` / `<id>_detail` into `PolicyPosition.explanation`
/// before sections are built, so they never double up here.
///
/// [headline] is the ordered pair the ballot row leads with. Everything else
/// the candidate wrote is still returned by [all] and reachable in the sheet,
/// so nothing they said is unreachable from the ballot.
class CandidateVoice {
  /// Long-form field types. `long_answer` is what the endorsement
  /// questionnaire uses; `textarea` is the legacy/builder alias.
  static const Set<String> _longTypes = {'long_answer', 'textarea'};

  /// The two answers the exec committee asked for by name, in reading order.
  /// Anything else the candidate wrote follows these in form order.
  static const List<String> _headlineIds = ['why_running', 'pos_top_priority'];

  /// A fallback question label for the headline ids, used only when the field
  /// has been removed from the live schema but the submitted value survives in
  /// `form_submissions.data`. Never overrides a real schema label.
  static const Map<String, String> _fallbackQuestions = {
    'why_running': 'Why are you running, in your own words?',
    'pos_top_priority':
        "What's the single policy you'd fight hardest for if elected?",
  };

  final List<VoiceAnswer> headline;
  final List<VoiceAnswer> supporting;

  const CandidateVoice._({required this.headline, required this.supporting});

  List<VoiceAnswer> get all => [...headline, ...supporting];

  bool get isEmpty => headline.isEmpty && supporting.isEmpty;

  static CandidateVoice from(CandidateEntry entry) {
    final byId = <String, VoiceAnswer>{};
    final order = <String>[];

    void put(String id, String question, String rawText) {
      final text = rawText.trim();
      if (text.isEmpty) return;
      if (byId.containsKey(id)) return;
      byId[id] = VoiceAnswer(id: id, question: question, text: text);
      order.add(id);
    }

    for (final section in entry.model.sections) {
      for (final answer in section.answers) {
        if (!_longTypes.contains(answer.type)) continue;
        put(answer.field.id, answer.label, answer.displayValue);
      }
    }

    // Belt and braces: if a headline field was dropped from the schema after
    // this candidate submitted, the parsed sections will not contain it, but
    // the value is still on the submission. Read it directly rather than
    // telling the exec the candidate wrote nothing.
    for (final id in _headlineIds) {
      if (byId.containsKey(id)) continue;
      final raw = entry.submission.data[id];
      if (raw == null) continue;
      put(id, _fallbackQuestions[id] ?? id, raw.toString());
    }

    final headline = <VoiceAnswer>[];
    for (final id in _headlineIds) {
      final a = byId[id];
      if (a != null) headline.add(a);
    }
    final supporting = <VoiceAnswer>[
      for (final id in order)
        if (!_headlineIds.contains(id)) byId[id]!,
    ];

    return CandidateVoice._(headline: headline, supporting: supporting);
  }

  /// The headline questions with no answer on file, by question text.
  List<String> blankHeadlineQuestions() {
    final answered = headline.map((a) => a.id).toSet();
    return [
      for (final id in _headlineIds)
        if (!answered.contains(id)) _fallbackQuestions[id] ?? id,
    ];
  }
}

/// Above this many characters an answer is no longer expanded in place: the
/// control opens the full-text sheet instead. A 2,600 character answer
/// inlined into a ballot row pushes the vote buttons a full screen away on a
/// phone, which is exactly the wrong trade on a meeting night. Answers below
/// the threshold expand in place so the common case costs no navigation.
const int _inlineExpandLimit = 900;

/// How many lines an answer shows before it is clamped. Six lines covers the
/// median endorsement answer end to end at ballot width, so most candidates
/// need no interaction at all.
const int _clampLines = 6;

/// Comfortable reading measure. Body copy this long needs a line length cap or
/// the eye loses its place on a wide desktop window.
const double _measure = 620;

/// The one reading style, shared by the in-row answer and the sheet answer so
/// the text does not change shape when the exec moves between them.
///
/// Looser leading than the 1.4 used for the AI one-liners, because people read
/// this end to end. Full-strength [ColorScheme.onSurface] rather than
/// onSurfaceVariant: this is the primary thing to read in the row, and muted
/// grey at 13.5px is where light-theme legibility falls over.
TextStyle _bodyStyle(ColorScheme cs) => TextStyle(
      fontSize: 13.5,
      height: 1.55,
      color: cs.onSurface,
    );

/// The candidate speaking for themselves, inside the ballot row.
///
/// WHY THIS EXISTS: 30 of 77 scored questionnaires came back at exactly 100
/// with zero deductions. For those candidates the AI rationale and the
/// "where the points went" list say nothing that separates one from another,
/// so an exec voting off the score alone is voting off a tie. Every one of
/// those 30 wrote both free-text answers. This surfaces them.
///
/// WHY IT RENDERS FOR EVERYONE: a rule that only showed this at exactly 100
/// would create a cliff. A 98 with one trivial deduction is just as
/// undifferentiated as a 100, and a block that appears only sometimes is a
/// block an exec cannot trust the absence of. What changes with the score is
/// PROMINENCE, not presence:
///
///  * [lead] true  (nothing deducted, or not scored at all): the candidate's
///    words are the only substantive thing to read, so they come first and
///    open expanded.
///  * [lead] false (deductions and/or disqualifiers exist): the itemised AI
///    evidence already gives the exec plenty, so this collapses to a single
///    tappable row underneath it. One tap, never a dead end.
class CandidateVoiceBlock extends StatefulWidget {
  final CandidateEntry entry;

  /// True when this block leads the expansion (see the class doc).
  final bool lead;

  const CandidateVoiceBlock({
    super.key,
    required this.entry,
    required this.lead,
  });

  @override
  State<CandidateVoiceBlock> createState() => _CandidateVoiceBlockState();
}

class _CandidateVoiceBlockState extends State<CandidateVoiceBlock> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.lead;
  }

  @override
  void didUpdateWidget(covariant CandidateVoiceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Promotion to lead (a rescore that cleared every deduction) should open
    // the block; demotion must not slam it shut under someone mid-read.
    if (widget.lead && !oldWidget.lead) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    final voice = CandidateVoice.from(widget.entry);
    if (voice.isEmpty) {
      // In lead position this IS the row's content, so it gets the full
      // caution panel. In supporting position the exec already has itemised
      // deductions to read, so a loud amber box would be noise: one honest
      // line is enough.
      return _NothingWritten(entry: widget.entry, quiet: !widget.lead);
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final body = _VoiceBody(entry: widget.entry, voice: voice);

    if (widget.lead) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _VoiceHeader(entry: widget.entry),
            const SizedBox(height: 8),
            body,
          ],
        ),
      );
    }

    // Supporting mode: a quiet disclosure row that matches VoterRollDisclosure.
    final count = voice.all.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                Icon(Icons.format_quote, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('In their own words',
                    style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
                Expanded(
                  child: Text(
                    count == 1
                        ? ' · 1 written answer'
                        : ' · $count written answers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
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
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: body,
          ),
        ),
      ],
    );
  }
}

/// Header: an explicit attribution line so nobody mistakes this for the model
/// talking. The AI rationale block one slot away uses `Icons.auto_awesome` and
/// the label "AI ALIGNMENT"; this deliberately uses a quote mark and names the
/// candidate.
class _VoiceHeader extends StatelessWidget {
  final CandidateEntry entry;
  const _VoiceHeader({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ai = entry.aiAlignment;

    // Only claim "nothing to deduct" when that is literally true of the score
    // in hand. An unscored row gets the honest version instead.
    final String note;
    if (ai == null) {
      note = 'Not AI scored yet, so this is all there is to read.';
    } else if (ai.deductions.isEmpty && ai.disqualifiers.isEmpty) {
      note = 'The AI found nothing to deduct, so the score cannot separate '
          '${entry.name} from anyone else at ${ai.overallScore}. '
          'Read what they wrote.';
    } else {
      note = 'Written by ${entry.name} on the questionnaire.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.format_quote, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('IN THEIR OWN WORDS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: cs.onSurfaceVariant)),
            const Spacer(),
            if (ai != null) AlignmentBadge(pct: ai.pct, dense: true),
          ],
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _measure),
          child: Text(note,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        ),
      ],
    );
  }
}

/// The answers themselves plus the honest "left blank" lines and the
/// everything-they-wrote affordance.
class _VoiceBody extends StatelessWidget {
  final CandidateEntry entry;
  final CandidateVoice voice;
  const _VoiceBody({required this.entry, required this.voice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final blanks = voice.blankHeadlineQuestions();
    final extras = voice.supporting.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < voice.headline.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _Answer(entry: entry, answer: voice.headline[i]),
        ],
        // If a headline question was answered by nobody at all this candidate
        // still gets their supporting answers rather than an empty block.
        if (voice.headline.isEmpty)
          for (int i = 0; i < voice.supporting.length && i < 2; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _Answer(entry: entry, answer: voice.supporting[i]),
          ],
        for (final q in blanks) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.remove_circle_outline,
                  size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Left blank: "$q"',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ],
        if (extras > 0) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showCandidateVoiceSheet(context, entry),
              icon: Icon(Icons.notes, size: 15, color: cs.onSurfaceVariant),
              label: Text(
                extras == 1
                    ? 'Read everything they wrote (1 more answer)'
                    : 'Read everything they wrote ($extras more answers)',
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5),
              ),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ),
        ],
      ],
    );
  }
}

/// One question and answer. The question is the form's own wording; the answer
/// sits behind a decorative gold rule, matching the quote treatment already
/// used for deduction quotes elsewhere in this expansion. Gold is a rule only,
/// never a text color, so both themes stay legible.
class _Answer extends StatefulWidget {
  final CandidateEntry entry;
  final VoiceAnswer answer;
  const _Answer({required this.entry, required this.answer});

  @override
  State<_Answer> createState() => _AnswerState();
}

class _AnswerState extends State<_Answer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.answer;
    final style = _bodyStyle(cs);
    final tooLongToInline = a.length > _inlineExpandLimit;
    // Rough reading time at ~230 wpm / ~5.5 characters per word. On a meeting
    // night "about 2 min" is the number an exec actually needs before they
    // commit to opening a 2,600 character answer; a character count is not.
    // Always >= 1 here because this only renders above _inlineExpandLimit.
    final readMinutes = (a.length / 1265).ceil();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _measure),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(a.question.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  height: 1.3,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border:
                  Border(left: BorderSide(color: HubTheme.gold, width: 3)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final overflows = _overflows(
                  text: a.text,
                  style: style,
                  maxWidth: constraints.maxWidth,
                  textScaler: MediaQuery.textScalerOf(context),
                );
                final clamp = overflows && !(_expanded && !tooLongToInline);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.text,
                      style: style,
                      maxLines: clamp ? _clampLines : null,
                      overflow:
                          clamp ? TextOverflow.ellipsis : TextOverflow.clip,
                    ),
                    if (overflows)
                      Align(
                        alignment: Alignment.centerLeft,
                        // Affordance carried by the icon and the weight, not
                        // by an accent color: this app ships arbitrary user
                        // themes (and Monet dynamic color), so cs.primary is
                        // not a contrast guarantee the way cs.onSurface is.
                        child: TextButton.icon(
                          onPressed: () {
                            if (tooLongToInline) {
                              showCandidateVoiceSheet(context, widget.entry,
                                  focusId: a.id);
                            } else {
                              setState(() => _expanded = !_expanded);
                            }
                          },
                          icon: Icon(
                            tooLongToInline
                                ? Icons.open_in_full
                                : (_expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more),
                            size: 15,
                            color: cs.onSurface,
                          ),
                          label: Text(
                            tooLongToInline
                                ? 'Read in full (about $readMinutes min)'
                                : (_expanded ? 'Show less' : 'Read more'),
                            style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// True when [text] would need more than [_clampLines] lines at this width.
  /// Measured rather than guessed from character count, so the control never
  /// appears on an answer that already fits.
  static bool _overflows({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) return text.length > 240;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _clampLines,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final result = painter.didExceedMaxLines;
    painter.dispose();
    return result;
  }
}

/// The honest empty state. A candidate who scored 100 and wrote nothing is the
/// one real dead end in this data, and the exec deserves to be told that in
/// words rather than shown a blank panel.
///
/// Colors are the self-contained qualifiedFg/qualifiedBg pair (~5.1:1),
/// identical in both themes, so this never depends on the surrounding surface.
class _NothingWritten extends StatelessWidget {
  final CandidateEntry entry;

  /// One muted line instead of the caution panel, for when the row already
  /// carries itemised deductions the exec can read.
  final bool quiet;

  const _NothingWritten({required this.entry, this.quiet = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ai = entry.aiAlignment;
    final nothingDeducted =
        ai != null && ai.deductions.isEmpty && ai.disqualifiers.isEmpty;

    final String message;
    if (ai == null) {
      message = 'Not AI scored yet, and they left every written answer blank. '
          'There is nothing on file to read.';
    } else if (nothingDeducted) {
      message =
          'Scored ${ai.overallScore} with nothing deducted, and every written '
          'answer left blank. There is no narrative on file to judge '
          '${entry.name} on.';
    } else {
      message = 'They left every written answer blank. The itemised scoring '
          'above is all there is to read.';
    }

    if (quiet) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.speaker_notes_off, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text('In their own words: $message',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MoydBrand.qualifiedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MoydBrand.qualifiedFg.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.speaker_notes_off,
              size: 15, color: MoydBrand.qualifiedFg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('NOTHING WRITTEN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: MoydBrand.qualifiedFg)),
                const SizedBox(height: 3),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: MoydBrand.qualifiedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything the candidate wrote, in one scrollable sheet.
///
/// This is where the 2,600 character answers go. A sheet rather than an
/// in-row scroller because a nested scrollable inside an expanded row inside
/// the ballot list fights the exec's thumb and loses their place in the list;
/// a sheet takes the full height, scrolls cleanly, and dismisses back to the
/// exact same row.
Future<void> showCandidateVoiceSheet(
  BuildContext context,
  CandidateEntry entry, {
  String? focusId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CandidateVoiceSheet(entry: entry, focusId: focusId),
  );
}

class _CandidateVoiceSheet extends StatelessWidget {
  final CandidateEntry entry;

  /// When set, that answer is rendered first (the exec tapped "Read in full"
  /// on it, so it is what they came for).
  final String? focusId;

  const _CandidateVoiceSheet({required this.entry, this.focusId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final voice = CandidateVoice.from(entry);
    final ai = entry.aiAlignment;

    final answers = <VoiceAnswer>[...voice.all];
    if (focusId != null) {
      final i = answers.indexWhere((a) => a.id == focusId);
      if (i > 0) answers.insert(0, answers.removeAt(i));
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('In their own words',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          entry.officeLine.isEmpty
                              ? entry.name
                              : '${entry.name} · ${entry.officeLine}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (ai != null) ...[
                    const SizedBox(width: 10),
                    AlignmentBadge(pct: ai.pct, dense: true),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Flexible(
              child: answers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: _NothingWritten(entry: entry),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      itemCount: answers.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: cs.outlineVariant),
                      ),
                      itemBuilder: (_, i) => _SheetAnswer(answer: answers[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet answer: never clamped, since the whole point of the sheet is the
/// full text. Same measure and leading as the in-row version so the reading
/// experience does not change when the exec moves between them.
class _SheetAnswer extends StatelessWidget {
  final VoiceAnswer answer;
  const _SheetAnswer({required this.answer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _measure),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(answer.question.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  height: 1.3,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border:
                  Border(left: BorderSide(color: HubTheme.gold, width: 3)),
            ),
            child: SelectableText(answer.text, style: _bodyStyle(cs)),
          ),
        ],
      ),
    );
  }
}
