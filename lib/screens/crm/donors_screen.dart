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
      final donors = await _repository.fetchDonors(
        limit: 200,
        searchQuery: _searchController.text,
      );
      setState(() {
        _donors = donors;
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
            Expanded(
              child: _buildContent(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
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

    return ListView.separated(
      itemCount: _donors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final donor = _donors[index];
        final total = donor.totalDonated ?? 0;
        final formatter = NumberFormat.simpleCurrency();

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                            donor.name ?? 'Unknown Donor',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            donor.email ?? 'No email provided',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (donor.phone != null)
                            Text(donor.phone!, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatter.format(total), style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (donor.isRecurringDonor == true)
                          Chip(
                            label: const Text('Recurring'),
                            avatar: const Icon(Icons.autorenew, size: 16),
                            backgroundColor: Colors.green.shade50,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (donor.member != null)
                      Text('Linked member: ${donor.member!.name ?? donor.member!.id}',
                          style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    TextButton(
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
                      child: const Text('View details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
