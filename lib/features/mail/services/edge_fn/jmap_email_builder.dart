// Build JMAP-typed Email objects from Gmail API JSON returned by our
// edge functions. The mail-message-get edge fn returns the raw Gmail
// REST shape (`{id, threadId, snippet, internalDate, labelIds, payload:
// {headers, body, parts}}`); this builder maps that into an Email type
// shaped enough for tmail's controllers/views to consume.

import 'dart:convert';

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

    // Walk payload tree; capture text/html and text/plain bodies as
    // EmailBodyPart entries with a synthetic PartId per body. tmail's
    // viewer reads bodyValues[partId].value to render the body.
    final bodyValues = <PartId, EmailBodyValue>{};
    final htmlBodyParts = <EmailBodyPart>{};
    final textBodyParts = <EmailBodyPart>{};
    int partCounter = 0;
    PartId nextPartId() {
      final pid = PartId('p${partCounter++}');
      return pid;
    }

    void walk(Map part) {
      final mime = (part['mimeType'] as String?)?.toLowerCase();
      final body = part['body'];
      final data = body is Map ? body['data'] as String? : null;
      if (data != null && data.isNotEmpty) {
        final decoded = _b64urlDecode(data);
        final pid = nextPartId();
        bodyValues[pid] = EmailBodyValue(
          value: decoded,
          isEncodingProblem: false,
          isTruncated: false,
        );
        final part0 = EmailBodyPart(
          partId: pid,
          type: _toMediaType(mime),
        );
        if (mime == 'text/html') {
          htmlBodyParts.add(part0);
        } else if (mime == 'text/plain') {
          textBodyParts.add(part0);
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
      return utf8.decode(base64.decode(b64));
    } catch (_) {
      return '';
    }
  }

  static dynamic _toMediaType(String? mime) {
    // tmail's EmailBodyPart.type is MediaType from http_parser. Since
    // we don't strictly need the type (tmail's viewer uses partId →
    // bodyValues[partId].value), pass null and let tmail's defaults
    // handle it. The reflection layer accepts dynamic.
    return null;
  }
}
