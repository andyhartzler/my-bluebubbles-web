import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/email_campaign.dart';
import 'package:bluebubbles/services/crm/email_campaign_repository.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF43A047);

class CampaignRecipientsList extends StatefulWidget {
  final String campaignId;
  final RecipientFilter initialFilter;
  final Map<RecipientFilter, int> recipientCounts;
  final ValueChanged<EmailCampaignRecipient>? onRecipientTap;
  final ValueChanged<RecipientFilter>? onFilterChanged;

  const CampaignRecipientsList({
    super.key,
    required this.campaignId,
    this.initialFilter = RecipientFilter.all,
    this.recipientCounts = const {},
    this.onRecipientTap,
    this.onFilterChanged,
  });

  @override
  State<CampaignRecipientsList> createState() => _CampaignRecipientsListState();
}

class _CampaignRecipientsListState extends State<CampaignRecipientsList> {
  final EmailCampaignRepository _repository = EmailCampaignRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;
  List<EmailCampaignRecipient> _recipients = [];
  RecipientFilter _currentFilter = RecipientFilter.all;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  static const _pageSize = 50;
  static final DateFormat _dateFormat = DateFormat('MMM d, y h:mm a');

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _scrollController.addListener(_handleScroll);
    _loadRecipients(reset: true);
  }

  @override
  void didUpdateWidget(CampaignRecipientsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != _currentFilter) {
      setState(() => _currentFilter = widget.initialFilter);
      _loadRecipients(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final recipients = await _repository.fetchCampaignRecipients(
      campaignId: widget.campaignId,
      filter: _currentFilter,
      searchQuery: _searchController.text,
      limit: _pageSize,
      offset: reset ? 0 : _recipients.length,
    );

    if (!mounted) return;

    setState(() {
      if (reset) {
        _recipients = recipients;
      } else {
        _recipients = [..._recipients, ...recipients];
      }
      _loading = false;
      _loadingMore = false;
      _hasMore = recipients.length >= _pageSize;
    });
  }

  void _handleScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadRecipients();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadRecipients(reset: true);
    });
  }

  void _onFilterChanged(RecipientFilter filter) {
    setState(() => _currentFilter = filter);
    widget.onFilterChanged?.call(filter);
    _loadRecipients(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(context),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildRecipientsList(),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by email or name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _loadRecipients(reset: true);
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  count: widget.recipientCounts[RecipientFilter.all],
                  selected: _currentFilter == RecipientFilter.all,
                  onSelected: () => _onFilterChanged(RecipientFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Opened',
                  count: widget.recipientCounts[RecipientFilter.opened],
                  selected: _currentFilter == RecipientFilter.opened,
                  color: _grassrootsGreen,
                  onSelected: () => _onFilterChanged(RecipientFilter.opened),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Clicked',
                  count: widget.recipientCounts[RecipientFilter.clicked],
                  selected: _currentFilter == RecipientFilter.clicked,
                  color: _momentumBlue,
                  onSelected: () => _onFilterChanged(RecipientFilter.clicked),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Bounced',
                  count: widget.recipientCounts[RecipientFilter.bounced],
                  selected: _currentFilter == RecipientFilter.bounced,
                  color: _actionRed,
                  onSelected: () => _onFilterChanged(RecipientFilter.bounced),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unsubscribed',
                  count: widget.recipientCounts[RecipientFilter.unsubscribed],
                  selected: _currentFilter == RecipientFilter.unsubscribed,
                  color: Colors.orange,
                  onSelected: () => _onFilterChanged(RecipientFilter.unsubscribed),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Failed',
                  count: widget.recipientCounts[RecipientFilter.failed],
                  selected: _currentFilter == RecipientFilter.failed,
                  color: Colors.grey,
                  onSelected: () => _onFilterChanged(RecipientFilter.failed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientsList() {
    if (_recipients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No recipients match the current filters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRecipients(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _recipients.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _recipients.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final recipient = _recipients[index];
          return _RecipientTile(
            recipient: recipient,
            onTap: () => widget.onRecipientTap?.call(recipient),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return FilterChip(
      label: Text(
        count != null ? '$label ($count)' : label,
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      side: selected ? BorderSide(color: chipColor) : null,
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final EmailCampaignRecipient recipient;
  final VoidCallback? onTap;

  static final DateFormat _dateFormat = DateFormat('MMM d, y h:mm a');

  const _RecipientTile({
    required this.recipient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipient.displayName != recipient.email)
                      Text(
                        recipient.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (recipient.opened)
                          _StatusBadge(
                            label: recipient.openCount > 1
                                ? 'Opened ${recipient.openCount}x'
                                : 'Opened',
                            color: _grassrootsGreen,
                            icon: Icons.mark_email_read_outlined,
                          ),
                        if (recipient.clicked)
                          _StatusBadge(
                            label: recipient.clickCount > 1
                                ? 'Clicked ${recipient.clickCount}x'
                                : 'Clicked',
                            color: _momentumBlue,
                            icon: Icons.touch_app_outlined,
                          ),
                        if (recipient.bounced)
                          _StatusBadge(
                            label: recipient.bounceType != null
                                ? 'Bounced (${recipient.bounceType})'
                                : 'Bounced',
                            color: _actionRed,
                            icon: Icons.error_outline,
                          ),
                        if (recipient.unsubscribed)
                          _StatusBadge(
                            label: 'Unsubscribed',
                            color: Colors.orange,
                            icon: Icons.unsubscribe_outlined,
                          ),
                        if (recipient.complained)
                          _StatusBadge(
                            label: 'Complained',
                            color: Colors.deepOrange,
                            icon: Icons.report_outlined,
                          ),
                        if (recipient.failed)
                          _StatusBadge(
                            label: 'Failed',
                            color: Colors.grey,
                            icon: Icons.cancel_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (recipient.sentAt != null)
                    Text(
                      _dateFormat.format(recipient.sentAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (recipient.geoLocation != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          recipient.geoLocation!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
