import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/subscriber.dart';
import 'package:bluebubbles/models/crm/email_campaign.dart';
import 'package:bluebubbles/services/crm/subscriber_repository.dart';
import 'package:bluebubbles/services/crm/email_campaign_repository.dart';
import 'package:bluebubbles/screens/crm/email_campaigns/email_campaign_detail_screen.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF43A047);

class SubscribersOverviewTab extends StatefulWidget {
  final VoidCallback? onNavigateToSubscribers;
  final VoidCallback? onNavigateToCampaigns;

  const SubscribersOverviewTab({
    super.key,
    this.onNavigateToSubscribers,
    this.onNavigateToCampaigns,
  });

  @override
  State<SubscribersOverviewTab> createState() => _SubscribersOverviewTabState();
}

class _SubscribersOverviewTabState extends State<SubscribersOverviewTab> {
  final SubscriberRepository _subscriberRepository = SubscriberRepository();
  final EmailCampaignRepository _campaignRepository = EmailCampaignRepository();
  final DateFormat _dateFormat = DateFormat('MMM d, y');

  SubscriberStats _subscriberStats = const SubscriberStats();
  EmailCampaignStats _campaignStats = const EmailCampaignStats();
  List<EmailCampaign> _recentCampaigns = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final results = await Future.wait([
        _subscriberRepository.fetchStats(),
        _campaignRepository.fetchStats(),
        _campaignRepository.fetchCampaigns(limit: 5, fetchTotalCount: false),
      ]);

      if (!mounted) return;

      setState(() {
        _subscriberStats = results[0] as SubscriberStats;
        _campaignStats = results[1] as EmailCampaignStats;
        _recentCampaigns = (results[2] as EmailCampaignFetchResult).campaigns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _openCampaignDetail(EmailCampaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailCampaignDetailScreen(
          campaignId: campaign.id,
          initialCampaign: campaign,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text('Failed to load overview data'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 28 : 12,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscriber Metrics Section
            _buildSectionHeader(
              theme,
              icon: Icons.people_outline,
              title: 'Subscriber Metrics',
              onViewAll: widget.onNavigateToSubscribers,
            ),
            const SizedBox(height: 12),
            _buildSubscriberStats(theme, isWide),
            if (_subscriberStats.bySource.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSourceBreakdown(theme, _subscriberStats.bySource, 'Subscribers by Source'),
            ],

            const SizedBox(height: 32),

            // Email Campaign Performance Section
            _buildSectionHeader(
              theme,
              icon: Icons.campaign_outlined,
              title: 'Email Campaign Performance',
              onViewAll: widget.onNavigateToCampaigns,
            ),
            const SizedBox(height: 12),
            _buildCampaignStats(theme, isWide),

            if (_recentCampaigns.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildRecentCampaignsSection(theme),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    VoidCallback? onViewAll,
  }) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _momentumBlue.withOpacity(0.12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: _momentumBlue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (onViewAll != null)
          TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('View All'),
          ),
      ],
    );
  }

  Widget _buildSubscriberStats(ThemeData theme, bool isWide) {
    final stats = _subscriberStats;

    final tiles = [
      _OverviewStatTile(
        label: 'Total Subscribers',
        value: stats.totalSubscribers,
        icon: Icons.people_outline,
        color: Colors.blueGrey,
      ),
      _OverviewStatTile(
        label: 'Active',
        value: stats.activeSubscribers,
        icon: Icons.mark_email_read_outlined,
        color: _grassrootsGreen,
      ),
      _OverviewStatTile(
        label: 'Unsubscribed',
        value: stats.unsubscribed,
        icon: Icons.unsubscribe_outlined,
        color: _actionRed,
      ),
      _OverviewStatTile(
        label: 'Also Donors',
        value: stats.donorCount,
        icon: Icons.volunteer_activism_outlined,
        color: Colors.purple,
      ),
      _OverviewStatTile(
        label: 'With Contact Info',
        value: stats.contactInfoCount,
        icon: Icons.contact_phone_outlined,
        color: Colors.teal,
      ),
      _OverviewStatTile(
        label: 'Recent Opt-ins (30d)',
        value: stats.recentOptIns,
        icon: Icons.fiber_new_outlined,
        color: Colors.orange,
      ),
    ];

    if (isWide) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: tiles.map((t) => SizedBox(width: 200, child: t)).toList(),
      );
    }

    return Column(
      children: tiles.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: t,
      )).toList(),
    );
  }

  Widget _buildCampaignStats(ThemeData theme, bool isWide) {
    final stats = _campaignStats;

    final tiles = [
      _OverviewStatTile(
        label: 'Total Campaigns',
        value: stats.totalCampaigns,
        icon: Icons.campaign_outlined,
        color: Colors.blueGrey,
      ),
      _OverviewStatTile(
        label: 'Sent',
        value: stats.sentCampaigns,
        icon: Icons.send_outlined,
        color: _momentumBlue,
      ),
      _OverviewStatTile(
        label: 'Avg Open Rate',
        value: stats.averageOpenRate,
        isPercentage: true,
        icon: Icons.visibility_outlined,
        color: _grassrootsGreen,
      ),
      _OverviewStatTile(
        label: 'Avg Click Rate',
        value: stats.averageClickRate,
        isPercentage: true,
        icon: Icons.touch_app_outlined,
        color: _momentumBlue,
      ),
      _OverviewStatTile(
        label: 'Total Recipients',
        value: stats.totalRecipients,
        icon: Icons.group_outlined,
        color: Colors.purple,
      ),
      _OverviewStatTile(
        label: 'Total Bounces',
        value: stats.totalBounces,
        icon: Icons.error_outline,
        color: _actionRed,
      ),
    ];

    if (isWide) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: tiles.map((t) => SizedBox(width: 200, child: t)).toList(),
      );
    }

    return Column(
      children: tiles.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: t,
      )).toList(),
    );
  }

  Widget _buildSourceBreakdown(ThemeData theme, Map<String, int> bySource, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bySource.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentCampaignsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Campaigns',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (widget.onNavigateToCampaigns != null)
              TextButton(
                onPressed: widget.onNavigateToCampaigns,
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentCampaigns.map((campaign) => _buildRecentCampaignTile(theme, campaign)),
      ],
    );
  }

  Widget _buildRecentCampaignTile(ThemeData theme, EmailCampaign campaign) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCampaignDetail(campaign),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign.sentAt != null
                          ? _dateFormat.format(campaign.sentAt!)
                          : 'Draft',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                theme,
                label: 'Open',
                value: '${campaign.displayOpenRate}%',
                color: _grassrootsGreen,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                theme,
                label: 'Click',
                value: '${campaign.displayClickRate}%',
                color: _momentumBlue,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(ThemeData theme, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _OverviewStatTile extends StatelessWidget {
  final String label;
  final num value;
  final bool isPercentage;
  final IconData icon;
  final Color color;

  const _OverviewStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = isPercentage
        ? '${value.toStringAsFixed(1)}%'
        : '${value.toInt()}';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayValue,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
