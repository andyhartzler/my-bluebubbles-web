import 'package:flutter/material.dart';

import '../../slate_controller.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';

/// A pinned bottom bar that surfaces the current compare selection: overlapping
/// mini faces plus a "Compare (n)" call to action. Hidden when nothing is
/// selected. Gradient surface with gold CTA, matching the hub's hero language.
class CompareTray extends StatelessWidget {
  final SlateController controller;

  /// Fired when the user taps "Compare (n)" — the host switches to the Compare
  /// tab's side-by-side view.
  final VoidCallback onCompare;

  const CompareTray({
    super.key,
    required this.controller,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.selectedEntries;
        if (selected.isEmpty) return const SizedBox.shrink();
        final n = selected.length;
        final canCompare = n >= 2;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: HubTheme.hero,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: HubTheme.royal.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: _stackWidth(n),
                    child: Stack(
                      children: [
                        for (var i = 0; i < selected.length && i < 6; i++)
                          Positioned(
                            left: i * 26.0,
                            child: Tooltip(
                              message: selected[i].name,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: HubTheme.gold, width: 1.6),
                                ),
                                child: HeadshotAvatar(
                                  file: selected[i].model.headshot,
                                  name: selected[i].name,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n == 1
                              ? '1 candidate selected'
                              : '$n candidates selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!canCompare)
                          const Text(
                            'Add one more to start the side-by-side',
                            style: TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: controller.clearSelection,
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: canCompare ? onCompare : null,
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    label: Text('Compare ($n)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HubTheme.gold,
                      foregroundColor: HubTheme.navy,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      // Dark disabled fill so the label stays readable on the
                      // gradient (white on this blend is > 7:1).
                      disabledBackgroundColor:
                          HubTheme.navy.withOpacity(0.55),
                      disabledForegroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _stackWidth(int n) {
    final shown = n.clamp(1, 6);
    return 36 + (shown - 1) * 26.0 + 4;
  }
}
