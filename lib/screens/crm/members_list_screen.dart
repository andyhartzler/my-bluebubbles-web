import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'bulk_message_screen.dart';
import 'member_detail_screen.dart';

/// Screen showing all CRM members with search and filters
class MembersListScreen extends StatefulWidget {
  final bool embed;

  const MembersListScreen({Key? key, this.embed = false}) : super(key: key);

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

  static const List<List<Color>> _cardGradients = [
    [Color(0xFF4e54c8), Color(0xFF8f94fb)],
    [Color(0xFF11998e), Color(0xFF38ef7d)],
    [Color(0xFFee0979), Color(0xFFff6a00)],
    [Color(0xFFfc5c7d), Color(0xFF6a82fb)],
    [Color(0xFF00b09b), Color(0xFF96c93d)],
  ];

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
    final body = _buildContent(context);

    if (widget.embed) {
      return body;
    }

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
      body: body,
    );
  }

  Widget _buildContent(BuildContext context) {
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

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _buildSearchField(),
        ),
        _buildFilterRow(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Showing ${_filteredMembers.length} of ${_members.length} members',
            style: theme.textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filteredMembers.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width > 1300
                          ? 3
                          : width > 900
                              ? 2
                              : 1;
                      final aspectRatio = crossAxisCount == 1 ? 2.4 : 1.6;

                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) => _buildMemberCard(_filteredMembers[index], index),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
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
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        _applyFilters();
      },
    );
  }

  Widget _buildFilterRow() {
    final hasFilters = _selectedCounty != null ||
        _selectedDistrict != null ||
        (_selectedCommittees != null && _selectedCommittees!.isNotEmpty);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(
            label: _selectedCounty ?? 'County',
            selected: _selectedCounty != null,
            onTap: _showCountyFilter,
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: _selectedDistrict != null
                ? 'District ${_formatDistrict(_selectedDistrict) ?? _selectedDistrict!}'
                : 'District',
            selected: _selectedDistrict != null,
            onTap: _showDistrictFilter,
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: _selectedCommittees == null || _selectedCommittees!.isEmpty
                ? 'Committee'
                : '${_selectedCommittees!.length} committees',
            selected: _selectedCommittees != null && _selectedCommittees!.isNotEmpty,
            onTap: _showCommitteeFilter,
          ),
          if (hasFilters) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 76, color: theme.colorScheme.primary.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              'No members match your filters',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or refreshing to see everyone in your database.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Member member, int index) {
    final theme = Theme.of(context);
    final gradient = _cardGradients[index % _cardGradients.length];
    final phoneDisplay = _hasText(member.phone)
        ? member.phone!.trim()
        : (_hasText(member.phoneE164) ? member.phoneE164!.trim() : null);
    final districtLabel = _formatDistrict(member.congressionalDistrict);

    final highlights = <Widget>[];
    if (phoneDisplay != null) {
      highlights.add(_buildInfoChip(Icons.phone, phoneDisplay));
    }
    if (_hasText(member.county)) {
      highlights.add(_buildInfoChip(Icons.map, member.county!.trim()));
    }
    if (districtLabel != null) {
      highlights.add(_buildInfoChip(Icons.account_balance, 'District $districtLabel'));
    }
    if (_hasText(member.currentChapterMember)) {
      highlights.add(_buildInfoChip(
        Icons.flag,
        'Chapter Status: ${member.currentChapterMember!.trim()}',
      ));
    }
    if (_hasText(member.graduationYear)) {
      highlights.add(_buildInfoChip(Icons.school, 'Grad ${member.graduationYear!.trim()}'));
    }
    if (member.committee != null && member.committee!.isNotEmpty) {
      for (final committee in member.committee!.take(2)) {
        if (_hasText(committee)) {
          highlights.add(_buildInfoChip(Icons.groups, committee.trim()));
        }
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openMember(member),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (member.optOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Opted Out',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (highlights.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: highlights,
                  ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
                    onPressed: () => _openMember(member),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _openMember(Member member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailScreen(member: member),
      ),
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
