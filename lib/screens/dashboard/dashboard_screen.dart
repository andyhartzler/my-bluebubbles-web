import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

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
      final schools = await _memberRepo.getSchoolCounts();
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
      final recentMembers = await _memberRepo.getRecentMembers(limit: 6);

      final chatCount = await _fetchChatCount();
      final totalMessages = await _fetchMessageCount();
      final weeklyMessages = await _fetchMessageCount(
        after: DateTime.now().subtract(const Duration(days: 7)),
      );

      setState(() {
        _data = _DashboardData(
          totalMembers: memberStats['total'] as int? ?? 0,
          contactableMembers: memberStats['contactable'] as int? ?? 0,
          optedOutMembers: memberStats['optedOut'] as int? ?? 0,
          withPhoneMembers: memberStats['withPhone'] as int? ?? 0,
          chatCount: chatCount,
          totalMessages: totalMessages,
          weeklyMessages: weeklyMessages,
          counties: counties,
          districts: districts,
          committees: committees,
          schools: schools,
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
            padding: padding,
            children: [
              _buildHeader(theme, data),
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

  Widget _buildHeader(ThemeData theme, _DashboardData data) {
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
                value: data.totalMembers,
                icon: Icons.people_alt,
              ),
              _HeaderPill(
                label: 'Contactable',
                value: data.contactableMembers,
                icon: Icons.sms,
              ),
              _HeaderPill(
                label: 'Weekly Messages',
                value: data.weeklyMessages,
                icon: Icons.send,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);
    final cards = [
      _StatCardData(
        title: 'Members with Phone Numbers',
        value: data.withPhoneMembers,
        icon: Icons.phone_in_talk,
        description: 'Ready for outreach',
        colors: [theme.colorScheme.secondary, theme.colorScheme.tertiary],
      ),
      _StatCardData(
        title: 'Opted Out',
        value: data.optedOutMembers,
        icon: Icons.block,
        description: 'Respecting preferences',
        colors: [Colors.redAccent.shade200, Colors.redAccent.shade400],
      ),
      _StatCardData(
        title: 'Active Conversations',
        value: data.chatCount,
        icon: Icons.forum,
        description: 'Current chats on BlueBubbles',
        colors: [theme.colorScheme.primary, theme.colorScheme.secondaryContainer],
      ),
      _StatCardData(
        title: 'Total Messages',
        value: data.totalMessages,
        icon: Icons.message,
        description: 'All-time across every channel',
        colors: [theme.colorScheme.tertiary, theme.colorScheme.primaryContainer],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 1.3,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => _StatCard(data: cards[index]),
        );
      },
    );
  }

  Widget _buildInteractiveChart(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);
    final metricLabels = <String, String>{
      'counties': 'Top Counties',
      'districts': 'Top Districts',
      'committees': 'Committees',
      'schools': 'Schools',
      'chapters': 'Chapters',
      'chapterStatuses': 'Chapter Status',
      'graduationYears': 'Graduation Years',
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
      'schools': data.schools,
      'chapters': data.chapters,
      'chapterStatuses': data.chapterStatuses,
      'graduationYears': data.graduationYears,
      'pronouns': data.pronouns,
      'genders': data.genders,
      'races': data.races,
      'languages': data.languages,
      'communityTypes': data.communityTypes,
      'industries': data.industries,
      'educationLevels': data.educationLevels,
      'registeredVoters': data.registeredVoters,
    };

    final selectedData = metricValues[_selectedMetric] ?? const {};
    final entries = selectedData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.take(8).toList();

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
                  DropdownButton<String>(
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
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'No data available for ${metricLabels[_selectedMetric] ?? 'selected metric'}.',
                style: theme.textTheme.bodyMedium,
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
                DropdownButton<String>(
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
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 280,
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
                        showTitles: true,
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
                          theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle(fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;

        final breakdowns = [
          _BreakdownCard(
            title: 'Top Counties',
            metricLabel: 'members',
            data: data.counties,
            total: data.totalMembers,
            accentColor: theme.colorScheme.primary,
          ),
          _BreakdownCard(
            title: 'Top Districts',
            metricLabel: 'members',
            data: data.districts,
            total: data.totalMembers,
            accentColor: theme.colorScheme.secondary,
          ),
          _BreakdownCard(
            title: 'Committees',
            metricLabel: 'members',
            data: data.committees,
            total: data.totalMembers,
            accentColor: theme.colorScheme.tertiary,
          ),
          _BreakdownCard(
            title: 'Chapter Engagement',
            metricLabel: 'responses',
            data: data.chapterStatuses,
            total: data.chapterStatuses.values.sum,
            accentColor: theme.colorScheme.primaryContainer,
          ),
          _BreakdownCard(
            title: 'Graduation Year',
            metricLabel: 'members',
            data: data.graduationYears,
            total: data.totalMembers,
            accentColor: theme.colorScheme.secondaryContainer,
          ),
          _BreakdownCard(
            title: 'Pronouns',
            metricLabel: 'responses',
            data: data.pronouns,
            total: data.pronouns.values.sum,
            accentColor: theme.colorScheme.tertiaryContainer,
          ),
          _BreakdownCard(
            title: 'Gender Identity',
            metricLabel: 'responses',
            data: data.genders,
            total: data.genders.values.sum,
            accentColor: theme.colorScheme.surfaceVariant,
          ),
          _BreakdownCard(
            title: 'Race & Ethnicity',
            metricLabel: 'responses',
            data: data.races,
            total: data.races.values.sum,
            accentColor: theme.colorScheme.inversePrimary,
          ),
          _BreakdownCard(
            title: 'Languages',
            metricLabel: 'speakers',
            data: data.languages,
            total: data.languages.values.sum,
            accentColor: theme.colorScheme.secondaryContainer,
          ),
          _BreakdownCard(
            title: 'Community Type',
            metricLabel: 'responses',
            data: data.communityTypes,
            total: data.communityTypes.values.sum,
            accentColor: theme.colorScheme.surfaceVariant,
          ),
          _BreakdownCard(
            title: 'Industries',
            metricLabel: 'members',
            data: data.industries,
            total: data.industries.values.sum,
            accentColor: theme.colorScheme.primary,
          ),
          _BreakdownCard(
            title: 'Education',
            metricLabel: 'responses',
            data: data.educationLevels,
            total: data.educationLevels.values.sum,
            accentColor: theme.colorScheme.secondary,
          ),
          _BreakdownCard(
            title: 'Voter Registration',
            metricLabel: 'members',
            data: data.registeredVoters,
            total: data.registeredVoters.values.sum,
            accentColor: theme.colorScheme.errorContainer,
          ),
        ];

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

    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
        child: Center(
          child: Text(
            'No recent members yet. New sign-ups will appear here automatically.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
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
          Text(
            'Newest Members',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...members.map((member) => _RecentMemberTile(member: member)),
        ],
      ),
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
  final Map<String, int> counties;
  final Map<String, int> districts;
  final Map<String, int> committees;
  final Map<String, int> schools;
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
  final List<Member> recentMembers;

  const _DashboardData({
    required this.totalMembers,
    required this.contactableMembers,
    required this.optedOutMembers,
    required this.withPhoneMembers,
    required this.chatCount,
    required this.totalMessages,
    required this.weeklyMessages,
    required this.counties,
    required this.districts,
    required this.committees,
    required this.schools,
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
        counties = const {},
        districts = const {},
        committees = const {},
        schools = const {},
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
        recentMembers = const [];
}

class _StatCardData {
  final String title;
  final int value;
  final IconData icon;
  final String description;
  final List<Color> colors;

  _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.description,
    required this.colors,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: theme.colorScheme.onPrimary, size: 28),
          const Spacer(),
          Text(
            data.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.value.toString(),
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withOpacity(0.85),
            ),
          ),
        ],
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

  const _BreakdownCard({
    required this.title,
    required this.metricLabel,
    required this.data,
    required this.total,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topEntries = data.entries.take(6).toList();

    return Container(
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
                padding: EdgeInsets.only(bottom: index == topEntries.length - 1 ? 0 : 14),
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
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _HeaderPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            '$value $label',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentMemberTile extends StatelessWidget {
  final Member member;

  const _RecentMemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (member.county != null && member.county!.isNotEmpty) member.county!,
      if (member.congressionalDistrict != null && member.congressionalDistrict!.isNotEmpty)
        Member.formatDistrictLabel(member.congressionalDistrict) ?? member.congressionalDistrict!,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (member.createdAt != null)
              Text(
                _timeAgo(member.createdAt!),
                style: theme.textTheme.labelSmall,
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
