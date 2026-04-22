import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';

/// Horizontal strip of up to 20 dots summarizing a voter's participation
/// across recent elections.
///
/// - Sorted newest-left.
/// - Filled (steelBlue) = voted, empty (white24 border) = eligibility/no data.
/// - Tap a dot → SnackBar with the election label.
/// - Bottom row shows "N of M elections voted (X%)".
class VoterHistoryStrip extends StatelessWidget {
  final List<VoterHistoryEntry> history;

  /// Total known elections in the window used for the percentage.
  /// If null, falls back to `history.length` (trivially 100%).
  final int? eligibleElections;

  /// Maximum dots to render.
  final int maxDots;

  const VoterHistoryStrip({
    super.key,
    required this.history,
    this.eligibleElections,
    this.maxDots = 20,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<VoterHistoryEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final toShow = sorted.take(maxDots).toList();
    final totalVoted = sorted.length;
    final eligible = eligibleElections ?? totalVoted;
    final pct = eligible > 0
        ? (totalVoted / eligible * 100).round()
        : 0;

    if (toShow.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No voting history on file',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // Taller to support a 32×32 tap target around each dot per
          // Material accessibility guidelines. The dot itself stays 10px.
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: toShow.length,
            separatorBuilder: (_, __) => const SizedBox(width: 2),
            itemBuilder: (context, i) {
              final e = toShow[i];
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.label),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 32,
                  height: 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: BrandColors.steelBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BrandColors.steelBlue.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.typeAbbreviation,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          eligible > 0
              ? '$totalVoted of $eligible elections voted ($pct%)'
              : '$totalVoted elections on record',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
