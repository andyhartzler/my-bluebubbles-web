import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/submission_review_model.dart';
import '../../../theme/moyd_brand.dart';

/// The shared candidate-face widget for the Endorsement HQ.
///
/// Loads [file] as a cover-fit network image with a `cacheWidth` sized to the
/// display box (headshots are multi-MB phone photos and dozens mount at once),
/// fades it in over 200ms, shows a subtle pulse while loading, and falls back
/// to deterministic-background initials whenever the file is null or fails to
/// decode. It never renders a broken-image glyph.
///
/// Privacy: headshot URLs live in a public bucket. Do not surface the raw URL
/// in exports or logs; only the rendered pixels belong on screen.
class HeadshotAvatar extends StatelessWidget {
  final ReviewFile? file;

  /// Full name, used to derive fallback initials and the deterministic color.
  final String name;

  /// Edge length in logical pixels when [shape] is a circle, or the width when
  /// square. Height matches [size] unless the parent constrains it.
  final double size;

  /// Circle (default) or rounded square (used by roster cards that fill a box).
  final bool circle;

  /// Corner radius when [circle] is false.
  final double radius;

  const HeadshotAvatar({
    super.key,
    required this.file,
    required this.name,
    this.size = 44,
    this.circle = true,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        circle ? BorderRadius.circular(size) : BorderRadius.circular(radius);

    Widget content;
    final url = file?.url;
    if (url == null || url.isEmpty) {
      content = _Initials(name: name, size: size);
    } else {
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
      final cacheW = (size * dpr * 1.5).round().clamp(64, 1024);
      content = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheW,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _LoadingPulse(name: name, size: size);
        },
        errorBuilder: (context, error, stack) =>
            _Initials(name: name, size: size),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: circle ? size : null,
        height: circle ? size : null,
        child: content,
      ),
    );
  }

  /// Derive up to two initials from a display name.
  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, math.min(2, p.length)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Deterministic navy-family background for a given name (all >= 4.5:1 with
  /// white text).
  static Color bgFor(String name) {
    const palette = [
      MoydBrand.navy,
      MoydBrand.navySoft,
      Color(0xFF7A5B12), // gold-dark
      Color(0xFF44506A),
    ];
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;
  const _Initials({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: HeadshotAvatar.bgFor(name),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(size * 0.18),
          child: Text(
            HeadshotAvatar.initialsFor(name),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.4,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.enable('smcp')],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPulse extends StatefulWidget {
  final String name;
  final double size;
  const _LoadingPulse({required this.name, required this.size});

  @override
  State<_LoadingPulse> createState() => _LoadingPulseState();
}

class _LoadingPulseState extends State<_LoadingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Color.lerp(base, base.withOpacity(0.4), _c.value),
        );
      },
    );
  }
}
