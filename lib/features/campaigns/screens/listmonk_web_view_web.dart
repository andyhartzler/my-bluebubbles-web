import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';

/// Web-specific iframe widget for Listmonk
///
/// Modern browsers block embedded credentials in URLs (e.g., https://user:pass@host/)
/// so this widget loads the plain URL and shows a credentials banner for manual login.
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  String? _iframeId;
  bool _isLoading = true;
  bool _isRegistered = false;
  String _statusMessage = 'Loading Listmonk...';
  String? _errorMessage;
  bool _showLoginHelp = false;
  bool _helpDismissed = false;
  Timer? _loginCheckTimer;
  final String _username = 'admin';
  final String _password = 'fucktrump67';

  @override
  void initState() {
    super.initState();
    _registerIframe();
  }

  @override
  void dispose() {
    _loginCheckTimer?.cancel();
    super.dispose();
  }

  void _registerIframe() {
    try {
      // Create unique iframe ID
      final iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';

      // Use the plain URL - embedded credentials are blocked by modern browsers
      // Users will need to login manually using the credentials banner
      debugPrint('📧 Listmonk: Loading without embedded credentials (blocked by browsers)');

      final iframe = html.IFrameElement()
        ..src = widget.src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'clipboard-read; clipboard-write'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('loading', 'eager')
        ..setAttribute('referrerpolicy', 'no-referrer');

      // Handle iframe load event
      iframe.onLoad.listen((_) {
        debugPrint('📧 Listmonk: Iframe loaded');
        if (mounted) {
          setState(() {
            _statusMessage = 'Logged in successfully';
            _isLoading = false;
          });

          // Multi-layer detection strategy
          _startLoginDetection();
        }
      });

      iframe.onError.listen((event) {
        if (mounted) {
          debugPrint('📧 Listmonk: Load error: $event');
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
      debugPrint('📧 Listmonk: Error registering iframe: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  void _startLoginDetection() {
    // Show credentials immediately for all browsers since embedded credentials
    // are blocked by modern browsers - users need to login manually
    if (!_helpDismissed) {
      _loginCheckTimer = Timer(const Duration(milliseconds: 500), () {
        debugPrint('📧 Listmonk: Showing credentials banner for manual login');
        if (mounted && !_helpDismissed) {
          setState(() {
            _showLoginHelp = true;
          });
        }
      });
    }
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

  void _openInNewTab() {
    html.window.open(widget.src, '_blank');
    debugPrint('📧 Listmonk: Opened in new tab');
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
                    const SizedBox(width: 8),
                    // Open in new tab button
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: _openInNewTab,
                      color: Colors.blue[700],
                      tooltip: 'Open in new tab',
                    ),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _dismissHelp,
                      color: Colors.blue[700],
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline, color: Colors.white, size: 18),
                      SizedBox(width: 8),
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
