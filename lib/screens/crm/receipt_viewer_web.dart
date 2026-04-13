import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// View-factory registrations must be globally unique and survive the lifetime
/// of the Flutter Web app. Track what we've already registered so we can return
/// the same factory id on repeated opens of the same URL without throwing.
final Set<String> _registered = <String>{};

/// Render a PDF (or any browser-viewable URL) as a native `<iframe>`.
///
/// The browser's built-in PDF viewer handles every valid PDF — encrypted,
/// forms, custom fonts, weird compression — because it's the same PDFium/pdf.js
/// that Chrome/Firefox/Safari ship with. This sidesteps every rendering bug
/// that `printing.PdfPreview` on Flutter Web can hit.
Widget? buildBrowserNativePdfViewer(String url) {
  // Stable per-URL view type so opening the same receipt twice doesn't leak
  // factory entries and doesn't re-register (which would throw).
  final viewType = 'pdf-iframe-${url.hashCode}';

  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('loading', 'eager')
        ..setAttribute('allow', 'fullscreen'),
    );
    _registered.add(viewType);
  }

  return HtmlElementView(viewType: viewType);
}
