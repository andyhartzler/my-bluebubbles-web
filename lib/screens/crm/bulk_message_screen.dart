import 'dart:async';
import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/bulk_send_result.dart';
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

/// Which of the two send actions is in flight, so the progress bar can name it.
enum _SendKind { none, custom, intro }

/// Why a member the operator asked for will not be texted. Ordered by the
/// sequence the send path applies them, so a member is only ever reported
/// under the first reason that stops them.
enum _SkipReason { recentlyContacted, optedOut, noPhone, notEligible }

/// The encoding a message body forces the carrier to use.
enum _SmsEncoding { gsm7, ucs2 }

/// Per-recipient cost of one message body.
///
/// Segment maths is the part operators get wrong: a single curly quote or
/// emoji drops the whole body from GSM-7 into UCS-2 and cuts the per-segment
/// budget from 160 characters to 70, so a message that looked like one text
/// silently becomes three.
@immutable
class _SmsCost {
  const _SmsCost({
    required this.encoding,
    required this.units,
    required this.segments,
    required this.perSegment,
    required this.forcedBy,
  });

  final _SmsEncoding encoding;

  /// Billable units: septets under GSM-7, UTF-16 code units under UCS-2.
  final int units;

  final int segments;

  /// Budget of the segment the body is currently being billed at.
  final int perSegment;

  /// The characters that forced UCS-2, in the order they appear. Empty under
  /// GSM-7.
  final List<String> forcedBy;

  int get remaining => (perSegment * segments) - units;

  bool get isUnicode => encoding == _SmsEncoding.ucs2;
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
  // What the last send in this session did. The composer does not close itself
  // on a send, so this is held until the exec leaves and is handed back then,
  // for a caller that awaits this route.
  BulkSendResult? _lastSendResult;
  _SendKind _sendKind = _SendKind.none;
  DateTime? _sendStartedAt;
  int _currentProgress = 0;
  int _totalMessages = 0;
  bool _crmReady = false;
  int _alreadyIntroducedPreview = 0;
  Map<String, int> _transportPreview = const {};
  final DateFormat _dateFormat = DateFormat.yMMMd();

  /// Members the filter matched but the send path will drop, counted by the
  /// first reason that stops each one.
  Map<_SkipReason, int> _filterSkips = const {};

  /// How many the filter alone reaches. The skip card divides against this
  /// rather than the audience total, which also carries hand-picked members.
  int _filterEligible = 0;

  /// False when the audience query returned fewer rows than the server said
  /// matched, which means it hit the row cap and every count on the card is
  /// short.
  bool _skipsExact = true;

  /// True when the breakdown query failed, so the card says nothing rather
  /// than showing zeroes that look like a clean audience.
  bool _skipsUnavailable = false;

