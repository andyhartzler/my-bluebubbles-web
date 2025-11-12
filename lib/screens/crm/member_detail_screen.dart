import 'dart:async';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_tab.dart';
import 'package:bluebubbles/screens/crm/meetings_screen.dart';
import 'package:bluebubbles/screens/crm/editors/member_edit_sheet.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/string_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as file_picker;

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
  final CRMMessageService _messageService = CRMMessageService.instance;
  final CRMEmailService _emailService = CRMEmailService.instance;
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();
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

  static const String _reportsBucket = 'member-documents';

  bool get _crmReady => _supabaseService.isInitialized;

  bool get _hasEmailRecipient {
    final email = _member.preferredEmail;
    return email != null && email.trim().isNotEmpty;
  }

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
      _fetchLatestMember();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _reportNotesController.dispose();
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
      builder: (context) => AlertDialog(
        title: const Text('Delete report'),
        content: const Text('This will remove the report and any attachments from storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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

  Future<void> _fetchLatestMember({bool showFeedback = false}) async {
    if (!_crmReady || _refreshingMember) return;

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

  Future<void> _selectProfilePhoto() async {
    if (!_crmReady || _uploadingPhoto) return;

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
            icon: _refreshingMember
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onSurface,
                      ),
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
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onSurface,
                      ),
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
              length: 2,
              child: Column(
                children: [
                  Material(
                    elevation: 2,
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor:
                          Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.account_circle_outlined), text: 'Overview'),
                        Tab(icon: Icon(Icons.email_outlined), text: 'Emails'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildOverviewTab(context),
                        EmailHistoryTab(
                          memberId: _member.id,
                          memberName: _member.name,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final theme = Theme.of(context);
    final phoneDisplay = _cleanText(_member.phone);
    final phoneE164 = _cleanText(_member.phoneE164);
    final primaryPhone = phoneDisplay ?? phoneE164;
    final phoneCopyValue = phoneE164 ?? phoneDisplay;
    final email = _cleanText(_member.email);
    final county = _cleanText(_member.county);
    final addressParts = _buildAddressParts(
      street: _member.address,
      city: _member.city,
      county: _member.county,
      state: _member.state,
    );
    final addressDisplay = addressParts.isEmpty ? null : addressParts.join('\n');
    final addressCopyValue = addressParts.isEmpty ? null : addressParts.join(', ');
    final addressLink = _buildAppleMapsLink(addressParts);
    final districtLabel = _formatDistrict(_member.congressionalDistrict);
    final committees = (_member.committee != null && _member.committee!.isNotEmpty)
        ? _member.committeesString
        : null;
    final notesValue = _cleanText(_member.notes);
    final isExecutive = _member.executiveCommittee;
    final executiveTitle =
        _cleanText(_member.executiveTitle) ?? (isExecutive ? 'Executive Committee' : null);
    final executiveRole = _cleanText(_member.executiveRoleDisplay);
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
        _copyRow('Address', addressDisplay, copyValue: addressCopyValue, link: addressLink),
      ]),
      _buildOptionalSection('Chapter Involvement', [
        _infoRowOrNull('Current Chapter Member', chapterStatus),
        _infoRowOrNull('Chapter Name', chapterName),
        _infoRowOrNull('Chapter Position', chapterPosition),
        if (dateElected != null) _buildInfoRow('Date Elected', _formatDateOnly(dateElected)),
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
        if (_member.age != null) _buildInfoRow('Age', '${_member.age} years old'),
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
    final notesSection = notesChildren.isEmpty ? null : _buildSection('Notes', notesChildren);
    final internalReportsSection = _buildInternalReportsSection();

    final allSections = <Widget>[
      ...sections,
      if (internalReportsSection != null) internalReportsSection,
      if (notesSection != null) notesSection,
      if (metadataSection != null) metadataSection,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final listPadding =
            isWide ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24) : const EdgeInsets.all(16);
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
            Center(child: _buildProfilePhoto()),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    _member.name,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (isExecutive && (executiveTitle != null || executiveRole != null)) ...[
                    const SizedBox(height: 6),
                    if (executiveTitle != null)
                      Text(
                        executiveTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (executiveRole != null)
                      Text(
                        executiveRole,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
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
                      icon: _uploadingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _member.hasProfilePhoto
                                  ? Icons.photo_camera_outlined
                                  : Icons.add_a_photo_outlined,
                            ),
                      label: Text(_uploadingPhoto
                          ? 'Uploading...'
                          : (_member.hasProfilePhoto ? 'Update Photo' : 'Add Photo')),
                      onPressed: _uploadingPhoto ? null : _selectProfilePhoto,
                    ),
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
            if (_crmReady || sectionLayout != null) const SizedBox(height: 24),
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

  Widget _buildProfilePhoto() {
    const double size = 120;
    final theme = Theme.of(context);
    final photoUrl = _member.primaryProfilePhotoUrl;
    final borderColor = theme.colorScheme.primary.withOpacity(0.35);

    Widget buildFallback() {
      final trimmed = _member.name.trim();
      final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B262C), Color(0xFF3282B8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 48,
            ),
          ),
        ),
      );
    }

    Widget content;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildFallback(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
            );
          },
        ),
      );
    } else {
      content = ClipOval(child: buildFallback());
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget? _buildInternalReportsSection() {
    if (!_crmReady) return null;

    final reports = _member.internalInfo.reports;
    final children = <Widget>[
      _buildReportComposer(),
    ];

    if (reports.isEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        const Text('No internal reports yet. Add a note or upload supporting documents.'),
      );
    } else {
      children.add(const SizedBox(height: 16));
      for (final entry in reports) {
        children.add(_buildReportEntryTile(entry));
      }
    }

    return _buildSection('Internal Reports', children);
  }

  Widget _buildReportComposer() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _reportNotesController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add internal notes about this member...',
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_pendingReportFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pendingReportFiles
                  .map(
                    (file) => Chip(
                      label: Text(file.name),
                      onDeleted: _savingReportEntry
                          ? null
                          : () => _removePendingReportFile(file),
                    ),
                  )
                  .toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _savingReportEntry ? null : _pickReportFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('Add Files'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _savingReportEntry ? null : _saveReportEntry,
              icon: _savingReportEntry
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_savingReportEntry ? 'Saving...' : 'Save Report'),
            ),
          ],
        ),
        if (_reportComposerError != null) ...[
          const SizedBox(height: 8),
          Text(
            _reportComposerError!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildReportEntryTile(MemberInternalReportEntry entry) {
    final attachments = entry.attachments;
    final timestamp = entry.updatedAt ?? entry.createdAt;
    final typeLabel = (entry.type ?? (entry.hasAttachments ? 'file' : 'note')).toUpperCase();
    final isUpdating = _updatingReportIds.contains(entry.id) || entry.isPending;
    final isDeleting = _deletingReportIds.contains(entry.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
        color: Theme.of(context).cardColor.withOpacity(0.95),
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
                    Text(
                      typeLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (timestamp != null)
                      Text(
                        _formatReportTimestamp(timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: isUpdating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    tooltip: 'Edit report notes',
                    onPressed: (isUpdating || isDeleting) ? null : () => _editReportEntry(entry),
                  ),
                  IconButton(
                    icon: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    tooltip: 'Delete report',
                    onPressed: (isDeleting || isUpdating) ? null : () => _deleteReportEntry(entry),
                  ),
                ],
              ),
            ],
          ),
          if ((entry.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.description!),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachments
                  .map(
                    (attachment) => OutlinedButton.icon(
                      onPressed: attachment.isLocalPlaceholder
                          ? null
                          : () => _openAttachment(attachment),
                      icon: Icon(_attachmentIcon(attachment)),
                      label: Text(attachment.filename ?? attachment.path.split('/').last),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (entry.isPending) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
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
