import 'package:flutter/foundation.dart';

/// Which bulk screen produced a result. The Desk writes this straight to
/// `outreach_touchpoints.channel`.
enum BulkSendChannel { sms, email }

/// What a bulk screen actually did, handed back through `Navigator.pop` so the
/// caller never has to guess.
///
/// A screen that is closed without sending pops null. That distinction is the
/// whole point of this type: the old flow prompted "save this?" on the way out
/// and so fired on abandoned sends as readily as on real ones.
///
/// The two channels fail differently and this record does not pretend
/// otherwise. SMS is sent one recipient at a time and reports per recipient, so
/// a send can be genuinely partial. Email is one batched call for the whole
/// list, so it either went or it threw. `partial` is therefore unreachable for
/// email, by construction rather than by convention.
@immutable
class BulkSendResult {
  /// SMS. [results] is the per-member map `CRMMessageService.sendBulkMessages`
  /// already returns, keyed by member id.
  BulkSendResult.sms(Map<String, bool> results)
      : channel = BulkSendChannel.sms,
        recipientMemberIds = List<String>.unmodifiable(results.keys),
        failedMemberIds = List<String>.unmodifiable(
          results.entries.where((e) => !e.value).map((e) => e.key),
        ),
        errorDetail = null;

  /// Email that the provider accepted for the whole batch.
  BulkSendResult.email(Iterable<String> recipientMemberIds)
      : channel = BulkSendChannel.email,
        recipientMemberIds = List<String>.unmodifiable(recipientMemberIds),
        failedMemberIds = const [],
        errorDetail = null;

  /// Email that threw. Nothing went out, so every recipient counts as failed.
  BulkSendResult.emailFailed(Iterable<String> recipientMemberIds, String message)
      : channel = BulkSendChannel.email,
        recipientMemberIds = List<String>.unmodifiable(recipientMemberIds),
        failedMemberIds = List<String>.unmodifiable(recipientMemberIds),
        // The column this lands in is bounded, and a provider stack trace can
        // run for pages.
        errorDetail =
            message.length > 500 ? message.substring(0, 500) : message;

  final BulkSendChannel channel;

  /// Everyone the send was attempted against, member ids.
  final List<String> recipientMemberIds;

  /// The subset that did not get it. Empty on a clean send.
  final List<String> failedMemberIds;

  /// Present only on an email failure: the `CRMEmailException` message.
  final String? errorDetail;

  int get attemptedCount => recipientMemberIds.length;

  int get deliveredCount => attemptedCount - failedMemberIds.length;

  /// The `outreach_touchpoints.status` value this outcome writes.
  String get status {
    if (failedMemberIds.isEmpty) return 'sent';
    if (failedMemberIds.length >= attemptedCount) return 'failed';
    return 'partial';
  }
}
