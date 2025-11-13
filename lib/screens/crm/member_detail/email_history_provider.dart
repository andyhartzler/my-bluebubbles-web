import 'dart:collection';
import 'dart:convert' as convert;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const Set<String> _orgMailboxAddresses = <String>{
  'info@moyoungdemocrats.org',
  'andrew@moyoungdemocrats.org',
  'collegedems@moyoungdemocrats.org',
  'comms@moyoungdemocrats.org',
  'creators@moyoungdemocrats.org',
  'events@moyoungdemocrats.org',
  'eboard@moyoungdemocrats.org',
  'fundraising@moyoungdemocrats.org',
  'highschool@moyoungdemocrats.org',
  'members@moyoungdemocrats.org',
  'membership@moyoungdemocrats.org',
  'policy@moyoungdemocrats.org',
  'political-affairs@moyoungdemocrats.org',
};

String? _sanitizePreview(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final withBreaks = trimmed
      .replaceAll(RegExp(r'(?i)<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'(?i)</(div|p|section|article|table|tbody|tr)>'), '\n\n')
      .replaceAll(RegExp(r'(?i)</?(ul|ol)>'), '\n\n')
      .replaceAll(RegExp(r'(?i)</li>'), '\n')
      .replaceAll(RegExp(r'(?i)<li[^>]*>'), '\n• ');

  final withoutScripts = withBreaks.replaceAll(RegExp(r'(?is)<script[^>]*>.*?</script>'), '');
  final withoutStyles = withoutScripts.replaceAll(RegExp(r'(?is)<style[^>]*>.*?</style>'), '');

  final stripped = withoutStyles.replaceAll(RegExp(r'<[^>]+>'), ' ');
  final decoded = _decodeHtmlEntities(stripped);
  final normalized = _normalizePreviewWhitespace(decoded);
  return normalized.isEmpty ? null : normalized;
}

String _decodeHtmlEntities(String input) {
  return input.replaceAllMapped(
    RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
    (match) {
      final value = match.group(1);
      if (value == null) return match.group(0)!;

      switch (value) {
        case 'nbsp':
          return ' ';
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
        case 'lsquo':
        case 'rsquo':
          return "'";
        case 'ldquo':
        case 'rdquo':
          return '"';
        case 'ndash':
          return '–';
        case 'mdash':
          return '—';
      }

      if (value.startsWith('#x') || value.startsWith('#X')) {
        final hex = value.substring(2);
        final codePoint = int.tryParse(hex, radix: 16);
        if (codePoint != null) {
          return String.fromCharCode(codePoint);
        }
      } else if (value.startsWith('#')) {
        final decimal = value.substring(1);
        final codePoint = int.tryParse(decimal, radix: 10);
        if (codePoint != null) {
          return String.fromCharCode(codePoint);
        }
      }

      return match.group(0)!;
    },
  );
}

String _normalizePreviewWhitespace(String? input) {
  if (input == null || input.isEmpty) return '';

  final cleaned = input
      .replaceAll(String.fromCharCode(0x00A0), ' ')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'[\t\f\v]+'), ' ');

  final lines = cleaned.split('\n');
  final paragraphs = <String>[];
  final buffer = <String>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    paragraphs.add(buffer.join(' ').trim());
    buffer.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushBuffer();
    } else {
      buffer.add(line.replaceAll(RegExp(r' {2,}'), ' '));
    }
  }
  flushBuffer();

  return paragraphs.join('\n\n').trim();
}

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
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal();
      }
      return null;
    }

    List<String> parseRecipients(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item.toString())
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return const [];
        return trimmed
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (value is Map) {
        final entries = <String>[];
        for (final dynamic item in value.values) {
          entries.addAll(parseRecipients(item));
        }
        return entries;
      }
      return const [];
    }

    final normalized = map.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );

    Map<String, dynamic>? resolveRecipientMap() {
      final raw = normalized['recipients'];
      if (raw is Map) {
        return raw.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return null;
    }

    List<String> resolveRecipientSet({
      required List<dynamic> primary,
      required List<dynamic> fallback,
    }) {
      for (final candidate in primary) {
        final parsed = parseRecipients(candidate);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
      for (final candidate in fallback) {
        final parsed = parseRecipients(candidate);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
      return const <String>[];
    }

    final Map<String, dynamic>? recipientMap = resolveRecipientMap();

    List<String> resolveRecipients() {
      final recipients = <String>{};
      recipients.addAll(parseRecipients(
        normalized['to_emails'] ??
            normalized['to_addresses'] ??
            normalized['recipient_emails'] ??
            normalized['to_address'] ??
            normalized['to'] ??
            (normalized['recipients'] is Map ? (normalized['recipients'] as Map)['to'] : normalized['recipients']),
      ));
      return recipients.toList(growable: false);
    }

    List<String> resolveCc() {
      final recipients = <String>{};
      recipients.addAll(parseRecipients(
        normalized['cc_emails'] ??
            normalized['cc_addresses'] ??
            normalized['cc_address'] ??
            normalized['cc'] ??
            (normalized['recipients'] is Map ? (normalized['recipients'] as Map)['cc'] : null),
      ));
      return recipients.toList(growable: false);
    }

    List<String> resolveBcc() {
      final recipients = <String>{};
      recipients.addAll(parseRecipients(
        normalized['bcc_emails'] ??
            normalized['bcc_addresses'] ??
            normalized['bcc_address'] ??
            normalized['bcc'] ??
            (normalized['recipients'] is Map ? (normalized['recipients'] as Map)['bcc'] : null),
      ));
      return recipients.toList(growable: false);
    }

    String resolveStatus() {
      final candidates = <String?>[
        normalized['status']?.toString(),
        normalized['email_status']?.toString(),
        normalized['email_type']?.toString(),
        normalized['message_status']?.toString(),
        normalized['message_state']?.toString(),
        normalized['email_type']?.toString(),
        normalized['direction']?.toString(),
        normalized['state']?.toString(),
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return 'unknown';
    }

    String resolveSubject() {
      final candidates = <String?>[
        normalized['subject']?.toString(),
        normalized['title']?.toString(),
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return 'No subject';
    }

    String? resolvePreview() {
      final candidates = <String?>[
        normalized['preview_text']?.toString(),
        normalized['snippet']?.toString(),
        normalized['body_text']?.toString(),
        normalized['body_html']?.toString(),
        normalized['body']?.toString(),
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          final sanitized = _sanitizePreview(candidate);
          if (sanitized != null && sanitized.isNotEmpty) {
            return sanitized;
          }
        }
      }
      return null;
    }

    String? resolveError() {
      final candidates = <String?>[
        normalized['error_message']?.toString(),
        normalized['error']?.toString(),
        normalized['message']?.toString(),
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate;
        }
      }
      return null;
    }

    DateTime? resolveTimestamp() {
      final candidates = <dynamic>[
        normalized['date'],
        normalized['email_date'],
        normalized['timestamp'],
        normalized['sent_at'],
        normalized['sentAt'],
        normalized['received_at'],
        normalized['receivedAt'],
        normalized['internal_date'],
        normalized['internalDate'],
        normalized['created_at'],
        normalized['synced_at'],
        normalized['updated_at'],
        normalized['updatedAt'],
      ];
      for (final candidate in candidates) {
        final parsed = parseDate(candidate);
        if (parsed != null) return parsed;
      }
      return null;
    }

    String resolveId() {
      final candidates = <dynamic>[
        normalized['id'],
        normalized['log_id'],
        normalized['gmail_message_id'],
        normalized['message_id'],
      ];
      for (final candidate in candidates) {
        if (candidate == null) continue;
        final value = candidate.toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return map.hashCode.toString();
    }

    String? resolveThreadId() {
      final candidates = <String?>[
        normalized['thread_id']?.toString(),
        normalized['thread']?.toString(),
        normalized['threadId']?.toString(),
        normalized['gmail_thread_id']?.toString(),
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return null;
    }

    final String id = resolveId();
    final String resolvedSubject = resolveSubject();
    final String resolvedStatus = resolveStatus();
    final DateTime? resolvedTimestamp = resolveTimestamp();
    final List<String> resolvedTo = resolveRecipients();
    final List<String> resolvedCc = resolveCc();
    final List<String> resolvedBcc = resolveBcc();
    final String? resolvedPreview = resolvePreview();
    final String? resolvedError = resolveError();
    final String? resolvedThreadId = resolveThreadId();

    return EmailHistoryEntry(
      id: id,
      subject: resolvedSubject,
      status: resolvedStatus,
      sentAt: resolvedTimestamp,
      to: resolvedTo,
      cc: resolvedCc,
      bcc: resolvedBcc,
      threadId: resolvedThreadId,
      previewText: resolvedPreview,
      errorMessage: resolvedError,
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

typedef _FunctionInvocation = Future<({int status, dynamic data})> Function(
  String name, {
  Map<String, dynamic>? body,
});

class EmailHistoryProvider extends ChangeNotifier {
  EmailHistoryProvider({
    CRMSupabaseService? supabaseService,
    _FunctionInvocation? functionInvoker,
    Iterable<String>? knownOrgEmailAddresses,
  })  : _supabaseService = supabaseService ?? CRMSupabaseService(),
        _functionInvokerOverride = functionInvoker,
        _knownOrgEmailAddresses = <String>{},
        _knownOrgEmailDomains = <String>{} {
    _seedOrgEmailAddresses(knownOrgEmailAddresses);
  }

  final CRMSupabaseService _supabaseService;
  final _FunctionInvocation? _functionInvokerOverride;
  final Map<String, EmailHistoryState> _stateByMember = <String, EmailHistoryState>{};
  final Set<String> _knownOrgEmailAddresses;
  final Set<String> _knownOrgEmailDomains;

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

    supabase.SupabaseClient? client;
    if (_functionInvokerOverride == null) {
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
    }

    Future<({int status, dynamic data})> invoke(String name, {Map<String, dynamic>? body}) async {
      Map<String, dynamic>? sanitizedBody;
      if (body != null) {
        sanitizedBody = Map<String, dynamic>.from(body)
          ..removeWhere((_, value) => value == null);
      }

      if (_functionInvokerOverride != null) {
        return _functionInvokerOverride!(name, body: sanitizedBody);
      }

      final supabase.SupabaseClient resolvedClient = client!;
      try {
        final response = await resolvedClient.functions.invoke(
          name,
          body: sanitizedBody,
        );
        return (status: response.status, data: response.data);
      } catch (error, stack) {
        Logger.warn(
          'Email history edge function threw for $name: $error',
          trace: stack,
        );
        return (
          status: 500,
          data: error.toString(),
        );
      }
    }

    try {
      final trimmedMemberId = memberId.trim();
      if (trimmedMemberId.isEmpty) {
        _stateByMember[memberId] = EmailHistoryState(
          isLoading: false,
          hasLoaded: true,
          entries: current.entries,
          error: 'Member identifier is missing. Please refresh and try again.',
        );
        notifyListeners();
        return;
      }
      final requestBody = <String, dynamic>{
        'memberId': trimmedMemberId,
        'member_id': trimmedMemberId,
        'maxResults': 50,
        'syncToDatabase': true,
      };

      List<Map<String, dynamic>> functionEntries = const <Map<String, dynamic>>[];
      String? failureMessage;

      try {
        final result = await invoke('get-member-emails', body: requestBody);
        final normalizedData = _normalizeResponsePayload(result.data);

        if (result.status != 200) {
          Logger.warn(
            'Email history edge function returned ${result.status} for member $memberId: $normalizedData',
          );
          failureMessage = _extractErrorMessage(normalizedData) ??
              'Failed to sync email history (HTTP ${result.status}).';
        } else {
          functionEntries = _extractEntries(normalizedData);
        }
      } catch (error, stack) {
        Logger.warn('Email history sync failed for $memberId: $error', trace: stack);
        failureMessage ??= 'Unable to refresh email history from Supabase.';
      }

      final List<Map<String, dynamic>> historyRows = <Map<String, dynamic>>[];
      if (client != null) {
        try {
          final response = await client
              .from('member_email_history')
              .select(
                [
                  'log_id',
                  'email_type',
                  'email_date',
                  'subject',
                  'body',
                  'from_address',
                  'to_address',
                  'gmail_message_id',
                  'gmail_thread_id',
                ].join(','),
              )
              .eq('member_id', trimmedMemberId)
              .order('email_date', ascending: false)
              .limit(200);

          if (response is List) {
            historyRows.addAll(
              response.whereType<Map<String, dynamic>>().map(
                    (row) => row.map<String, dynamic>(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ),
            );
          }
        } catch (error, stack) {
          Logger.warn('Failed to query member_email_history for $memberId: $error', trace: stack);
          failureMessage ??= 'Failed to load cached email history.';
        }
      }

      final entries = <EmailHistoryEntry>[];
      final seen = LinkedHashSet<String>();

      void appendEntries(Iterable<Map<String, dynamic>> rows) {
        for (final row in rows) {
          try {
            final entry = EmailHistoryEntry.fromMap(row);
            final key = entry.id.trim().isEmpty
                ? row.hashCode.toString()
                : entry.id.trim();
            if (seen.add(key)) {
              entries.add(entry);
            }
          } catch (error, stack) {
            Logger.warn('Failed to parse email history row for $memberId: $error', trace: stack);
          }
        }
      }

      appendEntries(functionEntries);
      appendEntries(historyRows);

      if (entries.isEmpty) {
        _stateByMember[memberId] = EmailHistoryState(
          isLoading: false,
          hasLoaded: true,
          entries: current.entries,
          error: failureMessage ?? 'No email history is available for this member yet.',
        );
        notifyListeners();
        return;
      }

      entries.sort((a, b) {
        final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

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

  String? _extractErrorMessage(dynamic data) {
    data = _normalizeResponsePayload(data);
    if (data == null) {
      return null;
    }
    if (data is String) {
      final trimmed = data.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (data is Map) {
      final Map<String, dynamic> normalized = data.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      for (final key in const ['error', 'message', 'detail', 'error_message']) {
        final value = normalized[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      final nested = normalized['data'];
      if (nested != null && nested != data) {
        return _extractErrorMessage(nested);
      }
      return null;
    }
    if (data is Iterable) {
      for (final item in data) {
        final extracted = _extractErrorMessage(item);
        if (extracted != null) {
          return extracted;
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _extractEntries(dynamic data) {
    data = _normalizeResponsePayload(data);
    if (data == null) {
      return const <Map<String, dynamic>>[];
    }
    if (data is List) {
      return _normalizeEntryList(data);
    }
    if (data is Map) {
      final Map<String, dynamic> normalized = data.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );

      for (final key in const ['entries', 'data', 'emails', 'messages', 'results']) {
        final dynamic candidate = normalized[key];
        final list = _normalizeEntryList(candidate);
        if (list.isNotEmpty) {
          return list;
        }
      }

      final single = normalized['entry'];
      final singleList = _normalizeEntryList(single);
      if (singleList.isNotEmpty) {
        return singleList;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _normalizeEntryList(dynamic value) {
    if (value is List) {
      final result = <Map<String, dynamic>>[];
      for (final item in value) {
        if (item is Map) {
          result.add(item.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ));
        }
      }
      return result;
    }
    if (value is Map) {
      return <Map<String, dynamic>>[
        value.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ];
    }
    return const <Map<String, dynamic>>[];
  }

  dynamic _normalizeResponsePayload(dynamic data) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        return data;
      }
      try {
        return convert.jsonDecode(trimmed);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  bool _isMissingColumnError(supabase.PostgrestException error, String columnName) {
    final String lowerColumn = columnName.toLowerCase();
    if (error.code == '42703') {
      return true;
    }
    final String message = (error.message ?? '').toLowerCase();
    return message.contains('column') && message.contains(lowerColumn);
  }

  Future<List<EmailMessage>> fetchThreadMessages({
    required String memberId,
    required String threadId,
  }) async {
    if (!_supabaseService.isInitialized) {
      throw StateError('CRM Supabase is not configured.');
    }

    supabase.SupabaseClient client;
    try {
      client = _supabaseService.privilegedClient;
    } catch (error, stack) {
      Logger.warn('Supabase client unavailable for email thread: $error', trace: stack);
      throw StateError('Supabase client is not available.');
    }

    try {
      final response = await client
          .from('email_inbox')
          .select(
            [
              'id',
              'subject',
              'body_text',
              'body_html',
              'snippet',
              'from_address',
              'to_address',
              'cc_address',
              'gmail_message_id',
              'message_id',
              'date',
              'in_reply_to',
            ].join(','),
          )
          .eq('member_id', memberId)
          .eq('gmail_thread_id', threadId)
          .order('date', ascending: true);

      final rows = response is List
          ? response.whereType<Map<String, dynamic>>().toList(growable: false)
          : <Map<String, dynamic>>[];

      final messages = rows.map(_mapEmailMessage).toList(growable: false);
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
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
      if (value is num) {
        final milliseconds = value.toInt();
        if (milliseconds == 0) return null;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
      }
      return null;
    }

    String? normalizeBody(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final sentAt =
        parseTimestamp(row['date']) ??
        parseTimestamp(row['email_date']) ??
        parseTimestamp(row['received_at']) ??
        parseTimestamp(row['internal_date']) ??
        parseTimestamp(row['sent_at']) ??
        parseTimestamp(row['created_at']) ??
        DateTime.now();

    final direction =
        (row['direction'] ?? row['message_direction'])?.toString().toLowerCase().trim() ?? '';
    bool? outgoingHint;
    if (direction.isNotEmpty) {
      if (direction.contains('outbound') || direction.contains('sent') || direction.contains('outgoing')) {
        outgoingHint = true;
      } else if (direction.contains('inbound') ||
          direction.contains('received') ||
          direction.contains('incoming')) {
        outgoingHint = false;
      }
    }

    final sender =
        _parseParticipant(row['from_address'] ?? row['from_email'] ?? row['from']) ??
        EmailParticipant(
          address: 'unknown@crm.local',
        );
    final senderAddressLower = sender.address.trim().toLowerCase();
    final bool senderMatchesOrg = senderAddressLower.isNotEmpty &&
        _orgMailboxAddresses.contains(senderAddressLower);
    final bool isOutgoing = outgoingHint ?? senderMatchesOrg;

    final messageId = (row['gmail_message_id'] ?? row['message_id'])?.toString();
    final fallbackId = row['id']?.toString();
    final id = (messageId != null && messageId.trim().isNotEmpty)
        ? messageId
        : ((fallbackId != null && fallbackId.trim().isNotEmpty)
            ? fallbackId
            : 'message-${sentAt.microsecondsSinceEpoch}');

    final toParticipants = _parseParticipants(
      row['to_address'] ?? row['to_addresses'] ?? row['to_emails'] ?? row['to'],
    );
    final ccParticipants = _parseParticipants(
      row['cc_address'] ?? row['cc_addresses'] ?? row['cc_emails'] ?? row['cc'],
    );
    final bccParticipants = _parseParticipants(
      row['bcc_address'] ?? row['bcc_addresses'] ?? row['bcc_emails'] ?? row['bcc'],
    );

    final mergedCc = <EmailParticipant>[...ccParticipants];
    final seen = mergedCc.map((participant) => participant.address.toLowerCase()).toSet();
    for (final participant in bccParticipants) {
      if (seen.add(participant.address.toLowerCase())) {
        mergedCc.add(participant);
      }
    }

    return EmailMessage(
      id: id,
      sentAt: sentAt,
      sender: sender,
      to: toParticipants,
      cc: mergedCc,
      subject: normalizeBody(row['subject']) ?? 'No subject',
      plainTextBody: normalizeBody(row['body_text'] ?? row['body'] ?? row['snippet']),
      htmlBody: normalizeBody(row['body_html']),
      isOutgoing: isOutgoing,
    );
  }

  EmailParticipant? _parseParticipant(dynamic value) {
    if (value == null) return null;
    if (value is EmailParticipant) return value;
    if (value is Map) {
      final dynamic rawAddress = value['address'] ??
          value['email'] ??
          value['value'] ??
          value['email_address'] ??
          value['gmail_address'];
      final dynamic rawName =
          value['display_name'] ?? value['name'] ?? value['label'] ?? value['displayName'];
      final EmailParticipant? parsed = _parseParticipant(rawAddress);
      if (parsed != null) {
        final String? displayName = rawName is String ? rawName.trim() : rawName?.toString().trim();
        return EmailParticipant(
          address: parsed.address,
          displayName:
              displayName != null && displayName.isNotEmpty ? displayName : parsed.displayName,
        );
      }
      if (value.length == 1) {
        return _parseParticipant(value.values.first);
      }
      return null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final angleMatch = RegExp(r'^(.*)<([^>]+)>$').firstMatch(raw);
    if (angleMatch != null) {
      final name = angleMatch.group(1)?.trim();
      final email = angleMatch.group(2)?.trim();
      if (email != null && email.isNotEmpty) {
        final cleanedName = name != null && name.isNotEmpty
            ? name.replaceAll(RegExp(r"""^["']|["']$"""), '').trim()
            : null;
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
              .replaceAll(RegExp(r"""^["']|["']$"""), '')
              .trim()
        : null;

    return EmailParticipant(
      address: email,
      displayName: nameRemainder != null && nameRemainder.isNotEmpty ? nameRemainder : null,
    );
  }

  void _seedOrgEmailAddresses(Iterable<String>? knownOrgEmailAddresses) {
    void addSeed(String? value) {
      if (value == null) return;
      _registerOrgEmailAddress(value);
    }

    for (final seed in CRMConfig.orgEmailAddresses) {
      addSeed(seed);
    }

    if (knownOrgEmailAddresses != null) {
      for (final candidate in knownOrgEmailAddresses) {
        addSeed(candidate);
      }
    }
  }

  bool _isOrgEmailAddress(String? address) {
    final normalized = _normalizeEmail(address);
    if (normalized == null) {
      return false;
    }
    if (_knownOrgEmailAddresses.contains(normalized)) {
      return true;
    }
    final domain = _extractDomain(normalized);
    return domain != null && _knownOrgEmailDomains.contains(domain);
  }

  void _registerOrgEmailAddress(String? address) {
    final normalized = _normalizeEmail(address);
    if (normalized == null) return;
    if (_knownOrgEmailAddresses.add(normalized)) {
      final domain = _extractDomain(normalized);
      if (domain != null) {
        _knownOrgEmailDomains.add(domain);
      }
    }
  }

  String? _normalizeEmail(String? address) {
    if (address == null) return null;
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  String? _extractDomain(String address) {
    final atIndex = address.lastIndexOf('@');
    if (atIndex == -1 || atIndex == address.length - 1) {
      return null;
    }
    return address.substring(atIndex + 1);
  }

  List<EmailParticipant> _parseParticipants(dynamic value) {
    final rawValues = <dynamic>[];

    void collect(dynamic source) {
      if (source == null) return;
      if (source is EmailParticipant) {
        rawValues.add(source);
        return;
      }
      if (source is Iterable) {
        for (final item in source) {
          collect(item);
        }
        return;
      }
      if (source is Map) {
        if (source.containsKey('address') ||
            source.containsKey('email') ||
            source.containsKey('value') ||
            source.containsKey('email_address') ||
            source.containsKey('gmail_address')) {
          rawValues.add(source);
          return;
        }
        for (final entry in source.values) {
          collect(entry);
        }
        return;
      }
      if (source is String) {
        final trimmed = source.trim();
        if (trimmed.isEmpty) return;
        if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
            (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
          try {
            final decoded = convert.jsonDecode(trimmed);
            collect(decoded);
            return;
          } catch (_) {
            // Fall through to comma parsing if JSON decoding fails.
          }
        }
        for (final segment in trimmed.split(',')) {
          final normalized = segment.trim();
          if (normalized.isNotEmpty) {
            rawValues.add(normalized);
          }
        }
        return;
      }
      rawValues.add(source);
    }

    collect(value);

    final participants = <EmailParticipant>[];
    final seen = <String>{};
    for (final item in rawValues) {
      final participant = _parseParticipant(item);
      if (participant == null) continue;
      final lower = participant.address.trim().toLowerCase();
      if (lower.isEmpty || !seen.add(lower)) continue;
      participants.add(participant);
    }

    return participants;
  }

  @visibleForTesting
  EmailMessage debugMapEmailMessage(Map<String, dynamic> row) => _mapEmailMessage(row);
}
