import 'package:flutter/foundation.dart';
import '../models/tracked_bill.dart';
import '../models/bill_action.dart';
import '../models/bill_vote.dart';
import '../models/bill_sponsor.dart';
import '../models/bill_note.dart';
import '../models/bill_document.dart';
import '../models/legislation_category.dart';
import '../services/legislation_service.dart';
import '../services/openstates_service.dart';
import '../services/ai_analysis_service.dart';

/// Main provider for legislation tracker state management
class LegislationProvider extends ChangeNotifier {
  final LegislationService _service = LegislationService();
  final OpenStatesService _openStatesService = OpenStatesService();
  final AiAnalysisService _aiService = AiAnalysisService();

  // State
  List<TrackedBill> _trackedBills = [];
  List<TrackedBill> _allTrackedBills = []; // Unfiltered list for position tabs
  List<LegislationCategory> _categories = [];
  LegislationStats _stats = LegislationStats.empty();
  TrackedBill? _selectedBill;
  List<BillAction> _selectedBillActions = [];
  List<BillVote> _selectedBillVotes = [];
  List<BillSponsor> _selectedBillSponsors = [];
  List<BillNote> _selectedBillNotes = [];
  List<BillDocument> _selectedBillDocuments = [];

  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isAnalyzingAi = false;
  String? _error;

  // AI Analysis state
  int _unanalyzedBillCount = 0;
  int _analyzedBillCount = 0;

  // Filters
  String _sessionFilter = '2026';
  String? _positionFilter;
  String? _priorityFilter;
  String? _categoryFilter;
  String? _sponsorFilter;
  String _searchQuery = '';
  bool _showArchived = false;
  bool _searchBillText = false;

  // Getters
  List<TrackedBill> get trackedBills => _trackedBills;
  List<LegislationCategory> get categories => _categories;
  LegislationStats get stats => _stats;
  TrackedBill? get selectedBill => _selectedBill;
  List<BillAction> get selectedBillActions => _selectedBillActions;
  List<BillVote> get selectedBillVotes => _selectedBillVotes;
  List<BillSponsor> get selectedBillSponsors => _selectedBillSponsors;
  List<BillNote> get selectedBillNotes => _selectedBillNotes;
  List<BillDocument> get selectedBillDocuments => _selectedBillDocuments;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isAnalyzingAi => _isAnalyzingAi;
  String? get error => _error;
  int get unanalyzedBillCount => _unanalyzedBillCount;
  int get analyzedBillCount => _analyzedBillCount;
  String get sessionFilter => _sessionFilter;
  String? get positionFilter => _positionFilter;
  String? get priorityFilter => _priorityFilter;
  String? get categoryFilter => _categoryFilter;
  String? get sponsorFilter => _sponsorFilter;
  String get searchQuery => _searchQuery;
  bool get showArchived => _showArchived;
  bool get searchBillText => _searchBillText;

  /// Get unique sponsors from tracked bills for filter dropdown
  List<String> get uniqueSponsors {
    final sponsors = <String>{};
    for (final bill in _trackedBills) {
      if (bill.primarySponsorName != null && bill.primarySponsorName!.isNotEmpty) {
        sponsors.add(bill.primarySponsorName!);
      }
    }
    final list = sponsors.toList();
    list.sort();
    return list;
  }

  // Filtered bills by position (use unfiltered list for accurate tab counts)
  List<TrackedBill> get supportedBills =>
      _allTrackedBills.where((b) => b.position == 'support').toList();
  List<TrackedBill> get opposedBills =>
      _allTrackedBills.where((b) => b.position == 'oppose').toList();
  List<TrackedBill> get watchingBills =>
      _allTrackedBills.where((b) => b.position == 'watching').toList();
  List<TrackedBill> get neutralBills =>
      _allTrackedBills.where((b) => b.position == 'neutral').toList();

  // Filtered bills by priority
  List<TrackedBill> get criticalBills =>
      _trackedBills.where((b) => b.priority == 'critical').toList();
  List<TrackedBill> get highPriorityBills =>
      _trackedBills.where((b) => b.priority == 'high').toList();

  // Bills with recent activity
  List<TrackedBill> get recentlyActiveBills {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _trackedBills
        .where((b) => b.latestActionDate?.isAfter(cutoff) ?? false)
        .toList();
  }

  // Bills requiring attention (critical priority + recent activity)
  List<TrackedBill> get billsRequiringAttention {
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    return _trackedBills.where((b) {
      if (b.priority == 'critical') return true;
      if (b.priority == 'high' && (b.latestActionDate?.isAfter(cutoff) ?? false)) return true;
      return false;
    }).toList();
  }

