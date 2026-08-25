import 'dart:async';
import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
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
      debugPrint('❌ Error updating preview: $e');
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
      backgroundColor: _canvasColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        title: Text(
          'Bulk Message',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _hairline),
        ),
      ),
      body: !_crmReady
          ? _buildCrmNotReadyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 20.0),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 840),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      ),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  // ─────────────────────── Presentation helpers (visual only) ───────────────────────
  // Styling constants and widget builders. All send/recipient/preview logic lives in
  // the frozen methods above; these helpers only READ existing state for display.

  static const double _cardRadius = 18.0;
  static const Color _smsGreen = Color(0xFF43A047);

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _ink => _isDarkMode ? Colors.white : BrandColors.unityBlue;

  Color get _inkMuted =>
      _isDarkMode ? Colors.white70 : BrandColors.unityBlue.withOpacity(0.72);

  Color get _hairline => _isDarkMode
      ? Colors.white.withOpacity(0.14)
      : BrandColors.unityBlue.withOpacity(0.10);

  Color get _cardColor =>
      _isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white;

  Color get _canvasColor => _isDarkMode
      ? Theme.of(context).scaffoldBackgroundColor
      : const Color(0xFFF4F6FA);

  Color get _fieldFill => _isDarkMode
      ? Colors.white.withOpacity(0.06)
      : const Color(0xFFF6F8FC);

  Color get _accentIconColor =>
      _isDarkMode ? BrandColors.momentumBlue : BrandColors.unityBlue;

  TextStyle get _overlineStyle => TextStyle(
        color: _inkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      );

  ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: BrandColors.unityBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _isDarkMode
            ? Colors.white.withOpacity(0.12)
            : BrandColors.unityBlue.withOpacity(0.35),
        disabledForegroundColor: _isDarkMode ? Colors.white38 : Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: _isDarkMode
              ? BorderSide(color: BrandColors.momentumBlue.withOpacity(0.55))
              : BorderSide.none,
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  ButtonStyle get _secondaryButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: _ink,
        disabledForegroundColor: _inkMuted.withOpacity(0.5),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(
          color: _isDarkMode
              ? Colors.white24
              : BrandColors.unityBlue.withOpacity(0.35),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    Widget? suffixIcon,
    String? counterText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      counterText: counterText,
      filled: true,
      fillColor: _fieldFill,
      labelStyle: TextStyle(color: _inkMuted, fontSize: 14),
      hintStyle: TextStyle(color: _inkMuted, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(_hairline),
      disabledBorder: border(_hairline.withOpacity(0.5)),
      focusedBorder: border(BrandColors.momentumBlue, 1.6),
      border: border(_hairline),
    );
  }

  Widget _buildCrmNotReadyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: BrandColors.momentumBlue.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded,
                    size: 26, color: _accentIconColor),
              ),
              const SizedBox(height: 16),
              Text(
                'CRM Supabase is not configured. Please verify environment variables before sending messages.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink, fontSize: 14.5, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required int step,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _hairline),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: BrandColors.unityBlue.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepBadge(step),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: _inkMuted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStepBadge(int step) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _isDarkMode
            ? BrandColors.momentumBlue.withOpacity(0.28)
            : BrandColors.unityBlue,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildNoteStrip({
    required IconData icon,
    required Color accent,
    required String text,
  }) {
    final iconColor =
        _isDarkMode ? accent : Color.lerp(accent, Colors.black, 0.35)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(_isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _ink, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _fieldFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: BrandColors.momentumBlue.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _accentIconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.unfold_more_rounded, size: 18, color: _inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportTile({
    required String label,
    required int count,
    required Color accent,
    required IconData icon,
  }) {
    final iconColor =
        _isDarkMode ? accent : Color.lerp(accent, Colors.black, 0.25)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(_isDarkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'via $label',
                  style: TextStyle(
                    color: _inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    final hasRecipients =
        _totalMessages > 0 || _selectedMembers.isNotEmpty || _filter.hasActiveFilters;

    // Display-only counters, derived locally from the composer text.
    final charCount = _messageController.text.length;
    final smsSegments = charCount == 0 ? 0 : ((charCount + 159) ~/ 160);

    return _buildSectionCard(
      step: 2,
      title: 'Message',
      subtitle: 'Each selected member receives this as an individual text.',
      children: [
        if (!hasRecipients) ...[
          _buildNoteStrip(
            icon: Icons.lock_outline_rounded,
            accent: BrandColors.momentumBlue,
            text:
                'Select recipients to enable composing. Once at least one member is chosen the message editor will unlock.',
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _messageController,
          maxLines: 5,
          maxLength: 500,
          enabled: hasRecipients,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: _ink, fontSize: 15, height: 1.45),
          decoration: _fieldDecoration(
            hint: 'Enter your message here...',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            charCount > 0
                ? '$charCount / 500 · ~$smsSegments SMS segment${smsSegments == 1 ? '' : 's'}'
                : '$charCount / 500',
            style: TextStyle(
              color: _inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._attachments.map(
              (file) => InputChip(
                label: Text(file.name),
                labelStyle: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                avatar: Icon(Icons.attachment, size: 18, color: _accentIconColor),
                backgroundColor: _fieldFill,
                shape: StadiumBorder(side: BorderSide(color: _hairline)),
                deleteIconColor: _inkMuted,
                onDeleted: () => _removeAttachment(file),
              ),
            ),
            OutlinedButton.icon(
              onPressed: hasRecipients ? _pickAttachments : null,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(_attachments.isEmpty
                  ? 'Add attachments'
                  : 'Add more attachments'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                disabledForegroundColor: _inkMuted.withOpacity(0.5),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                side: BorderSide(color: _hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipientsCard() {
    return _buildSectionCard(
      step: 1,
      title: 'Recipients',
      subtitle:
          'Choose a targeting strategy, then optionally add individual members to the list.',
      children: [
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
    );
  }

  Widget _buildModeChip(_RecipientMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    final Color background = selected
        ? BrandColors.unityBlue
        : (_isDarkMode ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F4F9));
    final Color borderColor = selected
        ? (_isDarkMode ? BrandColors.momentumBlue : BrandColors.unityBlue)
        : _hairline;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            _setMode(mode);
            _updatePreview();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : _inkMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    switch (_mode) {
      case _RecipientMode.allMembers:
        return _buildAllMembersInfo();
      case _RecipientMode.county:
        return _buildCountyDropdown();
      case _RecipientMode.district:
        return _buildDistrictSelector();
      case _RecipientMode.highSchool:
        return _buildHighSchoolSelector();
      case _RecipientMode.college:
        return _buildCollegeSelector();
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
    return _buildNoteStrip(
      icon: Icons.people_alt_outlined,
      accent: BrandColors.momentumBlue,
      text: 'Send to every contactable member currently visible in the directory. '
          'Members older than ${CRMConfig.maxVisibleMemberAge} are excluded automatically.',
    );
  }

  Widget _buildManualSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add individual members', style: _overlineStyle),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          style: TextStyle(color: _ink, fontSize: 15),
          decoration: _fieldDecoration(
            label: 'Search members by name or phone',
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
                        color: _inkMuted,
                      )
                    : Icon(Icons.search, color: _inkMuted)),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedMembers.isNotEmpty) ...[
          Text(
            'Selected members (${_selectedMembers.length})',
            style: _overlineStyle,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedMembers.map((member) {
              final introduced = member.introSentAt != null;
              final Color introducedIcon = _isDarkMode
                  ? BrandColors.sunriseGold
                  : const Color(0xFFB07D0A);
              return InputChip(
                label: Text(member.name),
                labelStyle: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: introduced ? FontWeight.w700 : FontWeight.w600,
                ),
                avatar: Icon(
                  introduced ? Icons.check_circle_outline : Icons.person_outline,
                  size: 18,
                  color: introduced ? introducedIcon : _accentIconColor,
                ),
                backgroundColor: introduced
                    ? BrandColors.sunriseGold.withOpacity(0.18)
                    : _fieldFill,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: introduced
                        ? BrandColors.sunriseGold.withOpacity(0.6)
                        : _hairline,
                  ),
                ),
                deleteIconColor: _inkMuted,
                tooltip: introduced
                    ? 'Intro sent ${_formatDate(member.introSentAt!)}'
                    : null,
                onDeleted: () => _toggleMemberSelection(member),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (_searchController.text.trim().length >= 2)
          _buildSearchResults()
        else
          Text(
            'Type at least 2 characters to search the member directory.',
            style: TextStyle(color: _inkMuted, fontSize: 13),
          ),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No matching members found.',
          style: TextStyle(color: _inkMuted, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: _searchResults.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (context, index) =>
            Divider(height: 1, thickness: 1, color: _hairline),
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
            minVerticalPadding: 10,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? _smsGreen.withOpacity(0.16)
                    : BrandColors.momentumBlue.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded, size: 18, color: _smsGreen)
                  : Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: _accentIconColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
            ),
            title: Text(
              member.name,
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
            subtitle: subtitleText == null
                ? null
                : Text(
                    subtitleText,
                    style: TextStyle(color: _inkMuted, fontSize: 12.5),
                  ),
            trailing: IconButton(
              tooltip: selected ? 'Remove from recipients' : 'Add to recipients',
              icon: Icon(
                selected ? Icons.remove_circle_outline : Icons.add_circle_outline,
                color: selected ? _inkMuted : _accentIconColor,
              ),
              onPressed: () => _toggleMemberSelection(member),
            ),
            onTap: () => _toggleMemberSelection(member),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) => _dateFormat.format(date);

  Widget _buildFiltersCard() {
    return _buildSectionCard(
      step: 3,
      title: 'Advanced Filters',
      subtitle: 'Optional limits applied on top of the targeting above.',
      children: [
        _buildAgeFields(),
        const SizedBox(height: 8),
        _buildFilterToggle(
          title: 'Exclude opted-out members',
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
        _buildFilterToggle(
          title: 'Exclude recently contacted (7 days)',
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
    );
  }

  Widget _buildFilterToggle({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(
          color: _ink,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor:
          _isDarkMode ? BrandColors.momentumBlue : BrandColors.unityBlue,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      decoration: _fieldDecoration(label: 'County'),
      dropdownColor: _cardColor,
      borderRadius: BorderRadius.circular(14),
      style: TextStyle(color: _ink, fontSize: 14.5),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _inkMuted),
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

  Widget _buildDistrictSelector() {
    final label = (_filter.congressionalDistricts == null || _filter.congressionalDistricts!.isEmpty)
        ? 'Select districts'
        : '${_filter.congressionalDistricts!.length} districts selected';

    return _buildPickerTile(
      icon: Icons.how_to_vote,
      label: label,
      onTap: () {
        final tempSelected = List<String>.from(_filter.congressionalDistricts ?? []);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Congressional Districts'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setDialogState) => ListView(
                  shrinkWrap: true,
                  children: _districts.map((district) {
                    final isSelected = tempSelected.contains(district);
                    return CheckboxListTile(
                      title: Text('District $district'),
                      value: isSelected,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            tempSelected.add(district);
                          } else {
                            tempSelected.remove(district);
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
                      tempSelected.isEmpty ? _RecipientMode.manual : _RecipientMode.district,
                      notify: false,
                    );
                    _filter = _filter.copyWithOverrides(
                      congressionalDistricts: tempSelected.isEmpty ? null : tempSelected,
                      clearCongressionalDistricts: tempSelected.isEmpty,
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

  Widget _buildHighSchoolSelector() {
    final label = _filter.anyHighSchool
        ? 'All High School Members'
        : (_filter.highSchools == null || _filter.highSchools!.isEmpty)
            ? 'Select high schools'
            : '${_filter.highSchools!.length} high schools selected';

    return _buildPickerTile(
      icon: Icons.school,
      label: label,
      onTap: () {
        var tempAnyHighSchool = _filter.anyHighSchool;
        final tempSelected = List<String>.from(_filter.highSchools ?? []);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select High Schools'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  // Header (all-of row + divider) counts as 2 leading items;
                  // items map 1:1 to _highSchools after that.
                  const headerCount = 2;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: headerCount + _highSchools.length,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return CheckboxListTile(
                          title: const Text('All High School Members'),
                          subtitle: const Text('Any member with a high school listed'),
                          value: tempAnyHighSchool,
                          onChanged: (checked) {
                            setDialogState(() {
                              tempAnyHighSchool = checked == true;
                              if (tempAnyHighSchool) {
                                tempSelected.clear();
                              }
                            });
                          },
                        );
                      }
                      if (index == 1) return const Divider();
                      final school = _highSchools[index - headerCount];
                      final isSelected = tempSelected.contains(school);
                      return CheckboxListTile(
                        title: Text(school),
                        value: isSelected,
                        enabled: !tempAnyHighSchool,
                        onChanged: tempAnyHighSchool
                            ? null
                            : (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    tempSelected.add(school);
                                  } else {
                                    tempSelected.remove(school);
                                  }
                                });
                              },
                      );
                    },
                  );
                },
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
                    final hasFilter = tempAnyHighSchool || tempSelected.isNotEmpty;
                    _setMode(
                      hasFilter ? _RecipientMode.highSchool : _RecipientMode.manual,
                      notify: false,
                    );
                    _filter = _filter.copyWithOverrides(
                      anyHighSchool: tempAnyHighSchool,
                      highSchools: tempSelected.isEmpty ? null : tempSelected,
                      clearHighSchools: tempSelected.isEmpty && !tempAnyHighSchool,
                      clearColleges: true,
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

  Widget _buildCollegeSelector() {
    final label = (_filter.colleges == null || _filter.colleges!.isEmpty)
        ? 'Select colleges'
        : '${_filter.colleges!.length} colleges selected';

    return _buildPickerTile(
      icon: Icons.account_balance,
      label: label,
      onTap: () {
        final tempSelected = List<String>.from(_filter.colleges ?? []);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Colleges'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setDialogState) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: _colleges.length,
                  itemBuilder: (context, index) {
                    final college = _colleges[index];
                    final isSelected = tempSelected.contains(college);
                    return CheckboxListTile(
                      title: Text(college),
                      value: isSelected,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            tempSelected.add(college);
                          } else {
                            tempSelected.remove(college);
                          }
                        });
                      },
                    );
                  },
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
                      tempSelected.isEmpty ? _RecipientMode.manual : _RecipientMode.college,
                      notify: false,
                    );
                    _filter = _filter.copyWithOverrides(
                      colleges: tempSelected.isEmpty ? null : tempSelected,
                      clearColleges: tempSelected.isEmpty,
                      clearHighSchools: true,
                      anyHighSchool: false,
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

  Widget _buildChapterDropdown() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Chapters')),
      ..._chapters.map(
        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: _filter.chapterName,
      decoration: _fieldDecoration(label: 'Chapter'),
      dropdownColor: _cardColor,
      borderRadius: BorderRadius.circular(14),
      style: TextStyle(color: _ink, fontSize: 14.5),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _inkMuted),
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
      decoration: _fieldDecoration(label: 'Chapter Membership Status'),
      dropdownColor: _cardColor,
      borderRadius: BorderRadius.circular(14),
      style: TextStyle(color: _ink, fontSize: 14.5),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _inkMuted),
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
            style: TextStyle(color: _ink, fontSize: 14.5),
            decoration: _fieldDecoration(label: 'Min Age'),
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
            style: TextStyle(color: _ink, fontSize: 14.5),
            decoration: _fieldDecoration(label: 'Max Age'),
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
    final label = _filter.committees == null || _filter.committees!.isEmpty
        ? 'Select committees'
        : '${_filter.committees!.length} committees selected';

    return _buildPickerTile(
      icon: Icons.group,
      label: label,
      onTap: () {
        final tempSelected = List<String>.from(_filter.committees ?? []);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Committees'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setDialogState) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: _committees.length,
                  itemBuilder: (context, index) {
                    final committee = _committees[index];
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
                  },
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
    return _buildSectionCard(
      step: 4,
      title: 'Preview',
      subtitle: 'Confirm the audience before anything is sent.',
      children: [
        if (_loadingPreview)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Counting recipients...',
                    style: TextStyle(color: _inkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_totalMessages',
                style: TextStyle(
                  color: _ink,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    _totalMessages == 1
                        ? 'member will receive this message'
                        : 'members will receive this message',
                    style: TextStyle(
                      color: _inkMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_transportPreview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (final entry in _transportPreview.entries)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _buildTransportTile(
                        label: entry.key == 'SMS' ? 'SMS' : 'iMessage',
                        count: entry.value,
                        accent: entry.key == 'SMS'
                            ? _smsGreen
                            : BrandColors.momentumBlue,
                        icon: entry.key == 'SMS'
                            ? Icons.sms_outlined
                            : Icons.chat_bubble_outline_rounded,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Attachments: ${_attachments.length}',
              style: TextStyle(
                color: _ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (smsCount > 0) ...[
              const SizedBox(height: 8),
              _buildNoteStrip(
                icon: Icons.attach_file_rounded,
                accent: BrandColors.momentumBlue,
                text:
                    '$smsCount SMS recipient(s) may receive attachments as MMS when available.',
              ),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.filter_alt_outlined, size: 16, color: _inkMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _filter.description,
                  style: TextStyle(color: _inkMuted, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          if (_alreadyIntroducedPreview > 0) ...[
            const SizedBox(height: 10),
            _buildNoteStrip(
              icon: Icons.history_rounded,
              accent: BrandColors.sunriseGold,
              text:
                  '$_alreadyIntroducedPreview recipient(s) already received the intro message and will be skipped for "Send Intro".',
            ),
          ],
          if (_selectedMembers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Manually selected: ${_selectedMembers.length}',
              style: TextStyle(color: _inkMuted, fontSize: 13),
            ),
          ],
          if (_previewMembers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('First 5 recipients:', style: _overlineStyle),
            const SizedBox(height: 8),
            ..._previewMembers.map(_buildPreviewMemberRow),
          ],
        ],
      ],
    );
  }

  Widget _buildPreviewMemberRow(Member m) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: BrandColors.momentumBlue.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _accentIconColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (info.isNotEmpty)
                  Text(
                    info.join(' — '),
                    style: TextStyle(color: _inkMuted, fontSize: 12, height: 1.3),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (!_crmReady) {
      return const SizedBox.shrink();
    }

    final introEligible = (_totalMessages - _alreadyIntroducedPreview).clamp(0, _totalMessages);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: _hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.35 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: _sending
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _totalMessages > 0 ? _currentProgress / _totalMessages : 0,
                            minHeight: 8,
                            backgroundColor: _hairline,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                BrandColors.momentumBlue),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sending $_currentProgress of $_totalMessages...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: Text(introEligible > 0 ? 'Send Intro ($introEligible)' : 'Send Intro'),
                            onPressed: introEligible == 0 ? null : _sendIntroMessages,
                            style: _secondaryButtonStyle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text('Send to $_totalMessages Members'),
                            onPressed: _messageController.text.trim().isEmpty || _totalMessages == 0
                                ? null
                                : _sendMessages,
                            style: _primaryButtonStyle,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
