import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/auth_refresh_guard.dart';
import 'package:bluebubbles/services/session_timeout_service.dart';

class SupabaseAuthGate extends StatefulWidget {
  final Widget child;

  const SupabaseAuthGate({super.key, required this.child});

  @override
  State<SupabaseAuthGate> createState() => _SupabaseAuthGateState();
}

class _SupabaseAuthGateState extends State<SupabaseAuthGate> with WidgetsBindingObserver {
  static const String _redirectUrl = 'https://moyd.app/auth/callback';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();
  final SessionTimeoutService _sessionService = SessionTimeoutService();

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription? _visibilitySubscription;
  SupabaseClient? _client;

  bool _isCheckingSession = true;
  bool _isAuthenticated = false;
  bool _isSending = false;
  bool _isVerifyingCode = false;
  bool _showCodeInput = false;
  bool _sessionExpired = false;
  String? _successMessage;
  String? _errorMessage;
  String? _emailForCode;

  // Phone sign-in (the default/preferred method for the exec team; email stays
  // available as a fallback so no one is ever locked out). When true the entry
  // form asks for a phone number and texts a code via Twilio Verify.
  bool _phoneMode = true;
  String? _phoneForCode; // E.164 number the SMS code was sent to
  bool _phoneCodeFlow = false; // the pending code is an SMS code, not an email one

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeClient();
    _setupVisibilityListener();
  }

  /// Listen for visibility changes to check session expiration when user returns
  void _setupVisibilityListener() {
    if (!kIsWeb) return;

    _visibilitySubscription = html.document.onVisibilityChange.listen((event) async {
      if (html.document.visibilityState == 'visible' && _isAuthenticated) {
        await _checkSessionExpiration();
      }
    });
  }

  /// Check if session has expired and sign out if needed
  Future<void> _checkSessionExpiration() async {
    final expired = await _sessionService.checkAndExpireSession();
    if (expired && mounted) {
      setState(() {
        _isAuthenticated = false;
        _sessionExpired = true;
        _errorMessage = 'Your session has expired. Please sign in again.';
      });
    } else if (!expired) {
      // The user just brought the app back into view with a valid session:
      // that is activity, so slide the idle window forward. Without this the
      // activity timestamp was only ever written at bootstrap and the
      // "activity-based" timeout degraded to a hard 4h-after-login sign-out.
      await _sessionService.recordActivity();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Check session when app resumes
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      _checkSessionExpiration();
    }
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

    // Refresh-storm circuit breaker: ends runaway token-refresh loops in
    // seconds (whatever their per-device cause) instead of letting the
    // server kill the session and boot the user to this screen.
    AuthRefreshGuard().start(_client!);

    _bootstrap();
    _authSubscription = _client!.auth.onAuthStateChange.listen((authState) async {
      switch (authState.event) {
        case AuthChangeEvent.signedIn:
          if (authState.session != null) {
            // Record session start for timeout tracking
            await _sessionService.recordSessionStart();
            if (!mounted) return;
            setState(() {
              _isAuthenticated = true;
              _sessionExpired = false;
              _successMessage = null;
              _errorMessage = null;
              _showCodeInput = false;
              _codeController.clear();
              _emailForCode = null;
            });
          }
          break;
        case AuthChangeEvent.signedOut:
          debugPrint('Auth state: signedOut - clearing session data');
          // Clear session timestamps
          await _sessionService.clearSession();
          // Clear the user session provider state so the next user gets fresh data
          if (mounted) {
            context.read<UserSessionProvider>().clearSession();
            debugPrint('UserSessionProvider cleared');
          }
          if (!mounted) return;
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
    var hasSession = currentSession != null;

    final errorParam = Get.parameters['error'] ?? Uri.base.queryParameters['error'];

    _codeController.clear();

    // Check if session has expired (only for non-PWA users)
    if (hasSession) {
      final expired = await _sessionService.isSessionExpired();
      if (expired) {
        debugPrint('Session expired on bootstrap - signing out');
        await client.auth.signOut();
        await _sessionService.clearSession();
        hasSession = false;
        if (mounted) {
          setState(() {
            _sessionExpired = true;
            _errorMessage = 'Your session has expired. Please sign in again.';
          });
        }
      } else {
        // Session is valid - record activity
        await _sessionService.recordActivity();
      }
    }

    if (!mounted) return;
    setState(() {
      _isAuthenticated = hasSession;
      _isCheckingSession = false;
      _showCodeInput = false;
      _isVerifyingCode = false;
      _emailForCode = null;
      if (!hasSession && errorParam != null && !_sessionExpired) {
        _errorMessage = _mapErrorMessage(errorParam);
      }
    });

    if (!hasSession) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        (_phoneMode ? _phoneFocusNode : _emailFocusNode).requestFocus();
        _stripErrorQuery();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _visibilitySubscription?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
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
      // Pre-validate: Check if user has any committees with workspace access
      final validationResponse = await client.rpc(
        'get_user_valid_committees',
        params: {'user_email': email},
      );

      final validCommittees = validationResponse as List<dynamic>? ?? [];

      // Check if user exists in members table (either as executive or committee member).
      // Routed through SECURITY DEFINER RPC so it survives the Phase 2 RLS
      // revocation of anon SELECT on `members`. Returns only 3 booleans — no PII.
      final memberCheck = await client
          .rpc('members_preauth_check', params: {'p_email': email})
          .maybeSingle();

      if (memberCheck == null || memberCheck['found'] != true) {
        // User not found in members table at all
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _errorMessage = 'This email is not associated with a Missouri Young Democrats member. If you believe this is an error, please contact info@moyoungdemocrats.org';
        });
        return;
      }

      final isExecutive = memberCheck['executive_committee'] == true;

      // If not executive and no valid committees with workspace access, reject
      if (!isExecutive && validCommittees.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _errorMessage = 'Your committee(s) do not have workspace access enabled. If you believe this is an error, please ask your committee leaders in Slack.';
        });
        return;
      }

      // User is valid - proceed with sending the OTP
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
      // Check if the error contains a structured message from our edge function
      // Pass through specific messages from the edge function
      if (message.contains('not currently a member of any committees') ||
          message.contains('not currently a member of any active committees') ||
          message.contains('does not have workspace access enabled') ||
          message.contains('do not have workspace access enabled') ||
          message.contains('not associated with a Missouri Young Democrats member')) {
        // Use the error message directly from the edge function
        errorMessage = message;
      } else if (message.contains('Signups not allowed')) {
        errorMessage =
            'This email is not associated with a Missouri Young Democrats member. If you believe this is an error, please contact info@moyoungdemocrats.org';
      } else if (message.contains('403') || message.contains('unexpected_failure')) {
        // Generic 403 - use a general message
        errorMessage =
            'Unable to verify access for this email. If you believe this is an error, please contact info@moyoungdemocrats.org';
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
      await client.auth.verifyOTP(
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

  /// Normalize a US phone to E.164 (+1XXXXXXXXXX). Returns null if not a
  /// plausible number. Mirrors the edge functions' own normalization so the
  /// exact-match phone lookup lines up.
  String? _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (raw.trim().startsWith('+') && digits.length >= 8) return '+$digits';
    return null;
  }

  String _cleanError(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
    s = s.trim();
    return s.isEmpty ? 'Something went wrong. Please try again.' : s;
  }

  /// The exec/committee workspace-access gate, shared by both sign-in methods.
  /// Returns null when the email is allowed into the CRM, otherwise a
  /// user-facing denial message. Keeping phone sign-in behind the exact same
  /// check as email is what stops a non-exec member who happens to have a phone
  /// on file from getting a broken, half-signed-in session.
  Future<String?> _checkWorkspaceAccess(SupabaseClient client, String email) async {
    try {
      final validCommittees =
          (await client.rpc('get_user_valid_committees', params: {'user_email': email}))
                  as List<dynamic>? ??
              [];
      final memberCheck = await client
          .rpc('members_preauth_check', params: {'p_email': email})
          .maybeSingle();

      if (memberCheck == null || memberCheck['found'] != true) {
        return 'This account is not associated with a Missouri Young Democrats member. If you believe this is an error, please contact info@moyoungdemocrats.org';
      }
      final isExecutive = memberCheck['executive_committee'] == true;
      if (!isExecutive && validCommittees.isEmpty) {
        return 'Your committee(s) do not have workspace access enabled. If you believe this is an error, please ask your committee leaders in Slack.';
      }
      return null;
    } catch (_) {
      return 'Unable to verify access. Please try again or contact info@moyoungdemocrats.org';
    }
  }

  /// Text a 6-digit code to the entered phone via the verify-phone edge
  /// function (Twilio Verify). We do NOT reveal whether an account exists yet;
  /// the phone -> member match happens after the code checks out.
  Future<void> _sendPhoneCode() async {
    final client = _client;
    if (client == null) {
      setState(() {
        _errorMessage = 'Authentication service is unavailable. Please try again later.';
      });
      return;
    }

    final phone = _toE164(_phoneController.text);
    if (phone == null) {
      setState(() {
        _errorMessage = 'Enter your mobile number (10 digits).';
        _successMessage = null;
      });
      _phoneFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await client.functions.invoke('verify-phone', body: {
        'action': 'start',
        'phone': phone,
      });
      final data = res.data;
      final err = (data is Map) ? data['error'] : null;
      if (err != null) throw Exception(err.toString());

      if (!mounted) return;
      setState(() {
        _successMessage = 'We texted a code to your phone';
        _showCodeInput = true;
        _phoneCodeFlow = true;
        _phoneForCode = phone;
        _codeController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showCodeInput) _codeFocusNode.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(e);
        _showCodeInput = false;
        _phoneForCode = null;
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Verify the SMS code, map the phone to the member's existing account, run
  /// the workspace-access gate, then complete sign-in on that same account.
  Future<void> _verifyPhoneCode() async {
    final client = _client;
    if (client == null) {
      setState(() {
        _errorMessage = 'Authentication service is unavailable. Please try again later.';
      });
      return;
    }

    final code = _codeController.text.trim();
    final phone = _phoneForCode;
    if (phone == null) {
      setState(() => _errorMessage = 'Please request a code first.');
      return;
    }
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'The code must be 6 digits.';
        _successMessage = null;
      });
      _codeFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // 1. Prove phone ownership + map to the member's email (exact e164 match,
      // server-side in the phone-signin edge function).
      final res = await client.functions.invoke('phone-signin', body: {
        'phone': phone,
        'code': code,
      });
      final data = res.data as Map?;
      if (data == null) {
        throw Exception('Could not verify the code. Please try again.');
      }
      if (data['verified'] != true) {
        throw Exception((data['error'] ?? 'That code is incorrect or expired.').toString());
      }
      if (data['matched'] != true || data['email'] == null || data['otp'] == null) {
        throw Exception((data['error'] ??
                'That number is not on file for a Missouri Young Democrats account. Sign in with email instead.')
            .toString());
      }
      final email = data['email'].toString();
      final otp = data['otp'].toString();

      // 2. Same exec/committee gate as email sign-in.
      final denial = await _checkWorkspaceAccess(client, email);
      if (denial != null) throw Exception(denial);

      // 3. Complete sign-in on the existing account.
      await client.auth.verifyOTP(email: email, token: otp, type: OtpType.email);
      if (!mounted) return;
      setState(() => _successMessage = 'Code verified! Signing you in...');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  void _switchMode(bool toPhone) {
    setState(() {
      _phoneMode = toPhone;
      _showCodeInput = false;
      _phoneCodeFlow = false;
      _phoneForCode = null;
      _emailForCode = null;
      _codeController.clear();
      _errorMessage = null;
      _successMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (toPhone ? _phoneFocusNode : _emailFocusNode).requestFocus();
    });
  }

  String _mapErrorMessage(String raw) {
    final decoded = Uri.decodeComponent(raw).trim();
    final normalized = decoded.toLowerCase();

    // Pass through specific messages from our edge function
    if (normalized.contains('not currently a member of any committees') ||
        normalized.contains('not currently a member of any active committees') ||
        normalized.contains('does not have workspace access enabled') ||
        normalized.contains('do not have workspace access enabled') ||
        normalized.contains('not associated with a missouri young democrats member')) {
      return decoded;
    }

    if (normalized.contains('unexpected_failure') || normalized.contains('403')) {
      return 'Unable to verify access for this email. If you believe this is an error, please contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('signups not allowed') ||
        (normalized.contains('signup') && normalized.contains('not allowed'))) {
      return 'This email is not associated with a Missouri Young Democrats member. If you believe this is an error, please contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('not found in our system') || normalized.contains('email not found')) {
      return 'This email is not associated with a Missouri Young Democrats member. If you believe this is an error, please contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('unknown_member') || normalized.contains('member_not_found')) {
      return 'This email is not associated with a Missouri Young Democrats member. If you believe this is an error, please contact info@moyoungdemocrats.org';
    }

    if (normalized.contains('auth_failed') || normalized.contains('expired')) {
      return 'That sign-in link was invalid or expired. Request a new link to continue.';
    }

    if (decoded.isEmpty) {
      return 'Unable to send the sign-in link. Please try again.';
    }

    return decoded;
  }

  List<Widget> _buildCodeEntrySection(ThemeData theme) {
    return [
      const SizedBox(height: 16),
      Text(
        _phoneCodeFlow
            ? 'Enter the 6-digit code we texted you:'
            : 'Enter the 6-digit code from your email:',
        style: theme.textTheme.bodyMedium?.copyWith(
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
        autofillHints: const [AutofillHints.oneTimeCode],
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                if (_phoneCodeFlow) {
                  _verifyPhoneCode();
                } else {
                  _verifyCode();
                }
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
            _phoneCodeFlow = false;
            _codeController.clear();
            _emailForCode = null;
            _phoneForCode = null;
            _errorMessage = null;
            _successMessage = null;
          });
          (_phoneMode ? _phoneFocusNode : _emailFocusNode).requestFocus();
        },
        child: Text(_phoneMode ? '← Back to phone entry' : '← Back to email entry'),
      ),
    ];
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 600;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: constraints.maxHeight > 600 ? 24.0 : 16.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        AutofillGroup(
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Sign in to Missouri Young Democrats',
                                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  if (_phoneMode)
                                    TextField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Mobile number',
                                        hintText: '(555) 123-4567',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.smartphone_outlined),
                                      ),
                                      autofillHints: const [AutofillHints.telephoneNumber],
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.send,
                                      enabled: !_showCodeInput,
                                      onSubmitted: (_) => _sendPhoneCode(),
                                      onChanged: (_) {
                                        if (_errorMessage != null) {
                                          setState(() => _errorMessage = null);
                                        }
                                      },
                                    )
                                  else
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
                                  if (_showCodeInput) ..._buildCodeEntrySection(theme),
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
                                              style: textTheme.bodyMedium?.copyWith(color: const Color(0xFFE63946)),
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
                                              style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF43A047)),
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
                                              if (_phoneMode) {
                                                _sendPhoneCode();
                                              } else {
                                                _sendMagicLink();
                                              }
                                            },
                                      icon: _isSending
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2.5),
                                            )
                                          : Icon(_phoneMode ? Icons.sms_outlined : Icons.arrow_forward),
                                      label: Text(_isSending
                                          ? 'Sending...'
                                          : (_phoneMode ? 'Text me a code' : 'Send magic link')),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF32A6DE),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _isSending ? null : () => _switchMode(!_phoneMode),
                                      child: Text(_phoneMode
                                          ? 'Sign in with email instead'
                                          : 'Sign in with phone instead'),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Text(
                                    _phoneMode
                                        ? 'We\'ll text you a secure code. Access is limited to the executive leadership team.'
                                        : 'We\'ll email you a secure sign-in link. Access is limited to the executive leadership team.',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: textTheme.bodySmall?.color?.withOpacity(0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}
