import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'models/social_media_account.dart';
import 'models/social_media_stats.dart';
import 'models/audience_demographics.dart';
import 'widgets/summary_cards.dart';
import 'widgets/platform_breakdown.dart';
import 'widgets/engagement_chart.dart';
import 'widgets/follower_growth_chart.dart';
import 'widgets/demographics_section.dart';
import 'widgets/sync_status.dart';
import 'theme/communications_committee_theme.dart';

/// Social Media Analytics tab for the Communications Committee
class SocialMediaAnalyticsTab extends StatefulWidget {
  final Committee committee;

  const SocialMediaAnalyticsTab({
    super.key,
    required this.committee,
  });

  @override
  State<SocialMediaAnalyticsTab> createState() => _SocialMediaAnalyticsTabState();
}

class _SocialMediaAnalyticsTabState extends State<SocialMediaAnalyticsTab> {
  // State
  List<SocialMediaAccount> _accounts = [];
  Set<String> _selectedPlatforms = {};
  Set<String> _selectedAccountIds = {};
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Data
  Map<String, SocialMediaStats> _latestStats = {};
  List<SocialMediaStats> _historicalStats = [];
  Map<String, AudienceDemographics> _demographics = {};

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('social_media_accounts')
          .select()
          .eq('is_active', true)
          .order('platform');

      _accounts = (response as List)
          .map((e) => SocialMediaAccount.fromJson(e as Map<String, dynamic>))
          .toList();

      // Select all by default
      _selectedPlatforms = _accounts.map((a) => a.platform).toSet();
      _selectedAccountIds = _accounts.map((a) => a.id).toSet();

