import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/credential_storage_service.dart';
// Conditional imports for web vs mobile/desktop
import 'listmonk_web_view_stub.dart'
    if (dart.library.html) 'listmonk_web_view_web.dart'
    if (dart.library.io) 'listmonk_web_view_mobile.dart';

/// Simple WebView screen that embeds Listmonk's full UI
/// Platform-aware: uses iframe on web, WebView on mobile/desktop with auto-login
class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({Key? key}) : super(key: key);

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _username;
  String? _password;

  static const String listmonkUrl = 'https://mail.moyd.app/admin';

  @override
  void initState() {
    super.initState();
    _initializeView();
  }

  void _initializeView() {
    if (kIsWeb) {
      // Web uses iframe - auto-login happens via API call
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } else {
      // Mobile/Desktop uses WebView with JavaScript auto-login
      _initializeWebView();
    }
  }

  Future<void> _initializeWebView() async {
    // Load credentials from secure storage
    _username = await CredentialStorageService.getListmonkUsername();
    _password = await CredentialStorageService.getListmonkPassword();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }

            // Auto-login when we hit the login page
            // Match both /admin/login and /admin/login?next=...
            if (url.contains('/admin/login') ||
                (url.contains('/admin') && !url.contains('/admin/campaigns') && !url.contains('/admin/subscribers'))) {
              _performAutoLogin();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(listmonkUrl));

    if (mounted) {
      setState(() {});
    }
  }

  void _performAutoLogin() {
    if (_controller == null || _username == null || _password == null) {
      debugPrint('❌ Cannot auto-login: controller or credentials missing');
      return;
    }

    final jsCode = '''
      (function() {
        console.log('🔐 Starting auto-login...');

        function attemptLogin() {
          // Find username/email field with multiple selectors
          const usernameField =
            document.querySelector('input[name="username"]') ||
            document.querySelector('input[name="email"]') ||
            document.querySelector('input[id="username"]') ||
            document.querySelector('input[id="email"]') ||
            document.querySelector('input[type="text"]') ||
            document.querySelector('input[type="email"]') ||
            document.querySelector('input[placeholder*="username" i]') ||
            document.querySelector('input[placeholder*="email" i]');

          // Find password field
          const passwordField =
            document.querySelector('input[name="password"]') ||
            document.querySelector('input[id="password"]') ||
            document.querySelector('input[type="password"]');

          // Find submit button
          const loginButton =
            document.querySelector('button[type="submit"]') ||
            document.querySelector('form button') ||
            document.querySelector('.btn-primary') ||
            document.querySelector('input[type="submit"]') ||
            document.querySelector('button');

          if (usernameField && passwordField && loginButton) {
            console.log('✅ Found all form elements');

            // Fill in the credentials
            usernameField.value = '$_username';
            passwordField.value = '$_password';

            // Trigger events that forms might be listening for
            const inputEvent = new Event('input', { bubbles: true });
            const changeEvent = new Event('change', { bubbles: true });

            usernameField.dispatchEvent(inputEvent);
            usernameField.dispatchEvent(changeEvent);
            passwordField.dispatchEvent(inputEvent);
            passwordField.dispatchEvent(changeEvent);

            console.log('📝 Credentials filled');

            // Submit after a short delay
            setTimeout(function() {
              loginButton.click();
              console.log('🚀 Login submitted');
            }, 300);

            return true;
          } else {
            console.log('❌ Form elements not found yet');
            console.log('Username field:', !!usernameField);
            console.log('Password field:', !!passwordField);
            console.log('Login button:', !!loginButton);
            return false;
          }
        }

        // Try immediately
        if (!attemptLogin()) {
          // If not found, try again after delays
          setTimeout(attemptLogin, 500);
          setTimeout(attemptLogin, 1000);
          setTimeout(attemptLogin, 2000);
          setTimeout(attemptLogin, 3000);
        }
      })();
    ''';

    _controller!.runJavaScript(jsCode);
  }

  Future<void> _reload() async {
    if (kIsWeb) {
      setState(() {
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
        _isLoading = true;
      });
      await _controller!.reload();
    } else {
      _initializeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Platform-specific view
          if (kIsWeb)
            // Web: Use iframe with API-based auth
            const Iframe(src: listmonkUrl)
          else if (_controller != null)
            // Mobile/Desktop: Use WebView with JS auto-login
            WebViewWidget(controller: _controller!),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
