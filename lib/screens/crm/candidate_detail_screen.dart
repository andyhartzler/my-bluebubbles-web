import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE DETAIL SCREEN
//  Full profile view for any candidate in the 2026 cycle
// ═══════════════════════════════════════════════════════════════

class CandidateDetailScreen extends StatefulWidget {
  final Candidate candidate;

  const CandidateDetailScreen({super.key, required this.candidate});

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  final CandidateRepository _repo = CandidateRepository();
  final TextEditingController _notesController = TextEditingController();
  bool _editingNotes = false;
  bool _savingNotes = false;

  Candidate get c => widget.candidate;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    _notesController.text = c.notes ?? '';
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    await _repo.updateNotes(c.id, _notesController.text);
    setState(() {
      _savingNotes = false;
      _editingNotes = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notes saved'),
          backgroundColor: BrandColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandedBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: CustomScrollView(
                slivers: [
                  // ── App Bar ──
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    expandedHeight: 0,
                    pinned: true,
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeroSection(),
                        const SizedBox(height: 16),
                        if (c.isYoungDem) ...[
                          _buildYoungDemScore(),
                          const SizedBox(height: 16),
                        ],
                        if (c.hasSocialLinks) ...[
                          _buildSocialLinks(),
                          const SizedBox(height: 16),
                        ],
                        if (_hasProfileInfo) ...[
                          _buildProfileInfo(),
                          const SizedBox(height: 16),
                        ],
                        if (c.campaignIssues != null &&
                            c.campaignIssues!.isNotEmpty) ...[
                          _buildCampaignIssues(),
                          const SizedBox(height: 16),
                        ],
                        if (c.endorsements != null &&
                            c.endorsements!.isNotEmpty) ...[
                          _buildEndorsements(),
                          const SizedBox(height: 16),
                        ],
                        _buildElectionHistory(),
                        const SizedBox(height: 16),
                        _buildEngagementTracking(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HERO SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroSection() {
    Color partyColor;
    String partyLabel;
    if (c.isDemocrat) {
      partyColor = BrandColors.democratBlue;
      partyLabel = 'Democrat';
    } else if (c.isRepublican) {
      partyColor = BrandColors.republicanRed;
      partyLabel = 'Republican';
    } else {
      partyColor = Colors.amber;
      partyLabel = c.party;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.unityBlue.withOpacity(0.85),
            partyColor.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: partyColor.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Hero(
            tag: 'candidate-${c.id}',
            child: CircleAvatar(
              radius: 48,
              backgroundColor: partyColor.withOpacity(0.2),
              backgroundImage:
                  c.photoUrl != null && c.photoUrl!.isNotEmpty
                      ? NetworkImage(c.photoUrl!)
                      : null,
              child: c.photoUrl == null || c.photoUrl!.isEmpty
                  ? Text(
                      c.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            c.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Office + District
          Text(
            c.officeDisplay,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Badges row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _badge(partyLabel, partyColor),
              if (c.estimatedAge != null)
                _badge('Age ${c.estimatedAge}', Colors.white54),
              if (c.isYoungDem)
                _badge(
                  '⭐ Young Democrat',
                  BrandColors.sunriseGold,
                  textColor: Colors.black87,
                ),
              if (c.officeLevel != null)
                _badge(
                  c.officeLevel!.substring(0, 1).toUpperCase() +
                      c.officeLevel!.substring(1),
                  BrandColors.steelBlue,
                ),
              if (c.filingDate != null && c.filingDate!.isNotEmpty)
                _badge('Filed ${c.filingDate}', Colors.white30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(color == Colors.white54 || color == Colors.white30 ? 0.15 : 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  YOUNG DEM SCORE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildYoungDemScore() {
    final score = c.youngDemScore;
    final maxScore = 100;
    final progress = (score / maxScore).clamp(0.0, 1.0);

    return _card(
      'Young Democrat Score',
      Icons.star,
      BrandColors.sunriseGold,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Score display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $maxScore',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _scoreColor(score),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _scoreLabel(score),
            style: TextStyle(
              color: _scoreColor(score),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Score breakdown
          _scoreRow('Age (14-36)', score >= 20 ? '✓' : '—', score >= 20),
          _scoreRow('Filed as Democrat', c.isDemocrat ? '✓' : '—', c.isDemocrat),
          _scoreRow('Young Dem Score', '$score pts', score > 0),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return BrandColors.success;
    if (score >= 50) return BrandColors.sunriseGold;
    if (score >= 30) return Colors.orange;
    return Colors.white54;
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Excellent – Core Young Democrat';
    if (score >= 50) return 'Strong – Active Young Democrat';
    if (score >= 30) return 'Promising – Potential Ally';
    return 'Developing – Needs Engagement';
  }

  Widget _scoreRow(String label, String value, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? BrandColors.success : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white70 : Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: active ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SOCIAL MEDIA LINKS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSocialLinks() {
    return _card(
      'Connect',
      Icons.link,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (c.campaignWebsite != null && c.campaignWebsite!.isNotEmpty)
                _socialButton(
                  Icons.language,
                  'Website',
                  Colors.white70,
                  () => _launchUrl(c.campaignWebsite!),
                ),
              if (c.socialTwitter != null && c.socialTwitter!.isNotEmpty)
                _socialButton(
                  Icons.alternate_email,
                  'Twitter/X',
                  const Color(0xFF1DA1F2),
                  () => _launchUrl(c.socialTwitter!),
                ),
              if (c.socialInstagram != null && c.socialInstagram!.isNotEmpty)
                _socialButton(
                  Icons.camera_alt,
                  'Instagram',
                  const Color(0xFFE4405F),
                  () => _launchUrl(c.socialInstagram!),
                ),
              if (c.socialFacebook != null && c.socialFacebook!.isNotEmpty)
                _socialButton(
                  Icons.facebook,
                  'Facebook',
                  const Color(0xFF1877F2),
                  () => _launchUrl(c.socialFacebook!),
                ),
              if (c.socialLinkedin != null && c.socialLinkedin!.isNotEmpty)
                _socialButton(
                  Icons.business,
                  'LinkedIn',
                  const Color(0xFF0A66C2),
                  () => _launchUrl(c.socialLinkedin!),
                ),
              if (c.ballotpediaUrl != null && c.ballotpediaUrl!.isNotEmpty)
                _socialButton(
                  Icons.how_to_vote,
                  'Ballotpedia',
                  const Color(0xFF009688),
                  () => _launchUrl(c.ballotpediaUrl!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROFILE INFO (Bio, Occupation, Education)
  // ═══════════════════════════════════════════════════════════════

  bool get _hasProfileInfo =>
      (c.bio?.isNotEmpty ?? false) ||
      (c.occupation?.isNotEmpty ?? false) ||
      (c.education?.isNotEmpty ?? false) ||
      (c.address?.isNotEmpty ?? false);

  Widget _buildProfileInfo() {
    return _card(
      'Profile',
      Icons.person,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (c.bio != null && c.bio!.isNotEmpty) ...[
            const Text(
              'Bio',
              style: TextStyle(
                color: BrandColors.sunriseGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.bio!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          if (c.occupation != null && c.occupation!.isNotEmpty)
            _infoRow(Icons.work, 'Occupation', c.occupation!),
          if (c.education != null && c.education!.isNotEmpty)
            _infoRow(Icons.school, 'Education', c.education!),
          if (c.address != null && c.address!.isNotEmpty)
            _infoRow(Icons.location_on, 'Address', c.address!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CAMPAIGN ISSUES
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCampaignIssues() {
    final issues = c.campaignIssues!
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return _card(
      'Campaign Issues',
      Icons.policy,
      Colors.purpleAccent,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: issues
              .map((issue) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      issue,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ENDORSEMENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEndorsements() {
    final endorsements = c.endorsements!
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return _card(
      'Endorsements',
      Icons.thumb_up,
      BrandColors.success,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: endorsements
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.verified,
                            color: BrandColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ELECTION HISTORY (placeholder for future SOS data)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildElectionHistory() {
    return _card(
      'Election History',
      Icons.how_to_vote,
      BrandColors.steelBlue,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.white.withOpacity(0.3), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.district != null
                          ? 'Historical results for District ${c.district} will be available once SOS data is integrated.'
                          : 'Historical results will be available once SOS data is integrated.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
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

  // ═══════════════════════════════════════════════════════════════
  //  MOYD ENGAGEMENT TRACKING
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEngagementTracking() {
    return _card(
      'MOYD Engagement',
      Icons.track_changes,
      BrandColors.sunriseGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Notes section
          Row(
            children: [
              const Text(
                'Internal Notes',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (!_editingNotes)
                GestureDetector(
                  onTap: () => setState(() => _editingNotes = true),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: BrandColors.sunriseGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_editingNotes)
            Column(
              children: [
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Add notes about this candidate…',
                    hintStyle: const TextStyle(color: Colors.white30),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _notesController.text = c.notes ?? '';
                        setState(() => _editingNotes = false);
                      },
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _savingNotes ? null : _saveNotes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.sunriseGold,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _savingNotes
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.notes?.isNotEmpty == true ? c.notes! : 'No notes yet',
                style: TextStyle(
                  color: c.notes?.isNotEmpty == true
                      ? Colors.white70
                      : Colors.white30,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            Icons.phone,
            'Contact',
            BrandColors.momentumBlue,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contact feature coming soon'),
                  backgroundColor: BrandColors.momentumBlue,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            Icons.thumb_up,
            'Endorse',
            BrandColors.success,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Endorsement tracking coming soon'),
                  backgroundColor: BrandColors.success,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            Icons.note_add,
            'Add Note',
            BrandColors.sunriseGold,
            () {
              setState(() => _editingNotes = true);
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED CARD BUILDER
  // ═══════════════════════════════════════════════════════════════

  Widget _card(String title, IconData icon, Color accent,
      {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.unityBlue.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
