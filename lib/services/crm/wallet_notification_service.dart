import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/wallet_pass_member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

enum WalletNotificationTarget {
  allPassHolders,
  activePasses,
  registeredDevices,
  selectedMembers,
}

class WalletNotificationResult {
  const WalletNotificationResult({
    required this.success,
    this.delivered = 0,
    this.message,
  });

  factory WalletNotificationResult.error(String message) =>
      WalletNotificationResult(success: false, message: message);

  final bool success;
  final int delivered;
  final String? message;
}

/// Service that centralizes all Supabase calls for wallet pass notification
/// workflows. Keeps the screen widgets decoupled from networking details.
class WalletNotificationService {
  WalletNotificationService._();

  static final WalletNotificationService instance = WalletNotificationService._();

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => _supabase.isInitialized;

  SupabaseClient get _client =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Load the latest wallet pass holders with optional search / inclusion
  /// filters. Results are limited to prevent runaway memory usage on web.
  Future<List<WalletPassMember>> fetchPassMembers({
    String? searchQuery,
    List<String>? memberIds,
    int limit = 250,
  }) async {
    if (!isReady) return const [];

    PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
        .from('membership_cards')
        .select('''
          id,
          member_id,
          card_status,
          apple_wallet_pass_serial,
          apple_wallet_generated_at,
          members:members!inner(
            id,
            name,
            email,
            phone,
            phone_e164,
            registered_voter,
            current_chapter_member,
            opt_out
          ),
          registrations:apple_wallet_registrations(
            id,
            registered_at
          )
        ''')
        .order('apple_wallet_generated_at', ascending: false);

    if (limit > 0) {
      query = query.limit(limit);
    }

    if (memberIds != null && memberIds.isNotEmpty) {
      query = query.in_('member_id', memberIds);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final sanitized = _escapeSearch(searchQuery.trim());
      final pattern = '%$sanitized%';
      query = query.or(
        'members.name.ilike.$pattern,members.email.ilike.$pattern',
      );
    }

    final response = await query;
    final data = _coerceList(response)
        .where((row) => row['apple_wallet_pass_serial'] != null)
        .toList(growable: false);
    return data
        .map((row) => WalletPassMember.fromJson(row))
        .toList(growable: false);
  }

  Future<WalletNotificationResult> sendNotification({
    required WalletNotificationTarget target,
    required String title,
    required String message,
    List<String>? memberIds,
  }) async {
    if (!isReady) {
      return WalletNotificationResult.error(
        'CRM Supabase is not configured for wallet notifications.',
      );
    }

    try {
      final payload = <String, dynamic>{
        'title': title,
        'message': message,
        'target': _targetToBackendValue(target),
      };

      if (target == WalletNotificationTarget.selectedMembers) {
        final ids = memberIds?.where((id) => id.trim().isNotEmpty).toList() ??
            const [];
        if (ids.isEmpty) {
          return WalletNotificationResult.error(
            'Select at least one member before sending.',
          );
        }
        payload['member_ids'] = ids;
      }

      final result = await _client.functions.invoke(
        'wallet-notification-dispatch',
        body: payload,
      );

      final decoded = result.data;
      if (decoded is Map<String, dynamic>) {
        final delivered = decoded['delivered'] is int
            ? decoded['delivered'] as int
            : int.tryParse(decoded['delivered']?.toString() ?? '') ?? 0;
        return WalletNotificationResult(
          success: true,
          delivered: delivered,
          message: decoded['message']?.toString(),
        );
      }

      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        final first = decoded.first as Map;
        final delivered = first['delivered'] is int
            ? first['delivered'] as int
            : int.tryParse(first['delivered']?.toString() ?? '') ?? 0;
        return WalletNotificationResult(
          success: true,
          delivered: delivered,
          message: first['message']?.toString(),
        );
      }

      return const WalletNotificationResult(success: true);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('❌ Failed to send wallet notification: $error');
        print(stackTrace);
      }
      return WalletNotificationResult.error(error.toString());
    }
  }

  List<Map<String, dynamic>> _coerceList(dynamic data) {
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    if (data is Map) {
      return [data.cast<String, dynamic>()];
    }
    if (data is PostgrestResponse) {
      final responseData = data.data;
      if (responseData is List) {
        return responseData.cast<Map<String, dynamic>>();
      }
      if (responseData is Map) {
        return [responseData.cast<String, dynamic>()];
      }
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      return _coerceList(decoded);
    }
    return const [];
  }

  String _escapeSearch(String query) {
    return query.replaceAll('%', '\\%').replaceAll('_', '\\_');
  }

  String _targetToBackendValue(WalletNotificationTarget target) {
    switch (target) {
      case WalletNotificationTarget.allPassHolders:
        return 'all';
      case WalletNotificationTarget.activePasses:
        return 'active';
      case WalletNotificationTarget.registeredDevices:
        return 'registered';
      case WalletNotificationTarget.selectedMembers:
        return 'selected';
    }
  }
}
