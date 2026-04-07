import 'dart:async';
import 'package:bluebubbles/helpers/mobile_selection_area.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/email_campaign.dart';
import 'package:bluebubbles/services/crm/email_campaign_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'email_campaign_detail_screen.dart';
import 'widgets/campaign_card.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _actionRed = Color(0xFFE63946);
const _grassrootsGreen = Color(0xFF43A047);

class EmailCampaignsTab extends StatefulWidget {
  const EmailCampaignsTab({super.key});

  @override
  State<EmailCampaignsTab> createState() => _EmailCampaignsTabState();
}

class _EmailCampaignsTabState extends State<EmailCampaignsTab> {
  final EmailCampaignRepository _repository = EmailCampaignRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('MMM d, y');

  Timer? _debounce;
  List<EmailCampaign> _campaigns = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _errorState = false;
  String? _errorMessage;

  // Filters
  String? _sourceFilter;
  bool? _sentOnlyFilter;
  DateTime? _sentAfter;
  DateTime? _sentBefore;

  // Filter options
  List<String> _availableSources = [];

  static const _pageSize = 30;

  bool get _crmReady => _supabaseService.isInitialized;

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
        _errorMessage = 'CRM Supabase is not configured. Add credentials to enable Email Campaigns.';
      });
      return;
    }

    await Future.wait([
      _loadCampaigns(reset: true),
      _loadFilters(),
    ]);
  }

  Future<void> _loadFilters() async {
    final sources = await _repository.fetchDistinctSources();
    if (mounted) {
      setState(() => _availableSources = sources);
    }
  }

  Future<void> _loadCampaigns({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final response = await _repository.fetchCampaigns(
      searchQuery: _searchController.text,
      source: _sourceFilter,
      sentAfter: _sentAfter,
      sentBefore: _sentBefore,
      hasSentAt: _sentOnlyFilter,
      limit: _pageSize,
      offset: reset ? 0 : _campaigns.length,
      fetchTotalCount: true,
    );

    if (!mounted) return;

    setState(() {
      if (reset) {
        _campaigns = response.campaigns;
      } else {
        _campaigns = [..._campaigns, ...response.campaigns];
      }
      _loading = false;
      _loadingMore = false;
      final total = response.totalCount ?? response.campaigns.length;
      _hasMore = _campaigns.length < total;
      _errorState = false;
      _errorMessage = null;
    });
  }

  void _handleScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadCampaigns();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadCampaigns(reset: true);
    });
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _sentAfter != null && _sentBefore != null
          ? DateTimeRange(start: _sentAfter!, end: _sentBefore!)
          : null,
    );

    if (range != null) {
      setState(() {
        _sentAfter = range.start;
        _sentBefore = range.end;
      });
      await _loadCampaigns(reset: true);
    }
  }

  void _clearDateRange() {
    setState(() {
      _sentAfter = null;
      _sentBefore = null;
    });
    _loadCampaigns(reset: true);
  }

  void _openCampaignDetail(EmailCampaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmailCampaignDetailScreen(
          campaignId: campaign.id,
          initialCampaign: campaign,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorState) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unable to load email campaigns'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _initialize, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_loading && _campaigns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadCampaigns(reset: true),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final horizontalPadding = isCompact ? 12.0 : 28.0;
        final bottomPadding = isCompact ? 16.0 : 32.0;

        return MobileAwareSelectionArea(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
                sliver: SliverToBoxAdapter(child: _buildFilters(context)),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, bottomPadding),
                sliver: _buildCampaignList(),
              ),
              if (_loadingMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottomPadding),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final totalLabel = _campaigns.isNotEmpty
        ? '${_campaigns.length} campaign${_campaigns.length == 1 ? '' : 's'} loaded'
        : 'Email campaigns';

    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _momentumBlue,
          ),
          padding: const EdgeInsets.all(10),
          child: const Icon(
            Icons.campaign_outlined,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email Campaigns',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                totalLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : () => _initialize(),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
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
                      hintText: 'Search by name or subject',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _loadCampaigns(reset: true);
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
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
                          .map(
                            (source) => DropdownMenuItem(
                              value: source,
                              child: Text(_capitalizeFirst(source)),
                            ),
                          )
                          .toList(),
                    ],
                    onChanged: (value) async {
                      setState(() => _sourceFilter = value);
                      await _loadCampaigns(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<bool?>(
                    value: _sentOnlyFilter,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: true, child: Text('Sent')),
                      DropdownMenuItem(value: false, child: Text('Draft')),
                    ],
                    onChanged: (value) async {
                      setState(() => _sentOnlyFilter = value);
                      await _loadCampaigns(reset: true);
                    },
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _sentAfter != null && _sentBefore != null
                            ? '${_dateFormat.format(_sentAfter!)} - ${_dateFormat.format(_sentBefore!)}'
                            : 'Sent Date Range',
                      ),
                    ),
                    if (_sentAfter != null)
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

  Widget _buildCampaignList() {
    if (_campaigns.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No campaigns match the current filters.'),
          ],
        ),
      );
    }

    final itemCount = _campaigns.length * 2 - 1;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) {
            return const SizedBox(height: 10);
          }
          final campaignIndex = index ~/ 2;
          final campaign = _campaigns[campaignIndex];
          return CampaignCard(
            campaign: campaign,
            onTap: () => _openCampaignDetail(campaign),
          );
        },
        childCount: itemCount > 0 ? itemCount : 0,
      ),
    );
  }
}

String _capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

