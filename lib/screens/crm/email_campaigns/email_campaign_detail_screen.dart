import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/email_campaign.dart';
import 'package:bluebubbles/models/crm/subscriber.dart';
import 'package:bluebubbles/services/crm/email_campaign_repository.dart';
import 'package:bluebubbles/services/crm/subscriber_repository.dart';

import 'widgets/campaign_stats_grid.dart';
import 'widgets/campaign_html_preview.dart';
import 'widgets/campaign_recipients_list.dart';
import 'widgets/campaign_links_list.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF43A047);

class EmailCampaignDetailScreen extends StatefulWidget {
  final String campaignId;
  final EmailCampaign? initialCampaign;

  const EmailCampaignDetailScreen({
    super.key,
    required this.campaignId,
    this.initialCampaign,
  });

  @override
  State<EmailCampaignDetailScreen> createState() => _EmailCampaignDetailScreenState();
}

class _EmailCampaignDetailScreenState extends State<EmailCampaignDetailScreen>
    with SingleTickerProviderStateMixin {
  final EmailCampaignRepository _repository = EmailCampaignRepository();
  final SubscriberRepository _subscriberRepository = SubscriberRepository();
  late TabController _tabController;

  EmailCampaign? _campaign;
  Map<RecipientFilter, int> _recipientCounts = {};
  bool _loading = true;
  bool _errorState = false;
  String? _errorMessage;

  // For navigating to Recipients tab with filter
  RecipientFilter _selectedRecipientFilter = RecipientFilter.all;

  static final DateFormat _dateFormat = DateFormat('MMM d, y');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, y \'at\' h:mm a');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _campaign = widget.initialCampaign;
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _repository.fetchCampaignById(widget.campaignId),
        _repository.fetchRecipientCounts(widget.campaignId),
      ]);

      final campaign = results[0] as EmailCampaign?;
      final counts = results[1] as Map<RecipientFilter, int>;

      if (!mounted) return;

      if (campaign == null) {
        setState(() {
          _loading = false;
          _errorState = true;
          _errorMessage = 'Campaign not found';
        });
        return;
      }

      setState(() {
        _campaign = campaign;
        _recipientCounts = counts;
        _loading = false;
        _errorState = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorState = true;
        _errorMessage = 'Failed to load campaign: $e';
      });
    }
  }

  void _navigateToRecipientsWithFilter(RecipientFilter filter) {
    setState(() => _selectedRecipientFilter = filter);
    _tabController.animateTo(1); // Switch to Recipients tab (index 1)
  }

  Future<void> _openSubscriberDetail(EmailCampaignRecipient recipient) async {
    if (recipient.subscriberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscriber not linked to this recipient')),
      );
      return;
    }

    final subscriber = await _subscriberRepository.fetchSubscriberById(recipient.subscriberId!);
    if (subscriber == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscriber not found')),
        );
      }
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuickSubscriberSheet(
        subscriber: subscriber,
        recipient: recipient,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_campaign?.name ?? 'Campaign Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _initialize,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_errorState) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unable to load campaign'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _initialize, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_loading && _campaign == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Material(
          elevation: 2,
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline), text: 'Recipients'),
              Tab(icon: Icon(Icons.link_outlined), text: 'Links'),
              Tab(icon: Icon(Icons.email_outlined), text: 'Email Preview'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(theme),
              CampaignRecipientsList(
                campaignId: widget.campaignId,
                initialFilter: _selectedRecipientFilter,
                recipientCounts: _recipientCounts,
                onRecipientTap: _openSubscriberDetail,
                onFilterChanged: (filter) {
                  setState(() => _selectedRecipientFilter = filter);
                },
              ),
              CampaignLinksList(campaignId: widget.campaignId),
              CampaignHtmlPreview(
                htmlContent: _campaign?.htmlContent,
                textContent: _campaign?.textContent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    final campaign = _campaign;
    if (campaign == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCampaignHeader(theme, campaign),
          const SizedBox(height: 20),
          CampaignStatsGrid(
            campaign: campaign,
            recipientCounts: _recipientCounts,
            onStatTap: _navigateToRecipientsWithFilter,
          ),
          const SizedBox(height: 20),
          _buildMetadataSection(theme, campaign),
          if (campaign.previewText != null && campaign.previewText!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreviewTextSection(theme, campaign),
          ],
        ],
      ),
    );
  }

  Widget _buildCampaignHeader(ThemeData theme, EmailCampaign campaign) {
    final isSent = campaign.isSent;
    final statusLabel = isSent ? 'Sent' : 'Draft';
    final statusColor = isSent ? _grassrootsGreen : Colors.orange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withOpacity(0.12),
                  shape: StadiumBorder(
                    side: BorderSide(color: statusColor.withOpacity(0.4)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              campaign.subject,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (campaign.sentAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Sent ${_dateTimeFormat.format(campaign.sentAt!)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection(ThemeData theme, EmailCampaign campaign) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Campaign Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (campaign.fromName != null || campaign.fromEmail != null)
                  _MetadataItem(
                    label: 'From',
                    value: campaign.fromName != null
                        ? '${campaign.fromName} <${campaign.fromEmail ?? 'N/A'}>'
                        : campaign.fromEmail ?? 'N/A',
                    icon: Icons.person_outline,
                  ),
                if (campaign.replyTo != null)
                  _MetadataItem(
                    label: 'Reply-To',
                    value: campaign.replyTo!,
                    icon: Icons.reply_outlined,
                  ),
                if (campaign.audienceName != null)
                  _MetadataItem(
                    label: 'Audience',
                    value: campaign.audienceName!,
                    icon: Icons.group_outlined,
                  ),
                if (campaign.segmentName != null)
                  _MetadataItem(
                    label: 'Segment',
                    value: campaign.segmentName!,
                    icon: Icons.filter_list_outlined,
                  ),
                _MetadataItem(
                  label: 'Source',
                  value: _capitalizeFirst(campaign.source),
                  icon: Icons.source_outlined,
                ),
                if (campaign.sendWeekday != null)
                  _MetadataItem(
                    label: 'Send Day',
                    value: campaign.sendWeekday!,
                    icon: Icons.calendar_today_outlined,
                  ),
                if (campaign.createdAt != null)
                  _MetadataItem(
                    label: 'Created',
                    value: _dateFormat.format(campaign.createdAt!),
                    icon: Icons.create_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTextSection(ThemeData theme, EmailCampaign campaign) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview Text',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              campaign.previewText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetadataItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSubscriberSheet extends StatelessWidget {
  final Subscriber subscriber;
  final EmailCampaignRecipient recipient;

  static final DateFormat _dateFormat = DateFormat('MMM d, y \'at\' h:mm a');

  const _QuickSubscriberSheet({
    required this.subscriber,
    required this.recipient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscriber.name,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            subscriber.email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Campaign Engagement',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _EngagementChip(
                      label: 'Opened',
                      value: recipient.opened,
                      count: recipient.openCount,
                      timestamp: recipient.firstOpenedAt,
                      positiveColor: _grassrootsGreen,
                    ),
                    _EngagementChip(
                      label: 'Clicked',
                      value: recipient.clicked,
                      count: recipient.clickCount,
                      timestamp: recipient.firstClickedAt,
                      positiveColor: _momentumBlue,
                    ),
                    _EngagementChip(
                      label: 'Bounced',
                      value: recipient.bounced,
                      timestamp: recipient.bouncedAt,
                      positiveColor: _actionRed,
                      invertColors: true,
                    ),
                    _EngagementChip(
                      label: 'Unsubscribed',
                      value: recipient.unsubscribed,
                      timestamp: recipient.unsubscribedAt,
                      positiveColor: Colors.orange,
                      invertColors: true,
                    ),
                  ],
                ),
                if (recipient.bounceReason != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Bounce Reason: ${recipient.bounceReason}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _actionRed,
                    ),
                  ),
                ],
                if (recipient.geoLocation != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(recipient.geoLocation!),
                    ],
                  ),
                ],
                if (recipient.deviceType != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.devices_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(_capitalizeFirst(recipient.deviceType!)),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EngagementChip extends StatelessWidget {
  final String label;
  final bool value;
  final int? count;
  final DateTime? timestamp;
  final Color positiveColor;
  final bool invertColors;

  static final DateFormat _dateFormat = DateFormat('MMM d, y');

  const _EngagementChip({
    required this.label,
    required this.value,
    required this.positiveColor,
    this.count,
    this.timestamp,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = invertColors ? !value : value;
    final displayColor = value ? positiveColor : Colors.grey;

    return Tooltip(
      message: timestamp != null ? _dateFormat.format(timestamp!) : '',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: displayColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: displayColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.cancel_outlined,
              size: 16,
              color: displayColor,
            ),
            const SizedBox(width: 6),
            Text(
              count != null && count! > 0 ? '$label ($count)' : label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: displayColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}
