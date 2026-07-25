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

  /// Buckets that are NOT world readable and must never be linked through
  /// `/storage/v1/object/public/...`.
  ///
  /// `meetings` holds the verbatim transcripts of executive committee and
  /// all-members meetings. It was a public bucket until
  /// moyd-ops/endorsement-round-2/sql/050_meetings_transcript_access.sql took
  /// it private and gated reads on `public.is_executive()`. For anything in
  /// here a failure to sign resolves to null, which the callers already render
  /// as "Unable to open transcript link", rather than falling back to a public
  /// URL. A dead link is the correct outcome; a working unauthenticated one is
  /// not.
  ///
  /// Two consequences worth knowing before debugging a "broken" link:
  ///  * Signing works against a bucket that is still public, so this file is
  ///    safe to ship BEFORE 050 is applied and must be, since the build it
  ///    replaces cannot read a private bucket at all.
  ///  * After 050, a signed-URL request from a non-executive account is
  ///    refused by the storage RLS policy and lands here as a null. That is the
  ///    designed outcome for the 28 Policy & Advocacy CRM accounts, not a bug.
  static const Set<String> _privateBuckets = <String>{'meetings'};

  /// Relative path prefixes that belong to the `meetings` bucket.
  static const List<String> _meetingsPrefixes = <String>[
    'transcripts/',
    'recordings/',
    'documents/',
  ];

  /// Resolve a raw storage path to a fully-qualified [Uri]. The resolver
  /// understands a few formats:
  ///
  /// * Plain HTTP(S) URLs, returned as-is.
  /// * Relative paths (e.g. `storage/v1/object/public/...`), prefixed with the
  ///   Supabase project URL from [CRMConfig.supabaseUrl].
  /// * Relative `transcripts/`, `recordings/` and `documents/` paths, which are
  ///   the `meetings` bucket and are always signed.
  /// * `storage://bucket/path` style URIs, for which a signed download URL is
  ///   requested from Supabase Storage. If signing fails the helper falls back
  ///   to a public URL, except for the buckets in [_privateBuckets], where it
  ///   returns null instead.
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
          if (_privateBuckets.contains(bucket)) return null;
          // If signing fails, the bucket might be public, try public URL
          final publicPath = 'storage/v1/object/public/$bucket/$objectPath';
          return baseUri.resolve(publicPath);
        }
      }

      if (_privateBuckets.contains(bucket)) return null;
      // Default to public bucket URL as fallback
      final fallbackPath = 'storage/v1/object/public/$bucket/$objectPath';
      return baseUri.resolve(fallbackPath);
    }

    // Handle relative paths - check if they look like storage paths
    final relativePath = trimmed.startsWith('/')
        ? trimmed.substring(1)
        : trimmed;

    // If the path starts with a bucket-like pattern (e.g., "transcripts/",
    // "documents/"), it is from the "meetings" bucket. meetings.transcript_file_path
    // stores exactly this shape. The bucket is private, so this is a signed URL
    // and not /object/public.
    if (_meetingsPrefixes.any((prefix) => relativePath.startsWith(prefix))) {
      final service = supabaseService ?? CRMSupabaseService();
      if (!service.isInitialized) return null;
      try {
        final signedUrl = await service.client.storage
            .from('meetings')
            .createSignedUrl(relativePath, signedUrlTtl.inSeconds);
        return Uri.tryParse(signedUrl);
      } catch (error, stackTrace) {
        debugPrint('⚠️ Failed to sign meetings/$relativePath: $error');
        debugPrint('$stackTrace');
        return null;
      }
    }

    // If it already starts with storage/v1/object, use as-is
    if (relativePath.startsWith('storage/v1/object/')) {
      return baseUri.resolve(relativePath);
    }

    // Otherwise, try to resolve as a regular relative path
    return baseUri.resolve(relativePath);
  }
}
