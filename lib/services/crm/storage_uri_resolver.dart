import 'package:flutter/foundation.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Utility for resolving paths returned from Supabase storage into launchable
/// URIs. Handles plain HTTPS links, relative paths that should be prefixed with
/// the Supabase project URL, and the custom `storage://bucket/path` scheme that
/// indicates a signed URL should be generated.
class CRMStorageUriResolver {
  CRMStorageUriResolver._();

  static const Duration _defaultSignedUrlTtl = Duration(hours: 1);

  /// Resolve a raw storage path to a fully-qualified [Uri]. The resolver
  /// understands a few formats:
  ///
  /// * Plain HTTP(S) URLs – returned as-is.
  /// * Relative paths (e.g. `storage/v1/object/public/...`) – prefixed with the
  ///   Supabase project URL from [CRMConfig.supabaseUrl].
  /// * `storage://bucket/path` style URIs – a signed download URL is requested
  ///   from Supabase Storage when possible. If signing fails, the helper falls
  ///   back to constructing a relative path from the project URL.
  static Future<Uri?> resolve(
    String? rawPath, {
    CRMSupabaseService? supabaseService,
    Duration signedUrlTtl = _defaultSignedUrlTtl,
  }) async {
    if (rawPath == null) return null;

    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;

    Uri? parsed;
    try {
      parsed = Uri.parse(trimmed);
    } on FormatException {
      return null;
    }

    if (parsed.hasScheme &&
        parsed.scheme != 'storage' &&
        parsed.scheme != 'supabase-storage') {
      return parsed;
    }

    final supabaseUrl = CRMConfig.supabaseUrl;
    if (supabaseUrl.isEmpty) {
      return parsed.hasScheme ? null : Uri.tryParse(trimmed);
    }

    final baseUri = Uri.tryParse(supabaseUrl);
    if (baseUri == null || baseUri.scheme.isEmpty) {
      return null;
    }

    if (parsed.hasScheme &&
        (parsed.scheme == 'storage' || parsed.scheme == 'supabase-storage')) {
      final bucket = parsed.host.isNotEmpty
          ? parsed.host
          : (parsed.pathSegments.isNotEmpty ? parsed.pathSegments.first : null);
      if (bucket == null || bucket.isEmpty) {
        return null;
      }

      final objectSegments = parsed.host.isNotEmpty
          ? parsed.pathSegments
          : (parsed.pathSegments.length > 1
              ? parsed.pathSegments.sublist(1)
              : const <String>[]);
      final objectPath = objectSegments.join('/');
      if (objectPath.isEmpty) {
        return null;
      }

      final service = supabaseService ?? CRMSupabaseService();
      if (service.isInitialized) {
        try {
          final signedUrl = await service.client.storage
              .from(bucket)
              .createSignedUrl(objectPath, signedUrlTtl.inSeconds);
          final signedUri = Uri.tryParse(signedUrl);
          if (signedUri != null) {
            return signedUri;
          }
        } catch (error, stackTrace) {
          debugPrint(
            '⚠️ Failed to create signed URL for $bucket/$objectPath: $error',
          );
          debugPrint('$stackTrace');
        }
      }

      final fallbackPath = 'storage/v1/object/$bucket/$objectPath';
      return baseUri.resolve(fallbackPath);
    }

    final relativePath = trimmed.startsWith('/')
        ? trimmed.substring(1)
        : trimmed;
    return baseUri.resolve(relativePath);
  }
}
