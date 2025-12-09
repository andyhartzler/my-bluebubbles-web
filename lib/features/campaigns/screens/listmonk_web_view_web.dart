import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:async';

import '../../../services/credential_storage_service.dart';

/// Web-specific iframe widget for Listmonk with automatic Basic Auth
/// Uses HTTP Basic Authentication embedded in the URL for auto-login
/// Falls back to manual login prompt on browsers that block credentials in iframes (Chrome)
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
  String? _errorMessage;
  bool _showLoginHelp = false;
  Timer? _loginCheckTimer;

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

  Future<void> _registerIframe() async {
    debugPrint('📧 Listmonk: Initializing with Basic Auth');

    try {
      // Get credentials from secure storage
      final username =
          await CredentialStorageService.getListmonkUsername() ?? 'admin';
      final password =
          await CredentialStorageService.getListmonkPassword() ?? 'fucktrump67';

      // Extract the base host from the source URL
      final uri = Uri.parse(widget.src);
      final baseHost = uri.host;
      final path = uri.path;

      // Build URL with Basic Auth embedded: https://username:password@host/path
      final authenticatedUrl = 'https://$username:$password@$baseHost$path';

      // Create unique iframe ID
      final iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';

      html.IFrameElement? iframeElement;

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
            // Prevent credentials from leaking in referrer header
            ..setAttribute('referrerpolicy', 'no-referrer');

          iframeElement = iframe;

          iframe.onLoad.listen((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              debugPrint('📧 Listmonk: Iframe loaded');

              // Check if we're still on login page after a delay
              // This helps detect when Basic Auth in URL doesn't work (Chrome)
              _loginCheckTimer = Timer(const Duration(seconds: 2), () {
                _checkLoginState(iframe);
              });
            }
          });

          iframe.onError.listen((event) {
            if (mounted) {
              debugPrint('❌ Listmonk: Load error: $event');
              setState(() {
                _isLoading = false;
                _errorMessage = 'Failed to load Email Campaigns';
              });
            }
          });

          return iframe;
        },
      );

      debugPrint('📧 Listmonk: Iframe registered with Basic Auth URL');

      if (mounted) {
        setState(() {
          _iframeId = iframeId;
          _isRegistered = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Listmonk: Error registering iframe: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  void _checkLoginState(html.IFrameElement iframe) {
    try {
      // Try to check if we can access the iframe content
      // If we get an error, it might be cross-origin or on login page
      final contentWindow = iframe.contentWindow;
      if (contentWindow != null) {
        try {
          // Try to access the location (this will fail for cross-origin)
          // Cast to html.Location to access href property
          final locationBase = contentWindow.location;
          final location = (locationBase is html.Location)
              ? (locationBase as html.Location).href
              : iframe.src ?? '';

          debugPrint('📧 Listmonk: Current URL: $location');

          // If URL contains 'login', show help
          if (location.contains('login') || location.contains('admin/login')) {
            debugPrint('⚠️ Listmonk: Still on login page, Basic Auth may not work in this browser');
            if (mounted) {
              setState(() {
                _showLoginHelp = true;
              });
            }
          }
        } catch (e) {
          // Cross-origin access blocked - this is expected
          // We can't tell if on login page, but assume Basic Auth worked
          debugPrint('📧 Listmonk: Cross-origin (expected), assuming authenticated');
        }
      }
    } catch (e) {
      debugPrint('📧 Listmonk: Could not check login state: $e');
    }
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

    // Show iframe with loading overlay and optional login help
    return Stack(
      children: [
        HtmlElementView(viewType: _iframeId!),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Email Campaigns...'),
                ],
              ),
            ),
          ),

        // Login credentials banner (shows if Basic Auth didn't work)
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
                                        'admin',
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
                                        'fucktrump67',
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
                      onPressed: () {
                        setState(() {
                          _showLoginHelp = false;
                        });
                      },
                      color: Colors.blue[700],
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
