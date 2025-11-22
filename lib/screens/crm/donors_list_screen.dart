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
import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/donor_detail_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/event_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _grassrootsGreen = Color(0xFF43A047);
const _justicePurple = Color(0xFF6A1B9A);

enum _DonationSearchResultType { donor, member, attendee }

class _DonationSearchResult {
  final _DonationSearchResultType type;
  final Donor? donor;
  final Member? member;
  final EventAttendee? attendee;

  const _DonationSearchResult({
    required this.type,
    this.donor,
    this.member,
    this.attendee,
  });

  String get uniqueKey {
    switch (type) {
      case _DonationSearchResultType.donor:
        return 'donor-${donor?.id ?? donor?.email ?? donor?.phone ?? ''}';
      case _DonationSearchResultType.member:
        return 'member-${member?.id ?? member?.email ?? member?.phone ?? ''}';
      case _DonationSearchResultType.attendee:
        return 'attendee-${attendee?.id ?? attendee?.guestEmail ?? attendee?.guestPhone ?? ''}';
    }
  }

  String get displayName {
    switch (type) {
      case _DonationSearchResultType.donor:
        return donor?.name ?? 'Unknown donor';
      case _DonationSearchResultType.member:
        return member?.name ?? 'Unknown member';
      case _DonationSearchResultType.attendee:
        return attendee?.displayName ?? 'Unknown attendee';
    }
  }

  String? get detail {
    switch (type) {
      case _DonationSearchResultType.donor:
        return donor?.email ?? donor?.phone;
      case _DonationSearchResultType.member:
        return member?.email ?? member?.phone ?? member?.phoneE164;
      case _DonationSearchResultType.attendee:
        return attendee?.guestEmail ?? attendee?.guestPhone ?? attendee?.member?.email ?? attendee?.member?.phone;
    }
  }

  IconData get icon {
    switch (type) {
      case _DonationSearchResultType.donor:
        return Icons.volunteer_activism_outlined;
      case _DonationSearchResultType.member:
        return Icons.person_outline;
      case _DonationSearchResultType.attendee:
        return Icons.event_available_outlined;
    }
  }

  String get chipLabel {
    switch (type) {
      case _DonationSearchResultType.donor:
        return 'Donor';
      case _DonationSearchResultType.member:
        return 'Member';
      case _DonationSearchResultType.attendee:
        return 'Event attendee';
    }
  }
}

class DonorsListScreen extends StatefulWidget {
  final bool embed;

  const DonorsListScreen({super.key, this.embed = false});

  @override
  State<DonorsListScreen> createState() => _DonorsListScreenState();
}

class _DonorsListScreenState extends State<DonorsListScreen> {
  final DonorRepository _repository = DonorRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final EventRepository _eventRepository = EventRepository();
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

  Future<List<_DonationSearchResult>> _searchDonationSubjects(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <_DonationSearchResult>[];

    final donorResult = await _repository.fetchDonors(searchQuery: trimmed, limit: 6);
    for (final donor in donorResult.donors) {
      results.add(_DonationSearchResult(type: _DonationSearchResultType.donor, donor: donor));
    }

    final members = await _memberRepository.searchMembers(trimmed);
    for (final member in members.take(6)) {
      results.add(_DonationSearchResult(type: _DonationSearchResultType.member, member: member));
    }

    if (_eventRepository.isReady) {
      final attendees = await _eventRepository.searchHistoricalAttendees(trimmed, limit: 6);
      for (final attendee in attendees) {
        results.add(_DonationSearchResult(type: _DonationSearchResultType.attendee, attendee: attendee));
      }
    }

    final unique = <String, _DonationSearchResult>{};
    for (final result in results) {
      unique.putIfAbsent(result.uniqueKey, () => result);
    }

    return unique.values.toList();
  }