      await _loadStats();
    } catch (e) {
      _showError('Failed to load accounts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStats() async {
    if (_selectedAccountIds.isEmpty) return;

    try {
      // Load latest stats for each account
      final latestResponse = await _supabase
          .from('social_media_stats')
          .select('*, social_media_accounts!inner(platform, account_name)')
          .inFilter('account_id', _selectedAccountIds.toList())
          .order('metric_date', ascending: false)
          .limit(_selectedAccountIds.length);

      // Load historical stats for charts
      final historicalResponse = await _supabase
          .from('social_media_stats')
          .select('*, social_media_accounts!inner(platform, account_name)')
          .inFilter('account_id', _selectedAccountIds.toList())
          .gte('metric_date', _dateRange.start.toIso8601String().split('T')[0])
          .lte('metric_date', _dateRange.end.toIso8601String().split('T')[0])
          .order('metric_date');

      // Load demographics
      final demographicsResponse = await _supabase
          .from('social_media_audience_demographics')
          .select('*, social_media_accounts!inner(platform, account_name)')
          .inFilter('account_id', _selectedAccountIds.toList())
          .order('metric_date', ascending: false)
          .limit(_selectedAccountIds.length);

      if (mounted) {
        setState(() {
          _latestStats = {
            for (var item in latestResponse as List)
              item['account_id'] as String:
                  SocialMediaStats.fromJson(item as Map<String, dynamic>)
          };
          _historicalStats = (historicalResponse as List)
              .map((e) => SocialMediaStats.fromJson(e as Map<String, dynamic>))
              .toList();
          _demographics = {
            for (var item in demographicsResponse as List)
              item['account_id'] as String:
                  AudienceDemographics.fromJson(item as Map<String, dynamic>)
          };
        });
      }
    } catch (e) {
      _showError('Failed to load stats: $e');
    }
  }

  Future<void> _refreshAllStats() async {
    setState(() => _isRefreshing = true);

    try {
      final functions = [
        'fetch-facebook-stats',
        'fetch-instagram-stats',
        'fetch-threads-stats',
        'fetch-youtube-stats',
      ];

      // Call all edge functions in parallel
      final results = await Future.wait(
        functions.map((fn) => _supabase.functions.invoke(fn)),
      );

      // Check for errors
      final errors = results.where((r) => r.status != 200).toList();
      if (errors.isNotEmpty) {
        _showError('Some platforms failed to refresh');
      }

      // Reload data
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stats refreshed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to refresh: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No social media accounts connected',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your social media accounts to see analytics',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Calculate summary totals
    int totalFollowers = 0;
    int totalEngagement = 0;
    int totalImpressions = 0;
    int totalPosts = 0;

    for (var stats in _latestStats.values) {
      totalFollowers += stats.followersCount ?? 0;
      totalEngagement += stats.totalEngagement;
      totalImpressions += stats.impressions ?? 0;
      totalPosts += stats.postsCount ?? 0;
    }

    return RefreshIndicator(
      onRefresh: _refreshAllStats,
      child: CustomScrollView(
        slivers: [
          // Header with filters and refresh button
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          // Summary cards
          SliverToBoxAdapter(
            child: SocialMediaSummaryCards(
              totalFollowers: totalFollowers,
              totalEngagement: totalEngagement,
              totalImpressions: totalImpressions,
              totalPosts: totalPosts,
            ),
          ),

          // Platform breakdown
          SliverToBoxAdapter(
            child: PlatformBreakdown(
              accounts: _accounts,
              latestStats: _latestStats,
              selectedAccountIds: _selectedAccountIds,
            ),
          ),

          // Engagement chart
          SliverToBoxAdapter(
            child: EngagementChart(
              historicalStats: _historicalStats,
              selectedPlatforms: _selectedPlatforms,
            ),
          ),

          // Follower growth chart
          SliverToBoxAdapter(
            child: FollowerGrowthChart(
              historicalStats: _historicalStats,
              selectedPlatforms: _selectedPlatforms,
            ),
          ),

          // Demographics section
          SliverToBoxAdapter(
            child: DemographicsSection(
              demographics: _demographics,
            ),
          ),

          // Sync status
          SliverToBoxAdapter(
            child: SyncStatus(
              accounts: _accounts,
              selectedAccountIds: _selectedAccountIds,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Social Media Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    _buildRefreshButton(),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Social Media Analytics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildRefreshButton(),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Filters row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildAccountFilterDropdown(),
              _buildDateRangePicker(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return FilledButton.icon(
      onPressed: _isRefreshing ? null : _refreshAllStats,
      icon: _isRefreshing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.refresh),
      label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh All'),
      style: FilledButton.styleFrom(
        backgroundColor: CommunicationsCommitteeTheme.primary,
      ),
    );
  }

  Widget _buildAccountFilterDropdown() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Platforms & Accounts',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        value: _selectedAccountIds.length == _accounts.length ? 'all' : 'custom',
        items: [
          const DropdownMenuItem(
            value: 'all',
            child: Text('All Platforms'),
          ),
          ..._accounts.map((account) => DropdownMenuItem(
                value: account.id,
                child: Row(
                  children: [
                    Icon(
                      _getPlatformIcon(account.platform),
                      size: 20,
                      color: CommunicationsCommitteeTheme.getPlatformColor(
                          account.platform),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        account.accountName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
        onChanged: (value) {
          setState(() {
            if (value == 'all') {
              _selectedAccountIds = _accounts.map((a) => a.id).toSet();
              _selectedPlatforms = _accounts.map((a) => a.platform).toSet();
            } else if (value != null && value != 'custom') {
              _selectedAccountIds = {value};
              final account = _accounts.firstWhere((a) => a.id == value);
              _selectedPlatforms = {account.platform};
            }
          });
          _loadStats();
        },
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          initialDateRange: _dateRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: CommunicationsCommitteeTheme.primary,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          setState(() => _dateRange = picked);
          _loadStats();
        }
      },
      icon: const Icon(Icons.calendar_today),
      label: Text(
        '${_formatDate(_dateRange.start)} - ${_formatDate(_dateRange.end)}',
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'threads':
        return Icons.alternate_email;
      case 'youtube':
        return Icons.play_circle_filled;
      case 'reddit':
        return Icons.reddit;
      case 'tiktok':
        return Icons.music_note;
      case 'twitter':
      case 'x':
        return Icons.flutter_dash;
      default:
        return Icons.share;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
