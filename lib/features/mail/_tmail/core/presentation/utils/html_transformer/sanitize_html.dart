import 'package:sanitize_html/sanitize_html.dart';

class SanitizeHtml {
  /// Wrapper over `sanitize_html` 2.x. The newer package no longer exposes
  /// `allowAttributes` / `allowTags` as positional whitelists — the default
  /// behavior is already a safe whitelist for HTML email rendering. Caller
  /// args are accepted but currently ignored; revisit if we need to widen
  /// what's permitted (e.g., calendar-event tags) post-Phase 2.
  String process({
    required String inputHtml,
    List<String>? allowAttributes,
    List<String>? allowTags,
  }) {
    return sanitizeHtml(inputHtml);
  }
}