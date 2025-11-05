import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/meetings_screen.dart';
import 'package:bluebubbles/screens/crm/editors/member_edit_sheet.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SocialPlatform { instagram, tiktok, x }

/// Detailed view of a single member
class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({
    Key? key,
    required this.member,
  }) : super(key: key);

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final CRMMessageService _messageService = CRMMessageService();
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();
  late Member _member;
  final TextEditingController _notesController = TextEditingController();
  bool _editingNotes = false;
  bool _sendingIntro = false;
  bool _loadingAttendance = false;
  bool _hasLoadedAttendance = false;
  String? _attendanceError;
  List<MeetingAttendance> _meetingAttendance = [];

  bool get _crmReady => _supabaseService.isInitialized;

  static const Map<String, List<Color>> _sectionPalette = {
    'Contact Information': [Color(0xFF0052D4), Color(0xFF65C7F7)],
    'Chapter Involvement': [Color(0xFF11998e), Color(0xFF38ef7d)],
    'Social Profiles': [Color(0xFFee0979), Color(0xFFff6a00)],
    'Political & Civic': [Color(0xFF4776E6), Color(0xFF8E54E9)],
    'Education & Employment': [Color(0xFFf7971e), Color(0xFFffd200)],
    'Personal Details': [Color(0xFF654ea3), Color(0xFFeaafc8)],
    'Goals & Interests': [Color(0xFF36d1dc), Color(0xFF5b86e5)],
    'Engagement & Interests': [Color(0xFF36d1dc), Color(0xFF5b86e5)],
    'Notes & Engagement': [Color(0xFFb24592), Color(0xFFf15f79)],
    'Metadata': [Color(0xFF232526), Color(0xFF414345)],
    'CRM Metadata': [Color(0xFF232526), Color(0xFF414345)],
  };

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _notesController.text = _member.notes ?? '';
    _memberLookup.cacheMember(_member);
    if (_crmReady) {
      _hasLoadedAttendance = true;
      _loadMeetingAttendance();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    if (!_crmReady) return;

    try {
      await _memberRepo.updateNotes(_member.id, _notesController.text);
      if (!mounted) return;
      final updated = _member.copyWith(notes: _notesController.text);
      setState(() {
        _member = updated;
        _editingNotes = false;
      });
      _memberLookup.cacheMember(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e')),
      );
    }
  }

  Future<void> _toggleOptOut() async {
    if (!_crmReady) return;
    final newOptOutStatus = !_member.optOut;

    try {
      await _memberRepo.updateOptOutStatus(
        _member.id,
        newOptOutStatus,
        reason: newOptOutStatus ? 'Manually opted out' : null,
      );

      if (!mounted) return;
      final updated = _member.copyWith(
        optOut: newOptOutStatus,
        optOutDate: newOptOutStatus ? DateTime.now() : _member.optOutDate,
        optInDate: !newOptOutStatus ? DateTime.now() : _member.optInDate,
      );
      setState(() {
        _member = updated;
      });
      _memberLookup.cacheMember(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newOptOutStatus ? 'Member opted out' : 'Member opted in'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating opt-out status: $e')),
      );
    }
  }

  Future<void> _loadMeetingAttendance() async {
    if (!_crmReady) return;

    _hasLoadedAttendance = true;
    setState(() {
      _loadingAttendance = true;
      _attendanceError = null;
    });

    try {
      final attendance = await _meetingRepository.getAttendanceForMember(_member.id);
      if (!mounted) return;
      for (final record in attendance) {
        final member = record.member;
        if (member != null) {
          _memberLookup.cacheMember(member);
        }
      }
      setState(() {
        _meetingAttendance = attendance;
        _loadingAttendance = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attendanceError = 'Failed to load meeting attendance: $e';
        _loadingAttendance = false;
      });
    }
  }

  Future<void> _editMember() async {
    if (!_crmReady) return;

    final updated = await showModalBottomSheet<Member?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: MemberEditSheet(member: _member),
      ),
    );

    if (!mounted || updated == null) return;
    setState(() => _member = updated);
    _memberLookup.cacheMember(updated);
  }

  Future<void> _startChat({List<PlatformFile> attachments = const []}) async {
    final address = _cleanText(_member.phoneE164) ?? _cleanText(_member.phone);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    try {
      final normalized = address.contains('@') ? address : cleansePhoneNumber(address);
      final lookup = await _lookupServiceAvailability(normalized);
      final isIMessage = lookup ?? normalized.contains('@');
      await Navigator.of(context, rootNavigator: true).push(ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: ChatCreator(
            initialSelected: [
              SelectedContact(
                displayName: _member.name,
                address: normalized,
                isIMessage: isIMessage,
              ),
            ],
            initialAttachments: attachments,
            launchConversationOnSend: false,
            popOnSend: false,
            onMessageSent: (chat) async {
              await _memberRepo.updateLastContacted(_member.id);
              if (!mounted) return;
              final now = DateTime.now();
              final updated = _member.copyWith(lastContacted: now);
              setState(() {
                _member = updated;
              });
              _memberLookup.cacheMember(updated);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Message sent to ${_member.name}')),
              );
            },
          ),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open chat composer: $e')),
      );
    }
  }

  Future<void> _sendIntro() async {
    if (!_crmReady || !_member.canContact || _sendingIntro) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Intro Message'),
        content: const Text(
          'Send the Missouri Young Democrats intro message and contact card to this member?',
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

    setState(() => _sendingIntro = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool success = false;
    Object? error;
    try {
      success = await _messageService.sendIntroToMember(_member);
    } catch (e) {
      error = e;
    }

    if (!mounted) return;

    Navigator.of(context).pop();
    setState(() => _sendingIntro = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending intro: $error')),
      );
      return;
    }

    if (success) {
      final now = DateTime.now();
      final updated = _member.copyWith(introSentAt: now, lastContacted: now);
      setState(() {
        _member = updated;
      });
      _memberLookup.cacheMember(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intro message sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send intro message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_crmReady && !_hasLoadedAttendance) {
      _hasLoadedAttendance = true;
      _loadMeetingAttendance();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _member.canContact ? _startChat : null,
            tooltip: 'Start Chat',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _member.canContact && !_sendingIntro ? _sendIntro : null,
            tooltip: 'Send Intro Message',
          ),
        ],
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. View only mode.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : () {
              final phoneDisplay = _cleanText(_member.phone);
              final phoneE164 = _cleanText(_member.phoneE164);
              final primaryPhone = phoneDisplay ?? phoneE164;
              final phoneCopyValue = phoneE164 ?? phoneDisplay;
              final email = _cleanText(_member.email);
              final address = _cleanText(_member.address);
              final county = _cleanText(_member.county);
              final districtLabel = _formatDistrict(_member.congressionalDistrict);
              final committees = (_member.committee != null && _member.committee!.isNotEmpty)
                  ? _member.committeesString
                  : null;
              final notesValue = _cleanText(_member.notes);
              final chapterStatus = _cleanText(_member.currentChapterMember);
              final chapterName = _cleanText(_member.chapterName);
              final chapterPosition = _cleanText(_member.chapterPosition);
              final graduationYear = _cleanText(_member.graduationYear);
              final schoolEmail = _cleanText(_member.schoolEmail);
              final dateElected = _member.dateElected;
              final termExpiration = _member.termExpiration;
              final college = _cleanText(_member.college);
              final highSchool = _cleanText(_member.highSchool);
              final legacySchool =
                  (college == null && highSchool == null) ? _cleanText(_member.schoolName) : null;

              final sections = <Widget?>[
                _buildOptionalSection('Contact Information', [
                  _copyRow('Phone', primaryPhone, copyValue: phoneCopyValue),
                  _copyRow('Email', email),
                  _copyRow('School Email', schoolEmail),
                  _infoRowOrNull('Address', address),
                ]),
                _buildOptionalSection('Chapter Involvement', [
                  _infoRowOrNull('Current Chapter Member', chapterStatus),
                  _infoRowOrNull('Chapter Name', chapterName),
                  _infoRowOrNull('Chapter Position', chapterPosition),
                  if (dateElected != null)
                    _buildInfoRow('Date Elected', _formatDateOnly(dateElected)),
                  if (termExpiration != null)
                    _buildInfoRow('Term Expiration', _formatDateOnly(termExpiration)),
                  _infoRowOrNull('Graduation Year', graduationYear),
                ]),
                _buildOptionalSection('Social Profiles', [
                  _socialRow(_SocialPlatform.instagram, 'Instagram', _member.instagram),
                  _socialRow(_SocialPlatform.tiktok, 'TikTok', _member.tiktok),
                  _socialRow(_SocialPlatform.x, 'X (Twitter)', _member.x),
                ]),
                _buildOptionalSection('Political & Civic', [
                  _infoRowOrNull('County', county),
                  if (districtLabel != null) _buildInfoRow('Congressional District', districtLabel),
                  if (committees != null) _buildInfoRow('Committees', committees),
                  if (_member.registeredVoter != null)
                    _buildInfoRow('Registered Voter', _member.registeredVoter! ? 'Yes' : 'No'),
                  _infoRowOrNull('Political Experience', _member.politicalExperience),
                  _infoRowOrNull('Current Involvement', _member.currentInvolvement),
                ]),
                _buildOptionalSection('Education & Employment', [
                  _infoRowOrNull('Education Level', _member.educationLevel),
                  _infoRowOrNull('In School', _member.inSchool),
                  _infoRowOrNull('College', college),
                  _infoRowOrNull('High School', highSchool),
                  _infoRowOrNull('School (Legacy)', legacySchool),
                  _infoRowOrNull('Employed', _member.employed),
                  _infoRowOrNull('Industry', _member.industry),
                  _infoRowOrNull('Leadership Experience', _member.leadershipExperience),
                ]),
                _buildOptionalSection('Personal Details', [
                  if (_member.dateOfBirth != null)
                    _buildInfoRow('Date of Birth', _formatDateOnly(_member.dateOfBirth!)),
                  if (_member.age != null)
                    _buildInfoRow('Age', '${_member.age} years old'),
                  _infoRowOrNull('Pronouns', _member.preferredPronouns),
                  _infoRowOrNull('Gender Identity', _member.genderIdentity),
                  _infoRowOrNull('Race', _member.race),
                  _infoRowOrNull('Sexual Orientation', _member.sexualOrientation),
                  if (_member.hispanicLatino != null)
                    _buildInfoRow('Hispanic/Latino', _member.hispanicLatino! ? 'Yes' : 'No'),
                  _infoRowOrNull('Languages', _member.languages),
                  _infoRowOrNull('Community Type', _member.communityType),
                  _infoRowOrNull('Disability', _member.disability),
                  _infoRowOrNull('Religion', _member.religion),
                  _infoRowOrNull('Zodiac Sign', _member.zodiacSign),
                ]),
                _buildOptionalSection('Engagement & Interests', [
                  _infoRowOrNull('Desire to Lead', _member.desireToLead),
                  _infoRowOrNull('Hours per Week', _member.hoursPerWeek),
                  _infoRowOrNull('Why Join', _member.whyJoin),
                  _infoRowOrNull('Goals & Ambitions', _member.goalsAndAmbitions),
                  _infoRowOrNull('Qualified Experience', _member.qualifiedExperience),
                  _infoRowOrNull('Referral Source', _member.referralSource),
                  _infoRowOrNull('Passionate Issues', _member.passionateIssues),
                  _infoRowOrNull('Why Issues Matter', _member.whyIssuesMatter),
                  _infoRowOrNull('Areas of Interest', _member.areasOfInterest),
                  _infoRowOrNull('Accommodations', _member.accommodations),
                ]),
              ].whereType<Widget>().toList();

              final metadataSection = _buildOptionalSection('CRM Metadata', [
                _copyRow('Member ID', _member.id),
                if (_member.lastContacted != null)
                  _buildInfoRow('Last Contacted', _formatDate(_member.lastContacted!)),
                if (_member.introSentAt != null)
                  _buildInfoRow('Intro Sent', _formatDate(_member.introSentAt!)),
                if (_member.dateJoined != null)
                  _buildInfoRow('Date Joined', _formatDate(_member.dateJoined!)),
                if (_member.createdAt != null)
                  _buildInfoRow('Added to System', _formatDate(_member.createdAt!)),
                _infoRowOrNull('Opt-Out Reason', _member.optOutReason),
                if (_member.optOutDate != null)
                  _buildInfoRow('Opt-Out Date', _formatDateOnly(_member.optOutDate!)),
                if (_member.optInDate != null)
                  _buildInfoRow('Opt-In Date', _formatDateOnly(_member.optInDate!)),
              ]);

              final notesChildren = <Widget>[];
              if (!_editingNotes && notesValue == null) {
                notesChildren.add(TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add notes'),
                  onPressed: () => setState(() => _editingNotes = true),
                ));
              }
              if (!_editingNotes && notesValue != null) {
                notesChildren.add(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notesValue),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () => setState(() => _editingNotes = true),
                    ),
                  ],
                ));
              }
              if (_editingNotes) {
                notesChildren.add(Column(
                  children: [
                    TextField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Add notes about this member...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _notesController.text = _member.notes ?? '';
                            setState(() => _editingNotes = false);
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveNotes,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ));
              }
              final notesSection =
                  notesChildren.isEmpty ? null : _buildSection('Notes', notesChildren);

              final allSections = <Widget>[
                ...sections,
                if (notesSection != null) notesSection,
                if (metadataSection != null) metadataSection,
              ];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 768;
                  final listPadding = isWide
                      ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
                      : const EdgeInsets.all(16);
                  final chipsAlignment = isWide ? WrapAlignment.start : WrapAlignment.center;
                  final actionsAlignment = isWide ? WrapAlignment.start : WrapAlignment.center;

                  Widget? sectionLayout;
                  if (allSections.isNotEmpty) {
                    if (isWide) {
                      const double spacing = 24;
                      const double maxCardWidth = 420;
                      const double minCardWidth = 320;
                      final double availableWidth = constraints.maxWidth - listPadding.horizontal;
                      double cardWidth = maxCardWidth;
                      if (availableWidth < maxCardWidth * 2 + spacing) {
                        if (availableWidth >= minCardWidth * 2 + spacing) {
                          cardWidth = (availableWidth - spacing) / 2;
                        } else {
                          cardWidth = availableWidth;
                        }
                      }

                      sectionLayout = Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        alignment: WrapAlignment.start,
                        children: allSections
                            .map(
                              (section) => SizedBox(
                                width: cardWidth.clamp(minCardWidth, maxCardWidth).toDouble(),
                                child: section,
                              ),
                            )
                            .toList(),
                      );
                    } else {
                      sectionLayout = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < allSections.length; i++) ...[
                            allSections[i],
                            if (i != allSections.length - 1) const SizedBox(height: 24),
                          ],
                        ],
                      );
                    }
                  }

                  return ListView(
                    padding: listPadding,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          child: Text(
                            _member.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _member.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: chipsAlignment,
                        runAlignment: chipsAlignment,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (_member.lastContacted != null)
                            Chip(
                              avatar: const Icon(Icons.schedule_send, size: 18),
                              label: Text('Last contacted ${_formatDate(_member.lastContacted!)}'),
                            ),
                          if (_member.introSentAt != null)
                            Chip(
                              avatar: const Icon(Icons.auto_awesome, size: 18),
                              label: Text('Intro sent ${_formatDate(_member.introSentAt!)}'),
                            ),
                        ],
                      ),
                      if (_member.lastContacted != null || _member.introSentAt != null)
                        const SizedBox(height: 8),
                      if (_member.optOut)
                        Align(
                          alignment: isWide ? Alignment.centerLeft : Alignment.center,
                          child: const Chip(
                            label: Text('OPTED OUT'),
                            backgroundColor: Colors.red,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (_crmReady)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: actionsAlignment,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit Member'),
                                onPressed: _editMember,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      ..._buildMeetingAttendanceSection(),
                      if (_crmReady || sectionLayout != null)
                        const SizedBox(height: 24),
                      if (sectionLayout != null) ...[
                        sectionLayout,
                        const SizedBox(height: 24),
                      ],
                      ElevatedButton.icon(
                        icon: Icon(_member.optOut ? Icons.check_circle : Icons.block),
                        label: Text(_member.optOut ? 'Opt In' : 'Opt Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _member.optOut ? Colors.green : Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _crmReady ? _toggleOptOut : null,
                      ),
                    ],
                  );
                },
              );
            }(),
    );
  }

  String? _cleanText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<bool?> _lookupServiceAvailability(String address) async {
    try {
      final response = await http.handleiMessageState(address);
      final data = response.data['data'];
      if (data is Map<String, dynamic>) {
        final available = data['available'];
        if (available is bool) {
          return available;
        }
      }
    } catch (_) {}
    return null;
  }

  bool _hasText(String? value) => _cleanText(value) != null;

  String? _formatDistrict(String? value) => Member.formatDistrictLabel(value);

  Widget? _infoRowOrNull(String label, String? value, {Widget? trailing, Uri? link}) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;
    return _buildInfoRow(label, cleaned, trailing: trailing, link: link);
  }

  Widget? _copyRow(String label, String? value, {String? copyValue, Uri? link}) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;

    final toCopy = _cleanText(copyValue) ?? cleaned;
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.copy, size: 20),
        tooltip: 'Copy $label',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: toCopy));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label copied')),
          );
        },
      ),
      if (link != null)
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 20),
          tooltip: 'Open $label',
          onPressed: () => _openLink(link),
        ),
    ];

    return _buildInfoRow(
      label,
      cleaned,
      trailing: actions.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: actions,
            ),
      link: link,
    );
  }

  Widget? _socialRow(_SocialPlatform platform, String label, String? value) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;

    final uri = _resolveSocialLink(platform, cleaned);
    final display = _formatSocialDisplay(platform, cleaned, uri);
    final copyTarget = uri?.toString() ?? cleaned;

    return _copyRow(label, display, copyValue: copyTarget, link: uri);
  }

  Widget? _buildOptionalSection(String title, Iterable<Widget?> rows) {
    final visible = rows.whereType<Widget>().toList();
    if (visible.isEmpty) return null;
    return _buildSection(title, visible);
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = _sectionPalette[title];
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final surfaceColor = colorScheme.surface;
    final List<Color>? blendedPalette = palette?.map((color) {
      final double blendFactor = isDark ? 0.35 : 0.8;
      return Color.lerp(color, surfaceColor, blendFactor)!;
    }).toList();

    final Color baseBackground = blendedPalette != null && blendedPalette.isNotEmpty
        ? Color.lerp(blendedPalette.first, blendedPalette.last, 0.5) ?? surfaceColor
        : colorScheme.surfaceVariant.withOpacity(isDark ? 0.5 : 0.9);
    final Brightness backgroundBrightness = ThemeData.estimateBrightnessForColor(baseBackground);
    final Color effectiveColor = backgroundBrightness == Brightness.dark
        ? Colors.white
        : theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface;

    final BoxDecoration decoration = blendedPalette != null
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: blendedPalette,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 18),
              ),
            ],
          )
        : BoxDecoration(
            color: baseBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outline.withOpacity(isDark ? 0.4 : 0.25)),
          );

    final sectionTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(
        bodyColor: effectiveColor,
        displayColor: effectiveColor,
      ),
      iconTheme: theme.iconTheme.copyWith(color: effectiveColor),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: decoration,
          padding: const EdgeInsets.all(20),
          child: Theme(
            data: sectionTheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing, Uri? link}) {
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.75) ??
        theme.colorScheme.onSurface.withOpacity(0.65);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: labelColor,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w600,
          color: labelColor,
        );

    final baseValueStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final baseValueColor = baseValueStyle.color ?? theme.colorScheme.onSurface;
    final linkStyle = baseValueStyle.copyWith(
      color: baseValueColor,
      decoration: TextDecoration.underline,
      decorationColor: baseValueColor.withOpacity(0.8),
    );
    final valueWidget = link != null
        ? InkWell(
            onTap: () => _openLink(link),
            child: Text(value, style: linkStyle),
          )
        : Text(value, style: baseValueStyle);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: valueWidget),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(child: trailing),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Uri? _resolveSocialLink(_SocialPlatform platform, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    Uri? parseUrl(String input) {
      final candidate = input.startsWith('http://') || input.startsWith('https://')
          ? input
          : 'https://$input';
      final uri = Uri.tryParse(candidate);
      if (uri == null || uri.host.isEmpty) return null;
      return uri;
    }

    final lower = trimmed.toLowerCase();
    const knownDomains = [
      'instagram.com',
      'www.instagram.com',
      'tiktok.com',
      'www.tiktok.com',
      'twitter.com',
      'www.twitter.com',
      'x.com',
      'www.x.com',
    ];

    if (lower.startsWith('http://') || lower.startsWith('https://') ||
        knownDomains.any((domain) => lower.contains(domain))) {
      return parseUrl(trimmed);
    }

    final username = trimmed.replaceFirst(RegExp(r'^@+'), '');
    if (username.isEmpty) return null;

    switch (platform) {
      case _SocialPlatform.instagram:
        return Uri.https('instagram.com', '/$username');
      case _SocialPlatform.tiktok:
        return Uri.https('www.tiktok.com', '/@$username');
      case _SocialPlatform.x:
        return Uri.https('x.com', '/$username');
    }
  }

  String _formatSocialDisplay(_SocialPlatform _platform, String raw, Uri? link) {
    final trimmed = raw.trim();

    if (link != null) {
      final segments = link.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = segments.last;
        final normalized = last.replaceFirst(RegExp(r'^@+'), '');
        if (normalized.isNotEmpty) {
          return '@$normalized';
        }
      }

      final host = link.host.replaceFirst(RegExp(r'^www\.'), '');
      final path = link.pathSegments.where((segment) => segment.isNotEmpty).join('/');
      if (path.isNotEmpty) {
        return '$host/$path';
      }
      return host;
    }

    final username = trimmed.replaceFirst(RegExp(r'^@+'), '');
    if (username.isEmpty) return trimmed;
    return '@$username';
  }

  Future<void> _openLink(Uri url) async {
    final success = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${url.toString()}')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatDateOnly(DateTime date) => '${date.month}/${date.day}/${date.year}';

  MeetingAttendance? get _latestMeeting {
    if (_meetingAttendance.isEmpty) return null;
    final sorted = [..._meetingAttendance]
      ..sort((a, b) {
        final aDate = a.meetingDate ?? a.meeting?.meetingDate;
        final bDate = b.meetingDate ?? b.meeting?.meetingDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    return sorted.firstOrNull;
  }

  List<Widget> _buildMeetingAttendanceSection() {
    if (!_crmReady) return const [];

    final widgets = <Widget>[];
    if (_loadingAttendance) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_attendanceError != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Unable to load meeting attendance'),
              subtitle: Text(_attendanceError!),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMeetingAttendance,
              ),
            ),
          ),
        ),
      );
    } else if (_meetingAttendance.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('No meetings recorded yet'),
              subtitle: const Text('This member has not attended any tracked meetings.'),
            ),
          ),
        ),
      );
    } else {
      final latest = _latestMeeting;
      if (latest != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildMeetingSummaryCard(latest),
          ),
        );
      }
    }

    widgets.add(
      Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.event_note),
          label: Text('Meeting Attendance (${_meetingAttendance.length})'),
          onPressed: _meetingAttendance.isEmpty ? null : _showMeetingAttendanceSheet,
        ),
      ),
    );

    return widgets;
  }

  Card _buildMeetingSummaryCard(MeetingAttendance attendance) {
    final dateLabel = attendance.formattedMeetingDate ?? 'Date unavailable';
    final durationLabel = attendance.durationSummary;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available),
        title: Text(attendance.meetingLabel),
        subtitle: Text('Last attended $dateLabel • $durationLabel'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _navigateToMeeting(attendance),
      ),
    );
  }

  void _showMeetingAttendanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('Meeting Attendance', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: _meetingAttendance.isEmpty
                    ? const Center(child: Text('No meetings recorded yet.'))
                    : ListView.separated(
                        itemCount: _meetingAttendance.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final attendance = _meetingAttendance[index];
                          final dateLabel = attendance.formattedMeetingDate ?? 'Date unavailable';
                          final details = <String>[
                            dateLabel,
                            attendance.durationSummary,
                            if (attendance.joinWindow != null) attendance.joinWindow!,
                          ].join(' • ');
                          return ListTile(
                            title: Text(attendance.meetingLabel),
                            subtitle: Text(details),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _navigateToMeeting(attendance);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToMeeting(MeetingAttendance attendance) {
    final meetingId = attendance.meetingId;
    if (meetingId == null) return;
    Navigator.of(context, rootNavigator: true).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MeetingsScreen(
            initialMeetingId: meetingId,
            highlightMemberId: _member.id,
          ),
        ),
      ),
    );
  }
}
