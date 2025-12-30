import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

// Platform-specific imports for WebView configuration
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../services/mautic_auth_service.dart';

// Conditional imports for web vs mobile/desktop
import 'mautic_web_view_stub.dart'
    if (dart.library.html) 'mautic_web_view_web.dart'
    if (dart.library.io) 'mautic_web_view_mobile.dart';

/// Screen that embeds Mautic in a WebView with automatic authentication via Edge Function
///
/// **Web Platform:** Uses iframe that loads the auto-login URL from Edge Function
/// **Mobile/Desktop:** Uses WebView that loads the auto-login URL
class MauticEmbedScreen extends StatefulWidget {
  /// Optional initial path in Mautic to navigate to (e.g., '/s/emails')
  final String? initialPath;

  const MauticEmbedScreen({
    Key? key,
    this.initialPath,
  }) : super(key: key);

  @override
  State<MauticEmbedScreen> createState() => _MauticEmbedScreenState();
}

class _MauticEmbedScreenState extends State<MauticEmbedScreen> {
  final MauticAuthService _authService = MauticAuthService();

  WebViewController? _controller;
  bool _isInitializing = true;
  bool _isLoading = true;
  String? _error;
  String? _loginUrl;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      // Get the auto-login URL from Edge Function
      final loginUrl = await _authService.getMauticLoginUrl(
        redirect: widget.initialPath ?? '/s/dashboard',
      );

      _loginUrl = loginUrl;

      if (kIsWeb) {
        // Web: iframe handles everything automatically
        debugPrint('Mautic: Using web iframe with auto-login URL');
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
      } else {
        // Mobile/Desktop: Set up WebView
        debugPrint('Mautic: Starting mobile/desktop WebView initialization...');
        await _setupWebView(loginUrl);
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Mautic: Initialization failed: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isInitializing = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _setupWebView(String loginUrl) async {
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
          debugPrint('Mautic: Page started: $url');
          if (mounted) {
            setState(() => _isLoading = true);
          }
        },
        onPageFinished: (String url) {
          debugPrint('Mautic: Page finished: $url');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('Mautic: WebView error: ${error.description}');
          if (error.isForMainFrame == true && mounted) {
            setState(() {
              _error = 'Page load error: ${error.description}';
              _isLoading = false;
            });
          }
        },
        onHttpError: (HttpResponseError error) {
          debugPrint('Mautic: HTTP error: ${error.response?.statusCode}');
        },
        onNavigationRequest: (request) {
          // Allow all navigation within Mautic
          if (request.url.contains('email.moyd.app')) {
            return NavigationDecision.navigate;
          }
          // Block other navigation (could open in external browser if needed)
          return NavigationDecision.navigate;
        },
      ),
    );

    // Load the auto-login URL
    await controller.loadRequest(Uri.parse(loginUrl));

    _controller = controller;
  }

  Future<void> _refresh() async {
    if (kIsWeb) {
      // Trigger rebuild for web iframe
      setState(() {
        _isLoading = true;
      });
      await _initialize();
    } else if (_controller != null) {
      // Re-authenticate to get fresh URL
      setState(() {
        _isLoading = true;
      });
      try {
        final loginUrl = await _authService.getMauticLoginUrl(
          redirect: widget.initialPath ?? '/s/dashboard',
        );
        _loginUrl = loginUrl;
        await _controller!.loadRequest(Uri.parse(loginUrl));
      } catch (e) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } else {
      await _initialize();
    }
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get a fresh login URL for the new path
      final loginUrl = await _authService.getMauticLoginUrl(redirect: path);
      _loginUrl = loginUrl;

      if (kIsWeb) {
        // For web, we need to reinitialize with new URL
        setState(() {
          _isLoading = false;
        });
      } else if (_controller != null) {
        await _controller!.loadRequest(Uri.parse(loginUrl));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Navigation failed: ${e.toString().replaceAll('Exception: ', '')}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Error state
    if (_error != null) {
      return _buildErrorView();
    }

    // Initializing state
    if (_isInitializing) {
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
      // Web: Use iframe with authenticated URL
      return MauticIframe(
        loginUrl: _loginUrl!,
        onRefresh: _refresh,
        onNavigate: _navigateTo,
      );
    } else if (_controller != null) {
      // Mobile/Desktop: Use WebView
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Mautic',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
}
