import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

import '../../../services/credential_storage_service.dart';

/// Web-specific iframe widget for Listmonk with automatic Basic Auth
/// Uses HTTP Basic Authentication embedded in the URL for auto-login
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  final String _iframeId =
      'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _registerIframe();
  }

  Future<void> _registerIframe() async {
    debugPrint('📧 Listmonk: Initializing with Basic Auth');

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

    try {
      // Register the view factory
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        _iframeId,
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

          iframe.onLoad.listen((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              debugPrint('📧 Listmonk: Loaded successfully');
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

  @override
  Widget build(BuildContext context) {
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

    return Stack(
      children: [
        HtmlElementView(viewType: _iframeId),
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
      ],
    );
  }
}
