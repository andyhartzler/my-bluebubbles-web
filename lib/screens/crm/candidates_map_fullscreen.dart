import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/widgets/crm/missouri_map_widget.dart';

/// Full-screen Missouri districts map. Launched from the candidates page
/// via the expand button. Uses the same MissouriMapWidget underneath
/// but fills the viewport and adds an overlay panel for district-level
/// detail when the user taps a polygon.
class CandidatesMapFullscreen extends StatefulWidget {
  final List<Candidate> allCandidates;
  final Map<String, List<Candidate>> houseDistricts;
  final Map<String, List<Candidate>> senateDistricts;
  final Map<String, List<Candidate>> congressionalDistricts;
  final String? initialDistrict;
  final DistrictType? initialType;

  const CandidatesMapFullscreen({
    super.key,
    required this.allCandidates,
    required this.houseDistricts,
    required this.senateDistricts,
    required this.congressionalDistricts,
    this.initialDistrict,
    this.initialType,
  });

  @override
  State<CandidatesMapFullscreen> createState() => _CandidatesMapFullscreenState();
}

class _CandidatesMapFullscreenState extends State<CandidatesMapFullscreen> {
  String? _selectedDistrict;
  DistrictType _selectedType = DistrictType.house;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.initialDistrict;
    _selectedType = widget.initialType ?? DistrictType.house;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final candidatesInDistrict = _selectedDistrict != null
        ? _candidatesForSelection()
        : <Candidate>[];

    return Scaffold(
      backgroundColor: BrandColors.navyBlue,
      body: SafeArea(
        child: Stack(
          children: [
            // Map — fills the viewport
            Positioned.fill(
              child: MissouriMapWidget(
                houseDistrictMap: widget.houseDistricts,
                senateDistrictMap: widget.senateDistricts,
                congressionalDistrictMap: widget.congressionalDistricts,
                height: mq.size.height,
                showLabels: true,
                showLegend: true,
                interactive: true,
                selectedDistrict: _selectedDistrict,
                onDistrictTap: (district, type) {
                  setState(() {
                    _selectedDistrict = district;
                    _selectedType = type;
                  });
                },
              ),
            ),

            // Top bar — close + title
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _topBar(),
            ),

            // Bottom sheet — district detail when one is selected
            if (_selectedDistrict != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _districtPanel(candidatesInDistrict),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final label = switch (_selectedType) {
      DistrictType.house => 'State House',
      DistrictType.senate => 'State Senate',
      DistrictType.congressional => 'U.S. Congressional',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close fullscreen',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.map_outlined, color: BrandColors.sunriseGold, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Missouri Districts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
            ),
            child: Text(
              '${widget.allCandidates.length} candidates',
              style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white70, size: 22),
            tooltip: 'Exit fullscreen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _districtPanel(List<Candidate> candidates) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: BrandColors.sunriseGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_typeLabel(_selectedType)} District $_selectedDistrict',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${candidates.length} candidate${candidates.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  tooltip: 'Clear selection',
                  onPressed: () => setState(() => _selectedDistrict = null),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: candidates.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No candidates filed in this district for 2026.',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) => _candidateRow(candidates[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _candidateRow(Candidate c) {
    final color = c.isDemocrat
        ? BrandColors.democratBlue
        : c.isRepublican
            ? BrandColors.republicanRed
            : Colors.white60;
    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openCandidate(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: BrandColors.navyBlue,
                backgroundImage: (c.photoUrl != null && c.photoUrl!.isNotEmpty) ? NetworkImage(c.photoUrl!) : null,
                child: (c.photoUrl == null || c.photoUrl!.isEmpty)
                    ? Text(c.initials, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(c.partyShort,
                            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(c.officeDisplay,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ),
              ),
              if (c.isYoungDem)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BrandColors.sunriseGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('YD',
                      style: TextStyle(color: BrandColors.sunriseGold, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  List<Candidate> _candidatesForSelection() {
    final map = switch (_selectedType) {
      DistrictType.house => widget.houseDistricts,
      DistrictType.senate => widget.senateDistricts,
      DistrictType.congressional => widget.congressionalDistricts,
    };
    return map[_selectedDistrict] ?? const [];
  }

  String _typeLabel(DistrictType t) => switch (t) {
        DistrictType.house => 'State House',
        DistrictType.senate => 'State Senate',
        DistrictType.congressional => 'Congressional',
      };

  void _openCandidate(Candidate c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CandidateDetailScreen(candidate: c)),
    );
  }
}
