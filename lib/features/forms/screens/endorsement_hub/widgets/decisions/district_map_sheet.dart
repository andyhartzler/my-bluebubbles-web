import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/crm/missouri_map_widget.dart';

import '../../../../widgets/review/stance_visuals.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'district_ref.dart';

/// Bottom sheet showing the candidate's district polygon on the Missouri map,
/// hub-branded (solid navy surface, never Theme.cardColor: white on navy is
/// ~11:1 and the gold pill / CTA carry navy text at ~5.8:1, never
/// white-on-gold). Opened from a ballot row's district chip.
Future<void> showDistrictMapSheet(
  BuildContext context, {
  required CandidateEntry entry,
  required DistrictRef ref,
  required VoidCallback onOpenReview,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _DistrictMapSheet(
      entry: entry,
      districtRef: ref,
      onOpenReview: onOpenReview,
    ),
  );
}

class _DistrictMapSheet extends StatefulWidget {
  final CandidateEntry entry;
  final DistrictRef districtRef;
  final VoidCallback onOpenReview;

  const _DistrictMapSheet({
    required this.entry,
    required this.districtRef,
    required this.onOpenReview,
  });

  @override
  State<_DistrictMapSheet> createState() => _DistrictMapSheetState();
}

class _DistrictMapSheetState extends State<_DistrictMapSheet> {
  final _mapController = MissouriMapController();

  @override
  void initState() {
    super.initState();
    // Zoom the embedded map to the district. Same race as the candidate
    // district sheet: addPostFrameCallback can fire before the map widget has
    // attached its state to the controller or the GeoJSON has finished
    // parsing, and the controller silently no-ops. Retry at 1 frame, 250ms,
    // and 1s (covers map mount + GeoJSON parse) without spamming the loader.
    void zoom() {
      if (!mounted) return;
      _mapController.zoomToDistrict(
        office: widget.districtRef.mapOffice,
        districtNum: widget.districtRef.districtNum,
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
    final e = widget.entry;
    final ref = widget.districtRef;
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: HubTheme.navy,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border:
              Border.all(color: HubTheme.gold.withOpacity(0.25), width: 1),
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
                  color: Colors.white24,
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
                  HeadshotAvatar(file: e.headshot, name: e.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        if (e.officeLine.isNotEmpty)
                          Text(e.officeLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            // Gold pill with NAVY text (~5.8:1); never
                            // white-on-gold, which fails AA.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: HubTheme.gold,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(ref.shortLabel,
                                  style: const TextStyle(
                                      color: HubTheme.navy,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (e.alignmentPct != null) ...[
                              const SizedBox(width: 6),
                              AlignmentBadge(pct: e.alignmentPct!, dense: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Embedded district-highlighted map. The hub has no Candidate
            // maps to pass; those only drive fill color, and the polygons
            // come from the widget's bundled GeoJSON.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: MissouriMapWidget(
                    controller: _mapController,
                    houseDistrictMap: const {},
                    senateDistrictMap: const {},
                    congressionalDistrictMap: const {},
                    selectedDistrict: ref.districtNum,
                    highlightedDistrict: ref.districtNum,
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
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenReview();
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Full review'),
                style: FilledButton.styleFrom(
                  backgroundColor: HubTheme.gold,
                  foregroundColor: HubTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
