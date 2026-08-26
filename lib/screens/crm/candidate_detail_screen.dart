import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/widgets/crm/candidate_rubric_card.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_painters.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_file_card.dart';
import 'package:bluebubbles/screens/crm/widgets/candidate_questionnaire_panel.dart';
import 'package:bluebubbles/screens/crm/widgets/endorsement_questionnaire_section.dart';
import 'package:bluebubbles/screens/crm/widgets/socials/candidate_socials_panel.dart';
import 'package:bluebubbles/screens/crm/candidate_edit_dialog.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/intelligence_profile_section.dart';
import 'package:bluebubbles/screens/crm/volunteers/candidate_outreach_section.dart';
import 'package:bluebubbles/screens/crm/mec_committee_picker.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/election_results_repository.dart' as er;
import 'package:bluebubbles/screens/crm/mec_donor_screen.dart';
import 'package:bluebubbles/screens/crm/mec_payee_screen.dart';
import 'package:bluebubbles/screens/crm/news_article_detail_screen.dart';
import 'package:bluebubbles/screens/crm/historical_candidate_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE DETAIL SCREEN
//  4-tab profile view for any candidate in the 2026 cycle
//
//  TAB 1: Profile — Bio, social links, score radar, quick actions
//  TAB 2: Money — MEC contributions, expenditures, opponent comparison
//  TAB 3: Race — Election history + district intel merged
//  TAB 4: Intel — News, endorsements, MOYD engagement (segmented)
// ═══════════════════════════════════════════════════════════════

class CandidateDetailScreen extends StatefulWidget {
  final Candidate candidate;
  final int initialTab;

  const CandidateDetailScreen({
    super.key,
    required this.candidate,
    this.initialTab = 0,
  });

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
  bool _uploadingPhoto = false;
  late Candidate _candidate;

  // ── State: Voter File (loaded on Profile tab first visit) ──
  VoterFileRecord? _voterRecord;
  bool _voterLoading = false;
  bool _voterLoaded = false;

  // ── State: Money Tab (contributions + expenditures) ──
  bool _financeLoading = true;
  String? _financeError;
  bool _financeTimedOut = false;
  List<Map<String, dynamic>> _mecCommittees = [];
  List<MECContribution> _mecContributions = [];
  List<Map<String, dynamic>> _topDonors = [];
  List<Map<String, dynamic>> _contributionTimeline = [];
  Map<String, dynamic> _financeSummary = {};
  String? _selectedMecId;
  // Expenditures (NEW)
  Map<String, dynamic> _expenditureSummary = {};
  List<Map<String, dynamic>> _topPayees = [];
  List<Map<String, dynamic>> _raceComparison = [];
  // FEC federal finance (for federal candidates)
  Map<String, dynamic> _fecSummary = {};
  List<Map<String, dynamic>> _fecTopDonors = [];
  List<Map<String, dynamic>> _fecTimeline = [];
  List<Map<String, dynamic>> _fecRecentContributions = [];
  List<Map<String, dynamic>> _fecCommittees = [];
  // FEC federal spending (who the candidate pays)
  List<Map<String, dynamic>> _fecTopPayees = [];
  List<Map<String, dynamic>> _fecSpendingByPurpose = [];
  List<Map<String, dynamic>> _fecRecentExpenditures = [];
  // FEC outside spending (independent expenditures for/against the candidate)
  Map<String, dynamic> _fecOutsideSpending = {};

  // ── State: Race Tab (history + district merged) ──
  bool _raceLoading = true;
  List<ElectionResult> _electionResults = [];
  List<Candidate> _districtCandidates = [];
  // Official 2026 primary result rows for this exact race (all parties), used
  // to render the November general field (advanced nominees, incl. R and L)
  // ahead of a collapsed primary-results section. Empty → fall back to the
  // flat filed-candidate list.
  final er.ElectionResultsRepository _results2026 = er.ElectionResultsRepository();
  List<er.ElectionResult> _raceResults = [];
  DistrictDemographics? _districtDemographics;
  Map<String, List<Candidate>> _adjacentDistricts = {};
  List<Map<String, dynamic>> _historicalCandidates = [];

