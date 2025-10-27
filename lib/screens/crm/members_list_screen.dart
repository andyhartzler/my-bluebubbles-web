import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'bulk_message_screen.dart';
import 'member_detail_screen.dart';

/// Screen showing all CRM members with search and filters
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({Key? key}) : super(key: key);

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  bool _loading = true;
  bool _crmReady = false;
  String _searchQuery = '';

  // Filter state
  String? _selectedCounty;
  String? _selectedDistrict;
  List<String>? _selectedCommittees;

  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];

  @override
  void initState() {
    super.initState();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_crmReady) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _memberRepo.getAllMembers(),
        _memberRepo.getUniqueCounties(),
        _memberRepo.getUniqueCongressionalDistricts(),
        _memberRepo.getUniqueCommittees(),
      ]);

      if (!mounted) return;

      setState(() {
        _members = results[0] as List<Member>;
        _filteredMembers = _members;
        _counties = results[1] as List<String>;
        _districts = results[2] as List<String>;
        _committees = results[3] as List<String>;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading members: $e');
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading members: $e')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _members.where((member) {
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesName = member.name.toLowerCase().contains(query);
          final matchesPhone = member.phone?.toLowerCase().contains(query) ?? false;
          if (!matchesName && !matchesPhone) return false;
        }

        if (_selectedCounty != null && member.county != _selectedCounty) {
          return false;
        }

        if (_selectedDistrict != null &&
            member.congressionalDistrict != _selectedDistrict) {
          return false;
        }

        if (_selectedCommittees != null && _selectedCommittees!.isNotEmpty) {
          if (member.committee == null) return false;
          final hasCommittee = _selectedCommittees!.any(
            (c) => member.committee!.contains(c),
          );
          if (!hasCommittee) return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCounty = null;
      _selectedDistrict = null;
      _selectedCommittees = null;
      _filteredMembers = _members;
    });
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String? _formatDistrict(String? value) => Member.formatDistrictLabel(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _crmReady ? _loadData : null,
            tooltip: 'Refresh',
          ),
          if (CRMConfig.bulkMessagingEnabled)
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: _crmReady
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BulkMessageScreen(),
                        ),
                      );
                    }
                  : null,
              tooltip: 'Bulk Message',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_crmReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'CRM Supabase is not configured. Please verify environment variables.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFilters();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              FilterChip(
                label: Text(_selectedCounty ?? 'County'),
                selected: _selectedCounty != null,
                onSelected: (_) => _showCountyFilter(),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(_selectedDistrict ?? 'District'),
                selected: _selectedDistrict != null,
                onSelected: (_) => _showDistrictFilter(),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(
                  _selectedCommittees == null || _selectedCommittees!.isEmpty
                      ? 'Committee'
                      : '${_selectedCommittees!.length} committees',
                ),
                selected: _selectedCommittees != null && _selectedCommittees!.isNotEmpty,
                onSelected: (_) => _showCommitteeFilter(),
              ),
              const SizedBox(width: 8),
              if (_selectedCounty != null ||
                  _selectedDistrict != null ||
                  (_selectedCommittees != null && _selectedCommittees!.isNotEmpty))
                TextButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                  onPressed: _clearFilters,
                ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Showing ${_filteredMembers.length} of ${_members.length} members',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: _filteredMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No members found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = _filteredMembers[index];
                    return _buildMemberTile(member);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(Member member) {
    final phoneDisplay = _hasText(member.phone)
        ? member.phone!.trim()
        : (_hasText(member.phoneE164) ? member.phoneE164!.trim() : null);

    final locationBits = <String>[
      if (_hasText(member.county)) member.county!.trim(),
      if (_formatDistrict(member.congressionalDistrict) != null)
        _formatDistrict(member.congressionalDistrict)!,
    ];

    return ListTile(
      leading: CircleAvatar(
        child: Text(member.name[0].toUpperCase()),
      ),
      title: Text(member.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phoneDisplay != null) Text(phoneDisplay),
          if (locationBits.isNotEmpty)
            Text(locationBits.join(' • '), style: const TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.optOut)
            const Chip(
              label: Text('Opted Out', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.red,
              labelStyle: TextStyle(color: Colors.white),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(member: member),
          ),
        );
      },
    );
  }

  void _showCountyFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by County'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Counties'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedCounty,
                  onChanged: (value) {
                    setState(() => _selectedCounty = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
              ..._counties.map((county) => ListTile(
                    title: Text(county),
                    leading: Radio<String?>(
                      value: county,
                      groupValue: _selectedCounty,
                      onChanged: (value) {
                        setState(() => _selectedCounty = value);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistrictFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Congressional District'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Districts'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedDistrict,
                  onChanged: (value) {
                    setState(() => _selectedDistrict = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
              ..._districts.map((district) {
                final label = _formatDistrict(district) ?? district;
                return ListTile(
                    title: Text('District $label'),
                    leading: Radio<String?>(
                      value: district,
                      groupValue: _selectedDistrict,
                      onChanged: (value) {
                        setState(() => _selectedDistrict = value);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                  );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommitteeFilter() {
    final tempSelected = List<String>.from(_selectedCommittees ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Committee'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setDialogState) => ListView(
              shrinkWrap: true,
              children: _committees.map((committee) {
                final isSelected = tempSelected.contains(committee);
                return CheckboxListTile(
                  title: Text(committee),
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        tempSelected.add(committee);
                      } else {
                        tempSelected.remove(committee);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCommittees = tempSelected.isEmpty ? null : tempSelected;
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
