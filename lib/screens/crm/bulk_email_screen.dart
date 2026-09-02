import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/forms/widgets/email_html_preview.dart';
import 'package:bluebubbles/models/crm/email_template.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/email_template_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/markdown_quill_loader.dart';
import 'package:bluebubbles/utils/quill_html_converter.dart';
import 'package:bluebubbles/widgets/email_template_picker.dart';

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

/// The three working surfaces of the page. On a wide window Compose is pinned
/// to the left and this selects what the right rail shows; on a narrow window
/// it selects the single visible pane.
enum _Pane { compose, audience, preview }

class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({
    Key? key,
    this.initialFilter,
    this.initialManualMembers,
    this.initialManualEmails,
    this.initialTemplate,
  }) : super(key: key);

  final MessageFilter? initialFilter;
  final List<Member>? initialManualMembers;
  final List<String>? initialManualEmails;
  final EmailTemplate? initialTemplate;

  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMEmailService _emailService = CRMEmailService.instance;
  final EmailTemplateRepository _templateRepository = EmailTemplateRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  final TextEditingController _subjectController = TextEditingController();
  late quill.QuillController _bodyController;
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _bodyScrollController = ScrollController();
  final TextEditingController _fromNameController = TextEditingController();
  final TextEditingController _replyToController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualEmailController = TextEditingController();
  final TextEditingController _ccSearchController = TextEditingController();
  final TextEditingController _ccManualEmailController = TextEditingController();
  final TextEditingController _bccSearchController = TextEditingController();
  final TextEditingController _bccManualEmailController = TextEditingController();
  final TextEditingController _rosterSearchController = TextEditingController();

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
  final List<EmailTemplate> _templates = [];

  MessageFilter _filter = MessageFilter();
  _RecipientMode _mode = _RecipientMode.manual;
  bool _crmReady = false;
  bool _loadingPreview = false;
  bool _sending = false;
  bool _searching = false;
  bool _searchingCc = false;
  bool _searchingBcc = false;
  bool _mailMergeEnabled = false;
  bool _loadingTemplates = false;
  String? _errorMessage;
  String? _templateLoadError;
  late String _selectedFromEmail;
  EmailTemplate? _appliedTemplate;
  String? _pendingTemplateKey;

  _Pane _activePane = _Pane.audience;
  bool _rosterExpanded = false;
  bool _copyExpanded = false;

  String _bodyHtml = '';
  String _bodyPlainText = '';

  /// The body HTML the preview pane is currently rendering. Held apart from
  /// [_bodyHtml] and updated on a settle timer because the web preview reloads
  /// its iframe whenever this string changes, and doing that per keystroke
  /// makes the pane flash and re-layout continuously.
  String _previewHtml = '';
  Timer? _previewDebounce;

  /// Address of the member the preview is being rendered for. Null until the
  /// operator picks one, at which point the first resolved recipient is used.
  String? _previewRecipientEmail;

  /// Every member and manual address the current audience resolves to. The
  /// roster, the preview recipient picker and the counts all read this, so the
  /// operator sees the same list the send will use.
  List<Member> _resolvedMembers = const [];
  List<String> _resolvedManualEmails = const [];
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

  /// White text on the light end of a tile gradient drops under 3:1 without
  /// this. Applied to every label that can land there, the way
  /// [BrandedStatCard] does.
  static const List<Shadow> _contrastShadow = [
    Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// Mirrors the `escapeHtml` the send-email function applies to merge values
  /// before substituting them into the HTML part: `& < > " '`. The preview is
  /// only trustworthy if it escapes exactly what the server escapes.
  static const HtmlEscape _previewValueEscape = HtmlEscape(
    HtmlEscapeMode(
      escapeLtGt: true,
      escapeQuot: true,
      escapeApos: true,
    ),
  );

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
  ];

  /// The variable keys `_buildRecipientVariables` can actually supply, derived
  /// from the offered chips so the two cannot drift apart. The send guard
  /// rejects any other token, which is what stops an unsupported one reaching
  /// a recipient as literal text.
  ///
  /// A chip whose key is not produced per recipient is the defect this set
  /// exists to prevent: the server replaces only keys present in the map, so an
  /// unsupplied token is delivered verbatim rather than failing.
  static final Set<String> _supportedMergeKeys = _mergeFieldDefinitions
      .map((definition) => definition.token.replaceAll(RegExp(r'[{}\s]'), ''))
      .toSet();

  static final RegExp _mergeTokenRegex =
      RegExp(r'(\{\{\s*[^{}]+\s*\}\}|\{\s*[^{}]+\s*\})');

  /// Only the double-brace form the server substitutes. `mergeTemplate` in
  /// `send-email` matches `{{\s*key\s*}}` and nothing else, so a single-brace
  /// `{foo}` is literal text rather than an unresolved token. Scanning for the
  /// single-brace form would also match CSS rules inside the generated HTML and
  /// block legitimate sends.
  static final RegExp _substitutableTokenRegex =
      RegExp(r'\{\{\s*([^{}]+?)\s*\}\}');

  /// Schemes the HTML converter will keep on an anchor. Anything else is
  /// silently dropped downstream, so the link dialog refuses it up front and
  /// says why.
  static const Set<String> _allowedLinkSchemes = {
    'http',
    'https',
    'mailto',
    'tel',
  };

  /// Control and whitespace characters browsers strip before resolving a URL.
  /// Removed before the scheme check for the same reason the converter removes
  /// them: `java&#9;script:` reaches the parser as `javascript:`.
  static final RegExp _linkStrippedCharacters = RegExp(r'[\x00-\x20\x7F]');

  @override
  void initState() {
    super.initState();
    _bodyController = quill.QuillController.basic();
    _captureEditorState(triggerSetState: false);
    _previewHtml = _bodyHtml;
    _bodyController.addListener(_handleBodyChanged);
    _subjectController.addListener(_handleSubjectChanged);
    _filter = widget.initialFilter ?? MessageFilter();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    final senders = CRMConfig.allowedSenderEmails;
    if (senders.contains(CRMConfig.defaultSenderEmail)) {
      _selectedFromEmail = CRMConfig.defaultSenderEmail;
    } else if (senders.isNotEmpty) {
      _selectedFromEmail = senders.first;
    } else {
      _selectedFromEmail = CRMConfig.defaultSenderEmail;
    }
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
    _pendingTemplateKey = widget.initialTemplate?.templateKey;
    _searchController.addListener(_onSearchChanged);
    _ccSearchController.addListener(_onCcSearchChanged);
    _bccSearchController.addListener(_onBccSearchChanged);
    _rosterSearchController.addListener(_onRosterSearchChanged);
    if (_crmReady) {
      _loadFilterOptions();
      _updatePreview();
      _loadTemplates();
    }
    if (widget.initialTemplate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyTemplate(widget.initialTemplate!, skipConfirmation: true);
      });
    }
  }

  @override
  void dispose() {
    _subjectController.removeListener(_handleSubjectChanged);
    _subjectController.dispose();
    _bodyController.removeListener(_handleBodyChanged);
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _bodyScrollController.dispose();
    _fromNameController.dispose();
    _replyToController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _ccSearchController.removeListener(_onCcSearchChanged);
    _bccSearchController.removeListener(_onBccSearchChanged);
    _rosterSearchController.removeListener(_onRosterSearchChanged);
    _searchController.dispose();
    _ccSearchController.dispose();
    _bccSearchController.dispose();
    _rosterSearchController.dispose();
    _manualEmailController.dispose();
    _ccManualEmailController.dispose();
    _bccManualEmailController.dispose();
    _searchDebounce?.cancel();
    _ccSearchDebounce?.cancel();
    _bccSearchDebounce?.cancel();
    _previewDebounce?.cancel();
    super.dispose();
  }

  bool get _hasRecipients => _totalRecipients > 0;

  bool get _canSendEmail =>
      _crmReady &&
      !_sending &&
      _hasRecipients &&
      _subjectController.text.trim().isNotEmpty &&
      _bodyPlainText.isNotEmpty;

  /// Why the send button is off, in the operator's words. Mirrors
  /// [_canSendEmail] condition for condition: a disabled button that explains
  /// nothing is the thing this replaces.
  List<String> get _sendBlockers {
    final blockers = <String>[];
    if (!_crmReady) {
      blockers.add('CRM Supabase is not configured, so sending is disabled.');
    }
    if (!_hasRecipients) {
      blockers.add('No recipients resolved yet. Pick an audience.');
    }
    if (_subjectController.text.trim().isEmpty) {
      blockers.add('The subject line is empty.');
    }
    if (_bodyPlainText.isEmpty) {
      blockers.add('The message body is empty.');
    }
    return blockers;
  }

  /// Tokens the current draft carries that no recipient variable can fill.
  /// Surfaced continuously rather than only on the send attempt, so the
  /// operator sees the problem while writing.
  List<String> get _currentUnsupportedTokens => _unsupportedMergeTokens(
        subject: _subjectController.text.trim(),
        plainText: _bodyPlainText.isEmpty ? null : _bodyPlainText,
        html: _bodyHtml.isEmpty ? null : _bodyHtml,
      );

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

    final filter = _activeFilter;
    final hasFilters = filter.hasActiveFilters;
    final hasManualRecipients = _selectedMembers.isNotEmpty || _manualEmails.isNotEmpty;

    if (!hasFilters && !hasManualRecipients) {
      setState(() {
        _resolvedMembers = const [];
        _resolvedManualEmails = const [];
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
        if (filter.excludeOptedOut && member.optOut) {
          return;
        }
        combined[member.id] = member;
      }

      if (hasFilters) {
        final response = await _memberRepo.getAllMembers(
          county: filter.county,
          congressionalDistrict: filter.congressionalDistrict,
          committees: filter.committees,
          highSchool: filter.highSchool,
          college: filter.college,
          chapterName: filter.chapterName,
          chapterStatus: filter.chapterStatus,
          minAge: filter.minAge,
          maxAge: filter.maxAge,
          optedOut: filter.excludeOptedOut ? false : null,
        );

        var members = response.members;
        if (filter.excludeRecentlyContacted) {
          final threshold = DateTime.now().subtract(
            filter.recentContactThreshold ?? const Duration(days: 7),
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
        _resolvedMembers = combined.values.toList(growable: false);
        _resolvedManualEmails = List<String>.unmodifiable(manualEmails);
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

  void _onRosterSearchChanged() {
    setState(() {});
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
    final fromName = _fromNameController.text.trim();
    final replyTo = _replyToController.text.trim();

    _captureEditorState(triggerSetState: false);
    final htmlBody = _bodyHtml.isNotEmpty ? _bodyHtml : null;
    final textBody = _bodyPlainText.isNotEmpty ? _bodyPlainText : null;

    // Refuse the send while any token remains that no recipient variable can
    // fill. Checked here rather than in `_canSendEmail` so the operator gets the
    // offending names instead of a silently disabled button, and before
    // `_sending` is set so the composer stays usable.
    final unresolved = _unsupportedMergeTokens(
      subject: subject,
      plainText: textBody,
      html: htmlBody,
    );
    if (unresolved.isNotEmpty) {
      final names = unresolved.join(', ');
      final plural = unresolved.length > 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot send: $names '
            '${plural ? 'are not supported merge fields' : 'is not a supported merge field'}. '
            '${plural ? 'They' : 'It'} would reach recipients as written. '
            'Remove ${plural ? 'them' : 'it'} or pick from the merge field list.',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    final confirmed = await _confirmSend(subject: subject);
    if (confirmed != true || !mounted) {
      return;
    }

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

      final recipientPayloads = _buildRecipientPayloads(
        emails: recipients.emails,
        members: recipients.members,
      );

      await _emailService.sendEmail(
        to: recipients.emails,
        subject: subject,
        htmlBody: htmlBody,
        textBody: textBody,
        fromEmail: _selectedFromEmail,
        fromName: fromName.isEmpty ? null : fromName,
        replyTo: replyTo.isEmpty ? null : replyTo,
        cc: recipients.ccEmails.isEmpty ? null : recipients.ccEmails,
        bcc: recipients.bccEmails.isEmpty ? null : recipients.bccEmails,
        recipients: recipientPayloads,
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

  /// Last stop before a few hundred inboxes. Restates what is about to happen
  /// in the terms that go wrong most often: how many, from whom, and whether
  /// personalization is on.
  Future<bool?> _confirmSend({required String subject}) {
    final ccCount = _ccMembers.length + _ccManualEmails.length;
    final bccCount = _bccMembers.length + _bccManualEmails.length;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Send this email?',
          style: TextStyle(
            color: BrandColors.unityBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow(Icons.group, 'Recipients',
                '$_totalRecipients ${_totalRecipients == 1 ? 'address' : 'addresses'}'),
            _confirmRow(Icons.alternate_email, 'From', _selectedFromEmail),
            _confirmRow(Icons.subject, 'Subject', subject),
            _confirmRow(
              Icons.auto_fix_high,
              'Mail merge',
              _mailMergeEnabled ? 'On' : 'Off',
            ),
            if (ccCount > 0 || bccCount > 0)
              _confirmRow(Icons.copy_all, 'Copies', '$ccCount CC, $bccCount BCC'),
            if (_attachments.isNotEmpty)
              _confirmRow(Icons.attach_file, 'Attachments',
                  '${_attachments.length} ${_attachments.length == 1 ? 'file' : 'files'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: BrandColors.unityBlue.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: BrandColors.unityBlue,
            ),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send now'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BrandColors.momentumBlue),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: BrandColors.unityBlue.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<({
    List<Member> members,
    List<String> emails,
    List<Member> ccMembers,
    List<String> ccEmails,
    List<Member> bccMembers,
    List<String> bccEmails,
  })> _resolveRecipients() async {
    final filter = _activeFilter;
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
      if (filter.excludeOptedOut && member.optOut) {
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

    if (filter.hasActiveFilters) {
      final response = await _memberRepo.getAllMembers(
        county: filter.county,
        congressionalDistrict: filter.congressionalDistrict,
        committees: filter.committees,
        highSchool: filter.highSchool,
        college: filter.college,
        chapterName: filter.chapterName,
        chapterStatus: filter.chapterStatus,
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        optedOut: filter.excludeOptedOut ? false : null,
      );

      var membersList = response.members;
      if (filter.excludeRecentlyContacted) {
        final threshold = DateTime.now().subtract(
          filter.recentContactThreshold ?? const Duration(days: 7),
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

  /// Builds the per-recipient payloads. The variables map is ALWAYS attached,
  /// regardless of the mail merge toggle.
  ///
  /// The toggle used to gate it. That shipped `{{first_name}}` to the recipient
  /// verbatim whenever a token was in the body and the toggle was off, because
  /// the server replaces only keys present in the map and a null map means no
  /// replacement at all. A token in the body is unambiguous intent to
  /// personalize, and the toggle is reachable in the off position with tokens
  /// present because an operator can switch it back off after the auto-enable
  /// fires. Always supplying the map is safer than refusing the send, because
  /// the send guard already blocks any token this map cannot fill, so by the
  /// time a send proceeds every token present is one of `_supportedMergeKeys`.
  List<CRMEmailRecipientPayload> _buildRecipientPayloads({
    required List<String> emails,
    required List<Member> members,
  }) {
    if (emails.isEmpty) {
      return const [];
    }

    final memberByEmail = <String, Member>{};
    for (final member in members) {
      final email = _normalizeEmail(member.preferredEmail);
      if (email == null) {
        continue;
      }
      memberByEmail[email.toLowerCase()] = member;
    }

    return emails
        .map(
          (email) => CRMEmailRecipientPayload(
            email: email,
            variables: _buildRecipientVariables(
              email: email,
              member: memberByEmail[email.toLowerCase()],
            ),
          ),
        )
        .toList(growable: false);
  }

  /// Fallbacks used when a recipient has no value for a supported merge key.
  ///
  /// EVERY supported key must resolve to something for EVERY recipient. The
  /// server replaces only the keys present in this map, so a key that is merely
  /// *offered* but omitted for one person is delivered to that person as the
  /// literal text `{{chapter_name}}`. An earlier guard checked that a token was
  /// in the supported SET, which proves the chip exists, not that a value was
  /// supplied, so it could never catch this. The set is static and the map was
  /// per recipient; that gap is the whole bug.
  ///
  /// These read as ordinary prose so a fallback never looks like a failure:
  /// "Hi Friend," is a plain greeting, "{{first_name}}" is a bug report.
  static const Map<String, String> _mergeFallbacks = {
    'full_name': 'Friend',
    'first_name': 'Friend',
    'chapter_name': 'your chapter',
  };

  /// Builds the merge map for one recipient, guaranteeing a value for every
  /// supported key. Returns the keys that fell back so the pre-send summary can
  /// tell the operator how many people will see generic wording, rather than
  /// letting them discover it in a reply.
  ({Map<String, dynamic> variables, Set<String> fellBack})
      _buildRecipientVariablesWithFallbacks({
    required String email,
    Member? member,
  }) {
    final variables = <String, dynamic>{'email': email};
    final fellBack = <String>{};

    void put(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        variables[key] = trimmed;
        return;
      }
      // No usable value. Fall back rather than omit: an omitted key ships the
      // raw token to this recipient.
      variables[key] = _mergeFallbacks[key] ?? '';
      fellBack.add(key);
    }

    final fullName = _resolveRecipientFullName(member, email);
    put('full_name', fullName);
    put('first_name', _resolveRecipientFirstName(member, fullName, email));
    put('chapter_name', member?.chapterName);

    // Assert the invariant the send guard depends on. If a new chip is added to
    // _mergeFieldDefinitions without a matching put() above, this catches it
    // here instead of in a member's inbox.
    assert(
      _supportedMergeKeys.every(variables.containsKey),
      'Merge chip offered with no per-recipient value: '
      '${_supportedMergeKeys.where((k) => !variables.containsKey(k))}',
    );

    return (variables: variables, fellBack: fellBack);
  }

  Map<String, dynamic> _buildRecipientVariables({
    required String email,
    Member? member,
  }) =>
      _buildRecipientVariablesWithFallbacks(email: email, member: member)
          .variables;

  String? _resolveRecipientFullName(Member? member, String email) {
    final memberName = member?.name;
    final trimmed = memberName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return _deriveNameFromEmail(email);
  }

  String? _resolveRecipientFirstName(
    Member? member,
    String? resolvedFullName,
    String email,
  ) {
    final rawName = member?.name;
    final trimmedRawName = rawName?.trim();
    final source = (trimmedRawName != null && trimmedRawName.isNotEmpty)
        ? trimmedRawName
        : resolvedFullName ?? _deriveNameFromEmail(email);
    if (source == null) {
      return null;
    }
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return null;
    }
    return _capitalizeWord(parts.first);
  }

  /// Local parts that name a function rather than a person. Greeting a shared
  /// mailbox by its local part produces "Hi Info" in a member's inbox, which is
  /// the artifact this list exists to prevent.
  static const Set<String> _roleAccountWords = {
    'admin', 'alerts', 'billing', 'board', 'chair', 'chapter', 'committee',
    'contact', 'donate', 'donations', 'events', 'exec', 'finance', 'help',
    'hello', 'hi', 'info', 'inquiries', 'mail', 'marketing', 'media', 'members',
    'membership', 'news', 'newsletter', 'noreply', 'no', 'reply', 'office',
    'outreach', 'press', 'privacy', 'sales', 'secretary', 'staff', 'support',
    'team', 'treasurer', 'volunteer', 'volunteers', 'webmaster',
  };

  /// Derives a display name from an address local part, but only when that
  /// local part plausibly names a PERSON. Returns null otherwise, so the
  /// caller omits the variable and the composer's own fallback wording stands.
  ///
  /// A wrong name is worse than no name here: the merge fields feed greetings,
  /// so a bad derivation is read by the recipient while an absent one is not.
  /// The gate is therefore biased to false negatives, and it covers full_name
  /// as well as first_name because both are greeted with.
  String? _deriveNameFromEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) {
      return null;
    }
    var localPart = email.substring(0, atIndex);

    // RFC 5233 subaddressing: everything after '+' is routing metadata the
    // recipient's provider strips, never part of a name.
    final plusIndex = localPart.indexOf('+');
    if (plusIndex >= 0) {
      localPart = localPart.substring(0, plusIndex);
    }

    // A digit means an account handle rather than a name, as in team2026.
    if (localPart.contains(RegExp(r'[0-9]'))) {
      return null;
    }

    final normalized = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final rawWords = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (rawWords.isEmpty) {
      return null;
    }

    if (rawWords.any((word) => _roleAccountWords.contains(word.toLowerCase()))) {
      return null;
    }

    // A single-letter leading word is an initial, so the first name resolver
    // would greet "Hi J". j.smith reaches here and is refused for that reason.
    if (rawWords.first.length < 2) {
      return null;
    }

    // Lowercase before capitalizing, but only here. A local part carries no
    // meaningful internal casing, since MARY.JONES and mary.jones are the same
    // mailbox, and greeting a member "Hi MARY" is its own artifact. A recorded
    // member name does assert its casing, so `_capitalizeWord` leaves the rest
    // of the word alone for names like McDonald.
    return rawWords
        .map((word) => _capitalizeWord(word.toLowerCase()))
        .join(' ');
  }

  String _capitalizeWord(String word) {
    if (word.isEmpty) {
      return word;
    }
    if (word.length == 1) {
      return word.toUpperCase();
    }
    return word.substring(0, 1).toUpperCase() + word.substring(1);
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

  void _handleSubjectChanged() {
    if (_mailMergeEnabled) {
      return;
    }
    if (_containsMergeToken(_subjectController.text)) {
      _toggleMailMerge(true);
    }
  }

  void _insertMergeField(String token) {
    if (_sending || !_mailMergeEnabled) return;

    final selection = _bodyController.selection;
    final documentLength = _bodyController.document.length;
    final isSelectionValid = selection.start >= 0 && selection.end >= 0;
    final defaultIndex = documentLength >= 0 ? documentLength : 0;
    final start = isSelectionValid ? selection.start : defaultIndex;
    final end = isSelectionValid ? selection.end : start;
    final baseOffset = start.clamp(0, defaultIndex);
    final extentOffset = end.clamp(0, defaultIndex);
    final replaceLength =
        (extentOffset - baseOffset).clamp(0, documentLength - baseOffset);

    final newSelection = TextSelection.collapsed(offset: baseOffset + token.length);

    _bodyController.replaceText(
      baseOffset,
      replaceLength,
      token,
      newSelection,
    );

    if (!_bodyFocusNode.hasFocus) {
      _bodyFocusNode.requestFocus();
    }
  }

  bool _templateRequiresMailMerge(EmailTemplate template) {
    return template.variables.isNotEmpty || _mergeTokenRegex.hasMatch(template.body);
  }

  String _formatTemplateVariable(String variable) {
    return _normalizeMergeToken(variable) ?? variable;
  }

  String? _normalizeMergeToken(String? raw) {
    if (raw == null) return null;
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{{') && trimmed.endsWith('}}')) {
      trimmed = trimmed.substring(2, trimmed.length - 2).trim();
    } else if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }
    if (trimmed.isEmpty) {
      return null;
    }
    return '{{${trimmed}}}';
  }

  bool _contentHasMergeTokens({String? plainText, String? html}) {
    if (_containsMergeToken(_subjectController.text)) {
      return true;
    }
    if (plainText != null && plainText.isNotEmpty && _containsMergeToken(plainText)) {
      return true;
    }
    if (html != null && html.isNotEmpty && _containsMergeToken(html)) {
      return true;
    }
    return false;
  }

  bool _containsMergeToken(String? text) {
    if (text == null || text.trim().isEmpty) {
      return false;
    }
    return _mergeTokenRegex.hasMatch(text);
  }

  /// Every substitutable token in the outgoing content whose key is not one
  /// `_buildRecipientVariables` supplies, in the `{{name}}` form the operator
  /// typed, deduplicated and ordered for a readable message.
  ///
  /// This is the durable half of the merge-variable fix. Supplying the
  /// variables map always resolves the SUPPORTED tokens; only refusing the send
  /// stops an unsupported one, because the server leaves a key it was not given
  /// untouched and the recipient reads the raw token.
  List<String> _unsupportedMergeTokens({
    required String subject,
    String? plainText,
    String? html,
  }) {
    final unsupported = <String>{};
    for (final source in <String?>[subject, plainText, html]) {
      if (source == null || source.isEmpty) {
        continue;
      }
      for (final match in _substitutableTokenRegex.allMatches(source)) {
        final key = match.group(1)?.trim();
        if (key == null || key.isEmpty) {
          continue;
        }
        if (!_supportedMergeKeys.contains(key)) {
          unsupported.add('{{$key}}');
        }
      }
    }
    final ordered = unsupported.toList()..sort();
    return ordered;
  }

  // ==================== PAGE SHELL ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.unityBlue,
      body: BrandedBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Below this the composer and the rail cannot both hold a usable
            // measure, so the page collapses to one pane at a time.
            final isWide = constraints.maxWidth >= 1100;
            return Column(
              children: [
                _buildPageHeader(isWide),
                Expanded(
                  child: _crmReady
                      ? _buildPanes(isWide)
                      : _buildUnavailableState(),
                ),
                if (_crmReady) _buildSendBar(isWide),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool isWide) {
    final canPop = Navigator.of(context).canPop();
    final subtitle = _crmReady
        ? '$_totalRecipients ${_totalRecipients == 1 ? 'recipient' : 'recipients'} resolved  ·  from $_selectedFromEmail'
        : 'Sending is disabled until CRM Supabase is configured';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: BrandColors.getTileGradient(),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (canPop)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Back',
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Email',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: _contrastShadow,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            shadows: _contrastShadow,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_loadingPreview)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrandColors.sunriseGold,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: (!_crmReady || _sending) ? null : _refreshAll,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    disabledColor: Colors.white54,
                    tooltip: 'Reload audience and templates',
                  ),
                ],
              ),
              if (_crmReady) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _headerPill(
                      Icons.group,
                      '$_totalRecipients ${_totalRecipients == 1 ? 'recipient' : 'recipients'}',
                    ),
                    _headerPill(Icons.filter_alt_outlined, _modeLabel(_mode)),
                    _headerPill(
                      Icons.auto_fix_high,
                      _mailMergeEnabled ? 'Merge on' : 'Merge off',
                    ),
                    if (_attachments.isNotEmpty)
                      _headerPill(
                        Icons.attach_file,
                        '${_attachments.length} ${_attachments.length == 1 ? 'attachment' : 'attachments'}',
                      ),
                    if (_missingEmailCount > 0)
                      _headerPill(
                        Icons.report_gmailerrorred,
                        '$_missingEmailCount without email',
                      ),
                  ],
                ),
                if (!isWide) ...[
                  const SizedBox(height: 14),
                  _buildPaneSegments(const [
                    _Pane.compose,
                    _Pane.audience,
                    _Pane.preview,
                  ]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: _contrastShadow,
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented pane switcher. Always rendered on a gradient surface so one
  /// treatment covers both the header (narrow) and the rail strip (wide).
  Widget _buildPaneSegments(List<_Pane> panes) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: panes.map((pane) {
          final selected = _effectivePane(panes) == pane;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _activePane = pane),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? BrandColors.sunriseGold : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _paneIcon(pane),
                        size: 16,
                        color: selected ? BrandColors.unityBlue : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _paneLabel(pane),
                        style: TextStyle(
                          color: selected ? BrandColors.unityBlue : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  /// The pane a segment group should show as selected. On a wide window the
  /// rail offers only Audience and Preview, so a stale Compose selection from
  /// a narrower layout resolves to Audience rather than lighting nothing.
  _Pane _effectivePane(List<_Pane> available) {
    if (available.contains(_activePane)) {
      return _activePane;
    }
    return available.first;
  }

  String _paneLabel(_Pane pane) {
    switch (pane) {
      case _Pane.compose:
        return 'Compose';
      case _Pane.audience:
        return 'Audience';
      case _Pane.preview:
        return 'Preview';
    }
  }

  IconData _paneIcon(_Pane pane) {
    switch (pane) {
      case _Pane.compose:
        return Icons.edit_note;
      case _Pane.audience:
        return Icons.groups_2_outlined;
      case _Pane.preview:
        return Icons.visibility_outlined;
    }
  }

  Widget _buildPanes(bool isWide) {
    if (!isWide) {
      switch (_activePane) {
        case _Pane.compose:
          return _buildComposePane();
        case _Pane.audience:
          return _buildAudiencePane();
        case _Pane.preview:
          return _buildPreviewPane();
      }
    }

    const railPanes = [_Pane.audience, _Pane.preview];
    final railPane = _effectivePane(railPanes);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _buildComposePane()),
        Container(width: 1, color: Colors.white.withValues(alpha: 0.1)),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
                padding: const EdgeInsets.all(12),
                child: _buildPaneSegments(railPanes),
              ),
              Expanded(
                child: railPane == _Pane.audience
                    ? _buildAudiencePane()
                    : _buildPreviewPane(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BrandColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off,
                size: 48,
                color: BrandColors.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CRM Supabase is not configured, so email sending is disabled.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadFilterOptions(), _updatePreview(), _loadTemplates()]);
  }

  // ==================== COMPOSE PANE ====================

  Widget _buildComposePane() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTemplateCard(),
        const SizedBox(height: 24),
        _buildMessageCard(),
        const SizedBox(height: 24),
        _buildCarbonCopyCard(),
      ],
    );
  }

  Widget _buildTemplateCard() {
    final template = _appliedTemplate;
    final actionsEnabled = !_sending;
    final subtitle = _templateLoadError ??
        (template != null
            ? '${template.templateTypeLabel} · ${template.audienceLabel}'
            : 'Start from approved copy instead of a blank page.');

    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Icons.description_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template?.templateName ?? 'No template selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        shadows: _contrastShadow,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _templateLoadError != null
                            ? const Color(0xFFFFD9D9)
                            : Colors.white70,
                        fontSize: 12,
                        shadows: _contrastShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: actionsEnabled ? _handleBrowseTemplates : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.sunriseGold,
                  foregroundColor: BrandColors.unityBlue,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white54,
                ),
                icon: _loadingTemplates
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrandColors.unityBlue,
                        ),
                      )
                    : const Icon(Icons.folder_open, size: 18),
                label: Text(template == null ? 'Browse templates' : 'Change template'),
              ),
              if (template != null)
                TextButton.icon(
                  onPressed: actionsEnabled ? _clearTemplateSelection : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade300,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear template'),
                ),
            ],
          ),
          if (template == null &&
              !_loadingTemplates &&
              _templates.isEmpty &&
              _templateLoadError == null) ...[
            const SizedBox(height: 10),
            const Text(
              'No templates found. Add rows to the email_templates table to populate this list.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                shadows: _contrastShadow,
              ),
            ),
          ],
          if (template != null && template.variables.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: template.variables
                  .map((variable) => _staticPill(_formatTemplateVariable(variable)))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    final isEnabled = !_sending;
    final fromOptions = CRMConfig.allowedSenderEmails;
    // Null rather than a value absent from `items`, which a DropdownButton
    // asserts on. Reachable when the allowed-sender list is empty.
    final fromValue = fromOptions.contains(_selectedFromEmail)
        ? _selectedFromEmail
        : (fromOptions.isNotEmpty ? fromOptions.first : null);

    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Icons.edit_note),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: _contrastShadow,
                      ),
                    ),
                    Text(
                      'Headers and body, written on the sheet that ships.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: _contrastShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // The message is authored on a white sheet rather than on the
          // gradient: Quill paints its own dark text, and every field on this
          // page is readable for the same reason a real email is.
          AbsorbPointer(
            absorbing: !isEnabled,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isEnabled ? 1 : 0.6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _paperRow(
                      label: 'From',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: fromValue,
                          isExpanded: true,
                          isDense: true,
                          dropdownColor: Colors.white,
                          icon: Icon(
                            Icons.expand_more,
                            color: BrandColors.unityBlue.withValues(alpha: 0.7),
                          ),
                          style: const TextStyle(
                            color: BrandColors.unityBlue,
                            fontSize: 14,
                          ),
                          items: fromOptions
                              .map(
                                (email) => DropdownMenuItem<String>(
                                  value: email,
                                  child: Text(
                                    email,
                                    style: const TextStyle(
                                      color: BrandColors.unityBlue,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null || value == _selectedFromEmail) return;
                            setState(() => _selectedFromEmail = value);
                          },
                        ),
                      ),
                    ),
                    _paperRow(
                      label: 'Name',
                      child: _paperTextField(
                        controller: _fromNameController,
                        hint: 'Missouri Young Democrats',
                      ),
                    ),
                    _paperRow(
                      label: 'Reply to',
                      child: _paperTextField(
                        controller: _replyToController,
                        hint: 'Optional reply address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    _paperRow(
                      label: 'Subject',
                      child: _paperTextField(
                        controller: _subjectController,
                        hint: 'What is this email about?',
                        emphasized: true,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _buildEditorToolbar(),
                    _buildEditor(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildMailMergeSection(),
          const SizedBox(height: 16),
          _buildAttachmentsSection(),
        ],
      ),
    );
  }

  Widget _paperRow({
    required String label,
    required Widget child,
    bool showDivider = true,
  }) {
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: BrandColors.unityBlue.withValues(alpha: 0.1)),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: BrandColors.unityBlue.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _paperTextField({
    required TextEditingController controller,
    String? hint,
    bool emphasized = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      cursorColor: BrandColors.momentumBlue,
      style: TextStyle(
        color: BrandColors.unityBlue,
        fontSize: emphasized ? 16 : 14,
        fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        hintText: hint,
        hintStyle: TextStyle(
          color: BrandColors.unityBlue.withValues(alpha: 0.7),
          fontWeight: FontWeight.normal,
          fontSize: emphasized ? 16 : 14,
        ),
      ),
    );
  }

  // ==================== EDITOR ====================

  Widget _buildEditorToolbar() {
    final attributes = _bodyController.getSelectionStyle().attributes;
    final headerValue = attributes[quill.Attribute.header.key]?.value;
    final listValue = attributes[quill.Attribute.list.key]?.value;
    final alignValue = attributes[quill.Attribute.align.key]?.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: BrandColors.unityBlue.withValues(alpha: 0.1)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _toolbarGroup('Text', [
            _toolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              active: attributes.containsKey(quill.Attribute.bold.key),
              onPressed: () => _toggleInlineFormat(quill.Attribute.bold),
            ),
            _toolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              active: attributes.containsKey(quill.Attribute.italic.key),
              onPressed: () => _toggleInlineFormat(quill.Attribute.italic),
            ),
            _toolbarButton(
              icon: Icons.format_underline,
              tooltip: 'Underline',
              active: attributes.containsKey(quill.Attribute.underline.key),
              onPressed: () => _toggleInlineFormat(quill.Attribute.underline),
            ),
            _toolbarButton(
              icon: Icons.format_strikethrough,
              tooltip: 'Strikethrough',
              active: attributes.containsKey(quill.Attribute.strikeThrough.key),
              onPressed: () => _toggleInlineFormat(quill.Attribute.strikeThrough),
            ),
          ]),
          _toolbarGroup('Blocks', [
            _toolbarButton(
              icon: Icons.title,
              tooltip: 'Heading 1',
              active: headerValue == 1,
              onPressed: () => _toggleBlockFormat(quill.Attribute.h1),
            ),
            _toolbarButton(
              icon: Icons.text_fields,
              tooltip: 'Heading 2',
              active: headerValue == 2,
              onPressed: () => _toggleBlockFormat(quill.Attribute.h2),
            ),
            _toolbarButton(
              icon: Icons.format_quote,
              tooltip: 'Blockquote',
              active: attributes.containsKey(quill.Attribute.blockQuote.key),
              onPressed: () => _toggleBlockFormat(quill.Attribute.blockQuote),
            ),
          ]),
          _toolbarGroup('Lists', [
            _toolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Bulleted list',
              active: listValue == 'bullet',
              onPressed: () => _toggleBlockFormat(quill.Attribute.ul),
            ),
            _toolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Numbered list',
              active: listValue == 'ordered',
              onPressed: () => _toggleBlockFormat(quill.Attribute.ol),
            ),
          ]),
          _toolbarGroup('Align', [
            _toolbarButton(
              icon: Icons.format_align_left,
              tooltip: 'Align left',
              active: alignValue == null || alignValue == 'left',
              onPressed: () => _toggleBlockFormat(quill.Attribute.leftAlignment),
            ),
            _toolbarButton(
              icon: Icons.format_align_center,
              tooltip: 'Align center',
              active: alignValue == 'center',
              onPressed: () => _toggleBlockFormat(quill.Attribute.centerAlignment),
            ),
            _toolbarButton(
              icon: Icons.format_align_right,
              tooltip: 'Align right',
              active: alignValue == 'right',
              onPressed: () => _toggleBlockFormat(quill.Attribute.rightAlignment),
            ),
          ]),
          _toolbarGroup('Link', [
            _toolbarButton(
              icon: Icons.link,
              tooltip: 'Add or edit hyperlink',
              active: attributes.containsKey(quill.Attribute.link.key),
              onPressed: _promptForLink,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _toolbarGroup(String label, List<Widget> buttons) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: BrandColors.unityBlue.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 6),
        ...buttons,
      ],
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _sending ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? BrandColors.unityBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.white : BrandColors.unityBlue.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    _bodyController.readOnly = _sending;

    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');

    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      // Quill derives its text color from the ambient DefaultTextStyle, which
      // in this app is a dark-theme white. Pinning it here is what keeps the
      // body legible on the white sheet regardless of the app theme.
      child: DefaultTextStyle(
        style: const TextStyle(
          color: BrandColors.unityBlue,
          fontSize: 15,
          height: 1.5,
        ),
        child: quill.QuillEditor(
          focusNode: _bodyFocusNode,
          scrollController: _bodyScrollController,
          configurations: quill.QuillEditorConfigurations(
            controller: _bodyController,
            sharedConfigurations: quill.QuillSharedConfigurations(locale: locale),
            scrollable: true,
            expands: false,
            padding: const EdgeInsets.all(12),
            placeholder: 'Write the message members will read…',
            minHeight: 260,
            customStyles: const quill.DefaultStyles(
              link: TextStyle(
                color: BrandColors.royalBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleInlineFormat(quill.Attribute attribute) {
    if (_sending) return;
    final selection = _bodyController.selection;
    if (!selection.isValid) return;
    final currentStyle = _bodyController.getSelectionStyle();
    final isActive = currentStyle.attributes.containsKey(attribute.key);
    final removal = quill.Attribute.clone(attribute, null);
    _bodyController.formatSelection(isActive ? removal : attribute);
  }

  /// Toggles a line-level attribute (heading, list, quote, alignment).
  /// Compared by value rather than key so tapping H1 while on H2 switches
  /// level instead of clearing the heading.
  void _toggleBlockFormat(quill.Attribute attribute) {
    if (_sending) return;
    final current = _bodyController.getSelectionStyle().attributes[attribute.key];
    final isActive = current != null && current.value == attribute.value;
    _bodyController.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
    setState(() {});
  }

  /// Normalizes a typed link the way the HTML converter will read it, or
  /// returns null when the converter would drop it.
  ///
  /// A bare `moyoungdemocrats.org` has no scheme, so the converter rejects it
  /// and the anchor silently disappears from the sent mail. Promoting it to
  /// https here is what makes the obvious input work.
  String? _normalizeLinkUrl(String raw) {
    final cleaned = raw.replaceAll(_linkStrippedCharacters, '');
    if (cleaned.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(cleaned);
    if (parsed == null) {
      return null;
    }

    if (parsed.scheme.isEmpty) {
      if (!cleaned.contains('.')) {
        return null;
      }
      final promoted = Uri.tryParse('https://$cleaned');
      if (promoted == null || promoted.host.isEmpty) {
        return null;
      }
      return 'https://$cleaned';
    }

    return _allowedLinkSchemes.contains(parsed.scheme.toLowerCase()) ? cleaned : null;
  }

  Future<void> _promptForLink() async {
    if (_sending) return;
    final selection = _bodyController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the text you want to link first.')),
      );
      return;
    }

    final currentStyle = _bodyController.getSelectionStyle();
    final existingLink =
        currentStyle.attributes[quill.Attribute.link.key]?.value?.toString() ?? '';
    final controller = TextEditingController(text: existingLink);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Hyperlink',
                style: TextStyle(
                  color: BrandColors.unityBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    cursorColor: BrandColors.momentumBlue,
                    style: const TextStyle(color: BrandColors.unityBlue),
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      labelStyle: TextStyle(
                        color: BrandColors.unityBlue.withValues(alpha: 0.7),
                      ),
                      hintText: 'https://moyoungdemocrats.org',
                      hintStyle: TextStyle(
                        color: BrandColors.unityBlue.withValues(alpha: 0.7),
                      ),
                      errorText: error,
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: BrandColors.momentumBlue),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      final normalized = _normalizeLinkUrl(controller.text.trim());
                      if (normalized == null) {
                        setDialogState(() => error = _linkRejectionMessage);
                        return;
                      }
                      Navigator.of(dialogContext).pop(normalized);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Email links can use http, https, mailto or tel. Anything else '
                    'is stripped out of the message before it is delivered.',
                    style: TextStyle(
                      color: BrandColors.unityBlue.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: BrandColors.unityBlue.withValues(alpha: 0.7)),
                  ),
                ),
                if (existingLink.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(''),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Remove link'),
                  ),
                ElevatedButton(
                  onPressed: () {
                    final normalized = _normalizeLinkUrl(controller.text.trim());
                    if (normalized == null) {
                      setDialogState(() => error = _linkRejectionMessage);
                      return;
                    }
                    Navigator.of(dialogContext).pop(normalized);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.sunriseGold,
                    foregroundColor: BrandColors.unityBlue,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    if (result.isEmpty) {
      _bodyController.formatSelection(
        quill.Attribute.clone(quill.Attribute.link, null),
      );
    } else {
      _bodyController.formatSelection(quill.LinkAttribute(result));
    }
    setState(() {});
  }

  static const String _linkRejectionMessage =
      'Use an http, https, mailto or tel address. Other schemes are dropped '
      'from the email, so the link would arrive as plain text.';

  // ==================== MERGE FIELDS AND ATTACHMENTS ====================

  Widget _buildMailMergeSection() {
    final template = _appliedTemplate;
    final templateVariables = template?.variables ?? const <String>[];
    final requiresTemplateMerge =
        template != null && _templateRequiresMailMerge(template);
    final unsupported = _currentUnsupportedTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToggleTile(
          icon: Icons.auto_fix_high,
          title: 'Personalize with mail merge',
          subtitle: 'Fill fields like {{first_name}} per recipient before sending.',
          value: _mailMergeEnabled,
          onChanged: _sending ? null : _toggleMailMerge,
        ),
        if (_mailMergeEnabled) ...[
          const SizedBox(height: 12),
          const Text(
            'Insert a field at the cursor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: _contrastShadow,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mergeFieldDefinitions
                .map(
                  (definition) => Tooltip(
                    message: '${definition.token}\n${definition.description}',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _sending ? null : () => _insertMergeField(definition.token),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                definition.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: _contrastShadow,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (templateVariables.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Template variables',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: _contrastShadow,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: templateVariables
                  .map((variable) => _staticPill(_formatTemplateVariable(variable)))
                  .toList(growable: false),
            ),
          ],
        ] else if (requiresTemplateMerge) ...[
          const SizedBox(height: 10),
          _buildNoticeStrip(
            icon: Icons.warning_amber_rounded,
            color: BrandColors.warning,
            message:
                'This template contains merge fields. Turn mail merge on so they '
                'are filled before sending.',
          ),
        ],
        if (unsupported.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildNoticeStrip(
            icon: Icons.block,
            color: BrandColors.error,
            message:
                'Sending is blocked: ${unsupported.join(', ')} '
                '${unsupported.length > 1 ? 'are not merge fields this CRM can fill' : 'is not a merge field this CRM can fill'}. '
                'Recipients would read the raw token. Remove it or use a field from the list.',
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: _contrastShadow,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._attachments.map(
              (file) => Container(
                padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attachment, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        '${file.name}  (${_formatBytes(file.size)})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: _contrastShadow,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : () => _removeAttachment(file),
                      icon: const Icon(Icons.close, size: 14),
                      color: Colors.white70,
                      disabledColor: Colors.white38,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      tooltip: 'Remove ${file.name}',
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _sending ? null : _pickAttachments,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white70),
              ),
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(_attachments.isEmpty ? 'Add attachments' : 'Add more'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ==================== CC / BCC ====================

  Widget _buildCarbonCopyCard() {
    final ccCount = _ccMembers.length + _ccManualEmails.length;
    final bccCount = _bccMembers.length + _bccManualEmails.length;
    final summary = (ccCount == 0 && bccCount == 0)
        ? 'Nobody copied on this send.'
        : '$ccCount on CC, $bccCount on BCC.';

    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _copyExpanded = !_copyExpanded),
              child: Row(
                children: [
                  _iconTile(Icons.copy_all_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CC and BCC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            shadows: _contrastShadow,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            shadows: _contrastShadow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _copyExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_copyExpanded) ...[
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
        ],
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
          '$label recipients',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: _contrastShadow,
          ),
        ),
        const SizedBox(height: 10),
        ...members.map(
          (member) => BrandedActivityFeedItem(
            primaryText: member.name,
            secondaryText: _normalizeEmail(member.preferredEmail) ?? 'No email on record',
            avatarInitials: _initialsFor(member.name),
            showChevron: false,
            trailing: IconButton(
              onPressed: _sending ? null : () => onRemoveMember(member),
              icon: const Icon(Icons.close, size: 16),
              color: Colors.white70,
              disabledColor: Colors.white38,
              tooltip: 'Remove from $label',
            ),
          ),
        ),
        ...manualEmails.map(
          (email) => BrandedActivityFeedItem(
            primaryText: email,
            secondaryText: 'Manual address',
            leadingIcon: Icons.alternate_email,
            showChevron: false,
            trailing: IconButton(
              onPressed: _sending ? null : () => onRemoveManual(email),
              icon: const Icon(Icons.close, size: 16),
              color: Colors.white70,
              disabledColor: Colors.white38,
              tooltip: 'Remove from $label',
            ),
          ),
        ),
        const SizedBox(height: 4),
        _searchField(
          controller: searchController,
          hint: 'Search members to add to $label',
          busy: searching,
        ),
        if (searchResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final member = searchResults[index];
                final selected = members.any((m) => m.id == member.id);
                return BrandedActivityFeedItem(
                  primaryText: member.name,
                  secondaryText:
                      _normalizeEmail(member.preferredEmail) ?? 'No email on record',
                  avatarInitials: _initialsFor(member.name),
                  showChevron: false,
                  onTap: _sending ? null : () => onToggleMember(member),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected ? BrandColors.sunriseGold : Colors.white70,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 10),
        _buildAddEmailRow(
          controller: manualController,
          hint: 'Add an address to $label',
          onAdd: onAddManual,
        ),
      ],
    );
  }

  // ==================== AUDIENCE PANE ====================

  Widget _buildAudiencePane() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: BrandedStatCard(
                title: 'Recipients',
                value: '$_totalRecipients',
                subtitle: _loadingPreview ? 'Resolving…' : _modeLabel(_mode),
                icon: Icons.group,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BrandedStatCard(
                title: 'No email on file',
                value: '$_missingEmailCount',
                subtitle: _missingEmailCount == 0
                    ? 'Everyone matched has an address'
                    : 'Skipped, cannot be emailed',
                icon: Icons.mark_email_unread_outlined,
                // Deliberately NOT an amber gradient. BrandedStatCard paints
                // white at 13px, 32px and 12px; white on #F59E0B is 2.15:1 and
                // on #D97706 is 3.19:1, so the title and subtitle fail 4.5:1
                // outright and the value misses the 3:1 large-text floor at the
                // light end. That gradient appears only in the error branch, so
                // the card would be least readable exactly when it is reporting
                // a problem. The default navy gradient carries white properly;
                // the icon does the warning instead of the background.
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildAudienceCard(),
        const SizedBox(height: 24),
        _buildExclusionsCard(),
        const SizedBox(height: 24),
        _buildRosterCard(),
      ],
    );
  }

  Widget _buildAudienceCard() {
    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Icons.groups_2_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audience',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: _contrastShadow,
                      ),
                    ),
                    Text(
                      'How this recipient list is built.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: _contrastShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _RecipientMode.values
                .map((mode) => _buildModeChip(mode))
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          _buildModeSelector(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildNoticeStrip(
              icon: Icons.error_outline,
              color: BrandColors.error,
              message: _errorMessage!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChip(_RecipientMode mode) {
    final selected = _mode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _sending ? null : () => _setMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _modeIcon(mode),
                size: 15,
                color: selected ? BrandColors.unityBlue : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                _modeLabel(mode),
                style: TextStyle(
                  color: selected ? BrandColors.unityBlue : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: selected ? null : _contrastShadow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeLabel(_RecipientMode mode) {
    switch (mode) {
      case _RecipientMode.manual:
        return 'Hand picked';
      case _RecipientMode.allMembers:
        return 'All members';
      case _RecipientMode.county:
        return 'County';
      case _RecipientMode.district:
        return 'District';
      case _RecipientMode.highSchool:
        return 'High school';
      case _RecipientMode.college:
        return 'College';
      case _RecipientMode.committee:
        return 'Committee';
      case _RecipientMode.chapter:
        return 'Chapter';
      case _RecipientMode.chapterStatus:
        return 'Chapter status';
    }
  }

  IconData _modeIcon(_RecipientMode mode) {
    switch (mode) {
      case _RecipientMode.manual:
        return Icons.person_add_alt_1;
      case _RecipientMode.allMembers:
        return Icons.people_alt_outlined;
      case _RecipientMode.county:
        return Icons.map_outlined;
      case _RecipientMode.district:
        return Icons.apartment_outlined;
      case _RecipientMode.highSchool:
        return Icons.school_outlined;
      case _RecipientMode.college:
        return Icons.school;
      case _RecipientMode.committee:
        return Icons.groups_outlined;
      case _RecipientMode.chapter:
        return Icons.flag_outlined;
      case _RecipientMode.chapterStatus:
        return Icons.badge_outlined;
    }
  }

  Widget _buildModeSelector() {
    switch (_mode) {
      case _RecipientMode.allMembers:
        return _buildNoticeStrip(
          icon: Icons.info_outline,
          color: BrandColors.momentumBlue,
          message:
              'Every member with a valid email address. Members older than '
              '${CRMConfig.maxVisibleMemberAge} are excluded automatically.',
        );
      case _RecipientMode.manual:
        return _buildManualPicker();
      case _RecipientMode.county:
        return _buildAudienceDropdown(
          label: 'County',
          value: _filter.county,
          items: _counties,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(county: value);
          }),
        );
      case _RecipientMode.district:
        return _buildAudienceDropdown(
          label: 'Congressional district',
          value: _filter.congressionalDistrict,
          items: _districts,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(congressionalDistrict: value);
          }),
        );
      case _RecipientMode.highSchool:
        return _buildAudienceDropdown(
          label: 'High school',
          value: _filter.highSchool,
          items: _highSchools,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(highSchool: value);
          }),
        );
      case _RecipientMode.college:
        return _buildAudienceDropdown(
          label: 'College',
          value: _filter.college,
          items: _colleges,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(college: value);
          }),
        );
      case _RecipientMode.committee:
        return _buildAudienceDropdown(
          label: 'Committee',
          value: _filter.committees?.firstOrNull,
          items: _committees,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(committees: value == null ? null : [value]);
          }),
        );
      case _RecipientMode.chapter:
        return _buildAudienceDropdown(
          label: 'Chapter',
          value: _filter.chapterName,
          items: _chapters,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(chapterName: value);
          }),
        );
      case _RecipientMode.chapterStatus:
        return _buildAudienceDropdown(
          label: 'Chapter status',
          value: _filter.chapterStatus,
          items: _chapterStatuses,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(chapterStatus: value);
          }),
        );
    }
  }

  Widget _buildAudienceDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final resolved = value != null && items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: _contrastShadow,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: resolved,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: Icon(
                Icons.expand_more,
                color: BrandColors.unityBlue.withValues(alpha: 0.7),
              ),
              hint: Text(
                items.isEmpty ? 'Nothing to choose yet' : 'Choose one',
                style: TextStyle(
                  color: BrandColors.unityBlue.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              style: const TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 14,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BrandColors.unityBlue,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _sending ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchField(
          controller: _searchController,
          hint: 'Search members by name or email',
          busy: _searching,
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final member = _searchResults[index];
                final selected = _selectedMembers.any((m) => m.id == member.id);
                return BrandedActivityFeedItem(
                  primaryText: member.name,
                  secondaryText:
                      _normalizeEmail(member.preferredEmail) ?? 'No email on record',
                  tertiaryText: member.chapterName,
                  avatarInitials: _initialsFor(member.name),
                  showChevron: false,
                  onTap: _sending ? null : () => _toggleMemberSelection(member),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected ? BrandColors.sunriseGold : Colors.white70,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ],
        if (_searchResults.isEmpty &&
            _searchController.text.trim().length >= 2 &&
            !_searching) ...[
          const SizedBox(height: 10),
          const Text(
            'No members match that search.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              shadows: _contrastShadow,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildAddEmailRow(
          controller: _manualEmailController,
          hint: 'Add an address that is not a member',
          onAdd: _addManualEmail,
        ),
      ],
    );
  }

  Widget _buildExclusionsCard() {
    final thresholdDays = (_filter.recentContactThreshold ?? const Duration(days: 7)).inDays;

    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Icons.shield_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exclusions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: _contrastShadow,
                      ),
                    ),
                    Text(
                      'Who is deliberately left out of this send.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: _contrastShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildToggleTile(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Skip members who opted out',
            subtitle: _filter.excludeOptedOut
                ? 'Opted-out members are removed from the list.'
                : 'Opted-out members WILL receive this email.',
            value: _filter.excludeOptedOut,
            danger: !_filter.excludeOptedOut,
            onChanged: _sending
                ? null
                : (value) {
                    setState(() {
                      _filter = _filter.copyWithOverrides(excludeOptedOut: value);
                    });
                    _updatePreview();
                  },
          ),
          const SizedBox(height: 8),
          _buildToggleTile(
            icon: Icons.history_toggle_off,
            title: 'Skip recently contacted',
            subtitle: 'Leaves out anyone emailed in the last $thresholdDays days.',
            value: _filter.excludeRecentlyContacted,
            onChanged: _sending
                ? null
                : (value) {
                    setState(() {
                      _filter = _filter.copyWithOverrides(
                        excludeRecentlyContacted: value,
                      );
                    });
                    _updatePreview();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildRosterCard() {
    final query = _rosterSearchController.text.trim().toLowerCase();
    final entries = _recipientEntries(query: query);
    // Collapsed, the roster is a sample. Expanded, it scrolls inside its own
    // box so a 400-member audience does not become 400 stacked widgets in the
    // page scroll.
    final visible = _rosterExpanded ? entries : entries.take(6).toList(growable: false);

    return BrandedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Icons.fact_check_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolved roster',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: _contrastShadow,
                      ),
                    ),
                    Text(
                      query.isEmpty
                          ? '$_totalRecipients ${_totalRecipients == 1 ? 'address' : 'addresses'} will be emailed'
                          : '${entries.length} of $_totalRecipients match "$query"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: _contrastShadow,
                      ),
                    ),
                  ],
                ),
              ),
              if (entries.length > 6)
                TextButton(
                  onPressed: () => setState(() => _rosterExpanded = !_rosterExpanded),
                  style: TextButton.styleFrom(foregroundColor: BrandColors.sunriseGold),
                  child: Text(_rosterExpanded ? 'Collapse' : 'Show all'),
                ),
            ],
          ),
          if (_totalRecipients > 0) ...[
            const SizedBox(height: 12),
            _searchField(
              controller: _rosterSearchController,
              hint: 'Find someone in this list',
              busy: false,
            ),
          ],
          const SizedBox(height: 12),
          if (_totalRecipients == 0)
            const Text(
              'Choose an audience or add addresses to build the list.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                shadows: _contrastShadow,
              ),
            )
          else if (entries.isEmpty)
            Text(
              'Nobody in this audience matches "$query".',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                shadows: _contrastShadow,
              ),
            )
          else if (_rosterExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: visible.length,
                itemBuilder: (context, index) => _rosterRow(visible[index]),
              ),
            )
          else
            ...visible.map(_rosterRow),
          if (!_rosterExpanded && entries.length > visible.length) ...[
            const SizedBox(height: 4),
            Text(
              'and ${entries.length - visible.length} more',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                shadows: _contrastShadow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rosterRow(_RecipientEntry entry) {
    final member = entry.member;
    final isHandPicked =
        member != null && _selectedMembers.any((m) => m.id == member.id);
    final isManual = member == null;

    return BrandedActivityFeedItem(
      primaryText: entry.label,
      secondaryText: entry.email,
      tertiaryText: member?.chapterName,
      avatarInitials: member == null ? null : _initialsFor(member.name),
      leadingIcon: member == null ? Icons.alternate_email : null,
      showChevron: false,
      onTap: () {
        setState(() {
          _previewRecipientEmail = entry.email;
          _activePane = _Pane.preview;
        });
      },
      trailing: (isHandPicked || isManual)
          ? IconButton(
              onPressed: _sending
                  ? null
                  : () {
                      if (member == null) {
                        _removeManualEmail(entry.email);
                      } else {
                        _removeSelectedMember(member);
                      }
                    },
              icon: const Icon(Icons.close, size: 16),
              color: Colors.white70,
              disabledColor: Colors.white38,
              tooltip: 'Remove from this send',
            )
          : null,
    );
  }

  /// Every address the current audience resolves to, members first, optionally
  /// narrowed by a roster search. This is the same set the preview picker and
  /// the send both work from.
  List<_RecipientEntry> _recipientEntries({String query = ''}) {
    final entries = <_RecipientEntry>[
      for (final member in _resolvedMembers)
        _RecipientEntry(
          email: _normalizeEmail(member.preferredEmail) ?? '',
          label: member.name,
          member: member,
        ),
      for (final email in _resolvedManualEmails)
        _RecipientEntry(email: email, label: email, member: null),
    ];

    if (query.isEmpty) {
      return entries;
    }
    return entries
        .where((entry) =>
            entry.label.toLowerCase().contains(query) ||
            entry.email.toLowerCase().contains(query))
        .toList(growable: false);
  }

  // ==================== PREVIEW PANE ====================

  Widget _buildPreviewPane() {
    final entries = _recipientEntries();
    final entry = _selectedPreviewEntry(entries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BrandedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconTile(Icons.visibility_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: _contrastShadow,
                          ),
                        ),
                        Text(
                          'The message as one member will receive it.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            shadows: _contrastShadow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (entry == null)
                const Text(
                  'Pick an audience first. The preview fills merge fields with a '
                  'real recipient, so it needs a resolved list.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    shadows: _contrastShadow,
                  ),
                )
              else ...[
                _buildPreviewRecipientPicker(entries, entry),
                const SizedBox(height: 14),
                _buildPreviewSheet(entry),
                const SizedBox(height: 12),
                const Text(
                  'This is the HTML this composer generates, merged with the '
                  'selected recipient\'s own values, exactly as the send service '
                  'merges it. The service only wraps it in a plain HTML document: '
                  'it adds no footer or styling of its own.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    shadows: _contrastShadow,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  _RecipientEntry? _selectedPreviewEntry(List<_RecipientEntry> entries) {
    if (entries.isEmpty) {
      return null;
    }
    final wanted = _previewRecipientEmail?.toLowerCase();
    if (wanted != null) {
      final match = entries.firstWhereOrNull(
        (entry) => entry.email.toLowerCase() == wanted,
      );
      if (match != null) {
        return match;
      }
    }
    return entries.first;
  }

  Widget _buildPreviewRecipientPicker(
    List<_RecipientEntry> entries,
    _RecipientEntry current,
  ) {
    // A dropdown holding every address of a several-hundred-member audience is
    // unusable, so it offers a window and the arrows walk the whole list.
    const optionLimit = 100;
    // Deduplicated because two member rows can share an address, and a
    // DropdownButton asserts when two items carry the same value.
    final options = <String>[];
    for (final entry in entries.take(optionLimit)) {
      if (!options.contains(entry.email)) {
        options.add(entry.email);
      }
    }
    if (!options.contains(current.email)) {
      options.insert(0, current.email);
    }
    final labelByEmail = {for (final entry in entries) entry.email: entry.label};
    final currentIndex = entries.indexWhere((entry) => entry.email == current.email);

    void step(int delta) {
      if (entries.isEmpty) return;
      final next = (currentIndex + delta) % entries.length;
      final wrapped = next < 0 ? next + entries.length : next;
      setState(() => _previewRecipientEmail = entries[wrapped].email);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Previewing as',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: _contrastShadow,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: current.email,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.expand_more,
                      color: BrandColors.unityBlue.withValues(alpha: 0.7),
                    ),
                    style: const TextStyle(
                      color: BrandColors.unityBlue,
                      fontSize: 14,
                    ),
                    items: options
                        .map(
                          (email) => DropdownMenuItem<String>(
                            value: email,
                            child: Text(
                              labelByEmail[email] == email
                                  ? email
                                  : '${labelByEmail[email] ?? email}  ·  $email',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: BrandColors.unityBlue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _previewRecipientEmail = value);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => step(-1),
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              tooltip: 'Previous recipient',
            ),
            IconButton(
              onPressed: () => step(1),
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              tooltip: 'Next recipient',
            ),
          ],
        ),
        if (entries.length > optionLimit) ...[
          const SizedBox(height: 6),
          Text(
            'The list shows the first $optionLimit of ${entries.length}. Use the '
            'arrows to reach the rest.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              shadows: _contrastShadow,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewSheet(_RecipientEntry entry) {
    final variables = _buildRecipientVariables(
      email: entry.email,
      member: entry.member,
    );
    final subject = _mergeLikeServer(
      _subjectController.text.trim(),
      variables,
      escapeValues: false,
    );
    final html = _mergeLikeServer(_previewHtml, variables, escapeValues: true);
    final leftover = _substitutableTokenRegex
        .allMatches(subject + html)
        .map((match) => '{{${match.group(1)?.trim()}}}')
        .toSet()
        .toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leftover.isNotEmpty) ...[
          _buildNoticeStrip(
            icon: Icons.warning_amber_rounded,
            color: BrandColors.warning,
            message:
                'Still unresolved for this recipient: ${leftover.join(', ')}. '
                'That is exactly what would land in their inbox.',
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: BrandColors.unityBlue.withValues(alpha: 0.1)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.isEmpty ? 'No subject yet' : subject,
                      style: TextStyle(
                        color: subject.isEmpty
                            ? BrandColors.unityBlue.withValues(alpha: 0.7)
                            : BrandColors.unityBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fromNameController.text.trim().isEmpty ? _selectedFromEmail : _fromNameController.text.trim()} '
                      '<$_selectedFromEmail>  to  ${entry.email}',
                      style: TextStyle(
                        color: BrandColors.unityBlue.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 460,
                child: EmailHtmlPreview(
                  html: html,
                  subject: subject,
                  recipientEmail: entry.email,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Applies the same substitution the send-email function applies, including
  /// the HTML escaping of values, so what the operator reads here is what the
  /// recipient gets rather than an approximation of it.
  String _mergeLikeServer(
    String source,
    Map<String, dynamic> variables, {
    required bool escapeValues,
  }) {
    if (source.isEmpty) {
      return source;
    }
    var merged = source;
    variables.forEach((key, value) {
      final pattern = RegExp('\\{\\{\\s*${RegExp.escape(key)}\\s*\\}\\}');
      final raw = value == null ? '' : value.toString();
      final replacement = escapeValues ? _previewValueEscape.convert(raw) : raw;
      merged = merged.replaceAllMapped(pattern, (_) => replacement);
    });
    return merged;
  }

  // ==================== SEND BAR ====================

  Widget _buildSendBar(bool isWide) {
    final blockers = _sendBlockers;
    final unsupported = _currentUnsupportedTokens;
    final ccCount = _ccMembers.length + _ccManualEmails.length;
    final bccCount = _bccMembers.length + _bccManualEmails.length;

    final String headline;
    final Color headlineColor;
    if (_sending) {
      headline = 'Sending…';
      headlineColor = Colors.white;
    } else if (blockers.isNotEmpty) {
      headline = blockers.first;
      headlineColor = BrandColors.sunriseGold;
    } else if (unsupported.isNotEmpty) {
      headline = 'Unsupported merge fields block this send.';
      headlineColor = BrandColors.sunriseGold;
    } else {
      headline =
          'Ready to send to $_totalRecipients ${_totalRecipients == 1 ? 'recipient' : 'recipients'}';
      headlineColor = Colors.white;
    }

    final details = <String>[
      'From $_selectedFromEmail',
      _mailMergeEnabled ? 'merge on' : 'merge off',
      if (ccCount > 0 || bccCount > 0) '$ccCount CC, $bccCount BCC',
      if (_attachments.isNotEmpty) '${_attachments.length} attached',
      if (blockers.length > 1) '${blockers.length - 1} more issue${blockers.length > 2 ? 's' : ''}',
    ];

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (blockers.isNotEmpty || unsupported.isNotEmpty) ...[
              Icon(
                blockers.isNotEmpty ? Icons.info_outline : Icons.block,
                size: 16,
                color: headlineColor,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                headline,
                style: TextStyle(
                  color: headlineColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  shadows: _contrastShadow,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          details.join('  ·  '),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            shadows: _contrastShadow,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final sendButton = Tooltip(
      message: blockers.isEmpty
          ? 'Send this email'
          : 'Cannot send yet:\n${blockers.map((reason) => '• $reason').join('\n')}',
      child: ElevatedButton.icon(
        onPressed: _canSendEmail ? _sendEmail : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.sunriseGold,
          foregroundColor: BrandColors.unityBlue,
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.white60,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        icon: _sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BrandColors.unityBlue,
                ),
              )
            : const Icon(Icons.send, size: 18),
        label: Text(_sending ? 'Sending' : 'Send email'),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 16),
                    sendButton,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 12),
                    sendButton,
                  ],
                ),
        ),
      ),
    );
  }

  // ==================== SHARED PIECES ====================

  Widget _iconTile(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _staticPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: _contrastShadow,
        ),
      ),
    );
  }

  Widget _buildNoticeStrip({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
                shadows: _contrastShadow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool danger = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: danger
            ? const Border(left: BorderSide(color: BrandColors.warning, width: 3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: _contrastShadow,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    shadows: _contrastShadow,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: BrandColors.sunriseGold,
            activeTrackColor: BrandColors.sunriseGold.withValues(alpha: 0.4),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required bool busy,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        enabled: !_sending,
        cursorColor: BrandColors.momentumBlue,
        style: const TextStyle(color: BrandColors.unityBlue, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintText: hint,
          hintStyle: TextStyle(
            color: BrandColors.unityBlue.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: BrandColors.unityBlue.withValues(alpha: 0.7),
          ),
          suffixIcon: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrandColors.momentumBlue,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAddEmailRow({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: controller,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              cursorColor: BrandColors.momentumBlue,
              style: const TextStyle(color: BrandColors.unityBlue, fontSize: 14),
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                hintText: hint,
                hintStyle: TextStyle(
                  color: BrandColors.unityBlue.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _sending ? null : onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.sunriseGold,
            foregroundColor: BrandColors.unityBlue,
            disabledBackgroundColor: Colors.white24,
            disabledForegroundColor: Colors.white54,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  // ==================== EDITOR STATE AND TEMPLATES ====================

  void _handleBodyChanged() {
    _captureEditorState();
  }

  void _captureEditorState({bool triggerSetState = true}) {
    final document = _bodyController.document;
    final deltaOps = document.toDelta().toJson();
    final deltaJson = deltaOps
        .map<Map<String, dynamic>>(
          (dynamic op) => Map<String, dynamic>.from(op as Map),
        )
        .toList(growable: false);
    // Quill's own toPlainText() keeps the anchor TEXT and throws away the href,
    // so a plain-text reader saw "click here" pointing at nothing. The converter
    // renders links as "text (url)" instead. Used for the text/plain MIME part;
    // the raw form below still drives token detection and the empty check, where
    // appended URLs would only add noise.
    final rawPlainText = document.toPlainText().trim();
    final plainText = QuillHtmlConverter.generatePlainText(deltaJson).trim();
    final html = QuillHtmlConverter.generateHtml(deltaJson, rawPlainText);
    final shouldEnableMailMerge =
        !_mailMergeEnabled && _contentHasMergeTokens(plainText: rawPlainText, html: html);

    void updateValues() {
      _bodyPlainText = plainText;
      _bodyHtml = html;
    }

    if (triggerSetState) {
      setState(updateValues);
    } else {
      updateValues();
    }

    _schedulePreviewRefresh(html);

    if (shouldEnableMailMerge) {
      _toggleMailMerge(true);
    }
  }

  void _schedulePreviewRefresh(String html) {
    if (html == _previewHtml) {
      return;
    }
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _previewHtml = html);
    });
  }

  Future<void> _loadTemplates() async {
    if (!_crmReady) return;

    setState(() {
      _loadingTemplates = true;
      _templateLoadError = null;
    });

    try {
      final templates = await _templateRepository.getActiveTemplates();
      if (!mounted) return;
      setState(() {
        _templates
          ..clear()
          ..addAll(templates);
        _loadingTemplates = false;
      });
      if (_pendingTemplateKey != null && _appliedTemplate == null) {
        final match = templates.firstWhereOrNull(
          (template) => template.templateKey == _pendingTemplateKey,
        );
        if (match != null) {
          await _applyTemplate(match, skipConfirmation: true);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTemplates = false;
        _templateLoadError = 'Failed to load templates: $error';
      });
    }
  }

  Future<void> _handleBrowseTemplates() async {
    if (!_crmReady || _sending) return;

    if (_templates.isEmpty && !_loadingTemplates) {
      await _loadTemplates();
    }

    if (!mounted) return;

    if (_templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates are available yet.')),
      );
      return;
    }

    final selection = await showEmailTemplatePicker(
      context: context,
      templates: _templates,
      initiallySelected: _appliedTemplate,
    );

    if (selection != null) {
      await _applyTemplate(selection);
    }
  }

  Future<void> _applyTemplate(
    EmailTemplate template, {
    bool skipConfirmation = false,
  }) async {
    if (!skipConfirmation) {
      final hasSubject = _subjectController.text.trim().isNotEmpty;
      final hasBody = _bodyController.document.toPlainText().trim().isNotEmpty;
      if (hasSubject || hasBody) {
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Replace current message?',
              style: TextStyle(
                color: BrandColors.unityBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Applying a template replaces the subject and the message body you '
              'have written so far.',
              style: TextStyle(color: BrandColors.unityBlue.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: BrandColors.unityBlue.withValues(alpha: 0.7)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.sunriseGold,
                  foregroundColor: BrandColors.unityBlue,
                ),
                child: const Text('Apply template'),
              ),
            ],
          ),
        );

        if (shouldReplace != true) {
          return;
        }
      }
    }

    final document = MarkdownQuillLoader.fromMarkdown(template.body);
    _resetBodyController(document);

    final subject = template.subject;
    _subjectController
      ..text = subject
      ..selection = TextSelection.collapsed(offset: subject.length);

    final requiresMailMerge = _templateRequiresMailMerge(template);

    setState(() {
      _appliedTemplate = template;
      _pendingTemplateKey = template.templateKey;
    });

    if (requiresMailMerge && !_mailMergeEnabled) {
      _toggleMailMerge(true);
    }
  }

  void _clearTemplateSelection() {
    setState(() {
      _appliedTemplate = null;
      _pendingTemplateKey = null;
    });
  }

  void _resetBodyController(quill.Document document) {
    _bodyController.removeListener(_handleBodyChanged);
    _bodyController.dispose();
    final length = document.length;
    _bodyController = quill.QuillController(
      document: document,
      selection: TextSelection.collapsed(offset: length > 0 ? length - 1 : 0),
    );
    _bodyController.addListener(_handleBodyChanged);
    _captureEditorState(triggerSetState: false);
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

/// One address the current audience resolves to. [member] is null for a manual
/// address, which is also what tells the preview there are no member-derived
/// merge values beyond the email itself.
class _RecipientEntry {
  const _RecipientEntry({
    required this.email,
    required this.label,
    required this.member,
  });

  final String email;
  final String label;
  final Member? member;
}
