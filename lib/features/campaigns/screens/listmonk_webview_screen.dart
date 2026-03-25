import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

// Platform-specific imports for WebView configuration
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../services/credential_storage_service.dart';

// Conditional imports for web vs mobile/desktop
import 'listmonk_web_view_stub.dart'
    if (dart.library.html) 'listmonk_web_view_web.dart'
    if (dart.library.io) 'listmonk_web_view_mobile.dart';

/// WebView screen that embeds Listmonk's full UI with auto-authentication
///
/// **Web Platform:** Uses iframe with HTTP Basic Auth embedded in URL (no CORS issues)
/// **Mobile/Desktop:** Uses WebView with JavaScript auto-login form filling
class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({Key? key}) : super(key: key);

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  static const String _listmonkUrl = 'https://mail.moyd.app';

  WebViewController? _controller;
  bool _isInitializing = true;
  bool _isLoading = true;
  String? _error;
  int _loginAttempts = 0;
  static const int _maxLoginAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _error = null;
      _loginAttempts = 0;
    });

    try {
      if (kIsWeb) {
        // Web: iframe with Basic Auth handles everything automatically
        debugPrint('📧 Listmonk: Using web iframe with Basic Auth');
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
      } else {
        // Mobile/Desktop: Set up WebView with JS auto-login
        debugPrint('Listmonk: Starting mobile/desktop initialization...');
        await _setupWebView();
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Listmonk: Initialization failed: $e');
      setState(() {
        _error = 'Failed to initialize: $e';
        _isInitializing = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _setupWebView() async {
    // Platform-specific configuration
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS/macOS configuration
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);

    // Basic configuration
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.white);

    // Enable debugging on Android
    if (controller.platform is AndroidWebViewController) {
      await AndroidWebViewController.enableDebugging(true);
    }

    // Set up navigation handling
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          if (mounted && progress == 100) {
            setState(() => _isLoading = false);
          }
        },
        onPageStarted: (String url) {
          debugPrint('Listmonk: Page started: $url');
          if (mounted) {
            setState(() => _isLoading = true);
          }
        },
        onPageFinished: (String url) {
          debugPrint('Listmonk: Page finished: $url');
          if (mounted) {
            setState(() => _isLoading = false);
          }

          // Check if we're on login page and need to auto-fill
          if (_isLoginPage(url)) {
            debugPrint('Listmonk: Login page detected, attempting auto-fill...');
            _attemptAutoLogin();
          }
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('Listmonk: WebView error: ${error.description}');
          if (error.isForMainFrame == true && mounted) {
            setState(() {
              _error = 'Page load error: ${error.description}';
              _isLoading = false;
            });
          }
        },
        onHttpError: (HttpResponseError error) {
          debugPrint('Listmonk: HTTP error: ${error.response?.statusCode}');
        },
      ),
    );

    // Set up JavaScript channel for communication
    await controller.addJavaScriptChannel(
      'FlutterBridge',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('Listmonk: JS Message: ${message.message}');
        _handleJsMessage(message.message);
      },
    );

    // Load the admin page
    await controller.loadRequest(Uri.parse('$_listmonkUrl/admin'));

    _controller = controller;
  }

  bool _isLoginPage(String url) {
    final lowerUrl = url.toLowerCase();
    // Match login page but not actual admin content pages
    return lowerUrl.contains('/admin/login') ||
        (lowerUrl.endsWith('/admin') || lowerUrl.endsWith('/admin/')) &&
            !lowerUrl.contains('/admin/campaigns') &&
            !lowerUrl.contains('/admin/subscribers') &&
            !lowerUrl.contains('/admin/lists') &&
            !lowerUrl.contains('/admin/templates') &&
            !lowerUrl.contains('/admin/settings');
  }

  Future<void> _attemptAutoLogin() async {
    if (_controller == null) return;

    _loginAttempts++;
    if (_loginAttempts > _maxLoginAttempts) {
      debugPrint('Listmonk: Max login attempts reached');
      return;
    }

    debugPrint('Listmonk: Auto-login attempt $_loginAttempts of $_maxLoginAttempts');

    // Get credentials from secure storage
    final username =
        await CredentialStorageService.getListmonkUsername() ?? 'admin';
    final password =
        await CredentialStorageService.getListmonkPassword() ?? 'fucktrump67';

    // Generate auto-login JavaScript
    final jsCode = _generateAutoLoginJs(username, password);
    _controller!.runJavaScript(jsCode);
  }

  String _generateAutoLoginJs(String username, String password) {
    return '''
(function() {
  console.log('MOYD Auto-login script starting...');

  const USERNAME = '$username';
  const PASSWORD = '$password';
  const MAX_ATTEMPTS = 15;
  const RETRY_DELAY = 300;

  let attempts = 0;

  function log(msg) {
    console.log('[MOYD] ' + msg);
    try {
      if (window.FlutterBridge) {
        FlutterBridge.postMessage(JSON.stringify({type: 'log', message: msg}));
      }
    } catch(e) { console.log('FlutterBridge.postMessage error: ' + e); }
  }

  function findElement(selectors) {
    for (const selector of selectors) {
      const el = document.querySelector(selector);
      if (el) return el;
    }
    return null;
  }

  function setInputValue(input, value) {
    input.value = '';
    input.focus();

    try {
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, 'value'
      ).set;
      setter.call(input, value);
    } catch(e) {
      input.value = value;
    }

    ['input', 'change', 'blur', 'keyup'].forEach(eventType => {
      input.dispatchEvent(new Event(eventType, { bubbles: true, cancelable: true }));
    });
  }

  function attemptLogin() {
    attempts++;
    log('Attempt ' + attempts + '/' + MAX_ATTEMPTS);

    const usernameSelectors = [
      'input[name="username"]',
      'input[name="email"]',
      'input[type="text"]:not([type="hidden"])',
      'input[type="email"]'
    ];

    const passwordSelectors = [
      'input[name="password"]',
      'input[type="password"]'
    ];

    const submitSelectors = [
      'button[type="submit"]',
      'input[type="submit"]',
      'form button:not([type="button"])'
    ];

    const usernameField = findElement(usernameSelectors);
    const passwordField = findElement(passwordSelectors);
    const submitButton = findElement(submitSelectors);

    log('Found - Username: ' + !!usernameField + ', Password: ' + !!passwordField + ', Submit: ' + !!submitButton);

    if (usernameField && passwordField) {
      log('Filling credentials...');
      setInputValue(usernameField, USERNAME);

      setTimeout(() => {
        setInputValue(passwordField, PASSWORD);
        log('Credentials filled, submitting...');

        setTimeout(() => {
          if (submitButton) {
            submitButton.click();
            log('Clicked submit button');
          } else {
            const form = document.querySelector('form');
            if (form) {
              form.submit();
              log('Form submitted');
            }
          }
        }, 300);
      }, 100);

      return true;
    }

    if (attempts < MAX_ATTEMPTS) {
      setTimeout(attemptLogin, RETRY_DELAY);
    } else {
      log('Max attempts reached, elements not found');
    }

    return false;
  }

  const isLoginPage = window.location.href.includes('/login') ||
                      document.querySelector('form input[type="password"]');

  if (!isLoginPage) {
    log('Not on login page, skipping auto-login');
    return;
  }

  setTimeout(attemptLogin, 500);
})();
''';
  }

  void _handleJsMessage(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'log':
          debugPrint('Listmonk JS: ${data['message']}');
          break;
        case 'login_attempted':
          debugPrint('Listmonk: Login attempt completed');
          break;
        case 'login_failed':
          debugPrint('Listmonk: Login failed: ${data['reason']}');
          break;
        case 'already_logged_in':
          debugPrint('Listmonk: Already logged in');
          break;
      }
    } catch (e) {
      debugPrint('Listmonk JS (raw): $message');
    }
  }

  Future<void> _refresh() async {
    if (kIsWeb) {
      // Trigger rebuild for web iframe
      setState(() {
        _isLoading = true;
      });
      await Future.delayed(Duration.zero);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } else if (_controller != null) {
      setState(() {
        _isLoading = true;
        _loginAttempts = 0;
      });
      await _controller!.reload();
    } else {
      await _initialize();
    }
  }

  Future<void> _retry() async {
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  void _openInNewTab() {
    // This will be handled by the web implementation
    // For non-web platforms, this button won't be shown effectively
  }

  Widget _buildBody() {
    // Error state (only for mobile/desktop)
    if (_error != null && !kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to Load',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF273351),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Initializing state (only for mobile/desktop)
    if (_isInitializing && !kIsWeb) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF273351)),
            SizedBox(height: 16),
            Text(
              'Connecting to Email Campaigns...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Platform-specific view
    if (kIsWeb) {
      // Web: Use iframe with SSO authentication via Supabase Edge Function
      return Iframe(
        src: '$_listmonkUrl/admin',
      );
    } else if (_controller != null) {
      // Mobile/Desktop: Use WebView with JS auto-login
      return Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF273351)),
              ),
            ),
        ],
      );
    }

    // Fallback loading state
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF273351)),
    );
  }
}
