import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/subscriber.dart';
import 'package:bluebubbles/services/crm/subscriber_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class SubscribersScreen extends StatefulWidget {
  const SubscribersScreen({super.key});

  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends State<SubscribersScreen> {
  final SubscriberRepository _repository = SubscriberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('MMM d, y');

  Timer? _debounce;
  List<Subscriber> _subscribers = [];
  SubscriberStats _stats = const SubscriberStats();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _errorState = false;
  String? _errorMessage;

  // Filters
  String? _statusFilter;
  String? _sourceFilter;
  String? _countyFilter;
  String? _stateFilter;
  bool _donorsOnly = false;
  bool _eventAttendeesOnly = false;
  DateTime? _optInStart;
  DateTime? _optInEnd;

  // Filter options
  List<String> _availableCounties = [];
  List<String> _availableStates = [];
  List<String> _availableSources = [];

  static const _pageSize = 30;

  bool get _crmReady => _supabaseService.isInitialized;
  bool get _canManage => _supabaseService.hasServiceRole;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!_crmReady) {
      setState(() {
        _loading = false;
        _errorState = true;
        _errorMessage = 'CRM Supabase is not configured. Add credentials to enable Subscribers.';
      });
      return;
    }

    await Future.wait([
      _loadSubscribers(reset: true),
      _loadStats(),
      _loadFilters(),
    ]);
  }

  Future<void> _loadStats() async {
    final stats = await _repository.fetchStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  Future<void> _loadFilters() async {
    final results = await Future.wait([
      _repository.fetchDistinctValues('county'),
      _repository.fetchDistinctValues('state'),
      _repository.fetchDistinctValues('source'),
    ]);

    if (mounted) {
      setState(() {
        _availableCounties = results[0];
        _availableStates = results[1];
        _availableSources = results[2];
      });
    }
  }

  Future<void> _loadSubscribers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final response = await _repository.fetchSubscribers(
      searchQuery: _searchController.text,
      subscriptionStatus: _statusFilter,
      source: _sourceFilter,
      county: _countyFilter,
      state: _stateFilter,
      donorsOnly: _donorsOnly,
      eventAttendeesOnly: _eventAttendeesOnly,
      optInStart: _optInStart,
      optInEnd: _optInEnd,
      limit: _pageSize,
      offset: reset ? 0 : _subscribers.length,
      fetchTotalCount: true,
    );

    if (!mounted) return;

    setState(() {
      if (reset) {
        _subscribers = response.subscribers;
      } else {
        _subscribers = [..._subscribers, ...response.subscribers];
      }
      _loading = false;
      _loadingMore = false;
      final total = response.totalCount ?? response.subscribers.length;
      _hasMore = _subscribers.length < total;
      _errorState = false;
      _errorMessage = null;
    });
  }

  void _handleScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadSubscribers();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadSubscribers(reset: true);
    });
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _optInStart != null && _optInEnd != null
          ? DateTimeRange(start: _optInStart!, end: _optInEnd!)
          : null,
    );

    if (range != null) {
      setState(() {
        _optInStart = range.start;
        _optInEnd = range.end;
      });
      await _loadSubscribers(reset: true);
    }
  }

  void _clearDateRange() {
    setState(() {
      _optInStart = null;
      _optInEnd = null;
    });
    _loadSubscribers(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _initialize(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_errorState) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unable to load subscribers'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSubscribers(reset: true),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _buildStats(context),
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          _buildSubscriberList(context),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final tiles = [
      _StatsTile(
        label: 'Total Subscribers',
        value: _stats.totalSubscribers,
        icon: Icons.people_outline,
        color: Colors.blueGrey,
      ),
      _StatsTile(
        label: 'Active Subscribers',
        value: _stats.activeSubscribers,
        icon: Icons.mark_email_read_outlined,
        color: Colors.blue,
      ),
      _StatsTile(
        label: 'Unsubscribed',
        value: _stats.unsubscribed,
        icon: Icons.unsubscribe_outlined,
        color: Colors.red,
      ),
      _StatsTile(
        label: 'Also Donors',
        value: _stats.donorCount,
        icon: Icons.volunteer_activism_outlined,
        color: Colors.purple,
      ),
      _StatsTile(
        label: 'With Contact Info',
        value: _stats.contactInfoCount,
        icon: Icons.contact_phone_outlined,
        color: Colors.teal,
      ),
      _StatsTile(
        label: 'Recent Opt-ins (30d)',
        value: _stats.recentOptIns,
        icon: Icons.fiber_new_outlined,
        color: Colors.orange,
      ),
    ];

    final sourceTiles = _stats.bySource.entries
        .map((entry) => _StatsTile(
              label: 'Source: ${entry.key}',
              value: entry.value,
              icon: Icons.tag_outlined,
              color: Colors.indigo,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tile in tiles) Padding(padding: const EdgeInsets.only(right: 12), child: tile),
            ],
          ),
        ),
        if (sourceTiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tile in sourceTiles)
                  Padding(padding: const EdgeInsets.only(right: 12), child: tile),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final chipStyle = theme.chipTheme.copyWith(
      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _loadSubscribers(reset: true);
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    value: _statusFilter,
                    decoration: const InputDecoration(labelText: 'Subscription Status'),
                    items: const [
                      DropdownMenuItem(value: 'subscribed', child: Text('Subscribed')),
                      DropdownMenuItem(value: 'unsubscribed', child: Text('Unsubscribed')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'cleaned', child: Text('Cleaned')),
                    ],
                    onChanged: (value) async {
                      setState(() => _statusFilter = value);
                      await _loadSubscribers(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    value: _sourceFilter,
                    decoration: const InputDecoration(labelText: 'Source'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ..._availableSources
                          .map((source) => DropdownMenuItem(value: source, child: Text(source)))
                          .toList(),
                      const DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) async {
                      setState(() => _sourceFilter = value);
                      await _loadSubscribers(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    value: _countyFilter,
                    decoration: const InputDecoration(labelText: 'County'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ..._availableCounties
                          .map((county) => DropdownMenuItem(value: county, child: Text(county)))
                          .toList(),
                    ],
                    onChanged: (value) async {
                      setState(() => _countyFilter = value);
                      await _loadSubscribers(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String?>(
                    value: _stateFilter,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any')),
                      ..._availableStates
                          .map((state) => DropdownMenuItem(value: state, child: Text(state)))
                          .toList(),
                    ],
                    onChanged: (value) async {
                      setState(() => _stateFilter = value);
                      await _loadSubscribers(reset: true);
                    },
                  ),
                ),
                FilterChip(
                  label: const Text('Also Donors'),
                  selected: _donorsOnly,
                  onSelected: (value) async {
                    setState(() => _donorsOnly = value);
                    await _loadSubscribers(reset: true);
                  },
                  selectedColor: chipStyle.backgroundColor,
                ),
                FilterChip(
                  label: const Text('Event Attendees'),
                  selected: _eventAttendeesOnly,
                  onSelected: (value) async {
                    setState(() => _eventAttendeesOnly = value);
                    await _loadSubscribers(reset: true);
                  },
                  selectedColor: chipStyle.backgroundColor,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(_optInStart != null && _optInEnd != null
                          ? '${_dateFormat.format(_optInStart!)} - ${_dateFormat.format(_optInEnd!)}'
                          : 'Opt-in Range'),
                    ),
                    if (_optInStart != null)
                      IconButton(
                        tooltip: 'Clear range',
                        onPressed: _clearDateRange,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriberList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_subscribers.isEmpty) {
      return Column(
        children: const [
          SizedBox(height: 32),
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('No subscribers match the current filters.'),
        ],
      );
    }

    final isWide = MediaQuery.of(context).size.width > 960;
    final crossAxisCount = isWide ? 2 : 1;
    final childAspectRatio = isWide ? 2.5 : 1.8;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _subscribers.length,
      itemBuilder: (context, index) {
        final subscriber = _subscribers[index];
        return _SubscriberCard(
          subscriber: subscriber,
          onTap: () => _openDetail(subscriber),
          onEdit: _canManage ? () => _openDetail(subscriber) : null,
        );
      },
    );
  }

  void _openDetail(Subscriber subscriber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _SubscriberDetailSheet(
          subscriber: subscriber,
          canManage: _canManage,
        );
      },
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  final Subscriber subscriber;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  static final DateFormat _dateFormat = DateFormat('MMM d, y');

  const _SubscriberCard({
    required this.subscriber,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (subscriber.subscriptionStatus ?? 'unknown').toLowerCase();
    final statusColor = _statusColor(status, theme);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subscriber.name,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              backgroundColor: statusColor.withOpacity(0.1),
                              side: BorderSide(color: statusColor.withOpacity(0.5)),
                              label: Text(status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(subscriber.email)),
                          ],
                        ),
                        if (subscriber.phoneE164 != null && subscriber.phoneE164!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16),
                              const SizedBox(width: 6),
                              Text(subscriber.phoneE164!),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (subscriber.city != null || subscriber.state != null)
                              _InfoPill(
                                icon: Icons.location_on_outlined,
                                label:
                                    '${subscriber.city ?? ''}${subscriber.city != null && subscriber.state != null ? ', ' : ''}${subscriber.state ?? ''}',
                              ),
                            if (subscriber.county != null)
                              _InfoPill(icon: Icons.map_outlined, label: subscriber.county!),
                            if (subscriber.congressionalDistrict != null)
                              _InfoPill(
                                  icon: Icons.account_balance_outlined,
                                  label: 'CD ${subscriber.congressionalDistrict}'),
                            if (subscriber.optinDate != null)
                              _InfoPill(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'Opt-in ${_dateFormat.format(subscriber.optinDate!)}'),
                            if (subscriber.source != null)
                              _InfoPill(icon: Icons.source_outlined, label: subscriber.source!),
                            if (subscriber.eventAttendanceCount > 0)
                              _InfoPill(
                                icon: Icons.event_available_outlined,
                                label: '${subscriber.eventAttendanceCount} events',
                              ),
                            if (subscriber.donor != null)
                              _InfoPill(
                                icon: Icons.volunteer_activism_outlined,
                                label:
                                    'Donor • ${(subscriber.donor!.totalDonated ?? 0).toStringAsFixed(2)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'View details',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: onTap,
                      ),
                      if (onEdit != null)
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: onEdit,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (subscriber.tagList.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subscriber.tagList
                      .map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'subscribed':
        return Colors.green;
      case 'unsubscribed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'cleaned':
        return Colors.grey;
      default:
        return theme.colorScheme.primary;
    }
  }
}

class _SubscriberDetailSheet extends StatelessWidget {
  final Subscriber subscriber;
  final bool canManage;

  const _SubscriberDetailSheet({
    required this.subscriber,
    required this.canManage,
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
        initialChildSize: 0.7,
        minChildSize: 0.5,
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
                      child: Text(
                        subscriber.name,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    Chip(
                      label: Text(subscriber.subscriptionStatus ?? 'unknown'),
                      backgroundColor: Colors.blueGrey.withOpacity(0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _detailItem('Email', subscriber.email, icon: Icons.email_outlined),
                    if (subscriber.phoneE164?.isNotEmpty ?? false)
                      _detailItem('Phone', subscriber.phoneE164!, icon: Icons.phone_outlined),
                    if (subscriber.dateOfBirth != null)
                      _detailItem(
                        'Date of Birth',
                        DateFormat('MMM d, y').format(subscriber.dateOfBirth!),
                        icon: Icons.cake_outlined,
                      ),
                    if (subscriber.address != null)
                      _detailItem('Address', subscriber.address!, icon: Icons.home_outlined),
                    if (subscriber.city != null || subscriber.state != null)
                      _detailItem(
                        'Location',
                        '${subscriber.city ?? ''}${subscriber.city != null && subscriber.state != null ? ', ' : ''}${subscriber.state ?? ''}',
                        icon: Icons.location_city_outlined,
                      ),
                    if (subscriber.zipCode != null)
                      _detailItem('ZIP', subscriber.zipCode!, icon: Icons.local_post_office_outlined),
                    if (subscriber.county != null)
                      _detailItem('County', subscriber.county!, icon: Icons.map_outlined),
                    if (subscriber.congressionalDistrict != null)
                      _detailItem('Congressional District', subscriber.congressionalDistrict!),
                    if (subscriber.houseDistrict != null)
                      _detailItem('House District', subscriber.houseDistrict!),
                    if (subscriber.senateDistrict != null)
                      _detailItem('Senate District', subscriber.senateDistrict!),
                    if (subscriber.employer != null)
                      _detailItem('Employer', subscriber.employer!, icon: Icons.badge_outlined),
                    if (subscriber.source != null)
                      _detailItem('Source', subscriber.source!, icon: Icons.source_outlined),
                    if (subscriber.optinDate != null)
                      _detailItem(
                        'Opt-in Date',
                        DateFormat('MMM d, y').format(subscriber.optinDate!),
                        icon: Icons.event_available_outlined,
                      ),
                    if (subscriber.lastSyncedAt != null)
                      _detailItem(
                        'Last Synced',
                        DateFormat('MMM d, y').format(subscriber.lastSyncedAt!),
                        icon: Icons.sync_outlined,
                      ),
                    _detailItem('Status', subscriber.subscriptionStatus ?? 'unknown'),
                  ],
                ),
                const SizedBox(height: 12),
                if (subscriber.tagList.isNotEmpty) ...[
                  Text('Tags', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: subscriber.tagList
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (subscriber.donor != null) ...[
                  Text('Donor Profile', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Total Donated: \$${(subscriber.donor!.totalDonated ?? 0).toStringAsFixed(2)}'),
                  Text('Donation Count: ${subscriber.donor!.donationCount}'),
                  if (subscriber.donor!.lastDonationDate != null)
                    Text(
                        'Last Donation: ${DateFormat('MMM d, y').format(subscriber.donor!.lastDonationDate!)}'),
                  const SizedBox(height: 12),
                ],
                if (subscriber.eventAttendanceCount > 0) ...[
                  Text('Events Attended', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${subscriber.eventAttendanceCount} events recorded'),
                  const SizedBox(height: 12),
                ],
                if (subscriber.notes?.isNotEmpty ?? false) ...[
                  Text('Notes', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subscriber.notes!),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showComingSoon(context),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View Full Details'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: canManage ? () => _showComingSoon(context) : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Subscriber'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: canManage ? () => _showComingSoon(context) : null,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Add Note'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailItem(String label, String value, {IconData? icon}) {
    return SizedBox(
      width: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Management actions coming soon.')),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _StatsTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatsTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        color: color.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      value.toString(),
                      style: theme.textTheme.headlineSmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
