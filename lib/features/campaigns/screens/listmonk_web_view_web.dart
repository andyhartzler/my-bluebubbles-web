import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web-specific iframe widget for Listmonk with SSO + postMessage authentication
///
/// This widget authenticates users with Listmonk via:
/// 1. Supabase Edge Function SSO token (validates CRM login)
/// 2. postMessage credential flow (completes Listmonk login)
class Iframe extends StatefulWidget {
  final String src;
  final bool showCredentials; // Kept for backward compatibility, but unused with SSO

  const Iframe({
    super.key,
    required this.src,
    this.showCredentials = false,
  });

  @override
  State<Iframe> createState() => _IframeState();
}

class _IframeState extends State<Iframe> {
  // Listmonk configuration
  static const String _listmonkBaseUrl = 'https://mail.moyd.app';
  static const String _listmonkAdminUrl = '$_listmonkBaseUrl/admin';

  // State
  String? _iframeId;
  html.IFrameElement? _iframe;
  bool _isLoading = true;
  bool _isRegistered = false;
  bool _isAuthenticating = false;
  String _statusMessage = 'Initializing...';
  String? _errorMessage;
  String? _authUrl;
  String? _listmonkUsername;
  String? _listmonkPassword;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  bool _credentialsSent = false;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _initializeAuth();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  /// Set up postMessage listener for Listmonk communication
  void _setupMessageListener() {
    debugPrint('📧 Listmonk: Setting up postMessage listener...');

    _messageSubscription = html.window.onMessage.listen((event) {
      if (event.data == null) return;

      try {
        // Handle both Map and JsObject types
        Map<String, dynamic>? data;

        if (event.data is Map) {
          data = Map<String, dynamic>.from(event.data as Map);
        } else {
          // Try to convert from JS object
          final jsData = event.data;
          if (jsData is! String) {
            // Try accessing properties directly
            try {
              final type = (jsData as dynamic).type;
              if (type != null) {
                data = {
                  'type': type.toString(),
                };
                // Try to get additional fields if present
                try {
                  final success = (jsData as dynamic).success;
                  final reason = (jsData as dynamic).reason;
                  if (success != null) data['success'] = success;
                  if (reason != null) data['reason'] = reason.toString();
                } catch (e) {
                  debugPrint('_IframeState._onMessage parse fields error: $e');
                }
              }
            } catch (e) {
              debugPrint('_IframeState._onMessage error: $e');
              return;
            }
          }
        }

        if (data == null) return;

        final type = data['type'] as String?;

        debugPrint('📧 Listmonk message received: $type');

        switch (type) {
          case 'MOYD_LOGIN_PAGE_READY':
            // Listmonk login page is ready and waiting for credentials
            debugPrint('📧 Listmonk login page ready, sending credentials...');
            _sendCredentialsToListmonk();
            break;

          case 'MOYD_LOGIN_RESULT':
            // Login attempt completed
            final success = data['success'] as bool? ?? false;
            final reason = data['reason'] as String?;

            if (success) {
              debugPrint('📧 Listmonk login successful!');
              // Hide loading overlay after a short delay to allow page redirect
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = null;
                  });
                }
              });
            } else if (reason == 'already_logged_in') {
              debugPrint('📧 Already logged in to Listmonk');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = null;
                });
              }
            } else {
              debugPrint('📧 Listmonk login failed: $reason');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Login failed: ${reason ?? 'Unknown error'}';
                });
              }
            }
            break;

          case 'MOYD_DASHBOARD_READY':
            // Dashboard has fully loaded - reliable signal to hide loading
            debugPrint('📧 Listmonk dashboard ready!');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = null;
              });
            }
            break;
        }
      } catch (e) {
        debugPrint('📧 Listmonk: Error handling message: $e');
      }
    });

    debugPrint('📧 Listmonk: postMessage listener ready');
  }

  /// Send credentials to Listmonk iframe via postMessage
  void _sendCredentialsToListmonk() {
    if (_credentialsSent) {
      debugPrint('📧 Listmonk: Credentials already sent, skipping...');
      return;
    }

    if (_iframe?.contentWindow == null) {
      debugPrint('📧 Listmonk: Error - Iframe not available');
      return;
    }

    if (_listmonkPassword == null || _listmonkPassword!.isEmpty) {
      debugPrint('📧 Listmonk: Error - Password not available');
      // Try to get credentials again
      _getAuthToken().then((result) {
        if (result != null) {
          final credentials = result['credentials'] as Map<String, dynamic>?;
          if (credentials != null) {
            _listmonkUsername = credentials['username'] as String?;
            _listmonkPassword = credentials['password'] as String?;
            _sendCredentialsToListmonk();
          }
        }
      });
      return;
    }

    debugPrint('📧 Sending credentials to Listmonk...');

    try {
      // Message type MUST be 'MOYD_LOGIN_CREDENTIALS' to match Listmonk's handler
      _iframe!.contentWindow!.postMessage({
        'type': 'MOYD_LOGIN_CREDENTIALS',
        'username': _listmonkUsername ?? 'admin',
        'password': _listmonkPassword,
      }, _listmonkBaseUrl);

      _credentialsSent = true;
      debugPrint('📧 Credentials sent to iframe');

      if (mounted) {
        setState(() {
          _statusMessage = 'Logging in...';
        });
      }
    } catch (e) {
      debugPrint('📧 Listmonk: Error sending credentials: $e');
    }
  }

  /// Initialize authentication flow
  Future<void> _initializeAuth() async {
    setState(() {
      _isLoading = true;
      _isAuthenticating = true;
      _statusMessage = 'Authenticating with Listmonk...';
      _errorMessage = null;
      _credentialsSent = false;
    });

    try {
      // Get SSO token and credentials from Supabase Edge Function
      final authResult = await _getAuthToken();

      if (authResult != null) {
        // Get credentials from response (nested in 'credentials' object)
        final credentials = authResult['credentials'] as Map<String, dynamic>?;
        if (credentials != null) {
          _listmonkUsername = credentials['username'] as String?;
          _listmonkPassword = credentials['password'] as String?;
          debugPrint('📧 Listmonk: Credentials received from Edge Function');
        }

        final ssoUrl = authResult['listmonk_url'] as String?;

        if (ssoUrl != null) {
          _authUrl = ssoUrl;
          debugPrint('📧 Listmonk: SSO URL received');
          _registerIframe(_authUrl!);
        } else {
          // No SSO URL but we have credentials - load admin and wait for postMessage
          debugPrint('📧 Listmonk: No SSO URL, using postMessage flow only');
          _registerIframe(_listmonkAdminUrl);
        }

        setState(() {
          _statusMessage = 'Loading email campaigns...';
          _isAuthenticating = false;
        });
      } else {
        // Auth failed completely
        debugPrint('📧 Listmonk: No auth data received, loading without auth');
        _registerIframe(_listmonkAdminUrl);

        setState(() {
          _statusMessage = 'Loading...';
          _errorMessage = 'Auto-login failed. You may need to log in manually.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      debugPrint('📧 Listmonk: Auth error: $e');

      // Load iframe anyway - user can log in manually or via postMessage
      _registerIframe(_listmonkAdminUrl);

      setState(() {
        _statusMessage = 'Loading...';
        _errorMessage = 'Auto-login unavailable. Please log in manually.';
        _isAuthenticating = false;
      });
    }
  }

  /// Get SSO authentication token and credentials from Supabase Edge Function
  Future<Map<String, dynamic>?> _getAuthToken() async {
    try {
      final supabase = Supabase.instance.client;

      // Check if user is authenticated
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint('📧 Listmonk: No active CRM session');
        return null;
      }

      debugPrint('📧 Listmonk: Requesting SSO token from Edge Function...');

      // Call the Edge Function
      final response = await supabase.functions.invoke(
        'listmonk-auth',
        body: {},
      );

      if (response.status != 200) {
        debugPrint('📧 Listmonk: Edge function error: ${response.status}');
        debugPrint('📧 Listmonk: Response: ${response.data}');
        return null;
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;

      if (data != null) {
        debugPrint('📧 Listmonk: Auth data received');
        debugPrint('📧 Listmonk: Has token: ${data['token'] != null}');
        debugPrint('📧 Listmonk: Has credentials: ${data['credentials'] != null}');
        debugPrint('📧 Listmonk: Has listmonk_url: ${data['listmonk_url'] != null}');
        return data;
      }

      debugPrint('📧 Listmonk: No data in response');
      return null;
    } catch (e) {
      debugPrint('📧 Listmonk: Failed to get auth token: $e');
      return null;
    }
  }

  /// Register the iframe with the platform view registry
  void _registerIframe(String url) {
    try {
      debugPrint('📧 Listmonk: Loading iframe with URL: $url');

      // Create unique iframe ID
      final iframeId = 'listmonk-iframe-${DateTime.now().millisecondsSinceEpoch}';

      _iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'clipboard-read; clipboard-write'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('loading', 'eager');

      // Handle iframe load event
      _iframe!.onLoad.listen((_) {
        debugPrint('📧 Listmonk: Iframe loaded');
        _handleIframeLoaded();
      });

      // Handle iframe errors
      _iframe!.onError.listen((event) {
        debugPrint('📧 Listmonk: Iframe error: $event');
        _handleIframeError();
      });

      // Register the view factory
      ui_web.platformViewRegistry.registerViewFactory(
        iframeId,
        (int viewId) => _iframe!,
      );

      debugPrint('📧 Listmonk: Iframe registered, waiting for load...');

      if (mounted) {
        setState(() {
          _iframeId = iframeId;
          _isRegistered = true;
        });
      }
    } catch (e) {
      debugPrint('📧 Listmonk: Error registering iframe: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  /// Handle successful iframe load
  void _handleIframeLoaded() {
    if (!mounted) return;

    debugPrint('📧 Listmonk: Iframe loaded, waiting for postMessage...');

    // Don't immediately hide loading - wait for Listmonk to request credentials
    // The postMessage listener will handle the authentication flow

    // Set a timeout to hide loading if no postMessage received
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading && !_credentialsSent) {
        debugPrint('📧 Listmonk: Timeout waiting for postMessage, hiding loading');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// Handle iframe load error
  void _handleIframeError() {
    if (!mounted) return;

    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('📧 Listmonk: Retrying... ($_retryCount/$_maxRetries)');

      setState(() {
        _statusMessage = 'Retrying... ($_retryCount/$_maxRetries)';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _refresh();
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load Listmonk. Please try again or open in new tab.';
      });
    }
  }

  /// Refresh the iframe and re-authenticate
  void _refresh() {
    setState(() {
      _isLoading = true;
      _isRegistered = false;
      _iframeId = null;
      _statusMessage = 'Refreshing...';
      _errorMessage = null;
      _retryCount = 0;
      _credentialsSent = false;
    });

    // Re-authenticate and reload
    _initializeAuth();
  }

  /// Open Listmonk in a new tab
  void _openInNewTab() {
    html.window.open(_listmonkAdminUrl, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    // Show error if registration failed
    if (_errorMessage != null && !_isLoading && !_isRegistered) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openInNewTab,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in new tab'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Wait for registration to complete before showing HtmlElementView
    if (!_isRegistered || _iframeId == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_isAuthenticating) ...[
                const SizedBox(height: 8),
                Text(
                  'Connecting to email campaign manager...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Show iframe with loading overlay and error banner
    return Stack(
      children: [
        // Iframe
        HtmlElementView(viewType: _iframeId!),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.9),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error banner (shown when SSO fails but iframe loaded)
        if (_errorMessage != null && !_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: _openInNewTab,
                    child: Text(
                      'Open in new tab',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    iconSize: 20,
                    color: Colors.orange.shade800,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