  Future<String?> _ensureDonorForMember(Member member) async {
    final memberId = member.id;
    if (memberId == null) return null;

    final existing = await _repository.findDonorByMemberId(memberId);
    if (existing?.id != null) return existing!.id;

    final payload = {
      'member_id': memberId,
      'name': member.name,
      'email': member.email,
      'phone': member.phone ?? member.phoneE164,
      'phone_e164': member.phoneE164 ?? member.phone,
    };

    return _repository.upsertDonor(data: payload);
  }

  Future<String?> _ensureDonorForAttendee(EventAttendee attendee) async {
    if (attendee.memberId != null) {
      final existing = await _repository.findDonorByMemberId(attendee.memberId!);
      if (existing?.id != null) return existing!.id;
    } else if (attendee.guestPhone != null) {
      final existing = await _repository.findDonorByPhone(attendee.guestPhone!);
      if (existing?.id != null) return existing!.id;
    }

    final payload = {
      'member_id': attendee.memberId,
      'name': attendee.member?.name ?? attendee.guestName,
      'email': attendee.member?.email ?? attendee.guestEmail,
      'phone': attendee.member?.phone ?? attendee.guestPhone,
      'phone_e164': attendee.member?.phoneE164 ?? attendee.guestPhone,
      'address': attendee.address,
      'city': attendee.city,
      'state': attendee.state,
      'zip_code': attendee.zip,
      'employer': attendee.employer,
      'occupation': attendee.occupation,
    };

    return _repository.upsertDonor(data: payload);
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
                  Checkbox(
                    value: donation.sentThankYou,
                    onChanged: (value) => _toggleThankYou(donation, value ?? false),
                    checkColor: Colors.white,
                    fillColor: MaterialStateProperty.all(_sunriseGold),
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
    final searchController = TextEditingController();
    final newDonorNameController = TextEditingController();
    final newDonorEmailController = TextEditingController();
    final newDonorPhoneController = TextEditingController();
    final newDonorAddressController = TextEditingController();
    final newDonorCityController = TextEditingController();
    final newDonorStateController = TextEditingController();
    final newDonorZipController = TextEditingController();
    final newDonorEmployerController = TextEditingController();
    final newDonorOccupationController = TextEditingController();
    DateTime donationDate = DateTime.now();
    String method = 'Cash';
    String? checkNumber;
    String? donorId;
    Event? selectedEvent;
    var searchResults = <_DonationSearchResult>[];
    _DonationSearchResult? selectedSubject;
    bool creatingNewDonor = false;
    bool searching = false;

    Timer? debounce;
    final availableEvents = _eventRepository.isReady
        ? await _eventRepository.fetchEvents(upcomingOnly: false, pastOnly: false)
        : <Event>[];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add manual donation'),
          content: StatefulBuilder(builder: (context, setState) {
            Future<void> handleSearch(String value) async {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), () async {
                setState(() => searching = true);
                final results = await _searchDonationSubjects(value);
                if (!mounted) return;
                setState(() {
                  searchResults = results;
                  searching = false;
                });
              });
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search member, donor, or event attendee',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: handleSearch,
                  ),
                  const SizedBox(height: 8),
                  if (selectedSubject != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: Icon(selectedSubject!.icon),
                        title: Text(selectedSubject!.displayName),
                        subtitle: Text(selectedSubject!.detail ?? 'Selected record'),
                        trailing: TextButton(
                          onPressed: () => setState(() {
                            selectedSubject = null;
                            creatingNewDonor = false;
                          }),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                  if (!creatingNewDonor)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (searching)
                          const LinearProgressIndicator(minHeight: 2)
                        else if (searchResults.isEmpty && searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              'No matches found. Create a new donor with full details.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ...searchResults.map(
                          (result) => ListTile(
                            dense: true,
                            leading: Icon(result.icon),
                            title: Text(result.displayName),
                            subtitle: Row(
                              children: [
                                Chip(label: Text(result.chipLabel)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(result.detail ?? '', overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            onTap: () => setState(() {
                              selectedSubject = result;
                              creatingNewDonor = false;
                            }),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              creatingNewDonor = true;
                              selectedSubject = null;
                              if (newDonorNameController.text.isEmpty &&
                                  searchController.text.trim().isNotEmpty) {
                                newDonorNameController.text = searchController.text.trim();
                              }
                            }),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Create new donor with details'),
                          ),
                        ),
                      ],
                    ),
                  if (creatingNewDonor) ...[
                    const SizedBox(height: 8),
                    Text('New donor details', style: Theme.of(context).textTheme.titleSmall),
                    TextField(
                      controller: newDonorNameController,
                      decoration: const InputDecoration(labelText: 'Full name *'),
                    ),
                    TextField(
                      controller: newDonorEmailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: newDonorPhoneController,
                      decoration: const InputDecoration(labelText: 'Phone (E.164 preferred)'),
                    ),
                    TextField(
                      controller: newDonorAddressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newDonorCityController,
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: newDonorStateController,
                            decoration: const InputDecoration(labelText: 'State'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: newDonorZipController,
                            decoration: const InputDecoration(labelText: 'ZIP'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newDonorEmployerController,
                            decoration: const InputDecoration(labelText: 'Employer'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: newDonorOccupationController,
                            decoration: const InputDecoration(labelText: 'Occupation'),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  DropdownButtonFormField<Event?>(
                    value: selectedEvent,
                    decoration: const InputDecoration(labelText: 'Link to event (optional)'),
                    items: [
                      const DropdownMenuItem<Event?>(value: null, child: Text('No event')),
                      ...availableEvents.map(
                        (event) => DropdownMenuItem<Event?>(
                          value: event,
                          child: Text('${event.title ?? 'Untitled'} — '
                              '${event.eventDate != null ? DateFormat.yMMMd().format(event.eventDate!.toLocal()) : 'No date'}'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => selectedEvent = value),
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
                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid donation amount.')),
                  );
                  return;
                }

                if (creatingNewDonor) {
                  final name = newDonorNameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name is required to create a donor.')),
                    );
                    return;
                  }

                  final payload = {
                    'name': name,
                    'email': newDonorEmailController.text.trim().isEmpty
                        ? null
                        : newDonorEmailController.text.trim(),
                    'phone': newDonorPhoneController.text.trim().isEmpty
                        ? null
                        : newDonorPhoneController.text.trim(),
                    'phone_e164': newDonorPhoneController.text.trim().isEmpty
                        ? null
                        : newDonorPhoneController.text.trim(),
                    'address': newDonorAddressController.text.trim().isEmpty
                        ? null
                        : newDonorAddressController.text.trim(),
                    'city': newDonorCityController.text.trim().isEmpty
                        ? null
                        : newDonorCityController.text.trim(),
                    'state': newDonorStateController.text.trim().isEmpty
                        ? null
                        : newDonorStateController.text.trim(),
                    'zip_code': newDonorZipController.text.trim().isEmpty
                        ? null
                        : newDonorZipController.text.trim(),
                    'employer': newDonorEmployerController.text.trim().isEmpty
                        ? null
                        : newDonorEmployerController.text.trim(),
                    'occupation': newDonorOccupationController.text.trim().isEmpty
                        ? null
                        : newDonorOccupationController.text.trim(),
                  };

                  donorId = await _repository.upsertDonor(data: payload);
                } else if (selectedSubject != null) {
                  switch (selectedSubject!.type) {
                    case _DonationSearchResultType.donor:
                      donorId = selectedSubject!.donor?.id;
                      break;
                    case _DonationSearchResultType.member:
                      final member = selectedSubject!.member;
                      if (member != null) {
                        donorId = await _ensureDonorForMember(member);
                      }
                      break;
                    case _DonationSearchResultType.attendee:
                      final attendee = selectedSubject!.attendee;
                      if (attendee != null) {
                        donorId = await _ensureDonorForAttendee(attendee);
                      }
                      break;
                  }
                }

                await _repository.addManualDonation(
                  donorId: donorId,
                  amount: amount,
                  donationDate: donationDate,
                  paymentMethod: method,
                  checkNumber: checkNumber,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  eventId: selectedEvent?.id,
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
    debounce?.cancel();
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
