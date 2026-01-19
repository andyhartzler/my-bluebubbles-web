import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

class CommitteeMembersTab extends StatefulWidget {
  final Committee committee;
  final String? initialSchoolFilter;
  final VoidCallback? onSchoolFilterCleared;

  const CommitteeMembersTab({
    super.key,
    required this.committee,
    this.initialSchoolFilter,
    this.onSchoolFilterCleared,
  });

  @override
  State<CommitteeMembersTab> createState() => _CommitteeMembersTabState();
}

class _CommitteeMembersTabState extends State<CommitteeMembersTab> {
  final CommitteeRepository _repository = CommitteeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  List<String> _allSchools = []; // All schools from the database for this committee type
  bool _loading = true;
  String? _error;
  String? _selectedSchoolFilter;

  Committee get committee => widget.committee;

  bool get _isSchoolCommittee =>
      committee.id == 'College Democrats' || committee.id == 'High School Democrats';

  @override
  void initState() {
    super.initState();
    _selectedSchoolFilter = widget.initialSchoolFilter;
    _loadMembers();
    _searchController.addListener(_filterMembers);
  }

  @override
  void didUpdateWidget(covariant CommitteeMembersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Apply new school filter if it changed
    if (widget.initialSchoolFilter != oldWidget.initialSchoolFilter &&
        widget.initialSchoolFilter != null) {
      setState(() {
        _selectedSchoolFilter = widget.initialSchoolFilter;
      });
      _filterMembers();
    }
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
      // Load members and all schools in parallel
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

      // Apply initial filter if provided
      if (_selectedSchoolFilter != null) {
        _filterMembers();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load members: $e';
        _loading = false;
      });
    }
  }

  /// Load all schools from the database (not just from committee members)
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
      print('Error loading schools: $e');
      return [];
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredMembers = _members.where((member) {
        // Apply school filter first if selected
        if (_selectedSchoolFilter != null && _selectedSchoolFilter!.isNotEmpty) {
          final memberSchool = _getSchoolDisplayName(member);
          if (memberSchool != _selectedSchoolFilter) {
            return false;
          }
        }

        // Apply text search filter
        if (query.isEmpty) {
          return true;
        }

        return member.name.toLowerCase().contains(query) ||
            (member.email?.toLowerCase().contains(query) ?? false) ||
            (member.phone?.toLowerCase().contains(query) ?? false) ||
            (member.chapterName?.toLowerCase().contains(query) ?? false) ||
            (member.college?.toLowerCase().contains(query) ?? false) ||
            (member.highSchool?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _setSchoolFilter(String? school) {
    if (_selectedSchoolFilter == school) return;
    setState(() {
      _selectedSchoolFilter = school;
    });
    _filterMembers();
    // Notify parent if filter is cleared
    if (school == null) {
      widget.onSchoolFilterCleared?.call();
    }
  }

  void _openMemberDetail(Member member) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MemberDetailScreen(member: member),
        ),
      ),
    );
  }

  /// Get the appropriate school name to display based on committee type
  String? _getSchoolDisplayName(Member member) {
    if (committee.id == 'College Democrats') {
      // Show college name for College Democrats
      return member.college;
    } else if (committee.id == 'High School Democrats') {
      // Show high school name for High School Democrats
      return member.highSchool;
    }
    // For other committees, show chapter name if available
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

    return Scaffold(
      body: BrandedBackground(
        child: RefreshIndicator(
          onRefresh: _loadMembers,
          child: Column(
            children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: _unityBlue),
                decoration: InputDecoration(
                  hintText: 'Search ${committee.displayName} members...',
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

            // School filter dropdown (only for College/HS Democrats)
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
                        return _buildDismissibleMemberCard(member);
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
        backgroundColor: _momentumBlue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDismissibleMemberCard(Member member) {
    return Dismissible(
      key: Key(member.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemoveMember(member),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.person_remove, color: Colors.white),
      ),
      child: _buildMemberCard(member),
    );
  }

  Future<bool> _confirmRemoveMember(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.name} from ${committee.displayName}?\n\n'
          'This will also remove them from the ${committee.displayName} Slack channel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repository.removeMemberFromCommittee(member.id, committee.name);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} removed from ${committee.displayName}')),
        );
        _loadMembers();
        return true;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove member')),
        );
      }
    }
    return false;
  }

  Future<void> _showAddMemberDialog() async {
    final searchController = TextEditingController();
    List<Member> searchResults = [];
    bool searching = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> searchMembers(String query) async {
              if (query.length < 2) {
                setDialogState(() {
                  searchResults = [];
                  searching = false;
                });
                return;
              }

              setDialogState(() => searching = true);

              final results = await _repository.getMembersNotInCommittee(
                committee.name,
                searchQuery: query,
              );

              setDialogState(() {
                searchResults = results;
                searching = false;
              });
            }

            Future<void> addMember(Member member) async {
              final success = await _repository.addMemberToCommittee(member.id, committee.name);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name} added to ${committee.displayName}')),
                );
                _loadMembers();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to add member')),
                );
              }
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isMobile = screenWidth < 600;

            return AlertDialog(
              title: Text(
                'Add Member to ${committee.displayName}',
                style: TextStyle(fontSize: isMobile ? 16 : 20),
              ),
              content: SizedBox(
                width: isMobile ? screenWidth * 0.85 : 400,
                height: isMobile ? screenHeight * 0.5 : 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search members by name or email...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: searchMembers,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: searching
                          ? const Center(child: CircularProgressIndicator())
                          : searchResults.isEmpty
                              ? Center(
                                  child: Text(
                                    searchController.text.length < 2
                                        ? 'Type at least 2 characters to search'
                                        : 'No members found',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).disabledColor,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: searchResults.length,
                                  itemBuilder: (context, index) {
                                    final member = searchResults[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: member.primaryProfilePhotoUrl != null
                                            ? NetworkImage(member.primaryProfilePhotoUrl!)
                                            : null,
                                        backgroundColor: committee.primaryColor.withOpacity(0.2),
                                        child: member.primaryProfilePhotoUrl == null
                                            ? Text(
                                                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                                style: TextStyle(color: committee.primaryColor),
                                              )
                                            : null,
                                      ),
                                      title: Text(member.name),
                                      subtitle: Text(member.preferredEmail ?? ''),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add_circle),
                                        color: committee.primaryColor,
                                        onPressed: () => addMember(member),
                                      ),
                                      onTap: () => addMember(member),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMemberCard(Member member) {
    final theme = Theme.of(context);
    final photoUrl = member.primaryProfilePhotoUrl;
    final schoolName = _getSchoolDisplayName(member);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _openMemberDetail(member),
        borderRadius: BorderRadius.circular(20),
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
                        if (member.preferredEmail != null)
                          _buildInfoChip(
                            icon: Icons.email_outlined,
                            text: member.preferredEmail!,
                          ),
                        if (member.primaryPhone != null)
                          _buildInfoChip(
                            icon: Icons.phone_outlined,
                            text: member.primaryPhone!,
                          ),
                        if (schoolName != null)
                          _buildInfoChip(
                            icon: committee.id == 'College Democrats'
                                ? Icons.school_outlined
                                : Icons.domain_outlined,
                            text: schoolName,
                            highlight: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? _momentumBlue.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: highlight ? Colors.white : Colors.white70,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
