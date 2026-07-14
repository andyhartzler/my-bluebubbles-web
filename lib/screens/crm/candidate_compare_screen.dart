import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE COMPARE SCREEN
//  Side-by-side comparison of two candidates with visual diffs
//  on demographics, scores, social presence, and engagement.
// ═══════════════════════════════════════════════════════════════

class CandidateCompareScreen extends StatefulWidget {
  final Candidate candidateA;
  final Candidate? candidateB;

  const CandidateCompareScreen({
    super.key,
    required this.candidateA,
    this.candidateB,
  });

  @override
  State<CandidateCompareScreen> createState() =>
      _CandidateCompareScreenState();
}

class _CandidateCompareScreenState extends State<CandidateCompareScreen>
    with SingleTickerProviderStateMixin {
  final CandidateRepository _repo = CandidateRepository();

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  Candidate? _candidateB;
  List<Candidate> _availableCandidates = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _candidateB = widget.candidateB;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_candidateB == null) {
      _loadSuggestions();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);

    // Load candidates from same district or similar office
    List<Candidate> suggestions = [];

    if (widget.candidateA.district != null) {
      suggestions = await _repo.fetchCandidatesByDistrict(
          widget.candidateA.district!);
      suggestions.removeWhere((c) => c.id == widget.candidateA.id);
    }

    // If no district matches, load by same office level
    if (suggestions.isEmpty) {
      suggestions = await _repo.fetchCandidates(
        officeLevel: widget.candidateA.officeLevel,
        limit: 50,
      );
      suggestions.removeWhere((c) => c.id == widget.candidateA.id);
    }

    setState(() {
      _availableCandidates = suggestions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1E37), BrandColors.unityBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _candidateB == null
                      ? _buildPickerView()
                      : _buildComparisonView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Compare Candidates',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_candidateB != null)
            GestureDetector(
              onTap: () => setState(() => _candidateB = null),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Picker when candidateB not selected ──

  Widget _buildPickerView() {
    return Column(
      children: [
        // Candidate A header
        _candidateHeader(widget.candidateA, 'Candidate A'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: BrandColors.sunriseGold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Select a candidate to compare against:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: BrandColors.sunriseGold))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _availableCandidates.length,
                  itemBuilder: (context, index) {
                    final c = _availableCandidates[index];
                    return _candidatePickerRow(c);
                  },
                ),
        ),
      ],
    );
  }

  Widget _candidatePickerRow(Candidate c) {
    Color partyColor;
    if (c.isDemocrat) {
      partyColor = BrandColors.democratBlue;
    } else if (c.isRepublican) {
      partyColor = BrandColors.republicanRed;
    } else {
      partyColor = Colors.amber;
    }

    return GestureDetector(
      onTap: () => setState(() => _candidateB = c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BrandColors.unityBlue.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: partyColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  c.partyShort,
                  style: TextStyle(
                    color: partyColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    c.officeDisplay,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (c.isYoungDem)
              const Icon(Icons.star, color: BrandColors.sunriseGold, size: 16),
            const SizedBox(width: 4),
            const Icon(Icons.compare_arrows, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Full comparison view ──

  Widget _buildComparisonView() {
    final a = widget.candidateA;
    final b = _candidateB!;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Headers
        Row(
          children: [
            Expanded(child: _candidateHeader(a, 'Candidate A')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VS',
                  style: TextStyle(
                      color: BrandColors.sunriseGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _candidateHeader(b, 'Candidate B')),
          ],
        ),
        const SizedBox(height: 16),

        // Quick stats comparison
        _compareSection('Basic Info', [
          _compareRow('Party', a.party, b.party),
          _compareRow('Office', a.office, b.office),
          _compareRow('District', a.district ?? '—', b.district ?? '—'),
          _compareRow('Age', '${a.estimatedAge ?? '?'}', '${b.estimatedAge ?? '?'}'),
          _compareRow('Filed', a.filingDate ?? '—', b.filingDate ?? '—'),
        ]),
        const SizedBox(height: 12),

        // Score comparison
        _compareSection('Young Dem Score', [
          _compareScoreRow('Total Score', a.youngDemScore, b.youngDemScore, 100),
          _compareScoreRow('Party', a.scoreParty, b.scoreParty, 100),
          _compareScoreRow('Primary', a.scorePrimary, b.scorePrimary, 100),
          _compareScoreRow('Finance', a.scoreContributions, b.scoreContributions, 100),
          _compareScoreRow('VAN', a.scoreVan, b.scoreVan, 100),
          _compareScoreRow('Endorsements', a.scoreEndorsements, b.scoreEndorsements, 100),
        ]),
        const SizedBox(height: 12),

        // Digital presence
        _compareSection('Digital Presence', [
          _compareBoolRow('Campaign Website', a.campaignWebsite?.isNotEmpty ?? false, b.campaignWebsite?.isNotEmpty ?? false),
          _compareBoolRow('Twitter/X', a.socialTwitter?.isNotEmpty ?? false, b.socialTwitter?.isNotEmpty ?? false),
          _compareBoolRow('Instagram', a.socialInstagram?.isNotEmpty ?? false, b.socialInstagram?.isNotEmpty ?? false),
          _compareBoolRow('Facebook', a.socialFacebook?.isNotEmpty ?? false, b.socialFacebook?.isNotEmpty ?? false),
          _compareBoolRow('LinkedIn', a.socialLinkedin?.isNotEmpty ?? false, b.socialLinkedin?.isNotEmpty ?? false),
          _compareRow('Social Links', '${a.socialLinkCount}', '${b.socialLinkCount}'),
        ]),
        const SizedBox(height: 12),

        // MOYD Engagement
        _compareSection('MOYD Engagement', [
          _compareBoolRow('Contacted', a.isContacted, b.isContacted),
          _compareBoolRow('Endorsed', a.isEndorsed, b.isEndorsed),
          _compareBoolRow('Young Dem', a.isYoungDem, b.isYoungDem),
          _compareRow('Assigned To', a.assignedTo ?? '—', b.assignedTo ?? '—'),
        ]),
        const SizedBox(height: 12),

        // Background
        _compareSection('Background', [
          _compareRow('Occupation', a.occupation ?? '—', b.occupation ?? '—'),
          _compareRow('Education', a.education ?? '—', b.education ?? '—'),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _candidateHeader(Candidate c, String label) {
    Color partyColor;
    if (c.isDemocrat) {
      partyColor = BrandColors.democratBlue;
    } else if (c.isRepublican) {
      partyColor = BrandColors.republicanRed;
    } else {
      partyColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            partyColor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: partyColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: partyColor.withOpacity(0.2),
            backgroundImage: c.avatarUrl != null
                ? NetworkImage(c.avatarUrl!)
                : null,
            child: c.avatarUrl == null
                ? Text(
                    c.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            c.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            c.compactOffice,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          if (c.isYoungDem) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '⭐ YD',
                style: TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compareSection(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _compareRow(String label, String valueA, String valueB) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              valueA,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.right,
              maxLines: 2,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valueB,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.left,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareScoreRow(String label, int valueA, int valueB, int max) {
    final betterA = valueA > valueB;
    final betterB = valueB > valueA;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$valueA',
                  style: TextStyle(
                    color: betterA ? BrandColors.success : Colors.white70,
                    fontSize: 13,
                    fontWeight: betterA ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: max > 0 ? valueA / max : 0,
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        betterA ? BrandColors.success : BrandColors.momentumBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: max > 0 ? valueB / max : 0,
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        betterB ? BrandColors.success : BrandColors.momentumBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$valueB',
                  style: TextStyle(
                    color: betterB ? BrandColors.success : Colors.white70,
                    fontSize: 13,
                    fontWeight: betterB ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareBoolRow(String label, bool valueA, bool valueB) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(
                valueA ? Icons.check_circle : Icons.cancel,
                color: valueA ? BrandColors.success : Colors.white24,
                size: 18,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                valueB ? Icons.check_circle : Icons.cancel,
                color: valueB ? BrandColors.success : Colors.white24,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
