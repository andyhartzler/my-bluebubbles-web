import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';

/// Web-specific iframe widget for Listmonk with auto-authentication
/// Only attempts login when the page is actually rendered/visible
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  final String _iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';
  bool _hasAttemptedAuth = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Register iframe immediately so it's ready
    _registerIframe();
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

  Future<void> _authenticateWithListmonk() async {
    if (_hasAttemptedAuth || _isAuthenticating) {
      return; // Already attempted or in progress
    }

    setState(() {
      _isAuthenticating = true;
      _hasAttemptedAuth = true;
    });

    final loginUrl = 'https://mail.moyd.app/api/admin/login';

    try {
      print('🔐 Attempting Listmonk API authentication...');

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

        if (request.status == 200) {
          print('✅ Listmonk API authentication successful');
          completer.complete();
        } else {
          final errorMsg = 'Auth failed with status ${request.status}';
          print('❌ $errorMsg');
          completer.completeError(errorMsg);
        }
      });

      request.onError.listen((error) {
        final errorMsg = 'Network error during authentication: $error';
        print('❌ $errorMsg');
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

      print('✅ Authentication complete, cookies should be set');

      // Wait a bit for cookies to be set, then reload iframe
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Reload the iframe to use the new auth cookies
        setState(() {});
      }
    } catch (e) {
      print('❌ Failed to authenticate with Listmonk: $e');
      print('💡 User can still login manually in the iframe');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only attempt authentication after the first frame is rendered
    // This ensures the page is actually visible before we try to auth
    if (!_hasAttemptedAuth) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAttemptedAuth) {
          print('🎯 Campaigns page is now visible, attempting auto-login...');
          _authenticateWithListmonk();
        }
      });
    }

    if (_isAuthenticating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Logging in to Listmonk...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return HtmlElementView(viewType: _iframeId);
  }
}
