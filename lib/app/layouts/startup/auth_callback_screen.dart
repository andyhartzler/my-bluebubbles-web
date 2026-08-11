import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String? _errorCode;

  SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_handleCallback);
  }

  Future<void> _handleCallback() async {
    final client = _clientOrNull;

    if (client == null) {
      if (!mounted) return;
      Get.offAllNamed('/?error=auth_failed');
      return;
    }

    try {
      await client.auth.getSessionFromUrl(Uri.base, storeSession: true);
    } on AuthException catch (error) {
      // The PKCE code verifier is written to this browser's local storage when
      // the link is requested, read back here, and deleted once the exchange
      // succeeds. So there is nothing to read back if the link is opened in a
      // different browser, a different device or a private window, and equally
      // if the link has already been used. Either way the exchange fails with a
      // message that is true and useless to the person reading it. Send a
      // stable code instead and let the sign-in screen explain what to do.
      _errorCode = error.message.toLowerCase().contains('code verifier')
          ? 'link_wrong_browser'
          : error.message;
    } catch (_) {
      _errorCode = 'auth_failed';
    }

    final session = client.auth.currentSession;

    if (session != null) {
      if (!mounted) return;
      Get.offAllNamed('/');
      return;
    }

    final errorParam = _errorCode ?? Uri.base.queryParameters['error'] ?? 'auth_failed';
    if (!mounted) return;
    final encoded = Uri.encodeComponent(errorParam);
    Get.offAllNamed('/?error=$encoded');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF273351), Color(0xFF32A6DE)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Completing your secure sign-in…',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
