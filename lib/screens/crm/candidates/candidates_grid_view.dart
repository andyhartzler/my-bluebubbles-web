import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

typedef CandidateTap = void Function(Candidate c);

/// Photo-forward responsive card grid. Cards expand to max 300px wide each,
/// with the selected card getting a gold gradient halo + lift shadow.
class CandidatesGridView extends StatelessWidget {
  final List<Candidate> candidates;
  final String? selectedCandidateId;
  final CandidateTap onSelect;
  final CandidateTap? onOpen;

  const CandidatesGridView({
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
        child: Text('No candidates match the current filters.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: candidates.length,
      itemBuilder: (context, i) {
        final c = candidates[i];
        final selected = c.id == selectedCandidateId;
        return _GridCard(
          candidate: c,
          selected: selected,
          onTap: () => onSelect(c),
          onOpen: onOpen == null ? null : () => onOpen!(c),
        );
      },
    );
  }
}

class _GridCard extends StatelessWidget {
  final Candidate candidate;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  const _GridCard({
    required this.candidate,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final partyColor = c.isDemocrat
        ? BrandColors.democratBlue
        : c.isRepublican
            ? BrandColors.republicanRed
            : Colors.amber;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      BrandColors.sunriseGold.withOpacity(0.35),
                      BrandColors.unityBlue.withOpacity(0.95),
                    ]
                  : [
                      BrandColors.unityBlue.withOpacity(0.95),
                      BrandColors.unityBlue.withOpacity(0.80),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? BrandColors.sunriseGold.withOpacity(0.8)
                  : Colors.white.withOpacity(0.08),
              width: selected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(selected ? 0.4 : 0.2),
                blurRadius: selected ? 18 : 8,
                offset: const Offset(0, 4),
              ),
              if (selected)
                BoxShadow(
                  color: BrandColors.sunriseGold.withOpacity(0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CorsAwareAvatar(
                    imageUrl: c.effectivePhotoUrl,
                    fallbackText: c.name,
                    radius: 26,
                  ),
                  const Spacer(),
                  if (c.isYoungDem)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BrandColors.sunriseGold.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: BrandColors.sunriseGold.withOpacity(0.55)),
                      ),
                      child: const Text('Young Dem',
                          style: TextStyle(
                              color: BrandColors.sunriseGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(c.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(c.officeDisplay,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: partyColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: partyColor.withOpacity(0.55)),
                    ),
                    child: Text(c.partyShort,
                        style: TextStyle(
                            color: partyColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  if (c.estimatedAge != null)
                    Text('Age ${c.estimatedAge}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
