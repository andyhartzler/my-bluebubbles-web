import '../services/html_exporter.dart';
import 'email_document.dart';

extension EmailDocumentHtml on EmailDocument {
  /// Export the current document to responsive, client-ready HTML.
  String toHtml() => HtmlExporter().export(this);
}
