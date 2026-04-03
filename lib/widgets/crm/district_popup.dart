import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  DISTRICT POPUP
//  Overlay popup showing candidate info when a district is
//  tapped on the map. Animates in/out with slide + fade.
// ═══════════════════════════════════════════════════════════════

class DistrictPopup extends StatefulWidget {
  final String districtNumber;
  final List<Candidate> candidates;
  final VoidCallback onClose;
  final ValueChanged<Candidate> onCandidateTap;
  final DistrictDemographics? demographics;

  const DistrictPopup({
    super.key,
    required this.districtNumber,
    required this.candidates,
    required this.onClose,
    required this.onCandidateTap,
    this.demographics,
  });

  @override
  State<DistrictPopup> createState() => _DistrictPopupState();
}

class _DistrictPopupState extends State<DistrictPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0B1E37).withOpacity(0.95),
                BrandColors.unityBlue.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: BrandColors.sunriseGold.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: BrandColors.sunriseGold.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              // Candidates list
              ...widget.candidates.map(_buildCandidateRow),
              // Demographics summary (if available)
              if (widget.demographics != null) _buildDemographics(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasDem = widget.candidates.any((c) => c.isDemocrat);
    final hasRep = widget.candidates.any((c) => c.isRepublican);
    final hasYd = widget.candidates.any((c) => c.isYoungDem);

    String statusLabel;
    Color statusColor;
    if (hasDem && !hasRep) {
      statusLabel = 'Uncontested (D)';
      statusColor = BrandColors.success;
    } else if (!hasDem && hasRep) {
      statusLabel = 'Uncontested (R)';
      statusColor = BrandColors.republicanRed;
    } else if (hasDem && hasRep) {
      statusLabel = 'Contested';
      statusColor = Colors.amber;
    } else {
      statusLabel = 'Open Seat';
      statusColor = Colors.white38;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: BrandColors.sunriseGold.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map, color: BrandColors.sunriseGold, size: 14),
                const SizedBox(width: 6),
                Text(
                  'District ${widget.districtNumber}',
                  style: const TextStyle(
                    color: BrandColors.sunriseGold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasYd) ...[
            const SizedBox(width: 6),
            const Icon(Icons.star, color: BrandColors.sunriseGold, size: 14),
          ],
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white54, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateRow(Candidate c) {
    Color partyColor;
    if (c.isDemocrat) {
      partyColor = BrandColors.democratBlue;
    } else if (c.isRepublican) {
      partyColor = BrandColors.republicanRed;
    } else {
      partyColor = Colors.amber;
    }

    return InkWell(
      onTap: () => widget.onCandidateTap(c),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Party badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: partyColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: partyColor.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  c.partyShort,
                  style: TextStyle(
                    color: partyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name and details
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YD',
                            style: TextStyle(
                              color: BrandColors.sunriseGold,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.office,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Age + chevron
            if (c.estimatedAge != null)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Age ${c.estimatedAge}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDemographics() {
    final d = widget.demographics!;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          if (d.registeredVoters != null)
            _miniStat('Voters', '${(d.registeredVoters! / 1000).toStringAsFixed(1)}k'),
          if (d.demRegistrationPercent > 0)
            _miniStat('Dem %', '${d.demRegistrationPercent.toStringAsFixed(0)}%'),
          if (d.urbanRural != null)
            _miniStat('Type', d.urbanRural!),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white30, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
