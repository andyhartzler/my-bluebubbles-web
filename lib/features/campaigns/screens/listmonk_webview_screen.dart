import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/credential_storage_service.dart';

class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({Key? key}) : super(key: key);

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _username;
  String? _password;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // Load credentials
    _username = await CredentialStorageService.getListmonkUsername();
    _password = await CredentialStorageService.getListmonkPassword();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);

            // Auto-login whenever we hit the login page
            if (url.contains('/admin/login') || url.endsWith('/admin') || url.endsWith('/admin/')) {
              _performAutoLogin();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://mail.moyd.app/admin'));

    setState(() {});
  }

  void _performAutoLogin() {
    if (_username == null || _password == null) {
      debugPrint('Credentials not loaded');
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
        }
      })();
    ''';

    _controller.runJavaScript(jsCode);
  }

  Future<void> _refreshPage() async {
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPage,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
