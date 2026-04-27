// Build JMAP-typed Email objects from Gmail API JSON returned by our
// edge functions. The mail-message-get edge fn returns the raw Gmail
// REST shape (`{id, threadId, snippet, internalDate, labelIds, payload:
// {headers, body, parts}}`); this builder maps that into an Email type
// shaped enough for tmail's controllers/views to consume.

import 'dart:convert';

import 'package:http_parser/http_parser.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_part.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_value.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';

class JmapEmailBuilder {
  JmapEmailBuilder._();

  static Email fromMailMessageGetJson(Map<String, dynamic> raw) {
    final id = _safeId(raw['id'] as String?);
    final threadIdRaw = _safeId(raw['threadId'] as String?);
    final emailId = id != null ? EmailId(id) : null;
    final threadId = threadIdRaw != null ? ThreadId(threadIdRaw) : null;
    final headers = _headerMap(raw);
    final labels = (raw['labelIds'] as List?)?.cast<String>() ?? const [];
    final internalDateMs = int.tryParse(raw['internalDate']?.toString() ?? '');
    final receivedAt = internalDateMs != null
        ? UTCDate(DateTime.fromMillisecondsSinceEpoch(internalDateMs))
        : null;

    final keywords = <KeyWordIdentifier, bool>{
      if (!labels.contains('UNREAD')) KeyWordIdentifier.emailSeen: true,
      if (labels.contains('STARRED')) KeyWordIdentifier.emailFlagged: true,
    };

    // Walk payload tree; capture text/html and text/plain bodies into
    // separate buckets. Then emit ONLY the preferred bucket into
    // bodyValues — html if present, otherwise text.
    //
    // Why: tmail's `Email.emailContentList` (in email_extension.dart)
    // iterates *all* bodyValues entries when assembling the renderable
    // content, joins them with '</br>', and renders the result. If we
    // emit both the html and the text/plain alternative for the same
    // logical message, the email viewer renders BOTH stacked — the
    // styled html on top and the plain-text duplicate below it.
    //
    // For multipart/alternative messages, RFC 2046 says the receiver
    // should pick the LAST/best part (typically text/html). For
    // multipart/mixed, only the first text body counts as the message
    // body — the rest are usually attachments (which we capture
    // elsewhere via Email.attachments). Either way, "prefer html when
    // both are present" produces the right result.
    final htmlParts = <_BodyCandidate>[];
    final textParts = <_BodyCandidate>[];

    void walk(Map part) {
      final mime = (part['mimeType'] as String?)?.toLowerCase();
      final body = part['body'];
      final data = body is Map ? body['data'] as String? : null;
      if (data != null && data.isNotEmpty) {
        final decoded = _b64urlDecode(data);
        if (mime == 'text/html') {
          htmlParts.add(_BodyCandidate(mime: mime!, value: decoded));
        } else if (mime == 'text/plain') {
          textParts.add(_BodyCandidate(mime: mime!, value: decoded));
        }
      }
      final parts = part['parts'];
      if (parts is List) {
        for (final p in parts) {
          if (p is Map) walk(p);
        }
      }
    }

    final payload = raw['payload'];
    if (payload is Map) walk(payload);

    // Pick exactly ONE body part to render:
    //   - Prefer the LARGEST text/html part. Some emails (forwarded
    //     newsletters, marketing notifications) include multiple text/html
    //     siblings — typically a brief plain-style summary and the styled
    //     full version. If we emit both, tmail's `emailContentList` joins
    //     them with `</br>` and the user sees the email rendered twice.
    //   - If no html part, fall back to the largest text/plain part.
    //   - If neither, emit nothing — the viewer renders an empty body.
    _BodyCandidate? selected;
    if (htmlParts.isNotEmpty) {
      htmlParts.sort((a, b) => b.value.length.compareTo(a.value.length));
      selected = htmlParts.first;
    } else if (textParts.isNotEmpty) {
      textParts.sort((a, b) => b.value.length.compareTo(a.value.length));
      selected = textParts.first;
    }

    final bodyValues = <PartId, EmailBodyValue>{};
    final htmlBodyParts = <EmailBodyPart>{};
    final textBodyParts = <EmailBodyPart>{};
    if (selected != null) {
      final pid = PartId('p0');
      bodyValues[pid] = EmailBodyValue(
        value: selected.value,
        isEncodingProblem: false,
        isTruncated: false,
      );
      final mediaType = _parseMediaType(selected.mime);
      final emailPart = EmailBodyPart(partId: pid, type: mediaType);
      if (selected.mime == 'text/html') {
        htmlBodyParts.add(emailPart);
      } else {
        textBodyParts.add(emailPart);
      }
    }

    return Email(
      id: emailId,
      threadId: threadId,
      subject: headers['subject'],
      preview: raw['snippet'] as String? ?? '',
      receivedAt: receivedAt,
      sentAt: receivedAt,
      from: _parseAddrSet(headers['from']),
      to: _parseAddrSet(headers['to']),
      cc: _parseAddrSet(headers['cc']),
      bcc: _parseAddrSet(headers['bcc']),
      replyTo: _parseAddrSet(headers['reply-to']),
      hasAttachment: labels.contains('HAS_ATTACHMENT'),
      keywords: keywords.isEmpty ? null : keywords,
      htmlBody: htmlBodyParts.isEmpty ? null : htmlBodyParts,
      textBody: textBodyParts.isEmpty ? null : textBodyParts,
      bodyValues: bodyValues.isEmpty ? null : bodyValues,
    );
  }

