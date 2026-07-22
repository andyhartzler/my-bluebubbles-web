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

/// Single verified send-as identity returned by `mail-identities-get`.
class MailSendAsIdentity {
  final String email;
  final String displayName;
  final bool isDefault;
  final bool verified;
  const MailSendAsIdentity({
    required this.email,
    required this.displayName,
    required this.isDefault,
    required this.verified,
  });
}

/// Wrapper for the `mail-identities-get` response — list of identities the
/// caller is authorized to send as, plus the primary (default) email.
class MailIdentitiesResponse {
  final List<MailSendAsIdentity> identities;
  final String primary;
  const MailIdentitiesResponse({
    required this.identities,
    required this.primary,
  });
}

/// Thrown when the inbox still can't be loaded after bounded retries.
/// `toString()` is intentionally user-friendly: MailInboxProvider stores the
/// raw error and the UI renders it directly, so this doubles as the empty
/// state copy instead of a raw 'Load failed'/'Failed to fetch'.
class MailListUnavailableException implements Exception {
  const MailListUnavailableException(this.cause);

  /// The final underlying error, kept for logging/debugging.
  final Object cause;

  @override
  String toString() =>
      'Your inbox is taking a moment to load. Please try again shortly.';
}

class MailApiClient {
  MailApiClient({CRMSupabaseService? supabase})
    : _supabase = supabase ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  /// Cached user-defined Gmail label IDs (Answered + Forwarded). Looked up
  /// once via `mail-labels-get` and reused for the rest of the session — the
  /// IDs are stable per Gmail account, so there's no benefit to re-fetching.
  ({String answered, String forwarded})? _cachedLabels;

  /// Returns the (answered, forwarded) Gmail label IDs for the caller's
  /// alias-scoped mailbox. The IDs are seeded one-shot via
  /// `tool/create_label_seed.js` and exposed by the `mail-labels-get` edge
  /// fn from Supabase secrets. First call hits the network, subsequent
  /// calls are served from the in-memory cache.
  Future<({String answered, String forwarded})> getLabelIds() async {
    if (_cachedLabels != null) return _cachedLabels!;
    final resp = await _supabase.client.functions.invoke('mail-labels-get');
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? {};
    _cachedLabels = (
      answered: data['answeredLabelId'] as String,
      forwarded: data['forwardedLabelId'] as String,
    );
    return _cachedLabels!;
  }

  Future<MailListPage> listInbox({
    int maxResults = 25,
    String? pageToken,
    String? q,
  }) async {
    // Bounded retry with backoff: transient iOS PWA fetch aborts surface as
    // 'Load failed'/'Failed to fetch' (FLUTTER-1/5) even though the
    // mail-list edge fn is healthy server-side — retry briefly before
    // giving up with a user-friendly error.
    const retryDelays = [Duration(seconds: 1), Duration(seconds: 3)];
    for (var attempt = 0; ; attempt++) {
      try {
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
            .map((m) =>
                MailMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
        return MailListPage(
          messages: messages,
          nextPageToken: data['nextPageToken'] as String?,
        );
      } catch (e) {
        // Only network-transient failures are worth retrying; auth/4xx-style
        // failures surface immediately with their real cause.
        final msg = e.toString();
        final transient = msg.contains('Load failed') ||
            msg.contains('Failed to fetch') ||
            msg.contains('ClientException') ||
            msg.contains('SocketException') ||
            msg.contains('Connection closed');
        if (!transient) rethrow;
        if (attempt >= retryDelays.length) {
          throw MailListUnavailableException(e);
        }
        await Future.delayed(retryDelays[attempt]);
      }
    }
  }

  /// Searches the inbox via the `mail-search` edge function. The query string
  /// is passed through unchanged; the edge function clamps results to the
  /// caller's alias-scoped Gmail mailbox server-side. Same response shape as
  /// `mail-list` so we can reuse [MailListPage].
  Future<MailListPage> searchInbox({
    required String q,
    int maxResults = 25,
    String? pageToken,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-search',
      body: {
        'q': q,
        'maxResults': maxResults,
        if (pageToken != null) 'pageToken': pageToken,
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

  /// Sends a message via the mail-send edge function.
  ///
  /// shared_alias mailboxes: From: is pinned server-side to the caller's
  /// alias_email regardless of [fromAddr] (server ignores it).
  ///
  /// self_owned mailboxes: pass [fromAddr] to send AS one of the user's
  /// verified Gmail sendAs identities (founder@, fundraising@, etc).
  /// Server validates against users.settings.sendAs and 403s if not on
  /// the verified list.
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
    String? fromAddr,
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
        if (fromAddr != null && fromAddr.isNotEmpty) 'fromAddr': fromAddr,
      },
    );
    final data = Map<String, dynamic>.from(resp.data as Map);
    return (
      gmailMessageId: data['gmailMessageId'] as String,
      threadId: data['threadId'] as String,
      rfc822MessageId: data['rfc822MessageId'] as String,
    );
  }

  /// Creates a Gmail draft via the mail-draft-create edge function.
  /// shared_alias: From: pinned to caller's alias regardless of [fromAddr].
  /// self_owned: pass [fromAddr] to draft AS a verified sendAs identity.
  Future<({String draftId, String gmailMessageId, String threadId, String rfc822MessageId})>
      createDraft({
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
    String? fromAddr,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-draft-create',
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
        if (fromAddr != null && fromAddr.isNotEmpty) 'fromAddr': fromAddr,
      },
    );
    final data = Map<String, dynamic>.from(resp.data as Map);
    return (
      draftId: data['draftId'] as String,
      gmailMessageId: (data['gmailMessageId'] ?? '') as String,
      threadId: (data['threadId'] ?? '') as String,
      rfc822MessageId: (data['rfc822MessageId'] ?? '') as String,
    );
  }

