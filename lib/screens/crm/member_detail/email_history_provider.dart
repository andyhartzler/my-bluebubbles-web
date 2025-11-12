import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailHistoryEntry {
  EmailHistoryEntry({
    required this.id,
    required this.subject,
    required this.status,
    required this.sentAt,
    required this.to,
    required this.cc,
    required this.bcc,
    this.threadId,
    this.previewText,
    this.errorMessage,
  });

  factory EmailHistoryEntry.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value.toLocal();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return DateTime.tryParse(trimmed)?.toLocal();
      }
      return null;
    }

    List<String> parseRecipients(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
      }
      if (value is String) {
        if (value.trim().isEmpty) return const [];
        return value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
      }
      return const [];
    }

    final String id = map['id']?.toString() ?? map.hashCode.toString();
    final String subject = map['subject']?.toString().trim().isNotEmpty == true
        ? map['subject'].toString().trim()
        : 'No subject';
    final String status = map['status']?.toString().trim().isNotEmpty == true
        ? map['status'].toString().trim()
        : 'unknown';

    return EmailHistoryEntry(
      id: id,
      subject: subject,
      status: status,
      sentAt: parseDate(map['sent_at'] ?? map['created_at']),
      to: parseRecipients(map['to_emails'] ?? map['to'] ?? map['recipients']),
      cc: parseRecipients(map['cc_emails'] ?? map['cc']),
      bcc: parseRecipients(map['bcc_emails'] ?? map['bcc']),
      threadId: map['thread_id']?.toString(),
      previewText: map['preview_text']?.toString(),
      errorMessage: map['error_message']?.toString(),
    );
  }

  final String id;
  final String subject;
  final String status;
  final DateTime? sentAt;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String? threadId;
  final String? previewText;
  final String? errorMessage;
}

class EmailHistoryState {
  const EmailHistoryState({
    required this.isLoading,
    required this.hasLoaded,
    required this.entries,
    this.error,
  });

  const EmailHistoryState.initial()
      : isLoading = false,
        hasLoaded = false,
        entries = const [],
        error = null;

  EmailHistoryState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    List<EmailHistoryEntry>? entries,
    String? error,
    bool clearError = false,
  }) {
    return EmailHistoryState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      entries: entries ?? this.entries,
      error: clearError ? null : (error ?? this.error),
    );
  }

  final bool isLoading;
  final bool hasLoaded;
  final List<EmailHistoryEntry> entries;
  final String? error;
}

class EmailHistoryProvider extends ChangeNotifier {
  EmailHistoryProvider({
    CRMSupabaseService? supabaseService,
    this.historyTable = 'crm_email_history',
  }) : _supabaseService = supabaseService ?? CRMSupabaseService();

  final CRMSupabaseService _supabaseService;
  final String historyTable;
  final Map<String, EmailHistoryState> _stateByMember = <String, EmailHistoryState>{};

  EmailHistoryState stateForMember(String memberId) {
    return _stateByMember.putIfAbsent(memberId, EmailHistoryState.initial);
  }

  Future<void> ensureLoaded(String memberId) async {
    final state = stateForMember(memberId);
    if (state.hasLoaded || state.isLoading) return;
    await refresh(memberId);
  }

  Future<void> refresh(String memberId) async {
    final current = stateForMember(memberId);
    _stateByMember[memberId] = current.copyWith(isLoading: true, error: null);
    notifyListeners();

    if (!_supabaseService.isInitialized) {
      _stateByMember[memberId] = EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: const [],
        error: 'CRM Supabase is not configured.',
      );
      notifyListeners();
      return;
    }

