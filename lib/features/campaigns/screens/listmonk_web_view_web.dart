import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';

/// Web-specific iframe widget for Listmonk with auto-authentication
/// Note: Due to browser security (CORS), we cannot inject JavaScript into cross-origin iframes.
/// We attempt API-based authentication, but if it fails, users must login manually.
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  final String _iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authenticateAndLoadIframe();
  }

  Future<void> _authenticateAndLoadIframe() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      print('🔐 Attempting Listmonk API authentication...');

      // Authenticate with Listmonk API first
      await _authenticateWithListmonk();

      print('✅ Authentication successful, loading iframe...');

      // Wait a bit for the cookie to be set
      await Future.delayed(const Duration(milliseconds: 1000));

      // Now register and load the iframe
      _registerIframe();
    } catch (e) {
      print('❌ Authentication error: $e');
      _errorMessage = e.toString();

      // Still load the iframe - user can login manually
      _registerIframe();
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _authenticateWithListmonk() async {
    final loginUrl = 'https://mail.moyd.app/api/admin/login';

    try {
      // Create a completer to handle the async response
      final completer = Completer<void>();

      // Create the request
      final request = html.HttpRequest();
      request.open('POST', loginUrl);
      request.setRequestHeader('Content-Type', 'application/json');
      request.setRequestHeader('Accept', 'application/json');
      request.withCredentials = true; // Important: allows cookies to be set

      request.onLoad.listen((_) {
        print('📡 API Response Status: ${request.status}');
        print('📡 API Response Headers: ${request.getAllResponseHeaders()}');
        print('📡 API Response Body: ${request.responseText}');

        if (request.status == 200) {
          print('✅ Listmonk API authentication successful');
          completer.complete();
        } else {
          final errorMsg = 'Auth failed with status ${request.status}: ${request.responseText}';
          print('❌ $errorMsg');
          completer.completeError(errorMsg);
        }
      });

      request.onError.listen((error) {
        final errorMsg = 'Network error during authentication: $error';
        print('❌ $errorMsg');
        print('💡 This might be due to CORS restrictions or network issues');
        completer.completeError(errorMsg);
      });

      // Send the login credentials
      final credentials = jsonEncode({
        'username': 'admin',
        'password': 'fucktrump67',
      });

      print('📤 Sending credentials to $loginUrl');
      request.send(credentials);

      // Wait for the request to complete (with timeout)
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Authentication request timed out after 10 seconds');
        },
      );
    } catch (e) {
      print('❌ Failed to authenticate with Listmonk: $e');

      // Try opening login page in a new window as fallback
      print('💡 Attempting fallback: opening login page...');
      _openLoginPageInNewTab();

      rethrow;
    }
  }

  void _openLoginPageInNewTab() {
    try {
      // Open login page in a small popup for user to login manually
      final loginWindow = html.window.open(
        'https://mail.moyd.app/admin/login',
        'listmonk_login',
        'width=600,height=700,menubar=no,toolbar=no,location=no,status=no',
      );

      if (loginWindow != null) {
        print('🪟 Opened login popup window - please login there first');

        // Check if window is closed every second
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (loginWindow.closed ?? true) {
            timer.cancel();
            print('🔄 Login window closed, reloading iframe...');
            // Trigger a reload of the iframe
            if (mounted) {
              setState(() {});
            }
          }
        });
      }
    } catch (e) {
      print('❌ Could not open login popup: $e');
    }
  }

  void _registerIframe() {
    try {
      // Register the view factory
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        _iframeId,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = widget.src
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            // Allow credentials (cookies) to be sent with requests
            ..setAttribute('credentialless', 'false')
            ..setAttribute('allow', 'same-origin');

          print('📺 Iframe registered with src: ${widget.src}');

          return iframe;
        },
      );
    } catch (e) {
      print('❌ Error registering iframe: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      // Show a loading indicator while authenticating
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Authenticating with Listmonk...',
              style: TextStyle(fontSize: 16),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Note: If automatic login fails, you can login manually.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return HtmlElementView(viewType: _iframeId);
  }
}
