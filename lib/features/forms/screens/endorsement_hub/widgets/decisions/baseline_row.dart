import 'package:flutter/material.dart';

import '../../decision_attribution_repository.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'attribution_sheet.dart';
import 'decision_chip.dart';
import 'decision_repository.dart';

/// "Locked baseline": the decisions the committee already made, read-only.
/// Nothing in the vote path can mutate these; a chair Confirm (elsewhere)
/// is the only way a candidate ever moves in here tonight.
///
/// [entries] is the (possibly search-filtered) list to render; [totalCount]
/// is the full decided count so the header can read "X of Y decided" while a
/// search query is narrowing the section.
///
/// ATTRIBUTION. These decisions came out of the 2026-07-14 Zoom call, they
/// were typed in the next morning from the recording, and the table only
/// records a typist. The [attribution] repository supplies the derived
/// who-was-in-the-room data; while it has nothing for a row (migration
/// unapplied, load failed, or a decision locked outside any attributed
/// meeting) that row renders exactly as it did before this feature: no
/// attribution line, no error, no empty placeholder. The header likewise keeps
/// its old subtitle until real meeting data exists to quote.
///
/// THE HEADER MAY NOT CLAIM AGREEMENT. An earlier version read "Decided by the
/// Executive Committee", and the sheet behind it claimed consensus. FOUR of the
/// 23 decisions have a record running against them: two contradicted by the
/// meeting's own recording (Hans Peter, Kemp Strickler) and two contradicted by
/// later individual ballots in public.endorsement_votes (Tara Childress Lopez
/// Hallmark and Don Crozier, both stored decline, both voted yes by the only
/// two execs who have ever recorded a position on them). So the header states
/// provenance only ("From the Jul 14 meeting") and surfaces the contested count
/// instead of averaging it away. The count comes from
/// v_endorsement_decision_meeting.decisions_contested, which is the union of
/// both axes, so it is 4 here and moves on its own if anyone votes again.
class BaselineSection extends StatefulWidget {
  final List<CandidateEntry> entries;
  final int totalCount;
  final bool expanded;
  final VoidCallback onToggle;
  final DecisionState Function(String candidateId) stateFor;

  /// Full record lookup (note + write metadata) for the attribution sheet's
  /// hedged "How this was entered" block. `repository.recordFor` upstream.
  final DecisionRecord Function(String candidateId) recordFor;
  final void Function(CandidateEntry) onOpen;
  final DecisionAttributionRepository attribution;

  /// Name coalesce (SlateController.displayNameFor). One decided submission
  /// (587c32d7, Hope Tinker) carries no name in its own data, so a raw
  /// `entry.name` here could render a nameless locked row. Optional so the
  /// widget still works standalone; falls back to `entry.name`.
  final String Function(CandidateEntry)? displayNameFor;

  const BaselineSection({
    super.key,
    required this.entries,
    required this.totalCount,
    required this.expanded,
    required this.onToggle,
    required this.stateFor,
    required this.recordFor,
    required this.onOpen,
    required this.attribution,
    this.displayNameFor,
  });

  @override
  State<BaselineSection> createState() => _BaselineSectionState();
}

class _BaselineSectionState extends State<BaselineSection> {
  @override
  void initState() {
    super.initState();
    // One-shot, shared across every mount; a no-op after the first load.
    widget.attribution.ensureLoaded();
  }

  String _nameFor(CandidateEntry e) {
    final n = (widget.displayNameFor?.call(e) ?? e.name).trim();
    return n.isEmpty ? 'Name not provided' : n;
  }

