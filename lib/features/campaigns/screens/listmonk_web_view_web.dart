import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:convert';

/// Web-specific iframe widget for Listmonk with auto-authentication
class Iframe extends StatefulWidget {
  final String src;

  const Iframe({super.key, required this.src});

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  final String _iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticateAndLoadIframe();
  }

  Future<void> _authenticateAndLoadIframe() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Authenticate with Listmonk API first
      await _authenticateWithListmonk();

      // Wait a bit for the cookie to be set
      await Future.delayed(const Duration(milliseconds: 500));

      // Now register and load the iframe
      _registerIframe();
    } catch (e) {
      print('Authentication error: $e');
      // Even if auth fails, still load the iframe (user can login manually)
      _registerIframe();
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _authenticateWithListmonk() async {
    final loginUrl = 'https://mail.moyd.app/api/admin/login';

    try {
      // Create the request
      final request = html.HttpRequest();
      request.open('POST', loginUrl);
      request.setRequestHeader('Content-Type', 'application/json');
      request.withCredentials = true; // Important: allows cookies to be set

      // Create a completer to handle the async response
      final completer = Completer<void>();

      request.onLoad.listen((_) {
        if (request.status == 200) {
          print('Listmonk authentication successful');
          completer.complete();
        } else {
          print('Listmonk authentication failed: ${request.status}');
          completer.completeError('Auth failed with status ${request.status}');
        }
      });

      request.onError.listen((error) {
        print('Listmonk authentication error: $error');
        completer.completeError(error);
      });

      // Send the login credentials
      final credentials = jsonEncode({
        'username': 'admin',
        'password': 'fucktrump67',
      });

      request.send(credentials);

      // Wait for the request to complete (with timeout)
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Authentication request timed out');
        },
      );
    } catch (e) {
      print('Failed to authenticate with Listmonk: $e');
      // Don't throw - we'll let the iframe load anyway
    }
  }

  void _registerIframe() {
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
          ..setAttribute('credentialless', 'false');
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      // Show a loading indicator while authenticating
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return HtmlElementView(viewType: _iframeId);
  }
}

class Completer<T> {
  bool _isCompleted = false;
  T? _result;
  Object? _error;
  final List<Function(T)> _successCallbacks = [];
  final List<Function(Object)> _errorCallbacks = [];

  Future<T> get future {
    return Future<T>((resolve, reject) {
      if (_isCompleted) {
        if (_error != null) {
          reject(_error!);
        } else {
          resolve(_result as T);
        }
      } else {
        _successCallbacks.add(resolve);
        _errorCallbacks.add(reject);
      }
    });
  }

  void complete([T? result]) {
    if (_isCompleted) return;
    _isCompleted = true;
    _result = result;
    for (var callback in _successCallbacks) {
      callback(result as T);
    }
    _successCallbacks.clear();
    _errorCallbacks.clear();
  }

  void completeError(Object error) {
    if (_isCompleted) return;
    _isCompleted = true;
    _error = error;
    for (var callback in _errorCallbacks) {
      callback(error);
    }
    _successCallbacks.clear();
    _errorCallbacks.clear();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
