import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'credential_storage_service.dart';

/// Service to handle Listmonk authentication
/// Uses multiple auth methods with fallbacks for maximum compatibility
class ListmonkAuthService {
  static const String listmonkUrl = 'https://mail.moyd.app';

  // Cached credentials
  static String? _cachedUsername;
  static String? _cachedPassword;

  /// Initialize and cache credentials from secure storage
  static Future<void> init() async {
    _cachedUsername = await CredentialStorageService.getListmonkUsername();
    _cachedPassword = await CredentialStorageService.getListmonkPassword();
    debugPrint('ListmonkAuthService: Credentials loaded');
  }

  /// Get username (uses cache if available)
  static Future<String> get username async {
    if (_cachedUsername == null) {
      _cachedUsername = await CredentialStorageService.getListmonkUsername();
    }
    return _cachedUsername ?? 'admin';
  }

  /// Get password (uses cache if available)
  static Future<String> get password async {
    if (_cachedPassword == null) {
      _cachedPassword = await CredentialStorageService.getListmonkPassword();
    }
    return _cachedPassword ?? 'fucktrump67';
  }

  /// Get Basic Auth header for API requests
  static Future<String> getBasicAuthHeader() async {
    final user = await username;
    final pass = await password;
    final credentials = base64Encode(utf8.encode('$user:$pass'));
    return 'Basic $credentials';
  }

  /// Attempt to authenticate with Listmonk and get session cookie
  /// Returns the session cookie string if successful, null otherwise
  static Future<String?> authenticate() async {
    debugPrint('ListmonkAuthService: Starting authentication...');

    final client = http.Client();

    try {
      // Method 1: Form-based login (mimics browser login)
      final cookie = await _tryFormLogin(client);
      if (cookie != null) return cookie;

      // Method 2: API-based login
      final apiCookie = await _tryApiLogin(client);
      if (apiCookie != null) return apiCookie;

      // Method 3: Basic auth to get session
      final sessionCookie = await _tryBasicAuthSession(client);
      if (sessionCookie != null) return sessionCookie;

      debugPrint('ListmonkAuthService: All auth methods failed');
      return null;
    } catch (e) {
      debugPrint('ListmonkAuthService: Error - $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Try form-based login like a browser would
  static Future<String?> _tryFormLogin(http.Client client) async {
    try {
      debugPrint('   Trying form login...');

      final user = await username;
      final pass = await password;

      final response = await client.post(
        Uri.parse('$listmonkUrl/admin/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Origin': listmonkUrl,
          'Referer': '$listmonkUrl/admin/login',
        },
        body: 'username=$user&password=$pass',
      );

      debugPrint('   Form login status: ${response.statusCode}');

      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        final sessionCookie = _extractSessionCookie(setCookie);
        if (sessionCookie != null) {
          debugPrint('Form login successful');
          return sessionCookie;
        }
      }
    } catch (e) {
      debugPrint('   Form login error: $e');
    }
    return null;
  }

  /// Try API-based login (Listmonk's /api/admin/login endpoint)
  static Future<String?> _tryApiLogin(http.Client client) async {
    try {
      debugPrint('   Trying API login...');

      final user = await username;
      final pass = await password;

      final response = await client.post(
        Uri.parse('$listmonkUrl/api/admin/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': user,
          'password': pass,
        }),
      );

      debugPrint('   API login status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null && setCookie.isNotEmpty) {
          final sessionCookie = _extractSessionCookie(setCookie);
          if (sessionCookie != null) {
            debugPrint('API login successful');
            return sessionCookie;
          }
        }
        // Even without cookie, 200 means auth succeeded
        debugPrint('API login succeeded (no cookie returned)');
      }
    } catch (e) {
      debugPrint('   API login error: $e');
    }
    return null;
  }

