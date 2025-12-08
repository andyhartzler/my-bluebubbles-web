import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

// Platform-specific imports for WebView configuration
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../services/listmonk_auth_service.dart';

// Conditional imports for web vs mobile/desktop
import 'listmonk_web_view_stub.dart'
    if (dart.library.html) 'listmonk_web_view_web.dart'
    if (dart.library.io) 'listmonk_web_view_mobile.dart';

/// WebView screen that embeds Listmonk's full UI with auto-authentication
/// Platform-aware: uses iframe on web, WebView on mobile/desktop with multi-layer auto-login
class ListmonkWebViewScreen extends StatefulWidget {
  const ListmonkWebViewScreen({Key? key}) : super(key: key);

  @override
  State<ListmonkWebViewScreen> createState() => _ListmonkWebViewScreenState();
}

class _ListmonkWebViewScreenState extends State<ListmonkWebViewScreen> {
  WebViewController? _controller;
  bool _isInitializing = true;
  bool _isLoading = true;
  String? _error;
  String? _sessionCookie;
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
      // Initialize auth service
      await ListmonkAuthService.init();

      if (kIsWeb) {
        // Web uses iframe - auto-login handled in the iframe widget
        debugPrint('Listmonk: Using web iframe implementation');
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
      } else {
        // Mobile/Desktop: Try to pre-authenticate first
        debugPrint('Listmonk: Starting mobile/desktop initialization...');

        // Step 1: Attempt pre-authentication to get session cookie
        _sessionCookie = await ListmonkAuthService.authenticate();
        if (_sessionCookie != null) {
          debugPrint('Listmonk: Pre-auth successful, got session cookie');
        } else {
          debugPrint('Listmonk: Pre-auth failed, will use JS auto-login');
        }

        // Step 2: Set up WebView
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

    // Inject cookie if we have one
    if (_sessionCookie != null) {
      await _injectCookie(controller);
    }

    // Load the admin page
    final headers = <String, String>{};
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    await controller.loadRequest(
      Uri.parse('${ListmonkAuthService.listmonkUrl}/admin'),
      headers: headers,
    );

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

  Future<void> _injectCookie(WebViewController controller) async {
    if (_sessionCookie == null) return;

    debugPrint('Listmonk: Injecting session cookie...');

    try {
      final cookieManager = WebViewCookieManager();

      // Parse cookie
      final parts = _sessionCookie!.split('=');
      if (parts.length >= 2) {
        final name = parts[0];
        final value = parts.sublist(1).join('=');

        await cookieManager.setCookie(
          WebViewCookie(
            name: name,
            value: value,
            domain: 'mail.moyd.app',
            path: '/',
          ),
        );
        debugPrint('Listmonk: Cookie injected successfully');
      }
    } catch (e) {
      debugPrint('Listmonk: Cookie injection failed: $e');
    }
  }

  Future<void> _attemptAutoLogin() async {
    if (_controller == null) return;

    _loginAttempts++;
    if (_loginAttempts > _maxLoginAttempts) {
      debugPrint('Listmonk: Max login attempts reached');
      return;
    }

    debugPrint('Listmonk: Auto-login attempt $_loginAttempts of $_maxLoginAttempts');

    // Get the comprehensive auto-login JavaScript from the service
    final jsCode = await ListmonkAuthService.generateAutoLoginJs();
    _controller!.runJavaScript(jsCode);
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
      appBar: AppBar(
        title: const Text('Email Campaigns'),
        backgroundColor: const Color(0xFF273351),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isInitializing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(),
    );
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
      // Web: Use iframe with API-based auth
      return Stack(
        children: [
          const Iframe(src: '${ListmonkAuthService.listmonkUrl}/admin'),
          if (_isLoading)
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF273351)),
              ),
            ),
        ],
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
