// Stub for twake_previewer_flutter (Dart 3.7+ requirement, not on our 3.5.4
// baseline). tmail uses TwakePreviewer + supporting widgets for inline
// file preview (HTML/PDF/text/image). Phase 1 doesn't expose attachment
// preview — we expose no-op shims so imports resolve. Replace with the
// real package when bluebubbles upgrades to Flutter 3.7+.

import 'package:flutter/material.dart';

class TwakePreviewer extends StatelessWidget {
  final TwakePreviewerController? controller;
  final String? url;
  final String? mimeType;
  final Map<String, String>? headers;
  const TwakePreviewer({
    super.key,
    this.controller,
    this.url,
    this.mimeType,
    this.headers,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TwakePreviewerController {
  TwakePreviewerController();
  void dispose() {}
  void reload() {}
}

// ----- Per-format previewers -----
//
// Tmail's call sites pass `bytes`, `zoomable`, `previewerOptions`,
// `topBarOptions`, `loadingOptions`, `htmlViewOptions`, `mimeType`,
// `originalUrl`, `supportedCharset`, `onError` etc. We accept them all and
// return a shrunken sized box so the tree still builds.

class TwakeImagePreviewer extends StatelessWidget {
  final List<int>? bytes;
  final String? url;
  final String? originalUrl;
  final String? path;
  final bool? zoomable;
  final PreviewerOptions? previewerOptions;
  final TopBarOptions? topBarOptions;
  final LoadingOptions? loadingOptions;
  final ValueChanged<PreviewerState>? onStateChanged;
  final VoidCallback? onError;
  const TwakeImagePreviewer({
    super.key,
    this.bytes,
    this.url,
    this.originalUrl,
    this.path,
    this.zoomable,
    this.previewerOptions,
    this.topBarOptions,
    this.loadingOptions,
    this.onStateChanged,
    this.onError,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TwakePlainTextPreviewer extends StatelessWidget {
  final List<int>? bytes;
  final String? content;
  final String? url;
  final dynamic charset;
  final SupportedCharset? supportedCharset;
  final PreviewerOptions? previewerOptions;
  final TopBarOptions? topBarOptions;
  final LoadingOptions? loadingOptions;
  final ValueChanged<PreviewerState>? onStateChanged;
  final VoidCallback? onError;
  const TwakePlainTextPreviewer({
    super.key,
    this.bytes,
    this.content,
    this.url,
    this.charset,
    this.supportedCharset,
    this.previewerOptions,
    this.topBarOptions,
    this.loadingOptions,
    this.onStateChanged,
    this.onError,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TwakeHtmlPreviewer extends StatelessWidget {
  final List<int>? bytes;
  final String? html;
  final String? url;
  final String? originalUrl;
  final String? mimeType;
  final HtmlViewOptions? htmlViewOptions;
  final PreviewerOptions? previewerOptions;
  final TopBarOptions? topBarOptions;
  final LoadingOptions? loadingOptions;
  final ValueChanged<PreviewerState>? onStateChanged;
  final VoidCallback? onError;
  const TwakeHtmlPreviewer({
    super.key,
    this.bytes,
    this.html,
    this.url,
    this.originalUrl,
    this.mimeType,
    this.htmlViewOptions,
    this.previewerOptions,
    this.topBarOptions,
    this.loadingOptions,
    this.onStateChanged,
    this.onError,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TwakePdfPreviewer extends StatelessWidget {
  final List<int>? bytes;
  final String? url;
  final String? originalUrl;
  final String? path;
  final PreviewerOptions? previewerOptions;
  final LoadingOptions? loadingOptions;
  final TopBarOptions? topBarOptions;
  final ValueChanged<PreviewerState>? onStateChanged;
  final VoidCallback? onError;
  final VoidCallback? onTapOutside;
  const TwakePdfPreviewer({
    super.key,
    this.bytes,
    this.url,
    this.originalUrl,
    this.path,
    this.previewerOptions,
    this.loadingOptions,
    this.topBarOptions,
    this.onStateChanged,
    this.onError,
    this.onTapOutside,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ----- Configuration types -----

class PreviewerOptions {
  final bool? enableShare;
  final bool? enableDownload;
  final bool? enableZoom;
  final Color? backgroundColor;
  final PreviewerState? previewerState;
  final double? width;
  final double? height;
  final ValueChanged<dynamic>? onError;
  final String? errorMessage;
  const PreviewerOptions({
    this.enableShare,
    this.enableDownload,
    this.enableZoom,
    this.backgroundColor,
    this.previewerState,
    this.width,
    this.height,
    this.onError,
    this.errorMessage,
  });
}

class TopBarOptions {
  final String? title;
  final String? subtitle;
  final Color? backgroundColor;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? visible;
  final VoidCallback? onClose;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;
  final VoidCallback? onTapOutside;
  const TopBarOptions({
    this.title,
    this.subtitle,
    this.backgroundColor,
    this.actions,
    this.leading,
    this.visible,
    this.onClose,
    this.onDownload,
    this.onShare,
    this.onPrint,
    this.onTapOutside,
  });
}

class LoadingOptions {
  final Widget? loadingWidget;
  final Color? loadingColor;
  final String? errorMessage;
  final double? progress;
  final Color? progressColor;
  final String? text;
  const LoadingOptions({
    this.loadingWidget,
    this.loadingColor,
    this.errorMessage,
    this.progress,
    this.progressColor,
    this.text,
  });
}

class HtmlViewOptions {
  final Map<String, String>? headers;
  final String? baseUrl;
  final bool? jsEnabled;
  final bool? localStorageEnabled;
  final String? contentClassName;
  final TextDirection? direction;
  final dynamic mailtoDelegate;
  final bool? keepWidthWhileLoading;
  const HtmlViewOptions({
    this.headers,
    this.baseUrl,
    this.jsEnabled,
    this.localStorageEnabled,
    this.contentClassName,
    this.direction,
    this.mailtoDelegate,
    this.keepWidthWhileLoading,
  });
}

class PreviewerState {
  static const loading = PreviewerState._('loading');
  static const success = PreviewerState._('success');
  static const error = PreviewerState._('error');
  static const failure = PreviewerState._('failure');
  static const idle = PreviewerState._('idle');
  final String _v;
  const PreviewerState._(this._v);
  @override
  String toString() => 'PreviewerState($_v)';
}

class SupportedCharset {
  static const utf8 = SupportedCharset._('utf-8');
  static const ascii = SupportedCharset._('ascii');
  static const latin1 = SupportedCharset._('iso-8859-1');
  final String _v;
  const SupportedCharset._(this._v);
}
