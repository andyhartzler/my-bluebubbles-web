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

/// Main provider for legislation tracker state management
class LegislationProvider extends ChangeNotifier {
  final LegislationService _service = LegislationService();
  final OpenStatesService _openStatesService = OpenStatesService();

  // State
  List<TrackedBill> _trackedBills = [];
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
  String? _error;

  // Filters
  String _sessionFilter = '2026';
  String? _positionFilter;
  String? _priorityFilter;
  String? _categoryFilter;
  String _searchQuery = '';
  bool _showArchived = false;

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
  String? get error => _error;
  String get sessionFilter => _sessionFilter;
  String? get positionFilter => _positionFilter;
  String? get priorityFilter => _priorityFilter;
  String? get categoryFilter => _categoryFilter;
  String get searchQuery => _searchQuery;
  bool get showArchived => _showArchived;

  // Filtered bills by position
  List<TrackedBill> get supportedBills =>
      _trackedBills.where((b) => b.position == 'support').toList();
  List<TrackedBill> get opposedBills =>
      _trackedBills.where((b) => b.position == 'oppose').toList();
  List<TrackedBill> get watchingBills =>
      _trackedBills.where((b) => b.position == 'watching').toList();
  List<TrackedBill> get neutralBills =>
      _trackedBills.where((b) => b.position == 'neutral').toList();

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
      _trackedBills = await _service.getTrackedBills(
        session: _sessionFilter,
        position: _positionFilter,
        priority: _priorityFilter,
        category: _categoryFilter,
        includeArchived: _showArchived,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    } catch (e) {
      _error = 'Failed to load bills: $e';
      _trackedBills = [];
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

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadTrackedBills();
  }

  void setShowArchived(bool show) {
    _showArchived = show;
    loadTrackedBills();
  }

  void clearFilters() {
    _positionFilter = null;
    _priorityFilter = null;
    _categoryFilter = null;
    _searchQuery = '';
    _showArchived = false;
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
      _selectedBillSponsors = await _service.getBillSponsors(billId);
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
  }) async {
    final trackedBill = await _service.trackBillFromSummary(
      bill: bill,
      position: position,
      priority: priority,
      categories: categories,
    );

    await loadTrackedBills();
    await loadStats();

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
}
