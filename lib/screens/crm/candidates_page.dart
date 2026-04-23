import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidates/candidates_mobile_page.dart';
import 'package:bluebubbles/screens/crm/candidates/candidates_split_page.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATES INTELLIGENCE PAGE — ROUTER
//
//  This file used to be a 2630-line monolith. It is now a thin
//  width-based router:
//
//   • ≥ 1200px   → CandidatesSplitPage    (sticky map + list panel)
//   • <  1200px  → CandidatesMobilePage   (hero map, stats, filters,
//                                          view-mode body, district
//                                          bottom sheet on tap)
//
//  All actual UI lives in lib/screens/crm/candidates/*. See the plan
//  doc at "Projects/2026-04-22 Candidates Page Redesign.md" for the
//  redesign rationale.
// ═══════════════════════════════════════════════════════════════

class CandidatesPage extends StatelessWidget {
  const CandidatesPage({super.key});

  static const double desktopBreakpoint = 1200;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;
        final body =
            isDesktop ? const CandidatesSplitPage() : const CandidatesMobilePage();

        // Ambient brand-colored gradient backdrop visible behind any
        // transparent surfaces in the children.
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1a2038),
                BrandColors.unityBlue,
              ],
            ),
          ),
          child: body,
        );
      },
    );
  }
}
