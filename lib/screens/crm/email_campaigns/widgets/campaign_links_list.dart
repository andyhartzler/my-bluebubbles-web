import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/email_campaign.dart';
import 'package:bluebubbles/services/crm/email_campaign_repository.dart';

const _momentumBlue = Color(0xFF32A6DE);

class CampaignLinksList extends StatefulWidget {
  final String campaignId;

  const CampaignLinksList({
    super.key,
    required this.campaignId,
  });

  @override
  State<CampaignLinksList> createState() => _CampaignLinksListState();
}

class _CampaignLinksListState extends State<CampaignLinksList> {
  final EmailCampaignRepository _repository = EmailCampaignRepository();

  List<EmailCampaignLink> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _loading = true);

    final links = await _repository.fetchCampaignLinks(widget.campaignId);

    if (!mounted) return;

    setState(() {
      _links = links;
      _loading = false;
    });
  }

  void _showLinkClicks(EmailCampaignLink link) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LinkClicksSheet(
        link: link,
        repository: _repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No tracked links found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This campaign has no tracked links or click data.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      );
    }

    // Calculate total clicks for percentage display
    final totalClicks = _links.fold<int>(0, (sum, link) => sum + link.totalClicks);

    return RefreshIndicator(
      onRefresh: _loadLinks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _links.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(totalClicks);
          }

          final link = _links[index - 1];
          return _LinkTile(
            link: link,
            totalClicks: totalClicks,
            onTap: () => _showLinkClicks(link),
          );
        },
      ),
    );
  }

  Widget _buildHeader(int totalClicks) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _momentumBlue.withOpacity(0.12),
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.link_outlined, color: _momentumBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_links.length} Tracked Links',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$totalClicks total clicks',
                    style: theme.textTheme.bodyMedium?.copyWith(
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

class _LinkTile extends StatelessWidget {
  final EmailCampaignLink link;
  final int totalClicks;
  final VoidCallback? onTap;

  const _LinkTile({
    required this.link,
    required this.totalClicks,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clickPercentage =
        totalClicks > 0 ? (link.totalClicks / totalClicks) * 100 : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (link.urlTitle != null && link.urlTitle!.isNotEmpty)
                          Text(
                            link.urlTitle!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          link.url,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy URL',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ClickStat(
                    label: 'Total Clicks',
                    value: link.totalClicks,
                  ),
                  const SizedBox(width: 24),
                  _ClickStat(
                    label: 'Unique Clicks',
                    value: link.uniqueClicks,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${clickPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: _momentumBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: clickPercentage / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(_momentumBlue),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClickStat extends StatelessWidget {
  final String label;
  final int value;

  const _ClickStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LinkClicksSheet extends StatefulWidget {
  final EmailCampaignLink link;
  final EmailCampaignRepository repository;

  const _LinkClicksSheet({
    required this.link,
    required this.repository,
  });

  @override
  State<_LinkClicksSheet> createState() => _LinkClicksSheetState();
}

class _LinkClicksSheetState extends State<_LinkClicksSheet> {
  List<EmailCampaignLinkClick> _clicks = [];
  bool _loading = true;

  static final DateFormat _dateFormat = DateFormat('MMM d, y h:mm a');

  @override
  void initState() {
    super.initState();
    _loadClicks();
  }

  Future<void> _loadClicks() async {
    final clicks = await widget.repository.fetchLinkClicks(
      linkId: widget.link.id,
      limit: 100,
    );

    if (!mounted) return;

    setState(() {
      _clicks = clicks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      builder: (context, controller) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.link_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Link Clicks',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.link.displayTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _clicks.isEmpty
                      ? Center(
                          child: Text(
                            'No click data available',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.all(16),
                          itemCount: _clicks.length,
                          itemBuilder: (context, index) {
                            final click = _clicks[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _momentumBlue.withOpacity(0.12),
                                  child: const Icon(
                                    Icons.touch_app_outlined,
                                    color: _momentumBlue,
                                  ),
                                ),
                                title: Text(click.email),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_dateFormat.format(click.clickedAt)),
                                    if (click.geoLocation != null)
                                      Text(
                                        click.geoLocation!,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                                trailing: click.deviceType != null
                                    ? Icon(
                                        _deviceIcon(click.deviceType!),
                                        size: 20,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  IconData _deviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
      case 'phone':
        return Icons.phone_android;
      case 'tablet':
        return Icons.tablet_android;
      case 'desktop':
        return Icons.desktop_windows;
      default:
        return Icons.devices;
    }
  }
}