  static Id? _safeId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Id(raw);
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _headerMap(Map<String, dynamic> raw) {
    final out = <String, String>{};
    final payload = raw['payload'];
    if (payload is Map) {
      final headers = payload['headers'];
      if (headers is List) {
        for (final h in headers) {
          if (h is Map) {
            final name = (h['name'] as String?)?.toLowerCase();
            final value = h['value'] as String?;
            if (name != null && value != null) out[name] = value;
          }
        }
      }
    }
    return out;
  }

  static EmailAddress? _parseAddr(String header) {
    final v = header.trim();
    if (v.isEmpty) return null;
    final ang = RegExp(r'<\s*([^<>\s]+@[^<>\s]+)\s*>').firstMatch(v);
    if (ang != null) {
      final addr = ang.group(1);
      final lt = v.indexOf('<');
      final name =
          lt > 0 ? v.substring(0, lt).replaceAll('"', '').trim() : null;
      return EmailAddress(name?.isNotEmpty == true ? name : null, addr);
    }
    if (RegExp(r'^[^\s<>"]+@[^\s<>"]+$').hasMatch(v)) {
      return EmailAddress(null, v);
    }
    return EmailAddress(v, null);
  }

  static Set<EmailAddress>? _parseAddrSet(String? header) {
    if (header == null || header.isEmpty) return null;
    final addrs = header
        .split(',')
        .map(_parseAddr)
        .whereType<EmailAddress>()
        .toSet();
    return addrs.isEmpty ? null : addrs;
  }

  static String _b64urlDecode(String s) {
    final pad = '=' * ((4 - s.length % 4) % 4);
    final b64 = (s + pad).replaceAll('-', '+').replaceAll('_', '/');
    try {
      // allowMalformed: true so emails sent in Windows-1252 / iso-8859-*
      // (smart quotes, non-breaking space, etc.) don't fail-and-return-empty
      // when their bytes are interpreted as UTF-8. Replacement char (U+FFFD)
      // is fine; rendering empty string instead would lose the entire email.
      return const Utf8Decoder(allowMalformed: true).convert(base64.decode(b64));
    } catch (_) {
      return '';
    }
  }

  static MediaType? _parseMediaType(String? mime) {
    if (mime == null || mime.isEmpty) return null;
    final slash = mime.indexOf('/');
    if (slash <= 0 || slash == mime.length - 1) return null;
    try {
      return MediaType(mime.substring(0, slash), mime.substring(slash + 1));
    } catch (_) {
      return null;
    }
  }
}

class _BodyCandidate {
  final String mime;
  final String value;
  _BodyCandidate({required this.mime, required this.value});
}
