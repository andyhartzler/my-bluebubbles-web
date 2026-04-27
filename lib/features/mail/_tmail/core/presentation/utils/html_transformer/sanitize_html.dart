/// Email-body HTML "sanitizer" — pass-through.
///
/// **Why pass-through:** the `sanitize_html` package this used to call is
/// designed for sanitizing Markdown-rendered output, not email bodies. Its
/// docstring literally states "this sanitizer does not allow any CSS" — it
/// strips inline `style=` attributes, `<style>` blocks, and `class` /
/// `id` attributes. For emails that's catastrophic: every styled HTML
/// email (login codes with branded buttons, marketing emails, etc.)
/// renders as unstyled walls of text. Andrew flagged this 2026-04-27:
/// the MOYD-portal-login email rendered as a plain hyperlink in the CRM
/// vs. a big blue branded button in Gmail.
///
/// **Why this is safe:** the rendered email body is dropped into a
/// sandboxed iframe (`HtmlContentViewerOnWeb` uses
/// `<iframe srcdoc="...">` — no parent-DOM access). Scripts are already
/// stripped by `RemoveScriptTransformer` (in `standardDomTransformers`).
/// CSS in an email iframe can't escape and can't exfiltrate — the iframe
/// has no access to the parent's cookies, document, or form data.
///
/// **What we do not need:** the original `sanitize_html` package's
/// strict whitelist. Email senders include legitimate styled markup
/// (table-based layouts, inline styles for compatibility with old
/// clients, custom button styling). Stripping those is a regression on
/// what every other email client renders.
class SanitizeHtml {
  String process({
    required String inputHtml,
    List<String>? allowAttributes,
    List<String>? allowTags,
  }) {
    return inputHtml;
  }
}