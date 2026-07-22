import 'package:flutter/material.dart';

import '../../../models/form_submission.dart';

/// Where a candidate is in their questionnaire journey right now.
enum JourneyStatus {
  /// Actively filling: activity within the last few minutes.
  liveNow('LIVE', Color(0xFF16A34A)),

  /// Started, real answers saved, activity within the last day.
  inProgress('In progress', Color(0xFF2563EB)),

  /// No longer produced by [JourneyEntry.statusAt]: long-idle journeys now
  /// count as completed (the mobile false-abandon bug ended sessions through
  /// no fault of the candidate). Kept only for the abandoned-event color on
  /// the timeline.
  stalled('Stalled', Color(0xFFD97706)),

  /// Certified and signed: a finished questionnaire.
  completed('Completed', Color(0xFF7C3AED)),

  /// Opened the form (phone entered) but never answered anything.
  openedOnly('Opened only', Color(0xFF6B7280));

  const JourneyStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// The window after the last save inside which a candidate counts as LIVE.
const Duration kLiveWindow = Duration(minutes: 3);

/// One candidate's questionnaire journey (deduped per person: the best
/// submission row for their phone, enriched with their autosave draft).
class JourneyEntry {
  final FormSubmission submission;

  /// Page reached in the form_drafts autosave (1-based), if a draft exists.
  final int? draftPage;

  /// Last-activity timestamp on the draft autosave, if a draft exists.
  final DateTime? draftUpdatedAt;

  /// Count of answered policy (pos_*) questions across submission + draft.
  final int policyAnswers;

  /// Count of all non-empty answered keys across submission + draft.
  final int totalAnswers;

  /// certify + signature both present: a truly finished response.
  final bool trulyFinished;

  const JourneyEntry({
    required this.submission,
    this.draftPage,
    this.draftUpdatedAt,
    required this.policyAnswers,
    required this.totalAnswers,
    required this.trulyFinished,
  });

  /// Best-known last activity: the newer of the submission row and the draft.
  DateTime get lastActivity {
    final s = submission.updatedAt ?? submission.createdAt;
    final d = draftUpdatedAt;
    if (d == null) return s;
    return d.isAfter(s) ? d : s;
  }

  JourneyStatus statusAt(DateTime now) {
    if (trulyFinished) return JourneyStatus.completed;
    if (policyAnswers == 0 && totalAnswers <= 4) return JourneyStatus.openedOnly;
    final idle = now.difference(lastActivity);
    if (idle <= kLiveWindow) return JourneyStatus.liveNow;
    if (idle <= const Duration(hours: 24)) return JourneyStatus.inProgress;
    // Idle for over a day: treat as completed rather than stalled. Sessions
    // were ended by our mobile visibilitychange bug, not the candidates.
    return JourneyStatus.completed;
  }
}

/// Kinds of moments on a candidate's journey timeline.
enum JourneyEventKind {
  view(Icons.visibility_outlined, 'Opened the form'),
  phoneEntered(Icons.phone_iphone, 'Entered phone number'),
  identityFound(Icons.person_search, 'Identity recognized'),
  fieldsAnswered(Icons.edit_note, 'Answered questions'),
  abandoned(Icons.pause_circle_outline, 'Marked abandoned'),
  resumed(Icons.play_circle_outline, 'Resumed'),
  submitted(Icons.task_alt, 'Submitted'),
  thankYouSent(Icons.mark_email_read_outlined, 'Thank-you email sent');

  const JourneyEventKind(this.icon, this.defaultTitle);
  final IconData icon;
  final String defaultTitle;
}

/// One moment on the timeline. [endTime] is set for grouped field-answer
/// blocks ("answered 12 questions over 9 minutes").
class JourneyEvent {
  final DateTime time;
  final DateTime? endTime;
  final JourneyEventKind kind;
  final String title;
  final String? detail;

  const JourneyEvent({
    required this.time,
    this.endTime,
    required this.kind,
    required this.title,
    this.detail,
  });
}
