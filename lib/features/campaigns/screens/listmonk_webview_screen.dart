import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Simple WebView screen that embeds Listmonk's full UI
/// Listmonk handles everything: campaigns, subscribers, templates, analytics
/// This screen integrates seamlessly into the app's existing layout
class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({super.key});

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  // Listmonk instance URL
  static const String listmonkUrl = 'https://mail.moyd.app';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize WebView: $e';
      });
    }
  }

  void _reload() {
    if (_controller != null) {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      _controller!.reload();
    } else {
      _initializeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header bar with actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.email,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Campaigns',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Powered by Listmonk',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
                tooltip: 'Reload Listmonk',
                color: theme.colorScheme.primary,
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHelp(context),
                tooltip: 'Help',
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),

        // WebView content
        Expanded(
          child: _buildContent(context, theme),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    if (_errorMessage != null) {
      return _buildErrorView(context, theme);
    }

    return Stack(
      children: [
        // WebView
        if (_controller != null)
          WebViewWidget(controller: _controller!),

        // Loading indicator
        if (_isLoading)
          Container(
            color: theme.colorScheme.surface.withOpacity(0.95),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading Listmonk...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 72,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Listmonk',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _showHelp(context),
              child: const Text('Learn More'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('About Email Campaigns'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Listmonk Integration',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This page displays Listmonk, a professional email campaign platform integrated directly into your CRM.',
              ),
              const SizedBox(height: 16),
              Text(
                'Features',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildHelpItem('Create and send email campaigns'),
              _buildHelpItem('Design emails with professional templates'),
              _buildHelpItem('Manage subscriber lists'),
              _buildHelpItem('Track campaign analytics and engagement'),
              _buildHelpItem('Schedule campaigns for optimal delivery'),
              const SizedBox(height: 16),
              Text(
                'Automatic Subscriber Sync',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildHelpItem('Donors → Newsletter + Donors lists', Icons.volunteer_activism),
              _buildHelpItem('Event Attendees → Newsletter + Event Attendees', Icons.event),
              _buildHelpItem('Members → Members list', Icons.groups),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscribers sync automatically from your CRM. No manual imports needed!',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
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

  Widget _buildHelpItem(String text, [IconData icon = Icons.check_circle_outline]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
