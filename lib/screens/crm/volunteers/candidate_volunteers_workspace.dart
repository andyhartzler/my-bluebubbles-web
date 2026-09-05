import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/volunteers/activities_hub_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/candidate_volunteers_map.dart';
import 'package:bluebubbles/screens/crm/volunteers/mobilize_desk_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/mobilize_models.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE VOLUNTEERS WORKSPACE (the "War Room" shell)
//
//  A slim three-tab shell over the shipped Missouri map, the Mobilize Desk
//  and the Activities hub. The map's selection + camera geometry must SURVIVE
//  a tab switch, so the body is an IndexedStack rather than a rebuild: the
//  map is constructed once and simply hidden while another tab is up. The
//  Desk relies on the same thing: an audience picked on the map survives a
//  trip back for ten more people.
//
//  This is the widget CandidatesPage mounts for CandidatesArea.volunteers.
// ═══════════════════════════════════════════════════════════════

/// Declaration order IS the IndexedStack child order, because the stack is
/// indexed by the ordinal. Adding a value here means adding its child in the
/// same position below.
enum _WorkspaceTab { map, mobilize, activities }

class CandidateVolunteersWorkspace extends StatefulWidget {
  const CandidateVolunteersWorkspace({super.key});

  @override
  State<CandidateVolunteersWorkspace> createState() =>
      _CandidateVolunteersWorkspaceState();
}

class _CandidateVolunteersWorkspaceState
    extends State<CandidateVolunteersWorkspace> {
  _WorkspaceTab _tab = _WorkspaceTab.map;

  /// The map's one-way channel into the Desk. A notifier rather than a
  /// constructor field because the Desk stays MOUNTED: it listens once and
  /// reacts to each new audience without being rebuilt from scratch.
  final ValueNotifier<MobilizeRequest?> _mobilizeHandoff =
      ValueNotifier<MobilizeRequest?>(null);

  @override
  void dispose() {
    _mobilizeHandoff.dispose();
    super.dispose();
  }

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
                // MOBILIZE hands the audience over and flips to the Desk. The
                // map keeps its region and camera, so Change goes straight
                // back to the selection the exec left.
                onMobilize: (request) {
                  _mobilizeHandoff.value = request;
                  setState(() => _tab = _WorkspaceTab.mobilize);
                },
              ),
              MobilizeDeskScreen(
                handoff: _mobilizeHandoff,
                active: _tab == _WorkspaceTab.mobilize,
                onOpenMap: () => setState(() => _tab = _WorkspaceTab.map),
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

/// Sub-tab strip sitting under the Candidates area switcher, in the Slack tab
/// idiom: the brand gradient band, white labels against white70, and a
/// sunriseGold indicator on the active tab. The labels sit at the band's left
/// edge, which is the gradient's navy end, so white and white70 both clear
/// 4.5:1 without a contrast shadow.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.active, required this.onChanged});

  final _WorkspaceTab active;
  final ValueChanged<_WorkspaceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: Row(
        children: [
          _tab(_WorkspaceTab.map, 'MAP', Icons.map_outlined),
          _tab(_WorkspaceTab.mobilize, 'MOBILIZE', Icons.campaign_outlined),
          _tab(_WorkspaceTab.activities, 'ACTIVITIES', Icons.event_note_outlined),
        ],
      ),
    );
  }

  Widget _tab(_WorkspaceTab tab, String label, IconData icon) {
    final selected = active == tab;
    final fg = selected ? Colors.white : Colors.white70;

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
                color: selected ? BrandColors.sunriseGold : Colors.transparent,
                width: 3,
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
