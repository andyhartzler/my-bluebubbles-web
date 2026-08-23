import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/meeting_commitment.dart';
import 'package:bluebubbles/services/crm/meeting_commitment_repository.dart';

/// The commitments a meeting produced, as a list somebody can work.
///
/// This sits above the narrative sections on the meeting detail screen. The
/// `Action Items` paragraph is still rendered below it and is still the
/// model's own words; this panel is the part that has owners, statuses and a
/// due date, and it is the part that can be wrong in a way somebody notices.
class MeetingCommitmentsPanel extends StatefulWidget {
  const MeetingCommitmentsPanel({
    Key? key,
    required this.meetingId,
    this.showCoverage = true,
  }) : super(key: key);

  final String meetingId;

  /// Region coverage is a whole-organisation view rather than a property of
  /// one meeting, so it is only worth drawing on a meeting that actually
  /// assigned regions.
  final bool showCoverage;

  @override
  State<MeetingCommitmentsPanel> createState() =>
      _MeetingCommitmentsPanelState();
}

class _MeetingCommitmentsPanelState extends State<MeetingCommitmentsPanel> {
  final MeetingCommitmentRepository _repository = MeetingCommitmentRepository();

  List<MeetingCommitment> _commitments = const [];
  List<RegionCoverage> _coverage = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final commitments = await _repository.getForMeeting(widget.meetingId);
    final hasRegions =
        commitments.any((c) => c.kind == CommitmentKind.region);
    final coverage = (widget.showCoverage && hasRegions)
        ? await _repository.getRegionCoverage()
        : const <RegionCoverage>[];
    if (!mounted) return;
    setState(() {
      _commitments = commitments;
      _coverage = coverage;
      _loading = false;
    });
  }

  Future<void> _saveProgress(
    MeetingCommitment commitment,
    CommitmentStatus status,
    String? note,
  ) async {
    try {
      final saved = await _repository.saveProgress(
        commitment.id,
        status: status,
        progressNote: note,
      );
      if (!mounted || saved == null) return;
      setState(() {
        _commitments = _commitments
            .map((c) => c.id == saved.id ? saved : c)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Nothing was changed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_commitments.isEmpty) {
      return const SizedBox.shrink();
    }

    final open = _commitments.where((c) => !c.status.isClosed).length;
    final overdue = _commitments.where((c) => c.isOverdue).length;
    final unconfirmed =
        _commitments.where((c) => c.needsConfirmation && !c.status.isClosed).length;

    final sections = <Widget>[];
    for (final kind in CommitmentKind.values) {
      final items = _commitments.where((c) => c.kind == kind).toList();
      if (items.isEmpty) continue;
      sections
        ..add(const SizedBox(height: 20))
        ..add(Text(
          kind.heading,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: theme.colorScheme.onSurface.withOpacity(0.72),
          ),
        ));
      for (final item in items) {
        sections
          ..add(const SizedBox(height: 10))
          ..add(_CommitmentTile(
            commitment: item,
            onSave: (status, note) => _saveProgress(item, status, note),
          ));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rtl,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Commitments',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _summaryLine(open, overdue, unconfirmed),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            ...sections,
            if (_coverage.isNotEmpty) ...[
              const SizedBox(height: 24),
              _CoverageSummary(coverage: _coverage),
            ],
          ],
          ),
        ),
      ),
    );
  }

  String _summaryLine(int open, int overdue, int unconfirmed) {
    final parts = <String>['$open still open'];
    if (overdue > 0) parts.add('$overdue past its date');
    if (unconfirmed > 0) parts.add('$unconfirmed never confirmed by the owner');
    return '${parts.join(' · ')}. Status and notes here are yours; nothing '
        'automated overwrites them.';
  }
}

class _CommitmentTile extends StatefulWidget {
  const _CommitmentTile({
    Key? key,
    required this.commitment,
    required this.onSave,
  }) : super(key: key);

  final MeetingCommitment commitment;
  final Future<void> Function(CommitmentStatus status, String? note) onSave;

  @override
  State<_CommitmentTile> createState() => _CommitmentTileState();
}

