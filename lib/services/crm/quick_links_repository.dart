import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mime_type/mime_type.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart' as io;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/quick_link.dart';

import 'supabase_service.dart';

class QuickLinksRepository {
  QuickLinksRepository({
    CRMSupabaseService? supabaseService,
    DateTime Function()? clock,
  })  : _supabase = supabaseService ?? CRMSupabaseService(),
        _clock = clock ?? DateTime.now;

  static const String quickLinksTable = 'quick_links';
  static const String storageBucket = 'quick-access-files';
  static const Set<String> legacyColumns = {
    'title',
    'category',
    'description',
    'notes',
    'url',
    'icon_url',
    'is_active',
    'sort_order',
    'storage_url',
  };

  final CRMSupabaseService _supabase;
  DateTime Function() _clock;

  SupabaseClient? _readOverride;
  SupabaseClient? _writeOverride;
  bool? _isReadyOverride;

  @protected
  bool get isReady => _isReadyOverride ?? _supabase.isInitialized;

  SupabaseClient get _readClient => _readOverride ??
      (_supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client);

  SupabaseClient get _writeClient => _writeOverride ?? _supabase.privilegedClient;

  @visibleForTesting
  void debugOverrideClients({
    SupabaseClient? readClient,
    SupabaseClient? writeClient,
    bool? isInitialized,
  }) {
    _readOverride = readClient;
    _writeOverride = writeClient;
    _isReadyOverride = isInitialized;
  }

  @visibleForTesting
  void debugOverrideClock(DateTime Function() value) {
    _clock = value;
  }

