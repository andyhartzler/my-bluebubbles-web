import 'dart:async';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/donation.dart';
import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  static const Color _unityBlue = Color(0xFF273351);
  static const Color _momentumBlue = Color(0xFF32A6DE);

  final DonorRepository _repository = DonorRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool _loading = true;
  String? _error;
  Donor? _donor;
  bool _sendingEmail = false;
  bool _startingMessage = false;

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
        .map((d) => d.donationDate)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, date) {
      if (latest == null) return date;
      return date.isAfter(latest) ? date : latest;
    });
    final eventsCount = donations.where((d) => (d.eventId ?? d.eventName) != null).length;
    final isRecurring = donor.isRecurringDonor ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, donor, totalGiven, isRecurring),
          const SizedBox(height: 16),
          _buildContactCard(theme, donor),
          const SizedBox(height: 16),
          _buildMemberLinkCard(theme, donor.memberId),
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
          _buildGivingChart(theme, donations),
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
    final formattedPhone = _formatPhoneDisplay(donor.phoneE164 ?? donor.phone);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow('Email', donor.email ?? 'Not provided'),
            _buildInfoRow('Phone', formattedPhone ?? 'Not provided'),
            _buildInfoRow('Address', _formatAddress(donor)),
            _buildInfoRow('County', donor.county ?? 'Not provided'),
            _buildInfoRow('Congressional District', donor.congressionalDistrict ?? 'Not provided'),
            _buildInfoRow(
              'Date of Birth',
              donor.dateOfBirth != null ? DateFormat.yMMMd().format(donor.dateOfBirth!) : 'Not provided',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: (donor.phoneE164 ?? donor.phone) == null || _startingMessage ? null : _startMessage,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send message'),
                ),
                ElevatedButton.icon(
                  onPressed: donor.email == null || _sendingEmail ? null : _composeEmail,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Send email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberLinkCard(ThemeData theme, String? memberId) {
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
                  if (memberId != null) ...[
                    Text('Member ID: $memberId'),
                    const Text('Tap below to view full profile.'),
                  ] else
                    const Text('No linked member record'),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (memberId != null)
                  ElevatedButton.icon(
                    onPressed: () => _openMember(memberId),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View member'),
                  ),
                OutlinedButton.icon(
                  onPressed: _openMemberSearch,
                  icon: const Icon(Icons.search),
                  label: Text(memberId == null ? 'Link to member' : 'Change member'),
                ),
              ],
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

  Widget _buildGivingChart(ThemeData theme, List<Donation> donations) {
    if (donations.isEmpty) return const SizedBox.shrink();

    final recent = [...donations]
      ..sort((a, b) => (b.donationDate ?? DateTime(0)).compareTo(a.donationDate ?? DateTime(0)));
    final sample = recent.take(6).toList();
    final maxAmount = sample.map((d) => d.amount ?? 0).fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giving snapshot', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sample.map((donation) {
                final amount = donation.amount ?? 0;
                final height = maxAmount == 0 ? 10.0 : (amount / maxAmount) * 120 + 10;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [_unityBlue, _momentumBlue],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _formatCurrency(amount),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        donation.donationDate != null ? DateFormat.Md().format(donation.donationDate!) : '—',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
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
        final aDate = a.donationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.donationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
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
                final dateText = donation.donationDate != null
                    ? DateFormat.yMMMd().format(donation.donationDate!)
                    : 'Date unknown';
                final title = _formatCurrency(donation.amount ?? 0);
                final subtitle = [
                  dateText,
                  if (donation.eventName != null) 'Event: ${donation.eventName}',
                  if (donation.paymentMethod != null) 'Method: ${donation.paymentMethod}',
                  if (donation.sentThankYou) 'Thank you sent',
                ].join(' • ');
                final notes = donation.notes?.trim();

                return CheckboxListTile(
                  value: donation.sentThankYou,
                  onChanged: (value) => _toggleThankYou(donation, value ?? false),
                  secondary: const Icon(Icons.volunteer_activism),
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
                  controlAffinity: ListTileControlAffinity.trailing,
                  dense: true,
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

  String _formatAddress(Donor donor) {
    final parts = [
      donor.address,
      [donor.city, donor.state].where((p) => (p ?? '').isNotEmpty).join(', '),
      donor.zipCode,
    ].where((part) => part != null && part!.trim().isNotEmpty).join('\n');

    return parts.isEmpty ? 'Not provided' : parts;
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

  Future<void> _startMessage() async {
    final donor = _donor;
    if (donor == null) return;

    final address = _cleanText(donor.phoneE164 ?? donor.phone);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    setState(() => _startingMessage = true);

    try {
      final normalized = address.contains('@') ? address : cleansePhoneNumber(address);
      final lookup = await _lookupServiceAvailability(normalized);
      final isIMessage = lookup ?? normalized.contains('@');

      await Navigator.of(context, rootNavigator: true).push(
        ThemeSwitcher.buildPageRoute(
          builder: (context) => TitleBarWrapper(
            child: ChatCreator(
              initialSelected: [
                SelectedContact(
                  displayName: donor.name ?? '',
                  address: normalized,
                  isIMessage: isIMessage,
                ),
              ],
              initialAttachments: const [],
              launchConversationOnSend: false,
              popOnSend: false,
              onMessageSent: (_) async {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message sent to ${donor.name ?? 'donor'}')),
                );
              },
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open chat composer: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _startingMessage = false);
      } else {
        _startingMessage = false;
      }
    }
  }

  Future<void> _composeEmail() async {
    final donor = _donor;
    if (donor == null) return;

    final email = _cleanText(donor.email);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address available')),
      );
      return;
    }

    setState(() => _sendingEmail = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulkEmailScreen(
            initialManualEmails: [email],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open email composer: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingEmail = false);
      } else {
        _sendingEmail = false;
      }
    }
  }

  Future<bool?> _lookupServiceAvailability(String address) async {
    try {
      final response = await http.handleiMessageState(address);
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        final available = data['available'];
        if (available is bool) {
          return available;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _cleanText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.simpleCurrency();
    return format.format(value);
  }

  Future<void> _toggleThankYou(Donation donation, bool sent) async {
    setState(() {
      _donor = _donor?.copyWith(
        donations: _donor?.donations
                .map((d) => d.id == donation.id ? d.copyWith(sentThankYou: sent) : d)
                .toList() ??
            [],
      );
    });

    await _repository.updateThankYouStatus(donation.id, sent);
  }

  Future<void> _openMember(String memberId) async {
    final member = await _memberRepository.getMemberById(memberId);
    if (member == null || !mounted) return;
    // ignore: use_build_context_synchronously
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
    );
  }

  Future<void> _openMemberSearch() async {
    final donor = _donor;
    if (donor == null) return;

    final searchController = TextEditingController();
    List<Member> results = [];
    bool searching = false;
    Timer? debounce;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> search([String? queryOverride]) async {
            final query = (queryOverride ?? searchController.text).trim();
            if (query.isEmpty) {
              setState(() {
                results = [];
                searching = false;
              });
              return;
            }
            setState(() => searching = true);
            final members = await _memberRepository.searchMembers(query);
            if (!context.mounted) return;
            setState(() {
              results = members;
              searching = false;
            });
          }

          return AlertDialog(
            title: const Text('Link to member'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search members',
                      hintText: 'Name, email, or phone',
                    ),
                    onChanged: (value) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 300), () => search(value));
                    },
                    onSubmitted: (_) => search(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: searching
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                            ? const Center(child: Text('Search for a member to link.'))
                            : ListView.separated(
                                itemBuilder: (context, index) {
                                  final member = results[index];
                                  return ListTile(
                                    title: Text(member.name ?? 'Unnamed member'),
                                    subtitle: Text(member.phoneE164 ?? member.phone ?? 'No phone'),
                                    trailing: TextButton(
                                      onPressed: () async {
                                        await _repository.linkDonorToMember(donor.id!, member.id);
                                        if (!mounted) return;
                                        Navigator.of(context).pop();
                                        await _load();
                                      },
                                      child: const Text('Link'),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemCount: results.length,
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        });
      },
    );

    debounce?.cancel();
  }

  String _initialForDonor(Donor donor) {
    final displayName = donor.name?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return 'D';
  }
}