class _CommitmentTileState extends State<_CommitmentTile> {
  late TextEditingController _noteController;
  late CommitmentStatus _status;
  bool _expanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.commitment.status;
    _noteController =
        TextEditingController(text: widget.commitment.progressNote ?? '');
  }

  @override
  void didUpdateWidget(covariant _CommitmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only follow the incoming row when this tile is closed. Adopting a new
    // value while somebody is mid-sentence in the note field would throw away
    // what they are typing, which is the same class of mistake as letting
    // automation overwrite it.
    if (!_expanded && widget.commitment.id != oldWidget.commitment.id) {
      _status = widget.commitment.status;
      _noteController.text = widget.commitment.progressNote ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Color _statusColor(ThemeData theme) {
    switch (_status) {
      case CommitmentStatus.done:
        return const Color(0xFF1B7F4B);
      case CommitmentStatus.inProgress:
        return const Color(0xFF0B4DB8);
      case CommitmentStatus.deferred:
      case CommitmentStatus.dropped:
        return theme.colorScheme.onSurface.withOpacity(0.55);
      case CommitmentStatus.open:
        return const Color(0xFF9A5B00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.commitment;
    final statusColor = _statusColor(theme);
    final overdue = c.isOverdue;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overdue
              ? theme.colorScheme.error.withOpacity(0.55)
              : theme.colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _Pill(
                              label: _status.label,
                              color: statusColor,
                              filled: true,
                            ),
                            Text(
                              c.isUnowned ? 'Nobody' : c.ownerLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.isUnowned
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            if (c.needsConfirmation)
                              _Pill(
                                label: 'not confirmed by owner',
                                color: const Color(0xFF9A5B00),
                              ),
                            for (final county in c.counties)
                              _Pill(
                                label: county,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.commitment,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (c.dueOn != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            overdue
                                ? 'Was due ${_formatDate(c.dueOn!)} and nothing has been recorded against it'
                                : 'Due ${_formatDate(c.dueOn!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: overdue
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                              fontWeight:
                                  overdue ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                        if (!_expanded && (c.progressNote ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            c.progressNote!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((c.evidence ?? '').isNotEmpty) ...[
                    Text(
                      'Why this is here',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.evidence!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in CommitmentStatus.values)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: _status == option,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _status = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 5,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      helperText:
                          'Yours. No import or re-run of the summariser can change it.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _status = c.status;
                                  _noteController.text = c.progressNote ?? '';
                                  _expanded = false;
                                }),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                await widget.onSave(
                                    _status, _noteController.text);
                                if (!mounted) return;
                                setState(() {
                                  _saving = false;
                                  _expanded = false;
                                });
                              },
                        child: Text(_saving ? 'Saving…' : 'Save'),
                      ),
                    ],
                  ),
                  if (c.statusSetAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last set by a person on ${_formatDate(c.statusSetAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Counties MOYD has members in, against who took them.
class _CoverageSummary extends StatelessWidget {
  const _CoverageSummary({Key? key, required this.coverage}) : super(key: key);

  final List<RegionCoverage> coverage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owned = coverage.where((c) => c.hasOwner).toList();
    final gaps = coverage.where((c) => !c.hasOwner).toList();
    final covered =
        owned.fold<int>(0, (sum, c) => sum + c.memberCount);
    final uncovered =
        gaps.fold<int>(0, (sum, c) => sum + c.memberCount);
    final topGaps = gaps.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What that leaves uncovered',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '$covered members sit in the ${owned.length} counties somebody took. '
            '$uncovered sit in the ${gaps.length} counties nobody did.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Biggest gaps',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final gap in topGaps)
                _Pill(
                  label: '${gap.county} · ${gap.memberCount}',
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          if (owned.any((c) => c.anyUnconfirmed)) ...[
            const SizedBox(height: 12),
            Text(
              'Counties whose owner has not confirmed: '
              '${owned.where((c) => c.anyUnconfirmed).map((c) => c.county).join(', ')}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    Key? key,
    required this.label,
    required this.color,
    this.filled = false,
  }) : super(key: key);

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // Text is always drawn in `color` on a heavily tinted-down background of
    // the same hue, so contrast holds in both the light and dark theme without
    // hard-coding a surface colour.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(filled ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
