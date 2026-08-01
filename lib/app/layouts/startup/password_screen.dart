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

  /// Seconds left before "Resend code" re-enables.
  ///
  /// Twilio Verify caps a single verification at 5 send attempts (error
  /// 60203) and the verification then stays dead until its 10 minute TTL
  /// lapses. Without a throttle an exec whose SMS is slow taps resend five
  /// times in as many seconds, burns the quota, and cannot get a code at all
  /// for ten minutes.
  int _resendCooldown = 0;
  Timer? _resendTimer;
  String? _phoneForCode; // E.164 number the SMS code was sent to
  bool _phoneCodeFlow = false; // the pending code is an SMS code, not an email one

  /// Seconds left before the EMAIL code can be requested again.
  ///
  /// Deliberately a SEPARATE timer from `_resendCooldown` above, which is the
  /// Twilio throttle. One shared timer would let an SMS cooldown block the
  /// email send, and "use Sign in with email instead" is exactly what
  /// _sendPhoneCode tells an exec to do when their text does not arrive. That
  /// would turn the throttle into the lockout it exists to prevent.
  ///
  /// Started after every successful send, exactly like the SMS one, and then
  /// corrected to GoTrue's own number whenever GoTrue does answer 429. A purely
  /// reactive cooldown would not fix the mechanism: the very first Back-then-
  /// resend inside GoTrue's window still puts a 429 on the wire, and
  /// SentryHttpClient reports every 4xx, so the issue would keep firing at a
  /// lower rate. Refusing locally BEFORE asking is what actually stops it.
  int _emailResendCooldown = 0;
  Timer? _emailResendTimer;

  /// The address the running cooldown belongs to, lowercased.
  ///
  /// Distinct from _lastEmailCodeSentTo, which answers a different question.
  /// That one means "a code reached this mailbox"; this one means "the server
  /// is holding a window against this mailbox". They diverge exactly when
  /// GoTrue refuses an address we never got a code to, which happens on an
  /// IP-scoped or project-wide limit, or when the window was opened from
  /// another device. Keying the hold on _lastEmailCodeSentTo would leave the
  /// button live in that case and let the user retry straight into another
  /// 429, which is the loop this whole change exists to stop.
  String? _emailCooldownFor;

  /// Seconds to hold the email send for after a successful one.
  ///
  /// GoTrue's per-address OTP interval defaults to 60s, and its refusal reads
  /// "you can only request this after N seconds" counting down from there.
  /// This is the client matching that default rather than discovering it by
  /// being refused. If the server is configured differently the reactive arm
  /// corrects it: a real 429 restarts this timer with GoTrue's own number.
  static const int _emailSendIntervalSeconds = 60;

  /// The address the last email code was actually sent to, remembered across
  /// "← Back to email entry".
  ///
  /// `_emailForCode` cannot answer this question, because Back nulls it on the
  /// way out. Back is the ONLY route from the code screen to the send button,
  /// so by the time a resend is refused we have already forgotten that the
  /// user is holding a perfectly good code. This is the one piece of state
  /// that lets the 429 arm put the entry box back instead of stranding them.
  String? _lastEmailCodeSentTo;

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
              // The code that got them in here is spent. Forgetting it stops
              // a later 429 from offering the code screen back with "the code
              // we already emailed you is still good" for a consumed one.
              _lastEmailCodeSentTo = null;
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
    _resendTimer?.cancel();
    _emailResendTimer?.cancel();
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

    // Re-entrancy guard. The disabled send button is NOT the only way in here:
    // the email field's onSubmitted fires this directly and stays enabled for
    // the whole request, because `enabled: !_showCodeInput` only flips after
    // the await returns. Two Enter presses a second apart therefore put two
    // concurrent signInWithOtp POSTs on the wire, and the second one is what
    // GoTrue answers 429 to.
    if (_isSending) return;

    // THE THROTTLE GOES ON THE SEND, not on the button, for the same reason
    // spelled out in _sendPhoneCode: every path has to pass through it. In
    // email mode the only route to a second code is "← Back to email entry"
    // and then the send button again, which is not throttled anywhere else.
    if (_emailSendHeld) {
      _refuseEmailResend(_emailResendCooldown);
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

      // Hand the result to UserSessionProvider so loadUserSession can skip
      // the duplicate get_user_valid_committees RPC after auth completes.
      UserSessionProvider.cachePreauthCommittees(email, validCommittees);

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
        _lastEmailCodeSentTo = email.toLowerCase();
        _codeController.clear();
      });
      _startEmailResendCooldown(_emailSendIntervalSeconds, email.toLowerCase());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showCodeInput) {
          _codeFocusNode.requestFocus();
        }
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      // GoTrue rate limit. Handled FIRST and separately, because the generic
      // branches below tear the code screen down, which is the dead end this
      // arm exists to stop: an exec whose code was rejected taps send again,
      // gets 429, and loses the entry box for the code still sitting in their
      // inbox. That is the same failure _sendPhoneCode already guards against
      // for SMS.
      //
      // gotrue 2.20.0 maps any non-2xx under 500 with a JSON body to
      // AuthApiException, which extends AuthException, carrying statusCode as
      // the string form of the HTTP status and code as GoTrue's error_code.
      if (_isRateLimit(error)) {
        // GoTrue's own number wins over our default: restart the timer with
        // what it actually asked for, then refuse identically to the local
        // gate above so the user sees one behaviour either way.
        final waitSeconds = _rateLimitSeconds(error.message);
        // Held against the address we just tried, not against the one we last
        // got a code to. GoTrue may be refusing an address this device has
        // never had a code for at all.
        _startEmailResendCooldown(waitSeconds, email.toLowerCase());
        _refuseEmailResend(waitSeconds);
        return;
      }

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

  /// Turn whatever was thrown into something an exec can act on.
  ///
  /// This used to be `e.toString()` with the "Exception: " prefix shaved off,
  /// so the sign-in error box rendered raw Dart. The two shapes that actually
  /// reach it during phone sign-in are the worst two to print verbatim:
  /// `FunctionException(status: 500, details: {...}, reasonPhrase: null)`
  /// from an edge-function failure, and
  /// `ClientException with SocketException: Failed host lookup...` from a
  /// dropped connection. Neither tells anyone what to do, and both look like
  /// the app is broken rather than the network.
  String _cleanError(Object e) {
    if (e is FunctionException) {
      final details = e.details;
      final inner = details is Map ? details['error'] : null;
      final msg = inner?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
      final reason = e.reasonPhrase?.trim();
      if (reason != null && reason.isNotEmpty) return reason;
      return 'Could not reach the sign-in service. Please try again in a '
          'moment, or use the other sign-in method below.';
    }
    if (e is AuthException) {
      final msg = e.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
    s = s.trim();
    if (s.isEmpty) return 'Something went wrong. Please try again.';
    // Transport-level failures never reach the user as Dart text.
    final lower = s.toLowerCase();
    if (lower.contains('clientexception') ||
        lower.contains('socketexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('failed to fetch') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('connection closed') ||
        lower.contains('connection refused')) {
      return 'Could not reach the server. Check your connection and try '
          'again.';
    }
    return s;
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
      // Hand the result to UserSessionProvider so loadUserSession can skip
      // the duplicate get_user_valid_committees RPC after auth completes.
      UserSessionProvider.cachePreauthCommittees(email, validCommittees);
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

    // Re-entrancy guard, the same one _sendMagicLink needs and for the same
    // reason: the phone field's onSubmitted calls this directly and the field
    // stays enabled for the whole request, so holding Enter fires several
    // concurrent verify-phone invocations. The cooldown below cannot catch
    // them, because it is still 0 until the first send returns. Each one is a
    // real Twilio send against a 5-send cap, so an impatient exec can burn the
    // verification and be locked out for its full 10 minute TTL, on the
    // default sign-in method, on the night of the vote.
    if (_isSending) return;

    // THE THROTTLE IS NOT JUST A DISABLED BUTTON.
    //
    // Twilio Verify caps a single verification at 5 sends (error 60203) and
    // then kills it for its full 10 minute TTL: an exec who burns the quota
    // cannot get a code AT ALL, on the night of the vote. The 30s cooldown
    // was enforced in exactly one place, the "Resend code" button's
    // onPressed, and two paths walked straight around it: "← Back to phone
    // entry" and the email/phone switch both zeroed `_resendCooldown`, and
    // the entry screen's own "Text me a code" button never consulted it. So
    // Back, tap, Back, tap was an unthrottled loop into the lockout. The gate
    // belongs on the send itself, where every path has to pass through it.
    if (_resendCooldown > 0) {
      setState(() {
        _errorMessage = 'Wait ${_resendCooldown}s before asking for another '
            'code. If the text still has not arrived, use "Sign in with '
            'email instead" below.';
        _successMessage = null;
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
      _startResendCooldown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showCodeInput) _codeFocusNode.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(e);
        // ONLY tear the code screen down on the FIRST send. A failed RESEND
        // used to wipe `_showCodeInput` and `_phoneForCode`, which threw the
        // exec back to the phone-number field and discarded the code they
        // had already been texted and may have been mid-way through typing.
        // The first code is very often still valid (Twilio Verify keeps the
        // verification alive for 10 minutes); the resend is the thing that
        // failed, not the code. Losing the entry field is what then drives
        // the send-again loop into the 5-send lockout.
        if (_phoneForCode == null) {
          _showCodeInput = false;
          _phoneCodeFlow = false;
        }
      });
      // A failed RESEND still starts the cooldown: the failure may well BE
      // the 5-send cap (Twilio 60203), and an uncooled retry loop is what
      // gets there. A failed FIRST send does not, so a mistyped number can be
      // corrected immediately.
      if (_phoneForCode != null) _startResendCooldown();
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

  /// True when the address currently typed is the one the cooldown belongs to.
  ///
  /// GoTrue's OTP interval is per mailbox, not per device, so this is matched
  /// on the address rather than just on the timer running. On a shared laptop
  /// at the vote, one exec requesting a code must not disable the send button
  /// for the next person who types their own address into it.
  bool get _emailSendHeld =>
      _emailResendCooldown > 0 &&
      _emailCooldownFor != null &&
      _emailCooldownFor == _emailController.text.trim().toLowerCase();

  /// Refuse another email code for [waitSeconds], and when we know one is
  /// already in their inbox, put the entry box back for it.
  ///
  /// Both refusal paths go through here: the local gate that declines before
  /// asking, and the 429 arm for when GoTrue declines anyway. The restore is
  /// the whole point. "← Back to email entry" is the only route from the code
  /// screen to the send button and it clears _showCodeInput and _emailForCode
  /// on the way out, so without this the exec is left on the entry screen
  /// being told their existing code is fine while the only field that accepts
  /// it is hidden. _lastEmailCodeSentTo survives Back precisely so this can
  /// undo it.
  ///
  /// Matched on the address, and case-insensitively, because GoTrue lowercases
  /// it: a typo corrected after Back must NOT restore a screen for a code that
  /// was never sent to what is on screen now, but a change of capitalisation
  /// is the same mailbox and the same rate-limit window.
  void _refuseEmailResend(int waitSeconds) {
    final typed = _emailController.text.trim().toLowerCase();
    final holdsCode = _lastEmailCodeSentTo != null && _lastEmailCodeSentTo == typed;
    setState(() {
      _successMessage = null;
      _errorMessage = holdsCode
          ? 'Wait ${waitSeconds}s before asking for another code. If the one '
              'we already emailed you has not expired it still works, so try '
              'it below first.'
          : 'Wait ${waitSeconds}s before requesting another sign-in code.';
      if (holdsCode) {
        _showCodeInput = true;
        _emailForCode = _lastEmailCodeSentTo;
        _phoneCodeFlow = false;
      } else {
        _showCodeInput = false;
        _emailForCode = null;
      }
    });
    if (holdsCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showCodeInput) _codeFocusNode.requestFocus();
      });
    }
  }

  /// True when GoTrue refused the send because of a rate limit.
  ///
  /// Both signals are checked because they fail independently. statusCode is
  /// absent on AuthRetryableFetchException raised before a response arrives,
  /// and code is null on responses from an API version older than 2024-01-01
  /// that carry no error_code at all.
  bool _isRateLimit(AuthException error) {
    return error.statusCode == '429' ||
        error.code == 'over_email_send_rate_limit' ||
        error.code == 'over_request_rate_limit';
  }

  /// How long GoTrue says to wait, read out of its own message.
  ///
  /// The per-address interval reads "For security purposes, you can only
  /// request this after 51 seconds." The hourly cap reads "email rate limit
  /// exceeded" with no number, hence the fallback. Clamped so a malformed or
  /// unexpected message can never lock the send button out for long.
  int _rateLimitSeconds(String message) {
    final match = RegExp(r'after (\d+) second').firstMatch(message.toLowerCase());
    final parsed = match == null ? null : int.tryParse(match.group(1)!);
    final seconds = parsed ?? 60;
    if (seconds < 1) return 1;
    if (seconds > 300) return 300;
    return seconds;
  }

  /// Start the email send cooldown for [seconds].
  ///
  /// Kept apart from _startResendCooldown so the Twilio timer is untouched.
  /// Like that one it survives _switchMode and "← Back", because neither
  /// resets it: the limit belongs to GoTrue and the email address, not to
  /// which form happens to be on screen.
  void _startEmailResendCooldown(int seconds, String forEmail) {
    _emailResendTimer?.cancel();
    setState(() {
      _emailResendCooldown = seconds;
      _emailCooldownFor = forEmail;
    });
    _emailResendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _emailResendCooldown--);
      if (_emailResendCooldown <= 0) t.cancel();
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  void _switchMode(bool toPhone) {
    // THE COOLDOWN SURVIVES THE SWITCH. It used to be cancelled and zeroed
    // here, which turned "Sign in with email instead" and back into a free
    // reset of the SMS throttle. The timer is about Twilio's per-verification
    // send quota, not about which form is on screen.
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
        // Must branch exactly like the Verify Code button below. It used to be
        // a hardcoded _verifyCode(), the EMAIL verifier, so pressing the
        // keyboard's submit key during the PHONE flow hit _verifyCode's own
        // guard and told someone signing in with a phone number
        // "Email address is required." (_emailForCode is null and the email
        // field was never shown). Reachable on any keyboard exposing a submit
        // key: desktop Enter, Android, and iOS whenever the numeric input
        // surfaces a Go key.
        onSubmitted: (_) {
          if (_isVerifyingCode) return;
          if (_phoneCodeFlow) {
            _verifyPhoneCode();
          } else {
            _verifyCode();
          }
        },
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
      // Resend, throttled. Before this the ONLY way to get a new code was to
      // tap "Back to phone entry" and then "Text me a code" again, which is
      // both undiscoverable and unthrottled: an exec whose SMS was slow would
      // loop it, burn Twilio's 5 sends per verification (60203) and then be
      // unable to get a code at all until the 10 minute TTL lapsed.
      if (_phoneCodeFlow) ...[
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: (_isSending || _isVerifyingCode || _resendCooldown > 0)
              ? null
              : _sendPhoneCode,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(_resendCooldown > 0
              ? 'Resend code in ${_resendCooldown}s'
              : 'Resend code'),
        ),
      ],
      const SizedBox(height: 4),
      TextButton(
        onPressed: () {
          // Same rule as _switchMode: the resend cooldown SURVIVES Back. It
          // used to be cancelled and zeroed right here, which made
          // "Back → Text me a code" the unthrottled path into Twilio's
          // 5-send lockout that the cooldown was added to prevent.
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
    // The sign-in error is the one piece of text an exec reads when they
    // CANNOT get in, and the app's default dark theme is OLED Dark, whose
    // card surface is near-black (~#191C20). Brand red #E63946 lands about
    // 4.1:1 there, under the 4.5:1 AA floor for body text. Lightening it to
    // #FF6B75 in dark mode gives ~6.2:1 while staying recognisably MOYD red;
    // light mode keeps the brand value unchanged (#E63946 on white is ~4.8:1).
    final errorRed = theme.brightness == Brightness.dark
        ? const Color(0xFFFF6B75)
        : const Color(0xFFE63946);

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
                                        // Rebuilds on every keystroke, not
                                        // only when clearing an error, so the
                                        // send button tracks _emailSendHeld
                                        // for the address actually typed.
                                        // Without this the button would keep
                                        // showing a countdown belonging to
                                        // someone else's address.
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                      },
                                    ),
                                  if (_showCodeInput) ..._buildCodeEntrySection(theme),
                                  const SizedBox(height: 16),
                                  if (_errorMessage != null)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: errorRed.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: errorRed.withOpacity(0.6)),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.error_outline, color: errorRed),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: textTheme.bodyMedium?.copyWith(color: errorRed),
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
                                      // Gated on the SMS cooldown too, not
                                      // just on _isSending. _sendPhoneCode
                                      // now refuses while the cooldown runs,
                                      // and a button that looks live but does
                                      // nothing is worse than a disabled one
                                      // that says how long is left.
                                      onPressed: (_isSending ||
                                              (_phoneMode
                                                  ? _resendCooldown > 0
                                                  : _emailSendHeld))
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
                                          : (_phoneMode
                                              ? (_resendCooldown > 0
                                                  ? 'Text me a code in ${_resendCooldown}s'
                                                  : 'Text me a code')
                                              : (_emailSendHeld
                                                  ? 'Send magic link in ${_emailResendCooldown}s'
                                                  : 'Send magic link'))),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF32A6DE),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                  // ALWAYS rendered, deliberately outside the
                                  // `if (!_showCodeInput)` block above.
                                  //
                                  // This button used to disappear the moment a
                                  // code was requested, which is precisely the
                                  // state execs get stuck in: phone-signin
                                  // returns "That number is verified, but no
                                  // account uses it. Sign in with email
                                  // instead." and "This number is linked to
                                  // more than one account. Sign in with email
                                  // instead.", and _verifyPhoneCode's catch
                                  // leaves _showCodeInput true. So the app
                                  // told people to do a thing while hiding the
                                  // only control that does it, and the sole
                                  // escape was a back link whose label never
                                  // mentions email. _switchMode already clears
                                  // the pending code state, so this is safe in
                                  // every state.
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: (_isSending || _isVerifyingCode)
                                        ? null
                                        : () => _switchMode(!_phoneMode),
                                    child: Text(_phoneMode
                                        ? 'Sign in with email instead'
                                        : 'Sign in with phone instead'),
                                  ),
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
