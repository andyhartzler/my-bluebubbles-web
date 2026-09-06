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

class _CandidateRow extends StatefulWidget {
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
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    final selected = widget.selected;
    final partyColor = c.isDemocrat
        ? BrandColors.democratBlue
        : c.isRepublican
            ? BrandColors.republicanRed
            : Colors.amber;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    BrandColors.sunriseGold.withOpacity(0.22),
                    BrandColors.unityBlue.withOpacity(0.92),
                  ]
                : _hovered
                    ? [
                        BrandColors.unityBlue.withOpacity(0.96),
                        BrandColors.momentumBlue.withOpacity(0.28),
                      ]
                    : [
                        BrandColors.unityBlue.withOpacity(0.92),
                        BrandColors.unityBlue.withOpacity(0.80),
                      ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? BrandColors.sunriseGold.withOpacity(0.70)
                : _hovered
                    ? BrandColors.sunriseGold.withOpacity(0.25)
                    : Colors.white.withOpacity(0.08),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BrandColors.sunriseGold.withOpacity(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onDoubleTap: widget.onOpen,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              child: Row(
                children: [
                  _Avatar(candidate: c, partyColor: partyColor),
                  const SizedBox(width: 12),
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
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
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
                              const _IncBadge(),
                            ],
                            if (c.isEndorsed) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded,
                                  color: BrandColors.success, size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // Party pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: partyColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c.partyShort.isEmpty
                                    ? c.party
                                    : c.partyShort,
                                style: TextStyle(
                                  color: partyColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                c.officeDisplay,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (c.estimatedAge != null) ...[
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Text(
                        '${c.estimatedAge}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: widget.onOpen,
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 16, color: Colors.white70),
                    tooltip: 'Open profile',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar: network photo if present, party-initials fallback with subtle
/// colored ring otherwise. Small enough to keep the row compact.
class _Avatar extends StatelessWidget {
  final Candidate candidate;
  final Color partyColor;
  const _Avatar({required this.candidate, required this.partyColor});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = candidate.effectivePhotoUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: partyColor.withOpacity(0.22),
        border: Border.all(color: partyColor.withOpacity(0.55), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        candidate.initials,
        style: TextStyle(
          color: partyColor,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IncBadge extends StatelessWidget {
  const _IncBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: const Text(
        'INC',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
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
