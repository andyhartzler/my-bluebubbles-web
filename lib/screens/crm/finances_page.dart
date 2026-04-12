import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _loadAll() async {
    await Future.wait([
      _loadConnections(),
      _loadTransactions(),
      _loadReports(),
      _loadDonations(),
      _loadDonors(),
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
            0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));
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
              (_monthlyDonations[key] ?? 0) + ((d['amount'] as num?)?.toDouble() ?? 0);
        }
      }
    }

    // ── Top 5 donors ──
    _topDonors = _donors.take(5).toList();

    // ── Expense categories ──
    _expenseCategories = {};
    for (final t in _transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
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
        'amount': (d['amount'] as num?)?.toDouble() ?? 0,
        'label': 'Contribution received',
        'method': d['payment_method'] ?? '',
      });
    }
    for (final t in _transactions.take(20)) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
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
      // 1. Get a link_token from the Edge Function
      final resp = await _supabase.privilegedClient.functions.invoke('plaid',
          body: {
            'action': 'create_link_token',
            'redirect_uri': 'https://moyd.app/plaid/callback',
          });
      final data = resp.data is Map
          ? resp.data as Map<String, dynamic>
          : (resp.data is String ? jsonDecode(resp.data as String) : <String, dynamic>{});
      final linkToken = data['link_token'] as String?;
      if (linkToken == null) throw Exception('No link token returned from Plaid');

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
    final id = txn['id'];
    if (id == null) return;
    try {
      await _supabase.privilegedClient
          .from('bank_transactions')
          .update({'mec_included': value})
          .eq('id', id);
      setState(() => txn['mec_included'] = value);
    } catch (_) {}
  }

  Future<void> _updateMecPurpose(Map<String, dynamic> txn, String purpose) async {
    final id = txn['id'];
    if (id == null) return;
    try {
      await _supabase.privilegedClient
          .from('bank_transactions')
          .update({'mec_purpose': purpose})
          .eq('id', id);
      setState(() => txn['mec_purpose'] = purpose);
    } catch (_) {}
  }

  Future<void> _toggleReportFiled(Map<String, dynamic> report) async {
    final id = report['id'];
    if (id == null) return;
    final current = report['status'] as String? ?? 'draft';
    final newStatus = current == 'filed' ? 'ready' : 'filed';
    try {
      await _supabase.privilegedClient
          .from('mec_reports')
          .update({'status': newStatus})
          .eq('id', id);
      setState(() => report['status'] = newStatus);
    } catch (_) {}
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
        0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
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
              children: [
                _buildOverviewTab(),
                _buildTransactionsTab(),
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
    if (_connectionsLoading) return CandidateUI.shimmerSkeleton(cardCount: 4);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Bank connection card
          _buildConnectionCard(),
          const SizedBox(height: 16),

          // Animated stat cards
          _buildAnimatedStatCards(),
          const SizedBox(height: 20),

          // Two-column layout on wide screens
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    _buildMonthlyTrendChart(),
                    const SizedBox(height: 16),
                    _buildRecentActivityFeed(),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(children: [
                    _buildTopDonorsLeaderboard(),
                    const SizedBox(height: 16),
                    _buildExpenseCategoriesBreakdown(),
                    const SizedBox(height: 16),
                    _buildDeadlineCard(),
                  ]),
                ),
              ],
            )
          else ...[
            _buildMonthlyTrendChart(),
            const SizedBox(height: 16),
            _buildTopDonorsLeaderboard(),
            const SizedBox(height: 16),
            _buildExpenseCategoriesBreakdown(),
            const SizedBox(height: 16),
            _buildRecentActivityFeed(),
            const SizedBox(height: 16),
            _buildDeadlineCard(),
          ],
        ],
      );
    });
  }

  // ── Animated stat cards with staggered entrance ──

  Widget _buildAnimatedStatCards() {
    final expenses = _transactions
        .where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 0)
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));

    final balance = _donationTotal - expenses;

    final cards = [
      _StatCardData('Contributions', '\$${CandidateUI.formatMoney(_donationTotal)}',
          '$_donationCount donors', BrandColors.success, Icons.volunteer_activism),
      _StatCardData('Expenditures', '\$${CandidateUI.formatMoney(expenses)}',
          '${_transactions.where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 0).length} transactions',
          BrandColors.republicanRed, Icons.payments),
      _StatCardData('Balance', '\$${CandidateUI.formatMoney(balance.abs())}',
          balance >= 0 ? 'Net positive' : 'Net negative',
          BrandColors.momentumBlue, Icons.account_balance_wallet),
      _StatCardData('MEC Reports', '${_reports.length}',
          '${_reports.where((r) => r['status'] == 'filed').length} filed',
          BrandColors.sunriseGold, Icons.description),
    ];

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        return Row(
          children: List.generate(cards.length, (i) {
            final delay = i * 0.15;
            final progress = ((_staggerController.value - delay) / (1 - delay))
                .clamp(0.0, 1.0);
            final curve = Curves.easeOutBack.transform(progress);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < cards.length - 1 ? 10 : 0),
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - curve)),
                  child: Opacity(
                    opacity: progress,
                    child: _statCard(
                      cards[i].label, cards[i].value, cards[i].subtitle,
                      cards[i].color, cards[i].icon,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _statCard(String label, String value, String subtitle, Color color,
      IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), Colors.white.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 18),
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
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 10)),
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
                              color: Colors.white.withOpacity(0.4),
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
                      color: Colors.white.withOpacity(0.4), fontSize: 13)),
            )
          else
            ...List.generate(_topDonors.length, (i) {
              final donor = _topDonors[i];
              final name = donor['name'] as String? ?? 'Anonymous';
              final total =
                  (donor['total_donated'] as num?)?.toDouble() ?? 0;
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
                      color: Colors.white.withOpacity(0.4), fontSize: 13)),
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
                      color: Colors.white.withOpacity(0.4), fontSize: 13)),
            )
          else
            ...List.generate(_recentActivity.length, (i) {
              final item = _recentActivity[i];
              final isDonation = item['type'] == 'donation';
              final color =
                  isDonation ? BrandColors.success : BrandColors.republicanRed;
              final amount = (item['amount'] as double?) ?? 0;
              final label = item['label'] as String? ?? '';
              final date = item['date'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
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
                                  color: Colors.white.withOpacity(0.4),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [
                  BrandColors.success.withOpacity(0.15),
                  BrandColors.success.withOpacity(0.05),
                ]
              : [
                  Colors.orange.withOpacity(0.15),
                  Colors.orange.withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: connected
                ? BrandColors.success.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
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
                  color: connected
                      ? BrandColors.success
                          .withOpacity(0.5 + _pulseController.value * 0.5)
                      : Colors.orange
                          .withOpacity(0.5 + _pulseController.value * 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: (connected ? BrandColors.success : Colors.orange)
                          .withOpacity(0.3),
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
                    color: connected ? BrandColors.success : Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (connected && conn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${conn['institution_name'] ?? 'UMB Bank'} • '
                    '${(conn['account_names'] as List?)?.join(', ') ?? 'Account'}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                  if (conn['last_synced_at'] != null)
                    Text(
                      'Last synced: ${_formatDate(conn['last_synced_at'])}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 11),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [urgency.withOpacity(0.15), Colors.white.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgency.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: urgency.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_today, color: urgency, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next MEC Filing Deadline',
                    style: TextStyle(
                        color: urgency,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${now.year}-Q$q Report • Due ${deadline.month}/${deadline.day}/${deadline.year}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: urgency.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$daysLeft days',
                style: TextStyle(
                    color: urgency,
                    fontSize: 14,
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

    return Column(
      children: [
        // Search bar
        _buildTransactionSearchBar(),

        // Date range + category filters
        _buildTransactionFilters(),

        // Transaction list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _buildTransactionRow(filtered[index]),
          ),
        ),

        // Total row
        _buildTransactionTotalRow(filtered),
      ],
    );
  }

  Widget _buildTransactionSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name or merchant...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(Icons.search,
                color: Colors.white.withOpacity(0.4), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.white.withOpacity(0.4), size: 18),
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
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: BrandColors.momentumBlue,
                            onPrimary: Colors.white,
                            surface: Color(0xFF1E3A5F),
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
                              : Colors.white54,
                          size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _dateRange != null
                            ? '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}'
                            : 'Date range',
                        style: TextStyle(
                          color: _dateRange != null
                              ? BrandColors.momentumBlue
                              : Colors.white54,
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
                      color: Colors.white.withOpacity(0.4), size: 16),
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
                            : Colors.white.withOpacity(0.04),
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
                                : Colors.white54,
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
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(included ? 0.05 : 0.02),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(included ? 0.08 : 0.03)),
      ),
      child: Row(
        children: [
          // MEC inclusion checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: included,
              onChanged: (v) => _toggleMecInclusion(t, v ?? true),
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
                          : Colors.white.withOpacity(0.4),
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
                              color: Colors.white.withOpacity(0.4),
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
                    color: Colors.white.withOpacity(0.3), size: 14),
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
    );
  }

  Widget _buildTransactionTotalRow(List<Map<String, dynamic>> filtered) {
    final totalExpense = filtered
        .where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 0)
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
    final totalIncome = filtered
        .where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) < 0)
        .fold(0.0,
            (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0).abs());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Text('${filtered.length} transactions',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
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
                onTap: () {
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
  //  TAB 3: MEC REPORTS — Timeline, validation, generation
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReportsTab() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Quarter timeline
          _buildQuarterTimeline(),
          const SizedBox(height: 20),

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
            const SizedBox(height: 16),
            _buildValidationWarnings(),
          ],

          const SizedBox(height: 20),

          // Report breakdown preview
          _buildReportPreview(),
          const SizedBox(height: 20),

          // Historical reports
          if (_reportsLoading)
            CandidateUI.shimmerSkeleton(cardCount: 2)
          else if (_reports.isNotEmpty)
            _buildHistoricalReports()
          else
            CandidateUI.emptyState(Icons.description, 'No Reports Yet',
                'Generate your first MEC quarterly report above.'),
        ],
      );
    });
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
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline,
                  color: Colors.white.withOpacity(0.6), size: 18),
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
                                  : Colors.white.withOpacity(0.4),
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
          BrandColors.sunriseGold.withOpacity(0.12),
          Colors.white.withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: BrandColors.sunriseGold.withOpacity(0.25)),
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
                                : Colors.white60,
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
              color: Colors.white.withOpacity(0.04),
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
                          '${_transactions.where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 100).length}',
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
                              color: Colors.white.withOpacity(0.4),
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
      final amt = (t['amount'] as num?)?.toDouble() ?? 0;
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
            ((t['amount'] as num?)?.toDouble() ?? 0) > 100 &&
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
                    color: Colors.white.withOpacity(0.4), fontSize: 11))
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
                        '\$${CandidateUI.formatMoney((d['amount'] as num?)?.toDouble() ?? 0)}',
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
                    color: Colors.white.withOpacity(0.4), fontSize: 11))
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
                        '\$${CandidateUI.formatMoney((t['amount'] as num?)?.toDouble() ?? 0)}',
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
        (r['total_contributions'] as num?)?.toDouble() ?? 0;
    final totalExp =
        (r['total_expenditures'] as num?)?.toDouble() ?? 0;
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
                onTap: () => _toggleReportFiled(r),
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
                            : Colors.white54,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status == 'filed' ? 'Filed' : 'Mark Filed',
                        style: TextStyle(
                          color: status == 'filed'
                              ? BrandColors.success
                              : Colors.white54,
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
