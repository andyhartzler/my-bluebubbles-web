import 'package:flutter/foundation.dart';
import '../services/openstates_service.dart';
import '../services/legislation_service.dart';

/// Provider for bill search functionality
class BillSearchProvider extends ChangeNotifier {
  final OpenStatesService _openStatesService = OpenStatesService();
  final LegislationService _legislationService = LegislationService();

  // State
  List<OpenStatesBillSummary> _searchResults = [];
  Pagination? _pagination;
  bool _isSearching = false;
  String? _error;

  // Current search params
  String _query = '';
  String _session = '2026';
  String? _chamber;
  String? _classification;
  String? _subject;

  // Tracked bill IDs (to show which are already tracked)
  Set<String> _trackedBillIds = {};

  // Getters
  List<OpenStatesBillSummary> get searchResults => _searchResults;
  Pagination? get pagination => _pagination;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String get query => _query;
  String get session => _session;
  String? get chamber => _chamber;
  String? get classification => _classification;
  String? get subject => _subject;
  Set<String> get trackedBillIds => _trackedBillIds;

  bool get hasResults => _searchResults.isNotEmpty;
  bool get hasMore => _pagination?.hasMore ?? false;

  bool isBillTracked(String openstatesId) => _trackedBillIds.contains(openstatesId);

  // Initialize (load tracked bill IDs)
  Future<void> initialize() async {
    try {
      final trackedBills = await _legislationService.getTrackedBills();
      _trackedBillIds = trackedBills.map((b) => b.openstatesBillId).toSet();
      notifyListeners();
    } catch (e) {
      // Ignore errors - just means we can't show tracked status
    }
  }

  // Search bills
  Future<void> searchBills({
    required String query,
    String? session,
    String? chamber,
    String? classification,
    String? subject,
    int page = 1,
  }) async {
    _query = query;
    if (session != null) _session = session;
    _chamber = chamber;
    _classification = classification;
    _subject = subject;

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _openStatesService.searchBills(
        query: query.isNotEmpty ? query : null,
        session: _session,
        chamber: chamber,
        classification: classification,
        subject: subject,
        page: page,
      );

      if (page == 1) {
        _searchResults = result.results;
      } else {
        _searchResults = [..._searchResults, ...result.results];
      }
      _pagination = result.pagination;
    } catch (e) {
      _error = e.toString();
      if (page == 1) {
        _searchResults = [];
      }
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // Quick search (just query)
  Future<void> quickSearch(String query) async {
    await searchBills(query: query);
  }

  // Search with all filters
  Future<void> searchWithFilters({
    String? query,
    String? session,
    String? chamber,
    String? classification,
    String? subject,
  }) async {
    await searchBills(
      query: query ?? _query,
      session: session,
      chamber: chamber,
      classification: classification,
      subject: subject,
    );
  }

  // Load next page
  Future<void> loadNextPage() async {
    if (_pagination == null || _pagination!.page >= _pagination!.maxPage) return;
    if (_isSearching) return;

    await searchBills(
      query: _query,
      session: _session,
      chamber: _chamber,
      classification: _classification,
      subject: _subject,
      page: _pagination!.page + 1,
    );
  }

  // Clear search
  void clearSearch() {
    _searchResults = [];
    _pagination = null;
    _query = '';
    _error = null;
    notifyListeners();
  }

  // Reset filters
  void resetFilters() {
    _chamber = null;
    _classification = null;
    _subject = null;
    notifyListeners();
  }

  // Set session
  void setSession(String session) {
    _session = session;
    notifyListeners();
  }

  // Set chamber filter
  void setChamber(String? chamber) {
    _chamber = chamber;
    notifyListeners();
  }

  // Set classification filter
  void setClassification(String? classification) {
    _classification = classification;
    notifyListeners();
  }

  // Set subject filter
  void setSubject(String? subject) {
    _subject = subject;
    notifyListeners();
  }

  // Set tracked bill IDs (batch operation for initialization)
  void setTrackedBillIds(Set<String> ids) {
    _trackedBillIds = ids;
    notifyListeners();
  }

  // Refresh tracked IDs after tracking a bill
  void addTrackedBillId(String openstatesId) {
    _trackedBillIds.add(openstatesId);
    notifyListeners();
  }

  // Remove tracked bill ID
  void removeTrackedBillId(String openstatesId) {
    _trackedBillIds.remove(openstatesId);
    notifyListeners();
  }

  // Refresh tracked bill IDs
  Future<void> refreshTrackedBillIds() async {
    try {
      final trackedBills = await _legislationService.getTrackedBills();
      _trackedBillIds = trackedBills.map((b) => b.openstatesBillId).toSet();
      notifyListeners();
    } catch (e) {
      // Ignore errors
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
