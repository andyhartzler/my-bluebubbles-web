import 'package:flutter/material.dart';

import 'package:bluebubbles/screens/crm/volunteers/activities_hub_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/candidate_volunteers_map.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';

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
            children: const [
              CandidateVolunteersMap(),
              ActivitiesHubScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact sub-tab strip sitting under the Candidates area switcher. Uses a 2px
/// unityBlue underline for the active tab so it reads as a nested tab rather
/// than a second heavyweight segmented control. Legible in both themes.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.active, required this.onChanged});

  final _WorkspaceTab active;
  final ValueChanged<_WorkspaceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1B2337) : Colors.white;
    final divider = isDark ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Row(
        children: [
          _tab(context, _WorkspaceTab.map, 'MAP', Icons.map_outlined, isDark),
          _tab(context, _WorkspaceTab.activities, 'ACTIVITIES',
              Icons.event_note_outlined, isDark),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    _WorkspaceTab tab,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final selected = active == tab;
    const activeColor = MoydMapTheme.unityBlue;
    final idle = isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF5A6478);
    final fg = selected ? activeColor : idle;

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
