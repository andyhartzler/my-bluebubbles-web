import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordScreen extends StatefulWidget {
  static const String authKey = 'app_authenticated';
  static const String authTimestampKey = 'app_authenticated_at';

  final Widget child;

  const PasswordScreen({super.key, required this.child});

  static Future<void> clearSavedAuth({SharedPreferences? prefs}) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    await sharedPrefs.remove(authKey);
    await sharedPrefs.remove(authTimestampKey);
  }

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isAuthenticated = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isLoading = true;

  static const String _correctPassword = 'fucktrump67';

  @override
  void initState() {
    super.initState();
    _checkSavedAuth();
  }

  Future<void> _checkSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool(PasswordScreen.authKey) ?? false;
    final lastAuthenticatedAt = prefs.getInt(PasswordScreen.authTimestampKey);

    bool isValid = isAuthenticated;
    if (isAuthenticated) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 30)).millisecondsSinceEpoch;
      if (lastAuthenticatedAt == null || lastAuthenticatedAt < cutoff) {
        await PasswordScreen.clearSavedAuth(prefs: prefs);
        isValid = false;
      }
    }

    setState(() {
      _isAuthenticated = isValid;
      _isLoading = false;
    });

    // Auto-focus the password field after a short delay if not authenticated
    if (!isValid) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _passwordFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkPassword() async {
    final enteredPassword = _passwordController.text;
    if (enteredPassword == _correctPassword) {
      // Save authentication state
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setBool(PasswordScreen.authKey, true);
      await prefs.setInt(PasswordScreen.authTimestampKey, now);

      setState(() {
        _isAuthenticated = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Incorrect password';
      });
      _passwordController.clear();
      _passwordFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If authenticated, show the actual app
    if (_isAuthenticated) {
      return widget.child;
    }

    // Show loading indicator while checking saved auth
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF273351),
                const Color(0xFF32A6DE),
              ],
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

    // Show password screen
    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF273351), // _unityBlue
                  const Color(0xFF32A6DE), // _momentumBlue
                ],
              ),
            ),
          ),
          // Center content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Password field
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Enter Password',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  errorText: _errorMessage,
                                ),
                                onSubmitted: (_) => _checkPassword(),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _checkPassword,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Unlock'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF32A6DE),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Loading indicator (app loads in background)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'App loading in background...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