    SupabaseClient client;
    try {
      client = _supabaseService.privilegedClient;
    } catch (error, stack) {
      Logger.warn('Supabase client unavailable for email history: $error', trace: stack);
      _stateByMember[memberId] = EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: const [],
        error: 'Supabase client is not available.',
      );
      notifyListeners();
      return;
    }

    try {
      final response = await client
          .from(historyTable)
          .select()
          .eq('member_id', memberId)
          .order('sent_at', ascending: false);

      final data = response is List
          ? response.whereType<Map<String, dynamic>>().toList(growable: false)
          : <Map<String, dynamic>>[];

      final entries = data.map(EmailHistoryEntry.fromMap).toList(growable: false);
      _stateByMember[memberId] = EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: entries,
      );
    } catch (error, stack) {
      Logger.warn('Failed to load email history for $memberId: $error', trace: stack);
      _stateByMember[memberId] = EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: current.entries,
        error: 'Failed to load email history. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<List<EmailMessage>> fetchThreadMessages({
    required String memberId,
    required String threadId,
  }) async {
    if (!_supabaseService.isInitialized) {
      throw StateError('CRM Supabase is not configured.');
    }

    SupabaseClient client;
    try {
      client = _supabaseService.privilegedClient;
    } catch (error, stack) {
      Logger.warn('Supabase client unavailable for email thread: $error', trace: stack);
      throw StateError('Supabase client is not available.');
    }

    try {
      final response = await client
          .from('email_inbox')
          .select()
          .eq('member_id', memberId)
          .eq('thread_id', threadId)
          .order('received_at', ascending: true)
          .order('sent_at', ascending: true);

      final rows = response is List
          ? response.whereType<Map<String, dynamic>>().toList(growable: false)
          : <Map<String, dynamic>>[];

      return rows.map(_mapEmailMessage).toList(growable: false);
    } catch (error, stack) {
      Logger.warn('Failed to load email thread $threadId for $memberId: $error', trace: stack);
      throw Exception('Failed to load email thread. Please try again.');
    }
  }

  EmailMessage _mapEmailMessage(Map<String, dynamic> row) {
    DateTime? parseTimestamp(dynamic value) {
      if (value is DateTime) {
        return value.toLocal();
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return DateTime.tryParse(trimmed)?.toLocal();
      }
      return null;
    }

    String? normalizeBody(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final sentAt =
        parseTimestamp(row['sent_at']) ?? parseTimestamp(row['received_at']) ?? DateTime.now();
    final direction = row['direction']?.toString().toLowerCase() ?? '';
    final isOutgoing = direction == 'outbound';
    final sender = _parseParticipant(row['from_email']) ??
        EmailParticipant(
          address: isOutgoing ? 'outbound@crm.local' : 'unknown@crm.local',
        );

    final messageId = row['message_id']?.toString();
    final fallbackId = row['id']?.toString();
    final id = (messageId != null && messageId.trim().isNotEmpty)
        ? messageId
        : ((fallbackId != null && fallbackId.trim().isNotEmpty)
            ? fallbackId
            : 'message-${sentAt.microsecondsSinceEpoch}');

    return EmailMessage(
      id: id,
      sentAt: sentAt,
      sender: sender,
      to: _parseParticipants(row['to_emails']),
      cc: _parseParticipants(row['cc_emails']),
      subject: normalizeBody(row['subject']),
      plainTextBody: normalizeBody(row['body_text']),
      htmlBody: normalizeBody(row['body_html']),
      isOutgoing: isOutgoing,
    );
  }

  EmailParticipant? _parseParticipant(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final angleMatch = RegExp(r'^(.*)<([^>]+)>$').firstMatch(raw);
    if (angleMatch != null) {
      final name = angleMatch.group(1)?.trim();
      final email = angleMatch.group(2)?.trim();
      if (email != null && email.isNotEmpty) {
        final cleanedName =
            name != null && name.isNotEmpty ? name.replaceAll(RegExp(r"^[\"']|[\"']$"), '').trim() : null;
        return EmailParticipant(
          address: email,
          displayName: cleanedName?.isNotEmpty == true ? cleanedName : null,
        );
      }
    }

    final emailMatch =
        RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false).firstMatch(raw);
    final email = emailMatch?.group(0)?.trim() ?? raw;
    final nameRemainder = emailMatch != null
        ? raw
            .replaceFirst(emailMatch.group(0)!, '')
            .replaceAll(RegExp(r"^[\"']|[\"']$"), '')
            .trim()
        : null;

    return EmailParticipant(
      address: email,
      displayName: nameRemainder != null && nameRemainder.isNotEmpty ? nameRemainder : null,
    );
  }

  List<EmailParticipant> _parseParticipants(dynamic value) {
    final participants = <EmailParticipant>[];
    Iterable<dynamic> values;
    if (value is List) {
      values = value;
    } else if (value is String) {
      values = value.split(',');
    } else {
      return participants;
    }

    final seen = <String>{};
    for (final item in values) {
      final participant = _parseParticipant(item);
      if (participant == null) continue;
      final lower = participant.address.toLowerCase();
      if (lower.isEmpty || !seen.add(lower)) continue;
      participants.add(participant);
    }

    return participants;
  }
}
