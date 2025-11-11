import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

enum _RecipientMode {
  manual,
  county,
  district,
  highSchool,
  college,
  committee,
  chapter,
  chapterStatus,
}

class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({
    Key? key,
    this.initialFilter,
    this.initialManualMembers,
    this.initialManualEmails,
  }) : super(key: key);

  final MessageFilter? initialFilter;
  final List<Member>? initialManualMembers;
  final List<String>? initialManualEmails;

  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMEmailService _emailService = CRMEmailService.instance;
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _fromNameController = TextEditingController();
  final TextEditingController _replyToController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualEmailController = TextEditingController();
  final TextEditingController _ccSearchController = TextEditingController();
  final TextEditingController _ccManualEmailController = TextEditingController();
  final TextEditingController _bccSearchController = TextEditingController();
  final TextEditingController _bccManualEmailController = TextEditingController();
  final FocusNode _bodyFocusNode = FocusNode();

  final List<Member> _selectedMembers = [];
  final List<Member> _searchResults = [];
  final List<Member> _ccMembers = [];
  final List<Member> _bccMembers = [];
  final List<Member> _ccSearchResults = [];
  final List<Member> _bccSearchResults = [];
  final List<PlatformFile> _attachments = [];
  final List<String> _manualEmails = [];
  final List<String> _ccManualEmails = [];
  final List<String> _bccManualEmails = [];

  MessageFilter _filter = MessageFilter();
  _RecipientMode _mode = _RecipientMode.manual;
  bool _crmReady = false;
  bool _loadingPreview = false;
  bool _sending = false;
  bool _searching = false;
  bool _searchingCc = false;
  bool _searchingBcc = false;
  bool _mailMergeEnabled = false;
  String? _errorMessage;

  List<Member> _previewMembers = [];
  List<String> _previewManualEmails = [];
  int _totalRecipients = 0;
  int _missingEmailCount = 0;

  Timer? _searchDebounce;
  Timer? _ccSearchDebounce;
  Timer? _bccSearchDebounce;

  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];
  List<String> _highSchools = [];
  List<String> _colleges = [];
  List<String> _chapters = [];
  List<String> _chapterStatuses = [];

  static const List<_MergeFieldDefinition> _mergeFieldDefinitions = [
    _MergeFieldDefinition(
      token: '{{first_name}}',
      label: 'First name',
      description:
          'Personalizes the greeting using the member\'s preferred first name when available.',
    ),
    _MergeFieldDefinition(
      token: '{{full_name}}',
      label: 'Full name',
      description: 'Displays the member\'s full recorded name.',
    ),
    _MergeFieldDefinition(
      token: '{{email}}',
      label: 'Email',
      description: 'Inserts the primary email address on record.',
    ),
    _MergeFieldDefinition(
      token: '{{chapter_name}}',
      label: 'Chapter',
      description: 'Shows the chapter associated with the member, if any.',
    ),
    _MergeFieldDefinition(
      token: '{{opt_out_url}}',
      label: 'Opt-out link',
      description: 'Adds the unique unsubscribe link required in merge mailings.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? MessageFilter();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    if (_filter.chapterName != null && _filter.chapterName!.isNotEmpty) {
      _mode = _RecipientMode.chapter;
    }
    if (widget.initialManualMembers != null && widget.initialManualMembers!.isNotEmpty) {
      _selectedMembers.addAll(widget.initialManualMembers!);
    }
    if (widget.initialManualEmails != null && widget.initialManualEmails!.isNotEmpty) {
      for (final email in widget.initialManualEmails!) {
        final trimmed = email.trim();
        if (trimmed.isNotEmpty) {
          _manualEmails.add(trimmed);
        }
      }
    }
    _searchController.addListener(_onSearchChanged);
    _ccSearchController.addListener(_onCcSearchChanged);
    _bccSearchController.addListener(_onBccSearchChanged);
    if (_crmReady) {
      _loadFilterOptions();
      _updatePreview();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _fromNameController.dispose();
    _replyToController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _ccSearchController.removeListener(_onCcSearchChanged);
    _bccSearchController.removeListener(_onBccSearchChanged);
    _searchController.dispose();
    _ccSearchController.dispose();
    _bccSearchController.dispose();
    _manualEmailController.dispose();
    _ccManualEmailController.dispose();
    _bccManualEmailController.dispose();
    _searchDebounce?.cancel();
    _ccSearchDebounce?.cancel();
    _bccSearchDebounce?.cancel();
    super.dispose();
  }

  bool get _hasRecipients => _totalRecipients > 0;

  bool get _canSendEmail =>
      _crmReady &&
      !_sending &&
      _hasRecipients &&
      _subjectController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty;

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

    final hasFilters = _filter.hasActiveFilters;
    final hasManualRecipients = _selectedMembers.isNotEmpty || _manualEmails.isNotEmpty;

    if (!hasFilters && !hasManualRecipients) {
      setState(() {
        _previewMembers = [];
        _previewManualEmails = [];
        _totalRecipients = 0;
        _missingEmailCount = 0;
        _loadingPreview = false;
      });
      return;
    }

    setState(() {
      _loadingPreview = true;
      _errorMessage = null;
    });

    try {
      final LinkedHashMap<String, Member> combined = LinkedHashMap();
      int missingEmails = 0;

      void addMember(Member member) {
        final email = _normalizeEmail(member.preferredEmail);
        if (email == null) {
          missingEmails++;
          return;
        }
        if (_filter.excludeOptedOut && member.optOut) {
          return;
        }
        combined[member.id] = member;
      }

      if (hasFilters) {
        final response = await _memberRepo.getAllMembers(
          county: _filter.county,
          congressionalDistrict: _filter.congressionalDistrict,
          committees: _filter.committees,
          highSchool: _filter.highSchool,
          college: _filter.college,
          chapterName: _filter.chapterName,
          chapterStatus: _filter.chapterStatus,
          optedOut: _filter.excludeOptedOut ? false : null,
        );

        var members = response.members;
        if (_filter.excludeRecentlyContacted) {
          final threshold = DateTime.now().subtract(
            _filter.recentContactThreshold ?? const Duration(days: 7),
          );
          members = members
              .where((member) => member.lastContacted == null || member.lastContacted!.isBefore(threshold))
              .toList();
        }

        for (final member in members) {
          addMember(member);
        }
      }

      for (final member in _selectedMembers) {
        addMember(member);
      }

      final memberEmailSet = combined.values
          .map((member) => _normalizeEmail(member.preferredEmail)?.toLowerCase())
          .whereType<String>()
          .toSet();
      final manualEmails = <String>[];
      for (final email in _manualEmails) {
        final normalized = _normalizeEmail(email);
        if (normalized == null) continue;
        final lower = normalized.toLowerCase();
        if (memberEmailSet.contains(lower)) continue;
        if (manualEmails.any((existing) => existing.toLowerCase() == lower)) continue;
        manualEmails.add(normalized);
      }

      if (!mounted) return;

      setState(() {
        final membersList = combined.values.toList(growable: false);
        final topMembers = membersList.take(5).toList(growable: false);
        final remaining = 5 - topMembers.length;
        final manualPreviewCount = remaining > 0
            ? (remaining > manualEmails.length ? manualEmails.length : remaining)
            : 0;
        final manualPreview = manualPreviewCount > 0
            ? manualEmails.sublist(0, manualPreviewCount)
            : const <String>[];
        _previewMembers = topMembers;
        _previewManualEmails = manualPreview;
        _totalRecipients = combined.length + manualEmails.length;
        _missingEmailCount = missingEmails;
        _loadingPreview = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPreview = false;
        _errorMessage = 'Failed to build preview: $error';
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final results = await _memberRepo.searchMembers(query);
        if (!mounted) return;
        setState(() {
          _searchResults
            ..clear()
            ..addAll(results.where((member) => _normalizeEmail(member.preferredEmail) != null));
          _searching = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _searchResults.clear();
          _searching = false;
        });
      }
    });
  }

  void _onCcSearchChanged() {
    _ccSearchDebounce?.cancel();
    final query = _ccSearchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _ccSearchResults.clear();
        _searchingCc = false;
      });
      return;
    }

    _ccSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searchingCc = true);
      try {
        final results = await _memberRepo.searchMembers(query);
        if (!mounted) return;
        setState(() {
          _ccSearchResults
            ..clear()
            ..addAll(results
                .where((member) => _normalizeEmail(member.preferredEmail) != null)
                .where((member) => !_selectedMembers.any((m) => m.id == member.id)));
          _searchingCc = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _ccSearchResults.clear();
          _searchingCc = false;
        });
      }
    });
  }

  void _onBccSearchChanged() {
    _bccSearchDebounce?.cancel();
    final query = _bccSearchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _bccSearchResults.clear();
        _searchingBcc = false;
      });
      return;
    }

    _bccSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searchingBcc = true);
      try {
        final results = await _memberRepo.searchMembers(query);
        if (!mounted) return;
        setState(() {
          _bccSearchResults
            ..clear()
            ..addAll(results
                .where((member) => _normalizeEmail(member.preferredEmail) != null)
                .where((member) => !_selectedMembers.any((m) => m.id == member.id)));
          _searchingBcc = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _bccSearchResults.clear();
          _searchingBcc = false;
        });
      }
    });
  }

  String? _normalizeEmail(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('@')) return null;
    return trimmed;
  }

  bool _emailAlreadyTargeted(String lowerCaseEmail) {
    bool matchesMemberEmail(Member member) {
      final email = member.preferredEmail;
      if (email == null) return false;
      return email.trim().toLowerCase() == lowerCaseEmail;
    }

    if (_manualEmails.any((value) => value.toLowerCase() == lowerCaseEmail)) {
      return true;
    }
    if (_ccManualEmails.any((value) => value.toLowerCase() == lowerCaseEmail)) {
      return true;
    }
    if (_bccManualEmails.any((value) => value.toLowerCase() == lowerCaseEmail)) {
      return true;
    }
    if (_selectedMembers.any(matchesMemberEmail)) {
      return true;
    }
    if (_ccMembers.any(matchesMemberEmail)) {
      return true;
    }
    if (_bccMembers.any(matchesMemberEmail)) {
      return true;
    }
    return false;
  }

  void _toggleMemberSelection(Member member) {
    final existingIndex = _selectedMembers.indexWhere((m) => m.id == member.id);
    if (existingIndex >= 0) {
      setState(() {
        _selectedMembers.removeAt(existingIndex);
      });
    } else {
      if (_normalizeEmail(member.preferredEmail) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} does not have an email address.')),
        );
        return;
      }
      setState(() {
        _selectedMembers.add(member);
      });
    }
    _updatePreview();
  }

  void _removeSelectedMember(Member member) {
    setState(() {
      _selectedMembers.removeWhere((m) => m.id == member.id);
    });
    _updatePreview();
  }

  void _toggleCcMember(Member member) {
    final existingIndex = _ccMembers.indexWhere((m) => m.id == member.id);
    if (existingIndex >= 0) {
      setState(() {
        _ccMembers.removeAt(existingIndex);
      });
      return;
    }

    final email = _normalizeEmail(member.preferredEmail);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} does not have an email address.')),
      );
      return;
    }

    final lower = email.toLowerCase();
    if (_emailAlreadyTargeted(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That email address is already selected.')),
      );
      return;
    }

    setState(() {
      _ccMembers.add(member);
    });
  }

  void _removeCcMember(Member member) {
    setState(() {
      _ccMembers.removeWhere((m) => m.id == member.id);
    });
  }

  void _toggleBccMember(Member member) {
    final existingIndex = _bccMembers.indexWhere((m) => m.id == member.id);
    if (existingIndex >= 0) {
      setState(() {
        _bccMembers.removeAt(existingIndex);
      });
      return;
    }

    final email = _normalizeEmail(member.preferredEmail);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} does not have an email address.')),
      );
      return;
    }

    final lower = email.toLowerCase();
    if (_emailAlreadyTargeted(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That email address is already selected.')),
      );
      return;
    }

    setState(() {
      _bccMembers.add(member);
    });
  }

  void _removeBccMember(Member member) {
    setState(() {
      _bccMembers.removeWhere((m) => m.id == member.id);
    });
  }

  Future<void> _pickAttachments() async {
    if (!_crmReady || _sending) return;

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final additions = <PlatformFile>[];
    final failedFiles = <String>[];

    for (final file in result.files) {
      final platformFile = await materializePickedPlatformFile(file, source: result);
      if (platformFile == null) {
        failedFiles.add(file.name);
        continue;
      }
      additions.add(platformFile);
    }

    if (!mounted) return;

    setState(() {
      for (final file in additions) {
        final exists = _attachments.any((existing) => existing.name.toLowerCase() == file.name.toLowerCase());
        if (!exists) {
          _attachments.add(file);
        }
      }
    });

    if (failedFiles.isNotEmpty && mounted) {
      final message = failedFiles.length == 1
          ? 'Could not read "${failedFiles.first}". Please try again.'
          : 'Could not read ${failedFiles.length} files: ${failedFiles.join(', ')}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _removeAttachment(PlatformFile file) {
    if (_sending) return;
    setState(() {
      _attachments.remove(file);
    });
  }

  void _addManualEmail() {
    if (_sending) return;
    final email = _normalizeEmail(_manualEmailController.text);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address before adding.')),
      );
      return;
    }

    final lower = email.toLowerCase();
    if (_emailAlreadyTargeted(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That email is already in the recipient list.')),
      );
      return;
    }

    setState(() {
      _manualEmails.add(email);
      _manualEmailController.clear();
    });
    _updatePreview();
  }

  void _removeManualEmail(String email) {
    setState(() {
      _manualEmails.remove(email);
    });
    _updatePreview();
  }

  void _addManualCcEmail() {
    if (_sending) return;
    final email = _normalizeEmail(_ccManualEmailController.text);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address before adding.')),
      );
      return;
    }

    final lower = email.toLowerCase();
    if (_emailAlreadyTargeted(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That email is already in the recipient list.')),
      );
      return;
    }

    setState(() {
      _ccManualEmails.add(email);
      _ccManualEmailController.clear();
    });
  }

  void _removeManualCcEmail(String email) {
    setState(() {
      _ccManualEmails.remove(email);
    });
  }

  void _addManualBccEmail() {
    if (_sending) return;
    final email = _normalizeEmail(_bccManualEmailController.text);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address before adding.')),
      );
      return;
    }

    final lower = email.toLowerCase();
    if (_emailAlreadyTargeted(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That email is already in the recipient list.')),
      );
      return;
    }

    setState(() {
      _bccManualEmails.add(email);
      _bccManualEmailController.clear();
    });
  }

  void _removeManualBccEmail(String email) {
    setState(() {
      _bccManualEmails.remove(email);
    });
  }

  Future<void> _sendEmail() async {
    if (!_canSendEmail) return;

    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    final fromName = _fromNameController.text.trim();
    final replyTo = _replyToController.text.trim();
    final bool mailMergeEnabled = _mailMergeEnabled;
    final Map<String, dynamic>? mergeVariables = mailMergeEnabled
        ? {
            'optOutSnippet': CRMConfig.defaultEmailOptOutSnippet,
            'placeholders':
                _mergeFieldDefinitions.map((definition) => definition.token).toList(),
          }
        : null;

    setState(() {
      _sending = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final recipients = await _resolveRecipients();
      if (recipients.emails.isEmpty) {
        throw CRMEmailException('No valid email addresses were found.');
      }

      final attachments = <CRMEmailAttachment>[];
      for (final file in _attachments) {
        final attachment = await _emailService.buildAttachmentFromPlatformFile(file);
        if (attachment != null) {
          attachments.add(attachment);
        }
      }

      await _emailService.sendEmail(
        to: recipients.emails,
        subject: subject,
        textBody: body,
        fromEmail: CRMConfig.defaultSenderEmail,
        fromName: fromName.isEmpty ? null : fromName,
        replyTo: replyTo.isEmpty ? null : replyTo,
        cc: recipients.ccEmails.isEmpty ? null : recipients.ccEmails,
        bcc: recipients.bccEmails.isEmpty ? null : recipients.bccEmails,
        mailMerge: mailMergeEnabled,
        variables: mergeVariables,
        attachments: attachments,
      );

      final Map<String, Member> contactedMembers = {
        for (final member in recipients.members) member.id: member,
        for (final member in recipients.ccMembers) member.id: member,
        for (final member in recipients.bccMembers) member.id: member,
      };

      for (final member in contactedMembers.values) {
        await _memberRepo.updateLastContacted(member.id);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      setState(() {
        _sending = false;
      });

      final totalCount =
          recipients.emails.length + recipients.ccEmails.length + recipients.bccEmails.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email sent to $totalCount recipient${totalCount == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _sending = false;
      });

      final message = error is CRMEmailException ? error.message : 'Failed to send email: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<({
    List<Member> members,
    List<String> emails,
    List<Member> ccMembers,
    List<String> ccEmails,
    List<Member> bccMembers,
    List<String> bccEmails,
  })> _resolveRecipients() async {
    final LinkedHashMap<String, Member> members = LinkedHashMap();
    final LinkedHashMap<String, String> emailMap = LinkedHashMap();
    final LinkedHashMap<String, Member> ccMemberMap = LinkedHashMap();
    final LinkedHashMap<String, String> ccEmailMap = LinkedHashMap();
    final LinkedHashMap<String, Member> bccMemberMap = LinkedHashMap();
    final LinkedHashMap<String, String> bccEmailMap = LinkedHashMap();

    void addEmail(LinkedHashMap<String, String> map, String email) {
      final lower = email.toLowerCase();
      map[lower] = email;
    }

    void addPrimaryEmail(String email) {
      addEmail(emailMap, email);
    }

    void addCcEmail(String email) {
      final lower = email.toLowerCase();
      if (emailMap.containsKey(lower) || ccEmailMap.containsKey(lower)) {
        return;
      }
      addEmail(ccEmailMap, email);
    }

    void addBccEmail(String email) {
      final lower = email.toLowerCase();
      if (emailMap.containsKey(lower) || ccEmailMap.containsKey(lower) || bccEmailMap.containsKey(lower)) {
        return;
      }
      addEmail(bccEmailMap, email);
    }

    for (final manual in _manualEmails) {
      final normalized = _normalizeEmail(manual);
      if (normalized != null) {
        addPrimaryEmail(normalized);
      }
    }

    for (final manual in _ccManualEmails) {
      final normalized = _normalizeEmail(manual);
      if (normalized != null) {
        addCcEmail(normalized);
      }
    }

    for (final manual in _bccManualEmails) {
      final normalized = _normalizeEmail(manual);
      if (normalized != null) {
        addBccEmail(normalized);
      }
    }

    void addMember(Member member) {
      final email = _normalizeEmail(member.preferredEmail);
      if (email == null) {
        return;
      }
      if (_filter.excludeOptedOut && member.optOut) {
        return;
      }
      members[member.id] = member;
      addPrimaryEmail(email);
    }

    void addCcMember(Member member) {
      final email = _normalizeEmail(member.preferredEmail);
      if (email == null) {
        return;
      }
      final lower = email.toLowerCase();
      if (emailMap.containsKey(lower) || ccEmailMap.containsKey(lower)) {
        return;
      }
      ccMemberMap[member.id] = member;
      addCcEmail(email);
    }

    void addBccMember(Member member) {
      final email = _normalizeEmail(member.preferredEmail);
      if (email == null) {
        return;
      }
      final lower = email.toLowerCase();
      if (emailMap.containsKey(lower) || ccEmailMap.containsKey(lower) || bccEmailMap.containsKey(lower)) {
        return;
      }
      bccMemberMap[member.id] = member;
      addBccEmail(email);
    }

    if (_filter.hasActiveFilters) {
      final response = await _memberRepo.getAllMembers(
        county: _filter.county,
        congressionalDistrict: _filter.congressionalDistrict,
        committees: _filter.committees,
        highSchool: _filter.highSchool,
        college: _filter.college,
        chapterName: _filter.chapterName,
        chapterStatus: _filter.chapterStatus,
        optedOut: _filter.excludeOptedOut ? false : null,
      );

      var membersList = response.members;
      if (_filter.excludeRecentlyContacted) {
        final threshold = DateTime.now().subtract(
          _filter.recentContactThreshold ?? const Duration(days: 7),
        );
        membersList = membersList
            .where((member) => member.lastContacted == null || member.lastContacted!.isBefore(threshold))
            .toList();
      }

      for (final member in membersList) {
        addMember(member);
      }
    }

    for (final member in _selectedMembers) {
      addMember(member);
    }

    for (final member in _ccMembers) {
      addCcMember(member);
    }

    for (final member in _bccMembers) {
      addBccMember(member);
    }

    return (
      members: members.values.toList(growable: false),
      emails: emailMap.values.toList(growable: false),
      ccMembers: ccMemberMap.values.toList(growable: false),
      ccEmails: ccEmailMap.values.toList(growable: false),
      bccMembers: bccMemberMap.values.toList(growable: false),
      bccEmails: bccEmailMap.values.toList(growable: false),
    );
  }

  void _setMode(_RecipientMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _updatePreview();
  }

  void _updateFilter(void Function() updater) {
    setState(updater);
    _updatePreview();
  }

  void _toggleMailMerge(bool enabled) {
    if (_mailMergeEnabled == enabled) return;
    setState(() {
      _mailMergeEnabled = enabled;
    });
  }

  void _insertMergeField(String token) {
    if (_sending || !_mailMergeEnabled) return;

    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, token);

    setState(() {
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + token.length),
      );
    });

    if (!_bodyFocusNode.hasFocus) {
      _bodyFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Email'),
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. Email sending is disabled.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final content = [
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildComposeCard(),
                        const SizedBox(height: 16),
                        _buildCarbonCopyCard(),
                        const SizedBox(height: 16),
                        _buildPreviewCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16, height: 16),
                  Expanded(
                    flex: isWide ? 4 : 0,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildRecipientsCard(),
                      ],
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(children: content);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildComposeCard(),
                          const SizedBox(height: 16),
                          _buildCarbonCopyCard(),
                          const SizedBox(height: 16),
                          _buildPreviewCard(),
                          const SizedBox(height: 16),
                          _buildRecipientsCard(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _crmReady
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Sending…' : 'Send Email'),
                      onPressed: _canSendEmail ? _sendEmail : null,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildComposeCard() {
    final bool canEdit = _hasRecipients && !_sending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compose Email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!_hasRecipients)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Select recipients to enable the compose form. Subject and message body are required.',
                ),
              ),
            if (!_hasRecipients) const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'From: ${CRMConfig.defaultSenderEmail} (default sender)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fromNameController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'From Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _replyToController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Reply-To Email (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _mailMergeEnabled,
              onChanged: canEdit ? _toggleMailMerge : null,
              title: const Text('Mail merge'),
              subtitle: const Text(
                'Personalize each email with member data and automatically include the opt-out link.',
              ),
            ),
            if (_mailMergeEnabled) ...[
              const SizedBox(height: 4),
              Text(
                'Available merge fields',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mergeFieldDefinitions
                    .map(
                      (field) => Tooltip(
                        message: field.description,
                        child: ActionChip(
                          avatar: const Icon(Icons.short_text, size: 18),
                          label: Text(field.label),
                          onPressed: canEdit ? () => _insertMergeField(field.token) : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _bodyController,
              focusNode: _bodyFocusNode,
              enabled: canEdit,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: _mailMergeEnabled
                    ? 'Type your message and insert merge fields such as {{first_name}}.'
                    : 'Type your message…',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_mailMergeEnabled) ...[
              const SizedBox(height: 12),
              Text(
                'Opt-out snippet preview (added automatically)',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  CRMConfig.defaultEmailOptOutSnippet,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._attachments.map(
                  (file) => InputChip(
                    label: Text(file.name),
                    avatar: const Icon(Icons.attachment, size: 18),
                    onDeleted: _sending ? null : () => _removeAttachment(file),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: canEdit ? _pickAttachments : null,
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

  Widget _buildCarbonCopyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CC / BCC',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Optionally copy additional members or contacts on this email.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            _buildCopySection(
              label: 'CC',
              members: _ccMembers,
              manualEmails: _ccManualEmails,
              searchController: _ccSearchController,
              searching: _searchingCc,
              searchResults: _ccSearchResults,
              onToggleMember: _toggleCcMember,
              onRemoveMember: _removeCcMember,
              manualController: _ccManualEmailController,
              onAddManual: _addManualCcEmail,
              onRemoveManual: _removeManualCcEmail,
            ),
            const SizedBox(height: 24),
            _buildCopySection(
              label: 'BCC',
              members: _bccMembers,
              manualEmails: _bccManualEmails,
              searchController: _bccSearchController,
              searching: _searchingBcc,
              searchResults: _bccSearchResults,
              onToggleMember: _toggleBccMember,
              onRemoveMember: _removeBccMember,
              manualController: _bccManualEmailController,
              onAddManual: _addManualBccEmail,
              onRemoveManual: _removeManualBccEmail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopySection({
    required String label,
    required List<Member> members,
    required List<String> manualEmails,
    required TextEditingController searchController,
    required bool searching,
    required List<Member> searchResults,
    required ValueChanged<Member> onToggleMember,
    required ValueChanged<Member> onRemoveMember,
    required TextEditingController manualController,
    required VoidCallback onAddManual,
    required ValueChanged<String> onRemoveManual,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label Recipients',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (members.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: members
                .map(
                  (member) => InputChip(
                    label: Text(member.name),
                    avatar: const Icon(Icons.person, size: 18),
                    onDeleted: _sending ? null : () => onRemoveMember(member),
                  ),
                )
                .toList(),
          ),
        if (members.isNotEmpty && manualEmails.isNotEmpty) const SizedBox(height: 8),
        if (manualEmails.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: manualEmails
                .map(
                  (email) => InputChip(
                    label: Text(email),
                    avatar: const Icon(Icons.alternate_email, size: 18),
                    onDeleted: _sending ? null : () => onRemoveManual(email),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          enabled: !_sending,
          decoration: InputDecoration(
            labelText: 'Search members to add to $label',
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
        ),
        if (searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final member = searchResults[index];
                final selected = members.any((m) => m.id == member.id);
                final email = _normalizeEmail(member.preferredEmail);
                return ListTile(
                  title: Text(member.name),
                  subtitle: Text(email ?? 'No email on record'),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  onTap: _sending ? null : () => onToggleMember(member),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: manualController,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Add email to $label',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => onAddManual(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _sending ? null : onAddManual,
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_loadingPreview)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_totalRecipients > 0) ...[
              const SizedBox(height: 12),
              Text('Total recipients: $_totalRecipients'),
              if (_missingEmailCount > 0)
                Text('Skipped $_missingEmailCount member(s) missing email addresses'),
              const SizedBox(height: 12),
              ..._previewMembers.map(
                (member) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(member.name),
                  subtitle: Text(member.preferredEmail ?? ''),
                ),
              ),
              ..._previewManualEmails.map(
                (email) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alternate_email),
                  title: Text(email),
                  subtitle: const Text('Manual recipient'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text('Add filters or manual recipients to populate the preview.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsCard() {
    final modeChips = [
      _buildModeChip(_RecipientMode.manual, 'Manual', Icons.person_add_alt_1),
      _buildModeChip(_RecipientMode.county, 'County', Icons.map_outlined),
      _buildModeChip(_RecipientMode.district, 'District', Icons.apartment_outlined),
      _buildModeChip(_RecipientMode.highSchool, 'High School', Icons.school_outlined),
      _buildModeChip(_RecipientMode.college, 'College', Icons.school),
      _buildModeChip(_RecipientMode.committee, 'Committee', Icons.groups_outlined),
      _buildModeChip(_RecipientMode.chapter, 'Chapter', Icons.flag_outlined),
      _buildModeChip(_RecipientMode.chapterStatus, 'Chapter Status', Icons.badge_outlined),
    ];

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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: modeChips,
            ),
            const SizedBox(height: 16),
            _buildModeSelector(),
            const SizedBox(height: 20),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude opted-out members'),
              value: _filter.excludeOptedOut,
              onChanged: _sending
                  ? null
                  : (value) {
                      setState(() {
                        _filter = _filter.copyWithOverrides(
                          excludeOptedOut: value ?? true,
                        );
                      });
                      _updatePreview();
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude recently contacted (7 days)'),
              value: _filter.excludeRecentlyContacted,
              onChanged: _sending
                  ? null
                  : (value) {
                      setState(() {
                        _filter = _filter.copyWithOverrides(
                          excludeRecentlyContacted: value ?? false,
                        );
                      });
                      _updatePreview();
                    },
            ),
            const SizedBox(height: 12),
            if (_selectedMembers.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedMembers
                    .map((member) => InputChip(
                          label: Text(member.name),
                          avatar: const Icon(Icons.person, size: 18),
                          onDeleted: () => _removeSelectedMember(member),
                        ))
                    .toList(),
              ),
            if (_manualEmails.isNotEmpty) ...[
              if (_selectedMembers.isNotEmpty) const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _manualEmails
                    .map((email) => InputChip(
                          label: Text(email),
                          avatar: const Icon(Icons.alternate_email, size: 18),
                          onDeleted: () => _removeManualEmail(email),
                        ))
                    .toList(),
              ),
            ],
            if (_mode == _RecipientMode.manual) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search members',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (_searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final member = _searchResults[index];
                      final selected = _selectedMembers.any((m) => m.id == member.id);
                      final email = _normalizeEmail(member.preferredEmail);
                      return ListTile(
                        title: Text(member.name),
                        subtitle: Text(email ?? 'No email on record'),
                        trailing: Icon(
                          selected ? Icons.check_circle : Icons.add_circle_outline,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).iconTheme.color,
                        ),
                        onTap: () => _toggleMemberSelection(member),
                      );
                    },
                  ),
                ),
              if (_searchResults.isEmpty && _searchController.text.trim().length >= 2 && !_searching)
                const Text('No members found matching your search.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualEmailController,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        labelText: 'Add manual email',
                        hintText: 'name@example.com',
                      ),
                      onSubmitted: (_) => _addManualEmail(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _sending ? null : _addManualEmail,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(_RecipientMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => _setMode(mode),
    );
  }

  Widget _buildModeSelector() {
    switch (_mode) {
      case _RecipientMode.manual:
        return const SizedBox.shrink();
      case _RecipientMode.county:
        return _buildDropdown(
          label: 'Select County',
          value: _filter.county,
          items: _counties,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(county: value);
          }),
        );
      case _RecipientMode.district:
        return _buildDropdown(
          label: 'Select Congressional District',
          value: _filter.congressionalDistrict,
          items: _districts,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(congressionalDistrict: value);
          }),
        );
      case _RecipientMode.highSchool:
        return _buildDropdown(
          label: 'Select High School',
          value: _filter.highSchool,
          items: _highSchools,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(highSchool: value);
          }),
        );
      case _RecipientMode.college:
        return _buildDropdown(
          label: 'Select College',
          value: _filter.college,
          items: _colleges,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(college: value);
          }),
        );
      case _RecipientMode.committee:
        return _buildDropdown(
          label: 'Select Committee',
          value: _filter.committees?.firstOrNull,
          items: _committees,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(committees: value == null ? null : [value]);
          }),
        );
      case _RecipientMode.chapter:
        return _buildDropdown(
          label: 'Select Chapter',
          value: _filter.chapterName,
          items: _chapters,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(chapterName: value);
          }),
        );
      case _RecipientMode.chapterStatus:
        return _buildDropdown(
          label: 'Select Chapter Status',
          value: _filter.chapterStatus,
          items: _chapterStatuses,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(chapterStatus: value);
          }),
        );
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: _sending ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _MergeFieldDefinition {
  final String token;
  final String label;
  final String description;

  const _MergeFieldDefinition({
    required this.token,
    required this.label,
    required this.description,
  });
}
