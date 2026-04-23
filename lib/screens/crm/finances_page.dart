import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'receipt_viewer_stub.dart'
    if (dart.library.html) 'receipt_viewer_web.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  FINANCES PAGE — World-class Campaign Finance Dashboard
//
//  Three tabs:
//   1. Overview   — KPI cards, monthly trend chart, top donors, expense
//                    categories, recent activity feed
//   2. Transactions — searchable, filterable bank transaction list with
//                     MEC inclusion toggles and bulk categorisation
//   3. MEC Reports — visual quarter timeline, validation warnings,
//                    report generation with preview, filed-status tracking
//
//  Data sources: donations, donors, bank_transactions, mec_reports,
//                plaid_connections (all via CRMSupabaseService).
//  Charts: fl_chart (BarChart, PieChart).
// ═══════════════════════════════════════════════════════════════════════════

class FinancesPage extends StatefulWidget {
  const FinancesPage({super.key});

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage>
    with TickerProviderStateMixin {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  late TabController _tabController;
  late AnimationController _pulseController;
  late AnimationController _staggerController;

  // ── Connection state ──
  List<Map<String, dynamic>> _connections = [];
  bool _connectionsLoading = true;

  // ── Transactions state ──
  List<Map<String, dynamic>> _transactions = [];
  bool _transactionsLoading = true;
  bool _syncing = false;

  // ── Transaction filters ──
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;
  final Set<String> _selectedCategories = {};
  static const List<String> _categoryOptions = [
    'Groceries', 'Office Supplies', 'Travel', 'Advertising',
    'Printing', 'Postage', 'Events', 'Consulting', 'Utilities', 'Other',
  ];

  // ── Reports state ──
  List<Map<String, dynamic>> _reports = [];
  bool _reportsLoading = true;
  bool _generating = false;
  String _selectedQuarter = '';

  // ── Past filings archive (scraped from MEC portal) ──
  // Populated from public.mec_historical_filings, distinct from _reports
  // which holds MOYD's own generated quarterly reports from the plaid
  // Edge Function. See migration 005_mec_historical_filings.sql.
  static const String _moydMecId = 'C253556';
  List<Map<String, dynamic>> _pastFilings = [];
  bool _pastFilingsLoading = true;

  // ── Receipts state ──
  List<Map<String, dynamic>> _receipts = [];
  bool _receiptsLoading = true;
  String _receiptFilter = 'all'; // 'all', 'unmatched', 'matched', 'inkind'

  // ── Double-tap guards for mutating handlers ──
  // Per-scope flags so concurrent edits on different rows don't serialize
  // unnecessarily; the guard only blocks re-entry into the same handler.
  bool _togglingInclusion = false;
  bool _updatingMecPurpose = false;
  bool _togglingReportFiled = false;
  bool _updatingReceiptStatus = false;
  bool _matchingReceipt = false;
  bool _savingMerchantStatus = false;

  // ── Donations / donors state ──
  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _donors = [];
  int _donationCount = 0;
  double _donationTotal = 0;

  // ── Computed caches ──
  Map<String, double> _monthlyDonations = {};
  List<Map<String, dynamic>> _topDonors = [];
  Map<String, double> _expenseCategories = {};
  List<Map<String, dynamic>> _recentActivity = [];

  StreamSubscription? _plaidSuccessSub;
  StreamSubscription? _plaidExitSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    _selectedQuarter = '${now.year}-Q$q';

    // Listen for Plaid Link callbacks
    _plaidSuccessSub = PlaidLink.onSuccess.listen(_onPlaidSuccess);
    _plaidExitSub = PlaidLink.onExit.listen(_onPlaidExit);

    _loadAll();
  }