  /// The single meeting behind the decided rows, for the header subtitle.
  /// Quoted ONLY when every attributed entry points at the same meeting; a
  /// future mixed baseline (two meetings, or meeting rows plus app-locked
  /// rows) falls back to the generic subtitle and lets the per-row lines
  /// carry the per-candidate claim, so the header never overstates.
  MeetingAttribution? _headerMeeting() {
    MeetingAttribution? found;
    var attributed = 0;
    for (final e in widget.entries) {
      final att = widget.attribution.attributionFor(e.id);
      if (att == null) continue;
      attributed++;
      if (found == null) {
        found = att.meeting;
      } else if (found.meetingId != att.meeting.meetingId) {
        return null;
      }
    }
    // Require full coverage of the visible decided rows: "Decided by the
    // Executive Committee" over a list containing unattributed rows would
    // claim more than the data does.
    if (found == null || attributed != widget.entries.length) return null;
    return found;
  }

  void _showSheet(CandidateEntry e, CandidateAttribution att) {
    showAttributionSheet(
      context,
      entry: e,
      displayName: _nameFor(e),
      record: widget.recordFor(e.id),
      attribution: att,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: widget.attribution,
      builder: (context, _) {
        final filtered = widget.entries.length != widget.totalCount;
        final meeting = _headerMeeting();
        // Provenance, not agreement. "From the <date> meeting" is true of all
        // 23 rows; "decided by the Executive Committee" is not true of the two
        // the recording contradicts, and the contested count says so rather
        // than hiding inside an average.
        final subtitle = meeting == null
            ? 'Shared decisions already made, read-only'
            : [
                'From the ${meeting.dateLabel} meeting',
                if (meeting.presenceLine != null) meeting.presenceLine!,
                if (meeting.contestedLine != null) meeting.contestedLine!,
              ].join(' · ');
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
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Expanded(
                      child: HubCardHeader(
                        icon: Icons.lock_clock,
                        title: filtered
                            ? 'Locked baseline · ${widget.entries.length} of '
                                '${widget.totalCount} decided'
                            : 'Locked baseline · ${widget.totalCount} decided',
                        subtitle: subtitle,
                        tileGradient: HubTheme.gradAmber,
                      ),
                    ),
                    Icon(
                      widget.expanded ? Icons.expand_less : Icons.expand_more,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: widget.expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                // Collapsed: an overlapping face strip keeps the tab's
                // faces-first identity visible at near-zero vertical cost while
                // the baseline is locked shut; expansion swaps it for the rows.
                firstChild: _FaceStrip(
                    entries: widget.entries, totalCount: widget.totalCount),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LayoutBuilder(builder: (context, constraints) {
                    // Same phone breakpoint as the face strip and the board.
                    final narrow = constraints.maxWidth < 720;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in widget.entries)
                          BaselineRow(
                            entry: e,
                            displayName: _nameFor(e),
                            state: widget.stateFor(e.id),
                            attribution:
                                widget.attribution.attributionFor(e.id),
                            narrow: narrow,
                            onOpen: () => widget.onOpen(e),
                            onShowAttribution: () {
                              final att =
                                  widget.attribution.attributionFor(e.id);
                              if (att != null) _showSheet(e, att);
                            },
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Collapsed-state face strip: the first few decided candidates as small
/// overlapping headshots plus a "+K" pill for the rest. Purely decorative
/// recognition; opening the section is still the only way to read names.
class _FaceStrip extends StatelessWidget {
  final List<CandidateEntry> entries;
  final int totalCount;
  const _FaceStrip({required this.entries, required this.totalCount});

  // 28px avatars overlapped by 10px.
  static const double _face = 28;
  static const double _step = 18;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox(width: double.infinity);
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: LayoutBuilder(builder: (context, constraints) {
          final maxFaces = constraints.maxWidth < 720 ? 6 : 8;
          final shown = entries.take(maxFaces).toList();
          final extra = totalCount - shown.length;
          return Row(
            children: [
              SizedBox(
                width: _face + (shown.length - 1) * _step,
                height: _face,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * _step,
                        child: HeadshotAvatar(
                          file: shown[i].headshot,
                          name: shown[i].name,
                          size: _face,
                        ),
                      ),
                  ],
                ),
              ),
              if (extra > 0) ...[
                const SizedBox(width: 8),
                HubCountPill(text: '+$extra'),
              ],
            ],
          );
        }),
      ),
    );
  }
}

/// One locked, already-decided candidate: compact identity + the shared
/// decision chip + a lock glyph. No vote controls, no tally, no final call.
///
/// When [attribution] is non-null a third identity line appears under the
/// office line, reporting what is on record about THIS decision: `Decided out
/// loud · Jul 14`, `Reason stated, outcome not · Jul 14`, or, on the four rows
/// something on record runs against, the theme's error color with a warning
/// glyph. Those four do not all carry the same label, because they are not the
/// same fact: the two the recording contradicts read `The room wanted the
/// opposite` / `Transcript does not support this`, and the two contradicted
/// only by later ballots read `2 execs later voted the other way`. The line is
/// tappable to open the provenance sheet. Null attribution renders the
/// pre-feature two-line row untouched.
///
/// The error color comes from [ColorScheme.error] rather than a fixed brand
/// red, because this line sits on `cs.surface` and has to hold in both light
/// and dark theme; a self-contained Fg-on-Bg pair is only used inside the
/// sheet, which paints its own navy.
class BaselineRow extends StatelessWidget {
  final CandidateEntry entry;

