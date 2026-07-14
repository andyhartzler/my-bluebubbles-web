import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/widgets/crm/missouri_map_widget.dart';

/// Bottom sheet shown on mobile when a user taps a candidate row. Presents
/// the candidate's district as a highlighted polygon in a 260px map window
/// + name + office + photo + "View profile" / "Zoom map" action row.
///
/// Desktop/tablet users already see the sticky right-pane map so they don't
/// need this sheet — it's only invoked from the mobile layout.
Future<void> showCandidateDistrictSheet({
  required BuildContext context,
  required Candidate candidate,
  required Map<String, List<Candidate>> houseDistricts,
  required Map<String, List<Candidate>> senateDistricts,
  required Map<String, List<Candidate>> congressionalDistricts,
  required VoidCallback onViewProfile,
  required VoidCallback onOpenFullMap,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (ctx) => _CandidateDistrictSheet(
      candidate: candidate,
      houseDistricts: houseDistricts,
      senateDistricts: senateDistricts,
      congressionalDistricts: congressionalDistricts,
      onViewProfile: onViewProfile,
      onOpenFullMap: onOpenFullMap,
    ),
  );
}

class _CandidateDistrictSheet extends StatefulWidget {
  final Candidate candidate;
  final Map<String, List<Candidate>> houseDistricts;
  final Map<String, List<Candidate>> senateDistricts;
  final Map<String, List<Candidate>> congressionalDistricts;
  final VoidCallback onViewProfile;
  final VoidCallback onOpenFullMap;

  const _CandidateDistrictSheet({
    required this.candidate,
    required this.houseDistricts,
    required this.senateDistricts,
    required this.congressionalDistricts,
    required this.onViewProfile,
    required this.onOpenFullMap,
  });

  @override
  State<_CandidateDistrictSheet> createState() =>
      _CandidateDistrictSheetState();
}

class _CandidateDistrictSheetState extends State<_CandidateDistrictSheet> {
  final _mapController = MissouriMapController();

  @override
  void initState() {
    super.initState();
    // Zoom the sheet's embedded map to the candidate's district. On mobile
    // this raced previously — addPostFrameCallback fired before either the
    // map widget had attached its state to the controller or the GeoJSON
    // had finished parsing, and the controller silently no-op'd. Retry at
    // 1 frame, 250ms, and 1s — covers map mount + tiny/medium/large
    // GeoJSON parse times — without spamming the loader.
    final c = widget.candidate;
    if (c.district == null || c.district!.isEmpty) return;

    void zoom() {
      if (!mounted) return;
      _mapController.zoomToDistrict(
        office: c.office,
        districtNum: c.district,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      zoom();
      Future.delayed(const Duration(milliseconds: 250), zoom);
      Future.delayed(const Duration(seconds: 1), zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    final partyColor = c.isDemocrat
        ? BrandColors.democratBlue
        : c.isRepublican
            ? BrandColors.republicanRed
            : const Color(0xFFFCD34D);

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              BrandColors.unityBlue,
              BrandColors.unityBlue.withOpacity(0.92),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
              color: BrandColors.sunriseGold.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.50),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            // Grab handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Candidate header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _Avatar(candidate: c, partyColor: partyColor),
                  const SizedBox(width: 14),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.isYoungDem) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      BrandColors.sunriseGold,
                                      BrandColors.sunriseGold.withOpacity(0.75),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 11, color: Color(0xFF1a1a2e)),
                                    SizedBox(width: 2),
                                    Text('YD',
                                        style: TextStyle(
                                          color: Color(0xFF1a1a2e),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c.officeDisplay,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: partyColor.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: partyColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                c.partyShort.isEmpty ? c.party : c.partyShort,
                                style: TextStyle(
                                  color: partyColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (c.estimatedAge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Age ${c.estimatedAge}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            if (c.isIncumbent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.white24),
                                ),
                                child: const Text(
                                  'INC',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Embedded district-highlighted map
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: MissouriMapWidget(
                    controller: _mapController,
                    houseDistrictMap: widget.houseDistricts,
                    senateDistrictMap: widget.senateDistricts,
                    congressionalDistrictMap: widget.congressionalDistricts,
                    selectedDistrict: c.district,
                    highlightedDistrict: c.district,
                    height: double.infinity,
                    compactMode: true,
                    showLegend: false,
                    showLabels: false,
                    interactive: true,
                  ),
                ),
              ),
            ),
            // Bottom action row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenFullMap();
                      },
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text('Zoom map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onViewProfile();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View candidate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.sunriseGold,
                        foregroundColor: const Color(0xFF1a1a2e),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Candidate candidate;
  final Color partyColor;
  const _Avatar({required this.candidate, required this.partyColor});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = candidate.avatarUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: partyColor.withOpacity(0.55), width: 2),
        color: partyColor.withOpacity(0.18),
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
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
