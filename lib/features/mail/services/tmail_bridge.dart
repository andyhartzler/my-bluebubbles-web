// Bridge between our MailMessage model + edge functions and tmail-flutter's
// PresentationEmail / PresentationMailbox / SelectMode types.
//
// Phase 1 just needs enough field coverage that EmailTileBuilder /
// EmailTileWebBuilder can render: from, to, cc, subject, preview, dates,
// keywords (UNREAD), threadId. Everything else stays null.

import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/responsive_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/select_mode.dart';
import 'package:bluebubbles/features/mail/models/mail_message.dart';

/// Initialize the GetX deps tmail's leaf widgets need at runtime
/// (ImagePaths + ResponsiveUtils, accessed via Get.find inside the
/// BaseEmailItemTile mixin). Idempotent — safe to call from multiple
/// MailScreen mounts.
void ensureTmailGetXBindings() {
  if (!Get.isRegistered<ImagePaths>()) {
    Get.put<ImagePaths>(ImagePaths(), permanent: true);
  }
  if (!Get.isRegistered<ResponsiveUtils>()) {
    Get.put<ResponsiveUtils>(ResponsiveUtils(), permanent: true);
  }
}

/// Convert our edge-function MailMessage into a JMAP-typed PresentationEmail
/// that EmailTileBuilder can consume. Most fields are stubbed to null —
/// our edge fns return only the subset Phase 1 needs.
PresentationEmail toPresentationEmail(MailMessage m) {
  Id? safeId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Id() validates against [a-zA-Z0-9][a-zA-Z0-9-_]*. Gmail message IDs
    // are hex/base64-like and typically pass; if not, fall through to null.
    try {
      return Id(raw);
    } catch (_) {
      return null;
    }
  }

  EmailAddress? parseAddr(String header) {
    final v = header.trim();
    if (v.isEmpty) return null;
    final ang = RegExp(r'<\s*([^<>\s]+@[^<>\s]+)\s*>').firstMatch(v);
    if (ang != null) {
      final addr = ang.group(1);
      final lt = v.indexOf('<');
      final name = lt > 0
          ? v.substring(0, lt).replaceAll('"', '').trim()
          : null;
      return EmailAddress(name?.isNotEmpty == true ? name : null, addr);
    }
    if (RegExp(r'^[^\s<>"]+@[^\s<>"]+$').hasMatch(v)) {
      return EmailAddress(null, v);
    }
    return EmailAddress(v, null);
  }

  Set<EmailAddress>? parseAddrSetFromList(List<String> entries) {
    final addrs = entries
        .map(parseAddr)
        .whereType<EmailAddress>()
        .toSet();
    return addrs.isEmpty ? null : addrs;
  }

  final emailIdId = safeId(m.id);
  final threadIdId = safeId(m.threadId);

  // Tmail uses keywords[KeyWordIdentifier.emailSeen] = true for read.
  final keywords = <KeyWordIdentifier, bool>{
    if (!m.isUnread) KeyWordIdentifier.emailSeen: true,
    if (m.labels.contains('FLAGGED')) KeyWordIdentifier.emailFlagged: true,
    if (m.labels.contains('IMPORTANT')) KeyWordIdentifier.emailFlagged: true,
  };

  return PresentationEmail(
    id: emailIdId != null ? EmailId(emailIdId) : null,
    threadId: threadIdId != null ? ThreadId(threadIdId) : null,
    subject: m.subject,
    preview: m.snippet,
    receivedAt: UTCDate(m.internalDate),
    sentAt: UTCDate(m.internalDate),
    from: m.from.isNotEmpty
        ? {if (parseAddr(m.from) case final a?) a}
        : null,
    to: parseAddrSetFromList(m.to),
    cc: parseAddrSetFromList(m.cc),
    keywords: keywords.isEmpty ? null : keywords,
    hasAttachment: m.labels.contains('HAS_ATTACHMENT'),
    selectMode: SelectMode.INACTIVE,
  );
}
