import 'package:flutter/material.dart';

import '../../../models/form_submission.dart';
import '../theme/hub_theme.dart';
import 'journey_models.dart';
import 'journey_service.dart';

/// One candidate's full journey through the questionnaire: when they opened
/// it (and on what device), entered their phone, each block of answering,
/// stalls, abandons, resumes, the submit, and the thank-you email.
class JourneyTimelineScreen extends StatefulWidget {
  final JourneyEntry entry;
  final void Function(FormSubmission submission)? onOpenSubmission;

  const JourneyTimelineScreen({
    super.key,
    required this.entry,
    this.onOpenSubmission,
  });

  @override
  State<JourneyTimelineScreen> createState() => _JourneyTimelineScreenState();
}

class _JourneyTimelineScreenState extends State<JourneyTimelineScreen> {
  final JourneyService _service = JourneyService();
  List<JourneyEvent>? _events;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await _service.loadTimeline(widget.entry);
      if (mounted) setState(() => _events = events);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.entry.submission;
    final status = widget.entry.statusAt(DateTime.now());

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(s.displayName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: HubTheme.navy,
        foregroundColor: Colors.white,
        actions: [
          if (widget.onOpenSubmission != null && widget.entry.trulyFinished)
            IconButton(
              tooltip: 'Open full submission',
              icon: const Icon(Icons.description_outlined),
              onPressed: () => widget.onOpenSubmission!(s),
            ),
        ],
      ),
      body: Column(
        children: [
          _header(cs, status),
          Expanded(child: _body(cs)),
        ],
      ),
    );
  }

  Widget _header(ColorScheme cs, JourneyStatus status) {
    final e = widget.entry;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(gradient: HubTheme.hero),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _pill(status.label, status.color),
          _pill('${e.policyAnswers} of 17 policy answers', HubTheme.gold),
          if (e.draftPage != null && !e.trulyFinished)
            _pill('page ${e.draftPage} of 13', HubTheme.gold),
          _pill('last active ${_fmtFull(e.lastActivity)}', Colors.white70),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the timeline.\n$_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    final events = _events;
    if (events == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
      return Center(
        child: Text('No recorded events for this journey yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: events.length,
      itemBuilder: (context, i) => _timelineRow(
        cs,
        events[i],
        isFirst: i == 0,
        isLast: i == events.length - 1,
        prev: i > 0 ? events[i - 1] : null,
      ),
    );
  }

  Widget _timelineRow(ColorScheme cs, JourneyEvent e,
      {required bool isFirst, required bool isLast, JourneyEvent? prev}) {
    // Show a "gap" note when more than an hour passed between moments.
    final gap = prev != null ? e.time.difference(prev.endTime ?? prev.time) : null;
    final showGap = gap != null && gap > const Duration(hours: 1);

    final accent = switch (e.kind) {
      JourneyEventKind.submitted => JourneyStatus.completed.color,
      JourneyEventKind.thankYouSent => JourneyStatus.completed.color,
      JourneyEventKind.abandoned => JourneyStatus.stalled.color,
      JourneyEventKind.resumed => JourneyStatus.liveNow.color,
      _ => HubTheme.royal,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGap)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 2, bottom: 2),
            child: Text(
              'quiet for ${_fmtGap(gap)}',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 8,
                      color: isFirst
                          ? Colors.transparent
                          : cs.outlineVariant.withOpacity(0.7),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withOpacity(0.6)),
                      ),
                      child: Icon(e.kind.icon, size: 15, color: accent),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : cs.outlineVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeLabel(e),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (e.detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          e.detail!,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _timeLabel(JourneyEvent e) {
    final start = _fmtFull(e.time);
    if (e.endTime == null || e.endTime == e.time) return start;
    final mins = e.endTime!.difference(e.time).inMinutes;
    return '$start${mins > 0 ? ' (over ${mins}m)' : ''}';
  }
}

String _fmtFull(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final ampm = l.hour < 12 ? 'am' : 'pm';
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.month}/${l.day} $h:$mm$ampm';
}

String _fmtGap(Duration d) {
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inHours < 48) return '${d.inHours}h';
  return '${d.inDays} days';
}
