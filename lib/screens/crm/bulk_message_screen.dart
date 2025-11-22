import 'dart:async';
import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

enum _RecipientMode {
  manual,
  allMembers,
  county,
  district,
  highSchool,
  college,
  committee,
  chapter,
  chapterStatus,
}

/// Screen for sending bulk individual messages
class BulkMessageScreen extends StatefulWidget {
  const BulkMessageScreen({Key? key, this.initialFilter, this.initialManualMembers}) : super(key: key);

  final MessageFilter? initialFilter;
  final List<Member>? initialManualMembers;

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen> {
  final CRMMessageService _messageService = CRMMessageService.instance;
  final MemberRepository _memberRepo = MemberRepository();
  final TextEditingController _messageController = TextEditingController();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  late MessageFilter _filter;
  final List<PlatformFile> _attachments = [];
  _RecipientMode _mode = _RecipientMode.manual;
  List<Member> _previewMembers = [];
  bool _loadingPreview = false;
  bool _sending = false;
  int _currentProgress = 0;
  int _totalMessages = 0;
  bool _crmReady = false;
  int _alreadyIntroducedPreview = 0;
  Map<String, int> _transportPreview = const {};
  final DateFormat _dateFormat = DateFormat.yMMMd();

  final TextEditingController _searchController = TextEditingController();
  final List<Member> _selectedMembers = [];
  List<Member> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];
  List<String> _highSchools = [];
  List<String> _colleges = [];
  List<String> _chapters = [];
  List<String> _chapterStatuses = [];

  MessageFilter get _activeFilter {
    if (_mode == _RecipientMode.allMembers) {
      return _filter.copyWithOverrides(
        clearCounty: true,
        clearCongressionalDistrict: true,
        clearHighSchool: true,
        clearCollege: true,
        clearChapterName: true,
        clearChapterStatus: true,
        clearCommittees: true,
        clearMinAge: true,
        maxAge: CRMConfig.maxVisibleMemberAge,
      );
    }
    return _filter;
  }

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? MessageFilter();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    final initialMembers = widget.initialManualMembers;
    if (initialMembers != null && initialMembers.isNotEmpty) {
      for (final member in initialMembers) {
        final key = _memberKey(member);
        if (key != null && !_selectedMembers.any((m) => _memberKey(m) == key)) {
          _selectedMembers.add(member);
        }
      }
      _setMode(_RecipientMode.manual, notify: false);
    }
    if (_filter.chapterName != null && _filter.chapterName!.isNotEmpty) {
      _mode = _RecipientMode.chapter;
    }
    _searchController.addListener(_onSearchChanged);
    if (_crmReady) {
      _loadFilterOptions();
      _updatePreview();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    final results = await Future.wait([
      _memberRepo.getUniqueCounties(),
      _memberRepo.getUniqueCongressionalDistricts(),
      _memberRepo.getUniqueCommittees(),
      _memberRepo.getUniqueHighSchools(),
      _memberRepo.getUniqueColleges(),
      _memberRepo.getUniqueChapterNames(),
      _memberRepo.getChapterStatusCounts(),
    ]);

    if (!mounted) return;

    setState(() {
      _counties = List<String>.from(results[0] as List);
      _districts = List<String>.from(results[1] as List);
      _committees = List<String>.from(results[2] as List);
      _highSchools = List<String>.from(results[3] as List);
      _colleges = List<String>.from(results[4] as List);
      _chapters = List<String>.from(results[5] as List);
      _chapterStatuses = (results[6] as Map<String, int>).keys.toList()..sort();
    });
  }

