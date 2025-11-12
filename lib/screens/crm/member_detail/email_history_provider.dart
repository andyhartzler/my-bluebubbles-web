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

    List<String> resolveRecipients() {
      final recipients = <String>{};
      recipients.addAll(parseRecipients(
        normalized['to_emails'] ??
            normalized['to_addresses'] ??
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
            normalized['bcc'] ??
            (normalized['recipients'] is Map ? (normalized['recipients'] as Map)['bcc'] : null),
      ));
      return recipients.toList(growable: false);
    }

    String resolveStatus() {
      final candidates = <String?>[
        normalized['status']?.toString(),
        normalized['message_state']?.toString(),
        normalized['direction']?.toString(),
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
        normalized['sent_at'],
        normalized['received_at'],
        normalized['internal_date'],
        normalized['created_at'],
        normalized['updated_at'],
      ];
      for (final candidate in candidates) {
        final parsed = parseDate(candidate);
        if (parsed != null) return parsed;
      }
      return null;
    }

    final String id = normalized['id']?.toString() ?? map.hashCode.toString();

    return EmailHistoryEntry(
      id: id,
      subject: resolveSubject(),
      status: resolveStatus(),
      sentAt: resolveTimestamp(),
      to: resolveRecipients(),
      cc: resolveCc(),
      bcc: resolveBcc(),
      previewText: resolvePreview(),
      errorMessage: resolveError(),
    );
  }

  final String id;
  final String subject;
  final String status;
  final DateTime? sentAt;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
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
  })  : _supabaseService = supabaseService ?? CRMSupabaseService(),
        _functionInvokerOverride = functionInvoker;

  final CRMSupabaseService _supabaseService;
  final _FunctionInvocation? _functionInvokerOverride;
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
      if (_functionInvokerOverride != null) {
        return _functionInvokerOverride!(name, body: body);
      }
      final SupabaseClient resolvedClient = client!;
      return resolvedClient.functions
          .invoke(name, body: body)
          .then((response) => (status: response.status, data: response.data));
    }

    try {
      final result = await invoke(
        'get-member-emails',
        body: <String, dynamic>{'member_id': memberId},
      );

      if (result.status != 200) {
        final errorMessage = _extractErrorMessage(result.data) ??
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

      final rawEntries = _extractEntries(result.data);
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

  List<Map<String, dynamic>> _extractEntries(dynamic payload) {
    List<Map<String, dynamic>> parse(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => item.map<String, dynamic>(
                  (key, value) => MapEntry(key.toString(), value),
                ))
            .toList(growable: false);
      }
      if (value is Map) {
        final normalized = value.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
        for (final key in const ['emails', 'records', 'data', 'items', 'results']) {
          if (!normalized.containsKey(key)) continue;
          final nested = parse(normalized[key]);
          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }
      return const <Map<String, dynamic>>[];
    }

    final entries = parse(payload);
    if (entries.isNotEmpty) {
      return entries;
    }
    if (payload is Map) {
      return [payload.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      )];
    }
    return const <Map<String, dynamic>>[];
  }

  String? _extractErrorMessage(dynamic payload) {
    if (payload is String) {
      final trimmed = payload.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (payload is Map) {
      final normalized = payload.map<String, dynamic>(
        (key, value) => MapEntry(key.toString().toLowerCase(), value),
      );
      for (final key in const ['error', 'message', 'detail', 'description']) {
        final value = normalized[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      if (normalized['errors'] is List) {
        final errors = normalized['errors'] as List;
        for (final item in errors) {
          final message = _extractErrorMessage(item);
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      }
    }
    if (payload is List) {
      for (final item in payload) {
        final message = _extractErrorMessage(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }
    return null;
  }
}
