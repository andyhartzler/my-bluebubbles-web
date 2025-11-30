import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

/// Widget that integrates the mail.moyd.app email builder via iframe
class EmailBuilderIframe extends StatefulWidget {
  /// Initial email design in JSON format (optional)
  final String? initialDesign;

  /// Callback when the user saves the email design
  final Function(String html, String designJson) onSave;

  /// Callback when the user cancels
  final VoidCallback? onCancel;

  const EmailBuilderIframe({
    super.key,
    this.initialDesign,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<EmailBuilderIframe> createState() => _EmailBuilderIframeState();
}

class _EmailBuilderIframeState extends State<EmailBuilderIframe> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isReady = false;

  static const String builderUrl = 'https://mail.moyd.app';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            // Load initial design if provided (after builder is ready)
            if (widget.initialDesign != null && _isReady) {
              _loadDesign(widget.initialDesign!);
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(builderUrl));
  }

  void _handleMessage(String messageJson) {
    try {
      final data = jsonDecode(messageJson) as Map<String, dynamic>;

      switch (data['action']) {
        case 'ready':
          setState(() {
            _isReady = true;
          });
          // Load initial design after builder is ready
          if (widget.initialDesign != null) {
            _loadDesign(widget.initialDesign!);
          }
          break;

        case 'save':
          final html = data['html'] as String;
          final design = data['design'] as String;
          widget.onSave(html, design);
          break;

        case 'error':
          _showError(data['error'] as String? ?? 'Unknown error occurred');
          break;

        default:
          debugPrint('Unknown message action: ${data['action']}');
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
      _showError('Failed to process builder message');
    }
  }

  void _loadDesign(String designJson) {
    if (!_isReady) {
      // Wait for ready signal
      return;
    }

    final message = jsonEncode({
      'type': 'LOAD_DESIGN',
      'design': designJson,
    });

    _controller.runJavaScript('''
      window.postMessage($message, '*');
    ''');
  }

  void _saveDesign() {
    _controller.runJavaScript('''
      window.postMessage({ type: 'SAVE_DESIGN' }, '*');
    ''');
  }

  void _resetEditor() {
    _controller.runJavaScript('''
      window.postMessage({ type: 'RESET_EDITOR' }, '*');
    ''');
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Designer'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (_isReady)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetEditor,
              tooltip: 'Reset Editor',
            ),
          if (_isReady)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton.icon(
                onPressed: _saveDesign,
                icon: const Icon(Icons.save),
                label: const Text('Save Design'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Loading indicator
          if (_isLoading || !_isReady)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading email builder...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
