import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/screens/crm/donor_detail_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class DonorsScreen extends StatefulWidget {
  const DonorsScreen({super.key});

  @override
  State<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends State<DonorsScreen> {
  final DonorRepository _repository = DonorRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Donor> _donors = [];
  Donor? _selectedDonor;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDonors() async {
    if (!_supabaseService.isInitialized) {
      setState(() {
        _loading = false;
        _error = 'CRM is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.fetchDonors(
        limit: 200,
        searchQuery: _searchController.text,
      );
      setState(() {
        _donors = result.donors;
        _selectedDonor = _resolveSelection(result.donors);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDonors,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search donors by name, email, or phone',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _loadDonors(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loadDonors,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent(theme, isWide)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isWide) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadDonors,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_donors.isEmpty) {
      return const Center(child: Text('No donors found.'));
    }

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth / 2) - 12;
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _donors
                        .map(
                          (donor) => SizedBox(
                            width: tileWidth,
                            child: _buildDonorTile(
                              theme,
                              donor,
                              isSelected: donor.id == (_selectedDonor?.id ?? ''),
                              onTap: () => setState(() => _selectedDonor = donor),
                              showBorderHighlight: true,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildDetailPane(theme, _selectedDonor ?? _donors.first),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: _donors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final donor = _donors[index];
        return _buildDonorTile(
          theme,
          donor,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DonorDetailScreen(
                  donorId: donor.id,
                  initialDonor: donor,
                ),
              ),
            );
            await _loadDonors();
          },
          isSelected: false,
        );
      },
    );
  }

  Donor? _resolveSelection(List<Donor> donors) {
    if (donors.isEmpty) return null;
    if (_selectedDonor == null) return donors.first;

    final match = donors.where((d) => d.id == _selectedDonor!.id);
    return match.isNotEmpty ? match.first : donors.first;
  }

  Widget _buildDonorTile(
    ThemeData theme,
    Donor donor, {
    required VoidCallback onTap,
    required bool isSelected,
    bool showBorderHighlight = false,
  }) {
    final total = donor.totalDonated ?? 0;
    final formatter = NumberFormat.compactSimpleCurrency();
    final chips = <Widget>[];

    if (donor.county != null && donor.county!.isNotEmpty) {
      chips.add(_buildPillChip(Icons.location_city, donor.county!));
    }

    if (donor.congressionalDistrict != null && donor.congressionalDistrict!.isNotEmpty) {
      chips.add(_buildPillChip(Icons.account_balance, 'CD ${donor.congressionalDistrict!}'));
    }

    if (donor.member != null) {
      chips.add(_buildPillChip(Icons.link, donor.member!.name ?? donor.member!.id ?? 'Linked member'));
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: showBorderHighlight && isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                foregroundColor: theme.colorScheme.primary,
                child: Text(_initialFor(donor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            donor.name ?? 'Unknown Donor',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (donor.isRecurringDonor == true)
                          Chip(
                            avatar: const Icon(Icons.autorenew, size: 16),
                            label: const Text('Recurring'),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      donor.email ?? 'No email provided',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chips,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(total),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (donor.donations.isNotEmpty)
                    Text(
                      '${donor.donations.length} gifts',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _initialFor(Donor donor) {
    final name = donor.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  Widget _buildDetailPane(ThemeData theme, Donor? donor) {
    if (donor == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a donor', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Choose a donor tile to view their details.'),
            ],
          ),
        ),
      );
    }

    final formatter = NumberFormat.simpleCurrency();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  foregroundColor: theme.colorScheme.primary,
                  child: Text(_initialFor(donor)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donor.name ?? 'Unknown Donor',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (donor.email != null)
                        Text(
                          donor.email!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lifetime giving', style: theme.textTheme.bodySmall),
                Text(formatter.format(donor.totalDonated ?? 0),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            if (donor.donations.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gifts recorded', style: theme.textTheme.bodySmall),
                  Text(donor.donations.length.toString(), style: theme.textTheme.titleMedium),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (donor.county != null && donor.county!.isNotEmpty)
                  _buildPillChip(Icons.location_city, donor.county!),
                if (donor.congressionalDistrict != null && donor.congressionalDistrict!.isNotEmpty)
                  _buildPillChip(Icons.account_balance, 'CD ${donor.congressionalDistrict!}'),
                if (donor.member != null)
                  _buildPillChip(Icons.link, donor.member!.name ?? donor.member!.id ?? 'Linked member'),
                if (donor.isRecurringDonor == true)
                  _buildPillChip(Icons.autorenew, 'Recurring donor'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DonorDetailScreen(
                        donorId: donor.id,
                        initialDonor: donor,
                      ),
                    ),
                  );
                  await _loadDonors();
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open full profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
