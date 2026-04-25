import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/mail/models/mail_message.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class MailListPage {
  final List<MailMessage> messages;
  final String? nextPageToken;
  const MailListPage({required this.messages, this.nextPageToken});
}

class MailApiClient {
  MailApiClient({CRMSupabaseService? supabase})
    : _supabase = supabase ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  Future<MailListPage> listInbox({
    int maxResults = 25,
    String? pageToken,
    String? q,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-list',
      body: {
        'maxResults': maxResults,
        if (pageToken != null) 'pageToken': pageToken,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? {};
    final messages = ((data['messages'] as List?) ?? const [])
        .map((m) => MailMessage.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    return MailListPage(
      messages: messages,
      nextPageToken: data['nextPageToken'] as String?,
    );
  }

  Future<List<Map<String, dynamic>>> getThread(String threadId) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-thread-get',
      body: {'threadId': threadId},
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? {};
    return ((data['messages'] as List?) ?? const [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getMessage(String messageId) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-message-get',
      body: {'messageId': messageId},
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }

  /// Sends a message via the mail-send edge function. From: header is
  /// pinned server-side to caller's alias (the resolveCaller layer
  /// ignores any client-supplied From). Returns the new gmailMessageId
  /// + threadId.
  Future<({String gmailMessageId, String threadId, String rfc822MessageId})>
      sendMessage({
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    required String subject,
    String? bodyText,
    String? bodyHtml,
    String? threadId,
    String? inReplyTo,
    List<String>? references,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-send',
      body: {
        'to': to,
        if (cc != null && cc.isNotEmpty) 'cc': cc,
        if (bcc != null && bcc.isNotEmpty) 'bcc': bcc,
        'subject': subject,
        if (bodyText != null && bodyText.isNotEmpty) 'bodyText': bodyText,
        if (bodyHtml != null && bodyHtml.isNotEmpty) 'bodyHtml': bodyHtml,
        if (threadId != null) 'threadId': threadId,
        if (inReplyTo != null) 'inReplyTo': inReplyTo,
        if (references != null && references.isNotEmpty)
          'references': references,
        if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
        if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      },
    );
    final data = Map<String, dynamic>.from(resp.data as Map);
    return (
      gmailMessageId: data['gmailMessageId'] as String,
      threadId: data['threadId'] as String,
      rfc822MessageId: data['rfc822MessageId'] as String,
    );
  }

  /// Fetches a single attachment's bytes via the mail-attachment-get edge fn.
  ///
  /// We bypass `functions.invoke` here because the Supabase Dart client only
  /// returns raw bytes when the response Content-Type is exactly
  /// `application/octet-stream` — anything else (image/png, application/pdf,
  /// etc.) gets utf8-decoded into a String, which mangles binary payloads.
  /// The edge function returns the attachment's *real* mimeType, so we go
  /// direct with `package:http`, reusing the auth + apikey headers Supabase
  /// has already populated on its FunctionsClient.
  ///
  /// Filename is decoded from the Content-Disposition header (RFC 5987
  /// `filename*=UTF-8''…` takes precedence over the plain `filename="..."`
  /// for non-ASCII names).
  Future<({Uint8List bytes, String mimeType, String filename})> getAttachment({
    required String messageId,
    required String attachmentId,
  }) async {
    final functions = _supabase.client.functions;
    final url = Uri.parse(
      '${CRMConfig.supabaseUrl}/functions/v1/mail-attachment-get',
    );
    final headers = <String, String>{
      ...functions.headers,
      'Content-Type': 'application/json',
    };
    final resp = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'messageId': messageId,
        'attachmentId': attachmentId,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'mail-attachment-get failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final mimeType = (resp.headers['content-type'] ?? 'application/octet-stream')
        .split(';')
        .first
        .trim();
    final filename = _parseDispositionFilename(
      resp.headers['content-disposition'],
      fallback: 'attachment-${attachmentId.substring(0, attachmentId.length.clamp(0, 8))}',
    );
    return (bytes: resp.bodyBytes, mimeType: mimeType, filename: filename);
  }

  /// Parses a Content-Disposition header into a filename string. Prefers the
  /// RFC 5987 extended `filename*=UTF-8''…` parameter (which is percent-encoded
  /// UTF-8 and supports non-ASCII), falling back to the unquoted `filename=…`
  /// parameter. Strips surrounding quotes and unescapes backslash-escaped
  /// quotes inside the quoted form.
  static String _parseDispositionFilename(
    String? header, {
    required String fallback,
  }) {
    if (header == null || header.isEmpty) return fallback;
    // RFC 5987: filename*=charset'lang'percent-encoded-value
    final extMatch = RegExp(
      r"filename\*\s*=\s*([^']*)'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(header);
    if (extMatch != null) {
      final charset = (extMatch.group(1) ?? 'utf-8').toLowerCase();
      final raw = extMatch.group(2)!.trim();
      try {
        if (charset == 'utf-8' || charset == 'utf8') {
          return Uri.decodeComponent(raw);
        }
        return Uri.decodeComponent(raw);
      } catch (_) {
        // fall through to plain filename
      }
    }
    final plainMatch = RegExp(
      r'filename\s*=\s*("((?:\\.|[^"\\])*)"|([^;]+))',
      caseSensitive: false,
    ).firstMatch(header);
    if (plainMatch != null) {
      final quoted = plainMatch.group(2);
      final bare = plainMatch.group(3);
      final value = (quoted ?? bare ?? '').trim();
      // Unescape backslash-escaped chars inside the quoted form.
      return value.replaceAll(RegExp(r'\\(.)'), r'$1');
    }
    return fallback;
  }

  /// Returns true iff the current user has an active mail alias provisioned.
  /// Used to gate the Mail nav tab — non-execs without an alias should not
  /// see the tab (avoids a confusing 403 on first open).
  Future<bool> hasActiveAlias() async {
    if (!_supabase.isInitialized) return false;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await _supabase.client
          .from('mail_aliases')
          .select('alias_email, revoked_at, gmail_send_as_verified')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return false;
      return row['revoked_at'] == null &&
          row['gmail_send_as_verified'] == true;
    } catch (_) {
      return false;
    }
  }
}
