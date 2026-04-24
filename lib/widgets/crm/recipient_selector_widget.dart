import 'dart:async';

import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart' show CountOption, PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Selection mode for the recipient selector
enum RecipientMode { individual, group, eventAttendees }

/// Reusable widget for selecting survey recipients from the members database.
///
/// Supports three modes:
/// - **Individual** — search and pick specific members
/// - **Group** — filter by demographics (county, district, school, etc.)
/// - **Event Attendees** — use attendees from a specific event (only when [eventId] is set)
class RecipientSelectorWidget extends StatefulWidget {
  /// If set, shows an "Event Attendees" mode option alongside Individual/Group.
  final String? eventId;

  /// Callback fired whenever the selected phone list changes.
  final void Function(List<String> phoneNumbers) onRecipientsChanged;

  /// Pre-selected phone numbers (E.164 format).
  final List<String> initialPhones;

  const RecipientSelectorWidget({
    super.key,
    this.eventId,
    required this.onRecipientsChanged,
    this.initialPhones = const [],
  });

  @override
  State<RecipientSelectorWidget> createState() =>
      _RecipientSelectorWidgetState();
}

class _RecipientSelectorWidgetState extends State<RecipientSelectorWidget> {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  SupabaseClient get _client => _supabase.client;

  // ── Mode ──────────────────────────────────────────────────────────────
  RecipientMode _mode = RecipientMode.individual;

  // ── Individual mode state ─────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;

  /// Selected members: phone_e164 -> member map
  final Map<String, Map<String, dynamic>> _selectedMembers = {};

  // ── Group mode state ──────────────────────────────────────────────────
  List<String> _counties = [];
  List<String> _highSchools = [];
  List<String> _colleges = [];
  List<String> _districts = [];

  String? _selectedCounty;
  String? _selectedHighSchool;
  String? _selectedCollege;
  String? _selectedDistrict;
  int? _ageMin;
  int? _ageMax;
  bool _chapterMembersOnly = false;

  final TextEditingController _ageMinController = TextEditingController();
  final TextEditingController _ageMaxController = TextEditingController();

  // ── Shared state ──────────────────────────────────────────────────────
  int _matchCount = 0;
  bool _countLoading = false;
  bool _filterOptionsLoading = true;

  // ── Event attendees state ─────────────────────────────────────────────
  int _eventAttendeeCount = 0;
  bool _eventCountLoading = false;

