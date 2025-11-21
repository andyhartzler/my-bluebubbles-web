import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _grassrootsGreen = Color(0xFF43A047);
const _justicePurple = Color(0xFF6A1B9A);

class DonorsListScreen extends StatefulWidget {
  final bool embed;

  const DonorsListScreen({super.key, this.embed = false});

  @override
  State<DonorsListScreen> createState() => _DonorsListScreenState();
}

class _DonorsListScreenState extends State<DonorsListScreen> {
  final DonorRepository _repository = DonorRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minTotalController = TextEditingController();

  List<Donor> _donors = [];
  List<Donor> _visibleDonors = [];
  bool _loading = true;
  String? _error;
  bool? _recurringFilter;
  bool? _linkedFilter;
  String _sortField = 'name';
  bool _ascending = true;

  int _totalDonors = 0;
  int _recurringCount = 0;
  int _linkedCount = 0;
  double _totalRaised = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minTotalController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_repository.isReady) {
      setState(() {
        _loading = false;
        _error = 'CRM Supabase is not configured. Add Supabase credentials to enable Donors.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await _repository.getDonorStats();
      final result = await _repository.fetchDonors();

      if (!mounted) return;
      setState(() {
        _donors = result.donors;
        _totalDonors = stats['total'] as int? ?? result.donors.length;
        _recurringCount = stats['recurring'] as int? ?? 0;
        _linkedCount = stats['linked'] as int? ?? 0;
        _totalRaised = stats['totalRaised'] as double? ?? _calculateTotalRaised(result.donors);
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load donors: $e';
        _loading = false;
      });
    }
  }

  void _handleSearchChanged() {
    _applyFilters();
  }

  double _calculateTotalRaised(List<Donor> donors) {
    return donors.fold<double>(0, (sum, donor) => sum + (donor.totalDonated ?? 0));
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final minTotal = double.tryParse(_minTotalController.text.trim());

    var filtered = [..._donors];

    if (query.isNotEmpty) {
      filtered = filtered.where((donor) {
        return (donor.name ?? '').toLowerCase().contains(query) ||
            (donor.email ?? '').toLowerCase().contains(query) ||
            (donor.phone ?? '').toLowerCase().contains(query);
      }).toList();
    }

    if (_recurringFilter != null) {
      filtered = filtered.where((donor) => donor.isRecurringDonor == _recurringFilter).toList();
    }

    if (_linkedFilter != null) {
      filtered = filtered
          .where((donor) => _linkedFilter! ? donor.memberId != null : donor.memberId == null)
          .toList();
    }

    if (minTotal != null) {
      filtered = filtered.where((donor) => (donor.totalDonated ?? 0) >= minTotal).toList();
    }

    filtered.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case 'total_donated':
          comparison = (a.totalDonated ?? 0).compareTo(b.totalDonated ?? 0);
          break;
        case 'created_at':
          comparison = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
          break;
        case 'phone':
          comparison = (a.phone ?? '').compareTo(b.phone ?? '');
          break;
        case 'member_id':
          comparison = (a.memberId ?? '').compareTo(b.memberId ?? '');
          break;
        default:
          comparison = (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
      }
      return _ascending ? comparison : -comparison;
    });

    setState(() {
      _visibleDonors = filtered;
    });
  }

  Future<void> _openMember(Donor donor) async {
    if (donor.memberId == null) return;
    try {
      final Member? member = await _memberRepository.getMemberById(donor.memberId!);
      if (!mounted || member == null) return;
      await Navigator.of(context).push(
        ThemeSwitcher.buildPageRoute(
          builder: (context) => TitleBarWrapper(
            child: MemberDetailScreen(member: member),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load member profile: $e')),
      );
    }
  }

  Widget _buildHeroCard({
    required String title,
    required String value,
    required Color color,
    IconData? icon,
    String? subtitle,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(icon, color: Colors.white),
              ),
            if (icon != null) const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search donors',
            ),
          ),
        ),
        DropdownButton<bool?>(
          value: _recurringFilter,
          underline: const SizedBox.shrink(),
          onChanged: (value) {
            setState(() => _recurringFilter = value);
            _applyFilters();
          },
          items: const [
            DropdownMenuItem(value: null, child: Text('All gifts')),
            DropdownMenuItem(value: true, child: Text('Recurring donors')),
            DropdownMenuItem(value: false, child: Text('One-time donors')),
          ],
        ),
        DropdownButton<bool?>(
          value: _linkedFilter,
          underline: const SizedBox.shrink(),
          onChanged: (value) {
            setState(() => _linkedFilter = value);
            _applyFilters();
          },
          items: const [
            DropdownMenuItem(value: null, child: Text('All profiles')),
            DropdownMenuItem(value: true, child: Text('Linked members')),
            DropdownMenuItem(value: false, child: Text('Guests only')),
          ],
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _minTotalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Min total',
              prefixText: r'$ ',
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ),
        TextButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();

    DataColumn buildColumn(String label, String field, {bool numeric = false}) {
      return DataColumn(
        numeric: numeric,
        label: InkWell(
          onTap: () => _updateSort(field),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (_sortField == field)
                Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
            ],
          ),
        ),
        onSort: (index, ascending) => _updateSort(field, ascending: ascending),
      );
    }

    final rows = _visibleDonors.map((donor) {
      final recurring = donor.isRecurringDonor ?? false;
      return DataRow(
        cells: [
          DataCell(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(donor.name ?? 'Unknown donor', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (donor.email != null)
                Text(
                  donor.email!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          )),
          DataCell(Text(donor.phone ?? '—')),
          DataCell(Row(
            children: [
              if (recurring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _grassrootsGreen.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Recurring'),
                ),
              if (recurring) const SizedBox(width: 8),
              Text(currency.format(donor.totalDonated ?? 0)),
            ],
          )),
          DataCell(
            donor.memberId != null
                ? TextButton.icon(
                    onPressed: () => _openMember(donor),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View member'),
                  )
                : const Text('Not linked'),
          ),
          DataCell(_buildRowActions(donor)),
        ],
      );
    }).toList();

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No donors match your filters yet.')),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _columnIndex(_sortField),
        sortAscending: _ascending,
        columns: [
          buildColumn('Donor', 'name'),
          buildColumn('Phone', 'phone'),
          buildColumn('Total Given', 'total_donated', numeric: true),
          buildColumn('CRM Link', 'member_id'),
          const DataColumn(label: Text('Actions')),
        ],
        rows: rows,
      ),
    );
  }

  int? _columnIndex(String field) {
    switch (field) {
      case 'name':
        return 0;
      case 'phone':
        return 1;
      case 'total_donated':
        return 2;
      case 'member_id':
        return 3;
      default:
        return null;
    }
  }

  void _updateSort(String field, {bool? ascending}) {
    setState(() {
      if (_sortField == field && ascending == null) {
        _ascending = !_ascending;
      } else {
        _sortField = field;
        _ascending = ascending ?? true;
      }
    });
    _applyFilters();
  }

  Widget _buildRowActions(Donor donor) {
    return Wrap(
      spacing: 6,
      children: [
        IconButton(
          tooltip: 'Email donor',
          icon: const Icon(Icons.email_outlined),
          onPressed: donor.email == null ? null : () => _launch(Uri.parse('mailto:${donor.email}')),
        ),
        IconButton(
          tooltip: 'Call donor',
          icon: const Icon(Icons.call_outlined),
          onPressed: donor.phone == null ? null : () => _launch(Uri.parse('tel:${donor.phone}')),
        ),
        IconButton(
          tooltip: 'Copy phone',
          icon: const Icon(Icons.copy),
          onPressed: donor.phone == null
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: donor.phone!));
                },
        ),
        if (donor.memberId != null)
          IconButton(
            tooltip: 'View member profile',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openMember(donor),
          ),
      ],
    );
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseReady = CRMConfig.crmEnabled && CRMSupabaseService().isInitialized;

    if (!supabaseReady) {
      return _buildScaffold(
        child: const Center(
          child: Text('CRM Supabase is not configured. Add Supabase credentials to enable Donors.'),
        ),
      );
    }

    if (_loading) {
      return _buildScaffold(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildScaffold(
        child: Center(child: Text(_error!)),
      );
    }

    final currency = NumberFormat.compactSimpleCurrency();
    final averageGift = _totalDonors == 0 ? 0 : _totalRaised / _totalDonors;

    return _buildScaffold(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fundraising', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Track donor relationships and giving performance.', style: theme.textTheme.bodyMedium),
                ],
              ),
              IconButton(
                tooltip: 'Refresh donors',
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final cards = [
              _buildHeroCard(
                title: 'Total Raised',
                value: currency.format(_totalRaised),
                subtitle: 'Across $_totalDonors donors',
                color: _momentumBlue,
                icon: Icons.volunteer_activism,
              ),
              _buildHeroCard(
                title: 'Recurring Donors',
                value: _recurringCount.toString(),
                subtitle:
                    '${((_recurringCount / (_totalDonors == 0 ? 1 : _totalDonors)) * 100).toStringAsFixed(1)}% of base',
                color: _grassrootsGreen,
                icon: Icons.autorenew,
              ),
              _buildHeroCard(
                title: 'Linked to CRM',
                value: _linkedCount.toString(),
                subtitle: 'Connected to member profiles',
                color: _justicePurple,
                icon: Icons.hub_outlined,
              ),
              _buildHeroCard(
                title: 'Average Gift',
                value: currency.format(averageGift),
                subtitle: 'Per donor lifetime total',
                color: _sunriseGold,
                icon: Icons.attach_money,
              ),
            ];

            if (isWide) {
              final children = <Widget>[];
              for (var i = 0; i < cards.length; i++) {
                children.add(Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12),
                    child: cards[i],
                  ),
                ));
              }
              return Row(children: children);
            }

            return Column(
              children: cards
                  .map((card) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: card,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 18),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildTable(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffold({required Widget child}) {
    if (widget.embed) return child;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donors'),
      ),
      body: child,
    );
  }
}
