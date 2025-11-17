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

enum _EmailInboxMode { received, sent }

enum _EmailDirection { received, sent }

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
      if (value == null) {
        return const <String>[];
      }
      if (value is EmailParticipant) {
        final normalized = value.address.trim();
        return normalized.isEmpty ? const <String>[] : <String>[normalized];
      }
      if (value is Iterable) {
        final results = <String>[];
        for (final item in value) {
          final parsed = parseRecipients(item);
          if (parsed.isNotEmpty) {
            results.addAll(parsed);
          }
        }
        return results;
      }
      if (value is Map) {
        final entries = <String>[];
        for (final dynamic item in value.values) {
          final parsed = parseRecipients(item);
          if (parsed.isNotEmpty) {
            entries.addAll(parsed);
          }
        }
        return entries;
      }
      final trimmed = value.toString().trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
        return const <String>[];
      }
      return trimmed
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item.toLowerCase() != 'null')
          .toList(growable: false);
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

    bool hasRecipientField(Iterable<String> keys) {
      for (final key in keys) {
        if (normalized.containsKey(key)) {
          return true;
        }
      }
      return false;
    }

    List<String> resolveRecipients() {
      final recipients = <String>{};

      void add(dynamic value) {
        recipients.addAll(parseRecipients(value));
      }

      add(normalized['to_emails']);
      add(normalized['to_addresses']);
      add(normalized['recipient_emails']);
      add(normalized['to_address']);
      add(normalized['to']);

      if (recipientMap != null) {
        add(recipientMap!['to']);
      } else if (normalized['recipients'] is! Map) {
        add(normalized['recipients']);
      }

      return recipients.toList(growable: false);
    }

    List<String> resolveCc() {
      final bool hasCcData = hasRecipientField(
            const ['cc_emails', 'cc_addresses', 'cc_address', 'cc'],
          ) ||
          (recipientMap?.containsKey('cc') ?? false);
      if (!hasCcData) {
        return const <String>[];
      }

      final recipients = <String>{};

      void add(dynamic value) {
        recipients.addAll(parseRecipients(value));
      }

      add(normalized['cc_emails']);
      add(normalized['cc_addresses']);
      add(normalized['cc_address']);
      add(normalized['cc']);
      if (recipientMap != null) {
        add(recipientMap!['cc']);
      }

      return recipients.toList(growable: false);
    }

    List<String> resolveBcc() {
      final bool hasBccData = hasRecipientField(
            const ['bcc_emails', 'bcc_addresses', 'bcc_address', 'bcc'],
          ) ||
          (recipientMap?.containsKey('bcc') ?? false);
      if (!hasBccData) {
        return const <String>[];
      }

      final recipients = <String>{};

      void add(dynamic value) {
        recipients.addAll(parseRecipients(value));
      }

      add(normalized['bcc_emails']);
      add(normalized['bcc_addresses']);
      add(normalized['bcc_address']);
      add(normalized['bcc']);
      if (recipientMap != null) {
        add(recipientMap!['bcc']);
      }

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
        normalized['body']?.toString(),
        normalized['body_text']?.toString(),
        normalized['body_html']?.toString(),
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
        normalized['email_date'],
        normalized['date'],
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
        normalized['log_id'],
        normalized['gmail_message_id'],
        normalized['email_id'],
        normalized['message_id'],
        normalized['id'],
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
        normalized['gmail_thread_id']?.toString(),
        normalized['thread_id']?.toString(),
        normalized['thread']?.toString(),
        normalized['threadId']?.toString(),
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
  final Map<String, DateTime> _workerLimitFailures = <String, DateTime>{};
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
    _stateByMember[memberId] = current.copyWith(
      isLoading: true,
      clearError: true,
    );
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

    final clients = _resolveSupabaseClients();
    if (clients == null) {
      _stateByMember[memberId] = EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: const [],
        error: 'Supabase client is not available.',
      );
      notifyListeners();
      return;
    }

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

    try {
      final _MemberMetadata? memberMetadata =
          await _loadMemberMetadata(clients.database, trimmedMemberId);
      if (memberMetadata == null) {
        Logger.debug(
          'Email history: no metadata found for $trimmedMemberId (candidate emails=0).',
        );
      } else {
        Logger.debug(
          'Email history: metadata for $trimmedMemberId => '
          'name=${memberMetadata.name ?? 'n/a'}, '
          'email=${memberMetadata.email ?? 'n/a'}, '
          'schoolEmail=${memberMetadata.schoolEmail ?? 'n/a'}, '
          'candidateEmails=${memberMetadata.candidateEmails}',
        );
      }

      final accumulator = _EmailHistoryAccumulator(
        memberId: trimmedMemberId,
        normalizeRow: (row) => _normalizeHistoryRow(
          row,
          trimmedMemberId,
          member: memberMetadata,
        ),
      )..addExisting(current.entries);

      Future<void> loadSource(
        String label,
        Future<List<Map<String, dynamic>>> Function() loader, {
        bool recordFailure = true,
      }) async {
        try {
          final rows = await loader();
          Logger.debug(
            'Email history: $label returned ${rows.length} rows for '
            '$trimmedMemberId.',
          );
          if (rows.isNotEmpty) {
            accumulator.addRows(rows);
          }
        } catch (error, stack) {
          Logger.warn('Failed to load $label for $trimmedMemberId: $error', trace: stack);
          if (recordFailure) {
            accumulator.addFailure('Failed to load $label.');
          }
        }
      }

      await loadSource(
        'received emails',
        () => _fetchInboxRows(
          clients.database,
          trimmedMemberId,
          member: memberMetadata,
          mode: _EmailInboxMode.received,
        ),
      );

      await loadSource(
        'sent emails',
        () => _fetchSentLogRows(
          clients.database,
          trimmedMemberId,
          member: memberMetadata,
        ),
        recordFailure: false,
      );

      await loadSource(
        'cached email history',
        () => _fetchMemberEmailHistoryRows(clients.database, trimmedMemberId),
      );

      final initialEntries = accumulator.snapshot(limit: 200);
      if (initialEntries.isNotEmpty) {
        _stateByMember[memberId] = EmailHistoryState(
          isLoading: true,
          hasLoaded: true,
          entries: initialEntries,
          error: accumulator.warningMessage,
        );
        notifyListeners();
      }

      bool syncSucceeded = false;
      if (_functionInvokerOverride != null || clients.functions != null) {
        final requestBody = <String, dynamic>{
          'memberId': trimmedMemberId,
          'member_id': trimmedMemberId,
          'maxResults': 200,
          'limit': 200,
          'syncToDatabase': true,
        };

        try {
          final result = await _invokeEdgeFunction(
            'get-member-emails',
            body: requestBody,
            client: clients.functions ?? clients.database,
          );
          final normalizedData = _normalizeResponsePayload(result.data);
          final int status = result.status;

          if (status >= 200 && status < 300) {
            syncSucceeded = true;
            final rows = _extractEntries(normalizedData);
            if (rows.isNotEmpty) {
              accumulator.addRows(rows);
            }
          } else {
            final extracted = _extractErrorMessage(normalizedData);
            final bool workerLimit = status == 546 ||
                (extracted?.toUpperCase().contains('WORKER_LIMIT') ?? false);
            final String baseMessage = workerLimit
                ? 'Email sync is temporarily over capacity. Showing stored emails.'
                : 'Failed to sync email history (HTTP $status).';
            final String detailedMessage = extracted != null && extracted.isNotEmpty
                ? '$baseMessage ${extracted.trim()}'
                : baseMessage;
            accumulator.addWarning(detailedMessage);
          }
        } catch (error, stack) {
          Logger.warn('Email history sync failed for $memberId: $error', trace: stack);
          accumulator.addWarning('Unable to refresh email history from Supabase.');
        }
      }

      if (syncSucceeded) {
        await loadSource(
          'refreshed email history',
          () => _fetchMemberEmailHistoryRows(clients.database, trimmedMemberId),
          recordFailure: false,
        );
        await loadSource(
          'refreshed received emails',
          () => _fetchInboxRows(
            clients.database,
            trimmedMemberId,
            member: memberMetadata,
            mode: _EmailInboxMode.received,
          ),
          recordFailure: false,
        );
        await loadSource(
          'refreshed sent emails',
          () => _fetchSentLogRows(
            clients.database,
            trimmedMemberId,
            member: memberMetadata,
          ),
          recordFailure: false,
        );
      }

      final finalEntries = accumulator.snapshot(limit: 200);
      List<EmailHistoryEntry> outputEntries;
      String? errorMessage;

      if (finalEntries.isEmpty) {
        outputEntries = current.entries;
        if (outputEntries.isEmpty) {
          errorMessage =
              accumulator.failureMessage ?? accumulator.warningMessage;
        } else {
          errorMessage = accumulator.warningMessage ?? accumulator.failureMessage;
        }
      } else {
        outputEntries = finalEntries;
        errorMessage = accumulator.warningMessage;
      }

      _stateByMember[memberId] = EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: outputEntries,
        error: errorMessage,
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

  _SupabaseClients? _resolveSupabaseClients() {
    supabase.SupabaseClient? database;
    try {
      database = _supabaseService.privilegedClient;
    } catch (error, stack) {
      Logger.warn('Supabase client unavailable for email history: $error', trace: stack);
      try {
        database = _supabaseService.client;
      } catch (clientError, clientStack) {
        Logger.warn('Fallback Supabase client unavailable: $clientError', trace: clientStack);
        database = null;
      }
    }

    if (database == null) {
      return null;
    }

    supabase.SupabaseClient? functionClient;
    if (_functionInvokerOverride == null) {
      try {
        functionClient = _supabaseService.client;
      } catch (error, stack) {
        Logger.warn('Supabase function client unavailable: $error', trace: stack);
        functionClient = database;
      }
    }

    return _SupabaseClients(
      database: database,
      functions: functionClient,
    );
  }

  Future<({int status, dynamic data})> _invokeEdgeFunction(
    String name, {
    Map<String, dynamic>? body,
    supabase.SupabaseClient? client,
  }) async {
    Map<String, dynamic>? sanitizedBody;
    if (body != null) {
      sanitizedBody = Map<String, dynamic>.from(body)
        ..removeWhere((_, value) => value == null);
    }

    if (_functionInvokerOverride != null) {
      return _functionInvokerOverride!(name, body: sanitizedBody);
    }

    if (client == null) {
      return (status: 503, data: 'Supabase client unavailable');
    }

    try {
      final response = await client.functions.invoke(
        name,
        body: sanitizedBody,
      );
      return (status: response.status, data: response.data);
    } catch (error, stack) {
      Logger.warn(
        'Email history edge function threw for $name: $error',
        trace: stack,
      );
      return (status: 500, data: error.toString());
    }
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

  bool _containsWorkerLimit(dynamic data) {
    data = _normalizeResponsePayload(data);
    if (data == null) {
      return false;
    }
    if (data is String) {
      return data.toUpperCase().contains('WORKER_LIMIT');
    }
    if (data is Map) {
      final Map<String, dynamic> normalized = data.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      for (final key in const ['code', 'message', 'error', 'detail']) {
        final value = normalized[key];
        if (value is String && value.toUpperCase().contains('WORKER_LIMIT')) {
          return true;
        }
      }
      final nested = normalized['data'];
      if (nested != null && nested != data) {
        return _containsWorkerLimit(nested);
      }
      return false;
    }
    if (data is Iterable) {
      for (final item in data) {
        if (_containsWorkerLimit(item)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _fetchCachedHistoryRows(
    supabase.SupabaseClient client,
    String memberId,
  ) async {
    final viewRows = await _queryMemberEmailHistoryView(client, memberId);
    if (viewRows.isNotEmpty) {
      return viewRows;
    }

    final fallbackRows = await _fetchCachedHistoryRowsFromTables(client, memberId);
    if (fallbackRows.isNotEmpty) {
      return fallbackRows;
    }

    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _queryMemberEmailHistoryView(
    supabase.SupabaseClient client,
    String memberId,
  ) async {
    try {
      final response = await client
          .from('member_email_history')
          .select(
            [
              'member_id',
              'member_name',
              'member_email',
              'email_type',
              'log_id',
              'subject',
              'body',
              'from_address',
              'to_address',
              'email_date',
              'gmail_message_id',
              'gmail_thread_id',
            ].join(','),
          )
          .eq('member_id', memberId)
          .order('email_date', ascending: false)
          .limit(200);

      final rows = _normalizeSupabaseList(response);
      if (rows.isNotEmpty) {
        return rows;
      }
    } on supabase.PostgrestException catch (error, stack) {
      Logger.warn(
        'member_email_history view unavailable for $memberId: ${error.message}',
        trace: stack,
      );
    } catch (error, stack) {
      Logger.warn(
        'Unexpected failure querying member_email_history for $memberId: $error',
        trace: stack,
      );
    }

    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _fetchCachedHistoryRowsFromTables(
    supabase.SupabaseClient client,
    String memberId,
  ) async {
    final member = await _fetchMemberMetadata(client, memberId);
    final results = <Map<String, dynamic>>[];

    try {
      final inboxRows = await _fetchInboxRows(
        client,
        memberId,
        member: member,
        mode: _EmailInboxMode.received,
      );

      for (final normalized in inboxRows) {
        results.add({
          ...normalized,
          'member_id': memberId,
          if (member?.name != null) 'member_name': member!.name,
          if (member?.preferredEmail != null)
            'member_email': member!.preferredEmail,
          'email_type': 'received',
          'log_id': normalized['id'] ?? normalized['log_id'],
          'email_date': normalized['email_date'] ??
              normalized['date'] ?? normalized['synced_at'],
          'from_address': normalized['from_address'],
          if (normalized.containsKey('to_address')) 'to_address': normalized['to_address'],
          if (normalized.containsKey('cc_address') &&
              !normalized.containsKey('cc_emails'))
            'cc_emails': normalized['cc_address'],
        });
      }
    } catch (error, stack) {
      Logger.warn('Failed to query email_inbox for $memberId: $error', trace: stack);
    }

    try {
      final sentRows = await _fetchSentLogRows(
        client,
        memberId,
        member: member,
      );

      for (final normalized in sentRows) {
        results.add({
          ...normalized,
          'member_id': memberId,
          if (member?.name != null) 'member_name': member!.name,
          if (member?.preferredEmail != null)
            'member_email': member!.preferredEmail,
          'email_type': 'sent',
          'log_id': normalized['id'] ?? normalized['log_id'],
          'email_date': normalized['email_date'] ?? normalized['created_at'],
          if (!normalized.containsKey('from_address') && normalized['sender'] != null)
            'from_address': normalized['sender'],
          if (!normalized.containsKey('to_address') &&
              normalized['recipient_emails'] is Iterable)
            'to_address':
                (normalized['recipient_emails'] as Iterable).map((e) => e.toString()).join(', '),
        });
      }
    } catch (error, stack) {
      Logger.warn('Failed to query sent email rows for $memberId: $error', trace: stack);
    }

    if (results.length <= 200) {
      return results;
    }

    results.sort((a, b) {
      final aDate = _coerceToDateTime(a['email_date']);
      final bDate = _coerceToDateTime(b['email_date']);
      final aMillis = aDate?.millisecondsSinceEpoch ?? 0;
      final bMillis = bDate?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });

    return results.take(200).toList(growable: false);
  }

  DateTime? _coerceToDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    if (value is num) {
      final millis = value.toInt();
      if (millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    return null;
  }

  Future<_MemberMetadata?> _fetchMemberMetadata(
    supabase.SupabaseClient client,
    String memberId,
  ) async {
    try {
      final response = await client
          .from('members')
          .select('id,name,email,school_email')
          .eq('id', memberId)
          .limit(1);

      final rows = _normalizeSupabaseList(response);
      if (rows.isNotEmpty) {
        final row = rows.first;
        return _MemberMetadata(
          id: row['id']?.toString(),
          name: row['name']?.toString(),
          email: row['email']?.toString(),
          schoolEmail: row['school_email']?.toString(),
        );
      }
    } catch (error, stack) {
      Logger.warn('Failed to fetch member metadata for $memberId: $error', trace: stack);
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeSupabaseList(dynamic response) {
    dynamic data = response;
    if (response is supabase.PostgrestResponse) {
      data = response.data;
    } else if (response is Map<String, dynamic> && response.containsKey('data')) {
      data = response['data'];
    }

    if (data is List) {
      return data.where((row) => row is Map).map((row) {
        final result = <String, dynamic>{};
        (row as Map).forEach((key, value) {
          result[key.toString()] = value;
        });
        return result;
      }).toList(growable: false);
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

  Map<String, dynamic> _normalizeHistoryRow(
    Map<String, dynamic> row,
    String memberId, {
    _MemberMetadata? member,
  }) {
    final normalized = <String, dynamic>{};
    row.forEach((key, value) {
      normalized[key.toString()] = value;
    });

    normalized['member_id'] ??= memberId;

    if (member != null) {
      if (member.name != null) {
        final currentName = normalized['member_name']?.toString() ?? '';
        if (currentName.trim().isEmpty) {
          normalized['member_name'] = member.name;
        }
      }
      final preferredEmail = member.preferredEmail;
      if (preferredEmail != null) {
        final currentEmail = normalized['member_email']?.toString() ?? '';
        if (currentEmail.trim().isEmpty) {
          normalized['member_email'] = preferredEmail;
        }
      }
    }

    final dynamic rawId = normalized['email_id'] ??
        normalized['log_id'] ??
        normalized['id'] ??
        normalized['gmail_message_id'] ??
        normalized['message_id'];
    final String key;
    if (rawId is String && rawId.trim().isNotEmpty) {
      key = rawId.trim();
    } else if (rawId != null) {
      key = rawId.toString();
    } else {
      key = 'row-${normalized.hashCode}';
    }

    normalized['id'] = key;
    normalized['email_id'] ??= key;
    normalized['log_id'] ??= key;

    if (normalized['direction'] == null && normalized['email_type'] != null) {
      normalized['direction'] = normalized['email_type'];
    }

    final dynamic timestamp = normalized['email_date'] ??
        normalized['sent_at'] ??
        normalized['received_at'] ??
        normalized['date'] ??
        normalized['created_at'] ??
        normalized['synced_at'];
    if (timestamp != null) {
      normalized['email_date'] ??= timestamp;
      normalized['sent_at'] ??= timestamp;
    }

    if (normalized['from_email'] == null && normalized['from_address'] != null) {
      normalized['from_email'] = normalized['from_address'];
    }

    if (normalized['to_emails'] == null && normalized['to_address'] != null) {
      normalized['to_emails'] = normalized['to_address'];
    }

    if (normalized['cc_emails'] == null && normalized['cc_address'] != null) {
      normalized['cc_emails'] = normalized['cc_address'];
    }

    if (normalized['bcc_emails'] == null && normalized['bcc_address'] != null) {
      normalized['bcc_emails'] = normalized['bcc_address'];
    }

    return normalized;
  }

  Map<String, dynamic> _normalizeViewHistoryRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    final dynamic rawLogId = row['log_id'] ?? row['id'];
    if (rawLogId != null) {
      final logId = rawLogId.toString();
      map['log_id'] = logId;
      map['email_id'] = logId;
      map['id'] = logId;
    }
    map['direction'] = row['email_type'] ?? row['direction'];
    map['from_email'] = row['from_address'] ?? row['from_email'];
    map['to_emails'] = row['to_address'] ?? row['to_emails'];
    final dynamic emailDate = row['email_date'];
    if (emailDate != null) {
      map['email_date'] = emailDate;
      map['sent_at'] = emailDate;
      map['received_at'] = emailDate;
    }
    map['thread_id'] = row['gmail_thread_id'] ?? row['thread_id'];
    map['gmail_thread_id'] = row['gmail_thread_id'];
    map['message_id'] = row['gmail_message_id'] ?? row['message_id'];
    map['gmail_message_id'] = row['gmail_message_id'];
    map['body_text'] = row['body'] ?? row['body_text'];
    return map;
  }

  Future<List<Map<String, dynamic>>> _fetchMemberEmailHistoryRows(
    supabase.SupabaseClient client,
    String memberId,
  ) async {
    final response = await client
        .from('member_email_history')
        .select(
          [
            'id',
            'member_id',
            'member_name',
            'member_email',
            'email_type',
            'log_id',
            'subject',
            'body',
            'from_address',
            'to_address',
            'email_date',
            'gmail_message_id',
            'gmail_thread_id',
            'created_at',
            'updated_at',
          ].join(','),
        )
        .eq('member_id', memberId)
        .order('email_date', ascending: false)
        .limit(200);

    return _normalizeSupabaseResponse(response)
        .map(_normalizeViewHistoryRow)
        .toList(growable: false);
  }
  bool _isMissingColumnError(supabase.PostgrestException error) {
    if (error.code == '42703') {
      return true;
    }
    final message = error.message.toLowerCase();
    return message.contains('column') && message.contains('does not exist');
  }

  Future<List<Map<String, dynamic>>> _fetchInboxRows(
    supabase.SupabaseClient client,
    String memberId, {
    _MemberMetadata? member,
    _EmailInboxMode mode = _EmailInboxMode.received,
  }) async {
    const primaryColumns = <String>[
      'id',
      'member_id',
      'gmail_message_id',
      'gmail_thread_id',
      'message_id',
      'subject',
      'from_address',
      'to_address',
      'cc_address',
      'snippet',
      'body_html',
      'body_text',
      'label_ids',
      'references_header',
      'in_reply_to',
      'date',
      'created_at',
      'synced_at',
      'is_read',
    ];

    const legacyColumns = <String>[
      'id',
      'member_id',
      'message_id',
      'thread_id',
      'subject',
      'from_email',
      'to_emails',
      'cc_emails',
      'bcc_emails',
      'snippet',
      'body_html',
      'body_text',
      'label_ids',
      'references_header',
      'in_reply_to_header',
      'received_at',
      'created_at',
      'updated_at',
      'direction',
      'message_state',
    ];

    final candidateEmails = member?.candidateEmails ?? const <String>[];
    final emailFilter = _buildInboxEmailFilter(
      candidateEmails,
      legacyColumns: false,
    );
    final legacyEmailFilter = _buildInboxEmailFilter(
      candidateEmails,
      legacyColumns: true,
    );

    Logger.debug(
      'Email history: inbox query setup for $memberId '
      '(candidateEmails=${candidateEmails.length}) '
      'mode=$mode filter=$emailFilter legacyFilter=$legacyEmailFilter',
    );

    Future<List<Map<String, dynamic>>> runQuery({required bool byEmail}) async {
      if (byEmail && emailFilter == null && legacyEmailFilter == null) {
        return const <Map<String, dynamic>>[];
      }

      Future<dynamic> buildQuery({
        required List<String> columns,
        required String orderColumn,
        required bool legacy,
      }) {
        final baseBuilder = client.from('email_inbox').select(columns.join(','));
        dynamic filteredBuilder;

        if (byEmail) {
          final filter = legacy ? legacyEmailFilter : emailFilter;
          if (filter == null || filter.isEmpty) {
            return Future<List<Map<String, dynamic>>>.value(const <Map<String, dynamic>>[]);
          }
          filteredBuilder = baseBuilder.or(filter);
        }

        filteredBuilder ??= baseBuilder.eq('member_id', memberId);
        return filteredBuilder.order(orderColumn, ascending: false).limit(200);
      }

      try {
        final response = await buildQuery(
          columns: primaryColumns,
          orderColumn: 'date',
          legacy: false,
        );
        return _normalizeSupabaseResponse(response);
      } on supabase.PostgrestException catch (error) {
        if (_isMissingColumnError(error)) {
          final response = await buildQuery(
            columns: legacyColumns,
            orderColumn: 'received_at',
            legacy: true,
          );
          return _normalizeSupabaseResponse(response);
        }
        rethrow;
      }
    }

    List<Map<String, dynamic>> rawRows = await runQuery(byEmail: false);
    Logger.debug(
      'Email history: inbox member_id query for $memberId returned '
      '${rawRows.length} rows.',
    );
    if (rawRows.isEmpty) {
      final fallbackRows = await runQuery(byEmail: true);
      Logger.debug(
        'Email history: inbox candidate-email fallback for $memberId returned '
        '${fallbackRows.length} rows.',
      );
      if (fallbackRows.isNotEmpty) {
        rawRows = fallbackRows;
      }
    }

    final rows = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (final item in rawRows) {
      final normalized = Map<String, dynamic>.from(item);
      final direction = _classifyInboxDirection(normalized);
      if (mode == _EmailInboxMode.sent && direction != _EmailDirection.sent) {
        continue;
      }
      if (mode == _EmailInboxMode.received &&
          direction != _EmailDirection.received) {
        continue;
      }
      final directionLabel = direction == _EmailDirection.sent ? 'sent' : 'received';
      normalized['member_id'] = memberId;
      if (member?.name != null) {
        normalized['member_name'] ??= member!.name;
      }
      if (member?.preferredEmail != null) {
        normalized['member_email'] ??= member!.preferredEmail;
      }
      normalized['thread_id'] ??= normalized['gmail_thread_id'];
      normalized['gmail_thread_id'] ??= normalized['thread_id'];
      normalized['gmail_message_id'] ??= normalized['message_id'];
      normalized['message_id'] ??= normalized['gmail_message_id'];
      normalized['from_address'] ??= normalized['from_email'];
      normalized['from_email'] ??= normalized['from_address'];
      normalized['to_address'] ??= normalized['to_emails'] ?? normalized['to'];
      normalized['to_emails'] ??= normalized['to_address'];
      normalized['cc_address'] ??= normalized['cc_emails'];
      normalized['cc_emails'] ??= normalized['cc_address'];
      if (normalized['bcc_address'] == null && normalized['bcc_emails'] != null) {
        normalized['bcc_address'] = normalized['bcc_emails'];
      }
      if (normalized['references_header'] == null && normalized['references'] != null) {
        normalized['references_header'] = normalized['references'];
      }
      if (normalized['in_reply_to'] == null && normalized['in_reply_to_header'] != null) {
        normalized['in_reply_to'] = normalized['in_reply_to_header'];
      }
      normalized['email_type'] ??= directionLabel;
      normalized['direction'] ??= normalized['email_type'];
      normalized['email_date'] ??= normalized['date'] ??
          normalized['received_at'] ?? normalized['created_at'] ?? normalized['synced_at'];
      normalized['synced_at'] ??= normalized['updated_at'];
      final uniqueId = normalized['id']?.toString() ??
          normalized['message_id']?.toString() ?? normalized['gmail_message_id']?.toString();
      if (uniqueId == null || seenIds.add(uniqueId)) {
        rows.add(normalized);
      }
    }

    return rows;
  }

  static const List<String> _sentLogColumns = <String>[
    'id',
    'created_at',
    'subject',
    'body',
    'html',
    'sender',
    'reply_to',
    'recipient_emails',
    'cc',
    'bcc',
    'gmail_message_id',
    'gmail_thread_id',
    'in_reply_to',
    'status',
    'member_ids',
    'error_message',
    'attachments',
    'variables',
  ];

  static const List<String> _legacySentLogColumns = <String>[
    'id',
    'created_at',
    'subject',
    'body',
    'html',
    'sender',
    'reply_to',
    'recipient_emails',
    'cc',
    'bcc',
    'gmail_message_id',
    'gmail_thread_id',
    'message_id',
    'thread_id',
    'status',
    'linked_member_ids',
    'error_message',
  ];

  Future<List<Map<String, dynamic>>> _fetchSentLogRows(
    supabase.SupabaseClient client,
    String memberId, {
    _MemberMetadata? member,
  }) async {
    const int limit = 200;
    String selectList = _sentLogColumns.join(',');
    bool usingLegacyColumns = false;

    supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> buildBaseQuery() {
      return client.from('email_logs').select(selectList);
    }

    final candidateEmails = member?.candidateEmails ?? const <String>[];
    final sentLogFilter = _buildSentLogRecipientFilter(
      candidateEmails,
      legacyColumns: false,
    );
    final legacySentLogFilter = _buildSentLogRecipientFilter(
      candidateEmails,
      legacyColumns: true,
    );

    Logger.debug(
      'Email history: sent log query setup for $memberId '
      '(candidateEmails=${candidateEmails.length}) '
      'filter=$sentLogFilter legacyFilter=$legacySentLogFilter',
    );
    List<Map<String, dynamic>> rawRows = const <Map<String, dynamic>>[];

    try {
      try {
        final response = await buildBaseQuery()
            .contains('member_ids', <String>[memberId])
            .order('created_at', ascending: false)
            .limit(limit);
        rawRows = _normalizeSupabaseResponse(response);
        Logger.debug(
          'Email history: email_logs member_id filter returned ' 
          '${rawRows.length} rows for $memberId.',
        );
      } on supabase.PostgrestException catch (error, stack) {
        if (_isMissingColumnError(error)) {
          usingLegacyColumns = true;
          selectList = _legacySentLogColumns.join(',');
          Logger.warn(
            'Email history: email_logs schema mismatch for $memberId. ' 
            'Falling back to recipient filters: ${error.message}',
            trace: stack,
          );
          rawRows = await _querySentLogsByRecipients(
            client,
            memberId: memberId,
            selectList: selectList,
            candidateEmails: candidateEmails,
            limit: limit,
            legacyColumns: true,
            filter: legacySentLogFilter,
          );
        } else {
          rethrow;
        }
      }

      if (rawRows.isEmpty) {
        final fallbackRows = await _querySentLogsByRecipients(
          client,
          memberId: memberId,
          selectList: selectList,
          candidateEmails: candidateEmails,
          limit: limit,
          legacyColumns: usingLegacyColumns,
          filter: usingLegacyColumns ? legacySentLogFilter : sentLogFilter,
        );
        Logger.debug(
          'Email history: email_logs fallback for $memberId returned '
          '${fallbackRows.length} rows.',
        );
        if (fallbackRows.isNotEmpty) {
          rawRows = fallbackRows;
        }
      }
    } on supabase.PostgrestException catch (error, stack) {
      Logger.warn('Failed to query email_logs for $memberId: ${error.message}', trace: stack);
      return const <Map<String, dynamic>>[];
    } catch (error, stack) {
      Logger.warn('Unexpected failure querying email_logs for $memberId: $error', trace: stack);
      return const <Map<String, dynamic>>[];
    }

    final normalized = _normalizeSentLogRows(
      rawRows,
      memberId,
      member: member,
    );

    Logger.debug(
      'Email history: returning ${normalized.length} sent email rows for '
      '$memberId (legacySchema=$usingLegacyColumns).',
    );

    if (normalized.length <= limit) {
      return normalized;
    }

    normalized.sort((a, b) {
      final aDate = _coerceToDateTime(a['email_date'] ?? a['created_at']);
      final bDate = _coerceToDateTime(b['email_date'] ?? b['created_at']);
      final aMillis = aDate?.millisecondsSinceEpoch ?? 0;
      final bMillis = bDate?.millisecondsSinceEpoch ?? 0;
      return bMillis.compareTo(aMillis);
    });

    return normalized.take(limit).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _querySentLogsByRecipients(
    supabase.SupabaseClient client, {
    required String memberId,
    required String selectList,
    required Iterable<String> candidateEmails,
    required int limit,
    required bool legacyColumns,
    String? filter,
  }) async {
    filter ??= _buildSentLogRecipientFilter(
      candidateEmails,
      legacyColumns: legacyColumns,
    );
    if (filter == null) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final response = await client
          .from('email_logs')
          .select(selectList)
          .or(filter)
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = _normalizeSupabaseResponse(response);
      Logger.debug(
        'Email history: email_logs recipient fallback returned ' 
        '${rows.length} rows for $memberId (legacySchema=$legacyColumns).',
      );
      return rows;
    } on supabase.PostgrestException catch (error, stack) {
      Logger.warn(
        'Failed to query email_logs recipients for $memberId: ${error.message}',
        trace: stack,
      );
    } catch (error, stack) {
      Logger.warn(
        'Unexpected failure querying email_logs recipients for $memberId: $error',
        trace: stack,
      );
    }

    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _normalizeSentLogRows(
    Iterable<Map<String, dynamic>> rows,
    String memberId, {
    _MemberMetadata? member,
  }) {
    final normalizedRows = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final row in rows) {
      final normalized = <String, dynamic>{};
      row.forEach((key, value) {
        normalized[key.toString()] = value;
      });

      normalized['member_id'] = memberId;
      if (member?.name != null) {
        normalized['member_name'] ??= member!.name;
      }
      if (member?.preferredEmail != null) {
        normalized['member_email'] ??= member!.preferredEmail;
      }

      normalized['log_id'] ??= normalized['id'];
      normalized['gmail_thread_id'] ??= normalized['thread_id'];
      normalized['thread_id'] ??= normalized['gmail_thread_id'];
      normalized['gmail_message_id'] ??= normalized['message_id'];
      normalized['message_id'] ??= normalized['gmail_message_id'];
      normalized['from_address'] ??= normalized['sender'] ?? normalized['from_email'];
      normalized['from_email'] ??= normalized['from_address'];

      final toList = _normalizeRecipientAddresses(
        normalized['recipient_emails'] ??
            normalized['to_emails'] ??
            normalized['to_address'] ??
            normalized['to'],
      );
      if (toList.isNotEmpty) {
        normalized['recipient_emails'] = toList;
        normalized['to_emails'] = toList;
        normalized['to_address'] ??= toList.join(', ');
      }

      final ccList = _normalizeRecipientAddresses(
        normalized['cc_emails'] ?? normalized['cc'],
      );
      if (ccList.isNotEmpty) {
        normalized['cc_emails'] = ccList;
        normalized['cc_address'] ??= ccList.join(', ');
      }

      final bccList = _normalizeRecipientAddresses(
        normalized['bcc_emails'] ?? normalized['bcc'],
      );
      if (bccList.isNotEmpty) {
        normalized['bcc_emails'] = bccList;
        normalized['bcc_address'] ??= bccList.join(', ');
      }

      normalized['body_text'] ??= normalized['body'];
      normalized['body_html'] ??= normalized['html'];
      normalized['direction'] ??= 'sent';
      normalized['email_type'] ??= 'sent';
      normalized['message_state'] ??= normalized['status'];
      normalized['email_date'] ??= normalized['created_at'];
      normalized['synced_at'] ??= normalized['updated_at'];

      final uniqueId = normalized['gmail_message_id']?.toString() ??
          normalized['message_id']?.toString() ??
          normalized['id']?.toString();
      if (uniqueId == null || seenIds.add(uniqueId)) {
        normalizedRows.add(normalized);
      }
    }

    return normalizedRows;
  }

  String? _buildSentLogRecipientFilter(
    Iterable<String> candidateEmails, {
    required bool legacyColumns,
  }) {
    final values = candidateEmails
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toList(growable: false);
    if (values.isEmpty) {
      return null;
    }

    final filterColumns = legacyColumns
        ? const ['recipient_emails', 'cc', 'bcc']
        : const ['recipient_emails', 'cc', 'bcc'];

    final clauses = <String>[];
    for (final email in values) {
      final encoded = _encodeArrayContainsValue(email);
      for (final column in filterColumns) {
        clauses.add('$column.cs.$encoded');
      }
    }

    return clauses.isEmpty ? null : clauses.join(',');
  }

  String _encodeArrayContainsValue(
    String value, {
    bool wrapInQuotes = true,
  }) {
    var escaped = value.replaceAll('\\', '\\\\');
    escaped = escaped.replaceAll('"', '\\"');
    escaped = escaped.replaceAll('{', '\\{').replaceAll('}', '\\}');
    final inner = wrapInQuotes ? '"$escaped"' : escaped;
    return '{$inner}';
  }

  bool _looksLikeUuid(String value) {
    final trimmed = value.trim();
    if (trimmed.length != 36) {
      return false;
    }
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(trimmed);
  }

  List<String> _normalizeRecipientAddresses(dynamic value) {
    final participants = _parseParticipants(value);
    if (participants.isEmpty) {
      return const <String>[];
    }

    final addresses = LinkedHashSet<String>();
    for (final participant in participants) {
      final normalized = _normalizeEmail(participant.address) ?? participant.address.trim();
      if (normalized.isNotEmpty) {
        addresses.add(normalized);
      }
    }

    return addresses.toList(growable: false);
  }

  Future<_MemberMetadata?> _loadMemberMetadata(
    supabase.SupabaseClient client,
    String memberId,
  ) async {
    try {
      final response = await client
          .from('members')
          .select('id,name,email,school_email')
          .eq('id', memberId)
          .limit(1);

      final List<Map<String, dynamic>> rows =
          _normalizeSupabaseResponse(response);
      if (rows.isNotEmpty) {
        final row = rows.first;
        return _MemberMetadata(
          id: row['id']?.toString(),
          name: row['name']?.toString(),
          email: row['email']?.toString(),
          schoolEmail: row['school_email']?.toString(),
        );
      }
    } catch (error, stack) {
      Logger.warn('Failed to fetch member metadata for $memberId: $error', trace: stack);
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeSupabaseResponse(dynamic response) {
    dynamic data = response;
    if (response is supabase.PostgrestResponse) {
      data = response.data;
    } else if (response is Map<String, dynamic> && response.containsKey('data')) {
      data = response['data'];
    }

    if (data is List) {
      return data.where((row) => row is Map).map((row) {
        final result = <String, dynamic>{};
        (row as Map).forEach((key, value) {
          result[key.toString()] = value;
        });
        return result;
      }).toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
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
      final sanitizedThreadId = threadId.trim();
      if (sanitizedThreadId.isEmpty) {
        throw ArgumentError.value(threadId, 'threadId', 'Thread id cannot be empty');
      }

      final encodedThreadId = _encodeOrFilterValue(sanitizedThreadId);

      Future<dynamic> queryInbox(List<String> columns, String orderColumn) {
        return client
            .from('email_inbox')
            .select(columns.join(','))
            .eq('member_id', memberId)
            .or(
              [
                'gmail_thread_id.eq.$encodedThreadId',
                'message_id.eq.$encodedThreadId',
                'gmail_message_id.eq.$encodedThreadId',
              ].join(','),
            )
            .order(orderColumn, ascending: true);
      }

      dynamic inboxResponse;
      try {
        inboxResponse = await queryInbox(const <String>[
          'id',
          'member_id',
          'gmail_message_id',
          'gmail_thread_id',
          'message_id',
          'subject',
          'body_html',
          'body_text',
          'snippet',
          'from_address',
          'to_address',
          'cc_address',
          'label_ids',
          'in_reply_to',
          'references_header',
          'date',
          'created_at',
          'synced_at',
          'is_read',
        ], 'date');
      } on supabase.PostgrestException catch (error) {
        if (_isMissingColumnError(error)) {
          inboxResponse = await queryInbox(const <String>[
            'id',
            'member_id',
            'message_id',
            'thread_id',
            'subject',
            'body_html',
            'body_text',
            'snippet',
            'from_email',
            'to_emails',
            'cc_emails',
            'label_ids',
            'in_reply_to_header',
            'references_header',
            'received_at',
            'created_at',
            'updated_at',
            'is_read',
            'direction',
            'message_state',
          ], 'received_at');
        } else {
          rethrow;
        }
      }

      final List<Map<String, dynamic>> inboxRows =
          _normalizeSupabaseResponse(inboxResponse);
      for (final row in inboxRows) {
        row['member_id'] ??= memberId;
        row['from_email'] ??= row['from_address'];
        row['from_address'] ??= row['from_email'];
        row['gmail_thread_id'] ??= row['thread_id'];
        row['thread_id'] ??= row['gmail_thread_id'] ?? sanitizedThreadId;
        row['gmail_message_id'] ??= row['message_id'];
        row['to_address'] ??= row['to_emails'] ?? row['to'];
        row['to_emails'] ??= row['to_address'];
        row['cc_address'] ??= row['cc_emails'];
        row['cc_emails'] ??= row['cc_address'];
        if (row['references_header'] == null && row['references'] != null) {
          row['references_header'] = row['references'];
        }
        if (row['in_reply_to'] == null && row['in_reply_to_header'] != null) {
          row['in_reply_to'] = row['in_reply_to_header'];
        }
        row['thread_id'] ??= row['gmail_thread_id'] ?? sanitizedThreadId;
        final direction = _classifyInboxDirection(row);
        final directionLabel = direction == _EmailDirection.sent ? 'sent' : 'received';
        row['email_type'] = directionLabel;
        row['direction'] ??= row['email_type'];
        row['date'] ??= row['received_at'];
      }
      final allRows = List<Map<String, dynamic>>.from(inboxRows);

      final messages = allRows.map(_mapEmailMessage).toList(growable: false);
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    } catch (error, stack) {
      Logger.warn('Failed to load email thread $threadId for $memberId: $error', trace: stack);
      throw Exception('Failed to load email thread. Please try again.');
    }
  }

  String _encodeOrFilterValue(String value) {
    final sanitized = value.trim();
    if (sanitized.isEmpty) {
      return sanitized;
    }
    return _escapeOrFilterValue(sanitized);
  }

  String _escapeOrFilterValue(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value.replaceAll(',', '\\,');
  }

  String? _buildInboxEmailFilter(
    Iterable<String> candidateEmails, {
    required bool legacyColumns,
  }) {
    final candidates = candidateEmails
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    final filters = <String>[];
    final fromColumn = legacyColumns ? 'from_email' : 'from_address';
    final toColumn = legacyColumns ? 'to_emails' : 'to_address';
    final ccColumn = legacyColumns ? 'cc_emails' : 'cc_address';

    for (final email in candidates) {
      final exact = _escapeOrFilterValue(email);
      filters.add('$fromColumn.ilike.$exact');

      final contains = _escapeOrFilterValue('%$email%');
      filters.add('$toColumn.ilike.$contains');
      filters.add('$ccColumn.ilike.$contains');
    }

    return filters.isEmpty ? null : filters.join(',');
  }

  _EmailDirection _classifyInboxDirection(Map<String, dynamic> row) {
    final candidates = <dynamic>[
      row['direction'],
      row['message_direction'],
      row['email_type'],
      row['message_state'],
    ];

    for (final candidate in candidates) {
      final normalized = candidate?.toString().toLowerCase().trim();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }
      if (normalized.contains('sent') ||
          normalized.contains('outbound') ||
          normalized.contains('outgoing')) {
        return _EmailDirection.sent;
      }
      if (normalized.contains('received') ||
          normalized.contains('inbound') ||
          normalized.contains('incoming')) {
        return _EmailDirection.received;
      }
    }

    final fromAddress =
        _extractPrimaryEmail(row['from_address'] ?? row['from_email'] ?? row['from']);
    if (fromAddress != null && _isOrgEmailAddress(fromAddress)) {
      return _EmailDirection.sent;
    }

    final toAddress = _extractPrimaryEmail(
      row['to_address'] ?? row['to_emails'] ?? row['to'],
    );
    if (toAddress != null && _isOrgEmailAddress(toAddress)) {
      return _EmailDirection.received;
    }

    return _EmailDirection.received;
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
        parseTimestamp(row['synced_at']) ??
        parseTimestamp(row['email_date']) ??
        parseTimestamp(row['received_at']) ??
        parseTimestamp(row['internal_date']) ??
        parseTimestamp(row['sent_at']) ??
        parseTimestamp(row['created_at']) ??
        DateTime.now();

    final direction = (row['direction'] ?? row['message_direction'] ?? row['email_type'])
            ?.toString()
            .toLowerCase()
            .trim() ??
        '';
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

    for (final seed in _orgMailboxAddresses) {
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

  String? _extractPrimaryEmail(dynamic value) {
    if (value == null) return null;
    if (value is EmailParticipant) {
      return _normalizeEmail(value.address);
    }
    if (value is List) {
      for (final entry in value) {
        final normalized = _extractPrimaryEmail(entry);
        if (normalized != null) {
          return normalized;
        }
      }
      return null;
    }
    if (value is Map) {
      final participant = _parseParticipant(value);
      if (participant != null) {
        return _normalizeEmail(participant.address);
      }
      return null;
    }
    final participant = _parseParticipant(value);
    if (participant != null) {
      return _normalizeEmail(participant.address);
    }
    return _normalizeEmail(value.toString());
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

  @visibleForTesting
  String? debugBuildInboxEmailFilter(
    Iterable<String> candidateEmails, {
    bool legacyColumns = false,
  }) {
    return _buildInboxEmailFilter(
      candidateEmails,
      legacyColumns: legacyColumns,
    );
  }

  @visibleForTesting
  Future<List<Map<String, dynamic>>> debugFetchSentLogRows(
    supabase.SupabaseClient client,
    String memberId, {
    _MemberMetadata? member,
  }) {
    return _fetchSentLogRows(client, memberId, member: member);
  }

  @visibleForTesting
  Map<String, dynamic> debugNormalizeHistoryRow(
    Map<String, dynamic> row,
    String memberId, {
    _MemberMetadata? member,
  }) {
    return _normalizeHistoryRow(row, memberId, member: member);
  }

  @visibleForTesting
  _MemberMetadata debugCreateMemberMetadata({
    String? id,
    String? name,
    String? email,
    String? schoolEmail,
  }) {
    return _MemberMetadata(
      id: id,
      name: name,
      email: email,
      schoolEmail: schoolEmail,
    );
  }

  @visibleForTesting
  void debugSetState(String memberId, EmailHistoryState state) {
    _stateByMember[memberId] = state;
    notifyListeners();
  }
}

class _EmailHistoryAccumulator {
  _EmailHistoryAccumulator({
    required this.memberId,
    required Map<String, dynamic> Function(Map<String, dynamic>) normalizeRow,
  })  : _normalizeRow = normalizeRow,
        _entriesById = LinkedHashMap<String, EmailHistoryEntry>();

  final String memberId;
  final Map<String, EmailHistoryEntry> _entriesById;
  final List<String> _blockingFailures = <String>[];
  final List<String> _warnings = <String>[];
  final Map<String, dynamic> Function(Map<String, dynamic>) _normalizeRow;

  void addExisting(List<EmailHistoryEntry> entries) {
    for (final entry in entries) {
      final key = _normalizeKey(entry.id);
      _entriesById[key] = entry;
    }
  }

  void addRows(Iterable<Map<String, dynamic>> rows) {
    var added = 0;
    var failed = 0;
    for (final row in rows) {
      try {
        final normalized = _normalizeRow(Map<String, dynamic>.from(row));
        final entry = EmailHistoryEntry.fromMap(normalized);
        final key = _normalizeKey(entry.id, fallback: normalized.hashCode.toString());
        _entriesById[key] = entry;
        added++;
      } catch (error, stack) {
        failed++;
        Logger.warn('Failed to parse email history row for $memberId: $error', trace: stack);
      }
    }
    Logger.debug(
      'Email history: accumulator processed ${rows.length} rows for '
      '$memberId (added=$added, failed=$failed).',
    );
  }

  void addFailure(String? message) {
    final trimmed = _trimmed(message);
    if (trimmed != null) {
      _blockingFailures.add(trimmed);
    }
  }

  void addWarning(String? message) {
    final trimmed = _trimmed(message);
    if (trimmed != null) {
      _warnings.add(trimmed);
    }
  }

  List<EmailHistoryEntry> snapshot({int? limit}) {
    final entries = _entriesById.values.toList(growable: false);
    entries.sort((a, b) {
      final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    if (limit != null && entries.length > limit) {
      return List<EmailHistoryEntry>.unmodifiable(entries.sublist(0, limit));
    }
    return List<EmailHistoryEntry>.unmodifiable(entries);
  }

  String? get failureMessage =>
      _blockingFailures.isEmpty ? null : _blockingFailures.join(' ');

  String? get warningMessage => _warnings.isEmpty ? null : _warnings.join(' ');

  String _normalizeKey(String value, {String? fallback}) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback ?? value.hashCode.toString();
  }

  String? _trimmed(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _SupabaseClients {
  const _SupabaseClients({
    required this.database,
    this.functions,
  });

  final supabase.SupabaseClient database;
  final supabase.SupabaseClient? functions;
}

class _MemberMetadata {
  const _MemberMetadata({
    this.id,
    this.name,
    this.email,
    this.schoolEmail,
  });

  final String? id;
  final String? name;
  final String? email;
  final String? schoolEmail;

  String? get preferredEmail => email ?? schoolEmail;

  List<String> get candidateEmails {
    final set = LinkedHashSet<String>();
    void addValue(String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        set.add(trimmed.toLowerCase());
      }
    }

    addValue(email);
    addValue(schoolEmail);
    return set.toList(growable: false);
  }
}
