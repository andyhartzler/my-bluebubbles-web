import 'package:flutter/material.dart';

import 'package:bluebubbles/screens/crm/volunteers/activities_hub_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/candidate_volunteers_map.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE VOLUNTEERS WORKSPACE (the "War Room" shell)
//
//  A slim two-tab shell over the shipped Missouri map and the new
//  Activities hub. The map's selection + camera geometry must SURVIVE a
//  tab switch, so the body is an IndexedStack rather than a rebuild: the
//  map is constructed once and simply hidden while Activities is up.
//
//  This is the widget CandidatesPage mounts for CandidatesArea.volunteers.
// ═══════════════════════════════════════════════════════════════

enum _WorkspaceTab { map, activities }

class CandidateVolunteersWorkspace extends StatefulWidget {
  const CandidateVolunteersWorkspace({super.key});

  @override
  State<CandidateVolunteersWorkspace> createState() =>
      _CandidateVolunteersWorkspaceState();
}

class _CandidateVolunteersWorkspaceState
    extends State<CandidateVolunteersWorkspace> {
  _WorkspaceTab _tab = _WorkspaceTab.map;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabBar(
          active: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        Expanded(
          // IndexedStack keeps BOTH children mounted; switching tabs only
          // toggles which is painted, so the map keeps its region + zoom.
          child: IndexedStack(
            index: _tab.index,
            children: [
              CandidateVolunteersMap(
                // The statewide rail's "All activities" link and "This week"
                // footer flip us to the Activities tab.
                onOpenActivities: () =>
                    setState(() => _tab = _WorkspaceTab.activities),
              ),
              const ActivitiesHubScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact sub-tab strip sitting under the Candidates area switcher. Uses a 2px
/// accent underline for the active tab so it reads as a nested tab rather than a
/// second heavyweight segmented control. Legible in both themes.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.active, required this.onChanged});

  final _WorkspaceTab active;
  final ValueChanged<_WorkspaceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final vt = VolunteersTheme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: vt.surface,
        border: Border(bottom: BorderSide(color: vt.divider)),
      ),
      child: Row(
        children: [
          _tab(context, _WorkspaceTab.map, 'MAP', Icons.map_outlined, vt),
          _tab(context, _WorkspaceTab.activities, 'ACTIVITIES',
              Icons.event_note_outlined, vt),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    _WorkspaceTab tab,
    String label,
    IconData icon,
    VolunteersTheme vt,
  ) {
    final selected = active == tab;
    final activeColor = vt.accent;
    final fg = selected ? activeColor : vt.secondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(tab),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? activeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