  @override
  void initState() {
    super.initState();

    // Hydrate initial selection
    for (final phone in widget.initialPhones) {
      _selectedMembers[phone] = {'phone_e164': phone, 'name': phone};
    }

    _loadFilterOptions();

    if (widget.eventId != null) {
      _loadEventAttendeeCount();
    }

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _loadFilterOptions() async {
    if (!_supabase.isInitialized) return;
    setState(() => _filterOptionsLoading = true);

    try {
      final futures = await Future.wait([
        _client
            .from('members')
            .select('county')
            .not('county', 'is', null)
            .not('opt_out', 'eq', true),
        _client
            .from('members')
            .select('high_school')
            .not('high_school', 'is', null)
            .not('opt_out', 'eq', true),
        _client
            .from('members')
            .select('college')
            .not('college', 'is', null)
            .not('opt_out', 'eq', true),
        _client
            .from('members')
            .select('congressional_district')
            .not('congressional_district', 'is', null)
            .not('opt_out', 'eq', true),
      ]);

      if (!mounted) return;

      setState(() {
        _counties = _distinctValues(futures[0] as List, 'county');
        _highSchools = _distinctValues(futures[1] as List, 'high_school');
        _colleges = _distinctValues(futures[2] as List, 'college');
        _districts =
            _distinctValues(futures[3] as List, 'congressional_district');
        _filterOptionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _filterOptionsLoading = false);
      debugPrint('[RecipientSelector] Failed to load filter options: $e');
    }
  }

  List<String> _distinctValues(List<dynamic> rows, String key) {
    final values = rows
        .whereType<Map<String, dynamic>>()
        .map((r) => r[key]?.toString())
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Future<void> _loadEventAttendeeCount() async {
    if (widget.eventId == null || !_supabase.isInitialized) return;
    setState(() => _eventCountLoading = true);

    try {
      final response = await _client
          .from('event_attendees')
          .select('id')
          .eq('event_id', widget.eventId!)
          .count(CountOption.exact);

      if (!mounted) return;
      setState(() {
        _eventAttendeeCount =
            (response is PostgrestResponse) ? (response.count ?? 0) : 0;
        _eventCountLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _eventCountLoading = false);
    }
  }

  // ── Search (Individual mode) ──────────────────────────────────────────

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(_searchController.text.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    if (!_supabase.isInitialized) return;

    setState(() => _searchLoading = true);

    try {
      // Search by name OR phone
      final nameResults = await _client
          .from('members')
          .select('id, name, phone_e164, profile_pictures')
          .not('opt_out', 'eq', true)
          .not('phone_e164', 'is', null)
          .ilike('name', '%$query%')
          .limit(20);

      List<Map<String, dynamic>> phoneResults = [];
      if (query.contains(RegExp(r'\d'))) {
        phoneResults = List<Map<String, dynamic>>.from(await _client
            .from('members')
            .select('id, name, phone_e164, profile_pictures')
            .not('opt_out', 'eq', true)
            .not('phone_e164', 'is', null)
            .ilike('phone_e164', '%$query%')
            .limit(20));
      }

      if (!mounted) return;

      // Merge and deduplicate by id
      final merged = <String, Map<String, dynamic>>{};
      for (final row in [...nameResults, ...phoneResults]) {
        final map = row as Map<String, dynamic>;
        final id = map['id']?.toString() ?? '';
        if (id.isNotEmpty) merged[id] = map;
      }

      setState(() {
        _searchResults = merged.values.toList();
        _searchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      debugPrint('[RecipientSelector] Search error: $e');
    }
  }

  // ── Group count ───────────────────────────────────────────────────────

  Future<void> _updateGroupCount() async {
    if (!_supabase.isInitialized) return;
    setState(() => _countLoading = true);

    try {
      var query = _client
          .from('members')
          .select('phone_e164')
          .not('opt_out', 'eq', true)
          .not('phone_e164', 'is', null);

      query = _applyGroupFilters(query);

      final response = await query.count(CountOption.exact);

      if (!mounted) return;
      setState(() {
        _matchCount =
            (response is PostgrestResponse) ? (response.count ?? 0) : 0;
        _countLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _countLoading = false);
      debugPrint('[RecipientSelector] Count error: $e');
    }
  }

  dynamic _applyGroupFilters(dynamic query) {
    if (_selectedCounty != null) {
      query = query.eq('county', _selectedCounty!);
    }
    if (_selectedHighSchool != null) {
      query = query.eq('high_school', _selectedHighSchool!);
    }
    if (_selectedCollege != null) {
      query = query.eq('college', _selectedCollege!);
    }
    if (_selectedDistrict != null) {
      query = query.eq('congressional_district', _selectedDistrict!);
    }
    if (_chapterMembersOnly) {
      query = query.eq('current_chapter_member', 'Yes');
    }
    if (_ageMin != null) {
      // date_of_birth <= today minus ageMin years (they are at least ageMin old)
      final maxDob = DateTime.now().subtract(Duration(days: _ageMin! * 365));
      query = query.lte('date_of_birth', maxDob.toIso8601String());
    }
    if (_ageMax != null) {
      // date_of_birth >= today minus ageMax years (they are at most ageMax old)
      final minDob = DateTime.now().subtract(Duration(days: (_ageMax! + 1) * 365));
      query = query.gte('date_of_birth', minDob.toIso8601String());
    }
    return query;
  }

  // ── Emit selected phones ─────────────────────────────────────────────

  Future<void> _emitPhones() async {
    switch (_mode) {
      case RecipientMode.individual:
        widget.onRecipientsChanged(_selectedMembers.keys.toList());
        break;

      case RecipientMode.group:
        await _fetchGroupPhones();
        break;

      case RecipientMode.eventAttendees:
        await _fetchEventAttendeePhones();
        break;
    }
  }

  Future<void> _fetchGroupPhones() async {
    if (!_supabase.isInitialized) return;

    try {
      var query = _client
          .from('members')
          .select('phone_e164')
          .not('opt_out', 'eq', true)
          .not('phone_e164', 'is', null);

      query = _applyGroupFilters(query);

      final data = await query;
      final phones = (data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['phone_e164']?.toString())
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .toList();

      widget.onRecipientsChanged(phones);
    } catch (e) {
      debugPrint('[RecipientSelector] Group phone fetch error: $e');
    }
  }

  Future<void> _fetchEventAttendeePhones() async {
    if (widget.eventId == null || !_supabase.isInitialized) return;

    try {
      // Attendees may have member_id (linked) or guest_phone (unlinked)
      final data = await _client
          .from('event_attendees')
          .select('guest_phone, members:member_id(phone_e164)')
          .eq('event_id', widget.eventId!);

      final phones = <String>{};
      for (final row in (data as List<dynamic>)) {
        final map = row as Map<String, dynamic>;
        // Linked member phone
        final memberData = map['members'];
        if (memberData is Map<String, dynamic>) {
          final phone = memberData['phone_e164']?.toString();
          if (phone != null && phone.isNotEmpty) phones.add(phone);
        }
        // Guest phone
        final guestPhone = map['guest_phone']?.toString();
        if (guestPhone != null && guestPhone.isNotEmpty) {
          phones.add(guestPhone);
        }
      }

      widget.onRecipientsChanged(phones.toList());
    } catch (e) {
      debugPrint('[RecipientSelector] Event attendee phone fetch error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _toggleMember(Map<String, dynamic> member) {
    final phone = member['phone_e164']?.toString() ?? '';
    if (phone.isEmpty) return;

    setState(() {
      if (_selectedMembers.containsKey(phone)) {
        _selectedMembers.remove(phone);
      } else {
        _selectedMembers[phone] = member;
      }
    });
    _emitPhones();
  }

  void _removeMember(String phone) {
    setState(() => _selectedMembers.remove(phone));
    _emitPhones();
  }

  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '***${phone.substring(phone.length - 4)}';
  }

  Widget _buildMemberAvatar(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    final profilePics = member['profile_pictures'];
    final photos = MemberProfilePhoto.parseList(profilePics);
    final url = photos.isNotEmpty ? photos.first.publicUrl : null;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
        backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
      );
    }

    return CircleAvatar(
      backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: BrandColors.unityBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _onGroupFilterChanged() {
    _updateGroupCount();
    _emitPhones();
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildModeToggleHeader(),
        Expanded(child: _buildModeBody()),
        _buildCountPreviewBar(),
      ],
    );
  }

  // ── Mode toggle header ────────────────────────────────────────────────

  Widget _buildModeToggleHeader() {
    final hasEvent = widget.eventId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_alt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Select Recipients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented button
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<RecipientMode>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white.withOpacity(0.15);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return BrandColors.unityBlue;
                  }
                  return Colors.white;
                }),
                side: WidgetStateProperty.all(
                  BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              segments: [
                const ButtonSegment<RecipientMode>(
                  value: RecipientMode.individual,
                  label: Text('Individual', style: TextStyle(fontSize: 13)),
                  icon: Icon(Icons.person, size: 18),
                ),
                const ButtonSegment<RecipientMode>(
                  value: RecipientMode.group,
                  label: Text('Group', style: TextStyle(fontSize: 13)),
                  icon: Icon(Icons.group, size: 18),
                ),
                if (hasEvent)
                  const ButtonSegment<RecipientMode>(
                    value: RecipientMode.eventAttendees,
                    label: Text('Event', style: TextStyle(fontSize: 13)),
                    icon: Icon(Icons.event, size: 18),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
                _emitPhones();
                if (_mode == RecipientMode.group) {
                  _updateGroupCount();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode body ─────────────────────────────────────────────────────────

  Widget _buildModeBody() {
    switch (_mode) {
      case RecipientMode.individual:
        return _buildIndividualMode();
      case RecipientMode.group:
        return _buildGroupMode();
      case RecipientMode.eventAttendees:
        return _buildEventAttendeesMode();
    }
  }

  // ── Individual mode ───────────────────────────────────────────────────

  Widget _buildIndividualMode() {
    return Column(
      children: [
        // Selected chips
        if (_selectedMembers.isNotEmpty) _buildSelectedChips(),
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: BrandColors.unityBlue),
            decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        // Results
        Expanded(
          child: _searchLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Type to search members'
                            : 'No members found',
                        style: TextStyle(
                          color: BrandColors.unityBlue.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final member = _searchResults[index];
                        final phone =
                            member['phone_e164']?.toString() ?? '';
                        final isSelected =
                            _selectedMembers.containsKey(phone);
                        final name =
                            member['name']?.toString() ?? 'Unknown';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? BrandColors.momentumBlue.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? BrandColors.momentumBlue.withOpacity(0.4)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleMember(member),
                            activeColor: BrandColors.momentumBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: BrandColors.unityBlue,
                              ),
                            ),
                            subtitle: Text(
                              _maskPhone(phone),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            secondary: _buildMemberAvatar(member),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSelectedChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _selectedMembers.entries.map((entry) {
          final name = entry.value['name']?.toString() ?? entry.key;
          return Chip(
            label: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: BrandColors.unityBlue,
            deleteIconColor: Colors.white70,
            onDeleted: () => _removeMember(entry.key),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      ),
    );
  }

  // ── Group mode ────────────────────────────────────────────────────────

  Widget _buildGroupMode() {
    if (_filterOptionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // County
          _buildFilterCard(
            icon: Icons.location_on_outlined,
            label: 'County',
            child: _buildDropdown(
              value: _selectedCounty,
              items: _counties,
              hint: 'All Counties',
              onChanged: (v) {
                setState(() => _selectedCounty = v);
                _onGroupFilterChanged();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Congressional District
          _buildFilterCard(
            icon: Icons.how_to_vote_outlined,
            label: 'Congressional District',
            child: _buildDropdown(
              value: _selectedDistrict,
              items: _districts,
              hint: 'All Districts',
              onChanged: (v) {
                setState(() => _selectedDistrict = v);
                _onGroupFilterChanged();
              },
            ),
          ),
          const SizedBox(height: 12),

          // High School
          _buildFilterCard(
            icon: Icons.school_outlined,
            label: 'High School',
            child: _buildDropdown(
              value: _selectedHighSchool,
              items: _highSchools,
              hint: 'All High Schools',
              onChanged: (v) {
                setState(() => _selectedHighSchool = v);
                _onGroupFilterChanged();
              },
            ),
          ),
          const SizedBox(height: 12),

          // College
          _buildFilterCard(
            icon: Icons.account_balance_outlined,
            label: 'College',
            child: _buildDropdown(
              value: _selectedCollege,
              items: _colleges,
              hint: 'All Colleges',
              onChanged: (v) {
                setState(() => _selectedCollege = v);
                _onGroupFilterChanged();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Age Range
          _buildFilterCard(
            icon: Icons.cake_outlined,
            label: 'Age Range',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageMinController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Min',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) {
                      _ageMin = int.tryParse(v);
                      _onGroupFilterChanged();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
                Expanded(
                  child: TextField(
                    controller: _ageMaxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Max',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) {
                      _ageMax = int.tryParse(v);
                      _onGroupFilterChanged();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Chapter Members Only toggle
          _buildFilterCard(
            icon: Icons.badge_outlined,
            label: 'Chapter Members Only',
            child: Switch(
              value: _chapterMembersOnly,
              activeColor: BrandColors.momentumBlue,
              onChanged: (v) {
                setState(() => _chapterMembersOnly = v);
                _onGroupFilterChanged();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Clear filters button
          if (_hasActiveGroupFilters)
            TextButton.icon(
              onPressed: _clearGroupFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear All Filters'),
              style: TextButton.styleFrom(
                foregroundColor: BrandColors.error,
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasActiveGroupFilters =>
      _selectedCounty != null ||
      _selectedHighSchool != null ||
      _selectedCollege != null ||
      _selectedDistrict != null ||
      _ageMin != null ||
      _ageMax != null ||
      _chapterMembersOnly;

  void _clearGroupFilters() {
    setState(() {
      _selectedCounty = null;
      _selectedHighSchool = null;
      _selectedCollege = null;
      _selectedDistrict = null;
      _ageMin = null;
      _ageMax = null;
      _chapterMembersOnly = false;
      _ageMinController.clear();
      _ageMaxController.clear();
      _matchCount = 0;
    });
    _onGroupFilterChanged();
  }

  Widget _buildFilterCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: BrandColors.unityBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.unityBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Event Attendees mode ──────────────────────────────────────────────

  Widget _buildEventAttendeesMode() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BrandColors.momentumBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available,
                size: 48,
                color: BrandColors.momentumBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Use Event Attendees',
              style: TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All attendees registered for this event will receive the survey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.unityBlue.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.tileGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _eventCountLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '$_eventAttendeeCount attendee${_eventAttendeeCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Count preview bar ─────────────────────────────────────────────────

  Widget _buildCountPreviewBar() {
    final int count;
    final String label;

    switch (_mode) {
      case RecipientMode.individual:
        count = _selectedMembers.length;
        label = '$count member${count == 1 ? '' : 's'} selected';
        break;
      case RecipientMode.group:
        count = _matchCount;
        label = _countLoading
            ? 'Counting...'
            : '$count member${count == 1 ? '' : 's'} match';
        break;
      case RecipientMode.eventAttendees:
        count = _eventAttendeeCount;
        label = _eventCountLoading
            ? 'Loading...'
            : '$count attendee${count == 1 ? '' : 's'}';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          if (_countLoading || _eventCountLoading)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                count > 0
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: count > 0 ? BrandColors.success : Colors.white70,
                size: 20,
              ),
            ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
