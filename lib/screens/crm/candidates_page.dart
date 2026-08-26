import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/forms/screens/endorsement_hub/endorsement_hub_screen.dart';
import 'package:bluebubbles/features/forms/theme/moyd_brand.dart';
import 'package:bluebubbles/screens/crm/candidates/candidates_mobile_page.dart';
import 'package:bluebubbles/screens/crm/candidates/candidates_split_page.dart';
import 'package:bluebubbles/screens/crm/volunteers/candidate_volunteers_map.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATES INTELLIGENCE PAGE — ROUTER
//
//  A thin area switch sits above three workspaces, defaulting to the
//  Candidate Volunteers map (the first thing Candidates opens to):
//
//   • Candidate Volunteers → the interactive Missouri "war room" map:
//       county / congressional / MO House / MO Senate, tap a region to
//       see its November candidates and the members who live there.
//   • Field          → the width-based candidate map/list router
//                       (≥1200px CandidatesSplitPage, else Mobile),
//                       with Primary and General sub-tabs.
//   • Endorsement HQ  → the 2026 candidate-survey intelligence hub.
//
//  Field UI lives in lib/screens/crm/candidates/*, the volunteers map in
//  lib/screens/crm/volunteers/*.
// ═══════════════════════════════════════════════════════════════

enum CandidatesArea { field, endorsementHq, volunteers }

class CandidatesPage extends StatefulWidget {
  const CandidatesPage({super.key});

  static const double desktopBreakpoint = 1200;

  @override
  State<CandidatesPage> createState() => _CandidatesPageState();
}

class _CandidatesPageState extends State<CandidatesPage> {
  // Candidate Volunteers (the map) is the landing area: clicking Candidates in
  // the main nav opens straight into the Missouri map.
  CandidatesArea _area = CandidatesArea.volunteers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AreaSwitcher(
          area: _area,
          onChanged: (a) => setState(() => _area = a),
        ),
        Expanded(
          child: switch (_area) {
            CandidatesArea.volunteers => const CandidateVolunteersMap(),
            CandidatesArea.endorsementHq => const EndorsementHubScreen(),
            CandidatesArea.field => _fieldBody(),
          },
        ),
      ],
    );
  }

  Widget _fieldBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= CandidatesPage.desktopBreakpoint;
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

/// A compact solid-navy strip hosting the {Field · Endorsement HQ} switch.
class _AreaSwitcher extends StatelessWidget {
  final CandidatesArea area;
  final ValueChanged<CandidatesArea> onChanged;
  const _AreaSwitcher({required this.area, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MoydBrand.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SegmentedButton<CandidatesArea>(
                segments: const [
                  ButtonSegment(
                    value: CandidatesArea.volunteers,
                    icon: Icon(Icons.map_outlined),
                    label: Text('Candidate Volunteers'),
                  ),
                  ButtonSegment(
                    value: CandidatesArea.field,
                    icon: Icon(Icons.insights_outlined),
                    label: Text('Field'),
                  ),
                  ButtonSegment(
                    value: CandidatesArea.endorsementHq,
                    icon: Icon(Icons.workspace_premium),
                    label: Text('Endorsement HQ'),
                  ),
                ],
                selected: {area},
                onSelectionChanged: (s) => onChanged(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return MoydBrand.gold;
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return MoydBrand.navy;
                    }
                    return Colors.white;
                  }),
                  side: WidgetStatePropertyAll(
                    BorderSide(color: Colors.white.withOpacity(0.4)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
