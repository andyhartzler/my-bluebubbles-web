// Conditional export for platform-specific email preview implementation
export 'email_html_preview_stub.dart'
    if (dart.library.html) 'email_html_preview_web.dart';
