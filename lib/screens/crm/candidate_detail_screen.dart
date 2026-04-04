import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE DETAIL SCREEN
//  Full 6-tab profile view for any candidate in the 2026 cycle
//
//  TAB 1: Overview — Bio, social links, score radar, quick actions
//  TAB 2: Campaign Finance — MEC contributions, top donors, timeline
//  TAB 3: Election History — Historical results, charts, trends
//  TAB 4: News & Endorsements — News cards, endorsement list
//  TAB 5: MOYD Engagement — Contact log, notes, endorsement toggle
//  TAB 6: District Intel — Race opponents, partisan lean, context
// ═══════════════════════════════════════════════════════════════

class CandidateDetailScreen extends StatefulWidget {
  final Candidate candidate;

  const CandidateDetailScreen({super.key, required this.candidate});

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late TabController _tabController;
  final CandidateRepository _repo = CandidateRepository();
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── State: General ──
  bool _editingNotes = false;
  bool _savingNotes = false;
  late Candidate _candidate;

  // ── State: Campaign Finance (Tab 2) ──
  bool _financeLoading = true;
  List<Map<String, dynamic>> _mecCommittees = [];
  List<MECContribution> _mecContributions = [];
  List<Map<String, dynamic>> _topDonors = [];
  List<Map<String, dynamic>> _contributionTimeline = [];
  Map<String, dynamic> _financeSummary = {};
  String? _selectedMecId;

  // ── State: Election History (Tab 3) ──
  bool _historyLoading = true;
  List<ElectionResult> _electionResults = [];

  // ── State: News & Endorsements (Tab 4) ──
  bool _newsLoading = true;
  List<CandidateNews> _newsArticles = [];
  List<Map<String, dynamic>> _endorsementRecords = [];

  // ── State: MOYD Engagement (Tab 5) ──
  bool _contactsLoading = true;
  List<CandidateContact> _contactLog = [];
  bool _showContactForm = false;
  final _contactNotesController = TextEditingController();
  final _contactOutcomeController = TextEditingController();
  final _contactSubjectController = TextEditingController();
  String _selectedContactType = 'phone';
  DateTime? _followUpDate;

  // ── State: District Intel (Tab 6) ──
  bool _districtLoading = true;
  List<Candidate> _districtCandidates = [];
  DistrictDemographics? _districtDemographics;
  Map<String, List<Candidate>> _adjacentDistricts = {};

  // ── State: Endorsement Dialog ──
  final _endorserNameController = TextEditingController();
  String _endorsementType = 'organization';

  Candidate get c => _candidate;

  @override
  void initState() {
    super.initState();
    _candidate = widget.candidate;
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
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_onTabChanged);
    _notesController.text = c.notes ?? '';
    _animController.forward();

