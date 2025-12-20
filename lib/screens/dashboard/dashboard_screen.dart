import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/dashboard_metrics.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:bluebubbles/services/crm/dashboard_metrics_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/screens/dashboard/widgets/quick_links_dialog.dart';

// Brand colors matching meetings/committees pages
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final QuickLinksRepository _quickLinksRepo = QuickLinksRepository();
  final DashboardMetricsService _metricsService = DashboardMetricsService();

  DashboardMetrics? _metrics;
  List<Member> _recentMembers = [];
  int _chatCount = 0;
  int _totalMessages = 0;
  int _weeklyMessages = 0;
  bool _loading = true;
  String? _error;
  String _selectedMetric = 'counties';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!CRMConfig.crmEnabled || !_supabaseService.isInitialized) {
      setState(() {
        _loading = false;
        _metrics = DashboardMetrics.empty;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final weeklySince = DateTime.now().subtract(const Duration(days: 7));

      // Fetch metrics from new table and BlueBubbles data in parallel
      final results = await Future.wait<dynamic>([
        _metricsService.fetchMetrics(),
        _fetchChatCount(),
        _fetchMessageCount(),
        _fetchMessageCount(after: weeklySince),
        _memberRepo.getRecentMembers(limit: 5),
      ]);

      final metrics = results[0] as DashboardMetrics?;
      final chatCount = (results[1] as int?) ?? 0;
      final totalMessages = (results[2] as int?) ?? 0;
      final weeklyMessages = (results[3] as int?) ?? 0;
      final recentMembers = (results[4] as List<Member>?) ?? [];

      if (!mounted) return;

      setState(() {
        _metrics = metrics ?? DashboardMetrics.empty;
        _chatCount = chatCount;
        _totalMessages = totalMessages;
        _weeklyMessages = weeklyMessages;
        _recentMembers = recentMembers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<int> _fetchChatCount() async {
    try {
      final Response<dynamic> response = await http.chatCount();
      return response.data['data']['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchMessageCount({DateTime? after}) async {
    try {
      final Response<dynamic> response = await http.messageCount(after: after);
      return response.data['data']['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void _openMembersList(BuildContext context, {bool showChaptersOnly = false}) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: MembersListScreen(showChaptersOnly: showChaptersOnly),
        ),
      ),
    );
  }

  void _openBulkMessaging(BuildContext context) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: BulkMessageScreen(),
        ),
      ),
    );
  }

  Future<void> _openQuickLinks(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => QuickLinksDialog(repository: _quickLinksRepo),
    );
    if (mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    return Stack(
      children: [
        // Background gradient
        Positioned.fill(
          child: Image.asset(
            'assets/images/Blue-Gradient-Background.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _actionRed),
            const SizedBox(height: 12),
            Text('Unable to load dashboard', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: _actionRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final metrics = _metrics ?? DashboardMetrics.empty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final horizontalPadding = isCompact ? 16.0 : 32.0;

        return SelectionArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Header
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildHeader(context, metrics),
                ),
              ),
              // Hero Stats Row
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildHeroStats(context, metrics),
                ),
              ),
              // Action Cards Grid
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildActionCards(context, metrics),
                ),
              ),
              // Interactive Chart
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildInteractiveChart(context, metrics),
                ),
              ),
              // Breakdown Cards
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildBreakdownSection(context, metrics),
                ),
              ),
              // Recent Members
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 32),
                sliver: SliverToBoxAdapter(
                  child: _buildRecentMembers(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, DashboardMetrics metrics) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _momentumBlue,
          ),
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              Text(
                'Real-time insights into your statewide organizing work',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh, color: _unityBlue),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildHeroStats(BuildContext context, DashboardMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 400;
        final isNarrow = constraints.maxWidth < 600;

        final stats = [
          _HeroStat(
            icon: Icons.people_alt,
            label: 'Total Members',
            value: metrics.totalMembers.toString(),
            color: _momentumBlue,
            onTap: () => _openMembersList(context),
          ),
          _HeroStat(
            icon: Icons.map_outlined,
            label: 'Counties',
            value: '${metrics.countiesRepresented} / 114',
            color: _sunriseGold,
            onTap: () => _openMembersList(context),
          ),
          _HeroStat(
            icon: Icons.flag,
            label: 'Chapters',
            value: metrics.charteredChapters.toString(),
            color: _grassrootsGreen,
            onTap: () => _openMembersList(context, showChaptersOnly: true),
          ),
        ];

        if (isVeryNarrow) {
          return Column(
            children: stats.map((stat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildHeroStatTile(stat),
            )).toList(),
          );
        }

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildHeroStatCard(stats[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildHeroStatCard(stats[1])),
                ],
              ),
              const SizedBox(height: 12),
              _buildHeroStatCard(stats[2]),
            ],
          );
        }

        return Row(
          children: stats.map((stat) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildHeroStatCard(stat),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildHeroStatCard(_HeroStat stat) {
    return Card(
      elevation: 4,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [_unityBlue, stat.color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(stat.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                stat.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat.label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatTile(_HeroStat stat) {
    return Card(
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [_unityBlue, stat.color.withOpacity(0.7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stat.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      stat.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCards(BuildContext context, DashboardMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 2 : 1;

        final cards = [
          _ActionCard(
            title: 'Members with Phones',
            value: metrics.membersWithPhone,
            icon: Icons.phone_in_talk,
            description: 'Ready for outreach',
            gradient: [_momentumBlue, _justicePurple],
            onTap: () => _openMembersList(context),
          ),
          _ActionCard(
            title: 'Quick Links',
            icon: Icons.link,
            description: 'Shared resources & documents',
            gradient: [_grassrootsGreen, _momentumBlue],
            onTap: () => _openQuickLinks(context),
          ),
          _ActionCard(
            title: 'Active Conversations',
            value: _chatCount,
            icon: Icons.forum,
            description: 'Current BlueBubbles chats',
            gradient: [_sunriseGold, _actionRed],
            onTap: () => _openBulkMessaging(context),
          ),
          _ActionCard(
            title: 'Total Messages',
            value: _totalMessages,
            icon: Icons.message,
            description: 'All-time messages sent',
            gradient: [_justicePurple, _momentumBlue],
            onTap: () => _openBulkMessaging(context),
          ),
        ];

        if (isCompact) {
          return SizedBox(
            height: 200,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.88),
              itemCount: cards.length,
              padEnds: false,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: index == cards.length - 1 ? 0 : 12),
                  child: _buildActionCard(cards[index]),
                );
              },
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.4,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => _buildActionCard(cards[index]),
        );
      },
    );
  }

  Widget _buildActionCard(_ActionCard card) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: card.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: card.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(card.icon, color: Colors.white, size: 28),
              const Spacer(),
              if (card.value != null) ...[
                Text(
                  _formatNumber(card.value!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                card.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveChart(BuildContext context, DashboardMetrics metrics) {
    final theme = Theme.of(context);

    final metricLabels = <String, String>{
      'counties': 'Top Counties',
      'districts': 'Top Districts',
      'committees': 'Committees',
      'highSchools': 'High Schools',
      'colleges': 'Colleges',
      'chapters': 'Chapters',
      'chapterStatuses': 'Chapter Status',
      'graduationYears': 'Graduation Years',
      'ageBuckets': 'Age Distribution',
      'sexualOrientations': 'Sexual Orientation',
      'pronouns': 'Pronouns',
      'genders': 'Gender Identity',
      'races': 'Race & Ethnicity',
      'languages': 'Languages',
      'communityTypes': 'Community Type',
      'industries': 'Industries',
      'educationLevels': 'Education Level',
      'registeredVoters': 'Voter Registration',
    };

    final metricValues = <String, Map<String, int>>{
      'counties': metrics.membersByCounty,
      'districts': metrics.membersByDistrict,
      'committees': metrics.membersByCommittee,
      'highSchools': metrics.membersByHighSchool,
      'colleges': metrics.membersByCollege,
      'chapters': metrics.membersByChapter,
      'chapterStatuses': metrics.membersByChapterStatus,
      'graduationYears': metrics.membersByGraduationYear,
      'ageBuckets': metrics.membersByAgeBucket,
      'sexualOrientations': metrics.membersBySexualOrientation,
      'pronouns': metrics.membersByPronoun,
      'genders': metrics.membersByGender,
      'races': metrics.membersByRace,
      'languages': metrics.membersByLanguage,
      'communityTypes': metrics.membersByCommunityType,
      'industries': metrics.membersByIndustry,
      'educationLevels': metrics.membersByEducationLevel,
      'registeredVoters': metrics.membersByVoterStatus,
    };

    final unsortedMetrics = {'ageBuckets', 'graduationYears'};

    final selectedData = metricValues[_selectedMetric] ?? const {};
    final entries = selectedData.entries
        .where((element) => element.value > 0)
        .toList();

    if (!unsortedMetrics.contains(_selectedMetric)) {
      entries.sort((a, b) => b.value.compareTo(a.value));
    }
    final topEntries = entries.take(8).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart, color: _momentumBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Member Distribution',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _unityBlue,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedMetric,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMetric = value);
                    }
                  },
                  items: metricLabels.entries
                      .map((entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (topEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No data available for ${metricLabels[_selectedMetric] ?? 'selected metric'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              _buildBarChart(topEntries),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _openMembersList(context),
              icon: const Icon(Icons.insights_outlined, color: _momentumBlue),
              label: const Text(
                'View members in this segment',
                style: TextStyle(color: _momentumBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<MapEntry<String, int>> entries) {
    final maxValue = entries.fold<int>(0, (prev, e) => e.value > prev ? e.value : prev);

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxValue * 1.2).clamp(1, double.infinity).toDouble(),
          barGroups: List.generate(entries.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entries[index].value.toDouble(),
                  width: 20,
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [_momentumBlue, _justicePurple],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final label = entries[index].key;
                  final displayLabel = label.length > 12 ? '${label.substring(0, 11)}…' : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      displayLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: _unityBlue),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11, color: _unityBlue),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: _unityBlue.withOpacity(0.9),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final entry = entries[groupIndex];
                return BarTooltipItem(
                  '${entry.key}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '${entry.value} members',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownSection(BuildContext context, DashboardMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final useCarousel = constraints.maxWidth < 600;

        final breakdowns = [
          _BreakdownData(
            title: 'Donations',
            icon: Icons.volunteer_activism,
            color: _grassrootsGreen,
            items: [
              _BreakdownItem('Total Donations', metrics.totalDonations.toString()),
              _BreakdownItem('Total Amount', '\$${_formatNumber(metrics.totalDonationAmount.toInt())}'),
              _BreakdownItem('This Month', metrics.donationsThisMonth.toString()),
            ],
          ),
          _BreakdownData(
            title: 'Events & Forms',
            icon: Icons.event,
            color: _sunriseGold,
            items: [
              _BreakdownItem('Total Events', metrics.totalEvents.toString()),
              _BreakdownItem('Upcoming', metrics.upcomingEvents.toString()),
              _BreakdownItem('Form Submissions', metrics.formSubmissionsThisMonth.toString()),
            ],
          ),
          _BreakdownData(
            title: 'Meetings',
            icon: Icons.video_camera_front_outlined,
            color: _momentumBlue,
            items: [
              _BreakdownItem('Total Meetings', metrics.totalMeetings.toString()),
              _BreakdownItem('This Month', metrics.meetingsThisMonth.toString()),
              _BreakdownItem('Attendance Records', metrics.totalAttendanceRecords.toString()),
            ],
          ),
          _BreakdownData(
            title: 'Messaging',
            icon: Icons.message,
            color: _justicePurple,
            items: [
              _BreakdownItem('Total Messages', _formatNumber(_totalMessages)),
              _BreakdownItem('This Week', _formatNumber(_weeklyMessages)),
              _BreakdownItem('Active Chats', _chatCount.toString()),
            ],
          ),
        ];

        if (useCarousel) {
          return SizedBox(
            height: 200,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: breakdowns.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: index == breakdowns.length - 1 ? 0 : 12),
                child: _buildBreakdownCard(breakdowns[index]),
              ),
            ),
          );
        }

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: breakdowns.map((data) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildBreakdownCard(data),
              ),
            )).toList(),
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: breakdowns.map((data) => SizedBox(
            width: (constraints.maxWidth - 16) / 2,
            child: _buildBreakdownCard(data),
          )).toList(),
        );
      },
    );
  }

  Widget _buildBreakdownCard(_BreakdownData data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, color: data.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _unityBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: _unityBlue.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMembers(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _grassrootsGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_add, color: _grassrootsGreen),
                ),
                const SizedBox(width: 12),
                Text(
                  'Newest Members',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_recentMembers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No recent members yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ..._recentMembers.map((member) => _buildMemberTile(member)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _openMembersList(context),
              icon: const Icon(Icons.people_alt_outlined, color: _momentumBlue),
              label: const Text(
                'View all members',
                style: TextStyle(color: _momentumBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Member member) {
    final theme = Theme.of(context);
    final details = [
      if (member.county != null && member.county!.isNotEmpty) member.county!,
      if (member.congressionalDistrict != null)
        Member.formatDistrictLabel(member.congressionalDistrict) ?? member.congressionalDistrict!,
    ];

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (_) => TitleBarWrapper(
              child: MemberDetailScreen(member: member),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _unityBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _momentumBlue.withOpacity(0.2),
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: _momentumBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _unityBlue.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (member.createdAt != null)
              Text(
                _timeAgo(member.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _unityBlue.withOpacity(0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  static String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}

class _HeroStat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
}

class _ActionCard {
  final String title;
  final int? value;
  final IconData icon;
  final String description;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    this.value,
    required this.icon,
    required this.description,
    required this.gradient,
    this.onTap,
  });
}

class _BreakdownData {
  final String title;
  final IconData icon;
  final Color color;
  final List<_BreakdownItem> items;

  const _BreakdownData({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _BreakdownItem {
  final String label;
  final String value;

  const _BreakdownItem(this.label, this.value);
}