  /// Members added by hand that the send path will drop anyway.
  final List<Member> _manualSkips = [];

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
    _messageController.addListener(_onMessageChanged);
    if (_crmReady) {
      _loadFilterOptions();
      _updatePreview();
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onMessageChanged() {
    // The segment counter and the recipient preview both read the composer, so
    // every keystroke has to repaint them.
    setState(() {});
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
        _filterSkips = const {};
        _filterEligible = 0;
        _skipsExact = true;
        _skipsUnavailable = false;
        _manualSkips.clear();
      });
      return;
    }

    setState(() => _loadingPreview = true);

    try {
      final Map<String, Member> combined = LinkedHashMap<String, Member>();
      final Map<String, Member> manualSkipped = LinkedHashMap<String, Member>();

      void addMember(Member member, {bool manual = false}) {
        final key = _memberKey(member);
        if (key == null) return;
        if (!member.canContact) {
          // Manual picks are the only skips worth naming one by one: the
          // operator chose these people, so a silent drop reads as a bug.
          if (manual) manualSkipped[key] = member;
          return;
        }
        combined[key] = member;
      }

      var filterEligible = 0;
      final skipCounts = <_SkipReason, int>{};
      var skipsExact = true;
      var skipsUnavailable = false;

      if (hasFilters) {
        // One query serves both the audience and the skip breakdown. Ask for
        // everything the filter matches WITHOUT the contactability constraint,
        // then classify each row once: the rows _skipReasonFor leaves
        // unclassified are exactly the rows the send path keeps, so the two
        // numbers cannot drift apart the way two separate queries could.
        try {
          final matched = await _memberRepo.getAllMembers(
            county: activeFilter.county,
            congressionalDistricts: activeFilter.congressionalDistricts,
            committees: activeFilter.committees,
            highSchools: activeFilter.highSchools,
            colleges: activeFilter.colleges,
            anyHighSchool: activeFilter.anyHighSchool,
            chapterName: activeFilter.chapterName,
            chapterStatus: activeFilter.chapterStatus,
            minAge: activeFilter.minAge,
            maxAge: activeFilter.maxAge,
            fetchTotalCount: true,
          );

          for (final member in matched.members) {
            final reason = _skipReasonFor(member, activeFilter);
            if (reason == null) {
              filterEligible++;
              addMember(member);
            } else {
              skipCounts[reason] = (skipCounts[reason] ?? 0) + 1;
            }
          }
          // The audience and the breakdown now come off the same rows, so the
          // old two-query disagreement is gone. What can still bite is the
          // PostgREST row cap: when the server counted more matches than it
          // handed back, every number on the card is short and it has to say
          // so rather than presenting a total that will not send.
          final matchedCount = matched.totalCount;
          skipsExact =
              matchedCount == null || matched.members.length >= matchedCount;
        } catch (e) {
          debugPrint('❌ Error loading the filtered audience: $e');
          skipsUnavailable = true;
        }
      }

      for (final member in _selectedMembers) {
        addMember(member, manual: true);
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
        _filterSkips = skipCounts;
        _filterEligible = filterEligible;
        _skipsExact = skipsExact;
        _skipsUnavailable = skipsUnavailable;
        _manualSkips
          ..clear()
          ..addAll(manualSkipped.values);
        _loadingPreview = false;
      });
    } catch (e) {
      debugPrint('❌ Error updating preview: $e');
      if (!mounted) return;
      setState(() => _loadingPreview = false);
    }
  }

  /// The first reason the send path would drop [member], mirroring the order
  /// CRMMessageService applies: the recent-contact window first, then the
  /// contactability rule the Member model owns.
  _SkipReason? _skipReasonFor(Member member, MessageFilter filter) {
    if (filter.excludeRecentlyContacted) {
      final threshold = DateTime.now().subtract(
        filter.recentContactThreshold ?? const Duration(days: 7),
      );
      if (member.lastContacted != null && !member.lastContacted!.isBefore(threshold)) {
        return _SkipReason.recentlyContacted;
      }
    }
    return _contactSkipReason(member);
  }

  /// Member owns the contactability rule; this only names its verdict for the
  /// card. Hand-picked members are only ever dropped by that rule: the recency
  /// window belongs to the filter and never touches an explicit pick.
  static _SkipReason? _contactSkipReason(Member member) =>
      switch (member.contactBlocker) {
        null => null,
        ContactBlocker.optedOut => _SkipReason.optedOut,
        ContactBlocker.noPhone => _SkipReason.noPhone,
        ContactBlocker.notEligible => _SkipReason.notEligible,
      };

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
    // member.id is non-nullable, so it always wins. Kept as the single key
    // source rather than a chain that reads as if a fallback were reachable.
    return member.id;
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
      _showSnack('Please enter a message');
      return;
    }

    if (_totalMessages == 0) {
      _showSnack('No members match the filter');
      return;
    }

    final cost = _messageCost;
    final confirmed = await _showBrandedConfirm(
      icon: Icons.send_rounded,
      title: 'Send this message?',
      lines: [
        '$_totalMessages ${_totalMessages == 1 ? 'member' : 'members'} will each receive an individual text.',
        '${cost.segments} SMS ${cost.segments == 1 ? 'segment' : 'segments'} per recipient, '
            '${cost.segments * _totalMessages} in total.',
        'Sent at ${CRMMessageService.messagesPerMinute} per minute, about '
            '${_formatDuration(_estimatedSendDuration(_totalMessages))} from now.',
      ],
      confirmLabel: 'Send',
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _sendKind = _SendKind.custom;
      _sendStartedAt = DateTime.now();
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
      setState(() {
        _sending = false;
        _sendKind = _SendKind.none;
        _sendStartedAt = null;
      });

      // The composer stays open after a send. The per-member outcome is held
      // here and handed back if the exec closes the screen, so a caller that
      // awaits this route still learns what happened, and the exec decides
      // when the composing is over.
      _lastSendResult = BulkSendResult.sms(results);

      await _showBrandedNotice(
        icon: Icons.check_circle_outline_rounded,
        title: 'Bulk message complete',
        lines: ['Successfully sent $successCount of $_totalMessages messages.'],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendKind = _SendKind.none;
        _sendStartedAt = null;
      });
      _showSnack('Error sending messages: $e');
    }
  }

  Future<void> _sendIntroMessages() async {
    final eligibleTotal = _totalMessages - _alreadyIntroducedPreview;
    if (eligibleTotal <= 0) {
      _showSnack('No eligible members to receive the intro message');
      return;
    }

    final manualEligible =
        _selectedMembers.where((member) => member.introSentAt == null).toList();
    final manualSkipped = _selectedMembers.length - manualEligible.length;

    final confirmed = await _showBrandedConfirm(
      icon: Icons.auto_awesome_rounded,
      title: 'Send the intro message?',
      lines: [
        'The standard Missouri Young Democrats intro goes to $eligibleTotal '
            '${eligibleTotal == 1 ? 'member' : 'members'}, with the contact card attached.',
        'This does NOT send what you typed in the composer.',
        'Sent at ${CRMMessageService.messagesPerMinute} per minute, about '
            '${_formatDuration(_estimatedSendDuration(eligibleTotal))} from now.',
      ],
      confirmLabel: 'Send intro',
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _sendKind = _SendKind.intro;
      _sendStartedAt = DateTime.now();
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
      setState(() {
        _sending = false;
        _sendKind = _SendKind.none;
        _sendStartedAt = null;
      });

      _showBrandedNotice(
        icon: Icons.check_circle_outline_rounded,
        title: 'Intro messages sent',
        lines: [
          'Successfully sent intro to $successCount of $eligibleTotal members.',
          if (manualSkipped > 0)
            'Skipped $manualSkipped hand-picked ${manualSkipped == 1 ? 'member' : 'members'} '
                'who already received the intro message.',
        ],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendKind = _SendKind.none;
        _sendStartedAt = null;
      });
      _showSnack('Error sending intro messages: $e');
    }
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

  // ─────────────────────────── SMS cost ───────────────────────────
  // GSM 03.38 default alphabet. Anything outside it, and outside the escape
  // table below, forces the whole body to UCS-2.

  static const String _gsm7Base =
      '@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !"#¤%&\'()*+,-./0123456789:;<=>?'
      '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§'
      '¿abcdefghijklmnopqrstuvwxyzäöñüà';

  /// Escape-table characters. Each costs TWO septets rather than one.
  static const String _gsm7Extended = '\f^{}\\[~]|€';

  static final Set<int> _gsm7BaseRunes = _gsm7Base.runes.toSet();
  static final Set<int> _gsm7ExtendedRunes = _gsm7Extended.runes.toSet();

  _SmsCost get _messageCost => _computeSmsCost(_messageController.text);

  /// Segment maths for one body.
  ///
  /// Deliberately ignores one refinement: an escape-table character may not
  /// straddle a segment boundary, so a body packed with `{` or `€` can spill
  /// one septet earlier than this reports. That costs at most one extra
  /// segment on a body that is already at the boundary, and modelling it would
  /// hide the thing operators actually need to see, which is the GSM-7 to
  /// UCS-2 cliff.
  static _SmsCost _computeSmsCost(String text) {
    if (text.isEmpty) {
      return const _SmsCost(
        encoding: _SmsEncoding.gsm7,
        units: 0,
        segments: 0,
        perSegment: 160,
        forcedBy: <String>[],
      );
    }

    var septets = 0;
    final forcedBy = <String>[];
    for (final rune in text.runes) {
      if (_gsm7BaseRunes.contains(rune)) {
        septets += 1;
      } else if (_gsm7ExtendedRunes.contains(rune)) {
        septets += 2;
      } else {
        final ch = String.fromCharCode(rune);
        if (!forcedBy.contains(ch)) forcedBy.add(ch);
      }
    }

    if (forcedBy.isEmpty) {
      final perSegment = septets <= 160 ? 160 : 153;
      final segments = septets <= 160 ? 1 : (septets / 153).ceil();
      return _SmsCost(
        encoding: _SmsEncoding.gsm7,
        units: septets,
        segments: segments,
        perSegment: perSegment,
        forcedBy: const <String>[],
      );
    }

    // UCS-2 bills UTF-16 code units, which is exactly what Dart's String
    // length counts, so an emoji outside the BMP correctly costs two.
    final units = text.length;
    final perSegment = units <= 70 ? 70 : 67;
    final segments = units <= 70 ? 1 : (units / 67).ceil();
    return _SmsCost(
      encoding: _SmsEncoding.ucs2,
      units: units,
      segments: segments,
      perSegment: perSegment,
      forcedBy: forcedBy,
    );
  }

  Duration _estimatedSendDuration(int recipients) {
    if (recipients <= 1) return Duration.zero;
    return CRMConfig.messageDelay * (recipients - 1);
  }

  static String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes < 60) {
      return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
    }
    final hours = d.inHours;
    final remMinutes = minutes % 60;
    return remMinutes == 0 ? '${hours}h' : '${hours}h ${remMinutes}m';
  }

  String _formatDate(DateTime date) => _dateFormat.format(date);

  // ───────────────────── Presentation ─────────────────────
  // Every surface on this screen sits on the navy-to-blue brand gradient, so
  // colours are fixed rather than theme-derived: white for primary text,
  // white70 for supporting copy, white60 for footnotes.

  static const Color _onGradient = Colors.white;
  static const Color _muted = Colors.white70;

  /// Disabled fill and ink for the filled buttons that sit on the brand
  /// gradient. A translucent WHITE fill is not usable here: the gradient runs
  /// navy to momentum blue, and the buttons sit at the momentum end, where a
  /// white veil leaves a light surface that neither navy nor dimmed white ink
  /// can hold contrast against. Veiling with navy instead darkens every point
  /// on the band, so white70 measures 7.0:1 at the navy end and 4.7:1 at the
  /// momentum end.
  static final Color _disabledFill = BrandColors.unityBlue.withValues(alpha: 0.7);
  static const Color _disabledInk = Colors.white70;
  static const Color _faint = Colors.white60;
  static const Color _smsGreen = Color(0xFF43A047);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.unityBlue,
      body: BrandedBackground(
        child: SizedBox.expand(
          child: Column(
            children: [
              _buildHeaderBand(),
              Expanded(
                child: _crmReady ? _buildBody() : _buildCrmNotReadyState(),
              ),
              if (_crmReady) _buildSendBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTile(IconData icon, {double pad = 10, double size = 22}) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(pad + 2),
      ),
      child: Icon(icon, color: _onGradient, size: size),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconTile(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: BrandTextStyles.title),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Inset panel used for wells, previews and grouped rows.
  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _noteStrip({
    required IconData icon,
    required String text,
    Color accent = BrandColors.sunriseGold,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _onGradient,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      counterText: '',
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.15),
      labelStyle: const TextStyle(color: _muted, fontSize: 13.5),
      floatingLabelStyle: const TextStyle(color: _onGradient, fontSize: 13.5),
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(Colors.white.withValues(alpha: 0.25)),
      disabledBorder: border(Colors.white.withValues(alpha: 0.12)),
      focusedBorder: border(BrandColors.sunriseGold, 1.6),
      border: border(Colors.white.withValues(alpha: 0.25)),
    );
  }

  Widget _buildHeaderBand() {
    final recipientLabel =
        _totalMessages == 1 ? '1 recipient' : '$_totalMessages recipients';
    return Container(
      decoration: BoxDecoration(gradient: BrandColors.getTileGradient()),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On a phone the labelled refresh button crowds the title out of
              // its own row, so it collapses to the icon alone.
              final compact = constraints.maxWidth < 640;
              return Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(_lastSendResult),
                    icon: const Icon(Icons.arrow_back_rounded, color: _onGradient),
                    tooltip: 'Back',
                  ),
                  _iconTile(Icons.sms_rounded, pad: 12, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Message',
                          style: BrandTextStyles.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _crmReady
                              ? 'Individual texts, one per member. $recipientLabel selected.'
                              : 'CRM connection unavailable.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (_crmReady) ...[
                    const SizedBox(width: 12),
                    _buildRefreshButton(compact: compact),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton({required bool compact}) {
    final busy = _loadingPreview;
    // The spinner only ever shows while the button is disabled, so it is
    // coloured for the disabled surface, not the gold enabled one.
    final icon = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          )
        : const Icon(Icons.refresh_rounded, size: 18);
    final style = ElevatedButton.styleFrom(
      backgroundColor: BrandColors.sunriseGold,
      foregroundColor: BrandColors.unityBlue,
      disabledBackgroundColor: _disabledFill,
      disabledForegroundColor: _disabledInk,
      elevation: 0,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    );
    final onPressed = busy || _sending ? null : _updatePreview;

    if (compact) {
      return Tooltip(
        message: 'Refresh the audience',
        child: ElevatedButton(
          onPressed: onPressed,
          style: style,
          child: icon,
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: const Text('Refresh'),
      style: style,
    );
  }

  Widget _buildCrmNotReadyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: BrandedCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 36,
                    color: _onGradient,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CRM Supabase is not configured',
                  style: BrandTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verify the environment variables before sending messages. '
                  'Nothing on this screen can reach members until it connects.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 13.5, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below this the two panes stop being readable side by side and the
        // composer gets too narrow to judge a message in.
        final wide = constraints.maxWidth >= 1000;

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAudienceStats(),
              const SizedBox(height: 24),
              _buildComposerCard(),
              const SizedBox(height: 24),
              _buildDevicePreviewCard(),
              const SizedBox(height: 24),
              _buildAudienceCard(),
              const SizedBox(height: 24),
              _buildExclusionsCard(),
              const SizedBox(height: 24),
              _buildRecipientsCard(),
              const SizedBox(height: 24),
              _buildFiltersCard(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                children: [
                  _buildComposerCard(),
                  const SizedBox(height: 24),
                  _buildDevicePreviewCard(),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                children: [
                  _buildAudienceStats(),
                  const SizedBox(height: 24),
                  _buildAudienceCard(),
                  const SizedBox(height: 24),
                  _buildExclusionsCard(),
                  const SizedBox(height: 24),
                  _buildRecipientsCard(),
                  const SizedBox(height: 24),
                  _buildFiltersCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _hasRecipients =>
      _totalMessages > 0 || _selectedMembers.isNotEmpty || _filter.hasActiveFilters;

  Widget _buildComposerCard() {
    final canEdit = _hasRecipients && !_sending;
    final cost = _messageCost;

    return _sectionCard(
      icon: Icons.edit_note_rounded,
      title: 'Message',
      subtitle: 'Each member receives this on its own, not as a group text.',
      children: [
        if (!_hasRecipients) ...[
          _noteStrip(
            icon: Icons.lock_outline_rounded,
            accent: BrandColors.sunriseGold,
            text: 'Choose recipients first. The composer unlocks as soon as at '
                'least one member is in the audience.',
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _messageController,
          maxLines: 6,
          maxLength: 500,
          enabled: canEdit,
          cursorColor: BrandColors.sunriseGold,
          style: const TextStyle(
            color: _onGradient,
            fontSize: 15,
            height: 1.45,
          ),
          decoration: _fieldDecoration(hint: 'Type the message members will receive...'),
        ),
        const SizedBox(height: 12),
        _buildCostBar(cost),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._attachments.map(_buildAttachmentChip),
            OutlinedButton.icon(
              onPressed: canEdit ? _pickAttachments : null,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(_attachments.isEmpty ? 'Add attachments' : 'Add more'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _onGradient,
                disabledForegroundColor: Colors.white38,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                side: const BorderSide(color: _muted),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentChip(PlatformFile file) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attachment_rounded, size: 16, color: _onGradient),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              file.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _onGradient,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _sending ? null : () => _removeAttachment(file),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: _muted,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            tooltip: 'Remove attachment',
          ),
        ],
      ),
    );
  }

  /// The segment counter. Operators are billed and rate limited per SEGMENT,
  /// not per message, so this reports the encoding, the budget it implies and
  /// the total that will actually leave the queue.
  Widget _buildCostBar(_SmsCost cost) {
    final budget = cost.perSegment * (cost.segments == 0 ? 1 : cost.segments);
    final fraction =
        budget == 0 ? 0.0 : (cost.units / budget).clamp(0.0, 1.0).toDouble();
    final totalSegments = cost.segments * _totalMessages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cost.isUnicode
                    ? BrandColors.warning.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cost.isUnicode ? 'UNICODE' : 'GSM-7',
                style: TextStyle(
                  color: cost.isUnicode ? BrandColors.unityBlue : _onGradient,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${cost.units} / $budget characters',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              cost.segments == 0
                  ? 'No segments yet'
                  : '${cost.segments} ${cost.segments == 1 ? 'segment' : 'segments'} each',
              style: const TextStyle(
                color: _onGradient,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              cost.isUnicode ? BrandColors.warning : _onGradient,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cost.segments == 0
              ? 'A plain body fits 160 characters in one segment. One emoji or curly '
                  'quote drops that to 70.'
              : '${cost.remaining} left in this segment. '
                  '$totalSegments ${totalSegments == 1 ? 'segment' : 'segments'} will be sent '
                  'across $_totalMessages ${_totalMessages == 1 ? 'recipient' : 'recipients'}.',
          style: const TextStyle(color: _faint, fontSize: 11.5, height: 1.4),
        ),
        if (cost.isUnicode) ...[
          const SizedBox(height: 10),
          _noteStrip(
            icon: Icons.warning_amber_rounded,
            accent: BrandColors.warning,
            text: 'Unicode: ${_describeForcingCharacters(cost.forcedBy)} '
                'pushed this out of the GSM-7 alphabet, so every segment now carries '
                '70 characters instead of 160. Replacing those characters usually '
                'halves the send.',
          ),
        ],
      ],
    );
  }

  static String _describeForcingCharacters(List<String> chars) {
    final shown = chars.take(6).map((c) => '"$c"').join(', ');
    if (chars.length <= 6) return shown;
    return '$shown and ${chars.length - 6} more';
  }

  Widget _buildDevicePreviewCard() {
    final text = _messageController.text;
    final cost = _messageCost;
    final segments = text.isEmpty
        ? const <String>[]
        : _splitIntoSegments(text, cost.perSegment, cost.encoding);

    return _sectionCard(
      icon: Icons.phone_iphone_rounded,
      title: 'Recipient preview',
      subtitle: segments.length > 1
          ? 'A multi-segment message can arrive as separate texts. Each bubble is one segment.'
          : 'What one member sees on their phone.',
      children: [
        _panel(
          padding: const EdgeInsets.all(14),
          child: segments.isEmpty
              ? const Text(
                  'Nothing to preview yet.',
                  style: TextStyle(color: _faint, fontSize: 13),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < segments.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      if (segments.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 4),
                          child: Text(
                            'Segment ${i + 1} of ${segments.length}',
                            style: const TextStyle(color: _faint, fontSize: 10.5),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              segments[i],
                              style: const TextStyle(
                                color: _onGradient,
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _noteStrip(
            icon: Icons.attach_file_rounded,
            accent: BrandColors.sunriseGold,
            text: '${_attachments.length} ${_attachments.length == 1 ? 'attachment follows' : 'attachments follow'} '
                'the text. SMS recipients receive them as MMS where the carrier allows it.',
          ),
        ],
      ],
    );
  }

  /// Split a body the way the carrier will, so the preview shows real bubbles
  /// rather than one block of text pretending to be a single message.
  static List<String> _splitIntoSegments(
    String text,
    int perSegment,
    _SmsEncoding encoding,
  ) {
    final segments = <String>[];
    final buffer = StringBuffer();
    var used = 0;

    for (final rune in text.runes) {
      final cost = encoding == _SmsEncoding.gsm7
          ? (_gsm7ExtendedRunes.contains(rune) ? 2 : 1)
          : (rune > 0xFFFF ? 2 : 1);
      if (used + cost > perSegment) {
        segments.add(buffer.toString());
        buffer.clear();
        used = 0;
      }
      buffer.write(String.fromCharCode(rune));
      used += cost;
    }
    if (buffer.isNotEmpty) segments.add(buffer.toString());
    return segments;
  }

  Widget _buildAudienceStats() {
    final cost = _messageCost;
    final totalSegments = cost.segments * _totalMessages;
    return Row(
      children: [
        Expanded(
          child: BrandedStatCard(
            title: 'Recipients',
            value: '$_totalMessages',
            subtitle: _loadingPreview ? 'Recounting...' : 'one individual text each',
            icon: Icons.people_alt_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BrandedStatCard(
            title: 'Segments queued',
            value: '$totalSegments',
            subtitle: cost.segments == 0
                ? 'write a message to see the cost'
                : '${cost.segments} per recipient',
            icon: Icons.tag_rounded,
            gradientColors: BrandColors.tileGradientReversed,
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceCard() {
    final smsCount = _transportPreview['SMS'] ?? 0;

    return _sectionCard(
      icon: Icons.groups_2_rounded,
      title: 'Audience',
      subtitle: 'Who this send actually reaches.',
      children: [
        if (_loadingPreview)
          _panel(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Counting recipients...',
                  style: TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
            ),
          )
        else ...[
          if (_transportPreview.isNotEmpty) ...[
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
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.filter_alt_outlined, size: 16, color: _faint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _filter.description,
                  style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
          if (_selectedMembers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_selectedMembers.length} hand-picked '
              '${_selectedMembers.length == 1 ? 'member' : 'members'} included.',
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
          if (_attachments.isNotEmpty && smsCount > 0) ...[
            const SizedBox(height: 10),
            _noteStrip(
              icon: Icons.attach_file_rounded,
              accent: BrandColors.sunriseGold,
              text: '$smsCount SMS ${smsCount == 1 ? 'recipient' : 'recipients'} may receive '
                  'attachments as MMS when the carrier supports it.',
            ),
          ],
          if (_alreadyIntroducedPreview > 0) ...[
            const SizedBox(height: 10),
            _noteStrip(
              icon: Icons.history_rounded,
              accent: BrandColors.sunriseGold,
              text: '$_alreadyIntroducedPreview already received the intro message. '
                  'They still get a custom message, but Send Intro skips them.',
            ),
          ],
          if (_previewMembers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'FIRST FEW RECIPIENTS',
              style: TextStyle(
                color: _faint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            ..._previewMembers.map(_buildRecipientRow),
          ],
        ],
      ],
    );
  }

  Widget _buildTransportTile({
    required String label,
    required int count,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _onGradient),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: _onGradient,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  'via $label',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
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

  Widget _buildRecipientRow(Member member) {
    final details = <String>[
      if (member.phoneE164 != null)
        member.phoneE164!
      else if (member.phone != null)
        member.phone!,
      if (member.county != null) member.county!,
      if (member.congressionalDistrict != null)
        Member.formatDistrictLabel(member.congressionalDistrict) ??
            member.congressionalDistrict!,
    ].where((value) => value.trim().isNotEmpty).toList();

    return BrandedActivityFeedItem(
      primaryText: member.name,
      secondaryText: details.isEmpty ? 'No contact details on file' : details.join(' • '),
      tertiaryText: member.introSentAt != null
          ? 'Intro sent ${_formatDate(member.introSentAt!)}'
          : null,
      avatarInitials: member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
      showChevron: false,
    );
  }

  // ─────────────────────── Who gets skipped ───────────────────────

  static String _skipLabel(_SkipReason reason) {
    switch (reason) {
      case _SkipReason.recentlyContacted:
        return 'Contacted too recently';
      case _SkipReason.optedOut:
        return 'Opted out of texts';
      case _SkipReason.noPhone:
        return 'No phone number on file';
      case _SkipReason.notEligible:
        return 'Not membership eligible';
    }
  }

  static IconData _skipIcon(_SkipReason reason) {
    switch (reason) {
      case _SkipReason.recentlyContacted:
        return Icons.schedule_rounded;
      case _SkipReason.optedOut:
        return Icons.block_rounded;
      case _SkipReason.noPhone:
        return Icons.phone_disabled_rounded;
      case _SkipReason.notEligible:
        return Icons.person_off_rounded;
    }
  }

  Widget _buildExclusionsCard() {
    final totalSkipped =
        _filterSkips.values.fold<int>(0, (sum, value) => sum + value);
    final filtered = _filter.hasActiveFilters;
    final matched = _filterEligible + totalSkipped;

    return _sectionCard(
      icon: Icons.filter_alt_off_rounded,
      title: 'Not being texted',
      subtitle: filtered
          ? 'Members the filter matched that the send path will drop.'
          : 'Members you picked that the send path will drop.',
      children: [
        if (_skipsUnavailable)
          _noteStrip(
            icon: Icons.help_outline_rounded,
            accent: BrandColors.warning,
            text: 'The skip breakdown could not be loaded, so this card is showing '
                'nothing rather than a clean audience it cannot vouch for. Refresh to retry.',
          )
        else if (totalSkipped == 0 && _manualSkips.isEmpty)
          _noteStrip(
            icon: Icons.check_circle_outline_rounded,
            accent: BrandColors.success,
            text: filtered
                ? 'Nobody is being dropped. Every matched member is reachable.'
                : 'Nobody is being dropped. Every member you picked is reachable.',
          )
        else if (totalSkipped > 0) ...[
          Text(
            '$totalSkipped of $matched matched '
            '${matched == 1 ? 'member' : 'members'} will not receive this.',
            style: const TextStyle(
              color: _onGradient,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final reason in _SkipReason.values)
            if ((_filterSkips[reason] ?? 0) > 0) ...[
              _buildSkipRow(reason, _filterSkips[reason]!),
              const SizedBox(height: 8),
            ],
          if (!_skipsExact)
            _noteStrip(
              icon: Icons.warning_amber_rounded,
              accent: BrandColors.warning,
              text: 'The audience query hit the row cap, so it returned fewer members '
                  'than the filter matches. Treat these counts as approximate.',
            ),
        ],
        if (_manualSkips.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'HAND-PICKED BUT UNREACHABLE',
            style: TextStyle(
              color: _faint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          for (final member in _manualSkips)
            BrandedActivityFeedItem(
              primaryText: member.name,
              secondaryText: _skipLabel(
                _contactSkipReason(member) ?? _SkipReason.notEligible,
              ),
              leadingIcon: Icons.person_off_rounded,
              showChevron: false,
              trailing: IconButton(
                onPressed: _sending ? null : () => _toggleMemberSelection(member),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: _muted,
                tooltip: 'Remove from list',
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSkipRow(_SkipReason reason, int count) {
    return _panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_skipIcon(reason), size: 20, color: _onGradient),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _skipLabel(reason),
              style: const TextStyle(
                color: _onGradient,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: _onGradient,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Recipients ───────────────────────

  Widget _buildRecipientsCard() {
    return _sectionCard(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Recipients',
      subtitle: 'Pick a targeting strategy, then add individual members on top.',
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
        if (_mode != _RecipientMode.manual) ...[
          const SizedBox(height: 16),
          _buildModeSelector(),
        ],
        const SizedBox(height: 20),
        const Text(
          'ADD INDIVIDUAL MEMBERS',
          style: TextStyle(
            color: _faint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          cursorColor: BrandColors.sunriseGold,
          style: const TextStyle(color: _onGradient, fontSize: 15),
          decoration: _fieldDecoration(
            label: 'Search members by name or phone',
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : (_searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear_rounded),
                        color: _muted,
                        tooltip: 'Clear search',
                      )
                    : const Icon(Icons.search_rounded, color: _muted)),
          ),
        ),
        if (_selectedMembers.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'SELECTED (${_selectedMembers.length})',
            style: const TextStyle(
              color: _faint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedMembers.map(_buildSelectedChip).toList(),
          ),
        ],
        const SizedBox(height: 14),
        if (_searchController.text.trim().length >= 2)
          _buildSearchResults()
        else
          const Text(
            'Type at least 2 characters to search the member directory.',
            style: TextStyle(color: _faint, fontSize: 12.5),
          ),
      ],
    );
  }

  Widget _buildSelectedChip(Member member) {
    final introduced = member.introSentAt != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: introduced
            ? Border.all(color: BrandColors.sunriseGold.withValues(alpha: 0.7))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            introduced ? Icons.check_circle_outline_rounded : Icons.person_outline_rounded,
            size: 16,
            color: introduced ? BrandColors.sunriseGold : _onGradient,
          ),
          const SizedBox(width: 8),
          Text(
            member.name,
            style: const TextStyle(
              color: _onGradient,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: _sending ? null : () => _toggleMemberSelection(member),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: _muted,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            tooltip: introduced
                ? 'Intro sent ${_formatDate(member.introSentAt!)}. Remove from list.'
                : 'Remove from list',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return _panel(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _noteStrip(
        icon: Icons.search_off_rounded,
        accent: BrandColors.sunriseGold,
        text: 'No reachable members match that search. Opted-out members and members '
            'without a phone number are not offered here.',
      );
    }

    return Column(
      children: _searchResults.map((member) {
        final selected = _isMemberSelected(member);
        final details = <String>[
          if (member.phoneE164 != null)
            member.phoneE164!
          else if (member.phone != null)
            member.phone!,
          if (member.county != null) member.county!,
          if (member.congressionalDistrict != null)
            Member.formatDistrictLabel(member.congressionalDistrict) ??
                member.congressionalDistrict!,
        ].where((value) => value.trim().isNotEmpty).toList();

        return BrandedActivityFeedItem(
          primaryText: member.name,
          secondaryText: details.isEmpty ? 'No contact details on file' : details.join(' • '),
          tertiaryText: member.introSentAt != null
              ? 'Intro sent ${_formatDate(member.introSentAt!)}'
              : null,
          avatarInitials: member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          onTap: _sending ? null : () => _toggleMemberSelection(member),
          trailing: IconButton(
            onPressed: _sending ? null : () => _toggleMemberSelection(member),
            icon: Icon(
              selected ? Icons.remove_circle_outline : Icons.add_circle_outline,
              size: 20,
            ),
            color: selected ? BrandColors.sunriseGold : _onGradient,
            tooltip: selected ? 'Remove from recipients' : 'Add to recipients',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModeChip(_RecipientMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _sending
              ? null
              : () {
                  _setMode(mode);
                  _updatePreview();
                },
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: selected ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? BrandColors.sunriseGold : Colors.white.withValues(alpha: 0.2),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: selected ? _onGradient : _muted),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _onGradient : _muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
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
        return _noteStrip(
          icon: Icons.people_alt_outlined,
          accent: BrandColors.sunriseGold,
          text: 'Every contactable member currently visible in the directory. '
              'Members older than ${CRMConfig.maxVisibleMemberAge} are excluded automatically.',
        );
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

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _sending ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              _iconTile(icon, pad: 8, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _onGradient,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.unfold_more_rounded, size: 18, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandedDropdown({
    required String label,
    required String? value,
    required String allLabel,
    required List<String> options,
    required String Function(String) itemLabel,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _fieldDecoration(label: label),
      dropdownColor: BrandColors.unityBlue,
      borderRadius: BorderRadius.circular(10),
      style: const TextStyle(color: _onGradient, fontSize: 14.5),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        ...options.map(
          (option) => DropdownMenuItem<String?>(
            value: option,
            child: Text(itemLabel(option)),
          ),
        ),
      ],
      onChanged: _sending ? null : onChanged,
    );
  }

  Widget _buildCountyDropdown() {
    return _buildBrandedDropdown(
      label: 'County',
      value: _filter.county,
      allLabel: 'All Counties',
      options: _counties,
      itemLabel: (value) => value,
      onChanged: (value) {
        setState(() {
          _setMode(
            value == null ? _RecipientMode.manual : _RecipientMode.county,
            notify: false,
          );
          _filter = _filter.copyWithOverrides(
            county: value,
            clearCounty: value == null,
          );
        });
        _updatePreview();
      },
    );
  }

  Widget _buildChapterDropdown() {
    return _buildBrandedDropdown(
      label: 'Chapter',
      value: _filter.chapterName,
      allLabel: 'All Chapters',
      options: _chapters,
      itemLabel: (value) => value,
      onChanged: (value) {
        setState(() {
          _setMode(
            value == null ? _RecipientMode.manual : _RecipientMode.chapter,
            notify: false,
          );
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
    return _buildBrandedDropdown(
      label: 'Chapter Membership Status',
      value: _filter.chapterStatus,
      allLabel: 'All Chapter Statuses',
      options: _chapterStatuses,
      itemLabel: (value) => value,
      onChanged: (value) {
        setState(() {
          _setMode(
            value == null ? _RecipientMode.manual : _RecipientMode.chapterStatus,
            notify: false,
          );
          _filter = _filter.copyWithOverrides(
            chapterStatus: value,
            clearChapterStatus: value == null,
          );
        });
        _updatePreview();
      },
    );
  }

  // ─────────────────────── Branded dialogs ───────────────────────

  Future<T?> _showBrandedDialog<T>({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrandColors.unityBlue,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: _onGradient,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: _muted,
          fontSize: 14,
          height: 1.45,
        ),
        title: Text(title),
        content: content,
        actions: actions,
      ),
    );
  }

  Widget _dialogCancel() => TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(foregroundColor: _muted),
        child: const Text('Cancel'),
      );

  Widget _dialogConfirm(String label, VoidCallback onPressed) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.sunriseGold,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      );

  Widget _dialogCheck({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    final enabled = onChanged != null;
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? _onGradient : Colors.white38,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(color: _faint, fontSize: 12),
            ),
      value: value,
      onChanged: onChanged,
      activeColor: BrandColors.sunriseGold,
      checkColor: BrandColors.unityBlue,
      side: const BorderSide(color: _muted, width: 1.5),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Future<bool?> _showBrandedConfirm({
    required IconData icon,
    required String title,
    required List<String> lines,
    required String confirmLabel,
  }) {
    return _showBrandedDialog<bool>(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(icon, pad: 8, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lines.first,
                  style: const TextStyle(
                    color: _onGradient,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          for (final line in lines.skip(1)) ...[
            const SizedBox(height: 10),
            Text(line, style: const TextStyle(color: _muted, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
      actions: [
        _dialogCancel(),
        _dialogConfirm(confirmLabel, () => Navigator.pop(context, true)),
      ],
    );
  }

  Future<void> _showBrandedNotice({
    required IconData icon,
    required String title,
    required List<String> lines,
  }) {
    return _showBrandedDialog<void>(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(icon, pad: 8, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lines.first,
                  style: const TextStyle(
                    color: _onGradient,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          for (final line in lines.skip(1)) ...[
            const SizedBox(height: 10),
            Text(line, style: const TextStyle(color: _muted, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
      actions: [
        _dialogConfirm('Done', () => Navigator.pop(context)),
      ],
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: _onGradient)),
        backgroundColor: BrandColors.unityBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
        _showBrandedDialog<void>(
          title: 'Select Congressional Districts',
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setDialogState) => ListView(
                shrinkWrap: true,
                children: _districts.map((district) {
                  return _dialogCheck(
                    title: 'District $district',
                    value: tempSelected.contains(district),
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
            _dialogCancel(),
            _dialogConfirm('Apply', () {
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
            }),
          ],
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
        _showBrandedDialog<void>(
          title: 'Select High Schools',
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
                      return _dialogCheck(
                        title: 'All High School Members',
                        subtitle: 'Any member with a high school listed',
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
                    if (index == 1) {
                      return Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: Colors.white.withValues(alpha: 0.1),
                      );
                    }
                    final school = _highSchools[index - headerCount];
                    return _dialogCheck(
                      title: school,
                      value: tempSelected.contains(school),
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
            _dialogCancel(),
            _dialogConfirm('Apply', () {
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
            }),
          ],
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
        _showBrandedDialog<void>(
          title: 'Select Colleges',
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setDialogState) => ListView.builder(
                shrinkWrap: true,
                itemCount: _colleges.length,
                itemBuilder: (context, index) {
                  final college = _colleges[index];
                  return _dialogCheck(
                    title: college,
                    value: tempSelected.contains(college),
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
            _dialogCancel(),
            _dialogConfirm('Apply', () {
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
            }),
          ],
        );
      },
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
        _showBrandedDialog<void>(
          title: 'Select Committees',
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setDialogState) => ListView.builder(
                shrinkWrap: true,
                itemCount: _committees.length,
                itemBuilder: (context, index) {
                  final committee = _committees[index];
                  return _dialogCheck(
                    title: committee,
                    value: tempSelected.contains(committee),
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
            _dialogCancel(),
            _dialogConfirm('Apply', () {
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
            }),
          ],
        );
      },
    );
  }

  // ─────────────────────── Advanced filters ───────────────────────

  Widget _buildFiltersCard() {
    return _sectionCard(
      icon: Icons.tune_rounded,
      title: 'Advanced filters',
      subtitle: 'Optional limits applied on top of the targeting above.',
      children: [
        Row(
          children: [
            Expanded(child: _buildAgeField('Min Age', isMin: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildAgeField('Max Age', isMin: false)),
          ],
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 6),
        _noteStrip(
          icon: Icons.shield_outlined,
          accent: BrandColors.success,
          text: 'Opted-out members are never texted, whatever this toggle says. '
              'The send path drops them again on its own.',
        ),
      ],
    );
  }

  Widget _buildAgeField(String label, {required bool isMin}) {
    return TextField(
      enabled: !_sending,
      cursorColor: BrandColors.sunriseGold,
      style: const TextStyle(color: _onGradient, fontSize: 14.5),
      decoration: _fieldDecoration(label: label),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final age = int.tryParse(value);
        setState(() {
          _filter = isMin
              ? _filter.copyWithOverrides(minAge: age, clearMinAge: value.isEmpty)
              : _filter.copyWithOverrides(maxAge: age, clearMaxAge: value.isEmpty);
        });
        _updatePreview();
      },
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
        style: const TextStyle(
          color: _onGradient,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: _sending ? null : onChanged,
      activeColor: BrandColors.sunriseGold,
      checkColor: BrandColors.unityBlue,
      side: const BorderSide(color: _muted, width: 1.5),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ─────────────────────── Send bar ───────────────────────

  Widget _buildSendBar() {
    final introEligible =
        (_totalMessages - _alreadyIntroducedPreview).clamp(0, _totalMessages).toInt();
    final canSendCustom =
        _messageController.text.trim().isNotEmpty && _totalMessages > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: BrandColors.getTileGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: _sending ? _buildSendProgress() : _buildSendActions(introEligible, canSendCustom),
        ),
      ),
    );
  }

  Widget _buildSendActions(int introEligible, bool canSendCustom) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Send message delivers what you typed. Send intro delivers the standard '
          'Missouri Young Democrats intro with the contact card, and skips anyone who '
          'already received it.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  introEligible > 0 ? 'Send intro ($introEligible)' : 'Send intro',
                ),
                onPressed: introEligible == 0 ? null : _sendIntroMessages,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _onGradient,
                  disabledForegroundColor: Colors.white38,
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: _muted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _totalMessages > 0
                      ? 'Send message to $_totalMessages'
                      : 'Send message',
                ),
                onPressed: canSendCustom ? _sendMessages : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.sunriseGold,
                  foregroundColor: BrandColors.unityBlue,
                  disabledBackgroundColor: _disabledFill,
                  disabledForegroundColor: _disabledInk,
                  elevation: 0,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A long send is rate limited to one message every couple of seconds, so a
  /// bare spinner reads as a hang. Report the count, the share done and an
  /// honest estimate derived from the configured delay.
  Widget _buildSendProgress() {
    final total = _totalMessages == 0 ? 1 : _totalMessages;
    final fraction = (_currentProgress / total).clamp(0.0, 1.0).toDouble();
    final percent = (fraction * 100).round();
    final remaining =
        (_totalMessages - _currentProgress).clamp(0, _totalMessages).toInt();
    final elapsed = _sendStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_sendStartedAt!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _iconTile(
              _sendKind == _SendKind.intro
                  ? Icons.auto_awesome_rounded
                  : Icons.send_rounded,
              pad: 8,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _sendKind == _SendKind.intro
                    ? 'Sending the intro message'
                    : 'Sending your message',
                style: const TextStyle(
                  color: _onGradient,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                color: _onGradient,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(BrandColors.sunriseGold),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$_currentProgress of $_totalMessages sent · '
          '${_formatDuration(elapsed)} elapsed · about '
          '${_formatDuration(_estimatedSendDuration(remaining + 1))} left · '
          '${CRMMessageService.messagesPerMinute} per minute',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
