import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/utils/logger/logger.dart';

class EmailService extends GetxService {
  EmailService._internal();

  static EmailService get instance =>
      Get.isRegistered<EmailService>() ? Get.find<EmailService>() : Get.put(EmailService._internal());

  factory EmailService() => instance;

  static const String _emailTable = 'emails';
  static const String _syncFunctionName = 'email-sync';
  static const String _sendFunctionName = 'email-send';
  static const String _replyFunctionName = 'email-reply';

  final Map<String, Map<String, dynamic>> _emailCache = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>>? _cachedInbox;
  Timer? _backgroundSyncTimer;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => _client != null;

  Future<List<Map<String, dynamic>>> fetchInbox({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedInbox != null) {
      return _copyList(_cachedInbox!);
    }

    final SupabaseClient? client = _client;
    if (client == null) {
      Logger.warn('Supabase is not initialized; returning cached inbox if available.', tag: 'EmailService');
      return _copyList(_cachedInbox ?? const <Map<String, dynamic>>[]);
    }

    try {
      final List<dynamic> response = await client
          .from(_emailTable)
          .select()
          .order('received_at', ascending: false);

      final List<Map<String, dynamic>> normalized = response
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> record) => _normalizeRecord(record))
          .toList(growable: false);

      _cacheInbox(normalized);
      return _copyList(normalized);
    } catch (error, stack) {
      Logger.error('Failed to fetch emails from Supabase', error: error, trace: stack, tag: 'EmailService');
      if (_cachedInbox != null && _cachedInbox!.isNotEmpty) {
        Logger.warn('Returning cached inbox after fetch failure.', tag: 'EmailService');
        return _copyList(_cachedInbox!);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchEmailById(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh && _emailCache.containsKey(id)) {
      return Map<String, dynamic>.from(_emailCache[id]!);
    }

    final SupabaseClient? client = _client;
    if (client == null) {
      Logger.warn('Supabase is not initialized; returning cached email if available.', tag: 'EmailService');
      return _emailCache.containsKey(id) ? Map<String, dynamic>.from(_emailCache[id]!) : null;
    }

    try {
      final Map<String, dynamic>? response = await client
          .from(_emailTable)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final Map<String, dynamic> normalized = _normalizeRecord(response);
      _updateCache(normalized);
      return Map<String, dynamic>.from(normalized);
    } catch (error, stack) {
      Logger.error('Failed to fetch email $id from Supabase', error: error, trace: stack, tag: 'EmailService');
      return _emailCache.containsKey(id) ? Map<String, dynamic>.from(_emailCache[id]!) : null;
    }
  }

  Future<void> forceSync({bool refreshAfter = true}) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      Logger.warn('Supabase is not initialized; skipping forced email sync.', tag: 'EmailService');
      return;
    }

    try {
      await client.functions.invoke(_syncFunctionName);
      Logger.info('Triggered email sync via Supabase function.', tag: 'EmailService');
      if (refreshAfter) {
        await fetchInbox(forceRefresh: true);
      }
    } catch (error, stack) {
      Logger.error('Failed to trigger email sync function', error: error, trace: stack, tag: 'EmailService');
      rethrow;
    }
  }

  void scheduleBackgroundSync({Duration delay = const Duration(seconds: 5), bool refreshAfter = true}) {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer(delay, () {
      unawaited(_runBackgroundSync(refreshAfter: refreshAfter));
    });
  }

  Future<void> _runBackgroundSync({required bool refreshAfter}) async {
    try {
      await forceSync(refreshAfter: refreshAfter);
    } catch (error, stack) {
      Logger.warn('Background email sync failed', error: error, trace: stack, tag: 'EmailService');
    }
  }

  Future<Map<String, dynamic>?> sendEmail({
    required String subject,
    required String body,
    required List<String> to,
    List<String>? cc,
    List<String>? bcc,
    List<Map<String, dynamic>>? attachments,
    List<String>? references,
    Map<String, dynamic>? additionalPayload,
    bool refreshAfter = true,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'subject': subject,
      'body': body,
      'to': to,
      if (cc != null) 'cc': cc,
      if (bcc != null) 'bcc': bcc,
      if (attachments != null) 'attachments': attachments,
      if (references != null) 'references': references,
      if (additionalPayload != null) ...additionalPayload,
    };

    return _invokeEmailFunction(
      functionName: _sendFunctionName,
      payload: payload,
      refreshAfter: refreshAfter,
    );
  }

  Future<Map<String, dynamic>?> replyToEmail({
    required String threadId,
    required String body,
    String? inReplyTo,
    List<String>? to,
    List<String>? cc,
    List<String>? bcc,
    List<Map<String, dynamic>>? attachments,
    List<String>? references,
    Map<String, dynamic>? additionalPayload,
    bool refreshAfter = true,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'thread_id': threadId,
      'body': body,
      if (inReplyTo != null) 'in_reply_to': inReplyTo,
      if (to != null) 'to': to,
      if (cc != null) 'cc': cc,
      if (bcc != null) 'bcc': bcc,
      if (attachments != null) 'attachments': attachments,
      if (references != null) 'references': references,
      if (additionalPayload != null) ...additionalPayload,
    };

    return _invokeEmailFunction(
      functionName: _replyFunctionName,
      payload: payload,
      refreshAfter: refreshAfter,
    );
  }

  Future<bool> markAsRead(String id) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      Logger.warn('Supabase is not initialized; unable to mark email as read.', tag: 'EmailService');
      return false;
    }

    try {
      final Map<String, dynamic>? response = await client
          .from(_emailTable)
          .update(<String, dynamic>{'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .select()
          .maybeSingle();

      if (response != null) {
        final Map<String, dynamic> normalized = _normalizeRecord(response);
        _updateCache(normalized);
      } else {
        _updateCache(<String, dynamic>{'id': id, 'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()});
      }
      return true;
    } catch (error, stack) {
      Logger.error('Failed to mark email $id as read', error: error, trace: stack, tag: 'EmailService');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _invokeEmailFunction({
    required String functionName,
    required Map<String, dynamic> payload,
    required bool refreshAfter,
  }) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      Logger.warn('Supabase is not initialized; cannot call $functionName.', tag: 'EmailService');
      return null;
    }

    final Map<String, dynamic> requestPayload = _preparePayload(payload);

    try {
      final FunctionResponse response =
          await client.functions.invoke(functionName, body: requestPayload);
      final dynamic data = response.data;

      Map<String, dynamic>? parsed;
      if (data is Map<String, dynamic>) {
        parsed = _normalizeRecord(data);
      } else if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        parsed = _normalizeRecord(Map<String, dynamic>.from(data.first as Map<String, dynamic>));
      }

      if (parsed != null) {
        _updateCache(parsed);
      }

      if (refreshAfter) {
        await fetchInbox(forceRefresh: true);
      }

      return parsed != null ? Map<String, dynamic>.from(parsed) : null;
    } catch (error, stack) {
      Logger.error('Failed to call Supabase function $functionName', error: error, trace: stack, tag: 'EmailService');
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeRecord(Map<String, dynamic> record) {
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(record);
    _applyReferenceConversion(normalized);

    final dynamic nested = normalized['message'];
    if (nested is Map<String, dynamic>) {
      final Map<String, dynamic> nestedMap = Map<String, dynamic>.from(nested);
      _applyReferenceConversion(nestedMap);
      normalized['message'] = nestedMap;
    }

    return normalized;
  }

  Map<String, dynamic> _preparePayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> prepared = Map<String, dynamic>.from(payload);
    _applyReferenceHeader(prepared);

    final dynamic nested = prepared['message'];
    if (nested is Map<String, dynamic>) {
      final Map<String, dynamic> nestedMap = Map<String, dynamic>.from(nested);
      _applyReferenceHeader(nestedMap);
      prepared['message'] = nestedMap;
    }

    return prepared;
  }

  void _applyReferenceConversion(Map<String, dynamic> target) {
    final dynamic header = target['references_header'];
    final dynamic references = target['references'];

    if (references is! List || references.isEmpty) {
      final List<String> parsed = _parseReferencesHeader(header);
      if (parsed.isNotEmpty) {
        target['references'] = parsed;
      }
    }

    if (header == null && references is List) {
      final String? headerValue = _buildReferencesHeader(references);
      if (headerValue != null) {
        target['references_header'] = headerValue;
      }
    }
  }

  void _applyReferenceHeader(Map<String, dynamic> target) {
    if (target.containsKey('references')) {
      final String? header = _buildReferencesHeader(target['references']);
      if (header != null) {
        target['references_header'] = header;
      } else {
        target.remove('references_header');
      }
    }
  }

  List<String> _parseReferencesHeader(dynamic header) {
    if (header == null) {
      return const <String>[];
    }

    if (header is Iterable) {
      return header
          .map((dynamic value) => value?.toString().trim())
          .whereType<String>()
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
    }

    if (header is String) {
      return header
          .split(RegExp(r'\s+'))
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }

  String? _buildReferencesHeader(dynamic references) {
    if (references == null) {
      return null;
    }

    if (references is String) {
      final String trimmed = references.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (references is Iterable) {
      final List<String> values = references
          .map((dynamic value) => value?.toString().trim())
          .whereType<String>()
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
      if (values.isEmpty) {
        return null;
      }
      return values.join(' ');
    }

    return null;
  }

  void _cacheInbox(List<Map<String, dynamic>> inbox) {
    _cachedInbox = inbox.map((Map<String, dynamic> email) => Map<String, dynamic>.from(email)).toList(growable: false);
    for (final Map<String, dynamic> email in _cachedInbox!) {
      final String? id = email['id']?.toString();
      if (id != null) {
        _emailCache[id] = email;
      }
    }
  }

  void _updateCache(Map<String, dynamic> email) {
    final String? id = email['id']?.toString();
    if (id == null) {
      return;
    }

    final Map<String, dynamic> copy = Map<String, dynamic>.from(email);
    _emailCache[id] = copy;

    if (_cachedInbox != null) {
      for (int index = 0; index < _cachedInbox!.length; index++) {
        final Map<String, dynamic> cached = _cachedInbox![index];
        if (cached['id']?.toString() == id) {
          _cachedInbox![index] = copy;
          return;
        }
      }
      _cachedInbox = <Map<String, dynamic>>[copy, ..._cachedInbox!];
    }
  }

  List<Map<String, dynamic>> _copyList(List<Map<String, dynamic>> source) {
    return source.map((Map<String, dynamic> email) => Map<String, dynamic>.from(email)).toList(growable: false);
  }

  @override
  void onClose() {
    _backgroundSyncTimer?.cancel();
    super.onClose();
  }
}
