import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
// Conditional imports for web vs mobile/desktop
import 'listmonk_web_view_stub.dart'
    if (dart.library.html) 'listmonk_web_view_web.dart'
    if (dart.library.io) 'listmonk_web_view_mobile.dart';

/// Simple WebView screen that embeds Listmonk's full UI
/// Listmonk handles everything: campaigns, subscribers, templates, analytics
/// This screen integrates seamlessly into the app's existing layout
/// Platform-aware: uses iframe on web, WebView on mobile/desktop
class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({super.key});

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  // Listmonk admin URL with auto-login
  static const String listmonkUrl = 'https://mail.moyd.app/admin';
  static const String listmonkUsername = 'admin';
  static const String listmonkPassword = 'fucktrump67';

  @override
  void initState() {
    super.initState();
    _initializeView();
  }

  void _initializeView() {
    if (kIsWeb) {
      // Web uses iframe - auto-login happens via iframe src
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Attempt auto-login via JavaScript after iframe loads
          _attemptWebAutoLogin();
        }
      });
    } else {
      _initializeWebView();
    }
  }

  void _attemptWebAutoLogin() {
    // For web platform, we'll inject JavaScript to auto-fill login
    // This needs to be done after iframe loads
    // Note: Due to cross-origin restrictions, this might not work
    // But we'll try to navigate directly to /admin which might have session
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
                // Attempt to auto-login after page loads
                _attemptAutoLogin(url);
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
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(listmonkUrl));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize WebView: $e';
        });
      }
    }
  }

  void _attemptAutoLogin(String currentUrl) {
    if (_controller == null) return;

    // Check if we're on the login page
    if (currentUrl.contains('/admin') || currentUrl.contains('login')) {
      // Inject JavaScript to auto-fill and submit login form
      final jsCode = '''
        (function() {
          try {
            // Wait a bit for the page to fully load
            setTimeout(function() {
              // Find username and password fields
              var usernameField = document.querySelector('input[name="username"]') ||
                                  document.querySelector('input[type="text"]') ||
                                  document.querySelector('input[placeholder*="username" i]');
              var passwordField = document.querySelector('input[name="password"]') ||
                                  document.querySelector('input[type="password"]');
              var submitButton = document.querySelector('button[type="submit"]') ||
                                 document.querySelector('input[type="submit"]') ||
                                 document.querySelector('button');

              if (usernameField && passwordField) {
                usernameField.value = '$listmonkUsername';
                passwordField.value = '$listmonkPassword';

                // Trigger input events to ensure form validation
                usernameField.dispatchEvent(new Event('input', { bubbles: true }));
                passwordField.dispatchEvent(new Event('input', { bubbles: true }));

                // Submit the form after a short delay
                setTimeout(function() {
                  if (submitButton) {
                    submitButton.click();
                  } else {
                    // Try to find and submit the form
                    var form = document.querySelector('form');
                    if (form) {
                      form.submit();
                    }
                  }
                }, 100);
              }
            }, 500);
          } catch(e) {
            console.log('Auto-login error:', e);
          }
        })();
      ''';

      _controller!.runJavaScript(jsCode);
    }
  }

  void _reload() {
    if (kIsWeb) {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      // Trigger rebuild which will recreate iframe
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } else if (_controller != null) {
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

    // Full-screen Listmonk iframe - no header bar for maximum space
    return _buildContent(context, theme);
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    if (_errorMessage != null) {
      return _buildErrorView(context, theme);
    }

    return Stack(
      children: [
        // Platform-specific view
        if (kIsWeb)
          // Simple iframe for web using HtmlElementView
          Iframe(src: listmonkUrl)
        else if (_controller != null)
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
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
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
            onPressed: () {
              Navigator.pop(dialogContext);
            },
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