  /// Lists drafts owned by the caller's alias via the mail-draft-list edge fn.
  /// Each draft entry exposes the same shape mail-draft-list returns:
  /// `{id, message: {id, threadId, from, to, cc, subject, snippet, ...}}`.
  Future<({List<Map<String, dynamic>> drafts, String? nextPageToken})>
      listDrafts({
    int? maxResults,
    String? pageToken,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-draft-list',
      body: {
        if (maxResults != null) 'maxResults': maxResults,
        if (pageToken != null) 'pageToken': pageToken,
      },
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? {};
    final drafts = ((data['drafts'] as List?) ?? const [])
        .whereType<Object>()
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    return (
      drafts: drafts,
      nextPageToken: data['nextPageToken'] as String?,
    );
  }

  /// Updates an existing Gmail draft via the mail-draft-update edge fn.
  /// shared_alias: server verifies the draft's From: matches caller's alias.
  /// self_owned: server skips that check (caller owns the whole mailbox);
  /// pass [fromAddr] to switch the draft's From: to a different verified
  /// sendAs identity.
  Future<({String draftId, String gmailMessageId, String threadId})>
      updateDraft({
    required String draftId,
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    required String subject,
    String? bodyText,
    String? bodyHtml,
    String? threadId,
    String? inReplyTo,
    List<String>? references,
    String? fromAddr,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-draft-update',
      body: {
        'draftId': draftId,
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
        if (fromAddr != null && fromAddr.isNotEmpty) 'fromAddr': fromAddr,
      },
    );
    final data = Map<String, dynamic>.from(resp.data as Map);
    return (
      draftId: (data['draftId'] ?? draftId) as String,
      gmailMessageId: (data['gmailMessageId'] ?? '') as String,
      threadId: (data['threadId'] ?? '') as String,
    );
  }

  /// Sends an existing Gmail draft via the mail-draft-send edge fn. The edge
  /// fn verifies caller ownership before sending. Returns the SENT message's
  /// gmailMessageId / threadId / rfc822MessageId for cache + audit reconciliation.
  Future<({String gmailMessageId, String threadId, String rfc822MessageId})>
      sendDraft({
    required String draftId,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-draft-send',
      body: {'draftId': draftId},
    );
    final data = Map<String, dynamic>.from(resp.data as Map);
    return (
      gmailMessageId: (data['gmailMessageId'] ?? '') as String,
      threadId: (data['threadId'] ?? '') as String,
      rfc822MessageId: (data['rfc822MessageId'] ?? '') as String,
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

  /// Fires an unsubscribe via the mail-unsubscribe edge fn. The edge fn
  /// verifies the caller's alias against the message's Delivered-To/To/Cc/Bcc
  /// headers (so an exec can't unsubscribe from another exec's lists), parses
  /// `List-Unsubscribe` + `List-Unsubscribe-Post`, and chooses one of three
  /// methods: `one-click-post` (RFC 8058), `http-get` (RFC 2369 https
  /// fallback), or `mailto` (RFC 2369 mailto fallback — sent via Gmail API
  /// from the caller's alias).
  ///
  /// Throws on any failure (no header, network error, 4xx/5xx from the
  /// sender's unsubscribe endpoint, etc.) — caller's UI should surface the
  /// message.
  Future<({String method, String url})> unsubscribe({
    required String messageId,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-unsubscribe',
      body: {'messageId': messageId},
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? {};
    if (data['ok'] != true) {
      throw Exception('Unsubscribe failed: ${data['error'] ?? 'unknown'}');
    }
    return (
      method: data['method'] as String,
      url: data['url'] as String,
    );
  }

  /// Fetches the raw RFC 822 bytes of a message via the mail-eml-get edge fn.
  ///
  /// We bypass `functions.invoke` for the same reason as [getAttachment]: the
  /// Supabase Dart client utf8-decodes any non-`application/octet-stream`
  /// response into a String, which mangles the binary EML stream. We go direct
  /// with `package:http`, reusing the auth + apikey headers Supabase has
  /// already populated on its FunctionsClient.
  ///
  /// Returns the raw bytes, the message Subject (URL-decoded from the
  /// `X-Subject` response header so the caller doesn't have to re-parse the
  /// envelope), and a sanitized `<subject>.eml` filename ready for download.
  Future<({Uint8List bytes, String subject, String filename})> getMessageRaw({
    required String messageId,
  }) async {
    final functions = _supabase.client.functions;
    final url = Uri.parse(
      '${CRMConfig.supabaseUrl}/functions/v1/mail-eml-get',
    );
    final headers = <String, String>{
      ...functions.headers,
      'Content-Type': 'application/json',
    };
    final resp = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'messageId': messageId}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'mail-eml-get failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final encodedSubject = resp.headers['x-subject'] ?? '';
    String subject;
    try {
      subject = Uri.decodeComponent(encodedSubject);
    } catch (_) {
      subject = encodedSubject;
    }
    final filename = _parseDispositionFilename(
      resp.headers['content-disposition'],
      fallback: 'message-${messageId.substring(0, messageId.length.clamp(0, 8))}.eml',
    );
    return (bytes: resp.bodyBytes, subject: subject, filename: filename);
  }

  /// Calls the mail-mutation edge fn to add/remove Gmail labels on a list of
  /// message IDs. The edge fn does per-message alias verification: any IDs
  /// the caller doesn't own land in `skipped`. Per-message Gmail-API failures
  /// land in `errors`. `mutated` contains IDs whose modify call returned 2xx.
  Future<({List<String> mutated, List<String> skipped, Map<String, String> errors})>
      modifyMessages({
    required List<String> messageIds,
    List<String>? addLabelIds,
    List<String>? removeLabelIds,
  }) async {
    if (messageIds.isEmpty) {
      return (
        mutated: const <String>[],
        skipped: const <String>[],
        errors: const <String, String>{},
      );
    }
    final hasAdd = addLabelIds != null && addLabelIds.isNotEmpty;
    final hasRemove = removeLabelIds != null && removeLabelIds.isNotEmpty;
    if (!hasAdd && !hasRemove) {
      // Nothing to do — short-circuit to avoid a 400 from the edge fn.
      return (
        mutated: List<String>.from(messageIds),
        skipped: const <String>[],
        errors: const <String, String>{},
      );
    }
    final resp = await _supabase.client.functions.invoke(
      'mail-mutation',
      body: {
        'messageIds': messageIds,
        if (hasAdd) 'addLabelIds': addLabelIds,
        if (hasRemove) 'removeLabelIds': removeLabelIds,
      },
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? const {};
    final mutated = ((data['mutated'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final skipped = ((data['skipped'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final rawErrors = (data['errors'] as Map?) ?? const {};
    final errors = <String, String>{};
    rawErrors.forEach((k, v) {
      if (k is String && v != null) errors[k] = v.toString();
    });
    return (mutated: mutated, skipped: skipped, errors: errors);
  }

  /// Permanently deletes the given Gmail messages via mail-permanent-delete.
  ///
  /// Two-layer safety on the server:
  ///   1. Per-message alias trust verification (silent skip on mismatch).
  ///   2. Refuses to delete messages currently labeled INBOX (caller must
  ///      trash-then-delete to confirm intent — mirrors tmail's UI flow).
  ///
  /// Returns:
  ///   deleted  — IDs whose users.messages.delete returned 2xx
  ///   skipped  — IDs the caller doesn't own (alias mismatch). NO error
  ///              surfaced for these — same pattern as `modifyMessages`.
  ///   errors   — per-id failure reasons. Includes `not_in_trash` (safety
  ///              gate fired) and `delete_failed_<status>` (Gmail rejected).
  Future<({List<String> deleted, List<String> skipped, Map<String, String> errors})>
      permanentlyDeleteMessages({required List<String> messageIds}) async {
    if (messageIds.isEmpty) {
      return (
        deleted: const <String>[],
        skipped: const <String>[],
        errors: const <String, String>{},
      );
    }
    final resp = await _supabase.client.functions.invoke(
      'mail-permanent-delete',
      body: {'messageIds': messageIds},
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? const {};
    final deleted = ((data['deleted'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final skipped = ((data['skipped'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final rawErrors = (data['errors'] as Map?) ?? const {};
    final errors = <String, String>{};
    rawErrors.forEach((k, v) {
      if (k is String && v != null) errors[k] = v.toString();
    });
    return (deleted: deleted, skipped: skipped, errors: errors);
  }

  /// Searches the MOYD CRM members directory for autocomplete suggestions.
  /// Backs `EdgeFnContactDataSource.getContactSuggestions()` — the composer
  /// types into a To/Cc/Bcc field and we substring-match against
  /// `members.name` / `members.email` server-side via the `mail-contact-search`
  /// edge fn.
  ///
  /// Returns up to `limit` rows (capped at 25 server-side). Empty queries
  /// short-circuit to an empty list — no point round-tripping for nothing.
  Future<List<({String id, String name, String email, String? phone})>>
      searchContacts({required String q, int limit = 10}) async {
    if (q.trim().isEmpty) return const [];
    final resp = await _supabase.client.functions.invoke(
      'mail-contact-search',
      body: {'q': q, 'limit': limit},
    );
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (data['contacts'] as List?) ?? const [];
    return list.map((c) {
      final m = Map<String, dynamic>.from(c as Map);
      return (
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        email: m['email'] as String,
        phone: m['phone'] as String?,
      );
    }).toList();
  }

  /// Returns the caller's verified Gmail sendAs identities, used to populate
  /// the composer's From: picker.
  ///
  /// shared_alias: returns a single entry for the caller's alias_email. The
  /// shared crm@ mailbox has many sendAs entries (one per provisioned exec)
  /// but the trust boundary keeps each exec pinned to their own alias.
  ///
  /// self_owned: returns every verified sendAs identity on the user's own
  /// Gmail seat. The mailbox owner can compose AS any of them.
  Future<MailIdentitiesResponse> getIdentities() async {
    final resp = await _supabase.client.functions.invoke('mail-identities-get');
    final data = (resp.data as Map?)?.cast<String, dynamic>() ?? {};
    final identities = ((data['identities'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => MailSendAsIdentity(
              email: (m['email'] as String? ?? '').toLowerCase(),
              displayName: (m['displayName'] as String?) ?? '',
              isDefault: m['isDefault'] == true,
              verified: m['verified'] == true,
            ))
        .where((i) => i.email.isNotEmpty)
        .toList(growable: false);
    return MailIdentitiesResponse(
      identities: identities,
      primary: (data['primary'] as String? ?? '').toLowerCase(),
    );
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
