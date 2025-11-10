import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/screens/dashboard/widgets/quick_links_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final QuickLinksRepository _quickLinksRepo = QuickLinksRepository();

  _DashboardData? _data;
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
        _data = const _DashboardData.empty();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final memberStats = await _memberRepo.getMemberStats();
      final counties = await _memberRepo.getCountyCounts();
      final districts = await _memberRepo.getDistrictCounts();
      final committees = await _memberRepo.getCommitteeCounts();
      final highSchools = await _memberRepo.getHighSchoolCounts();
      final colleges = await _memberRepo.getCollegeCounts();
      final chapters = await _memberRepo.getChapterCounts();
      final chapterStatuses = await _memberRepo.getChapterStatusCounts();
      final graduationYears = await _memberRepo.getGraduationYearCounts();
      final pronouns = await _memberRepo.getPronounCounts();
      final genders = await _memberRepo.getGenderIdentityCounts();
      final races = await _memberRepo.getRaceCounts();
      final languages = await _memberRepo.getLanguageCounts();
      final communityTypes = await _memberRepo.getCommunityTypeCounts();
      final industries = await _memberRepo.getIndustryCounts();
      final educationLevels = await _memberRepo.getEducationLevelCounts();
      final registeredVoters = await _memberRepo.getRegisteredVoterCounts();
      final sexualOrientations = await _memberRepo.getSexualOrientationCounts();
      final ageBuckets = await _memberRepo.getAgeBucketCounts();
      final recentMembers = await _memberRepo.getRecentMembers(limit: 6);

      final chatCount = await _fetchChatCount();
      final totalMessages = await _fetchMessageCount();
      final weeklyMessages = await _fetchMessageCount(
        after: DateTime.now().subtract(const Duration(days: 7)),
      );
      final quickLinksCount = await _quickLinksRepo.countQuickLinks();

      setState(() {
        _data = _DashboardData(
          totalMembers: memberStats['total'] as int? ?? 0,
          contactableMembers: memberStats['contactable'] as int? ?? 0,
          optedOutMembers: memberStats['optedOut'] as int? ?? 0,
          withPhoneMembers: memberStats['withPhone'] as int? ?? 0,
          chatCount: chatCount,
          totalMessages: totalMessages,
          weeklyMessages: weeklyMessages,
          quickLinksCount: quickLinksCount,
          counties: counties,
          districts: districts,
          committees: committees,
          highSchools: highSchools,
          colleges: colleges,
          chapters: chapters,
          chapterStatuses: chapterStatuses,
          graduationYears: graduationYears,
          pronouns: pronouns,
          genders: genders,
          races: races,
          languages: languages,
          communityTypes: communityTypes,
          industries: industries,
          educationLevels: educationLevels,
          registeredVoters: registeredVoters,
          sexualOrientations: sexualOrientations,
          ageBuckets: ageBuckets,
          recentMembers: recentMembers,
        );
        _loading = false;
      });
    } catch (e) {
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

  void _openCountiesView(BuildContext context) {
    _openMembersList(context);
  }

  void _openChaptersView(BuildContext context) {
    _openMembersList(context, showChaptersOnly: true);
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
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Text('Unable to load dashboard', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data ?? const _DashboardData.empty();

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth > 1200
              ? EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.1, vertical: 32)
              : const EdgeInsets.fromLTRB(24, 24, 24, 32);

          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: padding,
            children: [
              _buildHeader(context, theme, data),
              const SizedBox(height: 24),
              _buildStatsGrid(context, data),
              const SizedBox(height: 32),
              _buildInteractiveChart(context, data),
              const SizedBox(height: 32),
              _buildBreakdownRow(context, data),
              const SizedBox(height: 32),
              _buildRecentMembers(context, data.recentMembers),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, _DashboardData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, Missouri Young Democrats!',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time insights into your statewide organizing work.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _HeaderPill(
                label: 'Total Members',
                valueText: data.totalMembers.toString(),
                icon: Icons.people_alt,
                onTap: () => _openMembersList(context),
                semanticsLabel: '${data.totalMembers} total members',
              ),
              _HeaderPill(
                label: 'Counties Represented',
                valueText: '${data.countiesRepresented} / 114',
                icon: Icons.map_outlined,
                onTap: () => _openCountiesView(context),
                semanticsLabel:
                    '${data.countiesRepresented} of 114 Missouri counties represented',
              ),
              _HeaderPill(
                label: 'Chartered Chapters',
                valueText: data.charteredChapters.toString(),
                icon: Icons.flag,
                onTap: () => _openChaptersView(context),
                semanticsLabel: '${data.charteredChapters} chartered chapters',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);

    /// Design refresh plan for stats grid:
    /// - Introduce carousel navigation on compact layouts (implemented for <480 px widths).
    /// - Maintain responsive tiles that collapse into a single column when space tightens.
    /// - Add quick-action CTAs so each metric routes straight into deeper CRM workflows.
    final cards = [
      _StatCardData(
        title: 'Members with Phone Numbers',
        value: data.withPhoneMembers,
        icon: Icons.phone_in_talk,
        description: 'Ready for outreach',
        colors: [theme.colorScheme.secondary, theme.colorScheme.tertiary],
        actionLabel: 'View members with phones',
        semanticsLabel: '${data.withPhoneMembers} members with phone numbers',
        onTap: (context) => _openMembersList(context),
      ),
      _StatCardData(
        title: 'Quick Links',
        value: data.quickLinksCount,
        icon: Icons.link,
        description: 'Shared resources ready to launch',
        colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primary],
        actionLabel: 'Open quick links',
        semanticsLabel: '${data.quickLinksCount} quick links available',
        onTap: (context) => _openQuickLinks(context),
      ),
      _StatCardData(
        title: 'Active Conversations',
        value: data.chatCount,
        icon: Icons.forum,
        description: 'Current chats on BlueBubbles',
        colors: [theme.colorScheme.primary, theme.colorScheme.secondaryContainer],
        actionLabel: 'Open messaging hub',
        semanticsLabel: '${data.chatCount} active conversations',
        onTap: (context) => _openBulkMessaging(context),
      ),
      _StatCardData(
        title: 'Total Messages',
        value: data.totalMessages,
        icon: Icons.message,
        description: 'All-time across every channel',
        colors: [theme.colorScheme.tertiary, theme.colorScheme.primaryContainer],
        actionLabel: 'Review outreach analytics',
        semanticsLabel: '${data.totalMessages} total messages sent',
        onTap: (context) => _openBulkMessaging(context),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;

        if (isCompact) {
          return SizedBox(
            height: 240,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.88),
              itemCount: cards.length,
              padEnds: false,
              itemBuilder: (context, index) {
                final card = cards[index];
                return Padding(
                  padding: EdgeInsets.only(right: index == cards.length - 1 ? 0 : 12),
                  child: _StatCard(
                    data: card,
                    onTap: () => card.onTap(context),
                    actionLabel: card.actionLabel,
                    semanticsLabel: card.semanticsLabel,
                  ),
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
            crossAxisSpacing: constraints.maxWidth > 800 ? 20 : 16,
            mainAxisSpacing: constraints.maxWidth > 800 ? 20 : 16,
            childAspectRatio: crossAxisCount == 1
                ? 1.2
                : crossAxisCount == 2
                    ? 1.28
                    : 1.34,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return _StatCard(
              data: card,
              onTap: () => card.onTap(context),
              actionLabel: card.actionLabel,
              semanticsLabel: card.semanticsLabel,
            );
          },
        );
      },
    );
  }

  Widget _buildInteractiveChart(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);

    /// Design refresh plan for interactive chart:
    /// - Support swipeable cards under 480 px so organizers can flip between visualization and insights.
    /// - Pair the chart with a summary tile highlighting the same dataset for quicker scanning.
    /// - Provide contextual quick actions to jump from analytics into the related CRM lists.
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
      'counties': data.counties,
      'districts': data.districts,
      'committees': data.committees,
      'highSchools': data.highSchools,
      'colleges': data.colleges,
      'chapters': data.chapters,
      'chapterStatuses': data.chapterStatuses,
      'graduationYears': data.graduationYears,
      'ageBuckets': data.ageBuckets,
      'sexualOrientations': data.sexualOrientations,
      'pronouns': data.pronouns,
      'genders': data.genders,
      'races': data.races,
      'languages': data.languages,
      'communityTypes': data.communityTypes,
      'industries': data.industries,
      'educationLevels': data.educationLevels,
      'registeredVoters': data.registeredVoters,
    };

    final unsortedMetrics = {'ageBuckets'};

    final selectedData = metricValues[_selectedMetric] ?? const {};
    final entries = selectedData.entries
        .where((element) => element.value > 0)
        .toList();

    if (!unsortedMetrics.contains(_selectedMetric)) {
      entries.sort((a, b) => b.value.compareTo(a.value));
    }
    final topEntries = entries.take(8).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;
        final isWide = constraints.maxWidth > 900;

        Widget buildDropdown() {
          return DropdownButton<String>(
            value: _selectedMetric,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMetric = value);
              }
            },
            items: metricLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
          );
        }

        if (topEntries.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Member Distribution',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      buildDropdown(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No data available for ${metricLabels[_selectedMetric] ?? 'selected metric'}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openMembersList(context),
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('View members'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final maxValue = topEntries.fold<int>(0, (prev, element) => element.value > prev ? element.value : prev);
        final barGroups = List.generate(topEntries.length, (index) {
          final entry = topEntries[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                width: 18,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        });

        String formatLabel(String label) {
          const maxChars = 14;
          if (label.length <= maxChars) return label;
          return '${label.substring(0, maxChars - 1)}…';
        }

        Widget buildChartCard() {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Member Distribution',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      buildDropdown(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: isCompact ? 240 : 280,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (maxValue * 1.2).clamp(1, double.infinity).toDouble(),
                        barGroups: barGroups,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: !isCompact, // Hide labels on mobile to prevent overlap
                              reservedSize: 52,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= topEntries.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = formatLabel(topEntries[index].key);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall,
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
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: theme.colorScheme.surfaceVariant.withOpacity(0.9),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final entry = topEntries[groupIndex];
                              return BarTooltipItem(
                                '${entry.key}\n',
                                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold) ??
                                    const TextStyle(fontWeight: FontWeight.bold),
                                children: [
                                  TextSpan(
                                    text: '${entry.value} members',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openMembersList(context),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('View members in this segment'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildSummaryCard() {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${metricLabels[_selectedMetric] ?? 'Segment'} Snapshot',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...topEntries.mapIndexed(
                    (index, entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${entry.value} members',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openMembersList(context),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Explore full list'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final chartCard = buildChartCard();
        final summaryCard = buildSummaryCard();

        if (isCompact) {
          return SizedBox(
            height: 360,
            child: PageView(
              controller: PageController(viewportFraction: 0.92),
              children: [
                chartCard,
                summaryCard,
              ],
            ),
          );
        }

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: chartCard),
              const SizedBox(width: 24),
              SizedBox(width: 320, child: summaryCard),
            ],
          );
        }

        return Column(
          children: [
            chartCard,
            const SizedBox(height: 16),
            summaryCard,
          ],
        );
      },
    );
  }

  Widget _buildBreakdownRow(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);

    /// Design refresh plan for breakdown row:
    /// - Allow swipe navigation on narrow screens so metrics remain discoverable without endless scrolling.
    /// - Keep wrap-based layout for desktops but collapse into a single column when necessary.
    /// - Attach quick-action buttons so organizers can jump straight to segmented member lists.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        final useCarousel = constraints.maxWidth < 600;

        final breakdowns = [
          _BreakdownCard(
            title: 'Top Counties',
            metricLabel: 'members',
            data: data.counties,
            total: data.totalMembers,
            accentColor: theme.colorScheme.primary,
            actionLabel: 'View counties',
            onViewDetails: () => _openCountiesView(context),
          ),
          _BreakdownCard(
            title: 'Top Districts',
            metricLabel: 'members',
            data: data.districts,
            total: data.totalMembers,
            accentColor: theme.colorScheme.secondary,
            actionLabel: 'View districts',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Committees',
            metricLabel: 'members',
            data: data.committees,
            total: data.totalMembers,
            accentColor: theme.colorScheme.tertiary,
            actionLabel: 'View committees',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Age Distribution',
            metricLabel: 'members',
            data: data.ageBuckets,
            total: data.ageBuckets.values.sum,
            accentColor: theme.colorScheme.primaryContainer,
            actionLabel: 'View age segments',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Sexual Orientation',
            metricLabel: 'responses',
            data: data.sexualOrientations,
            total: data.sexualOrientations.values.sum,
            accentColor: theme.colorScheme.secondaryContainer,
            actionLabel: 'View responses',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Pronouns',
            metricLabel: 'responses',
            data: data.pronouns,
            total: data.pronouns.values.sum,
            accentColor: theme.colorScheme.tertiaryContainer,
            actionLabel: 'View pronoun data',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Gender Identity',
            metricLabel: 'responses',
            data: data.genders,
            total: data.genders.values.sum,
            accentColor: theme.colorScheme.surfaceVariant,
            actionLabel: 'View gender data',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Race & Ethnicity',
            metricLabel: 'responses',
            data: data.races,
            total: data.races.values.sum,
            accentColor: theme.colorScheme.inversePrimary,
            actionLabel: 'View race data',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Languages',
            metricLabel: 'speakers',
            data: data.languages,
            total: data.languages.values.sum,
            accentColor: theme.colorScheme.secondaryContainer,
            actionLabel: 'View languages',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Community Type',
            metricLabel: 'responses',
            data: data.communityTypes,
            total: data.communityTypes.values.sum,
            accentColor: theme.colorScheme.surfaceVariant,
            actionLabel: 'View community types',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Industries',
            metricLabel: 'members',
            data: data.industries,
            total: data.industries.values.sum,
            accentColor: theme.colorScheme.primary,
            actionLabel: 'View industries',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Education',
            metricLabel: 'responses',
            data: data.educationLevels,
            total: data.educationLevels.values.sum,
            accentColor: theme.colorScheme.secondary,
            actionLabel: 'View education data',
            onViewDetails: () => _openMembersList(context),
          ),
          _BreakdownCard(
            title: 'Voter Registration',
            metricLabel: 'members',
            data: data.registeredVoters,
            total: data.registeredVoters.values.sum,
            accentColor: theme.colorScheme.errorContainer,
            actionLabel: 'View voter status',
            onViewDetails: () => _openMembersList(context),
          ),
        ];

        if (useCarousel) {
          return SizedBox(
            height: 260,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: breakdowns.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: index == breakdowns.length - 1 ? 0 : 12),
                child: breakdowns[index],
              ),
            ),
          );
        }

        if (isWide) {
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: breakdowns
                .map(
                  (card) => SizedBox(
                    width: (constraints.maxWidth - 24) / 2,
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Column(
          children: breakdowns
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentMembers(BuildContext context, List<Member> members) {
    final theme = Theme.of(context);

    /// Design refresh plan for recent members:
    /// - Introduce carousel behaviour on mobile so the latest joins are swipeable.
    /// - Adjust spacing and typography based on width to preserve readability.
    /// - Provide a direct action for staff to jump into the full members list.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isNarrow = maxWidth < 600;
        final isTablet = maxWidth >= 600 && maxWidth < 1024;
        final EdgeInsetsGeometry containerPadding = isNarrow
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
            : const EdgeInsets.all(24);
        final TextStyle? titleStyle = (isNarrow ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w700);
        final verticalSpacing = isNarrow ? 12.0 : 16.0;

        Widget buildContent() {
          if (members.isEmpty) {
            return Text(
              'No recent members yet. New sign-ups will appear here automatically.',
              style: theme.textTheme.bodyMedium,
              textAlign: isNarrow ? TextAlign.start : TextAlign.center,
            );
          }

          if (isNarrow) {
            return SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                padding: EdgeInsets.zero,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 180,
                  child: _RecentMemberTile(
                    member: members[index],
                    variant: _RecentMemberTileVariant.compact,
                    margin: EdgeInsets.zero,
                    showDetails: false,
                    showTimestamp: true,
                  ),
                ),
              ),
            );
          }

          if (isTablet) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 3.2,
              ),
              itemBuilder: (context, index) => _RecentMemberTile(
                member: members[index],
                variant: _RecentMemberTileVariant.medium,
                margin: EdgeInsets.zero,
                showTimestamp: true,
              ),
            );
          }

          return Column(
            children: members
                .map(
                  (member) => _RecentMemberTile(
                    member: member,
                    variant: _RecentMemberTileVariant.regular,
                  ),
                )
                .toList(),
          );
        }

        return Container(
          padding: containerPadding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Newest Members', style: titleStyle),
              SizedBox(height: verticalSpacing),
              buildContent(),
              SizedBox(height: verticalSpacing),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openMembersList(context),
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('View all members'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardData {
  final int totalMembers;
  final int contactableMembers;
  final int optedOutMembers;
  final int withPhoneMembers;
  final int chatCount;
  final int totalMessages;
  final int weeklyMessages;
  final int quickLinksCount;
  final Map<String, int> counties;
  final Map<String, int> districts;
  final Map<String, int> committees;
  final Map<String, int> highSchools;
  final Map<String, int> colleges;
  final Map<String, int> chapters;
  final Map<String, int> chapterStatuses;
  final Map<String, int> graduationYears;
  final Map<String, int> pronouns;
  final Map<String, int> genders;
  final Map<String, int> races;
  final Map<String, int> languages;
  final Map<String, int> communityTypes;
  final Map<String, int> industries;
  final Map<String, int> educationLevels;
  final Map<String, int> registeredVoters;
  final Map<String, int> sexualOrientations;
  final Map<String, int> ageBuckets;
  final List<Member> recentMembers;

  const _DashboardData({
    required this.totalMembers,
    required this.contactableMembers,
    required this.optedOutMembers,
    required this.withPhoneMembers,
    required this.chatCount,
    required this.totalMessages,
    required this.weeklyMessages,
    required this.quickLinksCount,
    required this.counties,
    required this.districts,
    required this.committees,
    required this.highSchools,
    required this.colleges,
    required this.chapters,
    required this.chapterStatuses,
    required this.graduationYears,
    required this.pronouns,
    required this.genders,
    required this.races,
    required this.languages,
    required this.communityTypes,
    required this.industries,
    required this.educationLevels,
    required this.registeredVoters,
    required this.sexualOrientations,
    required this.ageBuckets,
    required this.recentMembers,
  });

  const _DashboardData.empty()
      : totalMembers = 0,
        contactableMembers = 0,
        optedOutMembers = 0,
        withPhoneMembers = 0,
        chatCount = 0,
        totalMessages = 0,
        weeklyMessages = 0,
        quickLinksCount = 0,
        counties = const {},
        districts = const {},
        committees = const {},
        highSchools = const {},
        colleges = const {},
        chapters = const {},
        chapterStatuses = const {},
        graduationYears = const {},
        pronouns = const {},
        genders = const {},
        races = const {},
        languages = const {},
        communityTypes = const {},
        industries = const {},
        educationLevels = const {},
        registeredVoters = const {},
        sexualOrientations = const {},
        ageBuckets = const {},
        recentMembers = const [];

  int get countiesRepresented {
    final filtered = counties.entries
        .where((entry) => entry.value > 0 && entry.key.trim().toLowerCase() != 'unknown')
        .length;
    return filtered;
  }

  int get charteredChapters {
    final charteredFromStatuses = chapterStatuses.entries
        .where((entry) => entry.key.toLowerCase().contains('charter'))
        .fold<int>(0, (sum, entry) => sum + entry.value);

    if (charteredFromStatuses > 0) {
      return charteredFromStatuses;
    }

    final charteredByName = chapters.entries
        .where((entry) => entry.key.toLowerCase().contains('charter'))
        .length;

    if (charteredByName > 0) {
      return charteredByName;
    }

    return chapters.length;
  }
}

class _StatCardData {
  final String title;
  final int value;
  final IconData icon;
  final String description;
  final List<Color> colors;
  final String actionLabel;
  final String semanticsLabel;
  final void Function(BuildContext context) onTap;

  _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.description,
    required this.colors,
    required this.actionLabel,
    required this.semanticsLabel,
    required this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  final VoidCallback? onTap;
  final String? actionLabel;
  final String? semanticsLabel;

  const _StatCard({
    required this.data,
    this.onTap,
    this.actionLabel,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: onTap != null,
      label: semanticsLabel ?? '${data.value} ${data.title}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: data.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: data.colors.last.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 220 || constraints.maxWidth < 220;
                final valueStyle = (isCompact
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.displaySmall)
                    ?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                );
                final titleStyle = (isCompact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                );
                final bodyStyle = theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.85),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(data.icon, color: theme.colorScheme.onPrimary, size: isCompact ? 24 : 28),
                    const SizedBox(height: 16),
                    Text(data.title, style: titleStyle),
                    const SizedBox(height: 8),
                    Text(data.value.toString(), style: valueStyle),
                    const SizedBox(height: 6),
                    Text(data.description, style: bodyStyle),
                    const Spacer(),
                    if (onTap != null)
                      TextButton.icon(
                        onPressed: onTap,
                        icon: Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.onPrimary),
                        label: Text(
                          actionLabel ?? 'Open details',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: theme.colorScheme.onPrimary,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final String metricLabel;
  final Map<String, int> data;
  final int total;
  final Color accentColor;
  final VoidCallback? onViewDetails;
  final String actionLabel;

  const _BreakdownCard({
    required this.title,
    required this.metricLabel,
    required this.data,
    required this.total,
    required this.accentColor,
    this.onViewDetails,
    this.actionLabel = 'View details',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topEntries = data.entries
        .where((entry) => entry.value > 0)
        .take(6)
        .toList();

    return Semantics(
      label: '$title breakdown',
      button: onViewDetails != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onViewDetails,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.insights, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (topEntries.isEmpty)
                  Text(
                    'No data available yet.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  ...topEntries.mapIndexed((index, entry) {
                    final percentage = total == 0 ? 0.0 : (entry.value / total).clamp(0.0, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == topEntries.length - 1 ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('${entry.value} $metricLabel'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 6,
                              color: accentColor,
                              backgroundColor: accentColor.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                if (onViewDetails != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.search),
                    label: Text(actionLabel),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const _HeaderPill({
    required this.label,
    required this.valueText,
    required this.icon,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: onTap != null,
      label: semanticsLabel ?? '$valueText $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  '$valueText $label',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _RecentMemberTileVariant { compact, medium, regular }

class _RecentMemberTile extends StatelessWidget {
  final Member member;
  final _RecentMemberTileVariant variant;
  final EdgeInsetsGeometry? margin;
  final bool showDetails;
  final bool showTimestamp;

  const _RecentMemberTile({
    required this.member,
    this.variant = _RecentMemberTileVariant.regular,
    this.margin,
    this.showDetails = true,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (member.county != null && member.county!.isNotEmpty) member.county!,
      if (member.congressionalDistrict != null && member.congressionalDistrict!.isNotEmpty)
        Member.formatDistrictLabel(member.congressionalDistrict) ?? member.congressionalDistrict!,
    ];

    late final BorderRadius borderRadius;
    late final EdgeInsetsGeometry padding;
    late final double avatarRadius;
    late final double horizontalSpacing;
    TextStyle? nameStyle;
    TextStyle? avatarTextStyle;

    switch (variant) {
      case _RecentMemberTileVariant.compact:
        borderRadius = BorderRadius.circular(12);
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
        avatarRadius = 16;
        horizontalSpacing = 8;
        nameStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
        avatarTextStyle = theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        );
        break;
      case _RecentMemberTileVariant.medium:
        borderRadius = BorderRadius.circular(14);
        padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14);
        avatarRadius = 20;
        horizontalSpacing = 12;
        nameStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
        avatarTextStyle = theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        );
        break;
      case _RecentMemberTileVariant.regular:
        borderRadius = BorderRadius.circular(16);
        padding = const EdgeInsets.all(16);
        avatarRadius = 22;
        horizontalSpacing = 16;
        nameStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
        avatarTextStyle = theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        );
        break;
    }

    final EdgeInsetsGeometry effectiveMargin;
    switch (variant) {
      case _RecentMemberTileVariant.compact:
        effectiveMargin = margin ?? EdgeInsets.zero;
        break;
      case _RecentMemberTileVariant.medium:
        effectiveMargin = margin ?? const EdgeInsets.symmetric(vertical: 6);
        break;
      case _RecentMemberTileVariant.regular:
        effectiveMargin = margin ?? const EdgeInsets.symmetric(vertical: 8);
        break;
    }

    final bool shouldShowDetails = showDetails && details.isNotEmpty;
    final bool shouldShowTimestamp = showTimestamp && member.createdAt != null;

    return InkWell(
      borderRadius: borderRadius,
      onTap: () {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (_) => TitleBarWrapper(
              child: MemberDetailScreen(member: member),
            ),
          ),
        );
      },
      child: Container(
        margin: effectiveMargin,
        padding: padding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
          borderRadius: borderRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: avatarTextStyle,
                  ),
                ),
                SizedBox(width: horizontalSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.name,
                        style: nameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (shouldShowDetails)
                        Text(
                          details.join(' • '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (shouldShowTimestamp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _timeAgo(member.createdAt!),
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
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
