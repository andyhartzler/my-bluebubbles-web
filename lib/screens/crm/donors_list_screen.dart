import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/donation.dart';
import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/donor_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

const _unityBlue = Color(0xFF273351);
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
  List<Donation> _recentDonations = [];
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
  double _recurringTotal = 0;

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
      final donations = await _repository.fetchRecentDonations(limit: 75);

      if (!mounted) return;
      setState(() {
        _donors = result.donors;
        _totalDonors = stats['total'] as int? ?? result.donors.length;
        _recurringCount = stats['recurring'] as int? ?? 0;
        _linkedCount = stats['linked'] as int? ?? 0;
        _totalRaised = stats['totalRaised'] as double? ?? _calculateTotalRaised(result.donors);
        _recurringTotal =
            stats['recurringTotal'] as double? ?? _calculateRecurringTotal(result.donors);
        _recentDonations = donations;
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

  double _calculateRecurringTotal(List<Donor> donors) {
    return donors
        .where((donor) => Donor.inferRecurringFromDonations(donor.donations))
        .fold<double>(0, (sum, donor) => sum + (donor.totalDonated ?? 0));
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
      filtered = filtered
          .where((donor) =>
              Donor.inferRecurringFromDonations(donor.donations) == _recurringFilter)
          .toList();
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String? _formatPhoneDisplay(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      final area = digits.substring(1, 4);
      final prefix = digits.substring(4, 7);
      final line = digits.substring(7);
      return '+1 ($area) $prefix-$line';
    }
    if (phone.startsWith('+')) return phone;
    return '+$phone';
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
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

  Widget _buildDonationList(BuildContext context) {
    if (_recentDonations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No donations recorded yet.')),
      );
    }

    final currency = NumberFormat.simpleCurrency();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final donation = _recentDonations[index];
        final donor = _donors.firstWhere(
          (d) => d.id == donation.donorId,
          orElse: () => Donor(
            id: donation.donorId,
            name: donation.donorName,
            email: donation.donorEmail,
            phone: donation.donorPhone,
            phoneE164: donation.donorPhoneE164,
          ),
        );

        final subtitleChips = <Widget>[];
        subtitleChips.add(_buildInfoChip(Icons.credit_card, donation.paymentMethodLabel));
        if (donation.eventId != null || donation.eventName != null) {
          subtitleChips.add(_buildInfoChip(Icons.event_available, donation.eventName ?? 'Linked event'));
        }
        if (donation.sentThankYou) {
          subtitleChips.add(_buildInfoChip(Icons.favorite, 'Thank you sent'));
        }

        final phoneDisplay = _formatPhoneDisplay(donor.phoneE164 ?? donor.phone ?? donation.donorPhone);
        final county = donor.county;
        final district = donor.congressionalDistrict;
        final age = _calculateAge(donor.dateOfBirth);
        final headerLine = [
          donation.formattedDate,
          if (county != null && county.isNotEmpty) 'County: $county',
          if (district != null && district.isNotEmpty) 'CD: $district',
          if (age != null) 'Age: $age',
        ].where((value) => value.isNotEmpty).join(' • ');

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (donor.id != null) {
                Navigator.of(context).push(
                  ThemeSwitcher.buildPageRoute(
                    builder: (_) => TitleBarWrapper(
                      child: DonorDetailScreen(
                        donorId: donor.id!,
                        initialDonor: donor,
                      ),
                    ),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_unityBlue, _momentumBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerLine,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          donor.name ?? donation.donorName ?? 'Unknown Donor',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phoneDisplay != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              phoneDisplay,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currency.format(donation.amount ?? 0),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: subtitleChips,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showThankYouConfirmation(donation),
                          icon: Icon(
                            donation.sentThankYou
                                ? Icons.check_circle
                                : Icons.mark_email_read_outlined,
                            size: 18,
                          ),
                          label: Text(
                            donation.sentThankYou ? 'Marked sent' : 'Mark sent',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            backgroundColor:
                                donation.sentThankYou ? _grassrootsGreen : _sunriseGold,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          donation.sentThankYou ? 'Thank-you sent' : 'Awaiting thank-you',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: _recentDonations.length,
    );
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

  Future<void> _showThankYouConfirmation(Donation donation) async {
    final markSent = !donation.sentThankYou;
    final amountText = NumberFormat.simpleCurrency().format(donation.amount ?? 0);
    final dateText = donation.donationDate != null
        ? DateFormat.yMMMd().format(donation.donationDate!)
        : 'Unknown date';
    final donorName = donation.donorName ?? 'this donor';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(markSent ? 'Confirm thank-you sent' : 'Mark thank-you pending'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(markSent
                  ? 'Confirm you have sent a thank-you to $donorName.'
                  : 'This will reopen the thank-you task.'),
              const SizedBox(height: 12),
              Text('Donation: $amountText'),
              Text('Date: $dateText'),
              if (donation.eventName != null) Text('Event: ${donation.eventName}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(markSent ? 'Mark sent' : 'Mark unsent'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _toggleThankYou(donation, markSent);
    }
  }

  Future<void> _toggleThankYou(Donation donation, bool sent) async {
    setState(() {
      _recentDonations = _recentDonations
          .map((d) => d.id == donation.id ? d.copyWith(sentThankYou: sent) : d)
          .toList();
    });

    await _repository.updateThankYouStatus(donation.id, sent);
  }

  Future<void> _showAddDonationDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime donationDate = DateTime.now();
    String method = 'Cash';
    String? selectedDonorId;
    String? checkNumber;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add manual donation'),
          content: StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: 'Donor (optional)'),
                    value: selectedDonorId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unattributed')),
                      ..._donors
                          .map((donor) => DropdownMenuItem(
                                value: donor.id,
                                child: Text(donor.name ?? 'Unknown Donor'),
                              ))
                          .toList(),
                    ],
                    onChanged: (value) => setState(() => selectedDonorId = value),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(DateFormat.yMMMd().format(donationDate))),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: donationDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setState(() => donationDate = picked);
                          }
                        },
                        child: const Text('Change date'),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Payment method'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Check', child: Text('Check')),
                      DropdownMenuItem(value: 'In-kind', child: Text('In-kind')),
                    ],
                    onChanged: (value) => setState(() => method = value ?? 'Cash'),
                  ),
                  if (method.toLowerCase() == 'check')
                    TextField(
                      onChanged: (value) => checkNumber = value,
                      decoration: const InputDecoration(labelText: 'Check number'),
                    ),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                ],
              ),
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null) return;

                await _repository.addManualDonation(
                  donorId: selectedDonorId,
                  amount: amount,
                  donationDate: donationDate,
                  paymentMethod: method,
                  checkNumber: checkNumber,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadData();
              },
              child: const Text('Save donation'),
            ),
          ],
        );
      },
    );
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
                    '${((_recurringCount / (_totalDonors == 0 ? 1 : _totalDonors)) * 100).toStringAsFixed(1)}% of base • ${currency.format(_recurringTotal)} lifetime',
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _showAddDonationDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add manual donation'),
              style: ElevatedButton.styleFrom(backgroundColor: _unityBlue, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildDonationList(context),
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
