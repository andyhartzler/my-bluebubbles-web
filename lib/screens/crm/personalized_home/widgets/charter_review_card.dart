import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';
import 'package:bluebubbles/screens/crm/chapters/chapter_navigation.dart';
import 'package:bluebubbles/screens/crm/chapters/chapters_hub_screen.dart';
import 'package:bluebubbles/services/crm/chapter_hub_service.dart';

/// A to-do on Home when chapters are waiting for review: how many charter
/// applications are in and how many sign-up answers still need sorting.
/// Opens the hub on its Review tab. Hidden when nothing is pending or the
/// load fails, so it never shows an empty or broken card.
class CharterReviewCard extends StatefulWidget {
  const CharterReviewCard({super.key});

  @override
  State<CharterReviewCard> createState() => _CharterReviewCardState();
}

class _CharterReviewCardState extends State<CharterReviewCard> {
  final _service = ChapterHubService.instance;
  int _applications = 0;
  int _signups = 0;

  @override
  void initState() {
    super.initState();
    _service.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _service.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    ChapterHubSnapshot snapshot;
    try {
      snapshot = await _service.load();
    } catch (_) {
      snapshot = ChapterHubSnapshot.empty;
    }
    if (!mounted) return;
    setState(() {
      _applications = snapshot.applicationCount;
      _signups = snapshot.signupCount;
    });
  }

  String get _summary {
    final parts = <String>[
      if (_applications > 0) _applications == 1 ? '1 charter application' : '$_applications charter applications',
      if (_signups > 0) _signups == 1 ? '1 entry from sign-ups to sort' : '$_signups entries from sign-ups to sort',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_applications == 0 && _signups == 0) return const SizedBox.shrink();

    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        label: 'Charter review. $_summary. Open review.',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: BrandColors.unityBlue.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: () => ChapterNavigation.openHub(context, initialTab: ChaptersHubTab.review),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, color: BrandColors.sunriseGold, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Charter review',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _summary,
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