  /// Coalesced display name; falls back to [CandidateEntry.name] upstream.
  final String displayName;
  final DecisionState state;
  final CandidateAttribution? attribution;
  final bool narrow;
  final VoidCallback onOpen;
  final VoidCallback onShowAttribution;
  const BaselineRow({
    super.key,
    required this.entry,
    required this.displayName,
    required this.state,
    required this.attribution,
    required this.narrow,
    required this.onOpen,
    required this.onShowAttribution,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final att = attribution;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: 0.92,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              HeadshotAvatar(file: entry.headshot, name: displayName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName,
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
                    if (att != null)
                      // Attribution line, matching the office line's muted
                      // treatment except on a contested row, where it takes
                      // the theme error color and a warning glyph so the two
                      // decisions the recording contradicts are visible
                      // without opening anything. Its own InkWell (nested taps
                      // resolve to the innermost target) so the row-open tap
                      // survives around it. The glyph and the text share one
                      // target.
                      _AttributionLine(
                        attribution: att,
                        narrow: narrow,
                        onTap: onShowAttribution,
                      ),
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

/// The third identity line on a locked row: what the meeting recording
/// supports about this specific decision, tappable to open the full evidence.
///
/// Deliberately NOT a single muted style for every row. A decision the room
/// stated out loud and a decision the room argued against are different facts
/// and must not look identical at a glance, which is exactly the mistake the
/// earlier "Committee consensus" line made on all 23 rows at once.
///
/// Colors come from [ColorScheme] so the line is legible in both themes: it
/// sits on `cs.surface`, whose value differs between light and dark, so a
/// fixed brand red would fail one of them.
class _AttributionLine extends StatelessWidget {
  final CandidateAttribution attribution;
  final bool narrow;
  final VoidCallback onTap;

  const _AttributionLine({
    required this.attribution,
    required this.narrow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final basis = attribution.basis;
    // The UNION of both contradiction axes, not basis.contested. Gating on the
    // basis flag alone left Tara Childress Lopez Hallmark and Don Crozier
    // rendering in neutral grey as ordinary rows, when the app's own vote table
    // records two execs voting against both.
    final contested = attribution.contested;

    final color = contested ? cs.error : cs.onSurfaceVariant;
    final icon = contested
        ? Icons.report_problem_outlined
        : basis.outcomeUnspoken
            ? Icons.help_outline
            : Icons.groups;

    // basisLabel, not basis.short: a row contested only by later ballots says
    // so, instead of showing "Reason stated, outcome not" in warning red with
    // no indication of what the warning is about.
    final short = attribution.basisLabel;

    // On a contested row the label already carries the whole point, so the
    // date is dropped on narrow rather than truncating the warning.
    final date = attribution.meeting.shortDateLabel;
    final label = contested && narrow
        ? short
        : narrow
            ? '$short · $date'
            : '$short · $date meeting';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: contested ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
