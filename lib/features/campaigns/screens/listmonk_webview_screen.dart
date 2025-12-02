import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Simple WebView screen that embeds Listmonk's full UI
/// Listmonk handles everything: campaigns, subscribers, templates, analytics
class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({super.key});

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  // CRITICAL: Update this URL to your deployed Listmonk instance
  static const String listmonkUrl = 'https://mail.moyd.app';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Failed to load Listmonk: ${error.description}';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within Listmonk
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(listmonkUrl));
  }

  void _reload() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Campaigns'),
        backgroundColor: const Color(0xFF1E3A8A), // MOYD blue
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
            tooltip: 'Help',
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          if (_errorMessage == null)
            WebViewWidget(controller: _controller),

          // Error message
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading && _errorMessage == null)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading Listmonk...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Email Campaigns'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This page displays Listmonk, your email campaign platform.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('What you can do in Listmonk:'),
              SizedBox(height: 8),
              Text('• Create and send email campaigns'),
              Text('• Design emails with templates'),
              Text('• View subscriber lists'),
              Text('• Track campaign analytics'),
              Text('• Manage email templates'),
              SizedBox(height: 16),
              Text(
                'Subscribers sync automatically:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Donors → Newsletter + Donors lists'),
              Text('• Event Attendees → Newsletter + Event Attendees lists'),
              Text('• Members → Members list'),
              SizedBox(height: 16),
              Text(
                'Need help? Check the Listmonk documentation or contact your administrator.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