    // Load initial data
    _loadOverviewData();
  }

  void _onTabChanged() {
    
    final idx = _tabController.index;
    switch (idx) {
      case 1:
        if (_financeLoading) _loadFinanceData();
        break;
      case 2:
        if (_historyLoading) _loadHistoryData();
        break;
      case 3:
        if (_newsLoading) _loadNewsData();
        break;
      case 4:
        if (_contactsLoading) _loadEngagementData();
        break;
      case 5:
        if (_districtLoading) _loadDistrictData();
        break;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    _contactNotesController.dispose();
    _contactOutcomeController.dispose();
    _contactSubjectController.dispose();
    _endorserNameController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadOverviewData() async {
    // Overview data is already on the candidate object
    // Pre-load contacts count for the badge
    _loadEngagementData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _financeLoading = true);

    try {
      // First find MEC committees for this candidate
      final committees = await _repo.getMECCommittees(c.mecCommitteeIds);
      _mecCommittees = committees;

      if (committees.isNotEmpty) {
        final mecId = committees.first['mec_id']?.toString() ?? '';
        _selectedMecId = mecId;

        if (mecId.isNotEmpty) {
          final results = await Future.wait([
            _repo.getMECContributions(mecId),
            _repo.getMECTopDonors(mecId),
            _repo.getMECContributionTimeline(mecId),
            _repo.getMECFinanceSummary(mecId),
          ]);

          _mecContributions = results[0] as List<MECContribution>;
          _topDonors = results[1] as List<Map<String, dynamic>>;
          _contributionTimeline = results[2] as List<Map<String, dynamic>>;
          _financeSummary = results[3] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading finance data: $e');
    }

    if (mounted) setState(() => _financeLoading = false);
  }

  Future<void> _loadHistoryData() async {
    setState(() => _historyLoading = true);

    try {
      if (c.district != null && c.district!.isNotEmpty) {
        _electionResults = await _repo.fetchElectionHistory(c.district!);
      }
    } catch (e) {
      debugPrint('❌ Error loading history data: $e');
    }

    if (mounted) setState(() => _historyLoading = false);
  }

  Future<void> _loadNewsData() async {
    setState(() => _newsLoading = true);

    try {
      final results = await Future.wait([
        _repo.fetchNews(c.id),
        _repo.fetchCandidateEndorsements(c.id),
      ]);

      _newsArticles = results[0] as List<CandidateNews>;
      _endorsementRecords = results[1] as List<Map<String, dynamic>>;
    } catch (e) {
      debugPrint('❌ Error loading news data: $e');
    }

    if (mounted) setState(() => _newsLoading = false);
  }

  Future<void> _loadEngagementData() async {
    setState(() => _contactsLoading = true);

    try {
      _contactLog = await _repo.fetchContacts(c.id);
    } catch (e) {
      debugPrint('❌ Error loading engagement data: $e');
    }

    if (mounted) setState(() => _contactsLoading = false);
  }

  Future<void> _loadDistrictData() async {
    setState(() => _districtLoading = true);

    try {
      if (c.district != null && c.district!.isNotEmpty) {
        final results = await Future.wait([
          _repo.getDistrictCandidates(c.office, c.district!),
          _repo.fetchDistrictDemographics(c.district!),
          _repo.getAdjacentDistrictCandidates(c.district!),
        ]);

        _districtCandidates = results[0] as List<Candidate>;
        _districtDemographics = results[1] as DistrictDemographics?;
        _adjacentDistricts = results[2] as Map<String, List<Candidate>>;
      }
    } catch (e) {
      debugPrint('❌ Error loading district data: $e');
    }

    if (mounted) setState(() => _districtLoading = false);
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    await _repo.updateNotes(c.id, _notesController.text);
    if (!mounted) return;
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

  Future<void> _toggleMOYDEndorsed() async {
    await _repo.toggleMOYDEndorsed(c.id);
    final updated = await _repo.fetchCandidate(c.id);
    if (updated != null && mounted) {
      setState(() => _candidate = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.isEndorsed
              ? '✅ ${c.firstName} marked as MOYD endorsed'
              : '❌ MOYD endorsement removed'),
          backgroundColor: updated.isEndorsed ? BrandColors.success : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _submitContactLog() async {
    final result = await _repo.addContactLog(
      c.id,
      _selectedContactType,
      _contactNotesController.text.trim().isNotEmpty
          ? _contactNotesController.text.trim()
          : null,
      _contactOutcomeController.text.trim().isNotEmpty
          ? _contactOutcomeController.text.trim()
          : null,
      subject: _contactSubjectController.text.trim().isNotEmpty
          ? _contactSubjectController.text.trim()
          : null,
      contactedBy: 'MOYD Team',
      followUpDate: _followUpDate?.toIso8601String(),
    );

    if (result != null && mounted) {
      _contactNotesController.clear();
      _contactOutcomeController.clear();
      _contactSubjectController.clear();
      setState(() {
        _showContactForm = false;
        _followUpDate = null;
      });
      await _loadEngagementData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact logged successfully'),
          backgroundColor: BrandColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addEndorsement() async {
    final name = _endorserNameController.text.trim();
    if (name.isEmpty) return;

    await _repo.addEndorsement(c.id, name, _endorsementType);
    _endorserNameController.clear();
    await _loadNewsData();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Endorsement from "$name" added'),
          backgroundColor: BrandColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddEndorsementDialog() {
    _endorserNameController.clear();
    _endorsementType = 'organization';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: BrandColors.unityBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add Endorsement',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _endorserNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Endorser name (org or individual)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Type:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _endorseTypeChip('organization', 'Organization', Icons.business, setDialogState),
                  _endorseTypeChip('individual', 'Individual', Icons.person, setDialogState),
                  _endorseTypeChip('union', 'Union', Icons.groups, setDialogState),
                  _endorseTypeChip('newspaper', 'Newspaper', Icons.newspaper, setDialogState),
                  _endorseTypeChip('elected_official', 'Elected Official', Icons.gavel, setDialogState),
                  _endorseTypeChip('pac', 'PAC', Icons.monetization_on, setDialogState),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: _addEndorsement,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.sunriseGold,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _endorseTypeChip(String value, String label, IconData icon, StateSetter setDialogState) {
    final selected = _endorsementType == value;
    return GestureDetector(
      onTap: () => setDialogState(() => _endorsementType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BrandColors.sunriseGold.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? BrandColors.sunriseGold : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? BrandColors.sunriseGold : Colors.white38),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail() async {
    if (c.email != null && c.email!.isNotEmpty) {
      await _launchUrl('mailto:${c.email}');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email address on file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone() async {
    if (c.phone != null && c.phone!.isNotEmpty) {
      await _launchUrl('tel:${c.phone}');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone number on file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          backgroundColor: BrandColors.momentumBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD — Main scaffold with tab bar
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandedBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // ── App Bar ──
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(
                          c.isEndorsed ? Icons.star : Icons.star_border,
                          color: c.isEndorsed ? BrandColors.sunriseGold : Colors.white54,
                        ),
                        onPressed: _toggleMOYDEndorsed,
                        tooltip: 'Toggle MOYD Endorsement',
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: BrandColors.unityBlue,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'copy_name', child: Text('Copy Name', style: TextStyle(color: Colors.white))),
                          if (c.email != null) const PopupMenuItem(value: 'copy_email', child: Text('Copy Email', style: TextStyle(color: Colors.white))),
                          if (c.phone != null) const PopupMenuItem(value: 'copy_phone', child: Text('Copy Phone', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'share', child: Text('Share Profile', style: TextStyle(color: Colors.white))),
                        ],
                        onSelected: (val) {
                          switch (val) {
                            case 'copy_name':
                              _copyToClipboard(c.name, 'Name');
                              break;
                            case 'copy_email':
                              _copyToClipboard(c.email ?? '', 'Email');
                              break;
                            case 'copy_phone':
                              _copyToClipboard(c.phone ?? '', 'Phone');
                              break;
                            case 'share':
                              _copyToClipboard(
                                '${c.name} — ${c.officeDisplay}\n${c.party}',
                                'Profile',
                              );
                              break;
                          }
                        },
                      ),
                    ],
                    expandedHeight: 0,
                    pinned: true,
                  ),

                  // ── Hero Profile Card ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _buildCompactHero(),
                    ),
                  ),

                  // ── Tab Bar ──
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      tabBar: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: BrandColors.sunriseGold,
                        unselectedLabelColor: Colors.white54,
                        indicatorColor: BrandColors.sunriseGold,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        unselectedLabelStyle: const TextStyle(fontSize: 13),
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Finance'),
                          Tab(text: 'History'),
                          Tab(text: 'News'),
                          Tab(text: 'MOYD'),
                          Tab(text: 'District'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildFinanceTab(),
                    _buildHistoryTab(),
                    _buildNewsTab(),
                    _buildEngagementTab(),
                    _buildDistrictTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  COMPACT HERO — Persistent header above tabs
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompactHero() {
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
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: partyColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Hero(
            tag: 'candidate-${c.id}',
            child: CircleAvatar(
              radius: 36,
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
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  c.officeDisplay,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge(partyLabel, partyColor),
                    if (c.estimatedAge != null)
                      _badge('Age ${c.estimatedAge}', Colors.white54),
                    if (c.isYoungDem)
                      _badge('⭐ YD', BrandColors.sunriseGold, textColor: Colors.black87),
                    if (c.isEndorsed)
                      _badge('✅ Endorsed', BrandColors.success),
                  ],
                ),
              ],
            ),
          ),
          // Quick actions column
          Column(
            children: [
              _quickActionIcon(Icons.email, 'Email', _launchEmail),
              const SizedBox(height: 8),
              _quickActionIcon(Icons.phone, 'Call', _launchPhone),
              const SizedBox(height: 8),
              _quickActionIcon(Icons.note_add, 'Note', () {
                _tabController.animateTo(4);
                setState(() => _editingNotes = true);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: OVERVIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Score Radar ──
        if (c.isYoungDem) ...[
          _buildYoungDemScore(),
          const SizedBox(height: 16),
        ],

        // ── Score Radar Chart ──
        _buildScoreRadar(),
        const SizedBox(height: 16),

        // ── Social Links ──
        if (c.hasSocialLinks) ...[
          _buildSocialLinks(),
          const SizedBox(height: 16),
        ],

        // ── Contact Info ──
        if (c.hasContactInfo) ...[
          _buildContactInfo(),
          const SizedBox(height: 16),
        ],

        // ── Bio & Profile ──
        if (_hasProfileInfo) ...[
          _buildProfileInfo(),
          const SizedBox(height: 16),
        ],

        // ── Campaign Issues ──
        if (c.campaignIssues != null && c.campaignIssues!.isNotEmpty) ...[
          _buildCampaignIssues(),
          const SizedBox(height: 16),
        ],

        // ── Existing Endorsements ──
        if (c.endorsements != null && c.endorsements!.isNotEmpty) ...[
          _buildEndorsements(),
          const SizedBox(height: 16),
        ],

        // ── Filing Information ──
        _buildFilingInfo(),
        const SizedBox(height: 16),

        // ── Quick Action Buttons ──
        _buildActionButtons(),
      ],
    );
  }

  // ── Score Radar Chart (CustomPaint) ──
  Widget _buildScoreRadar() {
    return _card(
      'Candidate Score Radar',
      Icons.radar,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _ScoreRadarPainter(
                scores: {
                  'Party': c.scoreParty.toDouble(),
                  'Primary': c.scorePrimary.toDouble(),
                  'Finance': c.scoreContributions.toDouble(),
                  'VAN': c.scoreVan.toDouble(),
                  'Endorse': c.scoreEndorsements.toDouble(),
                },
                maxValue: 40,
                accentColor: BrandColors.sunriseGold,
              ),
              size: const Size(220, 220),
            ),
          ),
          const SizedBox(height: 12),
          // Score legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _radarLegend('Party', c.scoreParty, Colors.blue),
              _radarLegend('Primary', c.scorePrimary, Colors.green),
              _radarLegend('Finance', c.scoreContributions, Colors.orange),
              _radarLegend('VAN', c.scoreVan, Colors.purple),
              _radarLegend('Endorse', c.scoreEndorsements, Colors.teal),
            ],
          ),
          const SizedBox(height: 8),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Total Score: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
              Text(
                '${c.youngDemScore}',
                style: TextStyle(
                  color: _scoreColor(c.youngDemScore),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(' / 100', style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _radarLegend(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text('$label: $value', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  // ── Contact Info Card ──
  Widget _buildContactInfo() {
    return _card(
      'Contact Information',
      Icons.contact_phone,
      BrandColors.momentumBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (c.email != null && c.email!.isNotEmpty)
            _contactRow(Icons.email, 'Email', c.email!, () => _launchUrl('mailto:${c.email}')),
          if (c.phone != null && c.phone!.isNotEmpty)
            _contactRow(Icons.phone, 'Phone', c.phone!, () => _launchUrl('tel:${c.phone}')),
          if (c.address != null && c.address!.isNotEmpty)
            _contactRow(Icons.location_on, 'Address', c.address!, null),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BrandColors.momentumBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: BrandColors.momentumBlue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  Text(
                    value,
                    style: TextStyle(
                      color: onTap != null ? BrandColors.momentumBlue : Colors.white,
                      fontSize: 14,
                      decoration: onTap != null ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Filing Info Card ──
  Widget _buildFilingInfo() {
    return _card(
      'Filing Information',
      Icons.assignment,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (c.filingDate != null && c.filingDate!.isNotEmpty)
            _infoRow(Icons.calendar_today, 'Filing Date', c.filingDate!),
          if (c.filingTime != null && c.filingTime!.isNotEmpty)
            _infoRow(Icons.access_time, 'Filing Time', c.filingTime!),
          _infoRow(Icons.account_balance, 'Office', c.office),
          if (c.district != null && c.district!.isNotEmpty)
            _infoRow(Icons.map, 'District', c.district!),
          if (c.officeLevel != null)
            _infoRow(Icons.layers, 'Level', c.officeLevel!.substring(0, 1).toUpperCase() + c.officeLevel!.substring(1)),
          if (c.fecCandidateId != null && c.fecCandidateId!.isNotEmpty)
            _infoRow(Icons.account_balance_wallet, 'FEC ID', c.fecCandidateId!),
          if (c.mecCommitteeIds.isNotEmpty)
            _infoRow(Icons.account_balance_wallet, 'MEC ID', c.mecCommitteeIds.first),
          if (c.voterMatchId != null && c.voterMatchId!.isNotEmpty)
            _infoRow(Icons.how_to_reg, 'Voter Match', c.voterMatchId!),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: CAMPAIGN FINANCE (MEC Data)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFinanceTab() {
    if (_financeLoading) {
      return const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold));
    }

    if (_mecCommittees.isEmpty) {
      return _buildEmptyState(
        Icons.monetization_on,
        'No MEC Campaign Finance Data',
        'No Missouri Ethics Commission committee records found for ${c.name}.\n\nThis candidate may not have filed a committee yet, or the name may not match exactly.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Committee Selector (if multiple) ──
        if (_mecCommittees.length > 1) ...[
          _buildCommitteeSelector(),
          const SizedBox(height: 16),
        ],

        // ── Finance Summary Cards ──
        _buildFinanceSummaryCards(),
        const SizedBox(height: 16),

        // ── Contribution Timeline Chart ──
        if (_contributionTimeline.isNotEmpty) ...[
          _buildContributionTimeline(),
          const SizedBox(height: 16),
        ],

        // ── Top 10 Donors ──
        if (_topDonors.isNotEmpty) ...[
          _buildTopDonors(),
          const SizedBox(height: 16),
        ],

        // ── Recent Contributions List ──
        if (_mecContributions.isNotEmpty) ...[
          _buildRecentContributions(),
          const SizedBox(height: 16),
        ],

        // ── Opponent Fundraising Comparison ──
        _buildOpponentComparison(),
      ],
    );
  }

  Widget _buildCommitteeSelector() {
    return _card(
      'MEC Committee',
      Icons.account_balance,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._mecCommittees.map((committee) {
            final mecId = committee['mec_id']?.toString() ?? '';
            final name = committee['committee_name'] as String? ?? 'Unknown Committee';
            final isSelected = mecId == _selectedMecId;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? BrandColors.sunriseGold.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? BrandColors.sunriseGold.withOpacity(0.5) : Colors.white12,
                ),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.account_balance,
                  color: isSelected ? BrandColors.sunriseGold : Colors.white38,
                  size: 20,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  'MEC ID: $mecId',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: BrandColors.sunriseGold, size: 18)
                    : null,
                onTap: () {
                  setState(() => _selectedMecId = mecId);
                  _loadFinanceData();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFinanceSummaryCards() {
    final totalRaised = _financeSummary['total_raised'] as double? ?? 0;
    final contributionCount = _financeSummary['contribution_count'] as int? ?? 0;
    final monetaryTotal = _financeSummary['monetary_total'] as double? ?? 0;
    final inKindTotal = _financeSummary['in_kind_total'] as double? ?? 0;
    final inKindCount = _financeSummary['in_kind_count'] as int? ?? 0;
    final avgContribution = _financeSummary['avg_contribution'] as double? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _financeStatCard('Total Raised', '\$${_formatMoney(totalRaised)}', Icons.attach_money, BrandColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _financeStatCard('Contributions', '$contributionCount', Icons.receipt_long, BrandColors.momentumBlue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _financeStatCard('Avg Contribution', '\$${_formatMoney(avgContribution)}', Icons.trending_up, BrandColors.sunriseGold)),
            const SizedBox(width: 10),
            Expanded(child: _financeStatCard('Monetary', '\$${_formatMoney(monetaryTotal)}', Icons.payments, BrandColors.steelBlue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _financeStatCard('In-Kind', inKindTotal > 0 ? '\$${_formatMoney(inKindTotal)} ($inKindCount)' : '$inKindCount items', Icons.card_giftcard, Colors.purpleAccent)),
            const SizedBox(width: 10),
            Expanded(child: _financeStatCard('Donors', '${_topDonors.length}+', Icons.people, Colors.tealAccent)),
          ],
        ),
      ],
    );
  }

  Widget _financeStatCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildContributionTimeline() {
    final maxAmount = _contributionTimeline.fold<double>(
      0,
      (max, e) => math.max(max, (e['total'] as num?)?.toDouble() ?? 0),
    );

    return _card(
      'Contribution Timeline',
      Icons.timeline,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _contributionTimeline.map((entry) {
                final total = (entry['total'] as num?)?.toDouble() ?? 0;
                final month = entry['month'] as String? ?? '';
                final height = maxAmount > 0 ? (total / maxAmount) * 130 : 0.0;
                final shortMonth = month.length >= 7 ? month.substring(5, 7) : month;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '\$${_formatMoneyShort(total)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 8),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height.clamp(4.0, 130.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [BrandColors.momentumBlue, BrandColors.sunriseGold],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shortMonth,
                          style: const TextStyle(color: Colors.white38, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDonors() {
    return _card(
      'Top Donors',
      Icons.star,
      BrandColors.sunriseGold,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(math.min(_topDonors.length, 10), (i) {
            final donor = _topDonors[i];
            final name = donor['donor_name'] as String? ?? 'Unknown';
            final amount = (donor['total_amount'] as num?)?.toDouble() ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _donorRankColor(i).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: _donorRankColor(i),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${_formatMoney(amount)}',
                    style: TextStyle(
                      color: _donorRankColor(i),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _donorRankColor(int rank) {
    if (rank == 0) return BrandColors.sunriseGold;
    if (rank == 1) return Colors.grey.shade300;
    if (rank == 2) return Colors.orange;
    return BrandColors.momentumBlue;
  }

  Widget _buildRecentContributions() {
    final recentCount = math.min(_mecContributions.length, 20);

    return _card(
      'Recent Contributions (${_mecContributions.length} total)',
      Icons.receipt_long,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(recentCount, (i) {
            final contrib = _mecContributions[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(i.isEven ? 0.03 : 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contrib.donorName.isNotEmpty ? contrib.donorName : 'Anonymous',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (contrib.donorLocation.isNotEmpty)
                          Text(
                            contrib.donorLocation,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      contrib.contributionDate ?? '',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      contrib.contributionAmount > 0
                          ? '\$${_formatMoney(contrib.contributionAmount)}'
                          : 'In-Kind',
                      style: TextStyle(
                        color: contrib.contributionAmount > 0 ? BrandColors.success : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_mecContributions.length > 20) ...[
            const SizedBox(height: 8),
            Text(
              '+ ${_mecContributions.length - 20} more contributions',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpponentComparison() {
    return _card(
      'Fundraising vs Opponents',
      Icons.compare_arrows,
      Colors.purpleAccent,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white.withOpacity(0.3), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.district != null
                        ? 'Opponent fundraising comparison for District ${c.district} will show here once opponent committee data is linked.'
                        : 'Link opponent committee data to see fundraising comparisons.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
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
  //  TAB 3: ELECTION HISTORY
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Historical Results Bar Chart ──
        if (_electionResults.isNotEmpty) ...[
          _buildElectionBarChart(),
          const SizedBox(height: 16),
          _buildWinMarginTrend(),
          const SizedBox(height: 16),
          _buildVoterTurnoutChart(),
          const SizedBox(height: 16),
          _buildPreviousCandidatesList(),
          const SizedBox(height: 16),
          _buildHistoryDetailList(),
        ] else ...[
          _buildElectionHistoryPlaceholder(),
        ],
      ],
    );
  }

  Widget _buildElectionBarChart() {
    final results = _electionResults.reversed.toList(); // Oldest first
    final maxVotes = results.fold<int>(
      0,
      (max, r) => math.max(max, math.max(r.demVotes ?? 0, r.repVotes ?? 0)),
    );

    return _card(
      'Dem vs Rep Votes by Cycle',
      Icons.bar_chart,
      BrandColors.democratBlue,
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: results.map((r) {
                final demH = maxVotes > 0 ? ((r.demVotes ?? 0) / maxVotes) * 160 : 0.0;
                final repH = maxVotes > 0 ? ((r.repVotes ?? 0) / maxVotes) * 160 : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Dem bar
                            Container(
                              width: 16,
                              height: demH.clamp(4.0, 160.0),
                              decoration: BoxDecoration(
                                color: BrandColors.democratBlue,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                            const SizedBox(width: 2),
                            // Rep bar
                            Container(
                              width: 16,
                              height: repH.clamp(4.0, 160.0),
                              decoration: BoxDecoration(
                                color: BrandColors.republicanRed,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${r.year}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        if (r.demWon)
                          const Text('D', style: TextStyle(color: BrandColors.democratBlue, fontSize: 9, fontWeight: FontWeight.bold))
                        else if (r.repWon)
                          const Text('R', style: TextStyle(color: BrandColors.republicanRed, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(BrandColors.democratBlue, 'Democrat'),
              const SizedBox(width: 16),
              _legendDot(BrandColors.republicanRed, 'Republican'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWinMarginTrend() {
    final results = _electionResults.reversed.toList();

    return _card(
      'Win Margin Trend',
      Icons.trending_up,
      BrandColors.sunriseGold,
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _MarginTrendPainter(
                results: results,
              ),
              size: const Size(double.infinity, 120),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('← Dem Win', style: TextStyle(color: BrandColors.democratBlue, fontSize: 10)),
              const SizedBox(width: 20),
              Container(width: 40, height: 1, color: Colors.white24),
              const SizedBox(width: 20),
              const Text('Rep Win →', style: TextStyle(color: BrandColors.republicanRed, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoterTurnoutChart() {
    final results = _electionResults.reversed.toList();
    final maxTurnout = results.fold<int>(0, (max, r) => math.max(max, r.totalVotes ?? 0));

    return _card(
      'Voter Turnout',
      Icons.people,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...results.map((r) {
            final turnout = r.totalVotes ?? 0;
            final pct = maxTurnout > 0 ? turnout / maxTurnout : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('${r.year}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 16,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(BrandColors.steelBlue.withOpacity(0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 55,
                    child: Text(
                      _formatNumber(turnout),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPreviousCandidatesList() {
    final demCandidates = <String>{};
    final repCandidates = <String>{};

    for (final r in _electionResults) {
      if (r.demCandidate != null && r.demCandidate!.isNotEmpty) {
        demCandidates.add('${r.demCandidate} (${r.year})');
      }
      if (r.repCandidate != null && r.repCandidate!.isNotEmpty) {
        repCandidates.add('${r.repCandidate} (${r.year})');
      }
    }

    return _card(
      'Previous Candidates',
      Icons.history,
      Colors.purpleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (demCandidates.isNotEmpty) ...[
            const Text('Democrats', style: TextStyle(color: BrandColors.democratBlue, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...demCandidates.map((name) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: BrandColors.democratBlue, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )),
            const SizedBox(height: 8),
          ],
          if (repCandidates.isNotEmpty) ...[
            const Text('Republicans', style: TextStyle(color: BrandColors.republicanRed, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...repCandidates.map((name) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: BrandColors.republicanRed, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryDetailList() {
    return _card(
      'Detailed Results',
      Icons.list_alt,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._electionResults.map((r) {
            final demPct = r.demPercent ?? 0;
            final repPct = r.repPercent ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: r.demWon
                      ? BrandColors.democratBlue.withOpacity(0.3)
                      : BrandColors.republicanRed.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${r.year}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: r.demWon ? BrandColors.democratBlue.withOpacity(0.2) : BrandColors.republicanRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r.demWon ? 'Dem Win' : 'Rep Win',
                          style: TextStyle(
                            color: r.demWon ? BrandColors.democratBlue : BrandColors.republicanRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Dem line
                  if (r.demCandidate != null) ...[
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: BrandColors.democratBlue, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(r.demCandidate!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        Text('${_formatNumber(r.demVotes ?? 0)} (${demPct.toStringAsFixed(1)}%)',
                          style: const TextStyle(color: BrandColors.democratBlue, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Rep line
                  if (r.repCandidate != null) ...[
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: BrandColors.republicanRed, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(r.repCandidate!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        Text('${_formatNumber(r.repVotes ?? 0)} (${repPct.toStringAsFixed(1)}%)',
                          style: const TextStyle(color: BrandColors.republicanRed, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                  // Turnout
                  if (r.totalVotes != null) ...[
                    const SizedBox(height: 6),
                    Text('Total votes: ${_formatNumber(r.totalVotes!)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildElectionHistoryPlaceholder() {
    return _buildEmptyState(
      Icons.how_to_vote,
      'No Election History',
      c.district != null
          ? 'Historical results for District ${c.district} will be available once SOS data is integrated.'
          : 'Historical results will be available once SOS data is integrated.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 4: NEWS & ENDORSEMENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNewsTab() {
    if (_newsLoading) {
      return const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── News Articles ──
        _buildNewsSection(),
        const SizedBox(height: 16),

        // ── Endorsements from dedicated table ──
        _buildEndorsementSection(),
        const SizedBox(height: 16),

        // ── Add Endorsement Button ──
        _buildAddEndorsementButton(),
      ],
    );
  }

  Widget _buildNewsSection() {
    if (_newsArticles.isEmpty) {
      return _card(
        'News Mentions',
        Icons.newspaper,
        BrandColors.momentumBlue,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.newspaper, color: Colors.white.withOpacity(0.15), size: 48),
                const SizedBox(height: 8),
                Text(
                  'No news articles found for ${c.firstName}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _card(
      'News Mentions (${_newsArticles.length})',
      Icons.newspaper,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._newsArticles.map((news) => _buildNewsCard(news)),
        ],
      ),
    );
  }

  Widget _buildNewsCard(CandidateNews news) {
    // Simple sentiment detection from headline
    String sentimentLabel = 'Neutral';
    Color sentimentColor = Colors.grey;
    final headline = news.headline.toLowerCase();
    if (headline.contains('wins') || headline.contains('endorsed') || headline.contains('support') || headline.contains('victory')) {
      sentimentLabel = 'Positive';
      sentimentColor = BrandColors.success;
    } else if (headline.contains('loses') || headline.contains('scandal') || headline.contains('contro') || headline.contains('defeat')) {
      sentimentLabel = 'Negative';
      sentimentColor = BrandColors.republicanRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: news.url != null ? () => _launchUrl(news.url!) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    news.headline,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Sentiment badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sentimentColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    sentimentLabel,
                    style: TextStyle(color: sentimentColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (news.summary != null && news.summary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                news.summary!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (news.source != null) ...[
                  Icon(Icons.source, color: Colors.white38, size: 12),
                  const SizedBox(width: 4),
                  Text(news.source!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
                const Spacer(),
                if (news.publishedAt != null)
                  Text(
                    _formatDate(news.publishedAt!),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                if (news.url != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new, color: BrandColors.momentumBlue, size: 14),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndorsementSection() {
    return _card(
      'Endorsements (${_endorsementRecords.length})',
      Icons.thumb_up,
      BrandColors.success,
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (_endorsementRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No endorsements recorded yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                ),
              ),
            )
          else
            ..._endorsementRecords.map((endorsement) {
              final name = endorsement['endorser_name'] as String? ?? 'Unknown';
              final type = endorsement['endorsement_type'] as String? ?? 'organization';
              final notes = endorsement['notes'] as String?;
              final icon = _endorsementTypeIcon(type);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BrandColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: BrandColors.success, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(
                            type.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                          if (notes != null && notes.isNotEmpty)
                            Text(notes, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified, color: BrandColors.success, size: 16),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _endorsementTypeIcon(String type) {
    switch (type) {
      case 'organization': return Icons.business;
      case 'individual': return Icons.person;
      case 'union': return Icons.groups;
      case 'newspaper': return Icons.newspaper;
      case 'elected_official': return Icons.gavel;
      case 'pac': return Icons.monetization_on;
      default: return Icons.thumb_up;
    }
  }

  Widget _buildAddEndorsementButton() {
    return GestureDetector(
      onTap: _showAddEndorsementDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: BrandColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.success.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add, color: BrandColors.success, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Endorsement',
              style: TextStyle(color: BrandColors.success, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 5: MOYD ENGAGEMENT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEngagementTab() {
    if (_contactsLoading) {
      return const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Engagement Status Overview ──
        _buildEngagementStatusCard(),
        const SizedBox(height: 16),

        // ── MOYD Endorsement Toggle ──
        _buildEndorsementToggle(),
        const SizedBox(height: 16),

        // ── Assigned Team Member Selector ──
        _buildAssignedMemberSelector(),
        const SizedBox(height: 16),

        // ── Follow-up Reminder ──
        _buildFollowUpReminder(),
        const SizedBox(height: 16),

        // ── Log Contact Button ──
        _buildLogContactButton(),
        const SizedBox(height: 8),

        // ── Contact Log Form (expandable) ──
        if (_showContactForm) ...[
          _buildContactForm(),
          const SizedBox(height: 16),
        ],

        // ── Contact Log Timeline ──
        _buildContactTimeline(),
        const SizedBox(height: 16),

        // ── Internal Notes ──
        _buildNotesSection(),
        const SizedBox(height: 16),

        // ── MOYD Member Link ──
        _buildMoydMemberLink(),
      ],
    );
  }

  Widget _buildEngagementStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.isContacted ? BrandColors.success.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.isContacted ? BrandColors.success.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              c.isContacted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: c.isContacted ? BrandColors.success : Colors.white38,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.isContacted ? 'Contacted' : 'Not Yet Contacted',
                  style: TextStyle(
                    color: c.isContacted ? BrandColors.success : Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.lastContactDate != null
                      ? 'Last: ${_formatDate(c.lastContactDate!)} via ${c.contactMethod ?? 'unknown'}'
                      : 'No contact recorded',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                Text(
                  '${_contactLog.length} interaction${_contactLog.length == 1 ? '' : 's'} logged',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (c.isEndorsed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⭐ Endorsed',
                style: TextStyle(color: BrandColors.sunriseGold, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEndorsementToggle() {
    return _card(
      'MOYD Endorsement',
      Icons.star,
      BrandColors.sunriseGold,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                c.isEndorsed
                    ? 'This candidate is endorsed by MOYD'
                    : 'Not currently endorsed',
                style: TextStyle(
                  color: c.isEndorsed ? Colors.white : Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(
              value: c.isEndorsed,
              onChanged: (_) => _toggleMOYDEndorsed(),
              activeColor: BrandColors.sunriseGold,
              inactiveTrackColor: Colors.white12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedMemberSelector() {
    // Team members for assignment — extend as team grows
    final teamMembers = CRMConfig.teamMembers.isNotEmpty
        ? [...CRMConfig.teamMembers, 'Unassigned']
        : ['Andrew Hartzler', 'Unassigned'];
    final current = c.assignedTo ?? 'Unassigned';

    return _card(
      'Assigned Team Member',
      Icons.person_pin,
      BrandColors.steelBlue,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: teamMembers.map((member) {
                final isSelected = current == member || (member == 'Unassigned' && current.isEmpty);
                return GestureDetector(
                  onTap: () async {
                    await _repo.assignTeamMember(c.id, member == 'Unassigned' ? null : member);
                    final updated = await _repo.fetchCandidate(c.id);
                    if (updated != null && mounted) setState(() => _candidate = updated);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? BrandColors.steelBlue.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? BrandColors.steelBlue : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.person_outline,
                          color: isSelected ? BrandColors.steelBlue : Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpReminder() {
    // Check for existing follow-ups in contact log
    final upcomingFollowUps = _contactLog
        .where((contact) => contact.followUpDate != null && contact.followUpDate!.isNotEmpty)
        .toList();

    return _card(
      'Follow-up Reminders',
      Icons.alarm,
      Colors.orange,
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (upcomingFollowUps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No follow-up reminders set. Log a contact with a follow-up date to create one.',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
              ),
            )
          else
            ...upcomingFollowUps.map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Follow up: ${contact.followUpDate}',
                            style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (contact.notes != null && contact.notes!.isNotEmpty)
                            Text(
                              contact.notes!,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLogContactButton() {
    return GestureDetector(
      onTap: () => setState(() => _showContactForm = !_showContactForm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: BrandColors.momentumBlue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.momentumBlue.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showContactForm ? Icons.close : Icons.add,
              color: BrandColors.momentumBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _showContactForm ? 'Cancel' : 'Log Contact',
              style: const TextStyle(
                color: BrandColors.momentumBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    final contactTypes = ['phone', 'email', 'in-person', 'text', 'social', 'other'];

    return _card(
      'Log New Contact',
      Icons.edit_note,
      BrandColors.momentumBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Contact type
          const Text('Contact Type', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: contactTypes.map((type) {
              final isSelected = _selectedContactType == type;
              IconData icon;
              switch (type) {
                case 'phone': icon = Icons.phone; break;
                case 'email': icon = Icons.email; break;
                case 'in-person': icon = Icons.people; break;
                case 'text': icon = Icons.message; break;
                case 'social': icon = Icons.share; break;
                default: icon = Icons.contact_mail;
              }

              return GestureDetector(
                onTap: () => setState(() => _selectedContactType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? BrandColors.momentumBlue.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? BrandColors.momentumBlue : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: isSelected ? BrandColors.momentumBlue : Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        type.replaceAll('-', ' '),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Subject
          TextField(
            controller: _contactSubjectController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Subject (optional)'),
          ),
          const SizedBox(height: 10),
          // Notes
          TextField(
            controller: _contactNotesController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            decoration: _inputDecoration('Notes / details'),
          ),
          const SizedBox(height: 10),
          // Outcome
          TextField(
            controller: _contactOutcomeController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Outcome (e.g., interested, no answer, scheduled meeting)'),
          ),
          const SizedBox(height: 10),
          // Follow-up date picker
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: BrandColors.sunriseGold,
                        surface: BrandColors.unityBlue,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() => _followUpDate = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white38, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _followUpDate != null
                        ? 'Follow-up: ${_formatDate(_followUpDate!)}'
                        : 'Set follow-up date (optional)',
                    style: TextStyle(
                      color: _followUpDate != null ? BrandColors.sunriseGold : Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                  if (_followUpDate != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _followUpDate = null),
                      child: const Icon(Icons.close, color: Colors.white38, size: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitContactLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.momentumBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Contact Log', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildContactTimeline() {
    return _card(
      'Contact Timeline (${_contactLog.length})',
      Icons.timeline,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (_contactLog.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No contacts logged yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                ),
              ),
            )
          else
            ..._contactLog.asMap().entries.map((entry) {
              final i = entry.key;
              final contact = entry.value;
              final isLast = i == _contactLog.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline line + dot
                    SizedBox(
                      width: 30,
                      child: Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: BrandColors.momentumBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 2),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(width: 2, color: Colors.white12),
                            ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(contact.typeIcon, color: BrandColors.momentumBlue, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  contact.contactType.replaceAll('-', ' ').toUpperCase(),
                                  style: const TextStyle(color: BrandColors.momentumBlue, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(contact.contactDate),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                            if (contact.subject != null && contact.subject!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(contact.subject!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                            if (contact.notes != null && contact.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(contact.notes!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                            if (contact.outcome != null && contact.outcome!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: BrandColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Outcome: ${contact.outcome}',
                                  style: const TextStyle(color: BrandColors.success, fontSize: 11),
                                ),
                              ),
                            ],
                            if (contact.followUpDate != null && contact.followUpDate!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.alarm, color: Colors.orange, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Follow-up: ${contact.followUpDate}',
                                    style: const TextStyle(color: Colors.orange, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                            if (contact.contactedBy != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'By: ${contact.contactedBy}',
                                style: const TextStyle(color: Colors.white30, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _card(
      'Internal Notes',
      Icons.note,
      BrandColors.sunriseGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              if (!_editingNotes)
                GestureDetector(
                  onTap: () => setState(() => _editingNotes = true),
                  child: const Text('Edit', style: TextStyle(color: BrandColors.sunriseGold, fontSize: 12, fontWeight: FontWeight.w500)),
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
                  decoration: _inputDecoration('Add notes about this candidate…'),
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
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _savingNotes ? null : _saveNotes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.sunriseGold,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _savingNotes
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
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
                c.notes?.isNotEmpty == true ? c.notes! : 'No notes yet — tap Edit to add internal notes.',
                style: TextStyle(
                  color: c.notes?.isNotEmpty == true ? Colors.white70 : Colors.white30,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoydMemberLink() {
    return _card(
      'MOYD Member Status',
      Icons.card_membership,
      BrandColors.momentumBlue,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Member status lookup not yet connected. If ${c.firstName} is a MOYD member, link their member profile here.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 6: DISTRICT INTEL
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDistrictTab() {
    if (_districtLoading) {
      return const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold));
    }

    if (c.district == null || c.district!.isEmpty) {
      return _buildEmptyState(
        Icons.map,
        'No District Data',
        'This candidate does not have a district assignment.\nDistrict intel is available for state-level races only.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── District Header ──
        _buildDistrictHeader(),
        const SizedBox(height: 16),

        // ── Candidates in This Race ──
        _buildRaceCandidates(),
        const SizedBox(height: 16),

        // ── Partisan Lean Estimate ──
        _buildPartisanLean(),
        const SizedBox(height: 16),

        // ── Voter Registration Stats ──
        if (_districtDemographics != null) ...[
          _buildVoterRegistration(),
          const SizedBox(height: 16),
          _buildDemographicProfile(),
          const SizedBox(height: 16),
        ],

        // ── Geographic Context ──
        _buildGeographicContext(),
        const SizedBox(height: 16),

        // ── Adjacent Districts ──
        if (_adjacentDistricts.isNotEmpty)
          _buildAdjacentDistricts(),
      ],
    );
  }

  Widget _buildDistrictHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandColors.sunriseGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.map, color: BrandColors.sunriseGold, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'District ${c.district}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      c.office,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    Text(
                      '${_districtCandidates.length} candidate${_districtCandidates.length == 1 ? '' : 's'} filed',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Race status indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _raceStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _raceStatusColor().withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(_raceStatusIcon(), color: _raceStatusColor(), size: 18),
                const SizedBox(width: 8),
                Text(
                  _raceStatusLabel(),
                  style: TextStyle(color: _raceStatusColor(), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _raceStatusColor() {
    final hasDem = _districtCandidates.any((c) => c.isDemocrat);
    final hasRep = _districtCandidates.any((c) => c.isRepublican);
    if (hasDem && hasRep) return Colors.amber;
    if (hasDem) return BrandColors.success;
    return BrandColors.republicanRed;
  }

  IconData _raceStatusIcon() {
    final hasDem = _districtCandidates.any((c) => c.isDemocrat);
    final hasRep = _districtCandidates.any((c) => c.isRepublican);
    if (hasDem && hasRep) return Icons.compare_arrows;
    return Icons.check_circle;
  }

  String _raceStatusLabel() {
    final hasDem = _districtCandidates.any((c) => c.isDemocrat);
    final hasRep = _districtCandidates.any((c) => c.isRepublican);
    if (hasDem && hasRep) return 'Contested Race — Dem vs Rep';
    if (hasDem) return 'Uncontested — Democrat Only';
    if (hasRep) return 'Uncontested — Republican Only';
    return 'No Major Party Candidates';
  }

  Widget _buildRaceCandidates() {
    final opponents = _districtCandidates.where((cand) => cand.id != c.id).toList();

    return _card(
      'Candidates in This Race (${_districtCandidates.length})',
      Icons.people,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Current candidate highlighted
          _buildDistrictCandidateRow(c, isCurrent: true),
          if (opponents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.white12)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Opponents', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: Colors.white12)),
                ],
              ),
            ),
            ...opponents.map((opp) => _buildDistrictCandidateRow(opp)),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No opponents filed', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildDistrictCandidateRow(Candidate cand, {bool isCurrent = false}) {
    Color partyColor;
    if (cand.isDemocrat) {
      partyColor = BrandColors.democratBlue;
    } else if (cand.isRepublican) {
      partyColor = BrandColors.republicanRed;
    } else {
      partyColor = Colors.amber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrent ? BrandColors.sunriseGold.withOpacity(0.08) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: isCurrent ? Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)) : null,
      ),
      child: InkWell(
        onTap: isCurrent ? null : () => _openCandidate(cand),
        child: Row(
          children: [
            // Party badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: partyColor.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: partyColor.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(cand.partyShort, style: TextStyle(color: partyColor, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        cand.name,
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Current', style: TextStyle(color: BrandColors.sunriseGold, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (cand.isYoungDem) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('YD', style: TextStyle(color: BrandColors.sunriseGold, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${cand.party}${cand.estimatedAge != null ? ' • Age ${cand.estimatedAge}' : ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isCurrent)
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  void _openCandidate(Candidate candidate) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(candidate: candidate),
      ),
    );
  }

  Widget _buildPartisanLean() {
    // Calculate from election history if available
    double partisanLean = 0;
    String leanLabel = 'Unknown';
    Color leanColor = Colors.grey;

    if (_electionResults.isNotEmpty) {
      double totalDemPct = 0;
      int count = 0;
      for (final r in _electionResults) {
        if (r.demPercent != null) {
          totalDemPct += r.demPercent!;
          count++;
        }
      }
      if (count > 0) {
        final avgDemPct = totalDemPct / count;
        partisanLean = avgDemPct - 50;
        if (partisanLean > 0) {
          leanLabel = 'D+${partisanLean.toStringAsFixed(1)}';
          leanColor = BrandColors.democratBlue;
        } else if (partisanLean < 0) {
          leanLabel = 'R+${(-partisanLean).toStringAsFixed(1)}';
          leanColor = BrandColors.republicanRed;
        } else {
          leanLabel = 'Even';
          leanColor = Colors.amber;
        }
      }
    }

    return _card(
      'Partisan Lean Estimate',
      Icons.balance,
      Colors.amber,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            leanLabel,
            style: TextStyle(color: leanColor, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_electionResults.isNotEmpty) ...[
            // Visual lean bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    Expanded(
                      flex: math.max(1, (50 + partisanLean).round()),
                      child: Container(color: BrandColors.democratBlue.withOpacity(0.7)),
                    ),
                    Expanded(
                      flex: math.max(1, (50 - partisanLean).round()),
                      child: Container(color: BrandColors.republicanRed.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('← Dem', style: TextStyle(color: BrandColors.democratBlue, fontSize: 10)),
                Text('Rep →', style: TextStyle(color: BrandColors.republicanRed, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Based on ${_electionResults.length} election cycle${_electionResults.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ] else
            const Text(
              'No historical data available to estimate partisan lean',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildVoterRegistration() {
    final demo = _districtDemographics!;

    return _card(
      'Voter Registration',
      Icons.how_to_reg,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (demo.registeredVoters != null) ...[
            Text(
              _formatNumber(demo.registeredVoters!),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text('Registered Voters', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            // Registration breakdown bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    if (demo.registeredDem != null && demo.registeredDem! > 0)
                      Expanded(
                        flex: demo.registeredDem!,
                        child: Container(
                          color: BrandColors.democratBlue,
                          alignment: Alignment.center,
                          child: Text(
                            '${demo.demRegistrationPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (demo.registeredRep != null && demo.registeredRep! > 0)
                      Expanded(
                        flex: demo.registeredRep!,
                        child: Container(
                          color: BrandColors.republicanRed,
                          alignment: Alignment.center,
                          child: Text(
                            '${demo.repRegistrationPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (demo.registeredOther != null && demo.registeredOther! > 0)
                      Expanded(
                        flex: demo.registeredOther!,
                        child: Container(
                          color: Colors.grey,
                          alignment: Alignment.center,
                          child: const Text(
                            'Other',
                            style: TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _regStatChip('Dem', _formatNumber(demo.registeredDem ?? 0), BrandColors.democratBlue),
                _regStatChip('Rep', _formatNumber(demo.registeredRep ?? 0), BrandColors.republicanRed),
                _regStatChip('Other', _formatNumber(demo.registeredOther ?? 0), Colors.grey),
              ],
            ),
          ] else
            const Text('Voter registration data not available', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _regStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildDemographicProfile() {
    final demo = _districtDemographics!;

    return _card(
      'Demographic Profile',
      Icons.analytics,
      Colors.purpleAccent,
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (demo.totalPopulation != null)
            _demoRow('Population', _formatNumber(demo.totalPopulation!)),
          if (demo.medianAge != null)
            _demoRow('Median Age', demo.medianAge!.toStringAsFixed(1)),
          if (demo.medianIncome != null)
            _demoRow('Median Income', '\$${_formatMoney(demo.medianIncome!)}'),
          if (demo.collegePercent != null)
            _demoRow('College Educated', '${demo.collegePercent!.toStringAsFixed(1)}%'),
          if (demo.diversityIndex != null)
            _demoRow('Diversity Index', demo.diversityIndex!.toStringAsFixed(2)),
          if (demo.urbanRural != null)
            _demoRow('Classification', demo.urbanRural!.substring(0, 1).toUpperCase() + demo.urbanRural!.substring(1)),
        ],
      ),
    );
  }

  Widget _demoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGeographicContext() {
    return _card(
      'Geographic Context',
      Icons.place,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, color: BrandColors.steelBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Missouri State House District ${c.district}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_districtDemographics?.urbanRural != null) ...[
                  _geoRow('Type', _districtDemographics!.urbanRural!.substring(0, 1).toUpperCase() + _districtDemographics!.urbanRural!.substring(1)),
                ],
                _geoRow('State', 'Missouri'),
                _geoRow('Chamber', c.office.contains('Senate') ? 'State Senate' : 'State House'),
                _geoRow('Term', '2-year term (House) / 4-year (Senate)'),
                _geoRow('Election', '2026 General Election'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _geoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildAdjacentDistricts() {
    return _card(
      'Adjacent Districts',
      Icons.grid_view,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._adjacentDistricts.entries.map((entry) {
            final dist = entry.key;
            final candidates = entry.value;
            final hasYd = candidates.any((c) => c.isYoungDem);
            final hasDem = candidates.any((c) => c.isDemocrat);
            final hasRep = candidates.any((c) => c.isRepublican);

            String statusLabel;
            Color statusColor;
            if (hasDem && hasRep) {
              statusLabel = 'Contested';
              statusColor = Colors.amber;
            } else if (hasDem) {
              statusLabel = 'Dem Only';
              statusColor = BrandColors.democratBlue;
            } else if (hasRep) {
              statusLabel = 'Rep Only';
              statusColor = BrandColors.republicanRed;
            } else {
              statusLabel = 'Other';
              statusColor = Colors.grey;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasYd ? BrandColors.sunriseGold.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasYd ? BrandColors.sunriseGold.withOpacity(0.4) : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        dist,
                        style: TextStyle(
                          color: hasYd ? BrandColors.sunriseGold : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidates.map((c) => c.name).join(', '),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${candidates.length} filed',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (hasYd) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star, color: BrandColors.sunriseGold, size: 14),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS FROM ORIGINAL
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 48, fontWeight: FontWeight.bold),
              ),
              Text(' / $maxScore', style: const TextStyle(color: Colors.white38, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_scoreColor(score)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _scoreLabel(score),
            style: TextStyle(color: _scoreColor(score), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
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
            child: Text(label, style: TextStyle(color: active ? Colors.white70 : Colors.white38, fontSize: 13)),
          ),
          Text(value, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

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
                _socialButton(Icons.language, 'Website', Colors.white70, () => _launchUrl(c.campaignWebsite!)),
              if (c.socialTwitter != null && c.socialTwitter!.isNotEmpty)
                _socialButton(Icons.alternate_email, 'Twitter/X', const Color(0xFF1DA1F2), () => _launchUrl(c.socialTwitter!)),
              if (c.socialInstagram != null && c.socialInstagram!.isNotEmpty)
                _socialButton(Icons.camera_alt, 'Instagram', const Color(0xFFE4405F), () => _launchUrl(c.socialInstagram!)),
              if (c.socialFacebook != null && c.socialFacebook!.isNotEmpty)
                _socialButton(Icons.facebook, 'Facebook', const Color(0xFF1877F2), () => _launchUrl(c.socialFacebook!)),
              if (c.socialLinkedin != null && c.socialLinkedin!.isNotEmpty)
                _socialButton(Icons.business, 'LinkedIn', const Color(0xFF0A66C2), () => _launchUrl(c.socialLinkedin!)),
              if (c.socialTiktok != null && c.socialTiktok!.isNotEmpty)
                _socialButton(Icons.music_note, 'TikTok', Colors.white70, () => _launchUrl(c.socialTiktok!)),
              if (c.ballotpediaUrl != null && c.ballotpediaUrl!.isNotEmpty)
                _socialButton(Icons.how_to_vote, 'Ballotpedia', const Color(0xFF009688), () => _launchUrl(c.ballotpediaUrl!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, Color color, VoidCallback onTap) {
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
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

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
            const Text('Bio', style: TextStyle(color: BrandColors.sunriseGold, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(c.bio!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                    ),
                    child: Text(issue, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildEndorsements() {
    final endorsements = c.endorsements!
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return _card(
      'Endorsements (from profile)',
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
                        const Icon(Icons.verified, color: BrandColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(Icons.phone, 'Contact', BrandColors.momentumBlue, _launchPhone),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(Icons.thumb_up, 'Endorse', BrandColors.success, _toggleMOYDEndorsed),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(Icons.note_add, 'Add Note', BrandColors.sunriseGold, () {
            _tabController.animateTo(4);
            setState(() => _editingNotes = true);
          }),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
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
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED UTILITIES
  // ═══════════════════════════════════════════════════════════════

  Widget _card(String title, IconData icon, Color accent, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
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
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(color == Colors.white54 || color == Colors.white30 ? 0.15 : 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.12), size: 64),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Formatting helpers ──
  String _formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(amount == amount.truncateToDouble() ? 0 : 2);
  }

  String _formatMoneyShort(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(0)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}K';
    }
    return number.toString();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB BAR DELEGATE — Pinned tab bar in NestedScrollView
// ═══════════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0b1e37),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
//  SCORE RADAR PAINTER — 5-axis radar/spider chart
// ═══════════════════════════════════════════════════════════════

class _ScoreRadarPainter extends CustomPainter {
  final Map<String, double> scores;
  final double maxValue;
  final Color accentColor;

  _ScoreRadarPainter({
    required this.scores,
    required this.maxValue,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final axes = scores.keys.toList();
    final n = axes.length;
    if (n == 0) return;

    final angleStep = 2 * math.pi / n;
    final startAngle = -math.pi / 2; // Top

    // Draw grid circles
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      canvas.drawCircle(center, r, gridPaint);
    }

    // Draw axis lines
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;

    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, end, axisPaint);
    }

    // Draw data polygon
    final dataPath = Path();
    final fillPaint = Paint()
      ..color = accentColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < n; i++) {
      final value = scores[axes[i]] ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final angle = startAngle + angleStep * i;
      final point = Offset(
        center.dx + radius * normalizedValue * math.cos(angle),
        center.dy + radius * normalizedValue * math.sin(angle),
      );

      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Draw data points
    final dotPaint = Paint()..color = accentColor;
    for (int i = 0; i < n; i++) {
      final value = scores[axes[i]] ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final angle = startAngle + angleStep * i;
      final point = Offset(
        center.dx + radius * normalizedValue * math.cos(angle),
        center.dy + radius * normalizedValue * math.sin(angle),
      );
      canvas.drawCircle(point, 4, dotPaint);
    }

    // Draw labels
    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final labelOffset = Offset(
        center.dx + (radius + 16) * math.cos(angle),
        center.dy + (radius + 16) * math.sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: axes[i],
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          labelOffset.dx - textPainter.width / 2,
          labelOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════
//  MARGIN TREND PAINTER — Win margin line chart
// ═══════════════════════════════════════════════════════════════

class _MarginTrendPainter extends CustomPainter {
  final List<ElectionResult> results;

  _MarginTrendPainter({required this.results});

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    final n = results.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width / 2;
    final midY = size.height / 2;

    // Draw center line (50-50)
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centerPaint);

    // Draw margin line
    final linePaint = Paint()
      ..color = BrandColors.sunriseGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [BrandColors.sunriseGold.withOpacity(0.3), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < n; i++) {
      final r = results[i];
      final demPct = r.demPercent ?? 50;
      final margin = demPct - 50; // Positive = Dem win, Negative = Rep win
      final x = n > 1 ? stepX * i : size.width / 2;
      final y = midY - (margin / 50) * midY; // Scale margin to chart height

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, midY);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw dot
      final dotColor = margin >= 0 ? BrandColors.democratBlue : BrandColors.republicanRed;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = dotColor);

      // Year label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${r.year}',
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 12));
    }

    // Close fill path
    if (n > 1) {
      fillPath.lineTo(stepX * (n - 1), midY);
    } else {
      fillPath.lineTo(size.width / 2, midY);
    }
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}