  Future<void> _updatePreview() async {
    if (!_crmReady) return;

    final activeFilter = _activeFilter;
    final hasFilters = activeFilter.hasActiveFilters;

    if (!hasFilters && _selectedMembers.isEmpty) {
      setState(() {
        _previewMembers = [];
        _totalMessages = 0;
        _alreadyIntroducedPreview = 0;
        _loadingPreview = false;
      });
      return;
    }

    setState(() => _loadingPreview = true);

    try {
      final Map<String, Member> combined = LinkedHashMap<String, Member>();

      void addMember(Member member) {
        final key = _memberKey(member);
        if (key == null || !member.canContact) return;
        combined[key] = member;
      }

      if (hasFilters) {
        final members = await _messageService.getFilteredMembers(activeFilter);
        for (final member in members) {
          addMember(member);
        }
      }

      for (final member in _selectedMembers) {
        addMember(member);
      }

      final combinedList = combined.values.toList();
      final alreadyIntroduced = combinedList.where((m) => m.introSentAt != null).length;
      Map<String, int> transports = const {};

      if (combinedList.isNotEmpty) {
        try {
          transports = await _messageService.previewTransportBreakdown(combinedList);
        } catch (_) {
          transports = const {};
        }
      }
      if (!mounted) return;
      setState(() {
        _previewMembers = combinedList.take(5).toList();
        _totalMessages = combinedList.length;
        _alreadyIntroducedPreview = alreadyIntroduced;
        _transportPreview = transports;
        _loadingPreview = false;
      });
    } catch (e) {
      print('❌ Error updating preview: $e');
      if (!mounted) return;
      setState(() => _loadingPreview = false);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();

    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final results = await _memberRepo.searchMembers(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results.where((member) => member.canContact).toList();
        _searching = false;
      });
    });
  }

  void _toggleMemberSelection(Member member) {
    final key = _memberKey(member);
    if (key == null) return;

    setState(() {
      if (_isMemberSelected(member)) {
        _selectedMembers.removeWhere((m) => _memberKey(m) == key);
      } else {
        _selectedMembers.add(member);
      }
    });

    _updatePreview();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.text = '';
    setState(() {
      _searchResults = [];
      _searching = false;
    });
  }

  bool _isMemberSelected(Member member) {
    final key = _memberKey(member);
    if (key == null) return false;
    return _selectedMembers.any((m) => _memberKey(m) == key);
  }

  String? _memberKey(Member member) {
    return member.id ?? member.phoneE164 ?? member.phone;
  }

  void _setMode(_RecipientMode mode, {bool notify = true}) {
    void updateMode() {
      _mode = mode;
      switch (mode) {
        case _RecipientMode.manual:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterName: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.allMembers:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterName: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.county:
          _filter = _filter.copyWithOverrides(
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterName: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.district:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterName: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.highSchool:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearCollege: true,
            clearChapterName: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.college:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearChapterName: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.committee:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterName: true,
            clearChapterStatus: true,
          );
          break;
        case _RecipientMode.chapter:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterStatus: true,
            clearCommittees: true,
          );
          break;
        case _RecipientMode.chapterStatus:
          _filter = _filter.copyWithOverrides(
            clearCounty: true,
            clearCongressionalDistrict: true,
            clearHighSchool: true,
            clearCollege: true,
            clearChapterName: true,
            clearCommittees: true,
          );
          break;
      }
    }

    if (notify) {
      setState(updateMode);
    } else {
      updateMode();
    }
  }

  Future<void> _sendMessages() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    if (_totalMessages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members match the filter')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Message'),
        content: Text(
          'Send message to $_totalMessages members?\n\n'
          'This will send individual messages at a rate of ${CRMMessageService.messagesPerMinute} per minute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _currentProgress = 0;
    });

    try {
      final results = await _messageService.sendBulkMessages(
        filter: _activeFilter,
        messageText: _messageController.text,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
        explicitMembers: List<Member>.from(_selectedMembers),
        attachments: List<PlatformFile>.from(_attachments),
      );

      final successCount = results.values.where((v) => v).length;

      if (!mounted) return;
      setState(() => _sending = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bulk Message Complete'),
          content: Text('Successfully sent $successCount of $_totalMessages messages'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending messages: $e')),
      );
    }
  }

  Future<void> _sendIntroMessages() async {
    final eligibleTotal = _totalMessages - _alreadyIntroducedPreview;
    if (eligibleTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible members to receive the intro message')),
      );
      return;
    }

    final manualEligible =
        _selectedMembers.where((member) => member.introSentAt == null).toList();
    final manualSkipped = _selectedMembers.length - manualEligible.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Intro Message'),
        content: Text(
          'Send the Missouri Young Democrats intro message to $eligibleTotal members?\n\n'
          'This will send individually at a rate of ${CRMMessageService.messagesPerMinute} per minute and include the contact card.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Intro'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _currentProgress = 0;
    });

    try {
      final results = await _messageService.sendIntroToFilteredMembers(
        _activeFilter,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
        explicitMembers: manualEligible,
      );

      final successCount = results.values.where((v) => v).length;

      if (!mounted) return;
      setState(() => _sending = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Intro Messages Sent'),
          content: Text('Successfully sent intro to $successCount of $eligibleTotal members'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (manualSkipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Skipped $manualSkipped members who already received the intro message.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending intro messages: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Message'),
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. Please verify environment variables before sending messages.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildRecipientsCard(),
                      const SizedBox(height: 16),
                      _buildMessageCard(),
                      const SizedBox(height: 16),
                      _buildFiltersCard(),
                      const SizedBox(height: 16),
                      _buildPreviewCard(),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildMessageCard() {
    final hasRecipients =
        _totalMessages > 0 || _selectedMembers.isNotEmpty || _filter.hasActiveFilters;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!hasRecipients)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Select recipients to enable composing. Once at least one member is chosen the message editor will unlock.',
                ),
              ),
            if (!hasRecipients) const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Enter your message here...',
                border: OutlineInputBorder(),
              ),
              enabled: hasRecipients,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._attachments.map(
                  (file) => InputChip(
                    label: Text(file.name),
                    avatar: const Icon(Icons.attachment, size: 18),
                    onDeleted: () => _removeAttachment(file),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: hasRecipients ? _pickAttachments : null,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_attachments.isEmpty ? 'Add attachments' : 'Add more attachments'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipients',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a targeting strategy, then optionally add individual members to the list.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(_RecipientMode.manual, 'Manual', Icons.person_add_alt_1),
                _buildModeChip(_RecipientMode.allMembers, 'All Members', Icons.people_alt_outlined),
                _buildModeChip(_RecipientMode.county, 'County', Icons.map_outlined),
                _buildModeChip(_RecipientMode.district, 'District', Icons.apartment_outlined),
                _buildModeChip(_RecipientMode.highSchool, 'High Schools', Icons.school_outlined),
                _buildModeChip(_RecipientMode.college, 'Colleges', Icons.school),
                _buildModeChip(_RecipientMode.committee, 'Committee', Icons.groups_2_outlined),
                _buildModeChip(_RecipientMode.chapter, 'Chapter', Icons.flag_outlined),
                _buildModeChip(_RecipientMode.chapterStatus, 'Chapter Status', Icons.badge_outlined),
              ],
            ),
            const SizedBox(height: 16),
            _buildModeSelector(),
            if (_mode != _RecipientMode.manual) const SizedBox(height: 20),
            _buildManualSelectionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(_RecipientMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : null),
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _setMode(mode);
        _updatePreview();
      },
    );
  }

  Widget _buildModeSelector() {
    switch (_mode) {
      case _RecipientMode.allMembers:
        return _buildAllMembersInfo();
      case _RecipientMode.county:
        return _buildCountyDropdown();
      case _RecipientMode.district:
        return _buildDistrictDropdown();
      case _RecipientMode.highSchool:
        return _buildHighSchoolDropdown();
      case _RecipientMode.college:
        return _buildCollegeDropdown();
      case _RecipientMode.committee:
        return _buildCommitteesSelector();
      case _RecipientMode.chapter:
        return _buildChapterDropdown();
      case _RecipientMode.chapterStatus:
        return _buildChapterStatusDropdown();
      case _RecipientMode.manual:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAllMembersInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Send to every contactable member currently visible in the directory. '
        'Members older than ${CRMConfig.maxVisibleMemberAge} are excluded automatically.',
      ),
    );
  }

  Widget _buildManualSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add individual members',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search members by name or phone',
            border: const OutlineInputBorder(),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      )
                    : const Icon(Icons.search)),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedMembers.isNotEmpty) ...[
          Text(
            'Selected members (${_selectedMembers.length})',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedMembers.map((member) {
              final introduced = member.introSentAt != null;
              return InputChip(
                label: Text(member.name),
                avatar: Icon(
                  introduced ? Icons.check_circle_outline : Icons.person,
                  size: 18,
                ),
                backgroundColor: introduced
                    ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4)
                    : null,
                labelStyle: introduced
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                    : null,
                tooltip: introduced ? 'Intro sent ${_formatDate(member.introSentAt!)}' : null,
                onDeleted: () => _toggleMemberSelection(member),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (_searchController.text.trim().length >= 2)
          _buildSearchResults()
        else
          const Text('Type at least 2 characters to search the member directory.'),
      ],
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null) return;

    setState(() {
      for (final file in result.files) {
        final alreadyExists = _attachments.any((existing) {
          if (existing.identifier != null && file.identifier != null) {
            return existing.identifier == file.identifier;
          }
          if (existing.path != null && file.path != null) {
            return existing.path == file.path;
          }
          return existing.name == file.name && existing.bytes == file.bytes;
        });

        if (!alreadyExists) {
          _attachments.add(file);
        }
      }
    });
  }

  void _removeAttachment(PlatformFile file) {
    setState(() {
      _attachments.remove(file);
    });
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No matching members found.'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final member = _searchResults[index];
        final selected = _isMemberSelected(member);
        final subtitleParts = <String>[
          if (member.phoneE164 != null)
            member.phoneE164!
          else if (member.phone != null)
            member.phone!,
          if (member.county != null) member.county!,
          if (member.congressionalDistrict != null)
            Member.formatDistrictLabel(member.congressionalDistrict) ?? member.congressionalDistrict!,
        ].where((value) => value.trim().isNotEmpty).toList();

        final infoLines = <String>[];
        if (subtitleParts.isNotEmpty) {
          infoLines.add(subtitleParts.join(' • '));
        }
        if (member.introSentAt != null) {
          infoLines.add('Intro sent ${_formatDate(member.introSentAt!)}');
        }
        final subtitleText = infoLines.isEmpty ? null : infoLines.join(' — ');

        return ListTile(
          leading: Icon(selected ? Icons.check_circle : Icons.person_add_alt_1),
          title: Text(member.name),
          subtitle: subtitleText == null ? null : Text(subtitleText),
          trailing: IconButton(
            icon: Icon(selected ? Icons.remove_circle_outline : Icons.add_circle_outline),
            onPressed: () => _toggleMemberSelection(member),
          ),
          onTap: () => _toggleMemberSelection(member),
        );
      },
    );
  }

  String _formatDate(DateTime date) => _dateFormat.format(date);

  Widget _buildFiltersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildAgeFields(),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Exclude opted-out members'),
              value: _filter.excludeOptedOut,
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWithOverrides(
                    excludeOptedOut: value ?? true,
                  );
                });
                _updatePreview();
              },
            ),
            CheckboxListTile(
              title: const Text('Exclude recently contacted (7 days)'),
              value: _filter.excludeRecentlyContacted,
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWithOverrides(
                    excludeRecentlyContacted: value ?? false,
                  );
                });
                _updatePreview();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountyDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Counties')),
      ..._counties.map(
        (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.county,
      decoration: const InputDecoration(
        labelText: 'County',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _setMode(value == null ? _RecipientMode.manual : _RecipientMode.county, notify: false);
          _filter = _filter.copyWithOverrides(
            county: value,
            clearCounty: value == null,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildDistrictDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Districts')),
      ..._districts.map(
        (d) => DropdownMenuItem<String?>(value: d, child: Text('District $d')),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.congressionalDistrict,
      decoration: const InputDecoration(
        labelText: 'Congressional District',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _setMode(value == null ? _RecipientMode.manual : _RecipientMode.district, notify: false);
          _filter = _filter.copyWithOverrides(
            congressionalDistrict: value,
            clearCongressionalDistrict: value == null,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildHighSchoolDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All High Schools')),
      ..._highSchools.map(
        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.highSchool,
      decoration: const InputDecoration(
        labelText: 'High School',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _setMode(value == null ? _RecipientMode.manual : _RecipientMode.highSchool, notify: false);
          _filter = _filter.copyWithOverrides(
            highSchool: value,
            clearHighSchool: value == null,
            clearCollege: true,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildCollegeDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Colleges')),
      ..._colleges.map(
        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.college,
      decoration: const InputDecoration(
        labelText: 'College',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _setMode(value == null ? _RecipientMode.manual : _RecipientMode.college, notify: false);
          _filter = _filter.copyWithOverrides(
            college: value,
            clearCollege: value == null,
            clearHighSchool: true,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildChapterDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Chapters')),
      ..._chapters.map(
        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.chapterName,
      decoration: const InputDecoration(
        labelText: 'Chapter',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _setMode(value == null ? _RecipientMode.manual : _RecipientMode.chapter, notify: false);
          _filter = _filter.copyWithOverrides(
            chapterName: value,
            clearChapterName: value == null,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildChapterStatusDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Chapter Statuses')),
      ..._chapterStatuses.map(
        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.chapterStatus,
      decoration: const InputDecoration(
        labelText: 'Chapter Membership Status',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _setMode(value == null ? _RecipientMode.manual : _RecipientMode.chapterStatus, notify: false);
          _filter = _filter.copyWithOverrides(
            chapterStatus: value,
            clearChapterStatus: value == null,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildAgeFields() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Min Age',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final age = int.tryParse(value);
              setState(() {
                _filter = _filter.copyWithOverrides(
                  minAge: age,
                  clearMinAge: value.isEmpty,
                );
              });
              _updatePreview();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Max Age',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final age = int.tryParse(value);
              setState(() {
                _filter = _filter.copyWithOverrides(
                  maxAge: age,
                  clearMaxAge: value.isEmpty,
                );
              });
              _updatePreview();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommitteesSelector() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.group),
      label: Text(
        _filter.committees == null || _filter.committees!.isEmpty
            ? 'Select committees'
            : '${_filter.committees!.length} committees selected',
      ),
      onPressed: () {
        final tempSelected = List<String>.from(_filter.committees ?? []);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Committees'),
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
                    _setMode(
                      tempSelected.isEmpty ? _RecipientMode.manual : _RecipientMode.committee,
                      notify: false,
                    );
                    _filter = _filter.copyWithOverrides(
                      committees: tempSelected.isEmpty ? null : tempSelected,
                      clearCommittees: tempSelected.isEmpty,
                    );
                  });
                  _updatePreview();
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard() {
    final smsCount = _transportPreview['SMS'] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_loadingPreview)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                'Will send to $_totalMessages members',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_transportPreview.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _transportPreview.entries
                      .map(
                        (entry) => Chip(
                          avatar: Icon(
                            entry.key == 'iMessage' ? Icons.message_outlined : Icons.sms_outlined,
                            size: 16,
                          ),
                          label: Text('${entry.value} ${entry.key == 'SMS' ? 'SMS' : 'iMessage'}'),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (_attachments.isNotEmpty) ...[
                Text(
                  'Attachments: ${_attachments.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (smsCount > 0)
                  Text(
                    '$smsCount SMS recipient(s) may receive attachments as MMS when available.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                  ),
                if (smsCount > 0) const SizedBox(height: 8),
              ],
              Text(
                _filter.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_alreadyIntroducedPreview > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$_alreadyIntroducedPreview recipient(s) already received the intro message and will be skipped for "Send Intro".',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ],
              if (_selectedMembers.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Manually selected: ${_selectedMembers.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_previewMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('First 5 recipients:'),
                ..._previewMembers.map(
                  (m) {
                    final details = <String>[
                      if (m.phoneE164 != null)
                        m.phoneE164!
                      else if (m.phone != null)
                        m.phone!,
                      if (m.county != null) m.county!,
                      if (m.congressionalDistrict != null)
                        Member.formatDistrictLabel(m.congressionalDistrict) ?? m.congressionalDistrict!,
                    ].where((value) => value.trim().isNotEmpty).toList();

                    final info = <String>[];
                    if (details.isNotEmpty) {
                      info.add(details.join(' • '));
                    }
                    if (m.introSentAt != null) {
                      info.add('Intro sent ${_formatDate(m.introSentAt!)}');
                    }

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 16),
                      title: Text(m.name, style: const TextStyle(fontSize: 14)),
                      subtitle: info.isEmpty ? null : Text(info.join(' — '), style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (!_crmReady) {
      return const SizedBox.shrink();
    }

    final introEligible = (_totalMessages - _alreadyIntroducedPreview).clamp(0, _totalMessages);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _sending
          ? Column(
              children: [
                LinearProgressIndicator(
                  value: _totalMessages > 0 ? _currentProgress / _totalMessages : 0,
                ),
                const SizedBox(height: 8),
                Text('Sending $_currentProgress of $_totalMessages...'),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(introEligible > 0 ? 'Send Intro ($introEligible)' : 'Send Intro'),
                    onPressed: introEligible == 0 ? null : _sendIntroMessages,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: Text('Send to $_totalMessages Members'),
                    onPressed: _messageController.text.trim().isEmpty || _totalMessages == 0
                        ? null
                        : _sendMessages,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
