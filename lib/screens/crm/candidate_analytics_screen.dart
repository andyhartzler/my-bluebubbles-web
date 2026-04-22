import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/widgets/crm/missouri_map_widget.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE ANALYTICS SCREEN
//  District-level analysis, race competitiveness ratings,
//  party breakdowns, age distributions, and engagement metrics.
// ═══════════════════════════════════════════════════════════════

class CandidateAnalyticsScreen extends StatefulWidget {
  final String? initialDistrict;

  const CandidateAnalyticsScreen({super.key, this.initialDistrict});

  @override
  State<CandidateAnalyticsScreen> createState() =>
      _CandidateAnalyticsScreenState();
}

class _CandidateAnalyticsScreenState extends State<CandidateAnalyticsScreen>
    with TickerProviderStateMixin {
  final CandidateRepository _repo = CandidateRepository();

  late TabController _tabController;
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;

  CandidateStats _stats = const CandidateStats();
  Map<String, Map<String, int>> _partyBreakdown = {};
  Map<String, int> _contestation = {};
  Map<String, List<Candidate>> _districtMap = {};
  List<Candidate> _allCandidates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _repo.fetchStats(),
      _repo.fetchPartyBreakdown(),
      _repo.fetchContestationBreakdown(),
      _repo.fetchCandidatesForAnalytics(),
    ]);

    final stats = results[0] as CandidateStats;
    final breakdown = results[1] as Map<String, Map<String, int>>;
    final contestation = results[2] as Map<String, int>;
    final candidates = results[3] as List<Candidate>;

    // Build district map
    final districtMap = <String, List<Candidate>>{};
    for (final c in candidates) {
      if (c.officeLevel == 'state' && c.district != null && c.district!.isNotEmpty) {
        districtMap.putIfAbsent(c.district!, () => []).add(c);
      }
    }

    setState(() {
      _stats = stats;
      _partyBreakdown = breakdown;
      _contestation = contestation;
      _districtMap = districtMap;
      _allCandidates = candidates;
      _loading = false;
    });
    _entranceController.forward();
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
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: BrandColors.sunriseGold))
                    : FadeTransition(
                        opacity: _fadeIn,
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildOverviewTab(),
                            _buildCompetitivenessTab(),
                            _buildDemographicsTab(),
                            _buildEngagementTab(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Candidate Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '2026 Cycle',
              style: TextStyle(
                color: BrandColors.sunriseGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: BrandColors.sunriseGold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: BrandColors.sunriseGold,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Competitiveness'),
          Tab(text: 'Demographics'),
          Tab(text: 'Engagement'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1: OVERVIEW — Key metrics and charts
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Key metrics grid
        _buildMetricsGrid(),
        const SizedBox(height: 16),

        // Party breakdown pie chart
        _buildPartyPieChart(),
        const SizedBox(height: 16),

        // Office level breakdown
        _buildOfficeLevelChart(),
        const SizedBox(height: 16),

        // Map overview
        MissouriMapWidget(
          districtMap: _districtMap,
          height: 280,
          interactive: false,
          showLegend: true,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        _metricCard('Total Filed', '${_stats.totalCandidates}',
            Icons.people, BrandColors.momentumBlue),
        _metricCard('Democrats', '${_stats.democrats}',
            Icons.how_to_vote, BrandColors.democratBlue),
        _metricCard('Republicans', '${_stats.republicans}',
            Icons.how_to_vote, BrandColors.republicanRed),
        _metricCard('Young Dems', '${_stats.youngDemocrats}',
            Icons.star, BrandColors.sunriseGold),
        _metricCard('Endorsed', '${_stats.endorsed}',
            Icons.thumb_up, BrandColors.success),
        _metricCard('Contacted', '${_stats.contacted}',
            Icons.phone, Colors.purpleAccent),
        _metricCard(
          'Avg YD Age',
          _stats.averageYdAge > 0
              ? _stats.averageYdAge.toStringAsFixed(1)
              : '—',
          Icons.cake,
          Colors.amber,
        ),
        _metricCard(
          'Uncontested D',
          '${_stats.uncontestedDemSeats}',
          Icons.check_circle,
          BrandColors.success,
        ),
        _metricCard(
          'With Website',
          '${_stats.withWebsite}',
          Icons.language,
          BrandColors.steelBlue,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.unityBlue.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildPartyPieChart() {
    final total = _stats.totalCandidates;
    if (total == 0) return const SizedBox.shrink();

    final dems = _stats.democrats;
    final reps = _stats.republicans;
    final others = total - dems - reps;

    return _analyticsCard(
      'Party Breakdown',
      Icons.pie_chart,
      BrandColors.momentumBlue,
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: BrandColors.democratBlue,
                      value: dems.toDouble(),
                      title: '$dems',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      radius: 60,
                    ),
                    PieChartSectionData(
                      color: BrandColors.republicanRed,
                      value: reps.toDouble(),
                      title: '$reps',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      radius: 60,
                    ),
                    if (others > 0)
                      PieChartSectionData(
                        color: Colors.amber,
                        value: others.toDouble(),
                        title: '$others',
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        radius: 60,
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendRow('Democrat', BrandColors.democratBlue,
                    '${(dems / total * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                _legendRow('Republican', BrandColors.republicanRed,
                    '${(reps / total * 100).toStringAsFixed(1)}%'),
                if (others > 0) ...[
                  const SizedBox(height: 8),
                  _legendRow('Other', Colors.amber,
                      '${(others / total * 100).toStringAsFixed(1)}%'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label $value',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOfficeLevelChart() {
    if (_partyBreakdown.isEmpty) return const SizedBox.shrink();

    return _analyticsCard(
      'By Office Level',
      Icons.account_balance,
      BrandColors.steelBlue,
      child: Column(
        children: _partyBreakdown.entries.map((entry) {
          final level = entry.key;
          final parties = entry.value;
          final dems = parties['Democratic'] ?? 0;
          final reps = parties['Republican'] ?? 0;
          final total = dems + reps;
          if (total == 0) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      level.substring(0, 1).toUpperCase() + level.substring(1),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'D: $dems  R: $reps',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: dems.clamp(1, 999),
                          child: Container(color: BrandColors.democratBlue),
                        ),
                        Expanded(
                          flex: reps.clamp(1, 999),
                          child: Container(color: BrandColors.republicanRed),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2: COMPETITIVENESS — Race ratings
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompetitivenessTab() {
    final contested = _contestation['contested'] ?? 0;
    final uDem = _contestation['uncontested_dem'] ?? 0;
    final uRep = _contestation['uncontested_rep'] ?? 0;
    final total = _contestation['total_districts'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contestation summary
        _analyticsCard(
          'Race Contestation',
          Icons.sports_score,
          Colors.amber,
          child: Column(
            children: [
              Row(
                children: [
                  _contestBadge('Contested', contested, Colors.amber),
                  _contestBadge('Uncontested (D)', uDem, BrandColors.democratBlue),
                  _contestBadge('Uncontested (R)', uRep, BrandColors.republicanRed),
                ],
              ),
              const SizedBox(height: 16),
              // Donut chart
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: [
                      if (contested > 0)
                        PieChartSectionData(
                          color: Colors.amber,
                          value: contested.toDouble(),
                          title: 'Contested\n$contested',
                          titleStyle: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          radius: 50,
                        ),
                      if (uDem > 0)
                        PieChartSectionData(
                          color: BrandColors.democratBlue,
                          value: uDem.toDouble(),
                          title: 'D Only\n$uDem',
                          titleStyle: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          radius: 50,
                        ),
                      if (uRep > 0)
                        PieChartSectionData(
                          color: BrandColors.republicanRed,
                          value: uRep.toDouble(),
                          title: 'R Only\n$uRep',
                          titleStyle: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          radius: 50,
                        ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 35,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$total districts with filings',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Opportunity districts — Dem-only (no Republican challenger)
        _analyticsCard(
          'Opportunity Districts (Uncontested D)',
          Icons.emoji_events,
          BrandColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Districts where a Democrat filed but no Republican — guaranteed wins.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ..._districtMap.entries
                  .where((e) {
                    final hasDem = e.value.any((c) => c.isDemocrat);
                    final hasRep = e.value.any((c) => c.isRepublican);
                    return hasDem && !hasRep;
                  })
                  .take(15)
                  .map((e) => _districtRow(e.key, e.value, BrandColors.success)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Vulnerability districts — Rep-only (no Dem challenger)
        _analyticsCard(
          'Vulnerability Districts (Uncontested R)',
          Icons.warning_amber,
          BrandColors.republicanRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Districts where only a Republican filed — recruit opportunities!',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ..._districtMap.entries
                  .where((e) {
                    final hasDem = e.value.any((c) => c.isDemocrat);
                    final hasRep = e.value.any((c) => c.isRepublican);
                    return !hasDem && hasRep;
                  })
                  .take(15)
                  .map((e) =>
                      _districtRow(e.key, e.value, BrandColors.republicanRed)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Young Dem districts
        _analyticsCard(
          'Young Democrat Districts',
          Icons.star,
          BrandColors.sunriseGold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Districts with identified Young Democrat candidates.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ..._districtMap.entries
                  .where((e) => e.value.any((c) => c.isYoungDem))
                  .map((e) =>
                      _districtRow(e.key, e.value, BrandColors.sunriseGold)),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _contestBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _districtRow(String district, List<Candidate> candidates, Color accent) {
    final hasYd = candidates.any((c) => c.isYoungDem);
    final demNames = candidates
        .where((c) => c.isDemocrat)
        .map((c) => c.name)
        .join(', ');
    final repNames = candidates
        .where((c) => c.isRepublican)
        .map((c) => c.name)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              district,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (demNames.isNotEmpty)
                  Text(
                    'D: $demNames',
                    style: TextStyle(
                      color: BrandColors.democratBlue.withOpacity(0.8),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (repNames.isNotEmpty)
                  Text(
                    'R: $repNames',
                    style: TextStyle(
                      color: BrandColors.republicanRed.withOpacity(0.8),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (hasYd)
            const Icon(Icons.star, color: BrandColors.sunriseGold, size: 14),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3: DEMOGRAPHICS — Age distribution, categories
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDemographicsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Age distribution
        _analyticsCard(
          'Age Distribution',
          Icons.cake,
          Colors.purpleAccent,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxAgeCount.toDouble() * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: BrandColors.unityBlue,
                        getTooltipItem: (group, gIdx, rod, rIdx) {
                          final labels = ['<25', '25-35', '36-50', '51-65', '65+', '?'];
                          return BarTooltipItem(
                            '${labels[group.x]}\n${rod.toY.round()}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const labels = ['<25', '25-35', '36-50', '51-65', '65+', '?'];
                            if (value.toInt() >= 0 && value.toInt() < labels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  labels[value.toInt()],
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.white.withOpacity(0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _ageBarGroups,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Young Dem age breakdown
        _analyticsCard(
          'Young Democrat Insights',
          Icons.star,
          BrandColors.sunriseGold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _insightRow(
                'Average Age',
                _stats.averageYdAge > 0
                    ? _stats.averageYdAge.toStringAsFixed(1)
                    : 'N/A',
                Icons.cake,
              ),
              _insightRow(
                'Total Young Dems',
                '${_stats.youngDemocrats}',
                Icons.people,
              ),
              _insightRow(
                '% of All Dems',
                _stats.democrats > 0
                    ? '${(_stats.youngDemocrats / _stats.democrats * 100).toStringAsFixed(1)}%'
                    : '0%',
                Icons.pie_chart,
              ),
              _insightRow(
                'With Websites',
                '${_allCandidates.where((c) => c.isYoungDem && c.campaignWebsite != null && c.campaignWebsite!.isNotEmpty).length}',
                Icons.language,
              ),
              _insightRow(
                'With Social Media',
                '${_allCandidates.where((c) => c.isYoungDem && c.hasSocialLinks).length}',
                Icons.share,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Top office targets
        _analyticsCard(
          'Filing Breakdown by Office',
          Icons.account_balance,
          BrandColors.steelBlue,
          child: _buildOfficeBreakdown(),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  int get _maxAgeCount {
    final dist = _stats.ageDistribution;
    return [
      dist['under25'] ?? 0,
      dist['25-35'] ?? 0,
      dist['36-50'] ?? 0,
      dist['51-65'] ?? 0,
      dist['over65'] ?? 0,
      dist['unknown'] ?? 0,
    ].reduce(math.max);
  }

  List<BarChartGroupData> get _ageBarGroups {
    final dist = _stats.ageDistribution;
    final values = [
      dist['under25'] ?? 0,
      dist['25-35'] ?? 0,
      dist['36-50'] ?? 0,
      dist['51-65'] ?? 0,
      dist['over65'] ?? 0,
      dist['unknown'] ?? 0,
    ];
    final colors = [
      BrandColors.sunriseGold,
      BrandColors.momentumBlue,
      BrandColors.democratBlue,
      BrandColors.steelBlue,
      Colors.grey,
      Colors.white24,
    ];

    return List.generate(values.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: values[i].toDouble(),
            color: colors[i],
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget _insightRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeBreakdown() {
    final officeCounts = <String, int>{};
    for (final c in _allCandidates) {
      final level = c.officeLevel ?? 'other';
      officeCounts[level] = (officeCounts[level] ?? 0) + 1;
    }
    final sorted = officeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((entry) {
        final total = _allCandidates.length;
        final pct = total > 0 ? entry.value / total : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    '${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(BrandColors.momentumBlue),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 4: ENGAGEMENT — MOYD outreach metrics
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEngagementTab() {
    final contactedPct = _stats.contactedPercent;
    final endorsedCount = _stats.endorsed;
    final totalDems = _stats.democrats;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Outreach progress
        _analyticsCard(
          'Outreach Progress',
          Icons.campaign,
          BrandColors.sunriseGold,
          child: Column(
            children: [
              _progressRing(
                'Candidates Contacted',
                contactedPct / 100,
                '${contactedPct.toStringAsFixed(0)}%',
                BrandColors.sunriseGold,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _engagementStat(
                    'Contacted',
                    '${_stats.contacted}',
                    BrandColors.success,
                  ),
                  _engagementStat(
                    'Not Yet',
                    '${_stats.totalCandidates - _stats.contacted}',
                    Colors.white70,
                  ),
                  _engagementStat(
                    'Endorsed',
                    '$endorsedCount',
                    BrandColors.sunriseGold,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Endorsement funnel
        _analyticsCard(
          'Endorsement Funnel',
          Icons.thumb_up,
          BrandColors.success,
          child: Column(
            children: [
              _funnelRow('Total Democrats', totalDems, 1.0, BrandColors.democratBlue),
              _funnelRow('Contacted', _stats.contacted, totalDems > 0 ? _stats.contacted / totalDems : 0, BrandColors.momentumBlue),
              _funnelRow('Endorsed', endorsedCount, totalDems > 0 ? endorsedCount / totalDems : 0, BrandColors.success),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action items
        _analyticsCard(
          'Action Items',
          Icons.checklist,
          Colors.purpleAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _actionItem(
                'Young Dems not yet contacted',
                _allCandidates
                    .where((c) => c.isYoungDem && !c.isContacted)
                    .length,
                Icons.phone_missed,
                Colors.amber,
              ),
              _actionItem(
                'Dems without campaign website',
                _allCandidates
                    .where((c) =>
                        c.isDemocrat &&
                        (c.campaignWebsite == null || c.campaignWebsite!.isEmpty))
                    .length,
                Icons.language,
                BrandColors.steelBlue,
              ),
              _actionItem(
                'Candidates with no social media',
                _allCandidates
                    .where((c) => c.isDemocrat && !c.hasSocialLinks)
                    .length,
                Icons.share,
                Colors.purpleAccent,
              ),
              _actionItem(
                'Uncontested Republican seats',
                _contestation['uncontested_rep'] ?? 0,
                Icons.warning_amber,
                BrandColors.republicanRed,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _progressRing(String label, double progress, String centerText, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                centerText,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _engagementStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _funnelRow(String label, int count, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                '$count (${(pct * 100).toStringAsFixed(0)}%)',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionItem(String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared card builder ──────────────────────────────────────

  Widget _analyticsCard(String title, IconData icon, Color accent,
      {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.unityBlue.withOpacity(0.85),
          ],
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