  /// Try Basic Auth and capture any session cookie
  static Future<String?> _tryBasicAuthSession(http.Client client) async {
    try {
      debugPrint('   Trying Basic Auth session...');

      final authHeader = await getBasicAuthHeader();

      final response = await client.get(
        Uri.parse('$listmonkUrl/admin'),
        headers: {
          'Authorization': authHeader,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        },
      );

      debugPrint('   Basic auth status: ${response.statusCode}');

      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        final sessionCookie = _extractSessionCookie(setCookie);
        if (sessionCookie != null) {
          debugPrint('Basic auth session obtained');
          return sessionCookie;
        }
      }
    } catch (e) {
      debugPrint('   Basic auth error: $e');
    }
    return null;
  }

  /// Extract session cookie from Set-Cookie header
  static String? _extractSessionCookie(String setCookieHeader) {
    // Look for session cookie (Listmonk uses 'session')
    final cookies = setCookieHeader.split(RegExp(r',(?=[^;]+?=)'));

    for (final cookie in cookies) {
      final trimmed = cookie.trim();
      if (trimmed.toLowerCase().startsWith('session=')) {
        // Get just the name=value part
        final parts = trimmed.split(';');
        return parts[0].trim();
      }
    }

    // Fallback: return first cookie if no 'session' found
    final firstCookie = setCookieHeader.split(';')[0].trim();
    if (firstCookie.contains('=')) {
      return firstCookie;
    }

    return null;
  }

  /// Verify if authentication is working
  static Future<bool> verifyAuth() async {
    try {
      final authHeader = await getBasicAuthHeader();
      final response = await http.get(
        Uri.parse('$listmonkUrl/api/health'),
        headers: {'Authorization': authHeader},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Generate JavaScript code for auto-login form filling
  /// This is used when cookie/API auth fails and we need to fill the login form
  static Future<String> generateAutoLoginJs() async {
    final user = await username;
    final pass = await password;

    return '''
(function() {
  console.log('MOYD Auto-login script starting...');

  // Configuration
  const USERNAME = '$user';
  const PASSWORD = '$pass';
  const MAX_ATTEMPTS = 15;
  const RETRY_DELAY = 300;

  let attempts = 0;

  function log(msg) {
    console.log('[MOYD] ' + msg);
    try {
      if (window.FlutterBridge) {
        FlutterBridge.postMessage(JSON.stringify({type: 'log', message: msg}));
      }
    } catch(e) {}
  }

  function findElement(selectors) {
    for (const selector of selectors) {
      const el = document.querySelector(selector);
      if (el) return el;
    }
    return null;
  }

  function setInputValue(input, value) {
    // Clear first
    input.value = '';
    input.focus();

    // Try native setter
    try {
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, 'value'
      ).set;
      setter.call(input, value);
    } catch(e) {
      input.value = value;
    }

    // Dispatch events
    ['input', 'change', 'blur', 'keyup'].forEach(eventType => {
      input.dispatchEvent(new Event(eventType, { bubbles: true, cancelable: true }));
    });

    // Also try InputEvent
    try {
      input.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        cancelable: true,
        inputType: 'insertText',
        data: value
      }));
    } catch(e) {}
  }

  function attemptLogin() {
    attempts++;
    log('Attempt ' + attempts + '/' + MAX_ATTEMPTS);

    // Find username field
    const usernameSelectors = [
      'input[name="username"]',
      'input[name="email"]',
      'input[id="username"]',
      'input[id="email"]',
      'input[type="text"]:not([type="hidden"])',
      'input[type="email"]',
      'input[placeholder*="user" i]',
      'input[placeholder*="email" i]',
      'input[autocomplete="username"]'
    ];

    // Find password field
    const passwordSelectors = [
      'input[name="password"]',
      'input[id="password"]',
      'input[type="password"]',
      'input[autocomplete="current-password"]'
    ];

    // Find submit button
    const submitSelectors = [
      'button[type="submit"]',
      'input[type="submit"]',
      'form button:not([type="button"])',
      'button.is-primary',
      '.button.is-primary',
      'button[class*="primary"]',
      'button[class*="login"]',
      'button[class*="submit"]',
      'form button'
    ];

    const usernameField = findElement(usernameSelectors);
    const passwordField = findElement(passwordSelectors);
    const submitButton = findElement(submitSelectors);

    log('Found - Username: ' + !!usernameField + ', Password: ' + !!passwordField + ', Submit: ' + !!submitButton);

    if (usernameField && passwordField) {
      log('Filling credentials...');

      // Fill username
      setInputValue(usernameField, USERNAME);

      // Small delay before password
      setTimeout(() => {
        setInputValue(passwordField, PASSWORD);

        log('Credentials filled, submitting...');

        // Try to submit
        setTimeout(() => {
          if (submitButton) {
            // Try click
            submitButton.click();
            log('Clicked submit button');

            // Also try form submit as backup
            setTimeout(() => {
              const form = document.querySelector('form');
              if (form) {
                try {
                  if (form.requestSubmit) {
                    form.requestSubmit();
                  } else {
                    form.submit();
                  }
                  log('Form submitted');
                } catch(e) {
                  log('Form submit error: ' + e.message);
                }
              }
            }, 200);
          } else {
            // No button found, try form submit
            const form = document.querySelector('form');
            if (form) {
              try {
                form.submit();
                log('Form submitted (no button)');
              } catch(e) {}
            }
          }

          // Notify Flutter
          try {
            if (window.FlutterBridge) {
              FlutterBridge.postMessage(JSON.stringify({type: 'login_attempted'}));
            }
          } catch(e) {}

        }, 300);
      }, 100);

      return true;
    }

    // Retry if elements not found
    if (attempts < MAX_ATTEMPTS) {
      setTimeout(attemptLogin, RETRY_DELAY);
    } else {
      log('Max attempts reached, elements not found');
      try {
        if (window.FlutterBridge) {
          FlutterBridge.postMessage(JSON.stringify({type: 'login_failed', reason: 'elements_not_found'}));
        }
      } catch(e) {}
    }

    return false;
  }

  // Check if already logged in
  const isLoginPage = window.location.href.includes('/login') ||
                      document.querySelector('form input[type="password"]');

  if (!isLoginPage) {
    log('Not on login page, skipping auto-login');
    try {
      if (window.FlutterBridge) {
        FlutterBridge.postMessage(JSON.stringify({type: 'already_logged_in'}));
      }
    } catch(e) {}
    return;
  }

  // Start login attempts after short delay
  setTimeout(attemptLogin, 500);
})();
''';
  }
}