  Future<List<QuickLink>> fetchQuickLinks({
    Duration signedUrlTTL = const Duration(hours: 6),
  }) async {
    if (!isReady) return [];

    final rows = await fetchQuickLinkRows();
    final links = rows
        .map((raw) => QuickLink.fromJson(_ensureJsonMap(raw)))
        .where((link) => link.isActive)
        .toList()
      ..sort((a, b) {
        final categoryCompare =
            a.displayCategory.toLowerCase().compareTo(b.displayCategory.toLowerCase());
        if (categoryCompare != 0) return categoryCompare;
        final orderCompare = (a.sortOrder ?? 1 << 20).compareTo(b.sortOrder ?? 1 << 20);
        if (orderCompare != 0) return orderCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final hydrated = await Future.wait(
      links.map((link) => _hydrateSignedUrl(link, signedUrlTTL)),
    );
    return hydrated;
  }

  Future<int> countQuickLinks() async {
    if (!isReady) return 0;
    try {
      final PostgrestResponse response = await _readClient
          .from(quickLinksTable)
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);
      return response.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<QuickLink> createQuickLink({
    required String title,
    required String category,
    String? description,
    String? externalUrl,
    String? iconUrl,
    PlatformFile? file,
    bool isActive = true,
    Duration signedUrlTTL = const Duration(hours: 6),
  }) async {
    if (!isReady) {
      throw StateError('Supabase is not initialized');
    }

    final normalizedExternalUrl = _normalizeExternalUrl(externalUrl);
    final sanitized = _sanitizePayload(
      title: title,
      category: category,
      description: description,
      iconUrl: iconUrl,
    );

    final upload = file != null
        ? await _uploadQuickLinkFile(file)
        : null;

    final payload = {
      ...sanitized,
      if (upload != null) ...upload,
      'is_active': isActive,
    };

    payload['url'] = _resolvePersistedUrl(
      normalizedExternalUrl,
      uploadMetadata: upload,
    );

    final row = await _insertQuickLinkRowWithFallback(payload);
    final link = QuickLink.fromJson(row);
    return _hydrateSignedUrl(link, signedUrlTTL);
  }

  Future<QuickLink> updateQuickLink(
    QuickLink link, {
    String? title,
    String? category,
    String? description,
    String? externalUrl,
    String? iconUrl,
    PlatformFile? file,
    bool removeExistingFile = false,
    bool? isActive,
    Duration signedUrlTTL = const Duration(hours: 6),
  }) async {
    if (!isReady) {
      throw StateError('Supabase is not initialized');
    }
    if (link.id.isEmpty) {
      throw ArgumentError('Quick link ID is required for updates.');
    }

    final normalizedExternalUrl = _normalizeExternalUrl(externalUrl);
    final sanitized = _sanitizePayload(
      title: title ?? link.title,
      category: category ?? link.category,
      description: description ?? link.description,
      iconUrl: iconUrl,
    );

    final updates = <String, dynamic>{
      ...sanitized,
      'is_active': isActive ?? link.isActive,
    };

    Map<String, dynamic>? upload;

    if (removeExistingFile || file != null) {
      if (link.hasStorageReference) {
        await removeStorageReference(
          link.storageBucket ?? storageBucket,
          link.storagePath!,
        );
      }
      updates.addAll(_clearStorageMetadata());
    }

    if (file != null) {
      upload = await _uploadQuickLinkFile(file);
      updates.addAll(upload);
    }

    final fallbackUrl =
        (normalizedExternalUrl == null && upload == null && !removeExistingFile)
            ? link.externalUrl
            : null;
    updates['url'] = _resolvePersistedUrl(
      normalizedExternalUrl,
      uploadMetadata: upload,
      fallbackUrl: fallbackUrl,
    );

    final row = await _updateQuickLinkRowWithFallback(link.id, updates);
    final updated = QuickLink.fromJson(row);
    return _hydrateSignedUrl(updated, signedUrlTTL);
  }

  Future<void> deleteQuickLink(QuickLink link) async {
    if (!isReady || link.id.isEmpty) return;
    if (link.hasStorageReference) {
      await removeStorageReference(
        link.storageBucket ?? storageBucket,
        link.storagePath!,
      );
    }
    await deleteQuickLinkRow(link.id);
  }

  Future<QuickLink> refreshSignedUrl(
    QuickLink link, {
    Duration signedUrlTTL = const Duration(hours: 6),
  }) async {
    if (!link.hasStorageReference || !isReady) {
      return link;
    }
    return _hydrateSignedUrl(link, signedUrlTTL, force: true);
  }

  @protected
  Future<List<Map<String, dynamic>>> fetchQuickLinkRows() async {
    final result = await _readClient
        .from(quickLinksTable)
        .select()
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('sort_order', ascending: true, nullsFirst: true)
        .order('title', ascending: true);

    final data = _coerceJsonList(result);
    return data;
  }

  @protected
  Future<Map<String, dynamic>> insertQuickLinkRow(
    Map<String, dynamic> payload,
  ) async {
    final response = await _writeClient
        .from(quickLinksTable)
        .insert(payload)
        .select()
        .single();
    return _ensureJsonMap(response);
  }

  @protected
  Future<Map<String, dynamic>> updateQuickLinkRow(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _writeClient
        .from(quickLinksTable)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return _ensureJsonMap(response);
  }

  @protected
  Future<void> deleteQuickLinkRow(String id) async {
    await _writeClient.from(quickLinksTable).delete().eq('id', id);
  }

  @protected
  Future<void> uploadBinary(
    String bucket,
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    await _writeClient.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  @protected
  Future<String?> createSignedUrl(
    String bucket,
    String path,
    Duration ttl,
  ) async {
    final seconds = ttl.inSeconds.clamp(1, 604800);
    try {
      return await _writeClient.storage
          .from(bucket)
          .createSignedUrl(path, seconds);
    } catch (_) {
      return null;
    }
  }

  @protected
  Future<void> removeStorageReference(String bucket, String path) async {
    try {
      await _writeClient.storage.from(bucket).remove([path]);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _uploadQuickLinkFile(PlatformFile file) async {
    final bytes = await _resolveFileBytes(file);
    final sanitizedName = _sanitizeFileName(file.name);
    final now = _clock().toUtc();
    final path = '${now.millisecondsSinceEpoch}-$sanitizedName';
    final contentType = mime(file.name) ?? 'application/octet-stream';

    await uploadBinary(
      storageBucket,
      path,
      bytes,
      contentType,
    );

    final publicUrl = _buildPublicUrl(storageBucket, path);

    return {
      'storage_bucket': storageBucket,
      'storage_path': path,
      if (publicUrl != null) 'storage_url': publicUrl,
      'file_name': file.name,
      'content_type': contentType,
      'file_size': bytes.length,
      'last_uploaded_at': now.toIso8601String(),
    };
  }

  Future<QuickLink> _hydrateSignedUrl(
    QuickLink link,
    Duration ttl, {
    bool force = false,
  }) async {
    if (!link.hasStorageReference) {
      return link;
    }

    if (!force && link.signedUrl != null && link.signedUrlExpiresAt != null) {
      final remaining = link.signedUrlExpiresAt!.difference(DateTime.now().toUtc());
      if (remaining.inSeconds > ttl.inSeconds ~/ 4) {
        return link;
      }
    }

    final url = await createSignedUrl(
      link.storageBucket ?? storageBucket,
      link.storagePath!,
      ttl,
    );

    if (url == null || url.isEmpty) {
      return link.copyWith(signedUrl: null, signedUrlExpiresAt: null);
    }

    final expiresAt = _clock().toUtc().add(ttl);
    return link.copyWith(
      signedUrl: url,
      signedUrlExpiresAt: expiresAt,
    );
  }

  Map<String, dynamic> _sanitizePayload({
    required String title,
    required String category,
    String? description,
    String? iconUrl,
  }) {
    final sanitizedTitle = title.trim();
    final sanitizedCategory = category.trim();
    if (sanitizedTitle.isEmpty) {
      throw ArgumentError('Title is required');
    }
    if (sanitizedCategory.isEmpty) {
      throw ArgumentError('Category is required');
    }

    String? normalizedIconUrl;
    if (iconUrl != null) {
      final trimmed = iconUrl.trim();
      if (trimmed.isNotEmpty) {
        normalizedIconUrl = trimmed;
      }
    }

    final bool includeIconUrl = iconUrl != null;

    return {
      'title': sanitizedTitle,
      'category': sanitizedCategory,
      'description': description?.trim(),
      'icon_url': normalizedIconUrl,
    }
      ..removeWhere((key, value) {
        if (key == 'icon_url' && includeIconUrl) {
          return false;
        }
        return value == null || (value is String && value.isEmpty);
      });
  }

  Map<String, dynamic> _legacyPayload(Map<String, dynamic> payload) {
    final entries = Map<String, dynamic>.from(payload);
    if (entries['notes'] == null && entries['description'] != null) {
      entries['notes'] = entries['description'];
    }

    return Map<String, dynamic>.fromEntries(
      entries.entries.where((entry) => legacyColumns.contains(entry.key)),
    );
  }

  bool _isMissingColumnError(Object error) {
    if (error is! PostgrestException) return false;
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        (message.contains('column') && message.contains('does not exist'));
  }

  Future<Map<String, dynamic>> _insertQuickLinkRowWithFallback(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await insertQuickLinkRow(payload);
    } catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }

      final legacy = _legacyPayload(payload);
      return insertQuickLinkRow(legacy);
    }
  }

  Future<Map<String, dynamic>> _updateQuickLinkRowWithFallback(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await updateQuickLinkRow(id, payload);
    } catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }

      final legacy = _legacyPayload(payload);
      return updateQuickLinkRow(id, legacy);
    }
  }

