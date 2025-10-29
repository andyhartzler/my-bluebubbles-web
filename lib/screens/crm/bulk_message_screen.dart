import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Screen for sending bulk individual messages
class BulkMessageScreen extends StatefulWidget {
  const BulkMessageScreen({Key? key}) : super(key: key);

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen> {
  final CRMMessageService _messageService = CRMMessageService();
  final MemberRepository _memberRepo = MemberRepository();
  final TextEditingController _messageController = TextEditingController();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  MessageFilter _filter = MessageFilter();
  List<Member> _previewMembers = [];
  bool _loadingPreview = false;
  bool _sending = false;
  int _currentProgress = 0;
  int _totalMessages = 0;
  bool _crmReady = false;

  final TextEditingController _searchController = TextEditingController();
  final List<Member> _selectedMembers = [];
  List<Member> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];
  List<String> _schools = [];
  List<String> _chapters = [];
  List<String> _chapterStatuses = [];

  @override
  void initState() {
    super.initState();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
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
      _memberRepo.getUniqueSchools(),
      _memberRepo.getUniqueChapterNames(),
      _memberRepo.getChapterStatusCounts(),
    ]);

    if (!mounted) return;

    setState(() {
      _counties = List<String>.from(results[0] as List);
      _districts = List<String>.from(results[1] as List);
      _committees = List<String>.from(results[2] as List);
      _schools = List<String>.from(results[3] as List);
      _chapters = List<String>.from(results[4] as List);
      _chapterStatuses = (results[5] as Map<String, int>).keys.toList()..sort();
    });
  }

  Future<void> _updatePreview() async {
    if (!_crmReady) return;

    setState(() => _loadingPreview = true);

    try {
      final members = await _messageService.getFilteredMembers(_filter);
      final Map<String, Member> combined = LinkedHashMap<String, Member>();

      void addMember(Member member) {
        final key = _memberKey(member);
        if (key == null || !member.canContact) return;
        combined[key] = member;
      }

      for (final member in members) {
        addMember(member);
      }

      for (final member in _selectedMembers) {
        addMember(member);
      }

      final combinedList = combined.values.toList();
      if (!mounted) return;
      setState(() {
        _previewMembers = combinedList.take(5).toList();
        _totalMessages = combinedList.length;
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
        filter: _filter,
        messageText: _messageController.text,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
        explicitMembers: List<Member>.from(_selectedMembers),
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
    if (_totalMessages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members match the filter')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Intro Message'),
        content: Text(
          'Send the Missouri Young Democrats intro message to $_totalMessages members?\n\n'
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
        _filter,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
        explicitMembers: List<Member>.from(_selectedMembers),
      );

      final successCount = results.values.where((v) => v).length;

      if (!mounted) return;
      setState(() => _sending = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Intro Messages Sent'),
          content: Text('Successfully sent intro to $successCount of $_totalMessages members'),
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
                      _buildMessageCard(),
                      const SizedBox(height: 16),
                      _buildRecipientsCard(),
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
            TextField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Enter your message here...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
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
              'Combine filters with manual selections to tailor your outreach.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
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
                  return InputChip(
                    label: Text(member.name),
                    onDeleted: () => _toggleMemberSelection(member),
                    avatar: const Icon(Icons.person, size: 18),
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
        ),
      ),
    );
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
          if (member.phoneE164 != null) member.phoneE164!
          else if (member.phone != null) member.phone!,
          if (member.county != null) member.county!,
          if (member.congressionalDistrict != null) 'District ${member.congressionalDistrict!}',
        ].where((value) => value.trim().isNotEmpty).toList();

        return ListTile(
          leading: Icon(selected ? Icons.check_circle : Icons.person_add_alt_1),
          title: Text(member.name),
          subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
          trailing: IconButton(
            icon: Icon(selected ? Icons.remove_circle_outline : Icons.add_circle_outline),
            onPressed: () => _toggleMemberSelection(member),
          ),
          onTap: () => _toggleMemberSelection(member),
        );
      },
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildCountyDropdown(),
            const SizedBox(height: 12),
            _buildDistrictDropdown(),
            const SizedBox(height: 12),
            _buildSchoolDropdown(),
            const SizedBox(height: 12),
            _buildChapterDropdown(),
            const SizedBox(height: 12),
            _buildChapterStatusDropdown(),
            const SizedBox(height: 12),
            _buildAgeFields(),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Exclude opted-out members'),
              value: _filter.excludeOptedOut,
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(excludeOptedOut: value ?? true);
                });
                _updatePreview();
              },
            ),
            CheckboxListTile(
              title: const Text('Exclude recently contacted (7 days)'),
              value: _filter.excludeRecentlyContacted,
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(excludeRecentlyContacted: value ?? false);
                });
                _updatePreview();
              },
            ),
            const SizedBox(height: 12),
            _buildCommitteesSelector(),
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
          _filter = _filter.copyWith(county: value);
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
          _filter = _filter.copyWith(congressionalDistrict: value);
        });
        _updatePreview();
      },
    );
  }

  Widget _buildSchoolDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Schools')),
      ..._schools.map(
        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.schoolName,
      decoration: const InputDecoration(
        labelText: 'School',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        setState(() {
          _filter = _filter.copyWith(schoolName: value);
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
          _filter = _filter.copyWith(chapterName: value);
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
          _filter = _filter.copyWith(chapterStatus: value);
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
                _filter = _filter.copyWith(minAge: age);
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
                _filter = _filter.copyWith(maxAge: age);
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
                    _filter = _filter.copyWith(
                      committees: tempSelected.isEmpty ? null : tempSelected,
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
              Text(
                _filter.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                  (m) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person, size: 16),
                    title: Text(m.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(m.phone ?? 'No phone', style: const TextStyle(fontSize: 12)),
                  ),
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
                    label: const Text('Send Intro'),
                    onPressed: _totalMessages == 0 ? null : _sendIntroMessages,
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
