import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

typedef CandidateTap = void Function(Candidate c);

/// Vertical list of candidate rows. Selecting a row fires [onSelect] (which
/// the split page uses to drive the map's gold ring); double-tap or the
/// trailing open-in-new button fires [onOpen] (full detail screen).
class CandidatesListView extends StatelessWidget {
  final List<Candidate> candidates;
  final String? selectedCandidateId;
  final CandidateTap onSelect;
  final CandidateTap? onOpen;

  const CandidatesListView({
    super.key,
    required this.candidates,
    required this.selectedCandidateId,
    required this.onSelect,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No candidates match the current filters.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      itemCount: candidates.length,
      itemBuilder: (context, i) => _CandidateRow(
        candidate: candidates[i],
        selected: candidates[i].id == selectedCandidateId,
        onTap: () => onSelect(candidates[i]),
        onOpen: onOpen == null ? null : () => onOpen!(candidates[i]),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final Candidate candidate;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected
            ? BrandColors.sunriseGold.withOpacity(0.20)
            : BrandColors.unityBlue.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? BrandColors.sunriseGold.withOpacity(0.70)
              : Colors.white.withOpacity(0.08),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: BrandColors.sunriseGold.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                _PartyBadge(candidate: c),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.isYoungDem) ...[
                            const SizedBox(width: 6),
                            const _YdBadge(),
                          ],
                          if (c.isIncumbent) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text(
                                'INC',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.officeDisplay,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (c.estimatedAge != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${c.estimatedAge}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new,
                      size: 16, color: Colors.white70),
                  tooltip: 'Open profile',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyBadge extends StatelessWidget {
  final Candidate candidate;
  const _PartyBadge({required this.candidate});

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (candidate.isDemocrat) {
      bg = BrandColors.democratBlue;
    } else if (candidate.isRepublican) {
      bg = BrandColors.republicanRed;
    } else {
      bg = Colors.amber;
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(candidate.partyShort,
            style: TextStyle(
                color: bg, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _YdBadge extends StatelessWidget {
  const _YdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BrandColors.sunriseGold.withOpacity(0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.55)),
      ),
      child: const Text('YD',
          style: TextStyle(
              color: BrandColors.sunriseGold,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}