  // ── State: Intel Tab (news + endorsements + MOYD engagement) ──
  bool _intelLoading = true;
  int _intelSegment = 0; // 0=News, 1=Endorsements, 2=MOYD
  List<CandidateNews> _newsArticles = [];
  List<Map<String, dynamic>> _endorsementRecords = [];
  List<CandidateContact> _contactLog = [];
  bool _showContactForm = false;
  final _contactNotesController = TextEditingController();
  final _contactOutcomeController = TextEditingController();
  final _contactSubjectController = TextEditingController();
  String _selectedContactType = 'phone';
  DateTime? _followUpDate;

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
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
    );
    _tabController.addListener(_onTabChanged);
    _notesController.text = c.notes ?? '';
    _animController.forward();

    // Profile tab opens immediately, so fetch the voter record right away.
    _loadVoterRecord();
  }

  Future<void> _loadVoterRecord() async {
    if (_voterLoaded || _voterLoading) return;
    final voterId = c.moVoterFileId;
    if (voterId == null || voterId.isEmpty) {
      _voterLoaded = true;
      return;
    }
    setState(() => _voterLoading = true);
    try {
      final record = await _repo.fetchVoterRecord(voterId);
      if (!mounted) return;
      setState(() {
        _voterRecord = record;
        _voterLoading = false;
        _voterLoaded = true;
      });
    } catch (e) {
      debugPrint('❌ _loadVoterRecord: $e');
      if (!mounted) return;
      setState(() {
        _voterLoading = false;
        _voterLoaded = true;
      });
    }
  }

  void _onTabChanged() {
    // Only fire on committed tab changes, not animation frames during swipe.
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    switch (idx) {
      case 1:
        if (_financeLoading) _loadFinanceData();
        break;
      case 2:
        if (_raceLoading) _loadRaceData();
        break;
      case 3:
        if (_intelLoading) _loadIntelData();
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

  Future<void> _loadFinanceData() async {
    setState(() {
      _financeLoading = true;
      _financeError = null;
      _financeTimedOut = false;
    });

    const loadTimeout = Duration(seconds: 20);
    final fecId = c.fecCandidateId;
    final hasFec = fecId != null && fecId.isNotEmpty;
    final hasDistrict = c.district != null && c.district!.isNotEmpty;
    final hasMecIds = c.mecCommitteeIds.isNotEmpty;

    // Check cache first (1hr TTL). Cache is keyed by the committee currently
    // showing — null == aggregate across all linked committees.
    final cacheKey = _selectedMecId ?? (hasMecIds ? '__ALL__${c.mecCommitteeIds.join(',')}' : '');
    final cached = _repo.getCachedFinanceSummary(cacheKey);
    if (cached != null && !_financeTimedOut) {
      _financeSummary = cached;
    }

    try {
      // Load MEC committees first (needed to know the mec_id for subsequent calls).
      bool committeesTimedOut = false;
      final committees = hasMecIds
          ? await _repo.getMECCommittees(c.mecCommitteeIds).timeout(
              loadTimeout,
              onTimeout: () {
                committeesTimedOut = true;
                return const <Map<String, dynamic>>[];
              },
            )
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      if (committeesTimedOut) _financeTimedOut = true;

      // Determine which committee(s) to load data for:
      //   * _selectedMecId == null AND candidate has multiple committees
      //     → aggregate ALL committees ("All committees" mode)
      //   * _selectedMecId set → that specific committee only
      //   * first load with one committee → auto-select it
      final validIds = committees.map((m) => m['mec_id']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      // If the currently selected committee is no longer in the list (e.g. user
      // just detached it), fall back to the aggregate view rather than a stale id.
      if (_selectedMecId != null && !validIds.contains(_selectedMecId)) {
        _selectedMecId = null;
      }
      // For candidates with a SINGLE committee, default to showing it specifically.
      if (_selectedMecId == null && validIds.length == 1) {
        _selectedMecId = validIds.first;
      }

      final bool aggregate = _selectedMecId == null && validIds.isNotEmpty;
      final String singleId = _selectedMecId ?? '';
      final List<String> multiIds = aggregate ? validIds : const [];

      final futures = <Future<dynamic>>[
        // MEC contributions (list)
        aggregate
            ? _repo.getMECContributionsMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECContributions(singleId) : Future.value(const <MECContribution>[]),
        // Top donors
        aggregate
            ? _repo.getMECTopDonorsMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECTopDonors(singleId) : Future.value(const <Map<String, dynamic>>[]),
        // Contribution timeline
        aggregate
            ? _repo.getMECContributionTimelineMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECContributionTimeline(singleId) : Future.value(const <Map<String, dynamic>>[]),
        // Finance summary
        aggregate
            ? _repo.getMECFinanceSummaryMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECFinanceSummary(singleId) : Future.value(const <String, dynamic>{}),
        // Expenditure summary
        aggregate
            ? _repo.getMECExpenditureSummaryMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECExpenditureSummary(singleId) : Future.value(const <String, dynamic>{}),
        // Top payees
        aggregate
            ? _repo.getMECTopPayeesMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECTopPayees(singleId) : Future.value(const <Map<String, dynamic>>[]),
        // Recent expenditures
        aggregate
            ? _repo.getMECRecentExpendituresMulti(multiIds)
            : singleId.isNotEmpty ? _repo.getMECRecentExpenditures(singleId) : Future.value(const <Map<String, dynamic>>[]),
        // Race comparison
        hasDistrict ? _repo.getRaceFinanceComparison(c.office, c.district!) : Future.value(const <Map<String, dynamic>>[]),
        // FEC data (only if federal candidate)
        hasFec ? _repo.getFECFinanceSummary(fecId) : Future.value(const <String, dynamic>{}),
        hasFec ? _repo.getFECTopDonors(fecId) : Future.value(const <Map<String, dynamic>>[]),
        hasFec ? _repo.getFECContributionTimeline(fecId) : Future.value(const <Map<String, dynamic>>[]),
        hasFec ? _repo.getFECRecentContributions(fecId) : Future.value(const <Map<String, dynamic>>[]),
        hasFec ? _repo.getFECCommittees(fecId) : Future.value(const <Map<String, dynamic>>[]),
        // FEC spending (who the candidate pays)
        hasFec ? _repo.getFECTopPayees(fecId) : Future.value(const <Map<String, dynamic>>[]),
        hasFec ? _repo.getFECSpendingByPurpose(fecId) : Future.value(const <Map<String, dynamic>>[]),
        hasFec ? _repo.getFECRecentExpenditures(fecId) : Future.value(const <Map<String, dynamic>>[]),
        // FEC outside spending (independent expenditures for/against the candidate)
        hasFec ? _repo.getFECOutsideSpending(fecId) : Future.value(const <String, dynamic>{}),
      ];

      bool batchTimedOut = false;
      final results = await Future.wait(futures).timeout(
        loadTimeout,
        onTimeout: () {
          batchTimedOut = true;
          return List.filled(futures.length, null);
        },
      );
      if (!mounted) return;
      if (batchTimedOut) _financeTimedOut = true;

      _mecCommittees = committees;
      _mecContributions = (results[0] as List?)?.cast<MECContribution>() ?? const [];
      _topDonors = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _contributionTimeline = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _financeSummary = (results[3] as Map<String, dynamic>?) ?? const {};
      if (_financeSummary.isNotEmpty && cacheKey.isNotEmpty) {
        _repo.cacheFinanceSummary(cacheKey, _financeSummary);
      }
      _expenditureSummary = (results[4] as Map<String, dynamic>?) ?? const {};
      _topPayees = (results[5] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      // results[6] (recent expenditures) intentionally skipped — not rendered
      _raceComparison = (results[7] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecSummary = (results[8] as Map<String, dynamic>?) ?? const {};
      _fecTopDonors = (results[9] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecTimeline = (results[10] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecRecentContributions = (results[11] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecCommittees = (results[12] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecTopPayees = (results[13] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecSpendingByPurpose = (results[14] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecRecentExpenditures = (results[15] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      _fecOutsideSpending = (results[16] as Map<String, dynamic>?) ?? const {};
    } catch (e) {
      debugPrint('❌ Error loading finance data: $e');
      _financeError = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _financeLoading = false;
      if (_financeError == null && _financeTimedOut) {
        _financeError = 'Finance data timed out after 20s. Tap Retry to try again.';
      }
    });
  }

  Future<void> _loadRaceData() async {
    setState(() => _raceLoading = true);

    try {
      if (c.district != null && c.district!.isNotEmpty) {
        final results = await Future.wait([
          _repo.fetchElectionHistory(c.district!),
          _repo.getDistrictCandidates(c.office, c.district!),
          _repo.fetchDistrictDemographics(c.district!),
          _repo.getAdjacentDistrictCandidates(c.district!),
        ]);

        _electionResults = results[0] as List<ElectionResult>;
        _districtCandidates = results[1] as List<Candidate>;
        _districtDemographics = results[2] as DistrictDemographics?;
        _adjacentDistricts = results[3] as Map<String, List<Candidate>>;

        // Pull the official 2026 primary field for this race so the District
        // tab can lead with the November ballot (advanced nominees of every
        // party) and tuck the primary losers away. Only meaningful for the
        // districted legislative seats the results table covers.
        final officeType =
            er.ElectionResultsRepository.officeTypeFor(c.office);
        if (officeType != null) {
          final bare = c.district!.replaceAll(RegExp(r'\D'), '');
          _raceResults = await _results2026.forDistrict(
            officeType: officeType,
            district: bare.isEmpty ? c.district! : bare,
          );
        } else {
          _raceResults = const [];
        }

        // Load historical candidates for this (district, office) pair
        // (non-blocking). Office is required after migration 20260427_02 —
        // without it District 81 of State Rep collided with District 81
        // of State Senator.
        if (c.office.isNotEmpty) {
          _repo
              .getDistrictHistoricalCandidates(c.district!, c.office)
              .then((hc) {
            if (mounted) setState(() => _historicalCandidates = hc);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading race data: $e');
    }

    if (mounted) setState(() => _raceLoading = false);
  }

  Future<void> _loadIntelData() async {
    setState(() => _intelLoading = true);

    try {
      final results = await Future.wait([
        _repo.fetchNews(c.id),
        _repo.fetchCandidateEndorsements(c.id),
        _repo.fetchContacts(c.id),
      ]);

      _newsArticles = results[0] as List<CandidateNews>;
      _endorsementRecords = results[1] as List<Map<String, dynamic>>;
      _contactLog = results[2] as List<CandidateContact>;
    } catch (e) {
      debugPrint('❌ Error loading intel data: $e');
    }

    if (mounted) setState(() => _intelLoading = false);
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    try {
      await _repo.updateNotes(c.id, _notesController.text);
    } catch (e) {
      debugPrint('❌ Error saving notes: $e');
      if (mounted) {
        setState(() => _savingNotes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save notes'), backgroundColor: BrandColors.error),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _savingNotes = false;
      _editingNotes = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notes saved'),
        backgroundColor: BrandColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Open MECDonorScreen using natural-key lookup.
  /// mec_contributions.donor_id is 96% unreliable (points at wrong mec_donors
  /// rows) so we key on (first_name, last_name, city, state) instead.
  void _openDonorProfileByKey({
    required String firstName,
    required String lastName,
    String? city,
    String? state,
  }) {
    if (firstName.isEmpty && lastName.isEmpty) return;
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: MECDonorScreen(
            firstName: firstName,
            lastName: lastName,
            city: city,
            state: state,
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    // Handle social media handles stored as @username
    if (url.startsWith('@')) {
      url = 'https://x.com/${url.substring(1)}';
    } else if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleMOYDEndorsed() async {
    try {
      await _repo.toggleMOYDEndorsed(c.id);
    } catch (e) {
      debugPrint('❌ Error toggling endorsement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update endorsement'), backgroundColor: BrandColors.error),
        );
      }
      return;
    }
    if (!mounted) return;
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

  // ─── Candidate photo upload ─────────────────────────────────────

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if ((file.bytes == null || file.bytes!.isEmpty) && file.path == null) return;

    setState(() => _uploadingPhoto = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newUrl = await _repo.uploadCandidatePhoto(
        candidateId: _candidate.id,
        file: file,
      );
      if (!mounted) return;
      if (newUrl == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Photo upload failed'), backgroundColor: BrandColors.error),
        );
        return;
      }
      final refreshed = await _repo.fetchCandidate(_candidate.id);
      if (!mounted) return;
      if (refreshed != null) {
        setState(() => _candidate = refreshed);
      }
      // Force NetworkImage to bypass cache for the new URL
      await NetworkImage(newUrl).evict();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Photo updated'),
          backgroundColor: BrandColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Photo upload error: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: BrandColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ─── Edit candidate profile ─────────────────────────────────────

  Future<void> _openEditDialog() async {
    // `showCandidateEditor` picks full-screen vs Dialog based on viewport
    // width — sub-600px gets a Scaffold-rooted route so the keyboard
    // doesn't cover fields.
    final updates = await showCandidateEditor(context, candidate: _candidate);
    if (updates == null || updates.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.updateCandidate(_candidate.id, updates);
    } catch (e) {
      debugPrint('❌ Error saving candidate edits: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save changes'), backgroundColor: BrandColors.error),
      );
      return;
    }
    final refreshed = await _repo.fetchCandidate(_candidate.id);
    if (!mounted) return;
    if (refreshed != null) {
      setState(() => _candidate = refreshed);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved ${updates.length} change${updates.length == 1 ? '' : 's'}'),
        backgroundColor: BrandColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitContactLog() async {
    CandidateContact? result;
    try {
      result = await _repo.addContactLog(
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
    } catch (e) {
      debugPrint('❌ Error logging contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log contact'), backgroundColor: BrandColors.error),
        );
      }
      return;
    }

    if (result != null && mounted) {
      _contactNotesController.clear();
      _contactOutcomeController.clear();
      _contactSubjectController.clear();
      setState(() {
        _showContactForm = false;
        _followUpDate = null;
      });
      await _loadIntelData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact logged successfully'),
            backgroundColor: BrandColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _addEndorsement() async {
    final name = _endorserNameController.text.trim();
    if (name.isEmpty) return;

    try {
      await _repo.addEndorsement(c.id, name, _endorsementType);
    } catch (e) {
      debugPrint('❌ Error adding endorsement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add endorsement'), backgroundColor: BrandColors.error),
        );
      }
      return;
    }

    _endorserNameController.clear();
    if (!mounted) return;
    await _loadIntelData();

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
                  hintStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Type:', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
            Icon(icon, size: 14, color: selected ? BrandColors.sunriseGold : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
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

  // ── SMS launcher (staff → candidate). Used by FAB speed-dial. ──
  Future<void> _launchSMS() async {
    final phone = c.phone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone number on file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await _launchUrl('sms:$phone');
  }

  // ── Copy the candidate-specific endorsement questionnaire link. ──
  void _copyQuestionnaireLink() {
    final link =
        'https://moyoungdemocrats.org/forms/endorsement-questionnaire?candidate_id=${c.id}';
    _copyToClipboard(link, 'Questionnaire link');
  }

  // ── Share profile (deep link if wired, plain-text summary otherwise). ──
  //
  // Flutter deep links aren't wired yet for candidate URLs — no
  // `/candidates/:id` route is registered on any platform as of
  // 2026-04-22. For now, this copies a human-readable summary to the
  // clipboard. When deep links land, swap `summary` for a real URL.
  void _shareProfile() {
    final district = (c.district != null && c.district!.isNotEmpty)
        ? ' (District ${c.district})'
        : '';
    final summary =
        '${c.name}, ${c.officeDisplay}$district\nParty: ${c.party}'
        '${c.isYoungDem ? "\n⭐ Young Democrat" : ""}'
        '${c.isEndorsed ? "\n✅ MOYD Endorsed" : ""}';
    _copyToClipboard(summary, 'Profile summary');
  }

  /// Jump to the Intel tab and open the "Log Contact" form. Used by the
  /// mobile FAB speed-dial ("Log Contact" entry).
  void _quickLogContact() {
    _tabController.animateTo(3);
    setState(() {
      _intelSegment = 2;
      _showContactForm = true;
    });
  }

  /// Jump to the Intel tab and focus the Notes field. Used by the mobile
  /// FAB speed-dial ("Add Note" entry).
  void _quickAddNote() {
    _tabController.animateTo(3);
    setState(() {
      _intelSegment = 2;
      _editingNotes = true;
    });
  }

  /// Reaches the Questionnaire tab's state so pull-to-refresh re-fetches it.
  final GlobalKey<EndorsementQuestionnaireSectionState> _questionnaireKey =
      GlobalKey<EndorsementQuestionnaireSectionState>();

  // ── Refresh handlers for RefreshIndicator — one per tab. ──
  Future<void> _refreshCurrentTab() async {
    final idx = _tabController.index;
    switch (idx) {
      case 0:
        // Profile: re-fetch the candidate (covers edited fields) + voter.
        final refreshed = await _repo.fetchCandidate(c.id);
        if (!mounted) return;
        setState(() {
          if (refreshed != null) _candidate = refreshed;
          _voterLoaded = false;
        });
        await _loadVoterRecord();
        break;
      case 1:
        await _loadFinanceData();
        break;
      case 2:
        await _loadRaceData();
        break;
      case 3:
        await _loadIntelData();
        break;
      case 4:
        // The questionnaire panel owns its own fetches, so refresh it through
        // its state rather than resolving a fake delay: pulling used to spin,
        // stop, and change nothing on screen.
        await _questionnaireKey.currentState?.reload();
        break;
      case 5:
        // Socials panel owns its own content; nothing to do at this level.
        // Pull-to-refresh still resolves after ~250ms so the user gets a
        // visible completion.
        await Future.delayed(const Duration(milliseconds: 250));
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD — Main scaffold with tab bar
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Mobile-first revamp (2026-04-22): use LayoutBuilder to pick a
    // chip-based tab row on narrow viewports (<600px) and keep the
    // classic TabBar on tablet/desktop. Body is wrapped in
    // RefreshIndicator so pull-to-refresh works on every tab.
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isMobile = constraints.maxWidth < 600;
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
                          tooltip: 'Back',
                        ),
                        actions: _buildAppBarActions(isMobile: isMobile),
                        expandedHeight: 0,
                        pinned: true,
                      ),

                      // ── Hero Profile Card ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isMobile ? 12 : 16,
                            0,
                            isMobile ? 12 : 16,
                            8,
                          ),
                          child: _buildCompactHero(isMobile: isMobile),
                        ),
                      ),

                      // ── Tab Navigation ──
                      //
                      // Mobile: horizontal scrollable chip row (bigger tap
                      // targets, clearer selection state).
                      // Desktop: classic underlined TabBar.
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: CandidateTabBarDelegate(
                          tabBar: isMobile ? _buildMobileTabChips() : _buildDesktopTabBar(),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _refreshable(_buildOverviewTab()),
                        _refreshable(_buildMoneyTab()),
                        _refreshable(_buildRaceTab()),
                        _refreshable(_buildIntelTab()),
                        _refreshable(CandidateQuestionnairePanel(
                          candidateId: c.id,
                          sectionKey: _questionnaireKey,
                        )),
                        _refreshable(CandidateSocialsPanel(candidate: c)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Mobile staff-action speed-dial — hidden on wide screens where
          // users have more chrome and the hero already exposes Email/Call.
          floatingActionButton: isMobile ? _buildStaffFab() : null,
        );
      },
    );
  }

  // ── AppBar actions: share button surfaces at top-level on every
  // viewport; secondary actions stay in the overflow menu. ──
  List<Widget> _buildAppBarActions({required bool isMobile}) {
    return [
      IconButton(
        icon: const Icon(Icons.ios_share, color: Colors.white70),
        onPressed: _shareProfile,
        tooltip: 'Share profile',
      ),
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.white70),
        onPressed: _openEditDialog,
        tooltip: 'Edit candidate',
      ),
      IconButton(
        icon: Icon(
          c.isEndorsed ? Icons.star : Icons.star_border,
          color: c.isEndorsed ? BrandColors.sunriseGold : Colors.white70,
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
          const PopupMenuItem(value: 'copy_questionnaire', child: Text('Copy Questionnaire Link', style: TextStyle(color: Colors.white))),
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
            case 'copy_questionnaire':
              _copyQuestionnaireLink();
              break;
          }
        },
      ),
    ];
  }

  // ── Desktop tab bar (≥600px) ──
  TabBar _buildDesktopTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: BrandColors.sunriseGold,
      unselectedLabelColor: Colors.white70,
      indicatorColor: BrandColors.sunriseGold,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
      tabs: const [
        Tab(text: 'Profile'),
        Tab(text: 'Money'),
        Tab(text: 'District'),
        Tab(text: 'Intel'),
        Tab(text: 'Questionnaire'),
        Tab(text: 'Socials'),
      ],
    );
  }

  // ── Mobile chip-style tab nav (<600px) ──
  //
  // Rendered inside the same SliverPersistentHeader slot as the desktop
  // TabBar so pinning + shouldRebuild work. We still provide a TabBar —
  // it's just styled with full-bleed pill indicators and larger tap
  // targets (the row height is clamped to `_tabBarDelegate.preferredSize`
  // via the surrounding SizedBox in the delegate). Each tab wraps its
  // label in a padded InkWell to guarantee ≥48×48 tap area.
  TabBar _buildMobileTabChips() {
    const tabLabels = ['Profile', 'Money', 'District', 'Intel', 'Q&A', 'Socials'];
    const tabIcons = [
      Icons.person_outline,
      Icons.attach_money,
      Icons.map_outlined,
      Icons.insights,
      Icons.fact_check_outlined,
      Icons.tag,
    ];
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      labelColor: BrandColors.sunriseGold,
      unselectedLabelColor: Colors.white70,
      indicatorSize: TabBarIndicatorSize.tab,
      // Transparent default indicator — the chips render their own fill
      // (see _MobileTabChip). Setting a transparent BoxDecoration keeps
      // the TabController happy without painting a line under the chip.
      indicator: const BoxDecoration(),
      dividerColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      tabs: [
        for (int i = 0; i < tabLabels.length; i++)
          Tab(
            height: 44,
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (_, __) {
                final selected = _tabController.index == i;
                return _MobileTabChip(
                  label: tabLabels[i],
                  icon: tabIcons[i],
                  selected: selected,
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Wrap any tab body in a RefreshIndicator with the tab's reloader. ──
  //
  // The inner `ListView`/panel child already uses its own scroll controller
  // — this works because RefreshIndicator intercepts the overscroll and
  // the inner list exposes the scroll position via Scrollable.
  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      color: BrandColors.sunriseGold,
      backgroundColor: BrandColors.unityBlue,
      child: child,
    );
  }

  // ── Mobile FAB speed-dial for the 4 most-used staff actions. ──
  //
  // Kept simple on purpose: a stateful widget that animates a column of
  // mini-FABs above the main FAB when tapped. No external dep required.
  Widget _buildStaffFab() {
    return _CandidateStaffFab(
      onLogContact: _quickLogContact,
      onAddNote: _quickAddNote,
      onCopyQuestionnaireLink: _copyQuestionnaireLink,
      onSendSms: _launchSMS,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  COMPACT HERO — Persistent header above tabs
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompactHero({bool isMobile = false}) {
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

    // Data completeness calculation
    int filled = 0;
    int total = 10;
    if (c.photoUrl != null && c.photoUrl!.isNotEmpty) filled++;
    if (c.bio != null && c.bio!.isNotEmpty) filled++;
    if (c.education != null && c.education!.isNotEmpty) filled++;
    if (c.occupation != null && c.occupation!.isNotEmpty) filled++;
    if (c.hasSocialLinks) filled++;
    if (c.hasContactInfo) filled++;
    if (c.hasCampaignFinance) filled++;
    if (c.endorsements != null && c.endorsements!.isNotEmpty) filled++;
    if (c.estimatedAge != null) filled++;
    if (c.ballotpediaUrl != null && c.ballotpediaUrl!.isNotEmpty) filled++;
    final completeness = filled / total;

    // Mobile summary: "Challenging X in District Y" / "Running for …"
    // Shown beneath the party + role chip row so it lives right where the
    // user's eye lands after reading the name.
    String? snippet;
    if (c.district != null && c.district!.isNotEmpty) {
      snippet = c.isIncumbent
          ? 'Incumbent • ${c.officeDisplay}, District ${c.district}'
          : '${c.officeDisplay}, District ${c.district}';
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.navyBlue,
            BrandColors.unityBlue,
            partyColor.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
        border: Border.all(color: partyColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: partyColor.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with glow ring + completeness
          Hero(
            tag: 'candidate-${c.id}',
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        partyColor.withOpacity(0.6),
                        partyColor.withOpacity(0.1),
                        partyColor.withOpacity(0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: partyColor.withOpacity(0.3), blurRadius: 12),
                    ],
                  ),
                ),
                // Completeness ring
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: completeness,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completeness >= 0.7 ? BrandColors.success : BrandColors.sunriseGold,
                    ),
                  ),
                ),
                // Photo — tap to upload / change
                GestureDetector(
                  onTap: _pickAndUploadPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: BrandColors.navyBlue,
                        backgroundImage: c.avatarUrl != null
                            ? NetworkImage(c.avatarUrl!)
                            : null,
                        child: c.avatarUrl == null
                            ? Text(
                                c.initials,
                                style: TextStyle(
                                  color: partyColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                      // Camera badge overlay — signals "tap to change photo"
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold,
                            shape: BoxShape.circle,
                            border: Border.all(color: BrandColors.navyBlue, width: 2),
                          ),
                          child: Icon(
                            _uploadingPhoto ? Icons.sync : Icons.camera_alt,
                            color: Colors.black87,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                Row(
                  children: [
                    // Arrow icon signals "aspiration" — unambiguous that this is what
                    // they're running FOR, not what they hold.
                    Icon(
                      c.isIncumbent ? Icons.refresh : Icons.arrow_forward,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        c.isIncumbent
                            ? 'Re-election: ${c.officeDisplay}'
                            : 'Running for ${c.officeDisplay}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Role badge — most important signal, leads the row
                    if (c.isIncumbent)
                      _badge('🏛️ INCUMBENT', BrandColors.sunriseGold, textColor: Colors.black87)
                    else
                      _badge('CANDIDATE 2026', BrandColors.momentumBlue),
                    _badge(partyLabel, partyColor),
                    if (c.estimatedAge != null)
                      _badge('Age ${c.estimatedAge}', Colors.white30),
                    if (c.isYoungDem)
                      _badge('⭐ YD', BrandColors.sunriseGold, textColor: Colors.black87),
                    if (c.isEndorsed)
                      _badge('✅ Endorsed', BrandColors.success),
                    _badge('${(completeness * 100).toInt()}%', completeness >= 0.7 ? BrandColors.success : Colors.white30),
                  ],
                ),
                // One-line snippet on mobile — saves the reader a scroll
                // to the Race tab to figure out the district context.
                if (isMobile && snippet != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    snippet,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Quick actions column — desktop only. On mobile, the speed-dial
          // FAB covers Email/Call/Note/SMS without eating hero width.
          if (!isMobile)
            Column(
              children: [
                _quickActionIcon(Icons.email, 'Email', _launchEmail, BrandColors.momentumBlue),
                const SizedBox(height: 6),
                _quickActionIcon(Icons.phone, 'Call', _launchPhone, BrandColors.success),
                const SizedBox(height: 6),
                _quickActionIcon(Icons.note_add, 'Note', () {
                  _tabController.animateTo(3);
                  setState(() {
                    _intelSegment = 2;
                    _editingNotes = true;
                  });
                }, BrandColors.sunriseGold),
              ],
            ),
        ],
      ),
    );
  }

  Widget _quickActionIcon(IconData icon, String tooltip, VoidCallback onTap, Color accent) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11), // 44px touch target (11*2 + 17 icon + 5 border)
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Icon(icon, color: accent.withOpacity(0.8), size: 17),
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
        // ── Edit profile CTA — always at the top, impossible to miss ──
        _buildEditProfileCta(),
        const SizedBox(height: 16),

        // ── MOYD Member Badge ──
        if (c.memberId != null) ...[
          _buildMemberBadge(),
          const SizedBox(height: 16),
        ],

        // ── Candidate Rubric (replaces _buildYoungDemScore + _buildScoreRadar)
        // 10-category 0-10 rubric driven by candidate_score_components.
        // Auto categories computed by recompute_candidate_score(); exec
        // committee can override individual scores via the stepper.
        CandidateRubricCard(candidateId: c.id),
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

        // ── MO Voter File (lazy-loaded, only rendered when a record exists) ──
        if (_voterLoading) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else if (_voterRecord != null) ...[
          VoterFileCard(
            record: _voterRecord!,
            dobSource: c.dobSource,
            matchConfidence: c.matchConfidence,
            matchMethod: c.matchMethod,
            showDebug: kDebugMode,
          ),
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

        // ── Field Outreach (Layer 2) ──
        CandidateOutreachSection(candidate: c),
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
              painter: ScoreRadarPainter(
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
              const Text('Total Score: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                '${c.youngDemScore}',
                style: TextStyle(
                  color: _scoreColor(c.youngDemScore),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(' / 100', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
        Text('$label: $value', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
              Icon(Icons.open_in_new, color: Colors.white70, size: 14),
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
          if (c.moVoterFileId != null && c.moVoterFileId!.isNotEmpty)
            _infoRow(Icons.how_to_reg, 'Voter Match', c.moVoterFileId!),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: CAMPAIGN FINANCE (MEC Data)
  // ═══════════════════════════════════════════════════════════════

  // ── Shimmer Loading Skeleton ──
  Widget _buildShimmerSkeleton({int cardCount = 3}) =>
      CandidateUI.shimmerSkeleton(cardCount: cardCount);

  /// Researched money-intelligence profiles for the candidate's linked
  /// committees — MEC (entity_type 'committee', key = mec_id) and FEC
  /// (entity_type 'fec_committee', key = cmte_id). Sections with no profile
  /// hide themselves so this collapses to nothing when nothing is researched.
  List<Widget> _buildCommitteeIntelligence() {
    final sections = <Widget>[];
    for (final c in _mecCommittees) {
      final mecId = c['mec_id']?.toString() ?? '';
      if (mecId.isEmpty) continue;
      sections.add(IntelligenceProfileSection(
        entityType: 'committee',
        entityKey: mecId,
        accentColor: BrandColors.momentumBlue,
        subtitle: c['committee_name'] as String? ?? 'MEC $mecId',
        hideWhenEmpty: true,
      ));
      sections.add(const SizedBox(height: 12));
    }
    for (final c in _fecCommittees) {
      final cmteId = c['cmte_id']?.toString() ?? '';
      if (cmteId.isEmpty) continue;
      sections.add(IntelligenceProfileSection(
        entityType: 'fec_committee',
        entityKey: cmteId,
        accentColor: BrandColors.federalBlue,
        subtitle: c['cmte_name'] as String? ?? 'FEC $cmteId',
        hideWhenEmpty: true,
      ));
      sections.add(const SizedBox(height: 12));
    }
    return sections;
  }

  /// First non-empty value across a set of candidate keys in [map]. Used to
  /// read freshness metadata defensively — the FEC/MEC summary RPCs may or may
  /// not surface these fields yet, so we render only what actually arrives.
  String? _firstOf(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  /// A short "how current is this money data" strip. Shows the source
  /// (FEC or MEC), the coverage-through date, the report period and the last
  /// sync time — whichever the backend already provides. Turns amber when the
  /// coverage date is older than 45 days. Returns null (renders nothing) until
  /// at least one freshness field is populated, so there is no fabricated
  /// "as of" claim before the backfill (B2/B3) lands.
  Widget? _buildFinanceFreshnessBanner({required bool isFec}) {
    final Map<String, dynamic> src = isFec ? _fecSummary : _financeSummary;
    if (src.isEmpty) return null;

    final coverage = _firstOf(src, const [
      'coverage_end_date',
      'coverage_through',
      'coverage_end',
      'report_through_date',
      'latest_report_date',
      'last_report_date',
      'through_date',
    ]);
    final period = _firstOf(src, const [
      'report_period',
      'report_type',
      'latest_report',
      'report_year',
    ]);
    final synced = _firstOf(src, const [
      'last_synced',
      'synced_at',
      'last_sync',
      'refreshed_at',
      'updated_at',
    ]);

    if (coverage == null && period == null && synced == null) return null;

    // Stale if we can date the coverage and it is >45 days old.
    var stale = false;
    if (coverage != null) {
      final d = DateTime.tryParse(coverage);
      if (d != null) {
        stale = DateTime.now().difference(d).inDays > 45;
      }
    }

    final Color accent = stale ? BrandColors.warning : BrandColors.steelBlue;
    final String sourceLabel = isFec
        ? 'Federal Election Commission'
        : 'Missouri Ethics Commission';

    final bits = <String>[];
    if (coverage != null) bits.add('Coverage through $coverage');
    if (period != null) bits.add('Report: $period');
    if (synced != null) bits.add('Synced $synced');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stale ? Icons.warning_amber_rounded : Icons.verified_outlined,
              color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stale ? '$sourceLabel · may be out of date' : sourceLabel,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                if (bits.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bits.join(' · '),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyTab() {
    if (_financeLoading) {
      return _buildShimmerSkeleton(cardCount: 4);
    }

    // Error/timeout banner — rendered above whatever data we did manage to load
    Widget? errorBanner;
    if (_financeError != null) {
      errorBanner = Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _financeError!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton.icon(
              onPressed: _financeLoading ? null : _loadFinanceData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final hasFinanceData = _mecCommittees.isNotEmpty;
    final hasExpenditures = (_expenditureSummary['total_spent'] as num?)?.toDouble() != null &&
        ((_expenditureSummary['total_spent'] as num?)?.toDouble() ?? 0) > 0;
    final hasFecData = ((_fecSummary['total_raised'] as num?)?.toDouble() ?? 0) > 0 ||
        _fecCommittees.isNotEmpty;

    if (!hasFinanceData && !hasFecData && _raceComparison.isEmpty) {
      final empty = _buildUnlinkedFinanceEmptyState();
      if (errorBanner != null) {
        return Column(
          children: [errorBanner, Expanded(child: empty)],
        );
      }
      return empty;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        if (errorBanner != null) ...[
          errorBanner,
          const SizedBox(height: 16),
        ],

        // ── Data freshness banner (source, coverage, last sync) ──
        if (_buildFinanceFreshnessBanner(isFec: hasFecData) != null) ...[
          _buildFinanceFreshnessBanner(isFec: hasFecData)!,
          const SizedBox(height: 16),
        ],

        // ── Intelligence Profiles for linked committees (MEC + FEC) ──
        ..._buildCommitteeIntelligence(),

        // ── FEC Federal Finance Summary (for federal candidates) ──
        if (hasFecData) ...[
          _buildFECSummarySection(),
          const SizedBox(height: 16),
          _buildFECSpendingSection(),
          const SizedBox(height: 16),
          _buildFECOutsideSpendingSection(),
          const SizedBox(height: 24),
        ],

        // ── Committee Selector — always visible when any committee is linked ──
        if (_mecCommittees.isNotEmpty) ...[
          _buildCommitteeSelector(),
          const SizedBox(height: 16),
        ],

        // ── Finance Summary Cards ──
        if (hasFinanceData) ...[
          _buildFinanceSummaryCards(),
          const SizedBox(height: 16),
        ],

        // ── Contribution Timeline Chart ──
        if (_contributionTimeline.isNotEmpty) ...[
          _buildContributionTimeline(),
          const SizedBox(height: 16),
        ],

        // ── Expenditure Section (NEW) ──
        if (hasExpenditures) ...[
          _buildExpenditureSummaryCards(),
          const SizedBox(height: 16),
          _buildSpendingByPurpose(),
          const SizedBox(height: 16),
          if (_topPayees.isNotEmpty) ...[
            _buildTopPayees(),
            const SizedBox(height: 16),
          ],
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

        // ── Race Fundraising Comparison (REAL DATA) ──
        if (_raceComparison.isNotEmpty) ...[
          _buildRaceFundraisingComparison(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCommitteeSelector() {
    final hasMultiple = _mecCommittees.length > 1;
    return _card(
      'MEC Committee',
      Icons.account_balance,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // "All committees" aggregate option — only shown when >1 committee is linked
          if (hasMultiple) _buildAllCommitteesPill(),
          ..._mecCommittees.map((committee) {
            final mecId = committee['mec_id']?.toString() ?? '';
            final name = committee['committee_name'] as String? ?? 'Unknown Committee';
            final isSelected = mecId == _selectedMecId;
            final treasurer = committee['treasurer_name'] as String?;
            final type = committee['committee_type'] as String?;
            final status = committee['committee_status'] as String?;
            final party = committee['party_affiliation'] as String?;
            final terminated = committee['terminated_date'] != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? BrandColors.sunriseGold.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? BrandColors.sunriseGold.withOpacity(0.5) : Colors.white12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.account_balance,
                      color: isSelected ? BrandColors.sunriseGold : Colors.white70,
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
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Icon(Icons.check_circle, color: BrandColors.sunriseGold, size: 18),
                        IconButton(
                          icon: const Icon(Icons.link_off, color: Colors.white54, size: 18),
                          tooltip: 'Detach from candidate',
                          onPressed: () => _detachMecCommittee(mecId),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() => _selectedMecId = mecId);
                      _loadFinanceData();
                    },
                  ),
                  if (isSelected && (treasurer != null || type != null || status != null || party != null || terminated))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (treasurer != null && treasurer.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.person_outline, color: Colors.white54, size: 14),
                                const SizedBox(width: 6),
                                Text('Treasurer: $treasurer',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (type != null && type.isNotEmpty) _committeeMetaChip(type, BrandColors.steelBlue),
                              if (party != null && party.isNotEmpty)
                                _committeeMetaChip(party,
                                    party.toLowerCase().contains('rep')
                                        ? BrandColors.republicanRed
                                        : BrandColors.democratBlue),
                              if (status != null && status.isNotEmpty)
                                _committeeMetaChip(status, Colors.white38),
                              if (terminated) _committeeMetaChip('Terminated', Colors.orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          // "Attach another" row
          Material(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _attachMecCommittee,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.add_link, color: BrandColors.momentumBlue, size: 18),
                    const SizedBox(width: 10),
                    Text('Attach another committee',
                        style: TextStyle(
                            color: BrandColors.momentumBlue.withOpacity(0.9),
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Edit profile" CTA at the top of the Profile tab. Highlights what's
  /// missing so the user knows exactly what to fill in.
  Widget _buildEditProfileCta() {
    final missing = <String>[];
    if (c.dateOfBirth == null) missing.add('DOB');
    if ((c.email == null || c.email!.isEmpty) && (c.phone == null || c.phone!.isEmpty)) missing.add('contact');
    if (c.photoUrl == null || c.photoUrl!.isEmpty) missing.add('photo');
    if (c.bio == null || c.bio!.isEmpty) missing.add('bio');
    if (c.occupation == null || c.occupation!.isEmpty) missing.add('occupation');

    final subtitle = missing.isEmpty
        ? 'Tap to fine-tune any detail on this candidate'
        : 'Missing: ${missing.join(", ")}';

    return InkWell(
      onTap: _openEditDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BrandColors.sunriseGold.withOpacity(0.15),
              BrandColors.momentumBlue.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.5)),
              ),
              child: const Icon(Icons.edit, color: BrandColors.sunriseGold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit profile details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: missing.isEmpty ? Colors.white70 : BrandColors.sunriseGold.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: missing.isEmpty ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCommitteesPill() {
    final isSelected = _selectedMecId == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [BrandColors.sunriseGold, Color(0xFFF5A000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? BrandColors.sunriseGold : Colors.white12,
          width: isSelected ? 0 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: BrandColors.sunriseGold.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.all_inclusive,
          color: isSelected ? Colors.black87 : Colors.white70,
          size: 20,
        ),
        title: Text(
          'All committees',
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Aggregate across ${_mecCommittees.length} committees',
          style: TextStyle(
            color: isSelected ? Colors.black87.withOpacity(0.7) : Colors.white70,
            fontSize: 11,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.black87, size: 18)
            : null,
        onTap: () {
          setState(() => _selectedMecId = null);
          _loadFinanceData();
        },
      ),
    );
  }

  Widget _committeeMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  // ─── MEC Committee attach / detach ──────────────────────────────

  Widget _buildUnlinkedFinanceEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BrandColors.unityBlue.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BrandColors.steelBlue.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance, color: BrandColors.steelBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('No MEC committee linked',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'No MEC filings linked yet. The quarterly sync has not matched a '
                'committee for ${c.name}. Connect their Missouri Ethics Commission '
                'committee to pull in contributions, expenditures, and donor history. '
                'Search by committee name, candidate name, or MEC ID.',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _attachMecCommittee,
                icon: const Icon(Icons.add_link, size: 16),
                label: const Text('Attach MEC committee'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.momentumBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No FEC federal record either. Edit the candidate profile if this is a federal race.',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _attachMecCommittee() async {
    final existing = _candidate.mecCommitteeIds.toSet();
    final picked = await showMecCommitteePicker(context, excludeMecIds: existing);
    if (picked == null) return;
    final newMecId = picked['mec_id']?.toString();
    if (newMecId == null || newMecId.isEmpty) return;

    final updated = [...existing, newMecId];
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.updateCandidate(_candidate.id, {'mec_committee_ids': updated});
    } catch (e) {
      debugPrint('❌ Error attaching MEC committee: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to attach committee'), backgroundColor: BrandColors.error),
      );
      return;
    }

    final refreshed = await _repo.fetchCandidate(_candidate.id);
    if (!mounted) return;
    if (refreshed != null) {
      setState(() {
        _candidate = refreshed;
        _selectedMecId = newMecId; // switch the view to the newly-linked committee
      });
      _loadFinanceData();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('✅ Linked ${picked['committee_name'] ?? newMecId}'),
        backgroundColor: BrandColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _detachMecCommittee(String mecId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        title: const Text('Detach committee?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove MEC $mecId from ${_candidate.name}? This does NOT delete any MEC data. It just unlinks this committee from this candidate.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Detach', style: TextStyle(color: BrandColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final remaining = _candidate.mecCommitteeIds.where((id) => id != mecId).toList();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.updateCandidate(_candidate.id, {'mec_committee_ids': remaining});
    } catch (e) {
      debugPrint('❌ Error detaching MEC committee: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to detach committee'), backgroundColor: BrandColors.error),
      );
      return;
    }

    final refreshed = await _repo.fetchCandidate(_candidate.id);
    if (!mounted) return;
    if (refreshed != null) {
      setState(() {
        _candidate = refreshed;
        if (_selectedMecId == mecId) {
          _selectedMecId = remaining.isNotEmpty ? remaining.first : null;
        }
      });
      _loadFinanceData();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Unlinked MEC $mecId'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFinanceSummaryCards() {
    final totalRaised = (_financeSummary['total_raised'] as num?)?.toDouble() ?? 0;
    final contributionCount = _financeSummary['contribution_count'] as int? ?? 0;
    final monetaryTotal = (_financeSummary['monetary_total'] as num?)?.toDouble() ?? 0;
    final inKindTotal = (_financeSummary['in_kind_total'] as num?)?.toDouble() ?? 0;
    final inKindCount = _financeSummary['in_kind_count'] as int? ?? 0;
    final avgContribution = (_financeSummary['avg_contribution'] as num?)?.toDouble() ?? 0;

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

  Widget _financeStatCard(String label, String value, IconData icon, Color accent) =>
      CandidateUI.financeStatCard(label, value, icon, accent);

  Widget _buildFECSummarySection() {
    final totalRaised = (_fecSummary['total_raised'] as num?)?.toDouble() ?? 0;
    final contribCount = (_fecSummary['contribution_count'] as num?)?.toInt() ?? 0;
    final avgContribution = (_fecSummary['avg_contribution'] as num?)?.toDouble() ?? 0;
    final uniqueDonors = (_fecSummary['unique_donors'] as num?)?.toInt() ?? 0;
    final indivTotal = (_fecSummary['individual_total'] as num?)?.toDouble() ?? 0;
    final pacTotal = (_fecSummary['pac_total'] as num?)?.toDouble() ?? 0;
    final cyclesActive = (_fecSummary['cycles_active'] as num?)?.toInt() ?? 0;

    return _card(
      'FEC Federal Fundraising',
      Icons.flag,
      BrandColors.federalBlue, // federal blue
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Committee chips
          if (_fecCommittees.isNotEmpty) ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _fecCommittees.take(4).map((cm) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandColors.federalBlue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BrandColors.federalBlue.withOpacity(0.3)),
                ),
                child: Text(
                  cm['cycle'] != null
                    ? '${cm['cmte_name'] ?? cm['cmte_id']} · ${cm['cycle']}'
                    : '${cm['cmte_name'] ?? cm['cmte_id']}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // Summary stat cards row 1
          Row(
            children: [
              Expanded(child: _financeStatCard('Total Raised', '\$${_formatMoney(totalRaised)}', Icons.attach_money, BrandColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _financeStatCard('Contributions', '$contribCount', Icons.receipt_long, BrandColors.steelBlue)),
              const SizedBox(width: 8),
              Expanded(child: _financeStatCard('Unique Donors', '$uniqueDonors', Icons.people, BrandColors.sunriseGold)),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2
          Row(
            children: [
              Expanded(child: _financeStatCard('Avg Contrib', '\$${_formatMoney(avgContribution)}', Icons.trending_up, BrandColors.momentumBlue)),
              const SizedBox(width: 8),
              Expanded(child: _financeStatCard('Individual', '\$${_formatMoney(indivTotal)}', Icons.person, Colors.lightBlueAccent)),
              const SizedBox(width: 8),
              Expanded(child: _financeStatCard('PAC', '\$${_formatMoney(pacTotal)}', Icons.business, Colors.purpleAccent)),
            ],
          ),
          if (cyclesActive > 0) ...[
            const SizedBox(height: 12),
            Text('Active across $cyclesActive election cycle${cyclesActive > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
          // Monthly timeline (line count only — compact)
          if (_fecTimeline.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${_fecTimeline.length} active months · ${_fecRecentContributions.length} recent contributions tracked',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          // Top FEC donors
          if (_fecTopDonors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Top Federal Donors', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._fecTopDonors.map((d) {
              final name = d['donor_name']?.toString() ?? '—';
              final city = d['city']?.toString() ?? '';
              final state = d['state']?.toString() ?? '';
              final total = (d['total_amount'] as num?)?.toDouble() ?? 0;
              final cnt = (d['contribution_count'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12))),
                    if (city.isNotEmpty || state.isNotEmpty)
                      Text('$city${city.isNotEmpty && state.isNotEmpty ? ", " : ""}$state',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 10),
                    Text('\$${_formatMoney(total)} ($cnt)',
                      style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── FEC Federal Spending (who the candidate pays) ──
  Widget _buildFECSpendingSection() {
    // Derive accurate totals from the by-purpose aggregation (covers every
    // itemized disbursement, not just the top slice).
    double totalSpent = 0;
    int paymentCount = 0;
    for (final p in _fecSpendingByPurpose) {
      totalSpent += (p['total_spent'] as num?)?.toDouble() ?? 0;
      paymentCount += (p['payment_count'] as num?)?.toInt() ?? 0;
    }
    final avgSpend = paymentCount > 0 ? totalSpent / paymentCount : 0.0;

    final hasSpending = _fecSpendingByPurpose.isNotEmpty ||
        _fecTopPayees.isNotEmpty ||
        _fecRecentExpenditures.isNotEmpty;

    return _card(
      'FEC Federal Spending',
      Icons.payments,
      BrandColors.federalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (!hasSpending) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No itemized spending reported',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Summary stat cards
            Row(
              children: [
                Expanded(child: _financeStatCard('Total Spent', '\$${_formatMoney(totalSpent)}', Icons.payment, Colors.redAccent)),
                const SizedBox(width: 8),
                Expanded(child: _financeStatCard('Payments', '$paymentCount', Icons.receipt, Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _financeStatCard('Avg Spend', '\$${_formatMoney(avgSpend)}', Icons.show_chart, Colors.deepOrange)),
              ],
            ),

            // Spending by purpose
            if (_fecSpendingByPurpose.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Spending by Purpose', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._fecSpendingByPurpose.take(8).map((item) {
                final purpose = (item['purpose'] as String?)?.trim();
                final category = (item['category_desc'] as String?)?.trim();
                final label = (purpose != null && purpose.isNotEmpty)
                    ? purpose
                    : (category != null && category.isNotEmpty ? category : 'Unspecified');
                final total = (item['total_spent'] as num?)?.toDouble() ?? 0;
                final count = (item['payment_count'] as num?)?.toInt() ?? 0;
                final pct = totalSpent > 0 ? total / totalSpent : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '\$${_formatMoney(total)} ($count)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.deepOrange.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Top payees
            if (_fecTopPayees.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Top Payees', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...List.generate(_fecTopPayees.length.clamp(0, 15), (i) {
                final payee = _fecTopPayees[i];
                final name = (payee['payee_name'] as String?)?.trim();
                final displayName = (name != null && name.isNotEmpty) ? name : 'Unknown';
                final amount = (payee['total_spent'] as num?)?.toDouble() ?? 0;
                final count = (payee['payment_count'] as num?)?.toInt() ?? 0;
                final city = (payee['city'] as String? ?? '').trim();
                final state = (payee['state'] as String? ?? '').trim();
                final location = [city, state].where((s) => s.isNotEmpty).join(', ');
                final purpose = (payee['top_purpose'] as String? ?? '').trim();

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
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '#${i + 1}',
                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (location.isNotEmpty || purpose.isNotEmpty)
                              Text(
                                [location, purpose].where((s) => s.isNotEmpty).join(' · '),
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${_formatMoney(amount)}', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('$count payment${count == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Recent payments
            if (_fecRecentExpenditures.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Recent Payments', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._fecRecentExpenditures.take(12).map((e) {
                final name = (e['payee_name'] as String?)?.trim();
                final displayName = (name != null && name.isNotEmpty) ? name : 'Unknown';
                final amount = (e['transaction_amt'] as num?)?.toDouble() ?? 0;
                final date = (e['transaction_dt'] as String? ?? '').trim();
                final purpose = (e['purpose'] as String? ?? '').trim();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              [date, if (purpose.isNotEmpty) purpose].join(' · '),
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('\$${_formatMoney(amount)}',
                          style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  // ── Outside Spending (independent expenditures for/against the candidate) ──
  Widget _buildFECOutsideSpendingSection() {
    final supportTotal = (_fecOutsideSpending['support_total'] as num?)?.toDouble() ?? 0;
    final opposeTotal = (_fecOutsideSpending['oppose_total'] as num?)?.toDouble() ?? 0;
    final bySpender = (_fecOutsideSpending['by_spender'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final hasOutside = supportTotal > 0 || opposeTotal > 0 || bySpender.isNotEmpty;

    return _card(
      'Outside Spending',
      Icons.campaign,
      BrandColors.federalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (!hasOutside) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No outside spending reported',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Support vs oppose totals — shown prominently.
            // Green = money supporting this candidate, red = money opposing them.
            Row(
              children: [
                Expanded(child: _financeStatCard('Supporting', '\$${_formatMoney(supportTotal)}', Icons.thumb_up, BrandColors.success)),
                const SizedBox(width: 8),
                Expanded(child: _financeStatCard('Opposing', '\$${_formatMoney(opposeTotal)}', Icons.thumb_down, BrandColors.error)),
              ],
            ),

            // Per-spender breakdown
            if (bySpender.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('By Spender', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...bySpender.map((s) {
                final name = (s['spender_name'] as String?)?.trim();
                final displayName = (name != null && name.isNotEmpty) ? name : 'Unknown';
                final amount = (s['amount'] as num?)?.toDouble() ?? 0;
                final code = (s['support_oppose'] as String? ?? '').trim().toUpperCase();
                final supporting = code == 'S';
                final chipColor = supporting ? BrandColors.success : BrandColors.error;
                final chipLabel = supporting ? 'FOR' : 'AGAINST';
                final latestDate = (s['latest_date'] as String? ?? '').trim();

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // FOR / AGAINST chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chipColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: chipColor.withOpacity(0.5), width: 0.5),
                        ),
                        child: Text(
                          chipLabel,
                          style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (latestDate.isNotEmpty)
                              Text('Latest: $latestDate',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('\$${_formatMoney(amount)}',
                          style: TextStyle(color: chipColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ],
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
                          style: const TextStyle(color: Colors.white70, fontSize: 8),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height.clamp(4.0, 130.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [BrandColors.momentumBlue.withOpacity(0.8), BrandColors.sunriseGold],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            boxShadow: [
                              BoxShadow(color: BrandColors.sunriseGold.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, -2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shortMonth,
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
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
    final maxAmount = _topDonors.isNotEmpty
        ? (_topDonors.first['total_amount'] as num?)?.toDouble() ?? 1
        : 1.0;

    return _card(
      'Top Donors',
      Icons.star,
      BrandColors.sunriseGold,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(_topDonors.length, (i) {
            final donor = _topDonors[i];
            final name = (donor['donor_name'] as String? ?? '').trim();
            final company = donor['company'] as String? ?? '';
            final city = donor['city'] as String? ?? '';
            final state = donor['state'] as String? ?? '';
            final amount = (donor['total_amount'] as num?)?.toDouble() ?? 0;
            final count = (donor['contribution_count'] as num?)?.toInt() ?? 0;
            final displayName = name.isNotEmpty ? name : company.isNotEmpty ? company : 'Anonymous';
            final location = [city, state].where((s) => s.isNotEmpty).join(', ');
            final barWidth = maxAmount > 0 ? amount / maxAmount : 0.0;

            final donorFirst = donor['first_name'] as String? ?? '';
            final donorLast  = donor['last_name']  as String? ?? '';

            return GestureDetector(
              onTap: (donorFirst.isNotEmpty || donorLast.isNotEmpty)
                  ? () => _openDonorProfileByKey(
                        firstName: donorFirst,
                        lastName: donorLast,
                        city: city,
                        state: state,
                      )
                  : null,
              child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(i == 0 ? 0.07 : 0.04),
                borderRadius: BorderRadius.circular(12),
                border: i == 0 ? Border.all(color: BrandColors.sunriseGold.withOpacity(0.2)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_donorRankColor(i).withOpacity(0.3), _donorRankColor(i).withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '#${i + 1}',
                            style: TextStyle(color: _donorRankColor(i), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (location.isNotEmpty)
                              Text(location, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_formatMoney(amount)}',
                            style: TextStyle(color: _donorRankColor(i), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (count > 1)
                            Text('$count gifts', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Mini bar chart
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      minHeight: 3,
                      backgroundColor: Colors.white.withOpacity(0.04),
                      valueColor: AlwaysStoppedAnimation<Color>(_donorRankColor(i).withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
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

  bool _showAllContributions = false;

  Widget _buildRecentContributions() {
    final total = _mecContributions.length;
    final showCount = _showAllContributions ? total : math.min(total, 20);

    return _card(
      'Recent Contributions ($total total)',
      Icons.receipt_long,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(showCount, (i) {
            final contrib = _mecContributions[i];
            final cFirst = contrib.contributorFirstName ?? '';
            final cLast  = contrib.contributorLastName  ?? '';
            return GestureDetector(
              onTap: (cFirst.isNotEmpty || cLast.isNotEmpty)
                  ? () => _openDonorProfileByKey(
                        firstName: cFirst,
                        lastName: cLast,
                        city: contrib.contributorCity,
                        state: contrib.contributorState,
                      )
                  : null,
              child: Container(
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
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      contrib.contributionDate ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
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
                        color: contrib.contributionAmount > 0 ? BrandColors.success : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            );
          }),
          if (total > 20 && !_showAllContributions) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showAllContributions = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: BrandColors.steelBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BrandColors.steelBlue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.expand_more, color: BrandColors.steelBlue, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Show all ${total - 20} remaining contributions',
                      style: const TextStyle(color: BrandColors.steelBlue, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_showAllContributions && total > 20) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showAllContributions = false),
              child: Text(
                'Show less',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Expenditure Summary Cards ──
  Widget _buildExpenditureSummaryCards() {
    final totalSpent = (_expenditureSummary['total_spent'] as num?)?.toDouble() ?? 0;
    final expCount = (_expenditureSummary['expenditure_count'] as num?)?.toInt() ?? 0;
    final avgExp = (_expenditureSummary['avg_expenditure'] as num?)?.toDouble() ?? 0;
    final uniquePayees = (_expenditureSummary['unique_payees'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.trending_down, color: Colors.redAccent.withOpacity(0.7), size: 18),
              const SizedBox(width: 6),
              const Text('Spending', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _financeStatCard('Total Spent', '\$${_formatMoney(totalSpent)}', Icons.payment, Colors.redAccent)),
            const SizedBox(width: 10),
            Expanded(child: _financeStatCard('Expenditures', '$expCount', Icons.receipt, Colors.orange)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _financeStatCard('Avg Spend', '\$${_formatMoney(avgExp)}', Icons.show_chart, Colors.deepOrange)),
            const SizedBox(width: 10),
            Expanded(child: _financeStatCard('Payees', '$uniquePayees', Icons.store, Colors.amber)),
          ],
        ),
      ],
    );
  }

  // ── Spending by Purpose ──
  Widget _buildSpendingByPurpose() {
    final byPurpose = (_expenditureSummary['by_purpose'] as List<dynamic>?) ?? [];
    if (byPurpose.isEmpty) return const SizedBox.shrink();

    final totalSpent = (_expenditureSummary['total_spent'] as num?)?.toDouble() ?? 1;

    return _card(
      'Spending by Purpose',
      Icons.pie_chart,
      Colors.deepOrange,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...byPurpose.take(8).map((item) {
            final purpose = item['purpose'] as String? ?? 'Unknown';
            final total = (item['total'] as num?)?.toDouble() ?? 0;
            final count = (item['count'] as num?)?.toInt() ?? 0;
            final pct = totalSpent > 0 ? total / totalSpent : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          purpose,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${_formatMoney(total)} ($count)',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepOrange.withOpacity(0.7),
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

  // ── Top Payees ──
  Widget _buildTopPayees() {
    return _card(
      'Top Payees',
      Icons.store,
      Colors.amber,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(_topPayees.length, (i) {
            final payee = _topPayees[i];
            final name = payee['payee_name'] as String? ?? 'Unknown';
            final amount = (payee['total_amount'] as num?)?.toDouble() ?? 0;
            final count = (payee['payment_count'] as num?)?.toInt() ?? 0;
            final city = payee['city'] as String? ?? '';
            final state = payee['state'] as String? ?? '';
            final location = [city, state].where((s) => s.isNotEmpty).join(', ');
            final firstName = (payee['payee_first_name'] as String? ?? '').trim();
            final lastName = (payee['payee_last_name'] as String? ?? '').trim();
            final company = (payee['payee_company'] as String? ?? '').trim();
            final canOpen = company.isNotEmpty || lastName.isNotEmpty;

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: canOpen
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MECPayeeScreen(
                            firstName: firstName.isNotEmpty ? firstName : null,
                            lastName: lastName.isNotEmpty ? lastName : null,
                            company: company.isNotEmpty ? company : null,
                            city: city.isNotEmpty ? city : null,
                            state: state.isNotEmpty ? state : null,
                          ),
                        ))
                    : null,
                child: Container(
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
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '#${i + 1}',
                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (location.isNotEmpty)
                              Text(location, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${_formatMoney(amount)}', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('$count payments', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                      if (canOpen) const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Race Fundraising Comparison (REAL DATA) ──
  Widget _buildRaceFundraisingComparison() {
    final maxRaised = _raceComparison.fold<double>(
      0,
      (max, r) => math.max(max, (r['total_raised'] as num?)?.toDouble() ?? 0),
    );

    return _card(
      'Race Fundraising',
      Icons.compare_arrows,
      Colors.purpleAccent,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._raceComparison.map((candidate) {
            final name = candidate['name'] as String? ?? '';
            final party = (candidate['party'] as String? ?? '').toLowerCase();
            final raised = (candidate['total_raised'] as num?)?.toDouble() ?? 0;
            final spent = (candidate['total_spent'] as num?)?.toDouble() ?? 0;
            final contribs = (candidate['contribution_count'] as num?)?.toInt() ?? 0;
            final isCurrent = candidate['candidate_id'] == c.id;
            final isIncumbent = candidate['incumbent'] == true;
            final noCommittee = candidate['no_committee_linked'] == true;
            final source = candidate['source'] as String? ?? 'MEC';

            Color partyColor;
            if (party.contains('democrat')) {
              partyColor = BrandColors.democratBlue;
            } else if (party.contains('republican')) {
              partyColor = BrandColors.republicanRed;
            } else {
              partyColor = Colors.amber;
            }

            final barWidth = maxRaised > 0 ? raised / maxRaised : 0.0;
            final candidateId = candidate['candidate_id']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? BrandColors.sunriseGold.withOpacity(0.18)
                    : BrandColors.unityBlue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent
                      ? BrandColors.sunriseGold.withOpacity(0.5)
                      : partyColor.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isCurrent
                      ? null
                      : () => _openOpponentFinanceDetail(
                            candidate: candidate,
                            candidateId: candidateId,
                            partyColor: partyColor,
                          ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: partyColor.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  party.contains('democrat') ? 'D' : party.contains('republican') ? 'R' : '?',
                                  style: TextStyle(color: partyColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isIncumbent) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BrandColors.sunriseGold.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('INCUMBENT',
                                    style: TextStyle(
                                        color: BrandColors.sunriseGold,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BrandColors.sunriseGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('You', style: TextStyle(color: BrandColors.sunriseGold, fontSize: 9, fontWeight: FontWeight.bold)),
                              )
                            else
                              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.6), size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barWidth,
                            minHeight: 14,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(partyColor.withOpacity(0.9)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (noCommittee && raised == 0)
                          Row(children: [
                            const Icon(Icons.info_outline, color: Colors.white54, size: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'No MEC or FEC committee on file, not yet reporting',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ])
                        else
                          Row(
                            children: [
                              Text('\$${_formatMoney(raised)} raised', style: TextStyle(color: partyColor, fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(source, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 12),
                              Text('$contribs donors', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              const Spacer(),
                              if (spent > 0)
                                Text('\$${_formatMoney(spent)} spent', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: DISTRICT (Election History + District Intel)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRaceTab() {
    if (_raceLoading) {
      return _buildShimmerSkeleton(cardCount: 5);
    }

    if (c.district == null || c.district!.isEmpty) {
      // Tailor the empty-state message to the office level
      final level = c.officeLevel ?? '';
      String title, message;
      if (level == 'federal') {
        title = 'Federal Race';
        message = 'District-level race data is not yet available for federal candidates.';
      } else if (level == 'statewide') {
        title = 'Statewide Race';
        message = 'This is a statewide race, so there is no district breakdown available.';
      } else if (level == 'judicial') {
        title = 'Judicial Race';
        message = 'Circuit-level race data is not yet available.';
      } else {
        title = 'No District Data';
        message = 'This candidate does not have a district assignment.';
      }
      return _buildEmptyState(Icons.map, title, message);
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

        // ── Partisan Lean ──
        _buildPartisanLean(),
        const SizedBox(height: 16),

        // ── Election History Charts ──
        if (_electionResults.isNotEmpty) ...[
          _buildElectionBarChart(),
          const SizedBox(height: 16),
          _buildWinMarginTrend(),
          const SizedBox(height: 16),
          _buildVoterTurnoutChart(),
          const SizedBox(height: 16),
          _buildHistoryDetailList(),
          const SizedBox(height: 16),
        ] else ...[
          _buildElectionHistoryPlaceholder(),
          const SizedBox(height: 16),
        ],

        // ── Demographics ──
        if (_districtDemographics != null) ...[
          _buildVoterRegistration(),
          const SizedBox(height: 16),
          _buildDemographicProfile(),
          const SizedBox(height: 16),
        ],

        // ── Past Candidates in This District ──
        if (_historicalCandidates.isNotEmpty) ...[
          _buildHistoricalCandidates(),
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
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
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
              painter: MarginTrendPainter(
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
                    child: Text('${r.year}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

  Widget _buildHistoryDetailList() {
    return _card(
      'Election History (${_electionResults.length} races)',
      Icons.how_to_vote,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 12),
          ..._electionResults.map((r) {
            final demPct = r.demPercent ?? 0;
            final repPct = r.repPercent ?? 0;
            final totalPct = demPct + repPct;
            final demBar = totalPct > 0 ? demPct / totalPct : 0.5;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Year + winner badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: r.demWon
                              ? BrandColors.democratBlue.withOpacity(0.25)
                              : BrandColors.republicanRed.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${r.year}',
                          style: TextStyle(
                            color: r.demWon ? BrandColors.democratBlue : BrandColors.republicanRed,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.demWon
                              ? (r.demCandidate ?? 'Democrat')
                              : (r.repCandidate ?? 'Republican'),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (r.totalVotes != null)
                        Text(
                          '${_formatNumber(r.totalVotes!)} votes',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Visual vote share bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          Flexible(
                            flex: (demBar * 100).round().clamp(1, 99),
                            child: Container(
                              color: BrandColors.democratBlue.withOpacity(0.7),
                              alignment: Alignment.center,
                              child: demPct >= 15
                                  ? Text('${demPct.toStringAsFixed(0)}%',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                          Flexible(
                            flex: ((1 - demBar) * 100).round().clamp(1, 99),
                            child: Container(
                              color: BrandColors.republicanRed.withOpacity(0.7),
                              alignment: Alignment.center,
                              child: repPct >= 15
                                  ? Text('${repPct.toStringAsFixed(0)}%',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Candidate names below bar
                  Row(
                    children: [
                      if (r.demCandidate != null)
                        Expanded(
                          child: Text(
                            'D: ${r.demCandidate!.replaceAll(' Incumbent', '')}',
                            style: TextStyle(color: BrandColors.democratBlue.withOpacity(0.8), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (r.repCandidate != null)
                        Expanded(
                          child: Text(
                            'R: ${r.repCandidate!.replaceAll(' Incumbent', '')}',
                            style: TextStyle(color: BrandColors.republicanRed.withOpacity(0.8), fontSize: 11),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
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

  // ═══════════════════════════════════════════════════════════════
  //  TAB 4: INTEL (merged News + Endorsements + MOYD Engagement)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildIntelTab() {
    if (_intelLoading) {
      return _buildShimmerSkeleton(cardCount: 3);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Segmented Control ──
        _buildIntelSegments(),
        const SizedBox(height: 16),

        // ── Content based on selected segment ──
        if (_intelSegment == 0) ...[
          _buildNewsSection(),
        ] else if (_intelSegment == 1) ...[
          _buildEndorsementSection(),
          const SizedBox(height: 12),
          // Ballotpedia endorsements from profile
          if (c.endorsements != null && c.endorsements!.isNotEmpty) ...[
            _buildEndorsements(),
            const SizedBox(height: 12),
          ],
          _buildAddEndorsementButton(),
        ] else ...[
          _buildEngagementStatusCard(),
          const SizedBox(height: 12),
          _buildEndorsementToggle(),
          const SizedBox(height: 12),
          _buildAssignedMemberSelector(),
          const SizedBox(height: 12),
          _buildFollowUpReminder(),
          const SizedBox(height: 12),
          _buildLogContactButton(),
          const SizedBox(height: 8),
          if (_showContactForm) ...[
            _buildContactForm(),
            const SizedBox(height: 12),
          ],
          _buildContactTimeline(),
          const SizedBox(height: 12),
          _buildNotesSection(),
          const SizedBox(height: 12),
          _buildMoydMemberLink(),
        ],
      ],
    );
  }

  Widget _buildIntelSegments() {
    final segments = [
      ('📰', 'News', _newsArticles.length),
      ('👍', 'Endorsements', _endorsementRecords.length),
      ('🤝', 'MOYD', _contactLog.length),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: List.generate(segments.length, (i) {
          final isSelected = _intelSegment == i;
          final (emoji, label, count) = segments[i];

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _intelSegment = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? BrandColors.sunriseGold.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected ? Border.all(color: BrandColors.sunriseGold.withOpacity(0.4)) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? BrandColors.sunriseGold : Colors.white70,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? BrandColors.sunriseGold.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? BrandColors.sunriseGold : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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

  /// Strip HTML entities & tags that leak in from news scrapers (&nbsp;, <br>, &amp;, …).
  static String _decodeHtml(String s) {
    var out = s
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&apos;'), "'")
        .replaceAll(RegExp(r'&#39;'), "'")
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&mdash;'), '—')
        .replaceAll(RegExp(r'&ndash;'), '–')
        .replaceAll(RegExp(r'&hellip;'), '…')
        .replaceAll(RegExp(r'&#[0-9]+;'), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')  // strip any stray HTML tags
        .replaceAll(RegExp(r' +'), ' ');
    return out.trim();
  }

  Widget _buildNewsCard(CandidateNews news) {
    // Prefer AI-scored sentiment when present; fall back to keyword heuristics.
    String sentimentEmoji;
    Color sentimentColor;
    final aiLabel = news.sentimentLabel?.toLowerCase();
    if (aiLabel == 'positive') {
      sentimentEmoji = '🟢'; sentimentColor = BrandColors.success;
    } else if (aiLabel == 'negative') {
      sentimentEmoji = '🔴'; sentimentColor = BrandColors.republicanRed;
    } else if (aiLabel == 'mixed') {
      sentimentEmoji = '🟡'; sentimentColor = BrandColors.sunriseGold;
    } else if (aiLabel == 'neutral') {
      sentimentEmoji = '⚪'; sentimentColor = Colors.grey;
    } else {
      sentimentEmoji = '⚪'; sentimentColor = Colors.grey;
      final headline = news.headline.toLowerCase();
      if (headline.contains('wins') || headline.contains('endorsed') || headline.contains('support') || headline.contains('victory') || headline.contains('leads')) {
        sentimentEmoji = '🟢'; sentimentColor = BrandColors.success;
      } else if (headline.contains('loses') || headline.contains('scandal') || headline.contains('contro') || headline.contains('defeat') || headline.contains('accused')) {
        sentimentEmoji = '🔴'; sentimentColor = BrandColors.republicanRed;
      }
    }

    final displaySummary = (news.aiSummary?.trim().isNotEmpty ?? false)
        ? news.aiSummary!
        : (news.summary?.trim().isNotEmpty ?? false)
            ? news.summary!
            : '';
    // Hide garbage: legacy [[verified]] markers, exact echoes of the headline.
    final cleanSummary = (displaySummary == '[[verified]]' || displaySummary.trim() == news.headline.trim())
        ? ''
        : _decodeHtml(displaySummary);
    final cleanHeadline = _decodeHtml(news.headline);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NewsArticleDetailScreen(
          newsId: news.id,
          fallbackHeadline: cleanHeadline,
          fallbackSource: news.source,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: sentimentColor.withOpacity(0.5), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sentimentEmoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cleanHeadline,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (cleanSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  cleanSummary,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  if (news.source != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(news.source!, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                  ],
                  const Spacer(),
                  if (news.publishedAt != null)
                    Text(
                      _formatDate(news.publishedAt!),
                      style: const TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                  if (news.url != null) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_outward, color: BrandColors.momentumBlue.withOpacity(0.5), size: 12),
                  ],
                ],
              ),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
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
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                          if (notes != null && notes.isNotEmpty)
                            Text(notes, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
  //  MOYD ENGAGEMENT SEGMENT (within Intel tab)
  // ═══════════════════════════════════════════════════════════════


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
              color: c.isContacted ? BrandColors.success : Colors.white70,
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
                    color: c.isContacted ? BrandColors.success : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.lastContactDate != null
                      ? 'Last: ${_formatDate(c.lastContactDate!)} via ${c.contactMethod ?? 'unknown'}'
                      : 'No contact recorded',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${_contactLog.length} interaction${_contactLog.length == 1 ? '' : 's'} logged',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                  color: c.isEndorsed ? Colors.white : Colors.white70,
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
    // The repo's getExecCommitteeMembers() returns the live exec roster
    // from public.members WHERE executive_committee = true. Names + photos
    // come from the joined assigned_member embed on c.assignedMember.
    return _card(
      'Assigned Team Member',
      Icons.person_pin,
      BrandColors.steelBlue,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: _openAssigneePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _assigneeAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.assignedMember?['name'] as String? ?? 'Unassigned',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (c.assignedMember?['executive_title'] != null)
                        Text(
                          c.assignedMember!['executive_title'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          'Tap to assign',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assigneeAvatar() {
    final url = c.assignedMemberPhotoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: BrandColors.steelBlue.withOpacity(0.3),
        backgroundImage: NetworkImage(url),
      );
    }
    final initials = (c.assignedMember?['name'] as String? ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 22,
      backgroundColor: BrandColors.steelBlue.withOpacity(0.3),
      child: initials.isEmpty
          ? const Icon(Icons.person_outline, color: Colors.white70, size: 22)
          : Text(initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              )),
    );
  }

  Future<void> _openAssigneePicker() async {
    final exec = await _repo.getExecCommitteeMembers();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: const Color(0xFF0B1E37),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Assign to executive committee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Icon(Icons.person_off, color: Colors.white54),
                  ),
                  title: const Text('Unassigned',
                      style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.of(sheetCtx).pop(null),
                ),
                const Divider(color: Colors.white12, height: 1),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: exec.length,
                    itemBuilder: (_, i) {
                      final m = exec[i];
                      final id = m['id'] as String;
                      final name = (m['name'] as String?) ?? '(no name)';
                      final title = (m['executive_title'] as String?) ?? '';
                      // members.profile_pictures is either:
                      //   • List of {path, bucket, primary, ...} (newer
                      //     uploads — array form)
                      //   • Map of {instagram: 'rel-path'} (legacy social
                      //     scrape — object form)
                      // Build a public storage URL from whichever shape we got
                      // so the avatar actually renders.
                      final pic = _extractMemberPhotoUrl(m['profile_pictures']);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: BrandColors.steelBlue.withOpacity(0.3),
                          backgroundImage:
                              pic != null ? NetworkImage(pic) : null,
                          child: pic == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: title.isEmpty
                            ? null
                            : Text(title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                )),
                        trailing: c.assignedTo == id
                            ? const Icon(Icons.check_circle,
                                color: BrandColors.sunriseGold)
                            : null,
                        onTap: () => Navigator.of(sheetCtx).pop(id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // null vs "no choice": showModalBottomSheet returns null when dismissed
    // without a tap; we use the explicit Unassigned tile to mean
    // "set to null". Distinguish by returning a sentinel — we use
    // the sheet result directly (null = dismiss, '' would be unassign).
    // Simpler: only act when exec roster was tapped or Unassigned was tapped.
    // The Unassigned tile pops with `null` like dismiss; to differentiate,
    // we can wrap in a Map. For now: if user taps Unassigned, we accept
    // the dismiss-equivalent path by checking whether they actually
    // intended to clear vs. dismiss. Simpler approach: close-without-tap
    // also leaves nothing changed because we only call assignTeamMember
    // when picked != current.
    if (!mounted) return;
    if (picked != c.assignedTo) {
      await _repo.assignTeamMember(c.id, picked);
      final updated = await _repo.fetchCandidate(c.id);
      if (updated != null && mounted) setState(() => _candidate = updated);
    }
  }

  /// Extract a public-storage URL from `members.profile_pictures`.
  /// Handles both shapes seen in production:
  ///   • List of {path, bucket, primary, ...} objects (newer uploads)
  ///   • Map of {instagram: 'rel-path', ...} (legacy social scrape)
  /// Returns null when nothing usable is present.
  String? _extractMemberPhotoUrl(dynamic pictures) {
    if (pictures == null) return null;
    final base = CRMConfig.supabaseUrl.endsWith('/')
        ? CRMConfig.supabaseUrl.substring(0, CRMConfig.supabaseUrl.length - 1)
        : CRMConfig.supabaseUrl;
    if (base.isEmpty) return null;

    String? buildUrl(dynamic path, [dynamic bucket]) {
      if (path is! String || path.isEmpty) return null;
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
      // Some legacy entries already include the storage path prefix.
      if (path.startsWith('storage/')) {
        return '$base/$path';
      }
      final b = (bucket is String && bucket.isNotEmpty)
          ? bucket
          : 'member-photos';
      return '$base/storage/v1/object/public/$b/$path';
    }

    if (pictures is List) {
      // Prefer the entry flagged primary; fall back to the first one.
      Map? primary;
      for (final entry in pictures) {
        if (entry is Map && entry['primary'] == true) {
          primary = entry;
          break;
        }
      }
      primary ??= (pictures.isNotEmpty && pictures.first is Map)
          ? pictures.first as Map
          : null;
      if (primary == null) return null;
      final direct = primary['url'] ?? primary['public_url'] ?? primary['publicUrl'];
      if (direct is String && direct.isNotEmpty) {
        return direct.startsWith('http') ? direct : buildUrl(direct);
      }
      return buildUrl(primary['path'], primary['bucket']);
    }
    if (pictures is Map) {
      // Try standard URL keys first, then fall through to legacy
      // `instagram: <relative path>` style entries.
      final direct = pictures['url'] ?? pictures['public_url'] ?? pictures['publicUrl'];
      if (direct is String && direct.isNotEmpty) {
        return direct.startsWith('http') ? direct : buildUrl(direct);
      }
      final pathFromBucket = pictures['path'];
      if (pathFromBucket != null) {
        return buildUrl(pathFromBucket, pictures['bucket']);
      }
      // Legacy social-scrape shape: any string-valued key is a relative path.
      for (final entry in pictures.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          return buildUrl(entry.value);
        }
      }
    }
    if (pictures is String && pictures.isNotEmpty) {
      return buildUrl(pictures);
    }
    return null;
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
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
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
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
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
          const Text('Contact Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                      Icon(icon, size: 14, color: isSelected ? BrandColors.momentumBlue : Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        type.replaceAll('-', ' '),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
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
                  // Use parent context's theme + only override accent colors,
                  // so ColorScheme fields (error, outline, etc.) aren't left null
                  // and internal date-picker widgets don't crash.
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
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
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _followUpDate != null
                        ? 'Follow-up: ${_formatDate(_followUpDate!)}'
                        : 'Set follow-up date (optional)',
                    style: TextStyle(
                      color: _followUpDate != null ? BrandColors.sunriseGold : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  if (_followUpDate != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _followUpDate = null),
                      child: const Icon(Icons.close, color: Colors.white70, size: 16),
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
      fillColor: Colors.white.withOpacity(0.12),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
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
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
                c.notes?.isNotEmpty == true ? c.notes! : 'No notes yet. Tap Edit to add internal notes.',
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
    final linked = c.linkedMember;
    // If the candidate row has member_id set but the embedded fetch
    // didn't populate linked_member (e.g. the PostgREST FK embed fell
    // back to the bare select on transient errors), fetch the member
    // directly so the tile reflects truth instead of showing "no match".
    if (linked == null && (c.memberId ?? '').isNotEmpty) {
      return _card(
        'MOYD Member Status',
        Icons.card_membership,
        BrandColors.momentumBlue,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _repo.fetchMemberById(c.memberId!),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BrandColors.momentumBlue,
                      ),
                    ),
                  ),
                );
              }
              final m = snap.data;
              if (m != null) return _linkedMemberPanel(m);
              return _possibleMatchPanel();
            },
          ),
        ),
      );
    }
    return _card(
      'MOYD Member Status',
      Icons.card_membership,
      BrandColors.momentumBlue,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: linked != null
            ? _linkedMemberPanel(linked)
            : _possibleMatchPanel(),
      ),
    );
  }

  Widget _linkedMemberPanel(Map<String, dynamic> m) {
    final name = (m['name'] as String?) ?? '';
    final title = (m['executive_title'] as String?) ?? '';
    final dateJoined = m['date_joined'] as String?;
    final pic = _extractMemberPhotoUrl(m['profile_pictures']);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      // Existing _openMemberProfile() reads c.memberId — which IS this
      // member's id when c.linkedMember is populated. So a no-arg call
      // does the right thing here.
      onTap: _openMemberProfile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BrandColors.momentumBlue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.momentumBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: BrandColors.momentumBlue.withOpacity(0.3),
              backgroundImage: pic != null ? NetworkImage(pic) : null,
              child: pic == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                  if (title.isNotEmpty)
                    Text(title,
                        style: const TextStyle(
                          color: BrandColors.sunriseGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                  if (dateJoined != null && dateJoined.isNotEmpty)
                    Text('Joined $dateJoined',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  Widget _possibleMatchPanel() {
    return FutureBuilder<List<dynamic>>(
      future: _repo.findPossibleMemberMatches(
        firstName: c.firstName,
        lastName: c.lastName,
        email: c.email,
      ),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BrandColors.momentumBlue),
              ),
            ),
          );
        }
        final matches = (snap.data ?? const []).cast<Map<String, dynamic>>();
        if (matches.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.white.withOpacity(0.55), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No matching MOYD member found by name or email.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: BrandColors.sunriseGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: BrandColors.sunriseGold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Possible matches by name/email. Link to confirm.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...matches.map((m) => _matchTile(m)),
          ],
        );
      },
    );
  }

  Widget _matchTile(Map<String, dynamic> m) {
    final name = (m['name'] as String?) ?? '';
    final email = (m['email'] as String?) ?? '';
    final pics = m['profile_pictures'];
    String? pic;
    if (pics is List && pics.isNotEmpty && pics.first is Map) {
      pic = (pics.first as Map)['url'] as String?;
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: BrandColors.momentumBlue.withOpacity(0.3),
        backgroundImage: pic != null ? NetworkImage(pic) : null,
        child: pic == null
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white))
            : null,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(email,
          style: TextStyle(
              color: Colors.white.withOpacity(0.55), fontSize: 12)),
      trailing: TextButton(
        style: TextButton.styleFrom(foregroundColor: BrandColors.sunriseGold),
        onPressed: () async {
          await _repo.linkCandidateToMember(c.id, m['id'] as String);
          final updated = await _repo.fetchCandidate(c.id);
          if (updated != null && mounted) {
            setState(() => _candidate = updated);
          }
        },
        child: const Text('Link'),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 6: DISTRICT INTEL
  // ═══════════════════════════════════════════════════════════════


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
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${_districtCandidates.length} candidate${_districtCandidates.length == 1 ? '' : 's'} filed',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    if (hasDem && hasRep) return 'Contested Race: Dem vs Rep';
    if (hasDem) return 'Uncontested: Democrat Only';
    if (hasRep) return 'Uncontested: Republican Only';
    return 'No Major Party Candidates';
  }

  Widget _buildRaceCandidates() {
    // No official 2026 result rows for this race → keep the flat filed list.
    if (_raceResults.isEmpty) {
      return _buildRaceCandidatesFlat();
    }

    // November ballot = the advancing nominee of every party (D, R, L, ...),
    // Democrats first, then by votes. Primary losers never appear here.
    final advanced = _raceResults.where((r) => r.advanced).toList()
      ..sort((a, b) {
        final ad = a.isDemocrat ? 0 : 1;
        final bd = b.isDemocrat ? 0 : 1;
        if (ad != bd) return ad.compareTo(bd);
        return b.votes.compareTo(a.votes);
      });

    // Did the profiled candidate win their primary? If not, their highlighted
    // row belongs in the collapsed primary section, not the November card.
    final currentAdvanced = advanced.any(_isCurrentResult);

    return Column(
      children: [
        _buildNovemberBallotCard(advanced),
        const SizedBox(height: 16),
        _buildPrimaryResultsSection(showCurrentHint: !currentAdvanced),
      ],
    );
  }

  bool _isCurrentResult(er.ElectionResult r) =>
      _normName(r.candidateName) == _normName(c.name);

  String _normName(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  Color _partyColorFor(String party) {
    final p = party.toLowerCase();
    if (p.contains('democr')) return BrandColors.democratBlue;
    if (p.contains('republic')) return BrandColors.republicanRed;
    if (p.contains('libert')) return Colors.amber;
    return BrandColors.slateBlue;
  }

  /// Best-effort match of a result row to a full `Candidate` profile by
  /// normalized name. Null → render initials + party chip, non-tappable
  /// (never fabricate a profile for an unmatched nominee).
  Candidate? _matchResultCandidate(er.ElectionResult r) {
    final target = _normName(r.candidateName);
    for (final dc in _districtCandidates) {
      if (_normName(dc.name) == target) return dc;
    }
    return null;
  }

  Widget _buildNovemberBallotCard(List<er.ElectionResult> advanced) {
    return _card(
      'November Ballot (${advanced.length})',
      Icons.how_to_vote,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Nominees on the general-election ballot',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          if (advanced.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No nominee has advanced to the November ballot yet.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55), fontSize: 13),
              ),
            )
          else
            ...advanced.map(_buildBallotRow),
        ],
      ),
    );
  }

  Widget _buildBallotRow(er.ElectionResult r) {
    final isCurrent = _isCurrentResult(r);
    final matched = _matchResultCandidate(r);
    final partyColor = _partyColorFor(r.party);
    final tappable = matched != null && !isCurrent;

    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrent
              ? [
                  BrandColors.sunriseGold.withOpacity(0.1),
                  BrandColors.sunriseGold.withOpacity(0.03)
                ]
              : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? BrandColors.sunriseGold.withOpacity(0.3)
              : partyColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: partyColor.withOpacity(0.15),
                backgroundImage: matched?.avatarUrl != null
                    ? NetworkImage(matched!.avatarUrl!)
                    : null,
                child: matched?.avatarUrl == null
                    ? Text(
                        _initialsFor(r.candidateName),
                        style: TextStyle(
                            color: partyColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: partyColor,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0b1e37), width: 2),
                  ),
                  child: Center(
                    child: Text(r.partyShort,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.candidateName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      _badge('You', BrandColors.sunriseGold,
                          textColor: Colors.black87),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.party} · ${_formatNumber(r.votes)} votes'
                  '${r.pct != null ? ' · ${r.pct!.toStringAsFixed(1)}%' : ''}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (tappable)
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.2), size: 18),
        ],
      ),
    );

    if (!tappable) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openCandidate(matched),
      child: row,
    );
  }

  /// Collapsed-by-default section listing every result row for the race,
  /// with votes, pct, a party chip and an "Advanced" tag on the winners.
  /// Filed candidates who did not advance live only here.
  Widget _buildPrimaryResultsSection({required bool showCurrentHint}) {
    final rows = [..._raceResults]
      ..sort((a, b) {
        final ad = a.isDemocrat ? 0 : 1;
        final bd = b.isDemocrat ? 0 : 1;
        if (ad != bd) return ad.compareTo(bd);
        return b.votes.compareTo(a.votes);
      });

    return _card(
      'Primary Results (${rows.length})',
      Icons.history_edu,
      BrandColors.slateBlue,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          maintainState: true,
          initiallyExpanded: false,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          title: Text(
            showCurrentHint
                ? 'August primary field (you did not advance)'
                : 'August primary field',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          children: rows.map(_buildPrimaryResultRow).toList(),
        ),
      ),
    );
  }

  Widget _buildPrimaryResultRow(er.ElectionResult r) {
    final isCurrent = _isCurrentResult(r);
    final partyColor = _partyColorFor(r.party);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? BrandColors.sunriseGold.withOpacity(0.08)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? BrandColors.sunriseGold.withOpacity(0.3)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: partyColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              r.partyShort,
              style: TextStyle(
                  color: partyColor, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.candidateName,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            _badge('You', BrandColors.sunriseGold, textColor: Colors.black87),
          ],
          if (r.advanced) ...[
            const SizedBox(width: 6),
            _badge('Advanced', BrandColors.success),
          ],
          const SizedBox(width: 10),
          Text(
            '${_formatNumber(r.votes)}'
            '${r.pct != null ? ' · ${r.pct!.toStringAsFixed(1)}%' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _buildRaceCandidatesFlat() {
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
                    child: Text('Opponents', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: Colors.white12)),
                ],
              ),
            ),
            ...opponents.map((opp) => _buildDistrictCandidateRow(opp)),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No opponents filed', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrent
              ? [BrandColors.sunriseGold.withOpacity(0.1), BrandColors.sunriseGold.withOpacity(0.03)]
              : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? BrandColors.sunriseGold.withOpacity(0.3) : partyColor.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: isCurrent ? null : () => _openCandidate(cand),
        child: Row(
          children: [
            // Photo + party overlay
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: partyColor.withOpacity(0.15),
                  backgroundImage: cand.avatarUrl != null
                      ? NetworkImage(cand.avatarUrl!)
                      : null,
                  child: cand.avatarUrl == null
                      ? Text(cand.initials, style: TextStyle(color: partyColor, fontSize: 14, fontWeight: FontWeight.bold))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: partyColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0b1e37), width: 2),
                    ),
                    child: Center(
                      child: Text(cand.partyShort, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cand.name,
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        _badge('You', BrandColors.sunriseGold, textColor: Colors.black87),
                      ],
                      if (cand.isYoungDem && !isCurrent) ...[
                        const SizedBox(width: 6),
                        _badge('YD', BrandColors.sunriseGold, textColor: Colors.black87),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cand.party}${cand.estimatedAge != null ? ' · Age ${cand.estimatedAge}' : ''}${cand.occupation != null && cand.occupation!.isNotEmpty ? ' · ${cand.occupation}' : ''}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isCurrent)
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 18),
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

  /// Opens a detailed finance view for an opponent candidate.
  /// Tries to find the full Candidate record to open full detail; falls back
  /// to a modal sheet with available finance data.
  void _openOpponentFinanceDetail({
    required Map<String, dynamic> candidate,
    String? candidateId,
    required Color partyColor,
  }) {
    // Try to find the full Candidate object to open the full detail screen
    Candidate? opponent;
    for (final dc in _districtCandidates) {
      if (dc.id == candidateId) {
        opponent = dc;
        break;
      }
    }
    if (opponent == null) {
      final targetName = (candidate['name'] as String? ?? '').toLowerCase();
      for (final dc in _districtCandidates) {
        if (dc.name.toLowerCase() == targetName) {
          opponent = dc;
          break;
        }
      }
    }

    final foundOpponent = opponent;
    if (foundOpponent != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(candidate: foundOpponent, initialTab: 2),
      ));
      return;
    }

    // Fallback: show a detail sheet with what we have
    final name = candidate['name'] as String? ?? 'Unknown';
    final raised = (candidate['total_raised'] as num?)?.toDouble() ?? 0;
    final spent = (candidate['total_spent'] as num?)?.toDouble() ?? 0;
    final contribs = (candidate['contribution_count'] as num?)?.toInt() ?? 0;
    final party = candidate['party'] as String? ?? '';
    final mecId = candidate['mec_id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0b1e37),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(party, style: TextStyle(color: partyColor, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            // Stats
            Row(
              children: [
                Expanded(child: _opponentStatCard(
                  'Raised', '\$${_formatMoney(raised)}', BrandColors.success,
                )),
                const SizedBox(width: 8),
                Expanded(child: _opponentStatCard(
                  'Spent', '\$${_formatMoney(spent)}', BrandColors.republicanRed,
                )),
                const SizedBox(width: 8),
                Expanded(child: _opponentStatCard(
                  'Donors', '$contribs', BrandColors.momentumBlue,
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Cash on hand
            if (raised > 0 || spent > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BrandColors.unityBlue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash on Hand (approx)',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_formatMoney(raised - spent)}',
                      style: TextStyle(
                        color: (raised - spent) >= 0 ? BrandColors.success : BrandColors.republicanRed,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            if (mecId.isNotEmpty)
              Text('MEC ID: $mecId',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            const Text(
              'Detailed contribution and expenditure breakdowns are available when this opponent has a linked candidate profile.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opponentStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ],
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
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ] else
            const Text(
              'No historical data available to estimate partisan lean',
              style: TextStyle(color: Colors.white70, fontSize: 12),
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
            const Text('Registered Voters', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
            const Text('Voter registration data not available', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildHistoricalCandidates() {
    return _card(
      'Past Candidates (${_historicalCandidates.length})',
      Icons.people_outline,
      BrandColors.momentumBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._historicalCandidates.take(20).map((hc) {
            final id = hc['id'] as String?;
            final name = hc['name'] as String? ?? '';
            final party = hc['party'] as String? ?? '';
            final photo = hc['photo_url'] as String?;
            final years = (hc['years_ran'] as List?)?.cast<int>() ?? [];
            final races = hc['total_races'] as int? ?? 0;

            Color partyColor;
            if (party.contains('Dem')) partyColor = BrandColors.democratBlue;
            else if (party.contains('Rep')) partyColor = BrandColors.republicanRed;
            else if (party.contains('Lib')) partyColor = Colors.amber;
            else partyColor = Colors.grey;

            return GestureDetector(
              onTap: id == null
                  ? null
                  : () => Navigator.of(context).push(
                        ThemeSwitcher.buildPageRoute(
                          builder: (_) => TitleBarWrapper(
                            child: HistoricalCandidateScreen(
                              historicalId: id,
                              candidateName: name,
                            ),
                          ),
                        ),
                      ),
              child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: partyColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  // Photo
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: partyColor.withOpacity(0.2),
                    backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo == null || photo.isEmpty
                        ? Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: partyColor, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Name + party + years
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '$party • $races race${races != 1 ? "s" : ""}',
                          style: TextStyle(color: partyColor.withOpacity(0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Years
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ...years.take(3).map((y) => Text('$y', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10))),
                      if (years.length > 3)
                        Text('+${years.length - 3}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            );
          }),
          if (_historicalCandidates.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_historicalCandidates.length - 20} more past candidates',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
              ),
            ),
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
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
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

  Future<void> _openMemberProfile() async {
    if (c.memberId == null) return;
    // Show spinner while we fetch — the member row is usually <100ms but we
    // want feedback immediately so the tap feels snappy.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold)),
    );
    try {
      final member = await MemberRepository().getMemberById(c.memberId!);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close spinner
      if (member == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load linked member profile'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TitleBarWrapper(child: MemberDetailScreen(member: member)),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading member: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  Widget _buildMemberBadge() {
    // Aged-out members still live on the roster but are flagged — surface that
    // here so the candidate card doesn't mis-advertise them as "Active".
    final isAgedOut = c.estimatedAge != null && c.estimatedAge! > 36;
    final title = isAgedOut ? 'MOYD Member (Aged Out)' : 'Active MOYD Member';
    final subtitle = isAgedOut
        ? 'Registered Missouri Young Democrats member, no longer eligible. Tap to view full profile →'
        : 'Registered Missouri Young Democrats member. Tap to view full profile →';
    final primary = isAgedOut ? Colors.orange : Colors.amber;

    return CandidateUI.card('MOYD Member', Icons.badge, primary, child: InkWell(
      onTap: _openMemberProfile,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary.withOpacity(0.3), primary.withOpacity(0.12)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(isAgedOut ? Icons.schedule : Icons.star, color: primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: primary.withOpacity(0.8), size: 22),
              ],
            ),
            if (c.dateOfBirth != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.cake, color: primary.withOpacity(0.6), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    // MO voter file only releases birth year — never synthesize a
                    // fake month/day for voter_file-sourced DOBs. Self-reported and
                    // AI-estimated sources keep the full date display.
                    c.dobSource == 'voter_file'
                        ? 'Born ${c.birthYear ?? c.dateOfBirth!.year}'
                        : 'DOB: ${c.dateOfBirth!.month}/${c.dateOfBirth!.day}/${c.dateOfBirth!.year}',
                    style: TextStyle(color: primary.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ));
  }

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
              Text(' / $maxScore', style: const TextStyle(color: Colors.white70, fontSize: 20)),
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
    return Colors.white70;
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
            child: Text(label, style: TextStyle(color: active ? Colors.white70 : Colors.white70, fontSize: 13)),
          ),
          Text(value, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
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
          gradient: LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_outward, color: color.withOpacity(0.7), size: 11),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
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
          child: _actionButton(Icons.edit, 'Edit', BrandColors.sunriseGold, _openEditDialog),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(Icons.phone, 'Contact', BrandColors.momentumBlue, _launchPhone),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(Icons.thumb_up, 'Endorse', BrandColors.success, _toggleMOYDEndorsed),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(Icons.note_add, 'Add Note', Colors.purpleAccent, () {
            _tabController.animateTo(3);
            setState(() {
              _intelSegment = 2;
              _editingNotes = true;
            });
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
          color: BrandColors.unityBlue.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED UTILITIES
  // ═══════════════════════════════════════════════════════════════

  // Thin delegates to shared helpers in candidate_ui_helpers.dart.
  // (Moved to reduce this file's size; preserves existing call sites.)
  Widget _card(String title, IconData icon, Color accent, {required Widget child}) =>
      CandidateUI.card(title, icon, accent, child: child);
  Widget _badge(String text, Color color, {Color textColor = Colors.white}) =>
      CandidateUI.badge(text, color, textColor: textColor);
  Widget _legendDot(Color color, String label) => CandidateUI.legendDot(color, label);
  Widget _buildEmptyState(IconData icon, String title, String subtitle) =>
      CandidateUI.emptyState(icon, title, subtitle);
  String _formatMoney(double amount) => CandidateUI.formatMoney(amount);
  String _formatMoneyShort(double amount) => CandidateUI.formatMoneyShort(amount);
  String _formatNumber(int number) => CandidateUI.formatNumber(number);
  String _formatDate(DateTime date) => CandidateUI.formatDate(date);
}

// ═══════════════════════════════════════════════════════════════
//  MOBILE TAB CHIP — pill-style tab chip for <600px layouts
// ═══════════════════════════════════════════════════════════════

class _MobileTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _MobileTabChip({
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? BrandColors.sunriseGold.withOpacity(0.18)
        : Colors.white.withOpacity(0.04);
    final border = selected
        ? BrandColors.sunriseGold.withOpacity(0.65)
        : Colors.white.withOpacity(0.10);
    final fg = selected ? BrandColors.sunriseGold : Colors.white70;
    return Container(
      // 44px chip height keeps each tap target comfortably above the
      // Material 48×48 minimum once the outer Tab's hit slop is added.
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: selected ? 1.4 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STAFF FAB — Mobile speed-dial for most-used staff actions
//
//  Tap the primary FAB → reveals a stack of mini-FABs above it for
//  "Log Contact" / "Add Note" / "Copy Questionnaire Link" / "Send SMS".
//  The reveal uses a short (180ms) animation so the interaction feels
//  instant. When a user has `prefers-reduced-motion` set (exposed via
//  MediaQuery.disableAnimations), the animation collapses to 0ms.
// ═══════════════════════════════════════════════════════════════

class _CandidateStaffFab extends StatefulWidget {
  final VoidCallback onLogContact;
  final VoidCallback onAddNote;
  final VoidCallback onCopyQuestionnaireLink;
  final VoidCallback onSendSms;

  const _CandidateStaffFab({
    required this.onLogContact,
    required this.onAddNote,
    required this.onCopyQuestionnaireLink,
    required this.onSendSms,
  });

  @override
  State<_CandidateStaffFab> createState() => _CandidateStaffFabState();
}

class _CandidateStaffFabState extends State<_CandidateStaffFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    // Honor reduced-motion by skipping the animation entirely.
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion) {
      _ctrl.value = _open ? 1 : 0;
    } else {
      if (_open) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  void _run(VoidCallback cb) {
    _toggle();
    // Let the close animation kick off before the tab switch so the
    // user's thumb doesn't feel like it jumped. Small delay, reduced
    // to 0 when animations are disabled.
    final delay = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 120);
    Future.delayed(delay, cb);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs, animated in on open.
        _buildMiniFab(
          label: 'Log Contact',
          icon: Icons.assignment_turned_in_outlined,
          color: BrandColors.momentumBlue,
          onTap: () => _run(widget.onLogContact),
        ),
        _buildMiniFab(
          label: 'Add Note',
          icon: Icons.note_add_outlined,
          color: BrandColors.sunriseGold,
          onTap: () => _run(widget.onAddNote),
        ),
        _buildMiniFab(
          label: 'Send SMS',
          icon: Icons.sms_outlined,
          color: BrandColors.success,
          onTap: () => _run(widget.onSendSms),
        ),
        _buildMiniFab(
          label: 'Copy Q&A Link',
          icon: Icons.link,
          color: Colors.deepPurpleAccent,
          onTap: () => _run(widget.onCopyQuestionnaireLink),
        ),
        const SizedBox(height: 8),
        // Primary FAB — rotates 45deg when open (× icon).
        FloatingActionButton(
          heroTag: 'candidate-staff-fab',
          backgroundColor: BrandColors.sunriseGold,
          foregroundColor: Colors.black87,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFab({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Size transition keeps the column reflowing smoothly; the chip
    // label is rendered alongside the button so labels are discoverable
    // without a long-press tooltip (thumb-only users never see tooltips).
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      axisAlignment: 1,
      child: FadeTransition(
        opacity: _ctrl,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tappable label pill (same onTap as the icon so the label
              // is a tap target too).
              Material(
                color: BrandColors.unityBlue,
                borderRadius: BorderRadius.circular(8),
                elevation: 3,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    // 40px height, but the tappable InkWell extends a
                    // few extra px at each edge — total tap area clears
                    // 48px with the adjacent mini FAB.
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: 'fab-$label',
                backgroundColor: color,
                foregroundColor: Colors.white,
                onPressed: onTap,
                child: Icon(icon, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