  // Initialize
  Future<void> initialize() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadCategories(),
        loadTrackedBills(),
        loadStats(),
        loadAiAnalysisCounts(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load categories
  Future<void> loadCategories() async {
    try {
      _categories = await _service.getCategories();
    } catch (e) {
      // Use default categories if database fetch fails
      _categories = LegislationCategories.defaultCategories
          .map((c) => LegislationCategory(
                id: c.id,
                name: c.name,
                displayName: c.displayName,
                description: c.description,
                color: c.color,
                icon: c.icon,
                sortOrder: c.sortOrder,
              ))
          .toList();
    }
    notifyListeners();
  }

  // Load tracked bills
  Future<void> loadTrackedBills() async {
    try {
      // Load filtered bills for display
      _trackedBills = await _service.getTrackedBills(
        session: _sessionFilter,
        position: _positionFilter,
        priority: _priorityFilter,
        category: _categoryFilter,
        sponsor: _sponsorFilter,
        includeArchived: _showArchived,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        searchBillText: _searchBillText,
      );

      // Also load unfiltered list for position tabs (only filter by session)
      _allTrackedBills = await _service.getTrackedBills(
        session: _sessionFilter,
        includeArchived: _showArchived,
      );
    } catch (e) {
      _error = 'Failed to load bills: $e';
      _trackedBills = [];
      _allTrackedBills = [];
    }
    notifyListeners();
  }

  // Load statistics
  Future<void> loadStats() async {
    try {
      _stats = await _service.getStatistics(session: _sessionFilter);
    } catch (e) {
      _stats = LegislationStats.empty();
    }
    notifyListeners();
  }

  // Set filters
  void setSessionFilter(String session) {
    _sessionFilter = session;
    loadTrackedBills();
    loadStats();
  }

  void setPositionFilter(String? position) {
    _positionFilter = position;
    loadTrackedBills();
  }

  void setPriorityFilter(String? priority) {
    _priorityFilter = priority;
    loadTrackedBills();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    loadTrackedBills();
  }

  void setSponsorFilter(String? sponsor) {
    _sponsorFilter = sponsor;
    loadTrackedBills();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadTrackedBills();
  }

  void setSearchBillText(bool search) {
    _searchBillText = search;
    if (_searchQuery.isNotEmpty) {
      loadTrackedBills();
    }
  }

  void setShowArchived(bool show) {
    _showArchived = show;
    loadTrackedBills();
  }

  void clearFilters() {
    _positionFilter = null;
    _priorityFilter = null;
    _categoryFilter = null;
    _sponsorFilter = null;
    _searchQuery = '';
    _showArchived = false;
    _searchBillText = false;
    loadTrackedBills();
  }

  // Select bill and load details
  Future<void> selectBill(String billId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedBill = await _service.getTrackedBill(billId);
      if (_selectedBill != null) {
        await Future.wait([
          _loadBillActions(billId),
          _loadBillVotes(billId),
          _loadBillSponsors(billId),
          _loadBillNotes(billId),
          _loadBillDocuments(billId),
        ]);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadBillActions(String billId) async {
    try {
      _selectedBillActions = await _service.getBillActions(billId);
    } catch (e) {
      _selectedBillActions = [];
    }
  }

  Future<void> _loadBillVotes(String billId) async {
    try {
      _selectedBillVotes = await _service.getBillVotes(billId);
    } catch (e) {
      _selectedBillVotes = [];
    }
  }

  Future<void> _loadBillSponsors(String billId) async {
    try {
      _selectedBillSponsors = await _service.getBillSponsorsWithLegislators(billId);
    } catch (e) {
      _selectedBillSponsors = [];
    }
  }

  Future<void> _loadBillNotes(String billId) async {
    try {
      _selectedBillNotes = await _service.getBillNotes(billId);
    } catch (e) {
      _selectedBillNotes = [];
    }
  }

  Future<void> _loadBillDocuments(String billId) async {
    try {
      _selectedBillDocuments = await _service.getBillDocuments(billId);
    } catch (e) {
      _selectedBillDocuments = [];
    }
  }

  void clearSelectedBill() {
    _selectedBill = null;
    _selectedBillActions = [];
    _selectedBillVotes = [];
    _selectedBillSponsors = [];
    _selectedBillNotes = [];
    _selectedBillDocuments = [];
    notifyListeners();
  }

  // Track a new bill
  Future<TrackedBill> trackBill({
    required OpenStatesBillSummary bill,
    String position = 'watching',
    String priority = 'medium',
    List<String> categories = const [],
    bool autoAnalyze = true,
  }) async {
    final trackedBill = await _service.trackBillFromSummary(
      bill: bill,
      position: position,
      priority: priority,
      categories: categories,
    );

    await loadTrackedBills();
    await loadStats();

    // Trigger AI analysis in the background (don't await)
    if (autoAnalyze) {
      _aiService.analyzeBill(billId: trackedBill.id).then((result) async {
        // Auto-apply category recommendations after analysis
        if (result.success) {
          await _aiService.applyAiRecommendations(
            billId: trackedBill.id,
            applyPosition: false,
            applyPriority: false,
            applyCategories: true,
          );
        }
        loadAiAnalysisCounts();
        loadTrackedBills();
        // Refresh selected bill if it's the one we just tracked
        if (_selectedBill?.id == trackedBill.id) {
          selectBill(trackedBill.id);
        }
      });
    }

    return trackedBill;
  }

  // Update bill position
  Future<void> updatePosition({
    required String billId,
    required String position,
    String? rationale,
  }) async {
    await _service.updatePosition(
      billId: billId,
      position: position,
      rationale: rationale,
    );

    if (_selectedBill?.id == billId) {
      _selectedBill = await _service.getTrackedBill(billId);
    }

    await loadTrackedBills();
    await loadStats();
  }

  // Update bill priority
  Future<void> updatePriority({
    required String billId,
    required String priority,
  }) async {
    await _service.updatePriority(billId: billId, priority: priority);

    if (_selectedBill?.id == billId) {
      _selectedBill = await _service.getTrackedBill(billId);
    }

    await loadTrackedBills();
    await loadStats();
  }

  // Update bill categories
  Future<void> updateCategories({
    required String billId,
    required List<String> categories,
  }) async {
    await _service.updateCategories(billId: billId, categories: categories);

    if (_selectedBill?.id == billId) {
      _selectedBill = await _service.getTrackedBill(billId);
    }

    await loadTrackedBills();
  }

  // Update bill tags
  Future<void> updateTags({
    required String billId,
    required List<String> tags,
  }) async {
    await _service.updateTags(billId: billId, tags: tags);

    if (_selectedBill?.id == billId) {
      _selectedBill = await _service.getTrackedBill(billId);
    }
  }

  // Add note
  Future<void> addNote({
    required String billId,
    required String content,
    String noteType = 'general',
    bool isPinned = false,
  }) async {
    await _service.addNote(
      billId: billId,
      content: content,
      noteType: noteType,
      isPinned: isPinned,
    );

    if (_selectedBill?.id == billId) {
      await _loadBillNotes(billId);
      notifyListeners();
    }
  }

  // Update note
  Future<void> updateNote({
    required String noteId,
    String? content,
    String? noteType,
    bool? isPinned,
  }) async {
    await _service.updateNote(
      noteId: noteId,
      content: content,
      noteType: noteType,
      isPinned: isPinned,
    );

    if (_selectedBill != null) {
      await _loadBillNotes(_selectedBill!.id);
      notifyListeners();
    }
  }

  // Delete note
  Future<void> deleteNote(String noteId) async {
    await _service.deleteNote(noteId);

    if (_selectedBill != null) {
      await _loadBillNotes(_selectedBill!.id);
      notifyListeners();
    }
  }

  // Archive bill
  Future<void> archiveBill({required String billId, String? reason}) async {
    await _service.archiveBill(billId: billId, reason: reason);

    if (_selectedBill?.id == billId) {
      clearSelectedBill();
    }

    await loadTrackedBills();
    await loadStats();
  }

  // Unarchive bill
  Future<void> unarchiveBill(String billId) async {
    await _service.unarchiveBill(billId);
    await loadTrackedBills();
    await loadStats();
  }

  // Delete tracked bill
  Future<void> deleteBill(String billId) async {
    await _service.deleteTrackedBill(billId);

    if (_selectedBill?.id == billId) {
      clearSelectedBill();
    }

    await loadTrackedBills();
    await loadStats();
  }

  // Sync tracked bills
  Future<SyncResult> syncBills({String? billId}) async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _openStatesService.syncTrackedBills(billId: billId);

      // Refresh data after sync
      await loadTrackedBills();
      await loadStats();

      if (_selectedBill != null) {
        await selectBill(_selectedBill!.id);
      }

      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Mark actions as seen
  Future<void> markActionsAsSeen(String billId) async {
    await _service.markActionsAsSeen(billId);
    if (_selectedBill?.id == billId) {
      await _loadBillActions(billId);
      notifyListeners();
    }
  }

  // Mark votes as seen
  Future<void> markVotesAsSeen(String billId) async {
    await _service.markVotesAsSeen(billId);
    if (_selectedBill?.id == billId) {
      await _loadBillVotes(billId);
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================
  // AI Analysis Methods
  // ==========================================

  /// Load AI analysis counts
  Future<void> loadAiAnalysisCounts() async {
    try {
      final results = await Future.wait([
        _aiService.getUnanalyzedBillCount(session: _sessionFilter),
        _aiService.getAnalyzedBillCount(session: _sessionFilter),
      ]);
      _unanalyzedBillCount = results[0];
      _analyzedBillCount = results[1];
      notifyListeners();
    } catch (e) {
      // Silently fail - counts are not critical
    }
  }

  /// Analyze a single bill with AI
  Future<AiAnalysisResult> analyzeBill({
    required String billId,
    bool forceReanalyze = false,
    bool autoApplyCategories = true,
  }) async {
    _isAnalyzingAi = true;
    notifyListeners();

    try {
      final result = await _aiService.analyzeBill(
        billId: billId,
        forceReanalyze: forceReanalyze,
      );

      // Auto-apply AI category recommendations
      if (autoApplyCategories && result.success) {
        await _aiService.applyAiRecommendations(
          billId: billId,
          applyPosition: false,  // Don't auto-apply position - needs user review
          applyPriority: false,  // Don't auto-apply priority - needs user review
          applyCategories: true, // Auto-apply categories
        );
      }

      // Refresh the bill data if it's the selected bill
      if (_selectedBill?.id == billId) {
        await selectBill(billId);
      }

      // Update counts
      await loadAiAnalysisCounts();
      await loadTrackedBills();

      return result;
    } finally {
      _isAnalyzingAi = false;
      notifyListeners();
    }
  }

  /// Analyze multiple bills in batch
  Future<BatchAnalysisResult> analyzeBillsBatch({
    int batchSize = 5,
    bool onlyUnanalyzed = true,
  }) async {
    _isAnalyzingAi = true;
    notifyListeners();

    try {
      final result = await _aiService.analyzeBillsBatch(
        batchSize: batchSize,
        onlyUnanalyzed: onlyUnanalyzed,
        session: _sessionFilter,
      );

      // Refresh bills list
      await loadTrackedBills();
      await loadAiAnalysisCounts();

      return result;
    } finally {
      _isAnalyzingAi = false;
      notifyListeners();
    }
  }

  /// Apply AI recommendations to a bill
  Future<bool> applyAiRecommendations({
    required String billId,
    bool applyPosition = true,
    bool applyPriority = true,
    bool applyCategories = true,
  }) async {
    try {
      final success = await _aiService.applyAiRecommendations(
        billId: billId,
        applyPosition: applyPosition,
        applyPriority: applyPriority,
        applyCategories: applyCategories,
      );

      if (success) {
        // Refresh the bill data
        if (_selectedBill?.id == billId) {
          await selectBill(billId);
        }
        await loadTrackedBills();
        await loadStats();
      }

      return success;
    } catch (e) {
      _error = 'Failed to apply AI recommendations: $e';
      notifyListeners();
      return false;
    }
  }

  /// Apply all AI recommendations to bills in watching status
  Future<int> applyAllAiRecommendations({bool onlyWatching = true}) async {
    try {
      final count = await _aiService.applyAllAiRecommendations(
        session: _sessionFilter,
        onlyWatching: onlyWatching,
      );

      if (count > 0) {
        await loadTrackedBills();
        await loadStats();
      }

      return count;
    } catch (e) {
      _error = 'Failed to apply AI recommendations: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Get bills where AI recommendation differs from current position
  List<TrackedBill> get billsWithDifferentAiRecommendation {
    return _trackedBills.where((b) => b.aiRecommendsDifferentPosition).toList();
  }

  /// Get bills with AI analysis
  List<TrackedBill> get analyzedBills {
    return _trackedBills.where((b) => b.hasAiAnalysis).toList();
  }

  /// Get bills without AI analysis
  List<TrackedBill> get unanalyzedBills {
    return _trackedBills.where((b) => !b.hasAiAnalysis).toList();
  }
}
