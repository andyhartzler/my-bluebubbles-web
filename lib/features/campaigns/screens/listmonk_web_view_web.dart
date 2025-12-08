import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';

import '../../../services/credential_storage_service.dart';

/// Web-specific iframe widget for Listmonk with auto-authentication
/// Only attempts login when the page is actually rendered/visible
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  final String _iframeId =
      'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';
  bool _hasAttemptedAuth = false;
  bool _isAuthenticating = false;
  String? _authError;
  int _authAttempts = 0;
  static const int _maxAuthAttempts = 3;

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

          print('Listmonk: Iframe registered with src: ${widget.src}');

          return iframe;
        },
      );
    } catch (e) {
      print('Listmonk: Error registering iframe: $e');
    }
  }

  Future<void> _authenticateWithListmonk() async {
    if (_hasAttemptedAuth || _isAuthenticating) {
      return; // Already attempted or in progress
    }

    setState(() {
      _isAuthenticating = true;
      _hasAttemptedAuth = true;
      _authError = null;
    });

    // Get credentials from secure storage
    final username =
        await CredentialStorageService.getListmonkUsername() ?? 'admin';
    final password =
        await CredentialStorageService.getListmonkPassword() ?? 'fucktrump67';

    final loginUrl = 'https://mail.moyd.app/api/admin/login';

    try {
      print('Listmonk: Attempting API authentication...');

      // Create a completer to handle the async response
      final completer = Completer<void>();

      // Create the request
      final request = html.HttpRequest();
      request.open('POST', loginUrl);
      request.setRequestHeader('Content-Type', 'application/json');
      request.setRequestHeader('Accept', 'application/json');
      request.withCredentials = true; // Important: allows cookies to be set

      request.onLoad.listen((_) {
        print('Listmonk: API Response Status: ${request.status}');

        if (request.status == 200) {
          print('Listmonk: API authentication successful');
          completer.complete();
        } else {
          final errorMsg = 'Auth failed with status ${request.status}';
          print('Listmonk: $errorMsg');
          completer.completeError(errorMsg);
        }
      });

      request.onError.listen((error) {
        final errorMsg = 'Network error during authentication: $error';
        print('Listmonk: $errorMsg');
        completer.completeError(errorMsg);
      });

      // Send the login credentials
      final credentials = jsonEncode({
        'username': username,
        'password': password,
      });

      print('Listmonk: Sending credentials to $loginUrl');
      request.send(credentials);

      // Wait for the request to complete (with timeout)
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Authentication request timed out after 10 seconds');
        },
      );

      print('Listmonk: Authentication complete, cookies should be set');

      // Wait a bit for cookies to be set, then reload iframe
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Reload the iframe to use the new auth cookies
        setState(() {});
      }
    } catch (e) {
      print('Listmonk: Failed to authenticate: $e');
      print('Listmonk: User can still login manually in the iframe');

      _authAttempts++;

      // Retry if we haven't exceeded max attempts
      if (_authAttempts < _maxAuthAttempts) {
        print('Listmonk: Retrying authentication (attempt ${_authAttempts + 1}/$_maxAuthAttempts)');
        _hasAttemptedAuth = false;
        await Future.delayed(const Duration(seconds: 1));
        await _authenticateWithListmonk();
        return;
      }

      if (mounted) {
        setState(() {
          _authError = e.toString();
        });
      }
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
          print('Listmonk: Campaigns page is now visible, attempting auto-login...');
          _authenticateWithListmonk();
        }
      });
    }

    if (_isAuthenticating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF273351)),
            const SizedBox(height: 16),
            Text(
              'Logging in to Email Campaigns...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_authAttempts > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Attempt ${_authAttempts + 1}/$_maxAuthAttempts',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Show error message if auth failed after all retries
    if (_authError != null && _authAttempts >= _maxAuthAttempts) {
      return Stack(
        children: [
          HtmlElementView(viewType: _iframeId),
          // Show a dismissible banner at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.orange[100],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Auto-login failed. Please log in manually.',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _authError = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return HtmlElementView(viewType: _iframeId);
  }
}
