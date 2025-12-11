import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';

import '../../../services/credential_storage_service.dart';

/// Web-specific iframe widget for Listmonk with robust authentication handling
///
/// Multi-layer authentication strategy:
/// 1. Tries HTTP Basic Auth in URL (works in Safari)
/// 2. Detects browser type and shows credentials proactively for Chrome
/// 3. Provides always-visible "Show Login Help" button as ultimate fallback
/// 4. Multiple detection methods with timeouts
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  static const String _listmonkOrigin = 'https://mail.moyd.app';

  // Listmonk credentials
  static const String _username = 'admin';
  static const String _password = 'fucktrump67';

  String? _iframeId;
  html.IFrameElement? _iframe;
  bool _isLoading = true;
  bool _isRegistered = false;
  bool _credentialsSent = false;
  String _statusMessage = 'Loading Listmonk...';
  String? _errorMessage;
  bool _showLoginHelp = false;
  bool _helpDismissed = false;
  Timer? _loginCheckTimer;
  Timer? _fallbackTimer;
  String _username = 'admin';
  String _password = 'fucktrump67';

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _registerIframe();
  }

  @override
  void dispose() {
    _loginCheckTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  /// Detect if this is Safari (which supports Basic Auth in iframes)
  bool get _isSafari {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('safari') && !userAgent.contains('chrome');
  }

  Future<void> _registerIframe() async {
    debugPrint('📧 Listmonk: Initializing with multi-layer auth strategy');

    try {
      // Get credentials from secure storage
      _username = await CredentialStorageService.getListmonkUsername() ?? 'admin';
      _password = await CredentialStorageService.getListmonkPassword() ?? 'fucktrump67';

      final data = event.data;
      if (data is! Map) return;

      // Build URL with Basic Auth embedded
      final authenticatedUrl = 'https://$_username:$_password@$baseHost$path';

      debugPrint('📧 Listmonk: Browser detection - Safari: $_isSafari');

      // For non-Safari browsers, proactively show help after loading
      // (Chrome/Firefox/Edge block Basic Auth in iframes)
      if (!_isSafari) {
        debugPrint('⚠️ Listmonk: Non-Safari browser detected, will show credentials proactively');
      }

      switch (messageType) {
        case 'MOYD_LOGIN_PAGE_READY':
          debugPrint('[MOYD Flutter] Login page ready, sending credentials...');
          _sendCredentials();
          break;

      // Register the view factory
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        iframeId,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = authenticatedUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allow = 'clipboard-read; clipboard-write'
            ..setAttribute('loading', 'eager')
            ..setAttribute('referrerpolicy', 'no-referrer');

          iframe.onLoad.listen((_) {
            if (mounted) {
              setState(() {
                _statusMessage = 'Logged in successfully';
                _isLoading = false;
              });
              debugPrint('📧 Listmonk: Iframe loaded');

              // Multi-layer detection strategy
              _startLoginDetection();
            }
          } else {
            debugPrint('[MOYD Flutter] Login failed: $reason');
            if (mounted) {
              setState(() {
                _statusMessage = 'Login failed - please try manually';
                _isLoading = false;
              });
            }
          }
          break;
      }
    });
  }

  Future<void> _registerIframe() async {
    debugPrint('[MOYD Flutter] Initializing Listmonk iframe with postMessage auth');

    try {
      // Create unique iframe ID
      final iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';

      final iframe = html.IFrameElement()
        ..src = widget.src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'clipboard-read; clipboard-write'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('loading', 'eager');

      _iframe = iframe;

      // Handle iframe load event
      iframe.onLoad.listen((_) {
        debugPrint('[MOYD Flutter] Iframe loaded');

        // Give the page a moment to initialize its JS
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_credentialsSent) {
            _sendCredentials();
          }
        });

        // Also try after a longer delay in case page is slow
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isLoading && !_credentialsSent) {
            debugPrint('[MOYD Flutter] Retry sending credentials...');
            _sendCredentials();
          }
        });
      });

      iframe.onError.listen((event) {
        if (mounted) {
          debugPrint('[MOYD Flutter] Load error: $event');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load Email Campaigns';
          });
        }
      });

      // Register the view factory
      ui_web.platformViewRegistry.registerViewFactory(
        iframeId,
        (int viewId) => iframe,
      );

      debugPrint('📧 Listmonk: Iframe registered');

      if (mounted) {
        setState(() {
          _iframeId = iframeId;
          _isRegistered = true;
        });
      }
    } catch (e) {
      debugPrint('[MOYD Flutter] Error registering iframe: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  void _startLoginDetection() {
    // Strategy 1: For non-Safari browsers, show credentials immediately
    // (we know Basic Auth won't work)
    if (!_isSafari && !_helpDismissed) {
      _loginCheckTimer = Timer(const Duration(seconds: 1), () {
        debugPrint('📧 Listmonk: Showing credentials for non-Safari browser');
        if (mounted && !_helpDismissed) {
          setState(() {
            _showLoginHelp = true;
          });
        }
      });
    }

    // Strategy 2: Ultimate fallback - always show after 5 seconds if not dismissed
    // This ensures help is NEVER silently hidden when user needs it
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('📧 Listmonk: Fallback timer - ensuring credentials are available');
      if (mounted && !_showLoginHelp && !_helpDismissed) {
        debugPrint('⚠️ Listmonk: Auto-showing credentials banner (fallback)');
        setState(() {
          _showLoginHelp = true;
        });
      }
    });
  }

  void _dismissHelp() {
    setState(() {
      _showLoginHelp = false;
      _helpDismissed = true;
    });
    debugPrint('📧 Listmonk: User dismissed credentials banner');
  }

  void _showHelp() {
    setState(() {
      _showLoginHelp = true;
      _helpDismissed = false;
    });
    debugPrint('📧 Listmonk: User requested credentials banner');
  }

  @override
  Widget build(BuildContext context) {
    // Show error if registration failed
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                  _credentialsSent = false;
                  _statusMessage = 'Loading Listmonk...';
                });
                _registerIframe();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Wait for registration to complete before showing HtmlElementView
    if (!_isRegistered || _iframeId == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Email Campaigns...'),
            ],
          ),
        ),
      );
    }

    // Show iframe with loading overlay, credentials banner, and help button
    return Stack(
      children: [
        // Iframe
        HtmlElementView(viewType: _iframeId!),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.9),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Login credentials banner
        if (_showLoginHelp && !_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 4,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.key, color: Colors.blue[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Please use these credentials to login below',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Username:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SelectableText(
                                        _username,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          color: Colors.blue[900],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Password:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SelectableText(
                                        _password,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          color: Colors.blue[900],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _dismissHelp,
                      color: Colors.blue[700],
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 20),
                    onPressed: _openInNewTab,
                    tooltip: 'Open in new tab',
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

        // Always-visible "Show Login Help" button when banner is dismissed
        if (!_showLoginHelp && !_isLoading)
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(20),
              color: Colors.blue[700],
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showHelp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Show Login Credentials',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