  String? _normalizeExternalUrl(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _resolvePersistedUrl(
    String? normalizedExternalUrl, {
    Map<String, dynamic>? uploadMetadata,
    String? fallbackUrl,
  }) {
    if (normalizedExternalUrl != null && normalizedExternalUrl.isNotEmpty) {
      return normalizedExternalUrl;
    }

    final storageUrl = uploadMetadata?['storage_url'];
    if (storageUrl is String && storageUrl.trim().isNotEmpty) {
      return storageUrl.trim();
    }

    if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
      return fallbackUrl.trim();
    }

    return '';
  }

  Map<String, dynamic> _clearStorageMetadata() {
    return {
      'storage_bucket': null,
      'storage_path': null,
      'storage_url': null,
      'file_name': null,
      'content_type': null,
      'file_size': null,
      'last_uploaded_at': null,
    };
  }

  String? _buildPublicUrl(String bucket, String path) {
    try {
      final url = _writeClient.storage.from(bucket).getPublicUrl(path);
      if (url.isNotEmpty) {
        return url;
      }
    } catch (_) {}

    final supabaseUrl = CRMConfig.supabaseUrl;
    if (supabaseUrl.isEmpty) {
      return null;
    }

    final baseUri = Uri.tryParse(supabaseUrl);
    if (baseUri == null) {
      return null;
    }

    final segments = <String>[
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      'storage',
      'v1',
      'object',
      'public',
      bucket,
      ...path.split('/').where((segment) => segment.isNotEmpty),
    ];

    return Uri(
      scheme: baseUri.scheme,
      userInfo: baseUri.userInfo,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      pathSegments: segments,
    ).toString();
  }

  Future<Uint8List> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    if (file.path != null) {
      final dataUriBytes = _tryDecodeDataUri(file.path!);
      if (dataUriBytes != null && dataUriBytes.isNotEmpty) {
        return dataUriBytes;
      }
      if (!kIsWeb) {
        final ioFile = io.File(file.path!);
        return await ioFile.readAsBytes();
      }
    }

    throw StateError('Unable to read data for file "${file.name}"');
  }

  Uint8List? _tryDecodeDataUri(String value) {
    try {
      final uri = Uri.parse(value);
      final data = uri.data;
      if (data == null) {
        return null;
      }
      final bytes = data.contentAsBytes();
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'quick-link-file';
    }
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.replaceAll(RegExp(r'_+'), '_');
  }

  Map<String, dynamic> _ensureJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    if (value is PostgrestResponse) {
      return _ensureJsonMap(value.data);
    }
    throw StateError('Unexpected payload type: ${value.runtimeType}');
  }

  List<Map<String, dynamic>> _coerceJsonList(dynamic value) {
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    if (value is List) {
      return value
          .map((item) => _ensureJsonMap(item))
          .toList();
    }
    if (value is PostgrestResponse) {
      return _coerceJsonList(value.data);
    }
    throw StateError('Unexpected response type: ${value.runtimeType}');
  }
}
