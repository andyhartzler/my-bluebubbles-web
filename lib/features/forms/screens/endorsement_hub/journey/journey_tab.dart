import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/form_submission.dart';
import '../theme/hub_theme.dart';
import 'journey_models.dart';
import 'journey_timeline_screen.dart';
import 'live_journey_controller.dart';

/// The "Live" tab: every candidate the moment they start the questionnaire,
/// grouped by where they are on the journey, with a pulsing badge for anyone
/// actively filling right now. Tap a card for the full timeline.
class JourneyTab extends StatefulWidget {
  final LiveJourneyController controller;
  final void Function(FormSubmission submission)? onOpenSubmission;

  const JourneyTab({
    super.key,
    required this.controller,
    this.onOpenSubmission,
  });

  @override
  State<JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<JourneyTab> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Relative timestamps ("2m ago") and LIVE decay re-render once a minute.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (c.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.error != null) {
          return HubEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load the journey feed',
            message: c.error!,
            action: FilledButton.icon(
              onPressed: c.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: HubTheme.navy,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }
        if (c.entries.isEmpty) {
          return const HubEmptyState(
            icon: Icons.sensors,
            title: 'No journeys yet',
            message:
                'Candidates appear here the moment they enter their phone '
                'number on the questionnaire, before they even finish.',
          );
        }

        final now = DateTime.now();
        final groups = <JourneyStatus, List<JourneyEntry>>{};
        for (final e in c.entries) {
          groups.putIfAbsent(e.statusAt(now), () => []).add(e);
        }
        const order = [
          JourneyStatus.liveNow,
          JourneyStatus.inProgress,
          JourneyStatus.completed,
          JourneyStatus.openedOnly,
        ];

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final status in order)
              if (groups[status]?.isNotEmpty ?? false) ...[
                _sectionHeader(context, status, groups[status]!.length),
                for (final e in groups[status]!)
                  _JourneyCard(
                    entry: e,
                    status: status,
                    onTap: () => _openTimeline(e),
                  ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  void _openTimeline(JourneyEntry entry) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JourneyTimelineScreen(
        entry: entry,
        onOpenSubmission: widget.onOpenSubmission,
      ),
    ));
  }

  Widget _sectionHeader(BuildContext context, JourneyStatus status, int n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Row(
        children: [
          if (status == JourneyStatus.liveNow)
            const _LivePulse(size: 10)
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '${status.label.toUpperCase()} ($n)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final JourneyEntry entry;
  final JourneyStatus status;
  final VoidCallback onTap;

  const _JourneyCard({
    required this.entry,
    required this.status,
    required this.onTap,
  });

  static const int _policyTotal = 17;
  static const int _pageTotal = 13;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = entry.submission;
    final name = s.displayName;
    final progress =
        (entry.policyAnswers / _policyTotal).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: status == JourneyStatus.liveNow
                    ? status.color.withOpacity(0.55)
                    : cs.outlineVariant.withOpacity(0.6),
                width: status == JourneyStatus.liveNow ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                _avatar(name, cs),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          _statusChip(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    entry.trulyFinished ? 1.0 : progress,
                                minHeight: 6,
                                backgroundColor:
                                    cs.outlineVariant.withOpacity(0.35),
                                valueColor: AlwaysStoppedAnimation(
                                    entry.trulyFinished
                                        ? JourneyStatus.completed.color
                                        : status.color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            entry.trulyFinished
                                ? 'Done'
                                : '${entry.policyAnswers}/$_policyTotal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (!entry.trulyFinished && entry.draftPage != null) {
      parts.add('page ${entry.draftPage} of $_pageTotal');
    }
    parts.add('active ${_relative(entry.lastActivity)}');
    return parts.join(' | ');
  }

  Widget _avatar(String name, ColorScheme cs) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        gradient: HubTheme.hero,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == JourneyStatus.liveNow) ...[
            const _LivePulse(size: 7),
            const SizedBox(width: 5),
          ],
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

String _relative(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.toLocal().month}/${t.toLocal().day}';
}

/// A small pulsing green dot for LIVE rows.
class _LivePulse extends StatefulWidget {
  final double size;
  const _LivePulse({required this.size});

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
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
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: JourneyStatus.liveNow.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
