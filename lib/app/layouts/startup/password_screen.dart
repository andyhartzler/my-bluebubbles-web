import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class SupabaseAuthGate extends StatefulWidget {
  final Widget child;

  const SupabaseAuthGate({super.key, required this.child});

  @override
  State<SupabaseAuthGate> createState() => _SupabaseAuthGateState();
}

class _SupabaseAuthGateState extends State<SupabaseAuthGate> {
  static const String _redirectUrl = 'https://moyd.app/auth/callback';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  StreamSubscription<AuthState>? _authSubscription;
  SupabaseClient? _client;

  bool _isCheckingSession = true;
  bool _isAuthenticated = false;
  bool _isSending = false;
  bool _isVerifyingCode = false;
  bool _showCodeInput = false;
  String? _successMessage;
  String? _errorMessage;
  String? _emailForCode;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  void _initializeClient() {
    try {
      _client = Supabase.instance.client;
    } catch (error) {
      setState(() {
        _isCheckingSession = false;
        _errorMessage = 'Authentication service is unavailable. Please try again later.';
      });
      return;
    }

    _bootstrap();
    _authSubscription = _client!.auth.onAuthStateChange.listen((authState) {
      switch (authState.event) {
        case AuthChangeEvent.signedIn:
          if (authState.session != null) {
            setState(() {
              _isAuthenticated = true;
              _successMessage = null;
              _errorMessage = null;
              _showCodeInput = false;
              _codeController.clear();
              _emailForCode = null;
            });
          }
          break;
        case AuthChangeEvent.signedOut:
          setState(() {
            _isAuthenticated = false;
            _successMessage = null;
            _showCodeInput = false;
            _isVerifyingCode = false;
            _codeController.clear();
            _emailForCode = null;
          });
          break;
        default:
          break;
      }
    });
  }

