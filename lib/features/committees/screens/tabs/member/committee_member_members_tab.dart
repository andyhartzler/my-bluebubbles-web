import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/member.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Read-only members tab for committee members (non-executive)
/// Shows the member directory without ability to:
/// - View member details
/// - Add or remove members
class CommitteeMemberMembersTab extends StatefulWidget {
  final Committee committee;

  const CommitteeMemberMembersTab({
    super.key,
    required this.committee,
  });

  @override
  State<CommitteeMemberMembersTab> createState() => _CommitteeMemberMembersTabState();
}

class _CommitteeMemberMembersTabState extends State<CommitteeMemberMembersTab> {
  final CommitteeRepository _repository = CommitteeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  List<String> _allSchools = [];
  bool _loading = true;
  String? _error;
  String? _selectedSchoolFilter;

  Committee get committee => widget.committee;

  bool get _isSchoolCommittee =>
      committee.id == 'College Democrats' || committee.id == 'High School Democrats';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getMembersForCommittee(committee.name),
        _loadAllSchools(),
      ]);

      if (!mounted) return;

      final members = results[0] as List<Member>;
      final allSchools = results[1] as List<String>;

      setState(() {
        _members = members;
        _filteredMembers = members;
        _allSchools = allSchools;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load members: $e';
        _loading = false;
      });
    }
  }

  Future<List<String>> _loadAllSchools() async {
    if (!_isSchoolCommittee) return [];

    try {
      Map<String, int> distribution;
      if (committee.id == 'College Democrats') {
        distribution = await _repository.getCollegeDistribution();
      } else {
        distribution = await _repository.getHighSchoolDistribution();
      }
      final schools = distribution.keys.toList()..sort();
      return schools;
    } catch (e) {
      return [];
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredMembers = _members.where((member) {
        // Apply school filter
        if (_selectedSchoolFilter != null && _selectedSchoolFilter!.isNotEmpty) {
          final memberSchool = _getSchoolDisplayName(member);
          if (memberSchool != _selectedSchoolFilter) {
            return false;
          }
        }

        // Apply text search
        if (query.isEmpty) return true;

        return member.name.toLowerCase().contains(query) ||
            (member.college?.toLowerCase().contains(query) ?? false) ||
            (member.highSchool?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _setSchoolFilter(String? school) {
    if (_selectedSchoolFilter == school) return;
    setState(() => _selectedSchoolFilter = school);
    _filterMembers();
  }

  String? _getSchoolDisplayName(Member member) {
    if (committee.id == 'College Democrats') {
      return member.college;
    } else if (committee.id == 'High School Democrats') {
      return member.highSchool;
    }
    return member.chapterName;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: _unityBlue),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadMembers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _momentumBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final schoolLabel = committee.id == 'College Democrats' ? 'College' : 'High School';

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _unityBlue), // Dark text on white background
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(color: _unityBlue.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: _momentumBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _momentumBlue.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _momentumBlue.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _momentumBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // School filter dropdown
          if (_isSchoolCommittee && _allSchools.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    committee.id == 'College Democrats' ? Icons.school : Icons.domain,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter by $schoolLabel:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _momentumBlue.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _allSchools.contains(_selectedSchoolFilter) ? _selectedSchoolFilter : null,
                          isExpanded: true,
                          hint: Text('All ${schoolLabel.toLowerCase()}s'),
                          onChanged: _setSchoolFilter,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All ${schoolLabel.toLowerCase()}s'),
                            ),
                            ..._allSchools.map(
                              (school) => DropdownMenuItem<String?>(
                                value: school,
                                child: Text(
                                  school,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedSchoolFilter != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20, color: Colors.white),
                      onPressed: () => _setSchoolFilter(null),
                      tooltip: 'Clear filter',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),

          if (_isSchoolCommittee && _allSchools.isNotEmpty)
            const SizedBox(height: 12),

          // Member count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${_filteredMembers.length} member${_filteredMembers.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadMembers,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Member list
          Expanded(
            child: _filteredMembers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No members match your search'
                              : 'No members in this committee',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      return _buildMemberCard(member);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Member member) {
    final theme = Theme.of(context);
    final photoUrl = member.primaryProfilePhotoUrl;
    final schoolName = _getSchoolDisplayName(member);
    final cd = member.congressionalDistrict;
    final age = _calculateAge(member.dateOfBirth);
    final dateJoined = _formatDateJoined(member.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            CorsAwareAvatar(
              imageUrl: photoUrl,
              radius: 26,
              backgroundColor: Colors.white.withOpacity(0.2),
              fallbackText: member.name,
              fallbackIconColor: Colors.white,
              fallbackTextColor: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (schoolName != null && schoolName.isNotEmpty)
                        _buildInfoChip(
                          _isSchoolCommittee && committee.id == 'College Democrats'
                              ? Icons.school
                              : Icons.domain,
                          schoolName,
                        ),
                      if (cd != null && cd.isNotEmpty)
                        _buildInfoChip(Icons.how_to_vote_outlined, 'CD $cd'),
                      if (age != null)
                        _buildInfoChip(Icons.cake_outlined, '$age yrs'),
                      if (dateJoined != null)
                        _buildInfoChip(Icons.calendar_today_outlined, dateJoined),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  int? _calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age > 0 ? age : null;
  }

  String? _formatDateJoined(DateTime? createdAt) {
    if (createdAt == null) return null;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt.month - 1]} ${createdAt.year}';
  }
}
