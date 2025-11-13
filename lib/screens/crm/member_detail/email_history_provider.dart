import 'dart:convert';

import 'package:bluebubbles/config/crm_config.dart';
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
      return resolveRecipientSet(
        primary: [
          normalized['to_address'],
          recipientMap?['to_address'],
          normalized['to_email'],
          recipientMap?['to_email'],
        ],
        fallback: [
          normalized['to_emails'],
          recipientMap?['to_emails'],
          normalized['to_addresses'],
          recipientMap?['to_addresses'],
          normalized['to'],
          recipientMap?['to'],
          recipientMap,
        ],
      );
    }

    List<String> resolveCc() {
      return resolveRecipientSet(
        primary: [
          normalized['cc_address'],
          recipientMap?['cc_address'],
          normalized['cc_email'],
          recipientMap?['cc_email'],
        ],
        fallback: [
          normalized['cc_emails'],
          recipientMap?['cc_emails'],
          normalized['cc_addresses'],
          recipientMap?['cc_addresses'],
          normalized['cc'],
          recipientMap?['cc'],
          recipientMap,
        ],
      );
    }

    List<String> resolveBcc() {
      return resolveRecipientSet(
        primary: [
          normalized['bcc_address'],
          recipientMap?['bcc_address'],
          normalized['bcc_email'],
          recipientMap?['bcc_email'],
        ],
        fallback: [
          normalized['bcc_emails'],
          recipientMap?['bcc_emails'],
          normalized['bcc_addresses'],
          recipientMap?['bcc_addresses'],
          normalized['bcc'],
          recipientMap?['bcc'],
          recipientMap,
        ],
      );
    }

    String resolveStatus() {
      final candidates = <String?>[
        normalized['status']?.toString(),
        normalized['email_status']?.toString(),
        normalized['email_type']?.toString(),
        normalized['message_status']?.toString(),
        normalized['message_state']?.toString(),
        normalized['email_direction']?.toString(),
        normalized['message_direction']?.toString(),
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
      ];
      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate;
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
        normalized['emailDate'],
        normalized['email_sent_at'],
        normalized['emailSentAt'],
        normalized['email_received_at'],
        normalized['emailReceivedAt'],
        normalized['email_queued_at'],
        normalized['emailQueuedAt'],
        normalized['email_processed_at'],
        normalized['emailProcessedAt'],
        normalized['message_sent_at'],
        normalized['messageSentAt'],
        normalized['message_received_at'],
        normalized['messageReceivedAt'],
        normalized['sent_at'],
        normalized['sentAt'],
        normalized['received_at'],
        normalized['receivedAt'],
        normalized['internal_date'],
        normalized['internalDate'],
        normalized['created_at'],
        normalized['createdAt'],
        normalized['updated_at'],
        normalized['updatedAt'],
      ];
      for (final candidate in candidates) {
        final parsed = parseDate(candidate);
        if (parsed != null) return parsed;
      }
      return null;
    }

    final String id = normalized['id']?.toString() ?? map.hashCode.toString();
    final String resolvedSubject = resolveSubject();
    final String resolvedStatus = resolveStatus();
    final DateTime? resolvedTimestamp = resolveTimestamp();
    final List<String> resolvedTo = resolveRecipients();
    final List<String> resolvedCc = resolveCc();
    final List<String> resolvedBcc = resolveBcc();
    final String? resolvedPreview = resolvePreview();
    final String? resolvedError = resolveError();
    final String? resolvedThreadId =
        normalized['thread_id']?.toString() ?? normalized['thread']?.toString();

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

    SupabaseClient? client;
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

    Future<({int status, dynamic data})> invoke(String name, {Map<String, dynamic>? body}) {
      Map<String, dynamic>? sanitizedBody;
      if (body != null) {
        sanitizedBody = Map<String, dynamic>.from(body)
          ..removeWhere((_, value) => value == null);
      }

      if (_functionInvokerOverride != null) {
        return _functionInvokerOverride!(name, body: sanitizedBody);
      }

      final SupabaseClient resolvedClient = client!;
      final dynamic payload = sanitizedBody == null ? null : jsonEncode(sanitizedBody);
      final Map<String, String>? headers = sanitizedBody == null
          ? null
          : const {'Content-Type': 'application/json'};

      return resolvedClient.functions
          .invoke(name, body: payload, headers: headers)
          .then((response) => (status: response.status, data: response.data));
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

      final result = await invoke('get-member-emails', body: requestBody);

      final normalizedData = _normalizeResponsePayload(result.data);

      if (result.status != 200) {
        Logger.warn(
          'Email history edge function returned ${result.status} for member $memberId: $normalizedData',
        );
        final errorMessage = _extractErrorMessage(normalizedData) ??
            'Failed to load email history (HTTP ${result.status}).';

        _stateByMember[memberId] = EmailHistoryState(
          isLoading: false,
          hasLoaded: true,
          entries: current.entries,
          error: errorMessage,
        );
        notifyListeners();
        return;
      }

      final rawEntries = _extractEntries(normalizedData);
      final entries = rawEntries.map(EmailHistoryEntry.fromMap).toList(growable: false);

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
        return jsonDecode(trimmed);
      } catch (_) {
        return data;
      }
    }
    return data;
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
      const selectedColumns = [
        'id',
        'direction',
        'message_direction',
        'date',
        'subject',
        'plain_body',
        'body_plain',
        'body_text',
        'html_body',
        'body_html',
        'from_address',
        'from_email',
        'from',
        'to_address',
        'to_addresses',
        'to_emails',
        'to',
        'cc_address',
        'cc_addresses',
        'cc_emails',
        'cc',
        'bcc_address',
        'bcc_addresses',
        'bcc_emails',
        'bcc',
        'gmail_message_id',
        'received_at',
        'internal_date',
      ];

      final response = await client
          .from('email_inbox')
          .select(selectedColumns.join(','))
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
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal();
      }
      return null;
    }

    String? normalizeBody(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final headerDate = parseTimestamp(row['date']);
    DateTime? receivedAt;
    DateTime? internalDate;
    if (headerDate == null) {
      receivedAt = parseTimestamp(row['received_at']);
      if (receivedAt == null) {
        internalDate = parseTimestamp(row['internal_date']);
      }
    }
    final sentAt = headerDate ?? receivedAt ?? internalDate ?? DateTime.now();

    List<dynamic> expandRecipientSource(dynamic source) {
      final values = <dynamic>[];

      void collect(dynamic value) {
        if (value == null) return;
        if (value is EmailParticipant) {
          values.add(value);
          return;
        }
        if (value is Iterable) {
          for (final item in value) {
            collect(item);
          }
          return;
        }
        if (value is Map) {
          values.add(value);
          return;
        }
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isEmpty) return;
          for (final segment in trimmed.split(',')) {
            final normalized = segment.trim();
            if (normalized.isNotEmpty) {
              values.add(normalized);
            }
          }
          return;
        }
        values.add(value);
      }

      collect(source);
      return values;
    }

    List<dynamic> preferRecipientSources({
      dynamic primary,
      List<dynamic> fallbacks = const [],
    }) {
      final preferred = expandRecipientSource(primary);
      if (preferred.isNotEmpty) {
        return preferred;
      }
      for (final candidate in fallbacks) {
        final expanded = expandRecipientSource(candidate);
        if (expanded.isNotEmpty) {
          return expanded;
        }
      }
      return const [];
    }

    final List<dynamic> fromCandidates = expandRecipientSource(row['from_address']);
    final dynamic fromValue = fromCandidates.isNotEmpty
        ? fromCandidates.first
        : (row['from_email'] ?? row['from']);
    final EmailParticipant? parsedSender = _parseParticipant(fromValue);

    final bool isOutgoing;
    if (parsedSender != null) {
      isOutgoing = _isOrgEmailAddress(parsedSender.address);
      if (isOutgoing) {
        _registerOrgEmailAddress(parsedSender.address);
      }
    } else {
      isOutgoing = false;
    }

    final sender = parsedSender ??
        EmailParticipant(
          address: isOutgoing ? 'outbound@crm.local' : 'unknown@crm.local',
        );

    final messageId = row['gmail_message_id']?.toString();
    final fallbackId = row['id']?.toString();
    final id = (messageId != null && messageId.trim().isNotEmpty)
        ? messageId
        : ((fallbackId != null && fallbackId.trim().isNotEmpty)
            ? fallbackId
            : 'message-${sentAt.microsecondsSinceEpoch}');

    final toParticipants = _parseParticipants(preferRecipientSources(
      primary: row['to_address'],
      fallbacks: [row['to_addresses'], row['to_emails'], row['to']],
    ));
    final ccParticipants = _parseParticipants(preferRecipientSources(
      primary: row['cc_address'],
      fallbacks: [row['cc_addresses'], row['cc_emails'], row['cc']],
    ));
    final bccParticipants = _parseParticipants(preferRecipientSources(
      primary: row['bcc_address'],
      fallbacks: [row['bcc_addresses'], row['bcc_emails'], row['bcc']],
    ));

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
      subject: normalizeBody(row['subject']),
      plainTextBody:
          normalizeBody(row['plain_body'] ?? row['body_plain'] ?? row['body_text']),
      htmlBody: normalizeBody(row['html_body'] ?? row['body_html']),
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
            final decoded = jsonDecode(trimmed);
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