  Future<void> _bootstrap() async {
    final client = _client;
    if (client == null) return;

    final currentSession = client.auth.currentSession;
    final hasSession = currentSession != null;

    final errorParam = Get.parameters['error'] ?? Uri.base.queryParameters['error'];

    _codeController.clear();

    setState(() {
      _isAuthenticated = hasSession;
      _isCheckingSession = false;
      _showCodeInput = false;
      _isVerifyingCode = false;
      _emailForCode = null;
      if (!hasSession && errorParam != null) {
        _errorMessage = _mapErrorMessage(errorParam);
      }
    });

    if (!hasSession) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _emailFocusNode.requestFocus();
        _stripErrorQuery();
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final client = _client;
    if (client == null) {
      setState(() {
        _errorMessage = 'Authentication service is unavailable. Please try again later.';
      });
      return;
    }

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your Missouri Young Democrats email address.';
        _successMessage = null;
      });
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: _redirectUrl,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      setState(() {
        _successMessage = 'Check your email';
        _showCodeInput = true;
        _emailForCode = email;
        _codeController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showCodeInput) {
          _codeFocusNode.requestFocus();
        }
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      String errorMessage;

      final message = error.message;
      if (message.contains('Signups not allowed')) {
        errorMessage =
            'This email is not registered in our system. If you believe this is an error, please contact info@moyoungdemocrats.org';
      } else if (message.contains('403') || message.contains('unexpected_failure')) {
        errorMessage =
            'This email is not associated with a member of the executive committee of the Missouri Young Democrats. If this is a mistake, please be sure to use the email you used when you filled out our Interest Form. For further help, contact info@moyoungdemocrats.org';
      } else if (message.contains('not found in our system')) {
        errorMessage = message;
      } else if (message.contains('executive committee')) {
        errorMessage = message;
      } else {
        errorMessage = _mapErrorMessage(message);
      }

      setState(() {
        _errorMessage = errorMessage;
        _showCodeInput = false;
        _emailForCode = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Something went wrong. Please try again or contact info@moyoungdemocrats.org for assistance.';
        _showCodeInput = false;
        _emailForCode = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final client = _client;
    if (client == null) {
      setState(() {
        _errorMessage = 'Authentication service is unavailable. Please try again later.';
      });
      return;
    }

    final code = _codeController.text.trim();
    final email = _emailForCode ?? _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Email address is required.';
        _successMessage = null;
      });
      return;
    }

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit code from your email.';
        _successMessage = null;
      });
      _codeFocusNode.requestFocus();
      return;
    }

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'The code must be 6 digits.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await client.auth.verifyOtp(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (!mounted) return;
      setState(() {
        _successMessage = 'Code verified! Signing you in...';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      String errorMessage;

      if (error.message.contains('expired') || error.message.contains('invalid')) {
        errorMessage = 'This code has expired or is invalid. Please request a new code.';
      } else {
        errorMessage = 'Unable to verify code. Please try again or request a new code.';
      }

      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isVerifyingCode = false;
      });
    }
  }

  String _mapErrorMessage(String raw) {
    final decoded = Uri.decodeComponent(raw).trim();
    final normalized = decoded.toLowerCase();

    if (normalized.contains('unexpected_failure') || normalized.contains('403')) {
      return 'This email is not associated with a member of the executive committee of the Missouri Young Democrats. If this is a mistake, please be sure to use the email you used when you filled out our Interest Form. For further help, contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('signups not allowed') ||
        (normalized.contains('signup') && normalized.contains('not allowed'))) {
      return 'This email is not registered in our system. If you believe this is an error, please contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('not found in our system') || normalized.contains('email not found')) {
      return 'This email is not registered as an executive committee member. For assistance, contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('executive committee') ||
        (normalized.contains('executive') && normalized.contains('only'))) {
      return decoded;
    }

    if (normalized.contains('unknown_member') || normalized.contains('member_not_found')) {
      return 'We couldn’t find your email in the Missouri Young Democrats roster.';
    }

    if (normalized.contains('non_executive') || normalized.contains('not_executive')) {
      return 'This dashboard is reserved for executive leadership. Please contact your team lead for access.';
    }

    if (normalized.contains('auth_failed') || normalized.contains('expired')) {
      return 'That sign-in link was invalid or expired. Request a new link to continue.';
    }

    if (decoded.isEmpty) {
      return 'Unable to send the sign-in link. Please try again.';
    }

    return decoded;
  }

  void _stripErrorQuery() {
    if (!kIsWeb) return;
    final uri = Uri.base;
    if (!uri.queryParameters.containsKey('error')) return;
    final params = Map<String, String>.from(uri.queryParameters);
    params.remove('error');
    final updated = uri.replace(queryParameters: params.isEmpty ? null : params);
    html.window.history.replaceState(null, '', updated.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.child;
    }

    if (_isCheckingSession) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF273351), Color(0xFF32A6DE)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF273351), Color(0xFF32A6DE)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in to Missouri Young Democrats',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Email address',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.mail_outline),
                              ),
                              autofillHints: const [AutofillHints.email],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.send,
                              enabled: !_showCodeInput,
                              onSubmitted: (_) => _sendMagicLink(),
                              onChanged: (_) {
                                if (_errorMessage != null) {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                }
                              },
                            ),
                            if (_showCodeInput) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Enter the 6-digit code from your email:',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _codeController,
                                focusNode: _codeFocusNode,
                                decoration: InputDecoration(
                                  labelText: '6-digit code',
                                  hintText: '123456',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.pin_outlined),
                                  counterText: '',
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textInputAction: TextInputAction.done,
                                enabled: !_isVerifyingCode,
                                onSubmitted: (_) => _verifyCode(),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _isVerifyingCode
                                    ? null
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        _verifyCode();
                                      },
                                icon: _isVerifyingCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(_isVerifyingCode ? 'Verifying...' : 'Verify Code'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF004AAD),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showCodeInput = false;
                                    _codeController.clear();
                                    _emailForCode = null;
                                    _errorMessage = null;
                                    _successMessage = null;
                                  });
                                  _emailFocusNode.requestFocus();
                                },
                                child: const Text('← Back to email entry'),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (_errorMessage != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE63946).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE63946).withOpacity(0.6)),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFE63946)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE63946)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_successMessage != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43A047).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF43A047).withOpacity(0.6)),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Color(0xFF43A047)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _successMessage!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF43A047)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!_showCodeInput) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _isSending
                                    ? null
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        _sendMagicLink();
                                      },
                                icon: _isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      )
                                    : const Icon(Icons.arrow_forward),
                                label: Text(_isSending ? 'Sending...' : 'Send magic link'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF32A6DE),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'We’ll email you a secure sign-in link. Access is limited to the executive leadership team.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
