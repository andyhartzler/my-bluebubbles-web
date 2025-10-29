import 'dart:async';

import 'package:flutter/material.dart';

class MYDLoadingScreen extends StatefulWidget {
  const MYDLoadingScreen({super.key});

  @override
  State<MYDLoadingScreen> createState() => _MYDLoadingScreenState();
}

class _MYDLoadingScreenState extends State<MYDLoadingScreen> {
  static const Duration _tick = Duration(milliseconds: 120);
  static const int _maxProgress = 100;
  late final Timer _timer;
  double _progress = 12;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      setState(() {
        _progress += 3;
        if (_progress > _maxProgress) {
          _progress = 18;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(rect),
                child: Text(
                  'Missouri Young Democrats',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please wait while we load your communications hub',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 8,
                      value: _progress / _maxProgress,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_progress.toInt()}%',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Preparing',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'We are automatically connecting to BlueBubbles and enabling private server features.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
