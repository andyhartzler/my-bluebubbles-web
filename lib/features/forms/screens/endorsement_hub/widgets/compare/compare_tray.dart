import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../slate_controller.dart';
import '../headshot_avatar.dart';

/// A pinned bottom bar that surfaces the current compare selection: overlapping
/// mini faces plus a "Compare (n)" call to action. Hidden when nothing is
/// selected.
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
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: MoydBrand.navy,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: MoydBrand.navy, width: 2),
                                ),
                                child: HeadshotAvatar(
                                  file: selected[i].model.headshot,
                                  name: selected[i].name,
                                  size: 36,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n == 1
                            ? '1 selected — add another to compare'
                            : '$n candidates selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: controller.clearSelection,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white70),
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: canCompare ? onCompare : null,
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: Text('Compare ($n)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: MoydBrand.gold,
                        foregroundColor: MoydBrand.navy,
                        disabledBackgroundColor: Colors.white24,
                        disabledForegroundColor: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _stackWidth(int n) {
    final shown = n.clamp(1, 6);
    return 36 + (shown - 1) * 26.0;
  }
}
