import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════
//  FINANCES PAGE — Bank Integration + MEC Report Generator
//  Connects to UMB Bank via Plaid, syncs transactions,
//  and auto-generates MEC quarterly campaign finance reports.
// ═══════════════════════════════════════════════════════════════

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

  // Connection state
  List<Map<String, dynamic>> _connections = [];
  bool _connectionsLoading = true;

  // Transactions state
  List<Map<String, dynamic>> _transactions = [];
  bool _transactionsLoading = true;
  bool _syncing = false;

  // Reports state
  List<Map<String, dynamic>> _reports = [];
  bool _reportsLoading = true;
  bool _generating = false;
  String _selectedQuarter = '';

  // Donations state (for report preview)
  int _donationCount = 0;
  double _donationTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Auto-detect current quarter
    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    _selectedQuarter = '${now.year}-Q$q';

    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadConnections(),
      _loadTransactions(),
      _loadReports(),
      _loadDonationStats(),
    ]);
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
    } catch (e) {
      if (mounted) setState(() => _connectionsLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('bank_transactions')
          .select()
          .order('date', ascending: false)
          .limit(200);
      if (mounted) setState(() {
        _transactions = (resp as List).cast<Map<String, dynamic>>();
        _transactionsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _transactionsLoading = false);
    }
  }

  Future<void> _loadReports() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('mec_reports')
          .select()
          .order('period_start', ascending: false)
          .limit(8);
      if (mounted) setState(() {
        _reports = (resp as List).cast<Map<String, dynamic>>();
        _reportsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _reportsLoading = false);
    }
  }

  Future<void> _loadDonationStats() async {
    try {
      final resp = await _supabase.privilegedClient
          .from('donations')
          .select('amount')
          .eq('status', 'completed');
      final donations = (resp as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() {
        _donationCount = donations.length;
        _donationTotal = donations.fold(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));
      });
    } catch (_) {}
  }

  Future<void> _syncTransactions() async {
    setState(() => _syncing = true);
    try {
      await _supabase.privilegedClient.functions.invoke('plaid', body: {'action': 'sync_transactions'});
      await _loadTransactions();
      await _loadConnections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions synced successfully'), backgroundColor: BrandColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      final resp = await _supabase.privilegedClient.functions.invoke('plaid',
          body: {'action': 'generate_mec_report', 'quarter': _selectedQuarter});
      await _loadReports();
      if (mounted) {
        final data = jsonDecode(resp.data as String? ?? '{}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generated: ${data['contributions']?['count'] ?? 0} contributions, ${data['expenditures']?['count'] ?? 0} expenditures'),
            backgroundColor: BrandColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _connectBank() async {
    try {
      final resp = await _supabase.privilegedClient.functions.invoke('plaid',
          body: {'action': 'create_link_token', 'redirect_uri': 'https://moyd.app/plaid/callback'});
      final data = jsonDecode(resp.data as String? ?? '{}');
      final linkToken = data['link_token'] as String?;
      if (linkToken == null) throw Exception('No link token returned');

      // Open Plaid Link — for web, we use the Plaid Link JS SDK
      // The plaid_flutter package handles this automatically
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening Plaid Link...'), backgroundColor: BrandColors.momentumBlue),
        );
      }
      // TODO: Integrate plaid_flutter PlaidLink widget with this linkToken
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1E37), BrandColors.unityBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTransactionsTab(),
                  _buildReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [BrandColors.sunriseGold.withOpacity(0.3), BrandColors.sunriseGold.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance, color: BrandColors.sunriseGold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Finances', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text('Bank Integration & MEC Reports', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              ],
            ),
          ),
          // Sync button
          if (_connections.isNotEmpty)
            _actionButton(
              icon: _syncing ? Icons.hourglass_top : Icons.sync,
              label: _syncing ? 'Syncing...' : 'Sync',
              color: BrandColors.momentumBlue,
              onTap: _syncing ? null : _syncTransactions,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: BrandColors.sunriseGold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: BrandColors.sunriseGold,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
          Tab(text: 'MEC Reports'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: OVERVIEW — Connection status + quick stats
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    if (_connectionsLoading) return CandidateUI.shimmerSkeleton(cardCount: 3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Bank connection card
        _buildConnectionCard(),
        const SizedBox(height: 16),

        // Quick stats
        _buildQuickStats(),
        const SizedBox(height: 16),

        // Next filing deadline
        _buildDeadlineCard(),
        const SizedBox(height: 16),

        // Recent reports
        if (_reports.isNotEmpty) ...[
          _buildRecentReports(),
        ],
      ],
    );
  }

  Widget _buildConnectionCard() {
    final connected = _connections.isNotEmpty;
    final conn = connected ? _connections.first : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [BrandColors.success.withOpacity(0.15), BrandColors.success.withOpacity(0.05)]
              : [Colors.orange.withOpacity(0.15), Colors.orange.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: connected ? BrandColors.success.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected
                          ? BrandColors.success.withOpacity(0.5 + _pulseController.value * 0.5)
                          : Colors.orange.withOpacity(0.5 + _pulseController.value * 0.5),
                      boxShadow: [BoxShadow(
                        color: (connected ? BrandColors.success : Colors.orange).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: _pulseController.value * 2,
                      )],
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
                        fontSize: 16, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (connected && conn != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${conn['institution_name'] ?? 'UMB Bank'} • ${(conn['account_names'] as List?)?.join(', ') ?? 'Account'}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                      if (conn['last_synced_at'] != null)
                        Text(
                          'Last synced: ${_formatDate(conn['last_synced_at'])}',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
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
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final expenses = _transactions
        .where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 0)
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
    final income = _transactions
        .where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) < 0)
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0).abs());

    return Row(
      children: [
        _statCard('Contributions', '\$${CandidateUI.formatMoney(_donationTotal)}',
            '$_donationCount donors', BrandColors.success, Icons.volunteer_activism),
        const SizedBox(width: 10),
        _statCard('Expenditures', '\$${CandidateUI.formatMoney(expenses)}',
            '${_transactions.where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 0).length} transactions',
            BrandColors.republicanRed, Icons.payments),
        const SizedBox(width: 10),
        _statCard('Balance', '\$${CandidateUI.formatMoney(_donationTotal - expenses)}',
            'Net position', BrandColors.momentumBlue, Icons.account_balance_wallet),
      ],
    );
  }

  Widget _statCard(String label, String value, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.12), Colors.white.withOpacity(0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color.withOpacity(0.7), size: 18),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineCard() {
    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    final deadlineMonth = q == 4 ? 1 : q * 3 + 1;
    final deadlineYear = q == 4 ? now.year + 1 : now.year;
    final deadline = DateTime(deadlineYear, deadlineMonth, 15);
    final daysLeft = deadline.difference(now).inDays;

    final urgency = daysLeft < 7 ? Colors.red : daysLeft < 30 ? Colors.orange : BrandColors.momentumBlue;

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
                Text('Next MEC Filing Deadline', style: TextStyle(color: urgency, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${now.year}-Q$q Report • Due ${deadline.month}/${deadline.day}/${deadline.year}',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: urgency.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$daysLeft days', style: TextStyle(color: urgency, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    return CandidateUI.card('Recent Reports', Icons.description, BrandColors.steelBlue, child: Column(
      children: [
        const SizedBox(height: 8),
        ..._reports.take(4).map((r) => _reportRow(r)),
      ],
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: TRANSACTIONS — Bank transaction list
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final t = _transactions[index];
        final amount = (t['amount'] as num?)?.toDouble() ?? 0;
        final isExpense = amount > 0;
        final date = t['date'] as String? ?? '';
        final name = t['merchant_name'] as String? ?? t['name'] as String? ?? 'Unknown';
        final category = (t['category'] as List?)?.join(' > ') ?? '';
        final included = t['mec_included'] as bool? ?? true;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(included ? 0.05 : 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(included ? 0.08 : 0.03)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isExpense ? BrandColors.republicanRed : BrandColors.success).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isExpense ? BrandColors.republicanRed : BrandColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                      color: included ? Colors.white : Colors.white.withOpacity(0.4),
                      fontSize: 13, fontWeight: FontWeight.w600,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$date • $category', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ],
                ),
              ),
              Text(
                '${isExpense ? "-" : "+"}\$${CandidateUI.formatMoney(amount.abs())}',
                style: TextStyle(
                  color: isExpense ? BrandColors.republicanRed : BrandColors.success,
                  fontSize: 14, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: MEC REPORTS — Generate + download quarterly reports
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Report generator card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandColors.sunriseGold.withOpacity(0.12), Colors.white.withOpacity(0.04)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: BrandColors.sunriseGold, size: 22),
                  const SizedBox(width: 10),
                  const Text('Generate MEC Report', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              // Quarter selector
              Row(
                children: [
                  const Text('Quarter: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  ...['Q1', 'Q2', 'Q3', 'Q4'].map((q) {
                    final year = DateTime.now().year;
                    final val = '$year-$q';
                    final isSelected = val == _selectedQuarter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedQuarter = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? BrandColors.sunriseGold.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? BrandColors.sunriseGold.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(q, style: TextStyle(
                            color: isSelected ? BrandColors.sunriseGold : Colors.white60,
                            fontSize: 13, fontWeight: FontWeight.w700,
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
                          Text('$_donationCount', style: const TextStyle(color: BrandColors.success, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('Contributions', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          Text('\$${CandidateUI.formatMoney(_donationTotal)}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                    Expanded(
                      child: Column(
                        children: [
                          Text('${_transactions.where((t) => ((t['amount'] as num?)?.toDouble() ?? 0) > 100).length}',
                              style: const TextStyle(color: BrandColors.republicanRed, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('Expenditures >\$100', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          Text('Itemized for MEC', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
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
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_generating ? 'Generating...' : 'Generate $_selectedQuarter Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.sunriseGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Past reports
        if (_reportsLoading)
          CandidateUI.shimmerSkeleton(cardCount: 2)
        else if (_reports.isNotEmpty)
          CandidateUI.card('Generated Reports', Icons.folder, BrandColors.steelBlue, child: Column(
            children: [
              const SizedBox(height: 8),
              ..._reports.map((r) => _reportRow(r)),
            ],
          ))
        else
          CandidateUI.emptyState(Icons.description, 'No Reports Yet', 'Generate your first MEC quarterly report above.'),
      ],
    );
  }

  Widget _reportRow(Map<String, dynamic> r) {
    final quarter = r['quarter'] as String? ?? '';
    final status = r['status'] as String? ?? 'draft';
    final contribs = (r['contribution_count'] as num?)?.toInt() ?? 0;
    final total = (r['total_contributions'] as num?)?.toDouble() ?? 0;
    final expCount = (r['expenditure_count'] as num?)?.toInt() ?? 0;
    final cd1aUrl = r['cd1a_csv_url'] as String?;
    final cd3bUrl = r['cd3b_csv_url'] as String?;

    Color statusColor;
    switch (status) {
      case 'ready': statusColor = BrandColors.success; break;
      case 'filed': statusColor = BrandColors.momentumBlue; break;
      default: statusColor = Colors.orange;
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
              Text(quarter, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text('$contribs contribs • \$${CandidateUI.formatMoney(total)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ),
          if (cd1aUrl != null || cd3bUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (cd1aUrl != null)
                  _downloadChip('CD1_A Contributions', cd1aUrl, BrandColors.success),
                if (cd1aUrl != null && cd3bUrl != null) const SizedBox(width: 8),
                if (cd3bUrl != null)
                  _downloadChip('CD3_B Expenditures', cd3bUrl, BrandColors.republicanRed),
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
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _actionButton({required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
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
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
