import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';

/// Web-specific iframe widget for Listmonk with automatic postMessage-based login
/// Uses postMessage API to send credentials to Listmonk which has been configured
/// to receive and process login credentials automatically.
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
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _registerIframe();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _setupMessageListener() {
    _messageSubscription = html.window.onMessage.listen((event) {
      // Verify origin
      if (event.origin != _listmonkOrigin) {
        return;
      }

      final data = event.data;
      if (data is! Map) return;

      final messageType = data['type'];

      switch (messageType) {
        case 'MOYD_LOGIN_PAGE_READY':
          debugPrint('[MOYD Flutter] Login page ready, sending credentials...');
          _sendCredentials();
          break;

        case 'MOYD_LOGIN_RESULT':
          final success = data['success'] == true;
          final reason = data['reason'] as String?;

          if (success) {
            debugPrint('[MOYD Flutter] Login successful');
            if (mounted) {
              setState(() {
                _statusMessage = 'Logged in successfully';
                _isLoading = false;
              });
            }
          } else if (reason == 'already_logged_in') {
            debugPrint('[MOYD Flutter] Already logged in');
            if (mounted) {
              setState(() {
                _statusMessage = 'Already logged in';
                _isLoading = false;
              });
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

      debugPrint('[MOYD Flutter] Iframe registered with postMessage auth');

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

  void _sendCredentials() {
    if (_iframe?.contentWindow == null) {
      debugPrint('[MOYD Flutter] No iframe content window available');
      return;
    }

    debugPrint('[MOYD Flutter] Sending credentials via postMessage...');

    _iframe!.contentWindow!.postMessage({
      'type': 'MOYD_LOGIN_CREDENTIALS',
      'username': _username,
      'password': _password,
    }, _listmonkOrigin);

    _credentialsSent = true;

    if (mounted) {
      setState(() {
        _statusMessage = 'Authenticating...';
      });
    }

    // Set a timeout - if no response, hide loading anyway
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _refresh() {
    setState(() {
      _isLoading = true;
      _credentialsSent = false;
      _statusMessage = 'Refreshing...';
    });

    _iframe?.src = '${widget.src}?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  void _openInNewTab() {
    html.window.open(widget.src, '_blank');
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

    // Show iframe with loading overlay
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

        // Action buttons in top-right corner (only show when not loading)
        if (!_isLoading)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                Material(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                    color: Colors.grey[700],
                  ),
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
      ],
    );
  }
}