  @override
  void dispose() {
    _plaidSuccessSub?.cancel();
    _plaidExitSub?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    _staggerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  String? _loadError;

  Future<void> _loadAll() async {
    if (!_supabase.isInitialized) {
      if (mounted) setState(() {
        _loadError = 'CRM not initialized. Check Supabase configuration.';
        _connectionsLoading = false;
        _transactionsLoading = false;
        _reportsLoading = false;
        _receiptsLoading = false;
      });
      return;
    }
    await Future.wait([
      _loadConnections(),
      _loadTransactions(),
      _loadReports(),
      _loadDonations(),
      _loadDonors(),
      _loadReceipts(),
      _loadPastFilings(),
    ]);
    _computeDerivedData();
    if (mounted) _staggerController.forward();
  }

  Future<void> _loadConnections() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('plaid_connections')
          .select()
          .eq('status', 'active');
      if (mounted) setState(() {
        _connections = (resp as List).cast<Map<String, dynamic>>();
        _connectionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _connectionsLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('bank_transactions')
          .select()
          .order('date', ascending: false)
          .limit(500);
      if (mounted) setState(() {
        _transactions = (resp as List).cast<Map<String, dynamic>>();
        _transactionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _transactionsLoading = false);
    }
  }

  Future<void> _loadReports() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('mec_reports')
          .select()
          .order('period_start', ascending: false)
          .limit(12);
      if (mounted) setState(() {
        _reports = (resp as List).cast<Map<String, dynamic>>();
        _reportsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _reportsLoading = false);
    }
  }

  Future<void> _loadDonations() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('donations')
          .select('amount, donation_date, donor_id, payment_method, status')
          .eq('status', 'completed')
          .order('donation_date', ascending: false);
      final list = (resp as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() {
        _donations = list;
        _donationCount = list.length;
        _donationTotal = list.fold(
            0.0, (sum, d) => sum + (_asDouble(d['amount'])));
      });
    } catch (_) {}
  }

  Future<void> _loadDonors() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('donors')
          .select('id, name, email, total_donated')
          .order('total_donated', ascending: false)
          .limit(20);
      if (mounted) setState(() {
        _donors = (resp as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  Future<void> _loadReceipts() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('receipts')
          .select()
          .order('email_date', ascending: false)
          .limit(200);
      if (mounted) setState(() {
        _receipts = (resp as List).cast<Map<String, dynamic>>();
        _receiptsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _receiptsLoading = false);
    }
  }

  Future<void> _loadPastFilings() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('mec_historical_filings')
          .select()
          .eq('committee_mec_id', _moydMecId)
          .order('filing_date', ascending: false)
          .limit(50);
      if (mounted) setState(() {
        _pastFilings = (resp as List).cast<Map<String, dynamic>>();
        _pastFilingsLoading = false;
      });
    } catch (_) {
      // Missing table or permission error — fall through to empty state
      if (mounted) setState(() {
        _pastFilings = [];
        _pastFilingsLoading = false;
      });
    }
  }

  void _computeDerivedData() {
    // ── Monthly donations (last 12 months) ──
    final now = DateTime.now();
    _monthlyDonations = {};
    for (int i = 11; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      _monthlyDonations[key] = 0;
    }
    for (final d in _donations) {
      final dateStr = d['donation_date'] as String? ?? '';
      if (dateStr.length >= 7) {
        final key = dateStr.substring(0, 7);
        if (_monthlyDonations.containsKey(key)) {
          _monthlyDonations[key] =
              (_monthlyDonations[key] ?? 0) + (_asDouble(d['amount']));
        }
      }
    }

    // ── Top 5 donors ──
    _topDonors = _donors.take(5).toList();

    // ── Expense categories ──
    _expenseCategories = {};
    for (final t in _transactions) {
      final amount = _asDouble(t['amount']);
      if (amount > 0) {
        final cats = t['category'] as List?;
        final cat = (cats != null && cats.isNotEmpty) ? cats.first.toString() : 'Uncategorized';
        _expenseCategories[cat] = (_expenseCategories[cat] ?? 0) + amount;
      }
    }

    // ── Recent activity (interleaved donations + expenditures, last 10) ──
    _recentActivity = [];
    for (final d in _donations.take(20)) {
      _recentActivity.add({
        'type': 'donation',
        'date': d['donation_date'] ?? '',
        'amount': _asDouble(d['amount']),
        'label': 'Contribution received',
        'method': d['payment_method'] ?? '',
      });
    }
    for (final t in _transactions.take(20)) {
      final amount = _asDouble(t['amount']);
      if (amount > 0) {
        _recentActivity.add({
          'type': 'expense',
          'date': t['date'] ?? '',
          'amount': amount,
          'label': t['merchant_name'] ?? t['name'] ?? 'Expenditure',
          'method': '',
        });
      }
    }
    _recentActivity.sort((a, b) =>
        (b['date'] as String).compareTo(a['date'] as String));
    if (_recentActivity.length > 10) {
      _recentActivity = _recentActivity.sublist(0, 10);
    }

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _syncTransactions() async {
    if (!mounted) return;
    setState(() => _syncing = true);
    try {
      await _supabase.privilegedClient.functions
          .invoke('plaid', body: {'action': 'sync_transactions'});
      await _loadTransactions();
      await _loadConnections();
      _computeDerivedData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transactions synced successfully'),
          backgroundColor: BrandColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _generateReport() async {
    if (!mounted) return;
    setState(() => _generating = true);
    try {
      final resp = await _supabase.privilegedClient.functions.invoke('plaid',
          body: {'action': 'generate_mec_report', 'quarter': _selectedQuarter});
      await _loadReports();
      if (mounted) {
        final data = resp.data is Map ? resp.data as Map<String, dynamic> : (resp.data is String ? jsonDecode(resp.data as String) : <String, dynamic>{});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Report generated: ${data['contributions']?['count'] ?? 0} contributions, '
              '${data['expenditures']?['count'] ?? 0} expenditures'),
          backgroundColor: BrandColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Generation failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _connectBank() async {
    try {
      if (!_supabase.isInitialized) {
        throw Exception('CRM not initialized. Check Supabase configuration.');
      }

      // 1. Get a link_token from the Edge Function
      final resp = await _supabase.privilegedClient.functions.invoke('plaid',
          body: {
            'action': 'create_link_token',
            'redirect_uri': 'https://moyd.app/plaid/callback',
          });

      // Safely parse the response — resp.data can be null, Map, or String
      final dynamic rawData = resp.data;
      Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else if (rawData is String && rawData.isNotEmpty) {
        try {
          data = jsonDecode(rawData) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Invalid response from Plaid function: $rawData');
        }
      } else {
        throw Exception(
            'Plaid function returned empty response. '
            'Check that Edge Function secrets (PLAID_CLIENT_ID, PLAID_SECRET) are set.');
      }

      // Check for error in the response body
      if (data.containsKey('error')) {
        throw Exception(data['error']?.toString() ?? 'Unknown Plaid error');
      }

      final linkToken = data['link_token'] as String?;
      if (linkToken == null || linkToken.isEmpty) {
        throw Exception(
            'No link token returned. '
            'Verify Plaid credentials are configured in Supabase Edge Function secrets.');
      }

      // 2. Create and open Plaid Link with the token
      final configuration = LinkTokenConfiguration(token: linkToken);
      await PlaidLink.create(configuration: configuration);
      PlaidLink.open();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plaid Link opened — complete the bank login'),
          backgroundColor: BrandColors.momentumBlue,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  /// Called when user successfully links their bank account via Plaid.
  Future<void> _onPlaidSuccess(LinkSuccess event) async {
    final publicToken = event.publicToken;
    final institutionId = event.metadata.institution?.id ?? '';
    final institutionName = event.metadata.institution?.name ?? 'UMB Bank';

    try {
      // Exchange the public_token for a permanent access_token via Edge Function
      await _supabase.privilegedClient.functions.invoke('plaid', body: {
        'action': 'exchange_token',
        'public_token': publicToken,
        'institution_id': institutionId,
        'institution_name': institutionName,
      });

      // Immediately sync transactions
      await _syncTransactions();
      await _loadConnections();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$institutionName connected successfully!'),
          backgroundColor: BrandColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Token exchange failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  /// Called when user exits Plaid Link (cancels or error).
  void _onPlaidExit(LinkExit event) {
    if (event.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Plaid Link error: ${event.error?.message ?? "Unknown"}'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Future<void> _toggleMecInclusion(Map<String, dynamic> txn, bool value) async {
    if (_togglingInclusion) return;
    final id = txn['id'];
    if (id == null) return;
    setState(() => _togglingInclusion = true);
    try {
      await _supabase.privilegedClient
          .from('bank_transactions')
          .update({'mec_included': value})
          .eq('id', id);
      if (mounted) setState(() => txn['mec_included'] = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update MEC inclusion: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _togglingInclusion = false);
    }
  }

  Future<void> _updateMecPurpose(Map<String, dynamic> txn, String purpose) async {
    if (_updatingMecPurpose) return;
    final id = txn['id'];
    if (id == null) return;
    setState(() => _updatingMecPurpose = true);
    try {
      await _supabase.privilegedClient
          .from('bank_transactions')
          .update({'mec_purpose': purpose})
          .eq('id', id);
      if (mounted) setState(() => txn['mec_purpose'] = purpose);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update purpose: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _updatingMecPurpose = false);
    }
  }

  Future<void> _toggleReportFiled(Map<String, dynamic> report) async {
    if (_togglingReportFiled) return;
    final id = report['id'];
    if (id == null) return;
    final current = report['status'] as String? ?? 'draft';
    final newStatus = current == 'filed' ? 'ready' : 'filed';
    setState(() => _togglingReportFiled = true);
    try {
      await _supabase.privilegedClient
          .from('mec_reports')
          .update({'status': newStatus})
          .eq('id', id);
      if (mounted) setState(() => report['status'] = newStatus);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update report status: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _togglingReportFiled = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  FILTERED TRANSACTIONS
  // ═══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get _filteredTransactions {
    var list = _transactions;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final name = (t['merchant_name'] as String? ?? t['name'] as String? ?? '').toLowerCase();
        return name.contains(q);
      }).toList();
    }

    if (_dateRange != null) {
      list = list.where((t) {
        final dateStr = t['date'] as String? ?? '';
        try {
          final d = DateTime.parse(dateStr);
          return !d.isBefore(_dateRange!.start) && !d.isAfter(_dateRange!.end);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (_selectedCategories.isNotEmpty) {
      list = list.where((t) {
        final cats = t['category'] as List?;
        if (cats == null || cats.isEmpty) {
          return _selectedCategories.contains('Other');
        }
        return cats.any((c) => _selectedCategories.contains(c.toString()));
      }).toList();
    }

    return list;
  }

  double get _filteredTotal {
    return _filteredTransactions.fold(
        0.0, (sum, t) => sum + (_asDouble(t['amount'])));
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Branded gradient header with integrated TabBar (matches Slack page)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Title row with sync button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, color: BrandColors.sunriseGold, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Finances',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                      ),
                      if (_connections.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _syncing ? Icons.hourglass_top : Icons.sync,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: _syncing ? 'Syncing...' : 'Sync Transactions',
                          onPressed: _syncing ? null : _syncTransactions,
                        ),
                    ],
                  ),
                ),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Transactions'),
                    Tab(icon: Icon(Icons.receipt), text: 'Receipts'),
                    Tab(icon: Icon(Icons.description), text: 'MEC Reports'),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: BrandColors.sunriseGold,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tab content with branded background
        Expanded(
          child: BrandedBackground(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOverviewTab(),
                _buildTransactionsTab(),
                _buildReceiptsTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: OVERVIEW — Full financial dashboard
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_loadError!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () { setState(() => _loadError = null); _loadAll(); },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_connectionsLoading) return CandidateUI.shimmerSkeleton(cardCount: 4);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final isMobile = constraints.maxWidth < 600;
      final hPad = isMobile ? 12.0 : 16.0;
      final gap = isMobile ? 10.0 : 16.0;

      return ListView(
        padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 40),
        children: [
          // Deadline card first on mobile — filing deadline is urgent
          if (isMobile) ...[
            _buildDeadlineCard(),
            SizedBox(height: gap),
          ],

          // Filing readiness banner — at-a-glance health for the current
          // quarter: generated report state + receipt matching progress +
          // unresolved blockers.
          _buildFilingReadinessBanner(),
          SizedBox(height: gap),

          // Bank connection card
          _buildConnectionCard(),
          SizedBox(height: gap),

          // Animated stat cards — 2x2 grid on mobile
          _buildAnimatedStatCards(),
          SizedBox(height: gap + 4),

          // Two-column layout on wide screens
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    _buildMonthlyTrendChart(),
                    SizedBox(height: gap),
                    _buildRecentActivityFeed(),
                  ]),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 2,
                  child: Column(children: [
                    _buildTopDonorsLeaderboard(),
                    SizedBox(height: gap),
                    _buildExpenseCategoriesBreakdown(),
                    SizedBox(height: gap),
                    _buildDeadlineCard(),
                  ]),
                ),
              ],
            )
          else ...[
            _buildMonthlyTrendChart(),
            SizedBox(height: gap),
            _buildTopDonorsLeaderboard(),
            SizedBox(height: gap),
            _buildExpenseCategoriesBreakdown(),
            SizedBox(height: gap),
            _buildRecentActivityFeed(),
            if (!isMobile) ...[
              SizedBox(height: gap),
              _buildDeadlineCard(),
            ],
          ],
        ],
      );
    });
  }

  // ── Animated stat cards with staggered entrance ──

  Widget _buildAnimatedStatCards() {
    final expenses = _transactions
        .where((t) => (_asDouble(t['amount'])) > 0)
        .fold(0.0, (sum, t) => sum + (_asDouble(t['amount'])));

    final balance = _donationTotal - expenses;

    final cards = [
      _StatCardData('Contributions', '\$${CandidateUI.formatMoney(_donationTotal)}',
          '$_donationCount donors', BrandColors.success, Icons.volunteer_activism),
      _StatCardData('Expenditures', '\$${CandidateUI.formatMoney(expenses)}',
          '${_transactions.where((t) => (_asDouble(t['amount'])) > 0).length} transactions',
          BrandColors.republicanRed, Icons.payments),
      _StatCardData('Balance', '\$${CandidateUI.formatMoney(balance.abs())}',
          balance >= 0 ? 'Net positive' : 'Net negative',
          BrandColors.momentumBlue, Icons.account_balance_wallet),
      _StatCardData('MEC Reports', '${_reports.length}',
          '${_reports.where((r) => r['status'] == 'filed').length} filed',
          BrandColors.sunriseGold, Icons.description),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      Widget buildCard(int i) {
        final delay = i * 0.15;
        final progress = ((_staggerController.value - delay) / (1 - delay))
            .clamp(0.0, 1.0);
        final curve = Curves.easeOutBack.transform(progress);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - curve)),
          child: Opacity(
            opacity: progress,
            child: _statCard(
              cards[i].label, cards[i].value, cards[i].subtitle,
              cards[i].color, cards[i].icon,
            ),
          ),
        );
      }

      return AnimatedBuilder(
        animation: _staggerController,
        builder: (context, _) {
          if (isMobile) {
            // 2x2 grid on mobile for readability
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: buildCard(0),
                    )),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 6),
                      child: buildCard(1),
                    )),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(right: 6, top: 6),
                      child: buildCard(2),
                    )),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(left: 6, top: 6),
                      child: buildCard(3),
                    )),
                  ],
                ),
              ],
            );
          }

          // Desktop: 4 in a row
          return Row(
            children: List.generate(cards.length, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < cards.length - 1 ? 10 : 0),
                  child: buildCard(i),
                ),
              );
            }),
          );
        },
      );
    });
  }

  Widget _statCard(String label, String value, String subtitle, Color color,
      IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue.withOpacity(0.95),
            BrandColors.unityBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Monthly giving trend bar chart ──

  Widget _buildMonthlyTrendChart() {
    final entries = _monthlyDonations.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final maxVal = entries.fold(0.0, (m, e) => math.max(m, e.value));
    final topY = maxVal > 0 ? (maxVal * 1.2) : 1000.0;

    return CandidateUI.card(
      'Monthly Giving Trend',
      Icons.bar_chart,
      BrandColors.success,
      child: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: topY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    // tooltipBgColor handled by fl_chart version
                    tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final key = entries[group.x.toInt()].key;
                      return BarTooltipItem(
                        '$key\n\$${CandidateUI.formatMoney(rod.toY)}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${CandidateUI.formatMoneyShort(value)}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = entries[idx].key.split('-');
                        const months = [
                          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                        ];
                        final monthIdx = int.tryParse(parts.last) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            monthIdx > 0 && monthIdx <= 12
                                ? months[monthIdx]
                                : '',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: topY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(entries.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value,
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        gradient: const LinearGradient(
                          colors: [BrandColors.success, Color(0xFF059669)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 600),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CandidateUI.legendDot(BrandColors.success, 'Donations received'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top donors leaderboard ──

  Widget _buildTopDonorsLeaderboard() {
    return CandidateUI.card(
      'Top Donors',
      Icons.emoji_events,
      BrandColors.sunriseGold,
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (_topDonors.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No donor data yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13)),
            )
          else
            ...List.generate(_topDonors.length, (i) {
              final donor = _topDonors[i];
              final name = donor['name'] as String? ?? 'Anonymous';
              final total =
                  _asDouble(donor['total_donated']);
              final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

              final medalColors = [
                BrandColors.sunriseGold,
                Colors.grey.shade400,
                const Color(0xFFCD7F32),
                BrandColors.momentumBlue,
                BrandColors.steelBlue,
              ];
              final color = medalColors[i.clamp(0, 4)];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(i == 0 ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: color.withOpacity(i == 0 ? 0.3 : 0.1)),
                ),
                child: Row(
                  children: [
                    // Rank
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: i < 3
                            ? Icon(Icons.emoji_events,
                                color: color, size: 16)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.3),
                            color.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(initials,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('\$${CandidateUI.formatMoney(total)}',
                        style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Expense categories breakdown (horizontal bars) ──

  Widget _buildExpenseCategoriesBreakdown() {
    final sorted = _expenseCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxVal = top.isNotEmpty ? top.first.value : 1.0;

    final barColors = [
      BrandColors.republicanRed,
      BrandColors.momentumBlue,
      BrandColors.sunriseGold,
      BrandColors.steelBlue,
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];

    return CandidateUI.card(
      'Expense Categories',
      Icons.pie_chart,
      BrandColors.republicanRed,
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No expense data yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13)),
            )
          else
            ...List.generate(top.length, (i) {
              final entry = top[i];
              final fraction = entry.value / maxVal;
              final color = barColors[i % barColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(entry.key,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('\$${CandidateUI.formatMoney(entry.value)}',
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation(color),
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

  // ── Recent activity feed ──

  Widget _buildRecentActivityFeed() {
    return CandidateUI.card(
      'Recent Activity',
      Icons.timeline,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 10),
          if (_recentActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No activity yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13)),
            )
          else
            ...List.generate(_recentActivity.length, (i) {
              final item = _recentActivity[i];
              final isDonation = item['type'] == 'donation';
              final color =
                  isDonation ? BrandColors.success : BrandColors.republicanRed;
              final amount = _asDouble(item['amount']);
              final label = item['label'] as String? ?? '';
              final date = item['date'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BrandColors.unityBlue.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.4), blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(date,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    Text(
                      '${isDonation ? '+' : '-'}\$${CandidateUI.formatMoney(amount)}',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Connection card (from original) ──

  Widget _buildConnectionCard() {
    final connected = _connections.isNotEmpty;
    final conn = connected ? _connections.first : null;
    final statusColor = connected ? BrandColors.success : Colors.orange;

    return BrandedCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      gradientColors: [
        statusColor.withOpacity(0.2),
        BrandColors.unityBlue.withOpacity(0.9),
      ],
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor
                      .withOpacity(0.5 + _pulseController.value * 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: _pulseController.value * 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Bank Connected' : 'No Bank Connected',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (connected && conn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${conn['institution_name'] ?? 'UMB Bank'} • '
                    '${(conn['account_names'] as List?)?.join(', ') ?? 'Account'}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 12),
                  ),
                  if (conn['last_synced_at'] != null)
                    Text(
                      'Last synced: ${_formatDate(conn['last_synced_at'])}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 11),
                    ),
                ],
              ],
            ),
          ),
          if (!connected)
            _actionButton(
              icon: Icons.add_card,
              label: 'Connect Bank',
              color: BrandColors.sunriseGold,
              onTap: _connectBank,
            ),
        ],
      ),
    );
  }

  // ── Filing readiness banner ──

  Widget _buildFilingReadinessBanner() {
    // Snapshot the health of the CURRENT quarter: do we have a generated
    // mec_reports row? Are all receipts reviewed? Are there bank
    // transactions that should be flagged for MEC but aren't?
    final now = DateTime.now();
    final currentQuarter = '${now.year}-Q${((now.month - 1) ~/ 3) + 1}';

    final generated = _reports.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['quarter'] == currentQuarter,
          orElse: () => null,
        );
    final reportStatus = generated?['status'] as String?;

    final unmatchedReceipts = _receipts.where((r) {
      final s = r['match_status'];
      return s == null || s == '' || s == 'unmatched';
    }).length;

    // Transactions with no mec_purpose / mec_payee_address during the
    // current quarter are still blockers for filing CD3_B.
    final quarterStart = DateTime(now.year, ((((now.month - 1) ~/ 3)) * 3) + 1, 1);
    final txInQuarter = _transactions.where((t) {
      final dateStr = t['date'] as String?;
      if (dateStr == null) return false;
      final d = DateTime.tryParse(dateStr);
      if (d == null) return false;
      return !d.isBefore(quarterStart) && !d.isAfter(now);
    }).toList();
    final unflaggedTx = txInQuarter.where((t) {
      final amt = _asDouble(t['amount']);
      if (amt <= 0) return false; // outflows only (positive = expense)
      final hasPurpose = (t['mec_purpose'] as String?)?.isNotEmpty ?? false;
      return !hasPurpose;
    }).length;

    // Determine the traffic light.
    Color stateColor;
    String stateLabel;
    IconData stateIcon;
    String headline;

    if (reportStatus == 'filed') {
      stateColor = BrandColors.success;
      stateLabel = 'FILED';
      stateIcon = Icons.check_circle;
      headline = '$currentQuarter filed and accepted.';
    } else if (reportStatus == 'ready') {
      stateColor = BrandColors.momentumBlue;
      stateLabel = 'READY';
      stateIcon = Icons.check_circle_outline;
      headline = '$currentQuarter report generated — ready to submit to MEC.';
    } else if (unmatchedReceipts > 0 || unflaggedTx > 0) {
      stateColor = Colors.orange;
      stateLabel = 'NEEDS REVIEW';
      stateIcon = Icons.warning_amber_rounded;
      final parts = <String>[];
      if (unmatchedReceipts > 0) {
        parts.add('$unmatchedReceipts unmatched receipt${unmatchedReceipts == 1 ? '' : 's'}');
      }
      if (unflaggedTx > 0) {
        parts.add('$unflaggedTx transaction${unflaggedTx == 1 ? '' : 's'} without MEC purpose');
      }
      headline = '${parts.join(', ')} before $currentQuarter is filable.';
    } else if (txInQuarter.isEmpty && _receipts.isEmpty) {
      stateColor = Colors.white54;
      stateLabel = 'EMPTY';
      stateIcon = Icons.schedule;
      headline = 'No data for $currentQuarter yet.';
    } else {
      stateColor = BrandColors.momentumBlue;
      stateLabel = 'CLEAN';
      stateIcon = Icons.insights;
      headline = '$currentQuarter: all receipts matched, all transactions categorized.';
    }

    return BrandedCard(
      padding: const EdgeInsets.all(14),
      gradientColors: [
        stateColor.withOpacity(0.18),
        BrandColors.unityBlue,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stateIcon, color: stateColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filing Readiness',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: stateColor.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: stateColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            stateLabel,
                            style: TextStyle(
                              color: stateColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick-jump action row — each tile jumps to the relevant tab.
          Row(
            children: [
              Expanded(
                child: _readinessMetric(
                  icon: Icons.receipt_long,
                  label: 'Q Transactions',
                  value: '${txInQuarter.length}',
                  badge: unflaggedTx > 0 ? '$unflaggedTx ✗' : null,
                  badgeColor: unflaggedTx > 0 ? Colors.orange : null,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _readinessMetric(
                  icon: Icons.receipt,
                  label: 'Receipts',
                  value: '${_receipts.length}',
                  badge: unmatchedReceipts > 0 ? '$unmatchedReceipts ✗' : null,
                  badgeColor:
                      unmatchedReceipts > 0 ? Colors.orange : null,
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _readinessMetric(
                  icon: Icons.description,
                  label: 'MEC Report',
                  value: reportStatus == null
                      ? '—'
                      : reportStatus.toUpperCase(),
                  badge: null,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readinessMetric({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? Colors.orange).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor ?? Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Deadline card ──

  Widget _buildDeadlineCard() {
    final now = DateTime.now();
    // Show the NEXT upcoming MEC filing deadline
    // Q1 (Jan-Mar) due Apr 15, Q2 (Apr-Jun) due Jul 15,
    // Q3 (Jul-Sep) due Oct 15, Q4 (Oct-Dec) due Jan 15 next year
    final deadlines = [
      (q: 1, date: DateTime(now.year, 4, 15)),
      (q: 2, date: DateTime(now.year, 7, 15)),
      (q: 3, date: DateTime(now.year, 10, 15)),
      (q: 4, date: DateTime(now.year + 1, 1, 15)),
    ];
    final next = deadlines.firstWhere(
      (d) => d.date.isAfter(now),
      orElse: () => (q: 1, date: DateTime(now.year + 1, 4, 15)),
    );
    final q = next.q;
    final deadline = next.date;
    final daysLeft = deadline.difference(now).inDays;

    final urgency = daysLeft < 7
        ? Colors.red
        : daysLeft < 30
            ? Colors.orange
            : BrandColors.momentumBlue;

    return BrandedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      gradientColors: [
        urgency.withOpacity(0.25),
        BrandColors.unityBlue,
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: urgency.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_today, color: urgency, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next MEC Filing Deadline',
                    style: TextStyle(
                        color: urgency,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${now.year}-Q$q Report • Due ${deadline.month}/${deadline.day}/${deadline.year}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: urgency.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$daysLeft days',
                style: TextStyle(
                    color: urgency,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: TRANSACTIONS — Searchable, filterable transaction list
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTransactionsTab() {
    if (_transactionsLoading) return CandidateUI.shimmerSkeleton(cardCount: 6);

    if (_transactions.isEmpty) {
      return CandidateUI.emptyState(
        Icons.receipt_long,
        'No Transactions',
        _connections.isEmpty
            ? 'Connect your bank account to see transactions.'
            : 'Sync your bank to pull recent transactions.',
      );
    }

    final filtered = _filteredTransactions;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final hPad = isMobile ? 8.0 : 12.0;

      // Filter state awareness — tell the operator what they're looking at
      // vs the whole set, so "total" row is never misleading.
      final hasFilter = _searchQuery.isNotEmpty ||
          _dateRange != null ||
          _selectedCategories.isNotEmpty;

      return Column(
        children: [
          // Search bar
          _buildTransactionSearchBar(),

          // Compact filter-state indicator
          if (hasFilter)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad + 6, 0, hPad + 6, 2),
              child: Row(
                children: [
                  Icon(Icons.filter_alt,
                      size: 12, color: BrandColors.sunriseGold),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Showing ${filtered.length} of ${_transactions.length} transactions',
                      style: TextStyle(
                          color: BrandColors.sunriseGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _searchQuery = '';
                      _searchCtrl.clear();
                      _dateRange = null;
                      _selectedCategories.clear();
                    }),
                    child: Text(
                      'Clear all',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Date range + category filters
          _buildTransactionFilters(),

          // Transaction list
          Expanded(
            child: filtered.isEmpty
                ? CandidateUI.emptyState(
                    Icons.filter_list_off,
                    'No Matches',
                    'No transactions match your current filters.',
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildTransactionRow(filtered[index]),
                  ),
          ),

          // Total row
          _buildTransactionTotalRow(filtered),
        ],
      );
    });
  }

  Widget _buildTransactionSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: BrandColors.unityBlue.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name or merchant...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIcon: Icon(Icons.search,
                color: Colors.white.withOpacity(0.7), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.white.withOpacity(0.7), size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        children: [
          // Date range picker + clear
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange,
                    builder: (context, child) {
                      // Use parent context's theme + only override accent colors,
                      // so ColorScheme fields (error, outline, etc.) aren't left null
                      // and internal range-picker widgets don't crash.
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme:
                              Theme.of(context).colorScheme.copyWith(
                                    primary: BrandColors.momentumBlue,
                                    onPrimary: Colors.white,
                                    surface: const Color(0xFF1E3A5F),
                                  ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) setState(() => _dateRange = range);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _dateRange != null
                        ? BrandColors.momentumBlue.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _dateRange != null
                          ? BrandColors.momentumBlue.withOpacity(0.4)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range,
                          color: _dateRange != null
                              ? BrandColors.momentumBlue
                              : Colors.white70,
                          size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _dateRange != null
                            ? '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}'
                            : 'Date range',
                        style: TextStyle(
                          color: _dateRange != null
                              ? BrandColors.momentumBlue
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dateRange != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _dateRange = null),
                  child: Icon(Icons.close,
                      color: Colors.white.withOpacity(0.7), size: 16),
                ),
              ],
              const Spacer(),
              if (_searchQuery.isNotEmpty ||
                  _dateRange != null ||
                  _selectedCategories.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                    _dateRange = null;
                    _selectedCategories.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BrandColors.republicanRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Clear all',
                        style: TextStyle(
                            color: BrandColors.republicanRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Category chips
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categoryOptions.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      selected
                          ? _selectedCategories.remove(cat)
                          : _selectedCategories.add(cat);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? BrandColors.steelBlue.withOpacity(0.2)
                            : BrandColors.unityBlue.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? BrandColors.steelBlue.withOpacity(0.5)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(cat,
                          style: TextStyle(
                            color: selected
                                ? BrandColors.steelBlue
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
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

  Widget _buildTransactionRow(Map<String, dynamic> t) {
    final amount = _asDouble(t['amount']);
    final isExpense = amount > 0;
    final date = t['date'] as String? ?? '';
    final name =
        t['merchant_name'] as String? ?? t['name'] as String? ?? 'Unknown';
    final category = (t['category'] as List?)?.join(' > ') ?? '';
    final included = t['mec_included'] as bool? ?? true;
    final mecPurpose = t['mec_purpose'] as String? ?? '';

    // Color code by amount size
    Color amountColor;
    FontWeight amountWeight;
    final absAmt = amount.abs();
    if (absAmt >= 500) {
      amountColor = BrandColors.sunriseGold;
      amountWeight = FontWeight.w900;
    } else if (absAmt >= 100) {
      amountColor = isExpense ? BrandColors.republicanRed : BrandColors.success;
      amountWeight = FontWeight.w700;
    } else {
      amountColor = isExpense
          ? BrandColors.republicanRed.withOpacity(0.6)
          : BrandColors.success.withOpacity(0.6);
      amountWeight = FontWeight.w500;
    }

    return GestureDetector(
      onTap: () => _openMerchantDetail(vendor: name, initialTransaction: t),
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(included ? 0.9 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(included ? 0.15 : 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // MEC inclusion checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: included,
              onChanged: _togglingInclusion
                  ? null
                  : (v) => _toggleMecInclusion(t, v ?? true),
              activeColor: BrandColors.success,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          // Direction icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isExpense ? BrandColors.republicanRed : BrandColors.success)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpense ? Icons.arrow_upward : Icons.arrow_downward,
              color:
                  isExpense ? BrandColors.republicanRed : BrandColors.success,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          // Name + category + MEC purpose
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                      color: included
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Flexible(
                      child: Text('$date • $category',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (mecPurpose.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: BrandColors.momentumBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(mecPurpose,
                            style: const TextStyle(
                                color: BrandColors.momentumBlue,
                                fontSize: 8,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // MEC purpose setter (tap to set)
          if (isExpense && included)
            GestureDetector(
              onTap: () => _showMecPurposeDialog(t),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.label_outline,
                    color: Colors.white.withOpacity(0.6), size: 14),
              ),
            ),
          const SizedBox(width: 8),
          // Amount
          Text(
            '${isExpense ? "-" : "+"}\$${CandidateUI.formatMoney(absAmt)}',
            style: TextStyle(
              color: amountColor,
              fontSize: 14,
              fontWeight: amountWeight,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTransactionTotalRow(List<Map<String, dynamic>> filtered) {
    final totalExpense = filtered
        .where((t) => (_asDouble(t['amount'])) > 0)
        .fold(0.0, (sum, t) => sum + (_asDouble(t['amount'])));
    final totalIncome = filtered
        .where((t) => (_asDouble(t['amount'])) < 0)
        .fold(0.0,
            (sum, t) => sum + (_asDouble(t['amount'])).abs());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue,
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          Text('${filtered.length} transactions',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          if (totalIncome > 0) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BrandColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+\$${CandidateUI.formatMoney(totalIncome)}',
                  style: const TextStyle(
                      color: BrandColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BrandColors.republicanRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('-\$${CandidateUI.formatMoney(totalExpense)}',
                style: const TextStyle(
                    color: BrandColors.republicanRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showMecPurposeDialog(Map<String, dynamic> t) {
    final purposes = [
      'Campaign literature/mailings',
      'Media advertising',
      'Fundraising events',
      'Office supplies',
      'Travel/lodging',
      'Consulting/polling',
      'Salary/wages',
      'Phone/internet',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set MEC Purpose',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: purposes.map((p) {
              final current = t['mec_purpose'] as String? ?? '';
              return ListTile(
                dense: true,
                title: Text(p,
                    style: TextStyle(
                      color: current == p
                          ? BrandColors.sunriseGold
                          : Colors.white70,
                      fontSize: 13,
                    )),
                leading: Icon(
                  current == p
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: current == p
                      ? BrandColors.sunriseGold
                      : Colors.white30,
                  size: 18,
                ),
                enabled: !_updatingMecPurpose,
                onTap: _updatingMecPurpose
                    ? null
                    : () {
                        _updateMecPurpose(t, p);
                        Navigator.pop(ctx);
                      },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: RECEIPTS — View, match, and manage receipts
  // ═══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get _filteredReceipts {
    if (_receiptFilter == 'all') return _receipts;
    if (_receiptFilter == 'unmatched') {
      return _receipts.where((r) {
        final s = r['match_status'];
        return s == null || s == '' || s == 'unmatched';
      }).toList();
    }
    return _receipts.where((r) => r['match_status'] == _receiptFilter).toList();
  }

  Widget _receiptStatTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue.withOpacity(0.95),
            BrandColors.unityBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsTab() {
    if (_receiptsLoading) return CandidateUI.shimmerSkeleton(cardCount: 4);

    // Surface any render error in-place so it's debuggable from the UI
    // instead of bubbling up to the generic ErrorWidget "An unexpected
    // error occurred" message that Andrew has been hitting.
    try {
      return _buildReceiptsTabInner();
    } catch (err, stack) {
      debugPrint('❌ Receipts tab render error: $err');
      debugPrint(stack.toString());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 12),
              const Text('Receipts tab error',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildReceiptsTabInner() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final hPad = isMobile ? 10.0 : 14.0;

      // Stat-strip rollups — sum amounts per bucket so the header shows real
      // money, not just row counts. Buckets are aligned with the filter chips.
      double sumAmounts(bool Function(Map<String, dynamic>) pred) {
        return _receipts.where(pred).fold(
            0.0, (sum, r) => sum + (_asDouble(r['amount'])));
      }

      final matchedCount = _receipts.where((r) => r['match_status'] == 'matched').length;
      final matchedSum = sumAmounts((r) => r['match_status'] == 'matched');
      final unmatchedCount = _receipts.where((r) =>
          r['match_status'] == null ||
          r['match_status'] == '' ||
          r['match_status'] == 'unmatched').length;
      final unmatchedSum = sumAmounts((r) =>
          r['match_status'] == null ||
          r['match_status'] == '' ||
          r['match_status'] == 'unmatched');
      final ignoredCount = _receipts.where((r) => r['match_status'] == 'ignored').length;
      final inkindCount = _receipts.where((r) => r['match_status'] == 'inkind').length;
      final totalCount = _receipts.length;

      return Column(
        children: [
          // Stat strip — 3 tiles (Matched $, Unmatched $, Ignored #) above
          // the filter chip row. Gives operators the money picture at a glance.
          if (totalCount > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _receiptStatTile(
                      icon: Icons.link,
                      label: 'Matched',
                      value: '\$${CandidateUI.formatMoney(matchedSum)}',
                      subtitle: '$matchedCount receipts',
                      color: BrandColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _receiptStatTile(
                      icon: Icons.link_off,
                      label: 'Unmatched',
                      value: '\$${CandidateUI.formatMoney(unmatchedSum)}',
                      subtitle: '$unmatchedCount awaiting review',
                      color: unmatchedCount > 0
                          ? BrandColors.sunriseGold
                          : BrandColors.momentumBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _receiptStatTile(
                      icon: Icons.block,
                      label: 'Ignored',
                      value: '$ignoredCount',
                      subtitle: '${((ignoredCount / totalCount) * 100).toStringAsFixed(0)}% of total',
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

          // Filter chips
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...[
                    ('all', 'All', Icons.list, totalCount),
                    ('unmatched', 'Unmatched', Icons.link_off, unmatchedCount),
                    ('matched', 'Matched', Icons.link, matchedCount),
                    ('inkind', 'In-Kind', Icons.volunteer_activism, inkindCount),
                    ('ignored', 'Ignored', Icons.block, ignoredCount),
                  ].map((item) {
                    final (value, label, icon, count) = item;
                    final selected = _receiptFilter == value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _receiptFilter = value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? BrandColors.momentumBlue.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? BrandColors.momentumBlue.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon,
                                  color: selected ? BrandColors.momentumBlue : Colors.white70,
                                  size: 14),
                              const SizedBox(width: 4),
                              Text('$label ($count)',
                                  style: TextStyle(
                                    color: selected ? BrandColors.momentumBlue : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Receipt list
          Expanded(
            child: _filteredReceipts.isEmpty
                ? CandidateUI.emptyState(
                    Icons.receipt,
                    'No Receipts',
                    _receiptFilter == 'all'
                        ? 'Receipts from email will appear here automatically.'
                        : 'No receipts with status "$_receiptFilter".',
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
                    itemCount: _filteredReceipts.length,
                    itemBuilder: (context, index) =>
                        _buildReceiptRow(_filteredReceipts[index]),
                  ),
          ),

          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: BrandColors.unityBlue,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Text(
                  '${_filteredReceipts.length} receipts',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                const Spacer(),
                Text(
                  'Total: \$${CandidateUI.formatMoney(_filteredReceipts.fold(0.0, (sum, r) => sum + (_asDouble(r['amount']))))}',
                  style: const TextStyle(
                      color: BrandColors.sunriseGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildReceiptRow(Map<String, dynamic> r) {
    final amount = _asDouble(r['amount']);
    final vendor = r['vendor_name'] as String? ?? 'Unknown Vendor';
    final category = r['category'] as String? ?? '';
    final emailDate = r['email_date'] as String? ?? '';
    final subject = r['email_subject'] as String? ?? '';
    final matchStatus = r['match_status'] as String? ?? 'unmatched';
    final hasFile = (r['storage_path'] as String?)?.isNotEmpty ?? false;

    Color statusColor;
    IconData statusIcon;
    switch (matchStatus) {
      case 'matched':
        statusColor = BrandColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'inkind':
        statusColor = BrandColors.sunriseGold;
        statusIcon = Icons.volunteer_activism;
        break;
      case 'ignored':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return GestureDetector(
      onTap: () => _openMerchantDetail(
        vendor: vendor,
        initialReceipt: r,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: BrandColors.unityBlue.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 16),
            ),
            const SizedBox(width: 10),
            // Vendor + subject
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      if (emailDate.isNotEmpty)
                        Text('${_formatDate(emailDate)} • ',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7), fontSize: 10)),
                      Flexible(
                        child: Text(category.isNotEmpty ? category : subject,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7), fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // File indicator
            if (hasFile)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.attach_file, color: Colors.white.withOpacity(0.5), size: 14),
              ),
            // Amount
            if (amount > 0)
              Text('\$${CandidateUI.formatMoney(amount)}',
                  style: TextStyle(
                      color: BrandColors.sunriseGold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  /// Opens full-screen merchant detail view showing all receipts + transactions
  void _openMerchantDetail({
    required String vendor,
    Map<String, dynamic>? initialReceipt,
    Map<String, dynamic>? initialTransaction,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MerchantDetailScreen(
        vendor: vendor,
        allReceipts: _receipts,
        allTransactions: _transactions,
        initialReceipt: initialReceipt,
        initialTransaction: initialTransaction,
        onDelete: (receiptId) async {
          if (_savingMerchantStatus) return;
          setState(() => _savingMerchantStatus = true);
          try {
            await _deleteReceipt(receiptId);
            if (mounted) setState(() {
              _receipts.removeWhere((r) => r['id'] == receiptId);
            });
          } finally {
            if (mounted) setState(() => _savingMerchantStatus = false);
          }
        },
        onUpdateStatus: (receiptId, status) async {
          if (_savingMerchantStatus) return;
          setState(() => _savingMerchantStatus = true);
          try {
            await _supabase.privilegedClient
                .from('receipts')
                .update({'match_status': status, 'updated_at': DateTime.now().toIso8601String()})
                .eq('id', receiptId);
            if (mounted) setState(() {
              final r = _receipts.firstWhere((r) => r['id'] == receiptId, orElse: () => {});
              if (r.isNotEmpty) r['match_status'] = status;
            });
          } catch (_) {
          } finally {
            if (mounted) setState(() => _savingMerchantStatus = false);
          }
        },
      ),
    ));
  }

  Future<void> _deleteReceipt(String receiptId) async {
    try {
      await _supabase.privilegedClient.functions
          .invoke('receipts', body: {'action': 'delete', 'receipt_id': receiptId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Receipt deleted'),
          backgroundColor: BrandColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showReceiptDetail(Map<String, dynamic> r) {
    final amount = _asDouble(r['amount']);
    final vendor = r['vendor_name'] as String? ?? 'Unknown';
    final category = r['category'] as String? ?? '';
    final description = r['description'] as String? ?? '';
    final subject = r['email_subject'] as String? ?? '';
    final from = r['email_from'] as String? ?? '';
    final matchStatus = r['match_status'] as String? ?? 'unmatched';
    final storageUrl = r['storage_url'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2E4A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Text(vendor,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (amount > 0)
              Text('\$${CandidateUI.formatMoney(amount)}',
                  style: const TextStyle(
                      color: BrandColors.sunriseGold,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),

            // Details
            _receiptDetailRow('Category', category),
            _receiptDetailRow('Description', description),
            _receiptDetailRow('Subject', subject),
            _receiptDetailRow('From', from),
            _receiptDetailRow('Date', _formatDate(r['email_date'])),
            _receiptDetailRow('Status', matchStatus.toUpperCase()),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.link,
                    label: 'Match',
                    color: BrandColors.success,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMatchDialog(r);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.volunteer_activism,
                    label: 'In-Kind',
                    color: BrandColors.sunriseGold,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _updateReceiptStatus(r, 'inkind');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.block,
                    label: 'Ignore',
                    color: Colors.grey,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _updateReceiptStatus(r, 'ignored');
                    },
                  ),
                ),
              ],
            ),

            if (storageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Receipt Document',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _ReceiptWebView(url: storageUrl),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _receiptDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateReceiptStatus(Map<String, dynamic> r, String status) async {
    if (_updatingReceiptStatus) return;
    final id = r['id'];
    if (id == null) return;
    setState(() => _updatingReceiptStatus = true);
    try {
      await _supabase.privilegedClient
          .from('receipts')
          .update({'match_status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      if (mounted) setState(() => r['match_status'] = status);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _updatingReceiptStatus = false);
    }
  }

  void _showMatchDialog(Map<String, dynamic> receipt) {
    // Show transactions that could match this receipt
    final receiptAmount = _asDouble(receipt['amount']);
    final candidateTxns = _transactions.where((t) {
      final txnAmount = (_asDouble(t['amount'])).abs();
      // Match within 10% or $5
      if (receiptAmount <= 0) return true;
      final diff = (txnAmount - receiptAmount).abs();
      return diff < 5 || diff / receiptAmount < 0.1;
    }).take(10).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Match to Transaction',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (candidateTxns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No matching transactions found',
                      style: TextStyle(color: Colors.white70)),
                )
              else
                ...candidateTxns.map((t) {
                  final name = t['merchant_name'] as String? ?? t['name'] as String? ?? 'Unknown';
                  final amount = (_asDouble(t['amount'])).abs();
                  final date = t['date'] as String? ?? '';
                  return ListTile(
                    dense: true,
                    enabled: !_matchingReceipt,
                    title: Text(name,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text('$date • \$${CandidateUI.formatMoney(amount)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                    trailing: Icon(Icons.link, color: BrandColors.success.withOpacity(0.7), size: 18),
                    onTap: _matchingReceipt
                        ? null
                        : () => _handleMatchReceiptToTxn(ctx, receipt, t, name),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMatchReceiptToTxn(
    BuildContext dialogCtx,
    Map<String, dynamic> receipt,
    Map<String, dynamic> txn,
    String name,
  ) async {
    if (_matchingReceipt) return;
    final receiptId = receipt['id'];
    final txnId = txn['id']?.toString();
    if (receiptId == null || txnId == null) return;
    setState(() => _matchingReceipt = true);
    Navigator.pop(dialogCtx);
    try {
      await _supabase.privilegedClient
          .from('receipts')
          .update({
            'transaction_id': txnId,
            'match_status': 'matched',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', receiptId);
      if (mounted) setState(() {
        receipt['match_status'] = 'matched';
        receipt['transaction_id'] = txnId;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Receipt matched to $name'),
          backgroundColor: BrandColors.success,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Match failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _matchingReceipt = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 4: MEC REPORTS — Timeline, validation, generation
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReportsTab() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final isMobile = constraints.maxWidth < 600;
      final hPad = isMobile ? 12.0 : 16.0;
      final gap = isMobile ? 12.0 : 20.0;

      return ListView(
        padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 40),
        children: [
          // Quarter timeline
          _buildQuarterTimeline(),
          SizedBox(height: gap),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildReportGenerator()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildValidationWarnings()),
              ],
            )
          else ...[
            _buildReportGenerator(),
            SizedBox(height: gap - 4),
            _buildValidationWarnings(),
          ],

          SizedBox(height: gap),

          // Report breakdown preview
          _buildReportPreview(),
          SizedBox(height: gap),

          // Historical reports
          if (_reportsLoading)
            CandidateUI.shimmerSkeleton(cardCount: 2)
          else if (_reports.isNotEmpty)
            _buildHistoricalReports()
          else
            CandidateUI.emptyState(Icons.description, 'No Reports Yet',
                'Generate your first MEC quarterly report above.'),

          SizedBox(height: gap),

          // Public-record filings archive (scraped from mec.mo.gov)
          if (_pastFilingsLoading)
            CandidateUI.shimmerSkeleton(cardCount: 1)
          else
            _buildPastFilingsArchive(),
        ],
      );
    });
  }

  // ── Past filings archive (mec_historical_filings) ──

  Widget _buildPastFilingsArchive() {
    return CandidateUI.card(
      'Past Filings — MEC Public Record',
      Icons.archive,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            'Every filing MEC has on record for Missouri Young Democrats ($_moydMecId). '
            'Updated by the mec-scraper committee-filings crawl.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (_pastFilings.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.white.withOpacity(0.55), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No archived filings yet. Run `python3 '
                      'scrape_committee_filings.py --mecid $_moydMecId --apply` '
                      'in /Users/moyd/mec-scraper to seed the archive.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._pastFilings.map(_pastFilingRow),
        ],
      ),
    );
  }

  Widget _pastFilingRow(Map<String, dynamic> f) {
    final filingType = (f['filing_type'] as String?) ?? 'Filing';
    final filingDate = (f['filing_date'] as String?) ?? '';
    final sourceUrl = f['source_url'] as String?;
    final storagePath = f['storage_path'] as String?;
    final totalContrib = (f['total_contributions'] as num?)?.toDouble();
    final totalExp = (f['total_expenditures'] as num?)?.toDouble();
    final quarter = f['quarter'] as String?;
    final year = f['filing_year'];

    final headerBadge = [
      if (year != null) year.toString(),
      if (quarter != null && quarter.isNotEmpty) quarter,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.steelBlue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  filingType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (headerBadge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BrandColors.steelBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    headerBadge,
                    style: TextStyle(
                      color: BrandColors.steelBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (filingDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Filed $filingDate',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
          if (totalContrib != null || totalExp != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (totalContrib != null)
                  Text(
                    'Contributions: \$${CandidateUI.formatMoney(totalContrib)}',
                    style: TextStyle(
                      color: BrandColors.success.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                if (totalContrib != null && totalExp != null)
                  const SizedBox(width: 12),
                if (totalExp != null)
                  Text(
                    'Expenditures: \$${CandidateUI.formatMoney(totalExp)}',
                    style: TextStyle(
                      color: BrandColors.republicanRed.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
          if (sourceUrl != null || storagePath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (sourceUrl != null)
                  _downloadChip(
                      'Open on MEC',
                      sourceUrl,
                      BrandColors.steelBlue),
                if (sourceUrl != null && storagePath != null)
                  const SizedBox(width: 8),
                if (storagePath != null)
                  _downloadChip(
                      'Archived PDF',
                      _supabase.privilegedClient.storage
                          .from('mec-filings')
                          .getPublicUrl(storagePath),
                      BrandColors.momentumBlue),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Quarter timeline ──

  Widget _buildQuarterTimeline() {
    final now = DateTime.now();
    final currentYear = now.year;

    // Show last 4 quarters + current
    final quarters = <String>[];
    for (int y = currentYear - 1; y <= currentYear; y++) {
      for (int q = 1; q <= 4; q++) {
        quarters.add('$y-Q$q');
      }
    }
    // Trim to last 8
    final display = quarters.length > 8
        ? quarters.sublist(quarters.length - 8)
        : quarters;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline,
                  color: Colors.white.withOpacity(0.8), size: 18),
              const SizedBox(width: 8),
              const Text('Quarterly Filing Timeline',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: display.map((q) {
                final report = _reports.cast<Map<String, dynamic>?>().firstWhere(
                    (r) => r?['quarter'] == q,
                    orElse: () => null);
                final status = report?['status'] as String? ?? 'none';

                Color dotColor;
                IconData dotIcon;
                switch (status) {
                  case 'filed':
                    dotColor = BrandColors.success;
                    dotIcon = Icons.check_circle;
                    break;
                  case 'ready':
                    dotColor = BrandColors.momentumBlue;
                    dotIcon = Icons.circle;
                    break;
                  case 'draft':
                    dotColor = Colors.orange;
                    dotIcon = Icons.pending;
                    break;
                  default:
                    dotColor = Colors.white.withOpacity(0.2);
                    dotIcon = Icons.radio_button_unchecked;
                }

                final isSelected = q == _selectedQuarter;

                return GestureDetector(
                  onTap: () => setState(() => _selectedQuarter = q),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? dotColor.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? dotColor.withOpacity(0.6)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child:
                                Icon(dotIcon, color: dotColor, size: 20),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(q.replaceAll('${q.split('-').first}-', ''),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CandidateUI.legendDot(BrandColors.success, 'Filed'),
              const SizedBox(width: 12),
              CandidateUI.legendDot(BrandColors.momentumBlue, 'Ready'),
              const SizedBox(width: 12),
              CandidateUI.legendDot(Colors.orange, 'Draft'),
              const SizedBox(width: 12),
              CandidateUI.legendDot(
                  Colors.white.withOpacity(0.2), 'Not generated'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Report generator card ──

  Widget _buildReportGenerator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BrandColors.unityBlue,
          BrandColors.sunriseGold.withOpacity(0.15),
        ]),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: BrandColors.sunriseGold.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: BrandColors.sunriseGold, size: 22),
              SizedBox(width: 10),
              Text('Generate MEC Report',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          // Quarter selector chips
          Row(
            children: [
              Text('Quarter: ',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              ...['Q1', 'Q2', 'Q3', 'Q4'].map((q) {
                final year = DateTime.now().year;
                final val = '$year-$q';
                final isSelected = val == _selectedQuarter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedQuarter = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? BrandColors.sunriseGold.withOpacity(0.25)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? BrandColors.sunriseGold.withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(q,
                          style: TextStyle(
                            color: isSelected
                                ? BrandColors.sunriseGold
                                : Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          // Preview stats
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BrandColors.unityBlue.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('$_donationCount',
                          style: const TextStyle(
                              color: BrandColors.success,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('Contributions',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11)),
                      Text(
                          '\$${CandidateUI.formatMoney(_donationTotal)}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.1)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                          '${_transactions.where((t) => (_asDouble(t['amount'])) > 100).length}',
                          style: const TextStyle(
                              color: BrandColors.republicanRed,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('Expenditures >\$100',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11)),
                      Text('Itemized for MEC',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generateReport,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_generating
                  ? 'Generating...'
                  : 'Generate $_selectedQuarter Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.sunriseGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Validation warnings ──

  Widget _buildValidationWarnings() {
    final warnings = <_ValidationWarning>[];

    // Check for large expenditures missing payee address
    final largeExpMissing = _transactions.where((t) {
      final amt = _asDouble(t['amount']);
      final included = t['mec_included'] as bool? ?? true;
      return amt > 100 && included && (t['mec_purpose'] == null || (t['mec_purpose'] as String).isEmpty);
    }).length;
    if (largeExpMissing > 0) {
      warnings.add(_ValidationWarning(
        '$largeExpMissing expenditures over \$100 are missing MEC purpose',
        Icons.warning_amber,
        Colors.orange,
      ));
    }

    // Check for excluded transactions
    final excludedCount = _transactions.where((t) => t['mec_included'] == false).length;
    if (excludedCount > 0) {
      warnings.add(_ValidationWarning(
        '$excludedCount transactions excluded from MEC reporting',
        Icons.info_outline,
        BrandColors.momentumBlue,
      ));
    }

    // Check for missing categories
    final noCat = _transactions.where((t) {
      final cats = t['category'] as List?;
      return cats == null || cats.isEmpty;
    }).length;
    if (noCat > 0) {
      warnings.add(_ValidationWarning(
        '$noCat transactions have no Plaid category',
        Icons.category,
        Colors.white54,
      ));
    }

    // Check if any report already exists for selected quarter
    final existingReport = _reports.cast<Map<String, dynamic>?>().firstWhere(
        (r) => r?['quarter'] == _selectedQuarter,
        orElse: () => null);
    if (existingReport != null) {
      warnings.add(_ValidationWarning(
        '$_selectedQuarter report already exists (${existingReport['status']})',
        Icons.check_circle_outline,
        BrandColors.success,
      ));
    }

    if (warnings.isEmpty) {
      warnings.add(_ValidationWarning(
        'All data looks good for report generation',
        Icons.verified,
        BrandColors.success,
      ));
    }

    return CandidateUI.card(
      'Validation Checks',
      Icons.verified_user,
      Colors.orange,
      child: Column(
        children: [
          const SizedBox(height: 10),
          ...warnings.map((w) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: w.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: w.color.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(w.icon, color: w.color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(w.message,
                          style: TextStyle(
                              color: w.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Report breakdown preview ──

  Widget _buildReportPreview() {
    // Sample contributions
    final sampleContribs = _donations.take(5).toList();
    // Sample expenditures
    final sampleExps = _transactions
        .where((t) =>
            (_asDouble(t['amount'])) > 100 &&
            (t['mec_included'] as bool? ?? true))
        .take(5)
        .toList();

    return CandidateUI.card(
      'Report Preview — $_selectedQuarter',
      Icons.preview,
      BrandColors.steelBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          // Contributions sample
          Text('CD1_A Contributions Sample',
              style: TextStyle(
                  color: BrandColors.success.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (sampleContribs.isEmpty)
            Text('No contribution data for this period',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11))
          else
            ...sampleContribs.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BrandColors.success.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: BrandColors.success.withOpacity(0.5),
                          size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d['donation_date'] as String? ?? '',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11),
                        ),
                      ),
                      Text(
                        '\$${CandidateUI.formatMoney(_asDouble(d['amount']))}',
                        style: const TextStyle(
                            color: BrandColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),

          const SizedBox(height: 14),
          Container(
              height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),

          // Expenditures sample
          Text('CD3_B Expenditures Sample (>\$100)',
              style: TextStyle(
                  color: BrandColors.republicanRed.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (sampleExps.isEmpty)
            Text('No itemized expenditures for this period',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11))
          else
            ...sampleExps.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BrandColors.republicanRed.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.store_outlined,
                          color: BrandColors.republicanRed.withOpacity(0.5),
                          size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t['merchant_name'] as String? ??
                              t['name'] as String? ??
                              'Unknown',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${CandidateUI.formatMoney(_asDouble(t['amount']))}',
                        style: const TextStyle(
                            color: BrandColors.republicanRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Historical reports with filed-status toggle ──

  Widget _buildHistoricalReports() {
    return CandidateUI.card(
      'Generated Reports',
      Icons.folder,
      BrandColors.steelBlue,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._reports.map((r) => _reportRow(r)),
        ],
      ),
    );
  }

  Widget _reportRow(Map<String, dynamic> r) {
    final quarter = r['quarter'] as String? ?? '';
    final status = r['status'] as String? ?? 'draft';
    final total =
        _asDouble(r['total_contributions']);
    final totalExp =
        _asDouble(r['total_expenditures']);
    final cd1aUrl = r['cd1a_csv_url'] as String?;
    final cd3bUrl = r['cd3b_csv_url'] as String?;

    Color statusColor;
    switch (status) {
      case 'ready':
        statusColor = BrandColors.momentumBlue;
        break;
      case 'filed':
        statusColor = BrandColors.success;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(quarter,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              // Filed toggle
              GestureDetector(
                onTap: _togglingReportFiled ? null : () => _toggleReportFiled(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status == 'filed'
                        ? BrandColors.success.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: status == 'filed'
                          ? BrandColors.success.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 'filed'
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: status == 'filed'
                            ? BrandColors.success
                            : Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status == 'filed' ? 'Filed' : 'Mark Filed',
                        style: TextStyle(
                          color: status == 'filed'
                              ? BrandColors.success
                              : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Contributions: \$${CandidateUI.formatMoney(total)}',
                style: TextStyle(
                    color: BrandColors.success.withOpacity(0.7),
                    fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                'Expenditures: \$${CandidateUI.formatMoney(totalExp)}',
                style: TextStyle(
                    color: BrandColors.republicanRed.withOpacity(0.7),
                    fontSize: 11),
              ),
            ],
          ),
          if (cd1aUrl != null || cd3bUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (cd1aUrl != null)
                  _downloadChip(
                      'CD1_A Contributions', cd1aUrl, BrandColors.success),
                if (cd1aUrl != null && cd3bUrl != null)
                  const SizedBox(width: 8),
                if (cd3bUrl != null)
                  _downloadChip('CD3_B Expenditures', cd3bUrl,
                      BrandColors.republicanRed),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _downloadChip(String label, String url, Color color) {
    return GestureDetector(
      onTap: () {
        final uri = Uri.tryParse(url);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════

  Widget _actionButton(
      {required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }

  double _asDouble(dynamic v) => _finNum(v);
}

/// Coerce a dynamic value to double, tolerating Supabase returning numeric
/// columns as either String ("32.05") or num (32.05). Casting directly with
/// `as num?` throws on the String form and crashed the Receipts tab render.
/// Used by _FinancesPageState and _MerchantDetailScreenState below.
double _finNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// ═══════════════════════════════════════════════════════════════
//  DATA CLASSES
// ═══════════════════════════════════════════════════════════════

class _StatCardData {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  const _StatCardData(this.label, this.value, this.subtitle, this.color, this.icon);
}

class _ValidationWarning {
  final String message;
  final IconData icon;
  final Color color;
  const _ValidationWarning(this.message, this.icon, this.color);
}

/// Full-screen merchant detail view showing all receipts + transactions for a vendor
class MerchantDetailScreen extends StatefulWidget {
  final String vendor;
  final List<Map<String, dynamic>> allReceipts;
  final List<Map<String, dynamic>> allTransactions;
  final Map<String, dynamic>? initialReceipt;
  final Map<String, dynamic>? initialTransaction;
  final Future<void> Function(String receiptId) onDelete;
  final Future<void> Function(String receiptId, String status) onUpdateStatus;

  const MerchantDetailScreen({
    super.key,
    required this.vendor,
    required this.allReceipts,
    required this.allTransactions,
    this.initialReceipt,
    this.initialTransaction,
    required this.onDelete,
    required this.onUpdateStatus,
  });

  @override
  State<MerchantDetailScreen> createState() => _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends State<MerchantDetailScreen> {
  Map<String, dynamic>? _selectedReceipt;

  double _asDouble(dynamic v) => _finNum(v);

  // Normalize vendor name for matching (Facebook = FACEBK, etc.)
  static const _vendorAliases = {
    'facebook': ['facebook', 'facebk', 'meta'],
    'meta': ['facebook', 'facebk', 'meta'],
    'google': ['google', 'gstatic', 'gsuite', 'workspace'],
    'googleapis': ['google', 'gstatic', 'gsuite', 'workspace'],
    'supabase': ['supabase', 'withorb'],
    'withorb': ['supabase', 'withorb'],
    'anthropic': ['anthropic', 'claude', 'parcel'],
    'parcel': ['anthropic', 'claude', 'parcel'],
    'netlify': ['netlify'],
    'vercel': ['vercel'],
    'digitalocean': ['digitalocean'],
    'mailchimp': ['mailchimp', 'reply'],
    'reply': ['mailchimp', 'reply'],
    'zoom': ['zoom'],
    'zapier': ['zapier'],
    'notion': ['notion'],
    'squarespace': ['sqsp', 'squarespac', 'squarespace'],
    'sqsp': ['sqsp', 'squarespac', 'squarespace'],
    'x corp': ['x corp', 'about.x'],
    'versapay': ['versapay', 'vsp*raven', 'raven printing', 'vpy'],
  };

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _matchesVendor(String name, String target) {
    final n = _normalize(name);
    final t = _normalize(target);
    if (n == t || n.contains(t) || t.contains(n)) return true;

    // Check aliases
    for (final entry in _vendorAliases.entries) {
      final key = entry.key;
      final aliases = entry.value;
      if (t == _normalize(key) || aliases.any((a) => _normalize(a) == t)) {
        if (aliases.any((a) => n.contains(_normalize(a)))) return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> get _merchantReceipts {
    return widget.allReceipts
        .where((r) => r['match_status'] != 'ignored')
        .where((r) => _matchesVendor(r['vendor_name'] as String? ?? '', widget.vendor))
        .toList()
      ..sort((a, b) => (b['email_date'] as String? ?? '').compareTo(a['email_date'] as String? ?? ''));
  }

  List<Map<String, dynamic>> get _merchantTransactions {
    return widget.allTransactions
        .where((t) => _matchesVendor(
              (t['merchant_name'] as String? ?? t['name'] as String? ?? ''),
              widget.vendor,
            ))
        .toList()
      ..sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
  }

  double get _totalSpent {
    double total = 0;
    for (final t in _merchantTransactions) {
      final amt = _asDouble(t['amount']);
      if (amt > 0) total += amt;
    }
    return total;
  }

  double get _totalReceiptAmount {
    double total = 0;
    for (final r in _merchantReceipts) {
      total += _asDouble(r['amount']);
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _selectedReceipt = widget.initialReceipt;
    // If opening from a transaction, try to find a matched receipt
    if (_selectedReceipt == null && widget.initialTransaction != null) {
      final txnId = widget.initialTransaction!['id']?.toString();
      if (txnId != null) {
        final matched = widget.allReceipts.firstWhere(
          (r) => r['transaction_id']?.toString() == txnId,
          orElse: () => {},
        );
        if (matched.isNotEmpty) _selectedReceipt = matched;
      }
    }
    // Fall back to the first receipt for this merchant
    _selectedReceipt ??= _merchantReceipts.isNotEmpty ? _merchantReceipts.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.unityBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(widget.vendor,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BrandedBackground(
        child: LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: receipt preview
                    Expanded(flex: 3, child: _buildReceiptPreviewPanel()),
                    // Right: lists
                    Expanded(flex: 2, child: _buildListsPanel()),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 12),
                    if (_selectedReceipt != null) ...[
                      SizedBox(
                        height: 400,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _ReceiptWebView(
                            url: _selectedReceipt!['storage_url'] as String? ?? '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptActions(_selectedReceipt!),
                      const SizedBox(height: 16),
                    ],
                    _buildTransactionsSection(),
                    const SizedBox(height: 16),
                    _buildReceiptsSection(),
                  ],
                );
        }),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final txnCount = _merchantTransactions.length;
    final receiptCount = _merchantReceipts.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.vendor,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _headerStat('Total Spent', '\$${CandidateUI.formatMoney(_totalSpent)}', BrandColors.sunriseGold),
              _headerStat('Transactions', '$txnCount', BrandColors.momentumBlue),
              _headerStat('Receipts', '$receiptCount', BrandColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildReceiptPreviewPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          const Text('Receipt Document',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedReceipt != null
                  ? _ReceiptWebView(url: _selectedReceipt!['storage_url'] as String? ?? '')
                  : const Center(
                      child: Text('No receipt selected',
                          style: TextStyle(color: Colors.black54))),
            ),
          ),
          if (_selectedReceipt != null) ...[
            const SizedBox(height: 12),
            _buildReceiptActions(_selectedReceipt!),
          ],
        ],
      ),
    );
  }

  Widget _buildListsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: ListView(
        children: [
          _buildTransactionsSection(),
          const SizedBox(height: 16),
          _buildReceiptsSection(),
        ],
      ),
    );
  }

  Widget _buildReceiptActions(Map<String, dynamic> r) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E3A5F),
                  title: const Text('Delete receipt?',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  content: const Text(
                      'This will permanently remove it from the CRM and storage.',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await widget.onDelete(r['id'] as String);
                if (mounted) {
                  setState(() {
                    _selectedReceipt = _merchantReceipts.isNotEmpty
                        ? _merchantReceipts.first
                        : null;
                  });
                }
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
            label: const Text('Delete',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await widget.onUpdateStatus(r['id'] as String, 'inkind');
              if (mounted) setState(() => r['match_status'] = 'inkind');
            },
            icon: const Icon(Icons.volunteer_activism, color: BrandColors.sunriseGold, size: 18),
            label: const Text('In-Kind',
                style: TextStyle(color: BrandColors.sunriseGold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: BrandColors.sunriseGold.withOpacity(0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await widget.onUpdateStatus(r['id'] as String, 'ignored');
              if (mounted) setState(() => r['match_status'] = 'ignored');
            },
            icon: const Icon(Icons.block, color: Colors.grey, size: 18),
            label: const Text('Ignore',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection() {
    final txns = _merchantTransactions;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: BrandColors.momentumBlue, size: 18),
              const SizedBox(width: 8),
              Text('Transactions (${txns.length})',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No bank transactions for this merchant',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            )
          else
            ...txns.map((t) {
              final amount = (_asDouble(t['amount'])).abs();
              final date = t['date'] as String? ?? '';
              final name = t['merchant_name'] as String? ?? t['name'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(date,
                              style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text('\$${CandidateUI.formatMoney(amount)}',
                        style: const TextStyle(
                            color: BrandColors.sunriseGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReceiptsSection() {
    final receipts = _merchantReceipts;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt, color: BrandColors.success, size: 18),
              const SizedBox(width: 8),
              Text('Receipts (${receipts.length})',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (receipts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No receipts for this merchant',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            )
          else
            ...receipts.map((r) {
              final isSelected = _selectedReceipt?['id'] == r['id'];
              final amount = _asDouble(r['amount']);
              final date = r['email_date'] as String? ?? '';
              final subject = r['email_subject'] as String? ?? '';
              return GestureDetector(
                onTap: () => setState(() => _selectedReceipt = r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BrandColors.success.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? BrandColors.success.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(date.length > 10 ? date.substring(0, 10) : date,
                                style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                      if (amount > 0)
                        Text('\$${CandidateUI.formatMoney(amount)}',
                            style: const TextStyle(
                                color: BrandColors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Inline receipt viewer — picks the right rendering strategy per file type.
///
/// Strategy:
///   - `.pdf` on Flutter Web  → browser-native `<iframe>` (via HtmlElementView).
///     This delegates to Chrome/Firefox/Safari's built-in PDF viewer and
///     sidesteps every bug the `printing` package's PDF.js/PDFium wrapper can
///     hit on malformed/complex PDFs.
///   - `.pdf` on mobile/desktop → `printing.PdfPreview` (works fine there).
///   - `.html` / `.htm`        → WebView (renders HTML receipts).
///   - Everything else (`.xlsx`, `.docx`, `.bin`, unknown) → "Open externally"
///     fallback so the user can at least download the file.
class _ReceiptWebView extends StatefulWidget {
  final String url;
  const _ReceiptWebView({required this.url});

  @override
  State<_ReceiptWebView> createState() => _ReceiptWebViewState();
}

enum _ReceiptKind { pdf, html, unsupported }

class _ReceiptWebViewState extends State<_ReceiptWebView> {
  _ReceiptKind _classify() {
    final u = widget.url.toLowerCase();
    final path = Uri.tryParse(u)?.path ?? u;
    if (path.endsWith('.pdf')) return _ReceiptKind.pdf;
    if (path.endsWith('.html') || path.endsWith('.htm')) return _ReceiptKind.html;
    return _ReceiptKind.unsupported;
  }

  @override
  Widget build(BuildContext context) {
    switch (_classify()) {
      case _ReceiptKind.pdf:
        return _PdfReceiptViewer(url: widget.url);
      case _ReceiptKind.html:
        return _HtmlReceiptViewer(url: widget.url);
      case _ReceiptKind.unsupported:
        return _UnsupportedReceiptViewer(url: widget.url);
    }
  }
}

/// PDF viewer:
///   - On web: native browser iframe (bulletproof).
///   - On mobile/desktop: printing package's PdfPreview, with http-fetched
///     bytes and an in-widget error boundary so a rendering throw in
///     PdfPreview surfaces as an inline "Open externally" card instead of
///     propagating to the global ErrorWidget.builder (which would mask the
///     failure as "An unexpected error occurred when rendering").
class _PdfReceiptViewer extends StatefulWidget {
  final String url;
  const _PdfReceiptViewer({required this.url});

  @override
  State<_PdfReceiptViewer> createState() => _PdfReceiptViewerState();
}

class _PdfReceiptViewerState extends State<_PdfReceiptViewer> {
  // Mobile/desktop path state — unused on web.
  Uint8List? _pdfData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pdfData = response.bodyBytes;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'HTTP ${response.statusCode}';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Web: hand the URL straight to the browser's built-in PDF viewer ──
    if (kIsWeb) {
      final native = buildBrowserNativePdfViewer(widget.url);
      if (native != null) return native;
      // Fall through to the error card if somehow the web impl didn't return.
    }

    // ── Mobile/desktop: fetch bytes and hand to printing.PdfPreview ──
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.momentumBlue),
      );
    }

    if (_error != null || _pdfData == null) {
      return _openExternallyCard(
        message: _error ?? 'Failed to load PDF',
        url: widget.url,
      );
    }

    return PdfPreview(
      build: (format) async => _pdfData!,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      pdfFileName: 'receipt.pdf',
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: BrandColors.momentumBlue),
      ),
    );
  }
}

/// Fallback for file types we can't preview inline (xlsx, docx, unknown .bin,
/// etc.). Offers a one-click "Open externally" so the user can download and
/// view in their native app.
class _UnsupportedReceiptViewer extends StatelessWidget {
  final String url;
  const _UnsupportedReceiptViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    final ext = _extOf(url);
    return _openExternallyCard(
      message: ext.isEmpty
          ? 'No preview available for this file type.'
          : 'No inline preview for .$ext files.',
      url: url,
    );
  }

  static String _extOf(String url) {
    final path = Uri.tryParse(url.toLowerCase())?.path ?? url.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }
}

/// Shared "Open externally" card used as an error/fallback widget.
Widget _openExternallyCard({required String message, required String url}) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.description_outlined, color: Colors.orange, size: 32),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            final uri = Uri.tryParse(url);
            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open externally'),
        ),
      ],
    ),
  );
}

/// HTML receipt viewer using WebView
class _HtmlReceiptViewer extends StatefulWidget {
  final String url;
  const _HtmlReceiptViewer({required this.url});

  @override
  State<_HtmlReceiptViewer> createState() => _HtmlReceiptViewerState();
}

class _HtmlReceiptViewerState extends State<_HtmlReceiptViewer> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: BrandColors.momentumBlue),
          ),
      ],
    );
  }
}
