import 'dart:async';
import 'package:bluebubbles/helpers/mobile_selection_area.dart';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/models/crm/wallet_pass_member.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_crossref_card.dart';
import 'package:bluebubbles/services/crm/voter_file_service.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_tab.dart';
import 'package:bluebubbles/screens/crm/meetings_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail/slack_activity_tab.dart';
import 'package:bluebubbles/screens/crm/member_detail/member_submission_screen.dart';
import 'package:bluebubbles/screens/crm/volunteers/member_outreach_section.dart';
import 'package:bluebubbles/screens/crm/widgets/member_profile_sections.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/crm/wallet_notification_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:bluebubbles/features/forms/models/form_submission.dart';
import 'package:bluebubbles/features/forms/services/forms_service.dart';
import 'package:bluebubbles/features/forms/services/votes_service.dart';
import 'package:bluebubbles/features/forms/widgets/submission_status_badge.dart';
import 'package:bluebubbles/features/forms/screens/submission_detail_screen.dart';
import 'package:bluebubbles/features/forms/screens/votes/vote_detail_screen.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter_svg/flutter_svg.dart';

enum _SocialPlatform { instagram, tiktok, x }

class _WalletNotificationDraft {
  const _WalletNotificationDraft({required this.title, required this.message});

  final String title;
  final String message;
}

class _DonationRecord {
  const _DonationRecord({
    this.id,
    this.amount,
    this.createdAt,
    this.designation,
  });

  final String? id;
  final double? amount;
  final DateTime? createdAt;
  final String? designation;
}

class _DonorProfile {
  const _DonorProfile({
    required this.id,
    required this.name,
    required this.totalDonated,
    required this.donationCount,
    required this.firstDonationAt,
    required this.lastDonationAt,
    required this.isRecurringDonor,
    required this.profileUrl,
    required this.donations,
  });

  final String? id;
  final String? name;
  final double? totalDonated;
  final int donationCount;
  final DateTime? firstDonationAt;
  final DateTime? lastDonationAt;
  final bool isRecurringDonor;
  final String? profileUrl;
  final List<_DonationRecord> donations;
}

enum _TriState { yes, no, unanswered }

enum _FieldKind {
  text,
  longText,
  email,
  phone,
  date,
  triBool,

  /// Free text that renders as chips when it carries a comma (languages).
  chipsText,
  social,

  /// address, city, state and county as one block, one Apple Maps link.
  addressBlock,

  /// Derived by on_member_updated_lookup_districts; read only in both modes.
  districts,

  /// The committee array, edited through crm_set_member_committees only.
  committees,
}

/// One answer on the profile sheet. The same spec drives read mode (the filled
/// part) and edit mode (the complete form).
class _ProfileField {
  const _ProfileField(
    this.key,
    this.label, {
    this.kind = _FieldKind.text,
    this.capitalizeWords = false,
    this.platform,
    this.readOnly = false,
    this.helper,
    this.onlyWithoutAddress = false,
  });

  final String key;
  final String label;
  final _FieldKind kind;
  final bool capitalizeWords;
  final _SocialPlatform? platform;

  /// Rendered in edit mode as a value with a caption rather than an input.
  final bool readOnly;

  /// Helper text under the input, or the read-only caption.
  final String? helper;

  /// county lives in the address block; it repeats in Districts only when no
  /// address block rendered it.
  final bool onlyWithoutAddress;

  /// Long fields break the two-up flow and take the full width.
  bool get isLong => kind == _FieldKind.longText || kind == _FieldKind.addressBlock;
}

/// One question group on the profile sheet.
class _ProfileSection {
  const _ProfileSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.fields,
    this.caption,
    this.cascade = const [],
  });

  final String id;
  final String title;

  /// The icon in the card header's tile.
  final IconData icon;
  final List<_ProfileField> fields;

  /// One line under the header in read mode.
  final String? caption;

  /// Cascade banner sentences shown above the inputs in edit mode. A section
  /// carries one when saving it fires a trigger the exec should know about.
  final List<String> cascade;
}

const String _districtsCaption = 'Districts are computed from the address.';

/// The membership form asks who you are, how to reach you, where you live,
/// what you study or do, where you organize, what you care about, and last,
/// background. The sheet follows that order. Executive fields live in the
/// header, and the system columns live on Sheet 2.
const List<_ProfileSection> _profileSections = [
  _ProfileSection(
    id: 'about',
    icon: Icons.person_outline,
    title: 'About',
    // date_of_birth drives update_membership_eligible, which is what gates
    // texting from the CRM.
    cascade: [
      'Date of birth sets membership eligibility. An ineligible member cannot be texted from the CRM.',
    ],
    fields: [
      _ProfileField('preferred_pronouns', 'Pronouns'),
      _ProfileField('date_of_birth', 'Date of birth', kind: _FieldKind.date),
      _ProfileField('languages', 'Languages', kind: _FieldKind.chipsText),
    ],
  ),
  _ProfileSection(
    id: 'contact',
    icon: Icons.contact_mail_outlined,
    title: 'Contact',
    // phone_e164 is the messaging key, and an address write recomputes county
    // and all three districts. email is class C and gets its own dialog.
    cascade: [
      'Phone is how texts reach this member. Changing it changes who receives them.',
      'Saving a new address recomputes county and all three districts. That takes a moment.',
    ],
    fields: [
      _ProfileField('email', 'Email', kind: _FieldKind.email),
      _ProfileField('phone', 'Phone', kind: _FieldKind.phone),
      _ProfileField('school_email', 'School email', kind: _FieldKind.email),
      _ProfileField('address_block', 'Address', kind: _FieldKind.addressBlock),
    ],
  ),
  _ProfileSection(
    id: 'districts',
    icon: Icons.map_outlined,
    title: 'Districts',
    caption: _districtsCaption,
    fields: [
      _ProfileField('county', 'County', readOnly: true, onlyWithoutAddress: true),
      _ProfileField(
        'congressional_district',
        'Congressional district',
        readOnly: true,
        helper: _districtsCaption,
      ),
      _ProfileField('house_district', 'House district', readOnly: true),
      _ProfileField('senate_district', 'Senate district', readOnly: true),
      _ProfileField('registered_voter', 'Registered voter', kind: _FieldKind.triBool),
    ],
  ),
  _ProfileSection(
    id: 'school_work',
    icon: Icons.school_outlined,
    title: 'School and work',
    fields: [
      _ProfileField('in_school', 'In school'),
      _ProfileField('college', 'College', capitalizeWords: true),
      _ProfileField('high_school', 'High school', capitalizeWords: true),
      _ProfileField('school_name', 'School', capitalizeWords: true),
      _ProfileField('graduation_year', 'Graduation year'),
      _ProfileField('education_level', 'Education level'),
      _ProfileField('employed', 'Employed'),
      _ProfileField('industry', 'Industry', capitalizeWords: true),
    ],
  ),
  _ProfileSection(
    id: 'chapter',
    icon: Icons.groups_outlined,
    title: 'Chapter',
    cascade: [
      'Committees set Slack channel membership. Executive Committee is not changed here.',
    ],
    fields: [
      _ProfileField('current_chapter_member', 'Current chapter member'),
      _ProfileField('chapter_name', 'Chapter name', capitalizeWords: true),
      _ProfileField('chapter_position', 'Chapter position', capitalizeWords: true),
      _ProfileField('date_elected', 'Date elected', kind: _FieldKind.date),
      _ProfileField('term_expiration', 'Term expiration', kind: _FieldKind.date),
      _ProfileField('committee', 'Committees', kind: _FieldKind.committees),
    ],
  ),
  _ProfileSection(
    id: 'involvement',
    icon: Icons.volunteer_activism_outlined,
    title: 'Involvement and interests',
    fields: [
      _ProfileField('why_join', 'Why join', kind: _FieldKind.longText),
      _ProfileField('passionate_issues', 'Passionate issues', kind: _FieldKind.longText),
      _ProfileField('why_issues_matter', 'Why these issues matter', kind: _FieldKind.longText),
      _ProfileField('areas_of_interest', 'Areas of interest', kind: _FieldKind.longText),
      _ProfileField('desire_to_lead', 'Desire to lead'),
      _ProfileField('hours_per_week', 'Hours per week'),
      _ProfileField('political_experience', 'Political experience', kind: _FieldKind.longText),
      _ProfileField('current_involvement', 'Current involvement', kind: _FieldKind.longText),
      _ProfileField('leadership_experience', 'Leadership experience', kind: _FieldKind.longText),
      _ProfileField('qualified_experience', 'Qualified experience', kind: _FieldKind.longText),
      _ProfileField('goals_and_ambitions', 'Goals and ambitions', kind: _FieldKind.longText),
      _ProfileField('referral_source', 'Referral source'),
      _ProfileField('accommodations', 'Accommodations', kind: _FieldKind.longText),
    ],
  ),
  _ProfileSection(
    id: 'social',
    icon: Icons.alternate_email,
    title: 'Social',
    fields: [
      _ProfileField('instagram', 'Instagram', kind: _FieldKind.social, platform: _SocialPlatform.instagram),
      _ProfileField('tiktok', 'TikTok', kind: _FieldKind.social, platform: _SocialPlatform.tiktok),
      _ProfileField('x', 'X', kind: _FieldKind.social, platform: _SocialPlatform.x),
    ],
  ),
  // Last on purpose: the most sensitive data on the page and the least needed
  // to make a call.
  _ProfileSection(
    id: 'background',
    icon: Icons.badge_outlined,
    title: 'Background',
    caption: 'Self reported on the membership form.',
    fields: [
      _ProfileField('gender_identity', 'Gender identity'),
      _ProfileField('race', 'Race'),
      _ProfileField('hispanic_latino', 'Hispanic or Latino', kind: _FieldKind.triBool),
      _ProfileField('sexual_orientation', 'Sexual orientation'),
      _ProfileField('religion', 'Religion'),
      _ProfileField('disability', 'Disability'),
      _ProfileField('community_type', 'Community type'),
      _ProfileField('zodiac_sign', 'Zodiac sign'),
    ],
  ),
];

/// Detailed view of a single member
class MemberDetailScreen extends StatefulWidget {
  final Member member;

  /// Optional initial tab index (0=Overview, 1=Emails, 2=Slack)
  final int initialTabIndex;

