import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class DonorDetailScreen extends StatefulWidget {
  final String donorId;
  final Donor? initialDonor;

  const DonorDetailScreen({
    super.key,
    required this.donorId,
    this.initialDonor,
  });

  @override
  State<DonorDetailScreen> createState() => _DonorDetailScreenState();
}

class _DonorDetailScreenState extends State<DonorDetailScreen> {
  final DonorRepository _repository = DonorRepository();
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool _loading = true;
  String? _error;
  Donor? _donor;

  @override
  void initState() {
    super.initState();
    _donor = widget.initialDonor;
    _load();
  }

  Future<void> _load() async {
    if (!_supabase.isInitialized) {
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
      final donor = await _repository.fetchDonorDetails(widget.donorId);
      setState(() {
        _donor = donor ?? _donor;
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
        title: const Text('Donor Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
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
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_donor == null) {
      return const Center(child: Text('Unable to load donor.'));
    }

    final donor = _donor!;
    final donations = donor.donations;
    final totalGiven =
        donor.totalDonated ?? donations.fold<double>(0, (sum, d) => sum + (d.amount ?? 0));
    final completedDonations = donations.where((d) => d.amount != null).toList();
    final donationCount = completedDonations.length;
    final averageGift = donationCount > 0 ? totalGiven / donationCount : null;
    final lastDonationDate = completedDonations
        .map((d) => d.donatedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, date) {
      if (latest == null) return date;
      return date.isAfter(latest) ? date : latest;
    });
    final eventsCount = donations.where((d) => (d.eventId ?? d.eventName) != null).length;
    final isRecurring = donor.isRecurringDonor ??
        donations.any((d) => d.recurring == true);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, donor, totalGiven, isRecurring),
          const SizedBox(height: 16),
          _buildContactCard(theme, donor),
          const SizedBox(height: 16),
          _buildMemberLinkCard(theme, donor.member),
          const SizedBox(height: 16),
          _buildSummaryCard(
            theme,
            totalGiven: totalGiven,
            donationCount: donationCount,
            averageGift: averageGift,
            lastDonationDate: lastDonationDate,
            eventsCount: eventsCount,
            isRecurring: isRecurring,
          ),
          const SizedBox(height: 16),
          _buildDonationHistory(theme, donations),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Donor donor, double totalGiven, bool isRecurring) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                _initialForDonor(donor),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          donor.name ?? 'Unknown Donor',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isRecurring)
                        Chip(
                          avatar: const Icon(Icons.autorenew, size: 16),
                          label: const Text('Recurring'),
                          backgroundColor: Colors.green.shade50,
                          side: BorderSide(color: Colors.green.shade200),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total contributed: ${_formatCurrency(totalGiven)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (donor.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Donor since ${DateFormat.yMMMMd().format(donor.createdAt!)}',
                        style: theme.textTheme.bodySmall,
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

  Widget _buildContactCard(ThemeData theme, Donor donor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow('Email', donor.email ?? 'Not provided'),
            _buildInfoRow('Phone', donor.phone ?? 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberLinkCard(ThemeData theme, Member? member) {
    if (member == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No linked member record',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Linked member', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(member.name ?? 'Unknown member'),
                  if (member.phone != null)
                    Text(member.phone!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberDetailScreen(member: member),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('View member'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme, {
    required double totalGiven,
    required int donationCount,
    required double? averageGift,
    required DateTime? lastDonationDate,
    required int eventsCount,
    required bool isRecurring,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildStat('Total Donated', _formatCurrency(totalGiven)),
                _buildStat('Donations', donationCount.toString()),
                _buildStat('Average Gift', averageGift != null ? _formatCurrency(averageGift) : '—'),
                _buildStat('Last Donation',
                    lastDonationDate != null ? DateFormat.yMMMd().format(lastDonationDate) : '—'),
                _buildStat('Events', eventsCount.toString()),
                _buildStat('Recurring', isRecurring ? 'Yes' : 'No'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationHistory(ThemeData theme, List<Donation> donations) {
    if (donations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No donations recorded yet.', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final sorted = [...donations]
      ..sort((a, b) {
        final aDate = a.donatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.donatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Donation History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final donation = sorted[index];
                final dateText = donation.donatedAt != null
                    ? DateFormat.yMMMd().format(donation.donatedAt!)
                    : 'Date unknown';
                final title = _formatCurrency(donation.amount ?? 0);
                final subtitle = [
                  dateText,
                  if (donation.eventName != null) 'Event: ${donation.eventName}',
                  if (donation.eventDate != null)
                    'Event Date: ${DateFormat.yMMMd().format(donation.eventDate!)}',
                  if (donation.method != null) 'Method: ${donation.method}',
                  if (donation.status != null) 'Status: ${donation.status}',
                ].join(' • ');
                final notes = donation.notes?.trim();

                return ListTile(
                  leading: const Icon(Icons.volunteer_activism),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitle),
                      if (notes != null && notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(notes, style: theme.textTheme.bodySmall),
                        ),
                    ],
                  ),
                  trailing: donation.recurring == true
                      ? const Icon(Icons.autorenew, color: Colors.green)
                      : null,
                  isThreeLine: notes != null && notes.isNotEmpty,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  dense: true,
                  minVerticalPadding: 8,
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: sorted.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.simpleCurrency();
    return format.format(value);
  }

  String _initialForDonor(Donor donor) {
    final displayName = donor.name?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return 'D';
  }
}
