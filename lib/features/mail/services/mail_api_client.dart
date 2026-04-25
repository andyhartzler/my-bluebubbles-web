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