  const MemberDetailScreen({
    Key? key,
    required this.member,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final CRMMessageService _messageService = CRMMessageService.instance;
  final CRMEmailService _emailService = CRMEmailService.instance;
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();
  final WalletNotificationService _walletService =
      WalletNotificationService.instance;
  late Member _member;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _reportNotesController = TextEditingController();
  bool _editingNotes = false;
  bool _sendingIntro = false;
  bool _sendingEmail = false;
  bool _loadingAttendance = false;
  bool _hasLoadedAttendance = false;
  String? _attendanceError;
  List<MeetingAttendance> _meetingAttendance = [];
  bool _uploadingPhoto = false;
  bool _savingReportEntry = false;
  List<PlatformFile> _pendingReportFiles = [];
  final Set<String> _updatingReportIds = <String>{};
  final Set<String> _deletingReportIds = <String>{};
  String? _reportComposerError;
  bool _refreshingMember = false;
  bool _togglingOptOut = false;
  WalletPassMember? _walletPass;
  bool _loadingWalletPass = false;
  bool _sendingWalletPush = false;
  String? _walletPassError;
  _DonorProfile? _donorProfile;
  bool _loadingDonorProfile = false;
  String? _donorError;

  // MO voter file cross-reference. Lazy, read-only.
  VoterFileRecord? _voterRecord;
  bool _loadingVoterRecord = false;
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();

  // Form submissions, votes, and jobs activity
  final FormsService _formsService = FormsService();
  final VotesService _votesService = VotesService();
  List<FormSubmission> _formSubmissions = [];
  List<Map<String, dynamic>> _votesCast = [];
  List<Map<String, dynamic>> _jobApplications = [];
  bool _loadingMemberActivity = false;

  static const String _reportsBucket = 'member-documents';

  bool get _crmReady => _supabaseService.isInitialized;

  bool get _hasEmailRecipient {
    final email = _member.preferredEmail;
    return email != null && email.trim().isNotEmpty;
  }

  // ── Per-section edit state ───────────────────────────────────
  // One section is in edit mode at a time. Controllers, picked dates and
  // tri-state values are keyed by column; committees are a set of the
  // NON-executive names, since Executive Committee is never edited here.
  static const String _aboutTitleGroup = 'about_title';
  String? _editingSection;
  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, DateTime?> _editDates = {};
  final Map<String, bool?> _editBools = {};
  Set<String> _editCommittees = <String>{};
  List<String> _knownCommittees = const [];
  bool _showCommitteeInput = false;
  bool _savingSection = false;
  bool _savingNotes = false;
  String? _editError;
  String? _editErrorTitle;

  /// The member row the open editor was seeded from, and the `updated_at` that
  /// exact row carried. They are captured together in _beginEdit and only ever
  /// move together, because they describe one row version.
  ///
  /// [_editBaseline] is what _computeUpdates diffs against, never _member: a
  /// row arriving from anywhere else while the editor is open would otherwise
  /// look like a field this exec had changed and be written back, reverting
  /// whoever really changed it.
  ///
  /// [_editBaselineUpdatedAt] is the compare-and-swap token the save sends
  /// back, so Postgres writes only while the row is still that version.
  Member? _editBaseline;
  String? _editBaselineUpdatedAt;

  /// The row the diff runs against. _member is only the fallback for code that
  /// reads it outside an edit session.
  Member get _diffBase => _editBaseline ?? _member;

  /// True between an address save and the refetch that picks up the
  /// districts the trigger recomputed; S3 shows a caption meanwhile.
  bool _districtsRefreshing = false;
  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _notesController.text = _member.notes ?? '';
    _memberLookup.cacheMember(_member);
    if (_crmReady) {
      _hasLoadedAttendance = true;
      _loadMeetingAttendance();
      _fetchLatestMember();
      _loadWalletPassInfo();
      _loadDonorProfile();
      _loadMemberActivity();
      _loadVoterRecord();
    }
  }

  Future<void> _loadVoterRecord() async {
    if (_loadingVoterRecord) return;
    final voterId = _member.moVoterFileId;
    if (voterId == null || voterId.isEmpty) return;
    setState(() => _loadingVoterRecord = true);
    try {
      final record = await VoterFileService.fetchRecord(voterId);
      if (!mounted) return;
      setState(() {
        _voterRecord = record;
        _loadingVoterRecord = false;
      });
    } catch (e) {
      debugPrint('❌ _loadVoterRecord (member): $e');
      if (!mounted) return;
      setState(() => _loadingVoterRecord = false);
    }
  }


  @override
  void dispose() {
    _disposeEditControllers(immediately: true);
    _notesController.dispose();
    _reportNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    if (!_crmReady || _savingNotes) return;

    setState(() => _savingNotes = true);
    try {
      // Written through the guarded path with no expectation, so notes stay
      // last-write-wins as they always have, but the server row comes back.
      // That row carries the new version token, which re-bases an open section
      // edit instead of leaving its guard pointing at a row this write just
      // replaced.
      final snapshot = await _memberRepo.updateMemberFieldsGuarded(
        _member.id,
        {'notes': _notesController.text},
        expectedUpdatedAt: null,
      );
      if (!mounted) return;
      if (snapshot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes were not saved. Try again.')),
        );
        return;
      }
      final updated = snapshot.member;
      setState(() {
        _member = updated;
        _editingNotes = false;
        _rebaseOpenEdit(snapshot);
      });
      _memberLookup.cacheMember(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved. Mautic will refresh this contact.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _pickReportFiles() async {
    if (!_crmReady || _savingReportEntry) return;

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final additions = <PlatformFile>[];
    final failedHydrations = <String>[];
    for (final file in result.files) {
      final platformFile =
          await materializePickedPlatformFile(file, source: result);
      if (platformFile == null) {
        failedHydrations.add(file.name);
        continue;
      }
      additions.add(platformFile);
    }

    final errorMessage = failedHydrations.isEmpty
        ? null
        : failedHydrations.length == 1
            ? 'We couldn\'t read "${failedHydrations.first}". Please try again or choose a different file.'
            : 'We couldn\'t read ${failedHydrations.length} files: ${failedHydrations.join(', ')}. Please try again or choose different files.';

    if (!mounted) return;

    setState(() {
      final existingNames =
          _pendingReportFiles.map((file) => file.name.toLowerCase()).toSet();
      final merged = [..._pendingReportFiles];
      for (final file in additions) {
        if (!existingNames.contains(file.name.toLowerCase())) {
          merged.add(file);
          existingNames.add(file.name.toLowerCase());
        }
      }
      _pendingReportFiles = merged;
      _reportComposerError = additions.isEmpty
          ? (errorMessage ??
              'We couldn\'t read the selected files. Please try again or choose different files.')
          : errorMessage;
    });

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _removePendingReportFile(PlatformFile file) {
    if (_savingReportEntry) return;
    setState(() {
      _pendingReportFiles =
          _pendingReportFiles.where((element) => element != file).toList(growable: false);
    });
  }

  void _clearReportComposer() {
    _reportNotesController.clear();
    setState(() {
      _pendingReportFiles = [];
      _reportComposerError = null;
    });
  }

  Future<void> _saveReportEntry() async {
    if (!_crmReady || _savingReportEntry) return;

    final description = _reportNotesController.text.trim();
    if (description.isEmpty && _pendingReportFiles.isEmpty) {
      setState(() {
        _reportComposerError = 'Add a note or choose at least one attachment.';
      });
      return;
    }

    final baseline = _member;
    final now = DateTime.now();
    final placeholderId = MemberInternalReportEntry.generateId();
    final placeholder = MemberInternalReportEntry(
      id: placeholderId,
      description: description.isEmpty ? null : description,
      attachments: _pendingReportFiles
          .map(
            (file) => MemberInternalReportAttachment(
              bucket: _reportsBucket,
              path: 'pending/${file.name}',
              filename: file.name,
              size: file.size,
              uploadedAt: now,
              isLocalPlaceholder: true,
            ),
          )
          .toList(),
      createdAt: now,
      updatedAt: now,
      isPending: true,
    );

    setState(() {
      _reportComposerError = null;
      _savingReportEntry = true;
      _member = _member.copyWith(
        internalInfo: _member.internalInfo.copyWith(
          reports: [placeholder, ..._member.internalInfo.reports],
        ),
      );
    });

    try {
      final entryForRepo = MemberInternalReportEntry(
        id: placeholderId,
        description: description.isEmpty ? null : description,
        createdAt: now,
      );
      final updated = await _memberRepo.saveInternalReportEntry(
        member: baseline,
        entry: entryForRepo,
        newFiles: _pendingReportFiles,
      );

      if (!mounted) return;

      if (updated != null) {
        setState(() {
          _member = updated;
        });
        _memberLookup.cacheMember(updated);
        _clearReportComposer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Internal report saved')),
        );
      } else {
        setState(() {
          _member = baseline;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save report entry')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _member = baseline;
        _reportComposerError = 'Failed to save report: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingReportEntry = false;
        });
      }
    }
  }

  Future<void> _editReportEntry(MemberInternalReportEntry entry) async {
    if (!_crmReady || _updatingReportIds.contains(entry.id)) return;

    final controller = TextEditingController(text: entry.description ?? '');
    try {
      final result = await showDialog<String?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Update report notes'),
            content: TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Update internal notes for this report',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (result == null) return;

      final trimmed = result.trim();
      final updatedDescription = trimmed.isEmpty ? null : trimmed;
      final baseline = _member;
      final pendingEntry = entry.copyWith(
        description: updatedDescription,
        updatedAt: DateTime.now(),
        isPending: true,
      );

      if (!mounted) return;
      setState(() {
        _updatingReportIds.add(entry.id);
        _member = _member.copyWith(
          internalInfo: _member.internalInfo.copyWith(
            reports: _member.internalInfo.reports
                .map((item) => item.id == entry.id ? pendingEntry : item)
                .toList(),
          ),
        );
      });

      try {
        final updated = await _memberRepo.saveInternalReportEntry(
          member: baseline,
          entry: entry.copyWith(description: updatedDescription),
        );
        if (!mounted) return;
        if (updated != null) {
          setState(() {
            _updatingReportIds.remove(entry.id);
            _member = updated;
          });
          _memberLookup.cacheMember(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report updated')),
          );
        } else {
          setState(() {
            _updatingReportIds.remove(entry.id);
            _member = baseline;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to update report entry')),
          );
        }
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _updatingReportIds.remove(entry.id);
          _member = baseline;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating report: $error')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteReportEntry(MemberInternalReportEntry entry) async {
    if (!_crmReady || _deletingReportIds.contains(entry.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _profileDialog(
        dialogContext,
        title: 'Delete report',
        body: 'This will remove the report and any attachments from storage.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        destructive: true,
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final baseline = _member;
    setState(() {
      _deletingReportIds.add(entry.id);
      _member = _member.copyWith(
        internalInfo: _member.internalInfo.copyWith(
          reports: _member.internalInfo.reports
              .where((item) => item.id != entry.id)
              .toList(),
        ),
      );
    });

    try {
      final updated = await _memberRepo.deleteInternalReportEntry(
        member: baseline,
        entryId: entry.id,
      );
      if (!mounted) return;
      setState(() {
        _deletingReportIds.remove(entry.id);
        if (updated != null) {
          _member = updated;
        }
      });
      if (updated != null) {
        _memberLookup.cacheMember(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deletingReportIds.remove(entry.id);
        _member = baseline;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting report: $error')),
      );
    }
  }

  /// Flip the member's opt-out flag and show whatever the database ended up
  /// holding.
  ///
  /// Nothing here merges the intended state locally. The repository returns the
  /// row the server wrote and throws if it did not write one, so the only way
  /// to reach the success path is with a row in hand. A member who is still
  /// opted in cannot be displayed as opted out, which is the direction of this
  /// bug that keeps sending texts to someone the CRM says was unsubscribed.
  Future<void> _toggleOptOut() async {
    if (!_crmReady || _togglingOptOut) return;
    final newOptOutStatus = !_member.optOut;

    setState(() => _togglingOptOut = true);
    try {
      final snapshot = await _memberRepo.updateOptOutStatus(
        _member.id,
        newOptOutStatus,
        reason: newOptOutStatus ? 'Manually opted out' : null,
      );

      if (!mounted) return;
      setState(() {
        _member = snapshot.member;
        _rebaseOpenEdit(snapshot);
      });
      _memberLookup.cacheMember(snapshot.member);

      // Read off the saved row, not off the toggle that was requested.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snapshot.member.optOut ? 'Member opted out' : 'Member opted in',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opt-out status was NOT changed. This member is still '
            '${_member.optOut ? 'opted out' : 'opted in'}. $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _togglingOptOut = false);
    }
  }

  /// Reload the member from the server.
  ///
  /// This will not run while a section is in edit mode. The screen used to
  /// reassign _member from here regardless, and the initState refetch, the
  /// post-address refetch and the pull-to-refresh all land at times nobody
  /// controls. With the editor open that swapped the row the controllers were
  /// seeded from, so a field a different exec had just changed no longer
  /// matched this exec's untouched controller, entered the diff as an edit and
  /// was written back on save, silently reverting them.
  Future<void> _fetchLatestMember({bool showFeedback = false}) async {
    if (!_crmReady || _refreshingMember) return;
    if (_editingSection != null) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save or cancel the open edit first. Refreshing now would '
              'replace the values you are editing.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _refreshingMember = true);

    try {
      final refreshed = await _memberRepo.getMemberById(_member.id);
      if (!mounted) return;

      if (refreshed != null) {
        setState(() {
          _member = refreshed;
          if (!_editingNotes) {
            _notesController.text = refreshed.notes ?? '';
          }
        });
        _memberLookup.cacheMember(refreshed);
        if (_walletService.isReady) {
          unawaited(_loadWalletPassInfo());
        }
        unawaited(_loadDonorProfile());
        unawaited(_loadVoterRecord());
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member refreshed')),
          );
        }
      } else if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to refresh member')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = showFeedback
          ? 'Error refreshing member: $e'
          : 'Error loading member details: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingMember = false);
      }
    }
  }

  Future<void> _refreshMember() => _fetchLatestMember(showFeedback: true);

  Future<void> _loadWalletPassInfo() async {
    if (!_walletService.isReady || _loadingWalletPass) return;

    setState(() {
      _loadingWalletPass = true;
      _walletPassError = null;
    });

    try {
      final members = await _walletService.fetchPassMembers(
        memberIds: [_member.id],
        limit: 1,
      );
      if (!mounted) return;
      setState(() {
        _walletPass = members.isNotEmpty ? members.first : null;
        _loadingWalletPass = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _walletPass = null;
        _walletPassError = error.toString();
        _loadingWalletPass = false;
      });
    }
  }

  Future<void> _loadDonorProfile() async {
    if (!_crmReady || _loadingDonorProfile) return;

    setState(() {
      _loadingDonorProfile = true;
      _donorError = null;
    });

    try {
      final response = await _supabaseService.client
          .from('donors')
          .select(
            'id,name,total_donated,donation_count,first_donation_date,last_donation_date,'
            'is_recurring_donor,donations(id,amount,created_at,designation)',
          )
          .eq('member_id', _member.id)
          .order('created_at', referencedTable: 'donations', ascending: false)
          .limit(1);

      _DonorProfile? donor;
      if (response is List && response.isNotEmpty) {
        final row = response.first;
        if (row is Map<String, dynamic>) {
          donor = _mapDonorProfile(row);
        }
      }

      if (!mounted) return;
      setState(() {
        _donorProfile = donor;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _donorError = 'Failed to load donor details: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDonorProfile = false;
        });
      }
    }
  }

  /// Load member activity: form submissions, votes, and job applications
  Future<void> _loadMemberActivity() async {
    setState(() => _loadingMemberActivity = true);

    try {
      // Load form submissions
      final submissions = await _formsService.getSubmissionsByMemberId(_member.id);
      if (mounted) {
        setState(() => _formSubmissions = submissions);
      }

      // Load votes cast by member using VotesService
      try {
        final votesResponse = await _votesService.getVotesByMember(_member.id);
        if (mounted) {
          setState(() => _votesCast = votesResponse);
        }
      } catch (e) {
        // Votes table may not exist, that's ok
        debugPrint('Could not load votes: $e');
      }

      // Load job applications
      try {
        final jobsResponse = await _supabaseService.client
            .from('job_applications')
            .select('*')
            .eq('member_id', _member.id)
            .order('created_at', ascending: false);

        if (mounted && jobsResponse is List) {
          setState(() => _jobApplications = List<Map<String, dynamic>>.from(jobsResponse));
        }
      } catch (e) {
        // Job applications table may not exist, that's ok
        debugPrint('Could not load job applications: $e');
      }
    } catch (e) {
      debugPrint('Error loading member activity: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingMemberActivity = false);
      }
    }
  }

  _DonorProfile _mapDonorProfile(Map<String, dynamic> donorRow) {
    final donations = <_DonationRecord>[];
    final donationRows = donorRow['donations'];
    if (donationRows is List) {
      for (final entry in donationRows) {
        if (entry is! Map<String, dynamic>) continue;
        final createdAt = _parseDate(entry['created_at']);
        donations.add(
          _DonationRecord(
            id: entry['id']?.toString(),
            amount: (entry['amount'] as num?)?.toDouble(),
            createdAt: createdAt,
            designation: entry['designation'] as String?,
          ),
        );
      }
    }

    donations.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    final totalFromRow = (donorRow['total_donated'] as num?)?.toDouble();
    final totalDonated = totalFromRow ??
        donations.fold<double>(0, (sum, donation) => sum + (donation.amount ?? 0));
    final donationCount = donorRow['donation_count'] is int
        ? donorRow['donation_count'] as int
        : donations.length;

    return _DonorProfile(
      id: donorRow['id']?.toString(),
      name: donorRow['name'] as String?,
      totalDonated: totalDonated,
      donationCount: donationCount,
      firstDonationAt:
          _parseDate(donorRow['first_donation_date']) ??
              _parseDate(donorRow['first_donation_at']) ??
              donations.lastOrNull?.createdAt,
      lastDonationAt:
          _parseDate(donorRow['last_donation_date']) ??
              _parseDate(donorRow['last_donation_at']) ??
              donations.firstOrNull?.createdAt,
      isRecurringDonor: donorRow['is_recurring_donor'] == true,
      profileUrl:
          donorRow['profile_url'] as String? ?? donorRow['profile_link'] as String?,
      donations: donations,
    );
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

  /// Upload a new profile photo.
  ///
  /// Blocked while a section is in edit mode. The upload writes
  /// profile_pictures and returns the whole member row, which this method
  /// assigns to _member; doing that under an open editor is the same clobber
  /// _fetchLatestMember was doing, and it moves the row version the pending
  /// save is guarded on.
  Future<void> _selectProfilePhoto() async {
    if (!_crmReady || _uploadingPhoto) return;
    if (_editingSection != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save or cancel the open edit before changing the photo.'),
        ),
      );
      return;
    }

    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'heic', 'heif', 'webp'],
      withData: true,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = result.files.first;
    final platformFile =
        await materializePickedPlatformFile(picked, source: result);
    if (platformFile == null) {
      if (!mounted) return;
      setState(() {
        _reportComposerError =
            'We couldn\'t read the selected photo. Please try again or choose a different file.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected photo. Please try again.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _uploadingPhoto = true;
      _reportComposerError = null;
    });

    try {
      final updated = await _memberRepo.uploadProfilePhoto(member: _member, file: platformFile);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _member = updated);
        _memberLookup.cacheMember(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update profile photo')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
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

  Future<void> _composeEmail() async {
    final email = _member.preferredEmail?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address available')),
      );
      return;
    }

    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    final fromNameController = TextEditingController();
    final replyToController = TextEditingController();
    final ccSearchController = TextEditingController();
    final ccManualEmailController = TextEditingController();
    final bccSearchController = TextEditingController();
    final bccManualEmailController = TextEditingController();

    final List<Member> ccMembers = [];
    final List<Member> bccMembers = [];
    final List<Member> ccSearchResults = [];
    final List<Member> bccSearchResults = [];
    final List<String> ccManualEmails = [];
    final List<String> bccManualEmails = [];
    final List<PlatformFile> attachmentFiles = [];

    Timer? ccSearchDebounce;
    Timer? bccSearchDebounce;
    bool searchingCc = false;
    bool searchingBcc = false;
    bool dialogOpen = true;

    String? errorMessage;
    bool sending = false;

    String? normalizeEmail(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      if (trimmed.isEmpty || !trimmed.contains('@')) {
        return null;
      }
      return trimmed;
    }

    final primaryEmailLower = email.toLowerCase();

    bool emailAlreadyUsed(String lowerCaseEmail) {
      if (lowerCaseEmail == primaryEmailLower) {
        return true;
      }

      bool matchesMemberEmail(Member member) {
        final normalized = normalizeEmail(member.preferredEmail);
        return normalized != null && normalized.toLowerCase() == lowerCaseEmail;
      }

      if (ccMembers.any(matchesMemberEmail)) return true;
      if (bccMembers.any(matchesMemberEmail)) return true;
      if (ccManualEmails.any((email) => email.toLowerCase() == lowerCaseEmail)) {
        return true;
      }
      if (bccManualEmails.any((email) => email.toLowerCase() == lowerCaseEmail)) {
        return true;
      }
      return false;
    }

    bool? result;
    try {
      result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void updateState() => setDialogState(() {});

              void onCcSearchChanged(String value) {
                ccSearchDebounce?.cancel();
                final query = value.trim();
                if (query.length < 2) {
                  setDialogState(() {
                    ccSearchResults.clear();
                    searchingCc = false;
                  });
                  return;
                }

                ccSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
                  if (!dialogOpen || !mounted) return;
                  setDialogState(() {
                    searchingCc = true;
                  });
                  try {
                    final results = await _memberRepo.searchMembers(query);
                    if (!dialogOpen || !mounted) return;
                    setDialogState(() {
                      ccSearchResults
                        ..clear()
                        ..addAll(
                          results.where(
                            (member) {
                              if (member.id == _member.id) return false;
                              return normalizeEmail(member.preferredEmail) != null;
                            },
                          ),
                        );
                      searchingCc = false;
                    });
                  } catch (_) {
                    if (!dialogOpen || !mounted) return;
                    setDialogState(() {
                      ccSearchResults.clear();
                      searchingCc = false;
                    });
                  }
                });
              }

              void onBccSearchChanged(String value) {
                bccSearchDebounce?.cancel();
                final query = value.trim();
                if (query.length < 2) {
                  setDialogState(() {
                    bccSearchResults.clear();
                    searchingBcc = false;
                  });
                  return;
                }

                bccSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
                  if (!dialogOpen || !mounted) return;
                  setDialogState(() {
                    searchingBcc = true;
                  });
                  try {
                    final results = await _memberRepo.searchMembers(query);
                    if (!dialogOpen || !mounted) return;
                    setDialogState(() {
                      bccSearchResults
                        ..clear()
                        ..addAll(
                          results.where(
                            (member) {
                              if (member.id == _member.id) return false;
                              return normalizeEmail(member.preferredEmail) != null;
                            },
                          ),
                        );
                      searchingBcc = false;
                    });
                  } catch (_) {
                    if (!dialogOpen || !mounted) return;
                    setDialogState(() {
                      bccSearchResults.clear();
                      searchingBcc = false;
                    });
                  }
                });
              }

              void toggleCcMember(Member member) {
                if (sending) return;
                final alreadySelected =
                    ccMembers.any((existing) => existing.id == member.id);
                if (alreadySelected) {
                  setDialogState(() {
                    ccMembers.removeWhere((existing) => existing.id == member.id);
                  });
                  return;
                }

                final normalized = normalizeEmail(member.preferredEmail);
                if (normalized == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selected member does not have an email address.'),
                    ),
                  );
                  return;
                }
                final lower = normalized.toLowerCase();
                if (emailAlreadyUsed(lower)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('That email is already in the recipient list.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  ccMembers.add(member);
                });
              }

              void toggleBccMember(Member member) {
                if (sending) return;
                final alreadySelected =
                    bccMembers.any((existing) => existing.id == member.id);
                if (alreadySelected) {
                  setDialogState(() {
                    bccMembers.removeWhere((existing) => existing.id == member.id);
                  });
                  return;
                }

                final normalized = normalizeEmail(member.preferredEmail);
                if (normalized == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selected member does not have an email address.'),
                    ),
                  );
                  return;
                }
                final lower = normalized.toLowerCase();
                if (emailAlreadyUsed(lower)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('That email is already in the recipient list.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  bccMembers.add(member);
                });
              }

              void removeCcMember(Member member) {
                if (sending) return;
                setDialogState(() {
                  ccMembers.removeWhere((existing) => existing.id == member.id);
                });
              }

              void removeBccMember(Member member) {
                if (sending) return;
                setDialogState(() {
                  bccMembers.removeWhere((existing) => existing.id == member.id);
                });
              }

              void addManualCcEmail() {
                if (sending) return;
                final manual = normalizeEmail(ccManualEmailController.text);
                if (manual == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid email address before adding.'),
                    ),
                  );
                  return;
                }
                final lower = manual.toLowerCase();
                if (emailAlreadyUsed(lower)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('That email is already in the recipient list.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  ccManualEmails.add(manual);
                  ccManualEmailController.clear();
                });
              }

              void addManualBccEmail() {
                if (sending) return;
                final manual = normalizeEmail(bccManualEmailController.text);
                if (manual == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid email address before adding.'),
                    ),
                  );
                  return;
                }
                final lower = manual.toLowerCase();
                if (emailAlreadyUsed(lower)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('That email is already in the recipient list.'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  bccManualEmails.add(manual);
                  bccManualEmailController.clear();
                });
              }

              void removeManualCcEmail(String value) {
                if (sending) return;
                setDialogState(() {
                  ccManualEmails.remove(value);
                });
              }

              void removeManualBccEmail(String value) {
                if (sending) return;
                setDialogState(() {
                  bccManualEmails.remove(value);
                });
              }

              Future<void> pickAttachments() async {
                if (sending) return;
                final result = await file_picker.FilePicker.platform.pickFiles(
                  allowMultiple: true,
                  withData: true,
                  withReadStream: !kIsWeb,
                );

                if (result == null || result.files.isEmpty) {
                  return;
                }

                final additions = <PlatformFile>[];
                final failedHydrations = <String>[];

                for (final file in result.files) {
                  try {
                    final platformFile =
                        await materializePickedPlatformFile(file, source: result);
                    if (platformFile == null) {
                      failedHydrations.add(file.name);
                      continue;
                    }
                    additions.add(platformFile);
                  } catch (_) {
                    failedHydrations.add(file.name);
                  }
                }

                if (!dialogOpen || !mounted) return;

                if (additions.isNotEmpty) {
                  setDialogState(() {
                    final existingNames =
                        attachmentFiles.map((file) => file.name.toLowerCase()).toSet();
                    for (final file in additions) {
                      final lower = file.name.toLowerCase();
                      if (existingNames.add(lower)) {
                        attachmentFiles.add(file);
                      }
                    }
                  });
                }

                if (failedHydrations.isNotEmpty && mounted) {
                  final message = failedHydrations.length == 1
                      ? 'We couldn\'t read "${failedHydrations.first}". Please try again or choose a different file.'
                      : 'We couldn\'t read ${failedHydrations.length} files: ${failedHydrations.join(', ')}. Please try again or choose different files.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              }

              void removeAttachment(PlatformFile file) {
                if (sending) return;
                setDialogState(() {
                  attachmentFiles.remove(file);
                });
              }

              Widget buildCopySection({
                required String label,
                required TextEditingController searchController,
                required TextEditingController manualController,
                required List<Member> members,
                required List<Member> searchResults,
                required List<String> manualEmails,
                required bool searching,
                required void Function(String value) onSearchChanged,
                required ValueChanged<Member> onToggleMember,
                required ValueChanged<Member> onRemoveMember,
                required VoidCallback onAddManual,
                required ValueChanged<String> onRemoveManual,
              }) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label Recipients',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                                onDeleted:
                                    sending ? null : () => onRemoveMember(member),
                              ),
                            )
                            .toList(),
                      ),
                    if (members.isNotEmpty && manualEmails.isNotEmpty)
                      const SizedBox(height: 8),
                    if (manualEmails.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: manualEmails
                            .map(
                              (value) => InputChip(
                                label: Text(value),
                                avatar:
                                    const Icon(Icons.alternate_email, size: 18),
                                onDeleted:
                                    sending ? null : () => onRemoveManual(value),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      enabled: !sending,
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
                      onChanged: onSearchChanged,
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
                            final email = normalizeEmail(member.preferredEmail);
                            final selected =
                                members.any((existing) => existing.id == member.id);
                            return ListTile(
                              title: Text(member.name),
                              subtitle: Text(email ?? 'No email on record'),
                              trailing: Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              onTap: sending ? null : () => onToggleMember(member),
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
                            enabled: !sending,
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
                          onPressed: sending ? null : onAddManual,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                );
              }

              Future<void> submit() async {
                final subject = subjectController.text.trim();
                final body = bodyController.text.trim();
                final fromName = fromNameController.text.trim();
                final replyTo = replyToController.text.trim();
                final usedEmails = <String>{primaryEmailLower};
                final ccList = <String>[];
                final bccList = <String>[];

                void addEmail(String? value, List<String> target) {
                  final normalized = normalizeEmail(value);
                  if (normalized == null) {
                    return;
                  }
                  final lower = normalized.toLowerCase();
                  if (usedEmails.add(lower)) {
                    target.add(normalized);
                  }
                }

                for (final member in ccMembers) {
                  addEmail(member.preferredEmail, ccList);
                }
                for (final manual in ccManualEmails) {
                  addEmail(manual, ccList);
                }
                for (final member in bccMembers) {
                  addEmail(member.preferredEmail, bccList);
                }
                for (final manual in bccManualEmails) {
                  addEmail(manual, bccList);
                }

                if (subject.isEmpty || body.isEmpty || sending) {
                  return;
                }

                setDialogState(() {
                  sending = true;
                  errorMessage = null;
                });
                setState(() => _sendingEmail = true);

                try {
                  final attachments = <CRMEmailAttachment>[];
                  for (final file in attachmentFiles) {
                    final attachment =
                        await _emailService.buildAttachmentFromPlatformFile(file);
                    if (attachment != null) {
                      attachments.add(attachment);
                    }
                  }

                  await _emailService.sendEmail(
                    to: [email],
                    subject: subject,
                    textBody: body,
                    fromEmail: CRMConfig.defaultSenderEmail,
                    fromName: fromName.isEmpty ? null : fromName,
                    replyTo: replyTo.isEmpty ? null : replyTo,
                    cc: ccList.isEmpty ? null : ccList,
                    bcc: bccList.isEmpty ? null : bccList,
                    attachments: attachments,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                } catch (error) {
                  final message = error is CRMEmailException
                      ? error.message
                      : 'Failed to send email: $error';
                  if (context.mounted) {
                    setDialogState(() {
                      sending = false;
                      errorMessage = message;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _sendingEmail = false);
                  } else {
                    _sendingEmail = false;
                  }
                }
              }

              final canSend = !sending &&
                  subjectController.text.trim().isNotEmpty &&
                  bodyController.text.trim().isNotEmpty;

              return AlertDialog(
                title: const Text('Compose Email'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'To: $email',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).hintColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('crm_email_subject_field'),
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                        onChanged: (_) => updateState(),
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
                        controller: fromNameController,
                        decoration: const InputDecoration(
                          labelText: 'From Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: replyToController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Reply-To Email (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('crm_email_body_field'),
                        controller: bodyController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Type your message…',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => updateState(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Attachments',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (attachmentFiles.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attachmentFiles
                              .map(
                                (file) => InputChip(
                                  label: Text(file.name),
                                  avatar: const Icon(Icons.insert_drive_file, size: 18),
                                  onDeleted: sending
                                      ? null
                                      : () => removeAttachment(file),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: sending ? null : pickAttachments,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Add attachments'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      buildCopySection(
                        label: 'CC',
                        searchController: ccSearchController,
                        manualController: ccManualEmailController,
                        members: ccMembers,
                        searchResults: ccSearchResults,
                        manualEmails: ccManualEmails,
                        searching: searchingCc,
                        onSearchChanged: onCcSearchChanged,
                        onToggleMember: toggleCcMember,
                        onRemoveMember: removeCcMember,
                        onAddManual: addManualCcEmail,
                        onRemoveManual: removeManualCcEmail,
                      ),
                      const SizedBox(height: 24),
                      buildCopySection(
                        label: 'BCC',
                        searchController: bccSearchController,
                        manualController: bccManualEmailController,
                        members: bccMembers,
                        searchResults: bccSearchResults,
                        manualEmails: bccManualEmails,
                        searching: searchingBcc,
                        onSearchChanged: onBccSearchChanged,
                        onToggleMember: toggleBccMember,
                        onRemoveMember: removeBccMember,
                        onAddManual: addManualBccEmail,
                        onRemoveManual: removeManualBccEmail,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: canSend ? submit : null,
                    child: sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('Send Email'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      subjectController.dispose();
      bodyController.dispose();
      fromNameController.dispose();
      replyToController.dispose();
      ccSearchController.dispose();
      ccManualEmailController.dispose();
      bccSearchController.dispose();
      bccManualEmailController.dispose();
      dialogOpen = false;
      ccSearchDebounce?.cancel();
      bccSearchDebounce?.cancel();
    }

    if (result == true) {
      await _memberRepo.updateLastContacted(_member.id);
      if (!mounted) return;
      final now = DateTime.now();
      final updated = _member.copyWith(lastContacted: now);
      setState(() => _member = updated);
      _memberLookup.cacheMember(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent to ${_member.name}')),
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
    if (!mounted) return;

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

  Future<void> _sendWalletPushToMember() async {
    if (!_walletService.isReady || _sendingWalletPush) return;

    final pass = _walletPass;
    if (pass == null || !pass.hasPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This member does not have an active wallet pass yet.'),
        ),
      );
      return;
    }

    final draft = await _promptWalletNotificationDraft();
    if (draft == null || !mounted) return;

    setState(() => _sendingWalletPush = true);

    WalletNotificationResult result;
    try {
      result = await _walletService.sendNotification(
        target: WalletNotificationTarget.selectedMembers,
        title: draft.title,
        message: draft.message,
        memberIds: [_member.id],
      );
    } finally {
      if (mounted) {
        setState(() => _sendingWalletPush = false);
      }
    }

    if (!mounted) return;

    if (result.success) {
      final delivered = result.delivered;
      final deliveredText = delivered > 0
          ? ' Delivered to $delivered device${delivered == 1 ? '' : 's'}.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent to ${_member.name}.$deliveredText'),
        ),
      );
    } else {
      final message = result.message ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send notification: $message'),
        ),
      );
    }
  }

  Future<_WalletNotificationDraft?> _promptWalletNotificationDraft() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_WalletNotificationDraft>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Notify ${_member.name}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification title',
                      hintText: 'Your title here',
                    ),
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a notification title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Notification message',
                      hintText: 'Your message here',
                    ),
                    minLines: 3,
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a notification message';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(
                  context,
                  _WalletNotificationDraft(
                    title: titleController.text.trim(),
                    message: messageController.text.trim(),
                  ),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    messageController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_crmReady && !_hasLoadedAttendance) {
      _hasLoadedAttendance = true;
      _loadMeetingAttendance();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _member.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _refreshingMember
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: !_crmReady || _refreshingMember ? null : _refreshMember,
            tooltip: 'Refresh Member',
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _member.canContact ? _startChat : null,
            tooltip: 'Start Chat',
          ),
          IconButton(
            icon: _sendingEmail
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.email_outlined),
            onPressed:
                !_crmReady || _sendingEmail || !_hasEmailRecipient ? null : _composeEmail,
            tooltip: 'Send Email',
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
          : DefaultTabController(
              length: 4,
              initialIndex: widget.initialTabIndex.clamp(0, 3),
              child: Column(
                children: [
                  // Branded tab bar with navy gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: BrandColors.tileGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white,
                      indicatorColor: BrandColors.sunriseGold,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                      ),
                      tabs: [
                        const Tab(icon: Icon(Icons.account_circle_outlined), text: 'Overview'),
                        const Tab(icon: Icon(Icons.email_outlined), text: 'Emails'),
                        Tab(
                          icon: SvgPicture.asset(
                            'assets/icon/slack-icon.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          text: 'Slack',
                        ),
                        const Tab(icon: Icon(Icons.video_camera_front_outlined), text: 'Meetings'),
                      ],
                    ),
                  ),
                  // Tab content with branded background
                  Expanded(
                    child: BrandedBackground(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildOverviewTab(context),
                          EmailHistoryTab(
                            memberId: _member.id,
                            memberName: _member.name,
                            memberEmail: _member.preferredEmail,
                          ),
                          SlackActivityTab(
                            member: _member,
                            onLinked: () => _fetchLatestMember(showFeedback: false),
                          ),
                          _buildMeetingsTab(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Activity card ────────────────────────────────────────────

  /// Forms submitted, votes cast and job applications. Null while loading and
  /// null when there is nothing to show: the grid never carries a spinner
  /// card or an empty placeholder for this block. [first] is kept for the
  /// caller and ignored; the card is its own surface.
  Widget? _buildMemberActivityBlock({required bool first}) {
    if (_loadingMemberActivity) return null;

    final hasFormSubmissions = _formSubmissions.isNotEmpty;
    final hasVotes = _votesCast.isNotEmpty;
    final hasJobApplications = _jobApplications.isNotEmpty;
    if (!hasFormSubmissions && !hasVotes && !hasJobApplications) return null;

    final dateFormat = DateFormat('MMM d, y');
    final subsections = <Widget>[];

    if (hasFormSubmissions) {
      subsections.add(
        _buildActivitySubsection(
          title: 'Form submissions',
          icon: Icons.assignment_outlined,
          count: _formSubmissions.length,
          children: _formSubmissions.take(3).map((submission) {
            return _activityRow(
              icon: Icons.description_outlined,
              title: submission.displayName != 'Anonymous'
                  ? submission.displayName
                  : 'Form submission',
              subtitle: dateFormat.format(submission.createdAt),
              trailing: SubmissionStatusBadge(status: submission.status, compact: true),
              onTap: () => _viewFormSubmission(submission),
            );
          }).toList(),
        ),
      );
    }

    if (hasVotes) {
      subsections.add(
        _buildActivitySubsection(
          title: 'Votes cast',
          icon: Icons.how_to_vote_outlined,
          count: _votesCast.length,
          children: _votesCast.take(3).map((vote) {
            final title = vote['form_schemas']?['title']?.toString() ?? 'Vote';
            final voteId = vote['form_schemas']?['id']?.toString() ??
                vote['voting_form_id']?.toString();
            final createdAtRaw = vote['created_at'];
            final createdAt =
                createdAtRaw != null ? DateTime.tryParse(createdAtRaw.toString()) : null;
            final voteData = vote['vote_data'] as Map<String, dynamic>?;
            final schema = vote['form_schemas']?['schema'] as Map<String, dynamic>?;
            final voteChoice = _getVoteChoiceLabel(voteData, schema);
            final subtitleParts = <String>[
              if (createdAt != null) dateFormat.format(createdAt),
              if (voteChoice != null) 'Voted: $voteChoice',
            ];
            return _activityRow(
              icon: Icons.check_circle_outline,
              title: title,
              subtitle: subtitleParts.isEmpty ? null : subtitleParts.join('  '),
              onTap: voteId != null ? () => _viewVoteDetails(voteId) : null,
            );
          }).toList(),
        ),
      );
    }

    if (hasJobApplications) {
      subsections.add(
        _buildActivitySubsection(
          title: 'Job applications',
          icon: Icons.work_outline,
          count: _jobApplications.length,
          children: _jobApplications.take(3).map((job) {
            final title = job['form_schemas']?['title']?.toString() ?? 'Application';
            final createdAtRaw = job['created_at'];
            final createdAt =
                createdAtRaw != null ? DateTime.tryParse(createdAtRaw.toString()) : null;
            final status = job['status']?.toString() ?? 'submitted';
            return _activityRow(
              icon: Icons.business_center_outlined,
              title: title,
              subtitle: createdAt != null ? dateFormat.format(createdAt) : null,
              trailing: _profileTag(status),
            );
          }).toList(),
        ),
      );
    }

    return ProfileSectionCard(
      title: 'Activity',
      icon: Icons.timeline_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: subsections,
      ),
    );
  }

  /// A status word as a solid unityBlue chip with a white outline, 12.51:1.
  Widget _profileTag(String text) => profileChip(text);

  /// One tappable row inside an activity subsection, on a solid unityBlue
  /// block with a hairline outline. Built by hand rather than as a ListTile so
  /// no Theme colour reaches the card.
  Widget _activityRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: ProfileTokens.fill,
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        border: Border.all(color: ProfileTokens.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ProfileText.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) Text(subtitle, style: ProfileText.caption),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: Colors.white),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        onTap: onTap,
        child: row,
      ),
    );
  }

  Widget _buildActivitySubsection({
    required String title,
    required IconData icon,
    required int count,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(title.toUpperCase(), style: ProfileText.label)),
              _profileTag('$count'),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
          if (count > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: Text('+${count - 3} more', style: ProfileText.caption),
            ),
        ],
      ),
    );
  }

  /// Endorsement questionnaires go to the candidate review, which is built for
  /// them: it carries the Gemini verdict block and is titled Candidate Review.
  /// Every other form, membership above all, is never scored, so it opens the
  /// read-only submission view instead. FormSubmission does not carry the slug,
  /// so the schema is fetched first and the branch is taken on its slug.
  Future<void> _viewFormSubmission(FormSubmission submission) async {
    bool isEndorsement = false;
    try {
      final form = await _formsService.getForm(submission.formId);
      isEndorsement = form.slug?.startsWith('endorsement-questionnaire') ?? false;
    } catch (e) {
      debugPrint('_viewFormSubmission: could not load form ${submission.formId}: $e');
    }
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isEndorsement
            ? SubmissionDetailScreen(
                formId: submission.formId,
                submissionId: submission.id,
              )
            : MemberSubmissionScreen(
                formId: submission.formId,
                submissionId: submission.id,
                avatarUrl: _member.effectiveAvatarUrl,
              ),
      ),
    );
  }

  /// Get the label for a vote choice by looking up the option ID in the schema
  String? _getVoteChoiceLabel(
    Map<String, dynamic>? voteData,
    Map<String, dynamic>? schema,
  ) {
    return VotesService.getVoteChoiceLabel(voteData, schema);
  }

  void _viewVoteDetails(String voteId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoteDetailScreen(voteId: voteId),
      ),
    );
  }

  // ── Overview tab ─────────────────────────────────────────────

  /// Gradient cards on the branded ground, centred at 1200, in the Slack
  /// management page's idiom: the hero card, a strip of stat cards, then
  /// every section as its own card, two columns from 1100 wide and one column
  /// below. Every piece of content sits on a card, because BrandedBackground
  /// is not light and no single ink passes at both of its ends (see
  /// ProfileTokens).
  Widget _buildOverviewTab(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 768;
        final twoColumns = constraints.maxWidth >= ProfileTokens.gridMinWidth;
        final listPadding = wide
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
            : const EdgeInsets.all(16);

        final sections = _buildSectionCards();
        final cards = <Widget>[...sections.cards, ..._buildRecordCards()];
        if (sections.omitted.isNotEmpty && _editingSection == null) {
          cards.add(_buildAddSectionsCard(sections.omitted));
        }

        return MobileAwareSelectionArea(
          child: ListView(
            padding: listPadding,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: ProfileTokens.maxSheetWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroCard(wide: wide),
                      const SizedBox(height: ProfileTokens.cardGap),
                      ..._buildStatStrip(wide: wide),
                      _buildCardGrid(cards, twoColumns: twoColumns),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Two columns of cards filled by alternating, 24 between cards in both
  /// directions; one column below 1100.
  Widget _buildCardGrid(List<Widget> cards, {required bool twoColumns}) {
    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: ProfileTokens.cardGap),
              items[i],
            ],
          ],
        );

    if (!twoColumns) return column(cards);

    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      (i.isEven ? left : right).add(cards[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: ProfileTokens.cardGap),
        Expanded(child: column(right)),
      ],
    );
  }

  // ── The stat strip ───────────────────────────────────────────

  /// BrandedStatCards for what the data genuinely supports. Nothing is
  /// invented: a card renders only when its value is known, and a count
  /// renders only once its load has finished. No subtitle is passed, because
  /// BrandedStatCard draws its subtitle at white 0.90, which is 4.04:1 on the
  /// card's light end and fails.
  List<Widget> _buildStatStrip({required bool wide}) {
    final stats = <Widget>[
      if (_member.registeredVoter != null)
        BrandedStatCard(
          title: 'Registered voter',
          value: _member.registeredVoter! ? 'Yes' : 'No',
          icon: Icons.how_to_vote_outlined,
        ),
      BrandedStatCard(
        title: 'Textable',
        value: _member.canContact ? 'Yes' : 'No',
        icon: Icons.sms_outlined,
      ),
      if (_crmReady && !_loadingAttendance && _attendanceError == null)
        BrandedStatCard(
          title: 'Meetings attended',
          value: '${_meetingAttendance.length}',
          icon: Icons.video_camera_front_outlined,
        ),
      if (_crmReady && !_loadingMemberActivity && _formSubmissions.isNotEmpty)
        BrandedStatCard(
          title: 'Forms submitted',
          value: '${_formSubmissions.length}',
          icon: Icons.assignment_outlined,
        ),
      if (_donorProfile != null && !_loadingDonorProfile)
        BrandedStatCard(
          title: 'Donated',
          value: _formatCurrency(_donorProfile!.totalDonated ?? 0),
          icon: Icons.volunteer_activism_outlined,
        ),
    ];
    if (stats.isEmpty) return const [];

    final Widget strip;
    if (wide) {
      strip = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: stats[i]),
          ],
        ],
      );
    } else {
      strip = LayoutBuilder(
        builder: (context, constraints) {
          final half = (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final stat in stats) SizedBox(width: half, child: stat)],
          );
        },
      );
    }
    return [strip, const SizedBox(height: ProfileTokens.cardGap)];
  }

  // ── The hero card ────────────────────────────────────────────

  /// The person is the headline: a 96 px photo in a 3 px sunriseGold ring,
  /// the name at 34, one meta line, the status pills, the district pills as
  /// solid unityBlue chips, then the action pills in the emphasis pair.
  Widget _buildHeroCard({required bool wide}) {
    final isExecutive = _member.executiveCommittee;
    final executiveTitle = _cleanText(_member.executiveTitle) ?? 'Executive Committee';
    final executiveRole = _cleanText(_member.executiveRoleDisplay);
    final chapterName = _cleanText(_member.chapterName);
    final county = _cleanText(_member.county);

    final meta = <String>[
      if (isExecutive)
        executiveRole == null ? executiveTitle : '$executiveTitle, $executiveRole',
      if (_member.dateJoined != null) 'Joined ${_formatDateOnly(_member.dateJoined!)}',
      if (county != null)
        county.toLowerCase().endsWith('county') ? county : '$county County',
    ];

    final pills = <Widget>[
      if (isExecutive)
        const ProfilePill(label: 'Executive Committee', style: ProfilePillStyle.emphasis),
      if (_member.optOut) const ProfilePill(label: 'Opted out', style: ProfilePillStyle.danger),
      if (_member.membershipEligible == false)
        const ProfilePill(label: 'Ineligible', style: ProfilePillStyle.danger),
      if (chapterName != null)
        ProfilePill(label: 'Chapter $chapterName', style: ProfilePillStyle.soft),
    ];

    final congressional = _cleanText(_member.congressionalDistrict);
    final house = _cleanText(_member.houseDistrict);
    final senate = _cleanText(_member.senateDistrict);
    final districtChips = <Widget>[
      if (congressional != null)
        profileChip(_formatDistrict(congressional) ?? congressional, icon: Icons.map_outlined),
      if (house != null) profileChip('House $house'),
      if (senate != null) profileChip('Senate $senate'),
    ];

    final blocker = _member.contactBlocker;
    final contactReason = switch (blocker) {
      ContactBlocker.optedOut => 'Opted out',
      ContactBlocker.noPhone => 'No phone on file',
      ContactBlocker.notEligible => 'Not eligible',
      null => null,
    };

    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        ProfileActionPill(
          icon: Icons.message_outlined,
          label: 'Text',
          onPressed: _member.canContact ? _startChat : null,
          disabledReason: contactReason,
        ),
        ProfileActionPill(
          icon: Icons.email_outlined,
          label: 'Email',
          onPressed: _crmReady && _hasEmailRecipient ? _composeEmail : null,
          disabledReason: _hasEmailRecipient ? null : 'No email on file',
          busy: _sendingEmail,
        ),
        ProfileActionPill(
          icon: Icons.auto_awesome_outlined,
          label: 'Intro',
          onPressed: _member.canContact && _crmReady ? _sendIntro : null,
          disabledReason: contactReason,
          busy: _sendingIntro,
        ),
        ProfileActionPill(
          icon: _member.hasProfilePhoto
              ? Icons.photo_camera_outlined
              : Icons.add_a_photo_outlined,
          label: _member.hasProfilePhoto ? 'Update photo' : 'Add photo',
          onPressed: _crmReady && _editingSection == null ? _selectProfilePhoto : null,
          busy: _uploadingPhoto,
        ),
      ],
    );

    final photo = _buildHeaderPhoto(radius: 48);

    final textColumn = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          _member.name,
          style: ProfileText.headerName,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meta.join(' · '),
            style: ProfileText.headerLine,
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
        ],
        if (pills.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            children: pills,
          ),
        ],
        if (districtChips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            children: districtChips,
          ),
        ],
      ],
    );

    Widget content;
    if (wide) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              photo,
              const SizedBox(width: 24),
              Expanded(child: textColumn),
              const SizedBox(width: 16),
              _headerEditButton(),
            ],
          ),
          const SizedBox(height: 24),
          actions,
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [_headerEditButton()]),
          Center(child: photo),
          const SizedBox(height: 16),
          textColumn,
          const SizedBox(height: 20),
          actions,
        ],
      );
    }

    return ProfileSheet(
      children: [
        Padding(
          padding: EdgeInsets.all(wide ? 28 : 20),
          child: content,
        ),
      ],
    );
  }

  /// The gold pencil pill on the hero card. Opens About plus the two executive
  /// title fields as one group.
  Widget _headerEditButton() {
    return profileEditButton(
      section: 'About and title',
      onPressed: _crmReady ? () => _beginEdit(_aboutTitleGroup) : null,
    );
  }

  /// The real photo. effectiveAvatarUrl prefers the member's own upload and
  /// falls through profile_pictures via MemberProfilePhoto.publicUrl; every
  /// executive has profile_pictures and none has avatar_url, so a raw
  /// avatar_url read is exactly why everyone showed initials before. The
  /// 3 px sunriseGold ring is a mark, not text; the initials fallback is white
  /// on solid unityBlue, 12.51:1. Tap to update.
  Widget _buildHeaderPhoto({required double radius}) {
    final avatar = CorsAwareAvatar(
      imageUrl: _member.effectiveAvatarUrl,
      radius: radius,
      backgroundColor: ProfileTokens.fill,
      fallbackText: _member.name,
      fallbackTextColor: Colors.white,
      fallbackIconColor: Colors.white,
    );

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _crmReady && !_uploadingPhoto && _editingSection == null
            ? _selectProfilePhoto
            : null,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: BrandColors.sunriseGold, width: 3),
          ),
          child: _uploadingPhoto
              ? SizedBox(
                  width: radius * 2,
                  height: radius * 2,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : avatar,
        ),
      ),
    );
  }

  // ── The section cards, read mode and edit mode ───────────────

  /// One card per section that has something to show or is being edited, in
  /// the order the member filled the form in, plus the sections omitted for
  /// having nothing to show. The list never comes back empty, so the page
  /// never reads as broken.
  ({List<Widget> cards, List<_ProfileSection> omitted}) _buildSectionCards() {
    final cards = <Widget>[];
    final omitted = <_ProfileSection>[];
    for (final section in _profileSections) {
      final built = _buildProfileSection(section, first: cards.isEmpty);
      if (built == null) {
        omitted.add(section);
      } else {
        cards.add(built);
      }
    }
    if (cards.isEmpty) {
      final firstName = _member.name.trim().split(RegExp(r'\s+')).first;
      cards.add(
        ProfileSectionCard(
          title: 'Profile',
          icon: Icons.person_outline,
          child: Text('Only a name is on file for $firstName.', style: ProfileText.value),
        ),
      );
    }
    return (cards: cards, omitted: omitted);
  }

  /// One "+ Section" chip per omitted section, on the last card of the grid.
  /// This is how a hidden field becomes editable without showing empty rows in
  /// read mode.
  Widget _buildAddSectionsCard(List<_ProfileSection> omitted) {
    return ProfileSectionCard(
      title: 'Add to profile',
      icon: Icons.add_circle_outline,
      caption: 'These sections have nothing on file yet.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final section in omitted)
            profileAddChip(
              title: section.title,
              onTap: () => _beginEdit(section.id),
            ),
        ],
      ),
    );
  }

  /// Returns null when the section has nothing to show and is not being
  /// edited. In edit mode every field of the section renders as an input,
  /// empty ones included, so edit mode is the complete form and read mode is
  /// the filled part of it.
  Widget? _buildProfileSection(_ProfileSection section, {required bool first}) {
    final editingGroup = _editingSection == _aboutTitleGroup && section.id == 'about';
    final editing = _editingSection == section.id || editingGroup;

    if (editing) {
      final title = editingGroup ? 'About and title' : section.title;
      final fields = _fieldsForEdit(_editingSection!);
      return ProfileSectionCard(
        title: title,
        icon: section.icon,
        child: _buildSectionEditor(section, title, fields),
      );
    }

    final addressShown = _buildAddressParts(
      street: _member.address,
      city: _member.city,
      county: _member.county,
      state: _member.state,
    ).isNotEmpty;

    final items = <ProfileFlowItem>[];
    for (final field in section.fields) {
      if (field.onlyWithoutAddress && addressShown) continue;
      final built = _readField(field);
      if (built != null) items.add(ProfileFlowItem(built, isLong: field.isLong));
    }
    if (items.isEmpty) return null;

    String? caption = section.caption;
    if (section.id == 'districts' && _districtsRefreshing) {
      caption = 'Updating from the new address';
    }

    return ProfileSectionCard(
      title: section.title,
      icon: section.icon,
      caption: caption,
      trailing: profileEditButton(
        section: section.title,
        onPressed: _crmReady ? () => _beginEdit(section.id) : null,
      ),
      child: ProfileFieldFlow(items: items),
    );
  }

  Map<String, dynamic> get _memberJson => _member.toJson();

  DateTime? _dateFor(String key) {
    switch (key) {
      case 'date_of_birth':
        return _member.dateOfBirth;
      case 'date_elected':
        return _member.dateElected;
      case 'term_expiration':
        return _member.termExpiration;
    }
    return null;
  }

  bool? _boolFor(String key) {
    switch (key) {
      case 'registered_voter':
        return _member.registeredVoter;
      case 'hispanic_latino':
        return _member.hispanicLatino;
    }
    return null;
  }

  /// A field in read mode, or null when its cleaned value is empty.
  Widget? _readField(_ProfileField field) {
    switch (field.kind) {
      case _FieldKind.text:
      case _FieldKind.longText:
      case _FieldKind.email:
      case _FieldKind.chipsText:
        final cleaned = _cleanText(_memberJson[field.key]?.toString());
        if (cleaned == null) return null;
        final String value = field.key == 'congressional_district'
            ? (_formatDistrict(cleaned) ?? cleaned)
            : cleaned;
        if (field.key == 'school_name' &&
            (_cleanText(_member.college) != null || _cleanText(_member.highSchool) != null)) {
          return null;
        }
        if (field.kind == _FieldKind.longText) {
          return ProfileLongText(label: field.label, value: value);
        }
        if (field.kind == _FieldKind.chipsText && value.contains(',')) {
          final parts = value
              .split(',')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList();
          return profileChips(parts, label: field.label);
        }
        if (field.kind == _FieldKind.email) {
          return ProfileField(
            label: field.label,
            value: value,
            onCopy: () => _copyToClipboard(field.label, value),
          );
        }
        return ProfileField(label: field.label, value: value);

      case _FieldKind.districts:
        return null;

      case _FieldKind.phone:
        final display = _cleanText(_member.phone) ?? _cleanText(_member.phoneE164);
        if (display == null) return null;
        final copyValue = _cleanText(_member.phoneE164) ?? display;
        return ProfileField(
          label: field.label,
          value: display,
          onCopy: () => _copyToClipboard(field.label, copyValue),
        );

      case _FieldKind.date:
        final date = _dateFor(field.key);
        if (date == null) return null;
        var text = _formatDateOnly(date);
        if (field.key == 'date_of_birth' && _member.age != null) {
          text = '$text (${_member.age})';
        }
        return ProfileField(label: field.label, value: text);

      case _FieldKind.triBool:
        final value = _boolFor(field.key);
        if (value == null) return null;
        return ProfileField(label: field.label, value: value ? 'Yes' : 'No');

      case _FieldKind.social:
        final raw = _cleanText(_memberJson[field.key]?.toString());
        if (raw == null) return null;
        final uri = _resolveSocialLink(field.platform!, raw);
        final display = _formatSocialDisplay(field.platform!, raw, uri);
        final copyTarget = uri?.toString() ?? raw;
        return ProfileField(
          label: field.label,
          value: display,
          link: uri,
          onOpenLink: _openLink,
          onCopy: () => _copyToClipboard(field.label, copyTarget),
        );

      case _FieldKind.addressBlock:
        final parts = _buildAddressParts(
          street: _member.address,
          city: _member.city,
          county: _member.county,
          state: _member.state,
        );
        if (parts.isEmpty) return null;
        final link = _buildAppleMapsLink(parts);
        return ProfileField(
          label: field.label,
          value: parts.join('\n'),
          link: link,
          onOpenLink: _openLink,
          onCopy: () => _copyToClipboard(field.label, parts.join(', ')),
        );

      case _FieldKind.committees:
        final committees = _member.committee ?? const <String>[];
        if (committees.isEmpty) return null;
        return profileChips(
          _orderedCommittees(committees),
          label: field.label,
          locked: const {_executiveCommittee},
        );
    }
  }

  static const String _executiveCommittee = 'Executive Committee';

  /// Executive Committee first when present, then the rest in stored order.
  List<String> _orderedCommittees(List<String> committees) {
    final rest = committees.where((c) => c != _executiveCommittee).toList();
    if (committees.contains(_executiveCommittee)) {
      return [_executiveCommittee, ...rest];
    }
    return rest;
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  // ── Sheet 1: the edit affordance ─────────────────────────────

  /// Which fields an edit group carries. The header pencil opens About plus
  /// the member's name and the two executive text fields as one group.
  List<_ProfileField> _fieldsForEdit(String groupId) {
    if (groupId == _aboutTitleGroup) {
      return [
        const _ProfileField('name', 'Name', capitalizeWords: true),
        ..._profileSections.firstWhere((s) => s.id == 'about').fields,
        const _ProfileField('executive_title', 'Executive title'),
        const _ProfileField('executive_role', 'Executive role'),
      ];
    }
    return _profileSections.firstWhere((s) => s.id == groupId).fields;
  }

  _ProfileSection _sectionForEdit(String groupId) {
    final id = groupId == _aboutTitleGroup ? 'about' : groupId;
    return _profileSections.firstWhere((s) => s.id == id);
  }

  /// Opens a section in edit mode. One section at a time: opening another
  /// asks before discarding a dirty one.
  Future<void> _beginEdit(String groupId) async {
    if (!_crmReady || _savingSection) return;
    if (_editingSection == groupId) return;

    if (_editingSection != null && _editIsDirty()) {
      final openTitle = _editingSection == _aboutTitleGroup
          ? 'About and title'
          : _sectionForEdit(_editingSection!).title;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _profileDialog(
          dialogContext,
          title: 'Discard changes to $openTitle?',
          body: 'The edits you made to $openTitle have not been saved.',
          cancelLabel: 'Keep editing',
          confirmLabel: 'Discard',
        ),
      );
      if (discard != true || !mounted) return;
    }

    // One read seeds the controllers AND supplies the row version the save is
    // guarded on. They have to come from the same read: a token belonging to a
    // different row version would either refuse a good save or, worse, pass a
    // save whose diff was taken against something else.
    final snapshot = await _memberRepo.getMemberSnapshotById(_member.id);
    if (!mounted) return;
    if (snapshot == null || snapshot.updatedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read this member to edit it. Check your connection and '
            'try again.',
          ),
        ),
      );
      return;
    }

    // Assigned before the seeding loop and outside setState on purpose: the
    // loop reads _member for phone, dates and tri-state values, so the row it
    // seeds from has to be in place first, and the single setState at the end
    // of this method is what publishes all of it in one frame.
    _disposeEditControllers();
    _member = snapshot.member;
    _editBaseline = snapshot.member;
    _editBaselineUpdatedAt = snapshot.updatedAt;
    _memberLookup.cacheMember(snapshot.member);

    final original = _diffBase.toJson();
    for (final field in _fieldsForEdit(groupId)) {
      switch (field.kind) {
        case _FieldKind.date:
          final date = _dateFor(field.key);
          _editDates[field.key] = date;
          _addEditController(field.key, date == null ? '' : _formatDateOnly(date));
          break;
        case _FieldKind.triBool:
          _editBools[field.key] = _boolFor(field.key);
          break;
        case _FieldKind.phone:
          _addEditController(
            field.key,
            _cleanText(_member.phone) ?? _cleanText(_member.phoneE164) ?? '',
          );
          break;
        case _FieldKind.addressBlock:
          for (final key in _addressKeys) {
            _addEditController(key, _cleanText(original[key]?.toString()) ?? '');
          }
          break;
        case _FieldKind.committees:
          _editCommittees = (_member.committee ?? const <String>[])
              .where((c) => c != _executiveCommittee)
              .toSet();
          _addEditController('committee_new', '');
          unawaited(_loadKnownCommittees());
          break;
        case _FieldKind.districts:
          break;
        case _FieldKind.text:
        case _FieldKind.longText:
        case _FieldKind.email:
        case _FieldKind.chipsText:
        case _FieldKind.social:
          _addEditController(field.key, _cleanText(original[field.key]?.toString()) ?? '');
          break;
      }
    }

    setState(() {
      _editingSection = groupId;
      _editError = null;
      _editErrorTitle = null;
      _showCommitteeInput = false;
      if (!_editingNotes) {
        _notesController.text = _member.notes ?? '';
      }
    });
  }

  static const List<String> _addressKeys = ['address', 'city', 'state', 'county'];

  void _addEditController(String key, String text) {
    final controller = TextEditingController(text: text);
    // Save is disabled while nothing has changed, so every keystroke has to
    // re-evaluate the diff.
    controller.addListener(_onEditChanged);
    _editControllers[key] = controller;
  }

  void _onEditChanged() {
    if (mounted) setState(() {});
  }

  /// Detaches the edit controllers now and disposes them after the frame, so
  /// a TextFormField still mounted for one more build never touches a disposed
  /// controller. [immediately] is for dispose(), where there is no next frame.
  void _disposeEditControllers({bool immediately = false}) {
    final retired = List<TextEditingController>.of(_editControllers.values);
    for (final controller in retired) {
      controller.removeListener(_onEditChanged);
    }
    _editControllers.clear();
    _editDates.clear();
    _editBools.clear();
    _editCommittees = <String>{};
    if (immediately) {
      for (final controller in retired) {
        controller.dispose();
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in retired) {
        controller.dispose();
      }
    });
  }

  Future<void> _loadKnownCommittees() async {
    final known = await _memberRepo.getUniqueCommittees();
    if (!mounted) return;
    setState(() => _knownCommittees = known);
  }

  void _cancelEdit() {
    if (_savingSection) return;
    _disposeEditControllers();
    setState(() {
      _editingSection = null;
      _editError = null;
      _editErrorTitle = null;
      _editBaseline = null;
      _editBaselineUpdatedAt = null;
    });
  }

  /// Re-bases the open editor on a row THIS screen just wrote. The diff
  /// baseline and the guard token move together because they describe the same
  /// row version; moving one without the other would either revert a field or
  /// refuse the next save for no reason. Call inside setState.
  void _rebaseOpenEdit(MemberSnapshot snapshot) {
    if (_editingSection == null) return;
    _editBaseline = snapshot.member;
    _editBaselineUpdatedAt = snapshot.updatedAt;
  }

  bool _editIsDirty() => _computeUpdates().isNotEmpty || _committeesChanged();

  bool _committeesChanged() {
    if (_editingSection != 'chapter') return false;
    final current = (_diffBase.committee ?? const <String>[])
        .where((c) => c != _executiveCommittee)
        .toSet();
    return !const SetEquality<String>().equals(current, _editCommittees);
  }

  /// Diff the inputs against the row the editor was SEEDED from, exactly as
  /// the retired edit sheet did: only changed keys go in the payload, a cleared value
  /// writes null, unchanged keys are omitted. committee never appears here (it
  /// goes through the RPC) and executive_committee has no input at all.
  ///
  /// The base is _editBaseline and never _member. A row that arrives from
  /// anywhere else while the editor is open would otherwise differ from this
  /// exec's untouched controller, enter the diff as an edit nobody made, and be
  /// written back over whoever really changed it.
  Map<String, dynamic> _computeUpdates() {
    final groupId = _editingSection;
    if (groupId == null) return const {};
    final original = _diffBase.toJson();
    final updates = <String, dynamic>{};

    void diffText(String key) {
      final controller = _editControllers[key];
      if (controller == null) return;
      final text = controller.text.trim();
      final originalText = (original[key]?.toString() ?? '').trim();
      if (text.isEmpty && originalText.isEmpty) return;
      if (text.isEmpty) {
        updates[key] = null;
      } else if (text != originalText) {
        updates[key] = text;
      }
    }

    for (final field in _fieldsForEdit(groupId)) {
      switch (field.kind) {
        case _FieldKind.text:
        case _FieldKind.longText:
        case _FieldKind.email:
        case _FieldKind.chipsText:
        case _FieldKind.social:
          diffText(field.key);
          break;
        case _FieldKind.addressBlock:
          for (final key in _addressKeys) {
            diffText(key);
          }
          break;
        case _FieldKind.date:
          final picked = _editDates[field.key];
          final newText = picked == null ? null : _isoDate(picked);
          final originalText = _cleanText(original[field.key]?.toString());
          if (newText != originalText) updates[field.key] = newText;
          break;
        case _FieldKind.triBool:
          final newValue = _editBools[field.key];
          final originalValue = original[field.key] as bool?;
          if (newValue != originalValue) updates[field.key] = newValue;
          break;
        case _FieldKind.phone:
          final controller = _editControllers[field.key];
          if (controller == null) break;
          final text = controller.text.trim();
          final originalPhone = _cleanText(original['phone']?.toString());
          final originalE164 = _cleanText(original['phone_e164']?.toString());
          if (text.isEmpty) {
            if (originalPhone != null) updates['phone'] = null;
            if (originalE164 != null) updates['phone_e164'] = null;
          } else {
            final normalized = _normalizePhone(text);
            if (text != originalPhone) updates['phone'] = text;
            if (normalized != null && normalized != originalE164) {
              updates['phone_e164'] = normalized;
            }
          }
          break;
        case _FieldKind.committees:
        case _FieldKind.districts:
          break;
      }
    }
    return updates;
  }

  String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// E.164 from what an exec types, in this order: strip everything but digits
  /// and a leading plus; 10 digits get +1; 11 digits starting with 1 get +;
  /// a leading plus with 8 to 15 digits after it is kept; anything else is
  /// invalid. cleansePhoneNumber in string_utils only strips characters, it
  /// does not produce E.164, so it is not used here. phone_e164 is the
  /// messaging key (Handle.address), so a wrong value silently breaks contact.
  String? _normalizePhone(String raw) {
    final trimmed = raw.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (hasPlus) {
      if (digits.length >= 8 && digits.length <= 15) return '+$digits';
      return null;
    }
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    return null;
  }

  static const _emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (RegExp(_emailPattern).hasMatch(text)) return null;
    return 'Enter a valid email address';
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (_normalizePhone(text) != null) return null;
    return 'Enter a phone number with area code';
  }

  /// The section body in edit mode: cascade banner, every field as an input,
  /// the inline error if the last save failed, then Cancel and Save.
  Widget _buildSectionEditor(_ProfileSection section, String title, List<_ProfileField> fields) {
    final dirty = _editIsDirty();
    final items = <ProfileFlowItem>[
      for (final field in fields)
        ProfileFlowItem(_editField(field), isLong: field.isLong || field.kind == _FieldKind.committees),
    ];

    return Form(
      key: _editFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.cascade.isNotEmpty) profileCascadeBanner(section.cascade),
          ProfileFieldFlow(items: items),
          if (_editError != null)
            profileErrorBanner(
              // A partial save is not "could not save": part of it committed,
              // and the banner has to say which part.
              title: _editErrorTitle ?? 'Could not save $title',
              message: _editError!,
            ),
          profileEditActions(
            onCancel: _cancelEdit,
            onSave: dirty ? () => _saveSection(title) : null,
            saving: _savingSection,
          ),
        ],
      ),
    );
  }

  Widget _editInputPadding(Widget child) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child);
  }

  Widget _editField(_ProfileField field) {
    switch (field.kind) {
      case _FieldKind.text:
      case _FieldKind.chipsText:
      case _FieldKind.social:
      case _FieldKind.email:
        if (field.readOnly) return _readOnlyEditField(field);
        return _editInputPadding(
          TextFormField(
            controller: _editControllers[field.key],
            style: profileInputText,
            cursorColor: ProfileTokens.ink,
            textCapitalization:
                field.capitalizeWords ? TextCapitalization.words : TextCapitalization.none,
            keyboardType:
                field.kind == _FieldKind.email ? TextInputType.emailAddress : TextInputType.text,
            validator: field.kind == _FieldKind.email ? _validateEmail : null,
            decoration: profileInput(field.label, helper: field.helper),
          ),
        );

      case _FieldKind.longText:
        return _editInputPadding(
          TextFormField(
            controller: _editControllers[field.key],
            style: profileInputText,
            cursorColor: ProfileTokens.ink,
            minLines: 3,
            maxLines: 8,
            decoration: profileInput(field.label),
          ),
        );

      case _FieldKind.phone:
        return _editInputPadding(
          TextFormField(
            controller: _editControllers[field.key],
            style: profileInputText,
            cursorColor: ProfileTokens.ink,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
            decoration: profileInput(field.label),
          ),
        );

      case _FieldKind.date:
        return _editInputPadding(_dateInput(field));

      case _FieldKind.triBool:
        return _editInputPadding(_triStateInput(field));

      case _FieldKind.addressBlock:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in const [
              ('address', 'Street address', false),
              ('city', 'City', true),
              ('state', 'State', false),
              ('county', 'County', true),
            ])
              _editInputPadding(
                TextFormField(
                  controller: _editControllers[entry.$1],
                  style: profileInputText,
                  cursorColor: ProfileTokens.ink,
                  textCapitalization:
                      entry.$3 ? TextCapitalization.words : TextCapitalization.none,
                  decoration: profileInput(entry.$2),
                ),
              ),
          ],
        );

      case _FieldKind.districts:
        return _readOnlyEditField(field);

      case _FieldKind.committees:
        return _committeeEditor(field);
    }
  }

  /// Derived columns render in edit mode as they do in read mode, with the
  /// reason they cannot be typed into. A hand edit to a district would be
  /// overwritten on the next address save.
  Widget _readOnlyEditField(_ProfileField field) {
    final read = _readField(field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        read ?? ProfileField(label: field.label, value: 'Not on file'),
        if (field.helper != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(field.helper!, style: ProfileText.caption),
          ),
      ],
    );
  }

  Widget _dateInput(_ProfileField field) {
    final controller = _editControllers[field.key];
    final hasValue = _editDates[field.key] != null;

    Future<void> pick() async {
      final initial = _editDates[field.key] ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
        builder: (context, child) => Theme(
          data: profileDatePickerTheme(context),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (picked == null || !mounted) return;
      setState(() {
        _editDates[field.key] = picked;
        controller?.text = _formatDateOnly(picked);
      });
    }

    return TextFormField(
      controller: controller,
      readOnly: true,
      style: profileInputText,
      onTap: pick,
      decoration: profileInput(
        field.label,
        helper: field.helper,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasValue)
              IconButton(
                tooltip: 'Clear ${field.label}',
                icon: Icon(Icons.clear, size: 18, color: ProfileTokens.inkMuted),
                onPressed: () => setState(() {
                  _editDates[field.key] = null;
                  controller?.text = '';
                }),
              ),
            IconButton(
              tooltip: 'Pick ${field.label}',
              icon: Icon(Icons.calendar_today_outlined, size: 18, color: ProfileTokens.inkMuted),
              onPressed: pick,
            ),
          ],
        ),
      ),
    );
  }

  Widget _triStateInput(_ProfileField field) {
    final value = _editBools[field.key];
    final selected = value == null
        ? _TriState.unanswered
        : (value ? _TriState.yes : _TriState.no);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label.toUpperCase(), style: ProfileText.label),
        const SizedBox(height: 8),
        SegmentedButton<_TriState>(
          style: profileSegmentedStyle(),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _TriState.yes, label: Text('Yes')),
            ButtonSegment(value: _TriState.no, label: Text('No')),
            ButtonSegment(value: _TriState.unanswered, label: Text('Not answered')),
          ],
          selected: {selected},
          onSelectionChanged: (set) {
            final pick = set.first;
            setState(() {
              _editBools[field.key] = switch (pick) {
                _TriState.yes => true,
                _TriState.no => false,
                _TriState.unanswered => null,
              };
            });
          },
        ),
      ],
    );
  }

  /// Toggle chips from getUniqueCommittees merged with the member's own list,
  /// so a committee only this member holds still appears. Executive Committee
  /// is rendered locked and never toggled here: it gates CRM access and
  /// changes only through Superadmin > Executives.
  Widget _committeeEditor(_ProfileField field) {
    final current = _member.committee ?? const <String>[];
    final hasExecutive = current.contains(_executiveCommittee);
    final options = <String>{
      ..._knownCommittees,
      ...current,
      ..._editCommittees,
    }..remove(_executiveCommittee);
    final sorted = options.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    Widget chip({
      required String label,
      required bool selected,
      required bool enabled,
      bool locked = false,
    }) {
      return FilterChip(
        label: Text(label),
        avatar: locked ? const Icon(Icons.lock_outline, size: 14) : null,
        selected: selected,
        showCheckmark: false,
        onSelected: enabled
            ? (value) => setState(() {
                  if (value) {
                    _editCommittees.add(label);
                  } else {
                    _editCommittees.remove(label);
                  }
                })
            : null,
        // Selected: the emphasis pair, sunriseGold under unityBlue, 7.17:1.
        // Unselected: solid unityBlue under white, 12.51:1, with a solid white
        // outline so the chip keeps an edge at the card's dark end. Disabled
        // keeps the same pair so the locked chip stays legible.
        selectedColor: ProfileTokens.emphasisFill,
        backgroundColor: ProfileTokens.fill,
        disabledColor: selected ? ProfileTokens.emphasisFill : ProfileTokens.fill,
        labelStyle: ProfileText.chip.copyWith(
          color: selected ? ProfileTokens.onEmphasis : Colors.white,
        ),
        iconTheme: IconThemeData(
          color: selected ? ProfileTokens.onEmphasis : Colors.white,
          size: 14,
        ),
        side: BorderSide(
          color: selected ? ProfileTokens.emphasisFill : ProfileTokens.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      );
    }

    final newController = _editControllers['committee_new'];

    void addNew() {
      final name = newController?.text.trim() ?? '';
      if (name.isEmpty) return;
      if (name == _executiveCommittee) {
        setState(() {
          _editError = 'Executive Committee is managed in Superadmin > Executives.';
        });
        return;
      }
      setState(() {
        _editCommittees.add(name);
        newController?.clear();
        _showCommitteeInput = false;
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label.toUpperCase(), style: ProfileText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasExecutive)
                chip(label: _executiveCommittee, selected: true, enabled: false, locked: true),
              for (final option in sorted)
                chip(
                  label: option,
                  selected: _editCommittees.contains(option),
                  enabled: true,
                ),
              profileAddChip(
                title: 'Add',
                onTap: () => setState(() => _showCommitteeInput = true),
              ),
            ],
          ),
          if (_showCommitteeInput) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: newController,
              autofocus: true,
              style: profileInputText,
              cursorColor: ProfileTokens.ink,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => addNew(),
              decoration: profileInput(
                'New committee',
                suffixIcon: IconButton(
                  tooltip: 'Add committee',
                  icon: Icon(Icons.add, size: 18, color: ProfileTokens.inkMuted),
                  onPressed: addNew,
                ),
              ),
            ),
          ],
          if (hasExecutive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Executive Committee membership is managed in Superadmin > Executives.',
                style: ProfileText.caption,
              ),
            ),
        ],
      ),
    );
  }

  /// Solid unityBlue dialog, radius 16, max width 480, padding 24, white ink
  /// (12.51:1). The confirm button is the emphasis pair for an ordinary choice
  /// (sunriseGold under unityBlue, 7.17:1) and solid #B91C1C under white
  /// (6.47:1) for the one write on this page that touches auth. The dialog is
  /// a flat navy ground rather than a gradient so its edge reads against the
  /// barrier and no button sits on a changing fill.
  Widget _profileDialog(
    BuildContext dialogContext, {
    required String title,
    required String body,
    required String cancelLabel,
    required String confirmLabel,
    bool destructive = false,
  }) {
    final confirmFill = destructive ? ProfileTokens.danger : ProfileTokens.emphasisFill;
    final confirmInk = destructive ? Colors.white : ProfileTokens.onEmphasis;
    return Dialog(
      backgroundColor: ProfileTokens.band,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ProfileTokens.sheetRadius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ProfileText.sectionTitle),
              const SizedBox(height: 14),
              Text(body, style: ProfileText.caption),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      textStyle: ProfileText.button,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmFill,
                      foregroundColor: confirmInk,
                      textStyle: ProfileText.button,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The one field whose save is not a plain update. Both consequences from
  /// the write hazards are stated in plain words before the write runs.
  /// The wording follows the trigger as it is now written, and nothing further.
  /// It used to promise that the save "rewrites the member's login identity",
  /// which was not true of every member: the trigger keyed on members.id, and
  /// for anyone whose members.user_id points at a different account that is the
  /// wrong row. The trigger now follows user_id and falls back to id only when
  /// user_id is null, so there are three outcomes and the copy names all three
  /// rather than promising the one that usually happens.
  Future<bool> _confirmEmailChange(String? newEmail) async {
    final oldEmail = _cleanText(_member.email) ?? 'none on file';
    final body = 'Saving a new email address does this, and you cannot undo it from here.\n\n'
        'Sign-in: the new address is written to the account this member signs in with, '
        'which is their linked login account, or their own member record if no login has '
        'been linked yet. They keep the same password and get no confirmation email. If '
        'this member has no login account at all, nothing about signing in changes and only '
        'the member record is updated.\n\n'
        'The save is refused outright if another account already uses this address, '
        'ignoring capitalisation, or if you clear the address entirely. Nothing is written '
        'in either case.\n\n'
        'Mautic: the member is re-synced. Mautic matches on email, so a new address can '
        'create a second Mautic contact and point this member at it, leaving the old contact '
        'and its history behind.\n\n'
        'From: $oldEmail\n'
        'To: ${newEmail ?? 'none'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _profileDialog(
        dialogContext,
        title: 'Change this member\'s email?',
        body: body,
        cancelLabel: 'Cancel',
        confirmLabel: 'Change email',
        destructive: true,
      ),
    );
    return confirmed == true;
  }

  /// Save the open section. Only changed keys go to the guarded field write;
  /// the server row it returns becomes _member (never the local edits merged
  /// in, because for class B fields the returned row is the state BEFORE the
  /// async trigger lands). committee goes through crm_set_member_committees,
  /// which preserves Executive Committee no matter what is sent.
  ///
  /// Two properties this method has to hold, both of which it used to break.
  ///
  /// The screen always shows what COMMITTED. This is two writes, and the second
  /// can fail after the first landed. The old code assigned _member only on the
  /// all-succeeded path, so a committee failure after a successful field write
  /// left the exec looking at their pre-save values while the server row held
  /// the new ones. Now `current` accumulates whatever came back and is assigned
  /// on EVERY exit, so there is no path that commits a write and hides it.
  ///
  /// The failure message says WHICH part failed and what survived. A single
  /// "Could not save X" over a half-applied save is worse than no message,
  /// because it invites the exec to retype values that are already stored.
  Future<void> _saveSection(String title) async {
    if (_savingSection) return;
    final form = _editFormKey.currentState;
    if (form != null && !form.validate()) return;

    final updates = _computeUpdates();
    final committeesChanged = _committeesChanged();
    if (updates.isEmpty && !committeesChanged) return;

    // The guard token is captured with the row the editor was seeded from. Its
    // absence means the editor was opened without one, which _beginEdit refuses
    // to do, so this is a real defensive stop rather than a fallback to an
    // unguarded write.
    final expectedUpdatedAt = _editBaselineUpdatedAt;
    if (expectedUpdatedAt == null) {
      setState(() {
        _editErrorTitle = 'Cannot save $title safely';
        _editError = 'This screen has lost track of which version of the member '
            'it is editing, so it will not write over the record blind. Cancel '
            'this edit and open it again.';
      });
      return;
    }

    if (updates.containsKey('email')) {
      final confirmed = await _confirmEmailChange(updates['email'] as String?);
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _savingSection = true;
      _editError = null;
      _editErrorTitle = null;
    });

    var current = _member;
    var fieldsCommitted = false;
    var committeesCommitted = false;
    String? failedPart;
    Object? failure;

    if (updates.isNotEmpty) {
      try {
        final saved = await _memberRepo.updateMemberFieldsGuarded(
          _member.id,
          updates,
          expectedUpdatedAt: expectedUpdatedAt,
        );
        if (saved == null) {
          throw StateError('The server did not return the saved member row.');
        }
        current = saved.member;
        fieldsCommitted = true;
        // The row moved, so the baseline and the token move with it. A retry
        // after a committee failure then sends only what is still unsaved and
        // guards on the version this write produced.
        if (mounted) setState(() => _rebaseOpenEdit(saved));
      } catch (e) {
        failedPart = 'fields';
        failure = e;
      }
    }

    if (failure == null && committeesChanged) {
      try {
        await _supabaseService.client.rpc(
          'crm_set_member_committees',
          params: {
            'p_member_id': _member.id,
            'p_committees': _editCommittees.toList(),
          },
        );
        committeesCommitted = true;
      } catch (e) {
        failedPart = 'committees';
        failure = e;
      }

      // Reloaded whether or not the RPC threw, because the RPC's own failure
      // does not prove it wrote nothing, and because the field write above may
      // have committed. Reading here is the only way the screen can show what
      // the server actually holds.
      try {
        final refreshed = await _memberRepo.getMemberSnapshotById(_member.id);
        if (refreshed == null) {
          throw StateError('The member could not be reloaded.');
        }
        current = refreshed.member;
        if (mounted) setState(() => _rebaseOpenEdit(refreshed));
      } catch (e) {
        failedPart = committeesCommitted ? 'committee reload' : failedPart;
        failure ??= e;
      }
    }

    if (!mounted) return;

    final addressChanged = _addressKeys.any(updates.containsKey);

    if (failure == null) {
      final consequences = <String>[
        if (updates.containsKey('phone') || updates.containsKey('phone_e164'))
          'Texts now go to the new number.',
        if (addressChanged) 'Districts are recomputing.',
        if (updates.containsKey('date_of_birth')) 'Eligibility recomputed.',
        if (updates.containsKey('email')) 'Login and Mautic contact updated.',
        if (committeesChanged) 'Slack channel membership is syncing.',
        'Mautic will refresh this contact.',
      ];

      _disposeEditControllers();
      setState(() {
        _member = current;
        if (!_editingNotes) _notesController.text = current.notes ?? '';
        _editingSection = null;
        _editBaseline = null;
        _editBaselineUpdatedAt = null;
        _savingSection = false;
        if (addressChanged) _districtsRefreshing = true;
      });
      _memberLookup.cacheMember(current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title saved. ${consequences.join(' ')}')),
      );
      if (addressChanged) unawaited(_refetchAfterDistrictTrigger());
      return;
    }

    // Failure. The editor stays open with every typed value intact, and the row
    // on screen becomes whatever the server confirmed, so a partly applied save
    // is visible rather than hidden behind the old values.
    final saved = <String>[
      if (fieldsCommitted) 'the field changes',
      if (committeesCommitted) 'the committee changes',
    ];
    final String headline;
    switch (failedPart) {
      case 'fields':
        headline = failure is StaleMemberWriteException
            ? 'Nothing was saved: this member changed while you were editing'
            : 'Nothing was saved to $title';
        break;
      case 'committees':
        headline = 'Part of $title was saved';
        break;
      default:
        headline = 'Saved, but this screen could not be refreshed';
    }

    final detail = StringBuffer();
    if (saved.isEmpty) {
      detail.write('Nothing was written. ');
    } else {
      detail.write('Already saved: ${saved.join(' and ')}. ');
    }
    if (failedPart == 'fields' && failure is StaleMemberWriteException) {
      detail.write(
        'Someone else changed this member after you opened the editor, so the '
        'write was refused rather than overwriting them. Cancel this edit and '
        'open it again to see their version, then re-apply your changes. ',
      );
    } else if (failedPart == 'committees') {
      detail.write('The committee change failed and was not applied. ');
    } else if (failedPart == 'committee reload') {
      detail.write(
        'The committee change was applied, but this screen could not read the '
        'member back, so what you see may be out of date. Refresh to check. ',
      );
    }
    detail.write(failure.toString());

    setState(() {
      _member = current;
      _savingSection = false;
      _editErrorTitle = headline;
      _editError = detail.toString();
    });
    _memberLookup.cacheMember(current);
  }

  /// on_member_updated_lookup_districts runs after the address write; four
  /// seconds is long enough for it to land so S3 shows the recomputed
  /// districts rather than the stale ones.
  Future<void> _refetchAfterDistrictTrigger() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    await _fetchLatestMember(showFeedback: false);
    if (!mounted) return;
    setState(() => _districtsRefreshing = false);
  }

  // ── The record cards: what the CRM knows ─────────────────────

  /// Every record card that has something to show, in order. Each is its own
  /// gradient card and joins the section cards in the grid.
  List<Widget> _buildRecordCards() {
    final cards = <Widget>[];
    void add(Widget? card) {
      if (card != null) cards.add(card);
    }

    add(_buildStatusStrip(first: true));
    add(_buildNotesBlock());
    if (_crmReady) add(_buildInternalReportsBlock());
    add(_buildMeetingsBlock());
    add(_buildMemberActivityBlock(first: false));
    add(_buildDonorBlock());
    add(_buildWalletBlock());
    if (_voterRecord != null) {
      add(
        ProfileSectionCard(
          title: 'Voter file',
          icon: Icons.how_to_reg_outlined,
          child: VoterCrossRefCard(
            record: _voterRecord!,
            memberDateOfBirth: _member.dateOfBirth,
          ),
        ),
      );
    }
    add(
      ProfileSectionCard(
        title: 'Outreach',
        icon: Icons.campaign_outlined,
        child: MemberOutreachSection(member: _member),
      ),
    );
    return cards;
  }

  /// Membership status: the facts, each rendered only when set, with the
  /// opt-out control at the trailing edge. Always renders. [first] is kept for
  /// the caller and ignored.
  Widget _buildStatusStrip({required bool first}) {
    final facts = <Widget>[
      if (_member.dateJoined != null) profileFact('Joined', _formatDateOnly(_member.dateJoined!)),
      if (_member.createdAt != null) profileFact('Added', _formatDateOnly(_member.createdAt!)),
      if (_member.lastContacted != null)
        profileFact('Last contacted', _formatDate(_member.lastContacted!)),
      if (_member.introSentAt != null) profileFact('Intro sent', _formatDate(_member.introSentAt!)),
      if (_member.optOutDate != null)
        profileFact(
          'Opt out',
          [
            _formatDateOnly(_member.optOutDate!),
            if (_cleanText(_member.optOutReason) != null) _cleanText(_member.optOutReason)!,
          ].join(', '),
        ),
      if (_member.optInDate != null)
        profileFact('Opted back in', _formatDateOnly(_member.optInDate!)),
      if (_member.membershipEligible != null)
        profileFact('Eligible', _member.membershipEligible! ? 'Yes' : 'No'),
      if (_cleanText(_member.moVoterFileId) != null) profileFact('Voter file', 'Linked'),
    ];

    return ProfileSectionCard(
      title: 'Membership status',
      icon: Icons.verified_outlined,
      trailing: profileOutlineButton(
        label: _member.optOut ? 'Opt in' : 'Opt out',
        icon: _member.optOut ? Icons.check_circle_outline : Icons.block_outlined,
        onPressed: _crmReady && !_togglingOptOut ? _toggleOptOut : null,
      ),
      child: facts.isEmpty
          ? Text('No status dates on file.', style: ProfileText.caption)
          : Wrap(spacing: 28, runSpacing: 16, children: facts),
    );
  }

  /// The notes editor. Read state is the quote block with the gold pencil in
  /// the header; edit state is an input, then Cancel and Save. Always renders.
  Widget _buildNotesBlock() {
    final notesValue = _cleanText(_member.notes);

    Widget body;
    if (_editingNotes) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _notesController,
            style: profileInputText,
            cursorColor: Colors.white,
            minLines: 3,
            maxLines: 8,
            decoration: profileInput('Notes'),
          ),
          profileEditActions(
            onCancel: () {
              _notesController.text = _member.notes ?? '';
              setState(() => _editingNotes = false);
            },
            onSave: _saveNotes,
            saving: _savingNotes,
          ),
        ],
      );
    } else if (notesValue != null) {
      body = ProfileLongText(value: notesValue);
    } else {
      body = Text('No notes yet.', style: ProfileText.caption);
    }

    return ProfileSectionCard(
      title: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      trailing: _editingNotes
          ? null
          : profileEditButton(
              section: 'notes',
              onPressed: _crmReady ? () => setState(() => _editingNotes = true) : null,
            ),
      child: body,
    );
  }

  /// The latest meeting and the attendance button. Renders only when there is
  /// attendance to show, it is still loading, or the load failed; the Meetings
  /// tab already carries the empty state.
  Widget? _buildMeetingsBlock() {
    if (!_crmReady) return null;
    if (!_loadingAttendance && _attendanceError == null && _meetingAttendance.isEmpty) {
      return null;
    }

    Widget body;
    if (_loadingAttendance) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    } else if (_attendanceError != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          profileErrorBanner(
            title: 'Could not load meeting attendance',
            message: _attendanceError!,
          ),
          const SizedBox(height: 12),
          profileOutlineButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: _loadMeetingAttendance,
          ),
        ],
      );
    } else {
      final latest = _latestMeeting!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMeetingSummaryRow(latest),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: profileOutlineButton(
              label: 'Meeting attendance (${_meetingAttendance.length})',
              icon: Icons.event_note,
              onPressed: _showMeetingAttendanceSheet,
            ),
          ),
        ],
      );
    }

    return ProfileSectionCard(
      title: 'Meetings',
      icon: Icons.video_camera_front_outlined,
      child: body,
    );
  }

  // ── Donor activity ───────────────────────────────────────────

  /// Renders only on data or on error, never a loading card of its own.
  Widget? _buildDonorBlock() {
    if (!_crmReady || _loadingDonorProfile) return null;

    Widget body;
    if (_donorError != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          profileErrorBanner(
            title: 'Could not load donor details',
            message: _donorError!,
          ),
          const SizedBox(height: 12),
          profileOutlineButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: _loadDonorProfile,
          ),
        ],
      );
    } else {
      final donor = _donorProfile;
      if (donor == null) return null;

      final totalDonated = donor.totalDonated ?? 0;
      final firstDonation = donor.firstDonationAt ?? donor.donations.lastOrNull?.createdAt;
      final lastDonation = donor.lastDonationAt ?? donor.donations.firstOrNull?.createdAt;
      final recentDonations = donor.donations.take(5).toList(growable: false);
      final profileUrl = _buildDonorProfileUrl(donor);

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildDonorStatTile(label: 'Total donated', value: _formatCurrency(totalDonated)),
              _buildDonorStatTile(label: 'Donations', value: donor.donationCount.toString()),
              if (firstDonation != null)
                _buildDonorStatTile(label: 'First donation', value: _formatDateOnly(firstDonation)),
              if (lastDonation != null)
                _buildDonorStatTile(label: 'Last donation', value: _formatDate(lastDonation)),
            ],
          ),
          if (donor.isRecurringDonor)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: profileChip('Recurring donor', emphasis: true, icon: Icons.autorenew),
            ),
          const SizedBox(height: 18),
          if (recentDonations.isNotEmpty) ...[
            Text('RECENT DONATIONS', style: ProfileText.label),
            const SizedBox(height: 8),
            for (final donation in recentDonations) _buildDonationTile(donation),
          ] else
            Text('No donation history on file.', style: ProfileText.caption),
          if (profileUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: profileOutlineButton(
                label: 'View full donor profile',
                icon: Icons.open_in_new,
                onPressed: () => _openLink(profileUrl),
              ),
            ),
        ],
      );
    }

    return ProfileSectionCard(
      title: 'Donor activity',
      icon: Icons.volunteer_activism_outlined,
      child: body,
    );
  }

  Widget _buildDonationTile(_DonationRecord donation) {
    final amountLabel =
        donation.amount != null ? _formatCurrency(donation.amount!) : 'Unknown amount';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_outlined, size: 20, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(amountLabel, style: ProfileText.value),
                Text(_formatDonationSubtitle(donation), style: ProfileText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stat tile inside a card: solid unityBlue with a hairline outline, the
  /// value at 32 bold white (12.51:1) over an 11 w700 label.
  Widget _buildDonorStatTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ProfileTokens.fill,
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        border: Border.all(color: ProfileTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: ProfileText.statValue),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: ProfileText.label),
        ],
      ),
    );
  }

  // ── Wallet pass ──────────────────────────────────────────────

  Widget? _buildWalletBlock() {
    if (!_walletService.isReady) return null;

    final pass = _walletPass;
    Widget body;
    if (_loadingWalletPass) {
      body = Row(
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Loading wallet pass details…', style: ProfileText.caption)),
        ],
      );
    } else if (_walletPassError != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          profileErrorBanner(
            title: 'Could not load wallet pass info',
            message: _walletPassError!,
          ),
          const SizedBox(height: 12),
          profileOutlineButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: _loadWalletPassInfo,
          ),
        ],
      );
    } else if (pass == null) {
      body = Text(
        'No wallet pass has been generated for this member yet.',
        style: ProfileText.caption,
      );
    } else {
      final summary = pass.isActive ? 'Active pass on file.' : 'Pass found but not currently active.';
      final registrationSummary = pass.isRegistered
          ? 'Registered on ${pass.registrationCount} device${pass.registrationCount == 1 ? '' : 's'}.'
          : 'Not registered for push notifications yet.';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$summary $registrationSummary', style: ProfileText.value),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWalletStatusChip('Pass generated', pass.hasPass),
              _buildWalletStatusChip('Active', pass.isActive),
              _buildWalletStatusChip('Push registered', pass.isRegistered),
            ],
          ),
          const SizedBox(height: 14),
          if ((pass.passSerial ?? '').isNotEmpty)
            Text('Pass serial: ${pass.passSerial}', style: ProfileText.caption),
          if (pass.passGeneratedAt != null)
            Text('Generated ${_formatDate(pass.passGeneratedAt!)}', style: ProfileText.caption),
          Text('Registered devices: ${pass.registrationCount}', style: ProfileText.caption),
        ],
      );
    }

    final canSendPush =
        pass != null && pass.hasPass && !_loadingWalletPass && _walletPassError == null;

    return ProfileSectionCard(
      title: 'Wallet pass',
      icon: Icons.wallet_outlined,
      trailing: Tooltip(
        message: 'Refresh wallet pass data',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            onTap: _loadingWalletPass ? null : _loadWalletPassInfo,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: Icon(Icons.refresh, size: 22, color: Colors.white)),
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ProfileActionPill(
              icon: Icons.notifications_active_outlined,
              label: _sendingWalletPush ? 'Sending…' : 'Send push notification',
              onPressed: canSendPush && !_sendingWalletPush ? _sendWalletPushToMember : null,
              disabledReason: canSendPush ? null : 'No pass to notify',
              busy: _sendingWalletPush,
            ),
          ),
        ],
      ),
    );
  }

  /// Active is the emphasis pair, sunriseGold under unityBlue (7.17:1);
  /// inactive is solid unityBlue under white with a white outline (12.51:1).
  Widget _buildWalletStatusChip(String label, bool isActive) {
    return profileChip(
      label,
      emphasis: isActive,
      icon: isActive ? Icons.check_circle : Icons.radio_button_unchecked,
    );
  }

  // ── Internal reports ─────────────────────────────────────────

  Widget _buildInternalReportsBlock() {
    final reports = _member.internalInfo.reports;
    return ProfileSectionCard(
      title: 'Internal reports',
      icon: Icons.folder_shared_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReportComposer(),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Text(
              'No internal reports yet. Add a note or upload supporting documents.',
              style: ProfileText.caption,
            )
          else
            for (final entry in reports) _buildReportEntryTile(entry),
        ],
      ),
    );
  }

  Widget _buildReportComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _reportNotesController,
          style: profileInputText,
          cursorColor: Colors.white,
          minLines: 3,
          maxLines: 6,
          decoration: profileInput('Internal notes about this member'),
        ),
        const SizedBox(height: 12),
        if (_pendingReportFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pendingReportFiles
                  .map(
                    (file) => InputChip(
                      label: Text(file.name, style: ProfileText.chip),
                      backgroundColor: ProfileTokens.fill,
                      deleteIconColor: Colors.white,
                      side: const BorderSide(color: ProfileTokens.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ProfileTokens.chipRadius),
                      ),
                      onDeleted:
                          _savingReportEntry ? null : () => _removePendingReportFile(file),
                    ),
                  )
                  .toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            profileOutlineButton(
              label: 'Add files',
              icon: Icons.attach_file,
              onPressed: _savingReportEntry ? null : _pickReportFiles,
            ),
            const SizedBox(width: 12),
            ProfileActionPill(
              icon: Icons.save_outlined,
              label: _savingReportEntry ? 'Saving...' : 'Save report',
              onPressed: _savingReportEntry ? null : _saveReportEntry,
              busy: _savingReportEntry,
            ),
          ],
        ),
        if (_reportComposerError != null)
          profileErrorBanner(title: 'Could not save report', message: _reportComposerError!),
      ],
    );
  }

  /// One report on a solid unityBlue block with a hairline outline, white
  /// throughout; the edit and delete glyphs are white, and the pending bar is
  /// gold on the hairline.
  Widget _buildReportEntryTile(MemberInternalReportEntry entry) {
    final attachments = entry.attachments;
    final timestamp = entry.updatedAt ?? entry.createdAt;
    final typeLabel = (entry.type ?? (entry.hasAttachments ? 'file' : 'note')).toUpperCase();
    final isUpdating = _updatingReportIds.contains(entry.id) || entry.isPending;
    final isDeleting = _deletingReportIds.contains(entry.id);

    Widget glyphButton({
      required IconData icon,
      required String tooltip,
      required bool busy,
      required VoidCallback? onPressed,
    }) {
      return IconButton(
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 22, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProfileTokens.fill,
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        border: Border.all(color: ProfileTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(typeLabel, style: ProfileText.label),
                    if (timestamp != null)
                      Text(_formatReportTimestamp(timestamp), style: ProfileText.caption),
                  ],
                ),
              ),
              glyphButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit report notes',
                busy: isUpdating,
                onPressed: (isUpdating || isDeleting) ? null : () => _editReportEntry(entry),
              ),
              glyphButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete report',
                busy: isDeleting,
                onPressed: (isDeleting || isUpdating) ? null : () => _deleteReportEntry(entry),
              ),
            ],
          ),
          if ((entry.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(entry.description!, style: ProfileText.longText),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachments
                  .map(
                    (attachment) => profileOutlineButton(
                      label: attachment.filename ?? attachment.path.split('/').last,
                      icon: _attachmentIcon(attachment),
                      onPressed: attachment.isLocalPlaceholder
                          ? null
                          : () => _openAttachment(attachment),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (entry.isPending) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 3,
              color: BrandColors.sunriseGold,
              backgroundColor: ProfileTokens.hairline,
            ),
          ],
        ],
      ),
    );
  }

  String? _cleanText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatCurrency(double amount) => _currencyFormat.format(amount);

  String _formatDonationSubtitle(_DonationRecord donation) {
    final parts = <String>[];
    final designation = _cleanText(donation.designation);
    if (designation != null) {
      parts.add(designation);
    }
    if (donation.createdAt != null) {
      parts.add(_formatDateOnly(donation.createdAt!));
    }
    if (parts.isEmpty) return 'No details available';
    return parts.join(' • ');
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
    } catch (e) {
      debugPrint('_MemberDetailScreenState._lookupServiceAvailability error: $e');
    }
    return null;
  }


  String? _formatDistrict(String? value) => Member.formatDistrictLabel(value);
  List<String> _buildAddressParts({
    String? street,
    String? city,
    String? county,
    String? state,
  }) {
    final parts = <String>[];
    final streetValue = _cleanText(street);
    final cityValue = _cleanText(city);
    final countyValue = _cleanText(county);
    final stateValue = _cleanText(state);

    if (streetValue != null) {
      parts.add(streetValue);
    }
    if (cityValue != null) {
      parts.add(cityValue);
    }
    if (countyValue != null) {
      final normalizedCounty = countyValue.toLowerCase().contains('county')
          ? countyValue
          : '$countyValue County';
      final alreadyPresent = parts.any(
        (part) => part.toLowerCase() == normalizedCounty.toLowerCase(),
      );
      if (!alreadyPresent) {
        parts.add(normalizedCounty);
      }
    }
    if (stateValue != null) {
      parts.add(stateValue);
    }

    return parts;
  }

  Uri? _buildAppleMapsLink(List<String> parts) {
    final query = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
    if (query.isEmpty) return null;
    return Uri.https('maps.apple.com', '/', {'q': query});
  }

  Future<void> _openAttachment(MemberInternalReportAttachment attachment) async {
    final url = attachment.publicUrl;
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment is not available yet.')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid attachment URL: $url')),
      );
      return;
    }

    await _openLink(uri);
  }

  IconData _attachmentIcon(MemberInternalReportAttachment attachment) {
    final contentType = attachment.contentType?.toLowerCase() ?? '';
    final name = (attachment.filename ?? attachment.path).toLowerCase();

    if (contentType.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif')) {
      return Icons.image_outlined;
    }
    if (contentType.startsWith('video/') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi')) {
      return Icons.movie_outlined;
    }
    if (contentType.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (contentType.contains('sheet') ||
        name.endsWith('.xls') ||
        name.endsWith('.xlsx') ||
        name.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (contentType.contains('presentation') ||
        name.endsWith('.ppt') ||
        name.endsWith('.pptx')) {
      return Icons.slideshow_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _formatReportTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
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

  Uri? _buildDonorProfileUrl(_DonorProfile donor) {
    if (donor.profileUrl != null) {
      final parsed = Uri.tryParse(donor.profileUrl!);
      if (parsed != null && parsed.hasScheme) {
        return parsed;
      }
    }
    if (donor.id == null) return null;
    return Uri.tryParse('https://donors.moyoungdemocrats.org/donors/${donor.id}');
  }

  String _formatDate(DateTime rawDate) {
    // PostgREST hands back a UTC-flagged DateTime, and Dart's .month/.day/.year
    // read UTC components off it. Without this .toLocal() the calendar branch
    // below renders the UTC date, which for a Central user is the PREVIOUS day
    // for anything after 7pm.
    //
    // This has to land in the same commit as the .toUtc() on the write side in
    // member_repository. Until today the two bugs cancelled: the write stored
    // Central wall-clock as if it were UTC, and the read pulled UTC components
    // back out, so the date came out right by accident. Fix either one alone
    // and 164 of 307 last_contacted rows start rendering the wrong day.
    final date = rawDate.toLocal();
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

  String _formatDateOnly(DateTime date) => DateFormat('MMM d, y').format(date.toLocal());

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

  /// The Meetings tab in the Overview's idiom: one gradient section card,
  /// centred at 1200, on BrandedBackground. Every state (loading, error, empty
  /// and the list) sits inside that card, because BrandedBackground runs a
  /// horizontal gradient and no single ink passes at both of its ends (see
  /// ProfileTokens). Every pairing is the shared surface's, computed against
  /// the fill it actually sits on: white ink 12.51:1 on unityBlue and 4.59:1
  /// at the card's light end; solid unityBlue rows and chips under white
  /// (12.51:1) with a white outline (12.51:1 against the fill it encloses);
  /// the sunriseGold refresh tile and Retry pill under unityBlue (7.17:1); the
  /// error banner solid #B91C1C under white (6.47:1). The loading spinner is a
  /// white stroke, a graphic, 4.59:1 at worst. Nothing rests on the bare ground.
  Widget _buildMeetingsTab(BuildContext context) {
    // Load attendance if not already loaded
    if (!_hasLoadedAttendance && !_loadingAttendance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMeetingAttendance();
      });
    }

    if (_loadingAttendance) {
      return _buildMeetingsPage(
        child: _buildMeetingsCard(
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_attendanceError != null) {
      return _buildMeetingsPage(
        child: _buildMeetingsCard(
          trailing: _buildMeetingsRefreshButton(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileErrorBanner(
                title: 'Meeting attendance did not load',
                message: _attendanceError!,
              ),
              const SizedBox(height: 16),
              ProfileActionPill(
                icon: Icons.refresh,
                label: 'Retry',
                onPressed: _loadMeetingAttendance,
              ),
            ],
          ),
        ),
      );
    }

    // Sort attendance by date (most recent first)
    final sortedAttendance = [..._meetingAttendance]
      ..sort((a, b) {
        final aDate = a.meetingDate ?? a.meeting?.meetingDate;
        final bDate = b.meetingDate ?? b.meeting?.meetingDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final count = sortedAttendance.length;
    final caption = count == 0
        ? 'No meetings attended yet'
        : '$count meeting${count == 1 ? '' : 's'} attended';

    return RefreshIndicator(
      onRefresh: _loadMeetingAttendance,
      color: BrandColors.momentumBlue,
      child: _buildMeetingsPage(
        child: _buildMeetingsCard(
          caption: caption,
          trailing: _buildMeetingsRefreshButton(),
          child: sortedAttendance.isEmpty
              ? _buildMeetingsEmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sortedAttendance.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildMeetingRow(sortedAttendance[i]),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  /// The tab's scroll frame: the Overview's padding and 1200 centring, always
  /// scrollable so pull to refresh works even when the card is short.
  Widget _buildMeetingsPage({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 768;
        final listPadding = wide
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
            : const EdgeInsets.all(16);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: listPadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ProfileTokens.maxSheetWidth),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The one Meetings card: the section header idiom with the tab's icon, the
  /// count line as the caption, and the refresh control at the trailing edge.
  Widget _buildMeetingsCard({required Widget child, String? caption, Widget? trailing}) {
    return ProfileSectionCard(
      title: 'Meeting Attendance',
      icon: Icons.video_camera_front_outlined,
      caption: caption,
      trailing: trailing,
      child: child,
    );
  }

  /// Refresh as the header's trailing control, in the edit pencil's geometry:
  /// a 40 px sunriseGold tile carrying a unityBlue glyph, 7.17:1.
  Widget _buildMeetingsRefreshButton() {
    return Tooltip(
      message: 'Refresh',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
          onTap: _loadMeetingAttendance,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ProfileTokens.emphasisFill,
              borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.refresh, size: 20, color: ProfileTokens.onEmphasis),
          ),
        ),
      ),
    );
  }

  /// Empty state inside the card: a solid unityBlue icon tile (white glyph on
  /// it, 12.51:1) over the 17 and 15 white lines, centred.
  Widget _buildMeetingsEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          profileIconTile(Icons.event_busy, size: 64, iconSize: 32),
          const SizedBox(height: 16),
          const Text(
            'No meetings recorded',
            style: ProfileText.value,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Meetings will appear here once ${_member.name.split(' ').first} attends one.',
            style: ProfileText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// One attended meeting as a tappable row block: solid unityBlue with a
  /// white outline (white on it 12.51:1; the outline keeps the block's edge at
  /// the card's dark corner). The label is 17 w500, the date 15, and the facts
  /// are solid outlined chips, white on unityBlue, 12.51:1. The whole block
  /// opens the meeting.
  Widget _buildMeetingRow(MeetingAttendance attendance) {
    final dateLabel = attendance.formattedMeetingDate ?? 'Date unavailable';
    final meeting = attendance.meeting;
    final hostName = meeting?.host?.name ?? 'Unknown host';
    final chapterName = meeting?.host?.chapterName;

    return Material(
      color: ProfileTokens.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        side: const BorderSide(color: ProfileTokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToMeeting(attendance),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available, size: 22, color: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attendance.meetingLabel, style: ProfileText.value),
                        Text(dateLabel, style: ProfileText.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 22, color: Colors.white),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  profileChip(attendance.durationSummary, icon: Icons.schedule),
                  if (attendance.joinWindow != null)
                    profileChip(attendance.joinWindow!, icon: Icons.login),
                  profileChip(hostName, icon: Icons.person),
                  if (chapterName != null) profileChip(chapterName, icon: Icons.group),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The latest meeting as one tappable row on the chip fill.
  Widget _buildMeetingSummaryRow(MeetingAttendance attendance) {
    final dateLabel = attendance.formattedMeetingDate ?? 'Date unavailable';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
        onTap: () => _navigateToMeeting(attendance),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: ProfileTokens.fill,
            borderRadius: BorderRadius.circular(ProfileTokens.blockRadius),
            border: Border.all(color: ProfileTokens.hairline),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_available, size: 22, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendance.meetingLabel, style: ProfileText.value),
                    Text(
                      'Last attended $dateLabel, ${attendance.durationSummary}',
                      style: ProfileText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  /// Solid unityBlue sheet with white content (12.51:1), rounded at the top
  /// to ProfileTokens.sheetRadius. The default paper surface is painted over
  /// by making the modal transparent and drawing the fill here. The date line
  /// is full white at the caption scale; size carries the de-emphasis.
  void _showMeetingAttendanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Container(
          decoration: const BoxDecoration(
            color: ProfileTokens.band,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ProfileTokens.sheetRadius),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text('Meeting Attendance', style: ProfileText.sectionTitle),
                const SizedBox(height: 8),
                Expanded(
                  child: _meetingAttendance.isEmpty
                      ? const Center(
                          child: Text('No meetings recorded yet.', style: ProfileText.caption),
                        )
                      : ListView.separated(
                          itemCount: _meetingAttendance.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: ProfileTokens.hairline),
                          itemBuilder: (context, index) {
                            final attendance = _meetingAttendance[index];
                            final dateLabel =
                                attendance.formattedMeetingDate ?? 'Date unavailable';
                            final details = <String>[
                              dateLabel,
                              attendance.durationSummary,
                              if (attendance.joinWindow != null) attendance.joinWindow!,
                            ].join(' • ');
                            return ListTile(
                              title: Text(attendance.meetingLabel, style: ProfileText.value),
                              subtitle: Text(details, style: ProfileText.caption),
                              trailing: const Icon(Icons.open_in_new, color: Colors.white),
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
