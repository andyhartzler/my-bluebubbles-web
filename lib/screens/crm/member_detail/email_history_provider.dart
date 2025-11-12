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
          .select<Map<String, dynamic>>()
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
}
