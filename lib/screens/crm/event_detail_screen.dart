import 'dart:async';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/services/crm/donor_repository.dart';
import 'package:bluebubbles/services/crm/event_repository.dart';
import 'package:bluebubbles/services/crm/member_lookup_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/phone_normalizer.dart';
import 'package:bluebubbles/screens/crm/qr_scanner_screen.dart';
import 'package:bluebubbles/widgets/event_map_widget.dart';
import 'file_picker_materializer.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);

class EventDetailScreen extends StatefulWidget {
  final Event initialEvent;

  const EventDetailScreen({super.key, required this.initialEvent});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

enum _AttendeeFilter { all, checkedIn, notCheckedIn, members, guests }

class _AttendeeProspect {
  final String source;
  final Member? member;
  final Donor? donor;
  final EventAttendee? attendee;

  const _AttendeeProspect({
    required this.source,
    this.member,
    this.donor,
    this.attendee,
  });

  String get displayName => member?.name ?? donor?.name ?? attendee?.displayName ?? 'Unknown';

  String? get email => member?.email ?? donor?.email ?? attendee?.guestEmail;

  String? get phone => member?.phone ?? member?.phoneE164 ?? donor?.phoneE164 ?? donor?.phone ?? attendee?.guestPhone;
}

class _EventDetailScreenState extends State<EventDetailScreen> with TickerProviderStateMixin {
  final EventRepository _repository = EventRepository();
  final CRMMemberLookupService _memberLookup = CRMMemberLookupService();
  final DonorRepository _donorRepository = DonorRepository();
  final MemberRepository _memberRepository = MemberRepository();

  late Event _currentEvent;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _locationAddressController;
  late TextEditingController _maxAttendeesController;
  late TextEditingController _phoneController;
  late TextEditingController _eventDateDisplayController;
  late TextEditingController _eventEndDateDisplayController;

  late FocusNode nameFocus;
  late FocusNode emailFocus;
  late FocusNode phoneFocus;
  late FocusNode dobFocus;
  late FocusNode addressFocus;
  late FocusNode cityFocus;
  late FocusNode stateFocus;
  late FocusNode zipFocus;
  late FocusNode employerFocus;
  late FocusNode occupationFocus;
  late FocusNode guestCountFocus;

  DateTime? _eventDate;
  DateTime? _eventEndDate;
  DateTime? _rsvpDeadline;
  String? _eventType;
  String _status = 'draft';
  bool _hideAddressBeforeRsvp = false;
  bool _rsvpEnabled = true;
  bool _checkinEnabled = false;
  bool _editingDetails = false;

  bool _autoSavingDraft = false;
  bool _saving = false;
  bool _deleting = false;
  bool _loadingAttendees = false;
  List<EventAttendee> _attendees = [];
  String? _attendeeError;
  _AttendeeFilter _attendeeFilter = _AttendeeFilter.all;
  String _attendeeSearch = '';
  StreamSubscription<List<EventAttendee>>? _attendeeSub;
  bool _openingAttendeeEmail = false;
  bool _openingAttendeeMessage = false;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.initialEvent;
    final event = widget.initialEvent;
    _titleController = TextEditingController(text: event.title);
    _descriptionController = TextEditingController(text: event.description ?? '');
    _locationController = TextEditingController(text: event.location ?? '');
    _locationAddressController = TextEditingController(text: event.locationAddress ?? '');
    _maxAttendeesController = TextEditingController(
      text: event.maxAttendees != null ? event.maxAttendees.toString() : '',
    );
    _phoneController = TextEditingController();
    _eventDateDisplayController = TextEditingController();
    _eventEndDateDisplayController = TextEditingController();
    _eventDate = event.eventDate;
    _eventEndDate = event.eventEndDate;
    _rsvpDeadline = event.rsvpDeadline;
    _eventType = event.eventType;
    _status = event.status;
    _hideAddressBeforeRsvp = event.hideAddressBeforeRsvp;
    _rsvpEnabled = event.rsvpEnabled;
    _checkinEnabled = event.checkinEnabled;
    _editingDetails = event.id == null;

    _titleController.addListener(_maybeAutoSaveDraft);

    _initFocusNodes();

    _syncDateDisplays();

    if (event.id != null) {
      _loadAttendees();
      _startAttendeeStream();
    }
  }

  void _initFocusNodes() {
    nameFocus = FocusNode();
    emailFocus = FocusNode();
    phoneFocus = FocusNode();
    dobFocus = FocusNode();
    addressFocus = FocusNode();
    cityFocus = FocusNode();
    stateFocus = FocusNode();
    zipFocus = FocusNode();
    employerFocus = FocusNode();
    occupationFocus = FocusNode();
    guestCountFocus = FocusNode();
  }

  void _disposeFocusNodes() {
    nameFocus.dispose();
    emailFocus.dispose();
    phoneFocus.dispose();
    dobFocus.dispose();
    addressFocus.dispose();
    cityFocus.dispose();
    stateFocus.dispose();
    zipFocus.dispose();
    employerFocus.dispose();
    occupationFocus.dispose();
    guestCountFocus.dispose();
  }

  void _resetFocusNodes() {
    _disposeFocusNodes();
    _initFocusNodes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _locationAddressController.dispose();
    _maxAttendeesController.dispose();
    _phoneController.dispose();
    _eventDateDisplayController.dispose();
    _eventEndDateDisplayController.dispose();
    _disposeFocusNodes();
    _attendeeSub?.cancel();
    super.dispose();
  }

  void _syncDateDisplays() {
    final formatter = DateFormat.yMMMd().add_jm();
    _eventDateDisplayController.text =
        _eventDate != null ? formatter.format(_eventDate!.toLocal()) : '';
    _eventEndDateDisplayController.text =
        _eventEndDate != null ? formatter.format(_eventEndDate!.toLocal()) : '';
  }

  void _maybeAutoSaveDraft() {
    if (_currentEvent.id != null || _autoSavingDraft) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    _ensureDraftSaved();
  }

  Future<void> _ensureDraftSaved() async {
    if (_currentEvent.id != null || _autoSavingDraft) return;
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _autoSavingDraft = true);
    try {
      final saved = await _repository.createEvent(_buildEventFromForm());
      if (!mounted) return;
      setState(() {
        _currentEvent = saved;
        _status = saved.status;
        _hideAddressBeforeRsvp = saved.hideAddressBeforeRsvp;
        _autoSavingDraft = false;
      });
      _loadAttendees();
      _startAttendeeStream();
    } catch (e) {
      if (!mounted) return;
      setState(() => _autoSavingDraft = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save draft: $e')),
      );
    }
  }

  Event _buildEventFromForm({String? id}) {
    return Event(
      id: id ?? _currentEvent.id ?? widget.initialEvent.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      eventDate: _eventDate ?? _currentEvent.eventDate ?? DateTime.now(),
      eventEndDate: _eventEndDate,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      locationAddress: _locationAddressController.text.trim().isEmpty ? null : _locationAddressController.text.trim(),
      hideAddressBeforeRsvp: _hideAddressBeforeRsvp,
      eventType: _eventType,
      rsvpEnabled: _rsvpEnabled,
      rsvpDeadline: _rsvpDeadline,
      maxAttendees: int.tryParse(_maxAttendeesController.text),
      checkinEnabled: _checkinEnabled,
      status: _status,
      createdBy: _currentEvent.createdBy ?? widget.initialEvent.createdBy,
      createdAt: _currentEvent.createdAt ?? widget.initialEvent.createdAt,
      updatedAt: DateTime.now(),
      socialShareImage: _currentEvent.socialShareImage,
      websiteImage: _currentEvent.websiteImage,
    );
  }

  Future<void> _saveEvent() async {
    if (_titleController.text.trim().isEmpty || _eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and start date are required.')),
      );
      return;
    }

    final isNew = _currentEvent.id == null;
    setState(() => _saving = true);
    try {
      Event saved;
      if (isNew) {
        saved = await _repository.createEvent(_buildEventFromForm());
      } else {
        saved = await _repository.updateEvent(_buildEventFromForm());
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _currentEvent = saved;
        _hideAddressBeforeRsvp = saved.hideAddressBeforeRsvp;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event saved successfully.')),
      );

      setState(() => _editingDetails = false);
      if (isNew) {
        _loadAttendees();
        _startAttendeeStream();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save event: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImage({required bool isSocialShare}) async {
    if (_currentEvent.id == null) {
      await _ensureDraftSaved();
      if (_currentEvent.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a title to save this event before uploading.')),
        );
        return;
      }
    }

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      withReadStream: !kIsWeb,
      type: file_picker.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );

    if (result == null || result.files.isEmpty) return;

    final platformFile = await materializePickedPlatformFile(
      result.files.first,
      source: result,
    );

    if (platformFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected image. Please try again.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await _repository.uploadEventImage(
        eventId: _currentEvent.id!,
        file: platformFile,
        isSocialShare: isSocialShare,
      );
      if (!mounted) return;
      setState(() {
        _currentEvent = updated;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  Future<void> _confirmDeleteEvent() async {
    final eventId = _currentEvent.id;
    if (eventId == null || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _actionRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _repository.deleteEvent(eventId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete event: $e')),
      );
    }
  }

  Future<void> _loadAttendees() async {
    final eventId = _currentEvent.id;
    if (eventId == null) return;
    setState(() {
      _loadingAttendees = true;
      _attendeeError = null;
    });

    try {
      final attendees = await _repository.fetchAttendees(eventId);
      if (!mounted) return;
      setState(() {
        _attendees = attendees;
        _loadingAttendees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attendeeError = e.toString();
        _loadingAttendees = false;
      });
    }
  }

  void _startAttendeeStream() {
    final eventId = _currentEvent.id;
    if (eventId == null) return;

    _attendeeSub?.cancel();
    _attendeeSub = _repository.watchAttendees(eventId).listen(
      (attendees) {
        if (!mounted) return;
        setState(() {
          _attendees = attendees;
          _attendeeError = null;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _attendeeError = error.toString();
        });
      },
    );
  }

  Future<void> _handlePhoneLookup() async {
    if (widget.initialEvent.id == null) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _loadingAttendees = true);
    final member = await _repository.previewMemberByPhone(phone);
    if (!mounted) return;
    setState(() => _loadingAttendees = false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm check-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (member != null) ...[
                Text(member.name ?? 'Member'),
                if (member.email != null) Text(member.email!),
                if (member.phone != null) Text(member.phone!),
              ] else ...[
                const Text('No member record found.'),
                const SizedBox(height: 8),
                Text('Send RSVP confirmation to $phone?'),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _loadingAttendees = true);
    final attendee = await _repository.checkInByPhone(
      eventId: widget.initialEvent.id!,
      phoneNumber: phone,
      eventName: _titleController.text.trim(),
    );

    if (!mounted) return;
    _phoneController.clear();
    setState(() => _loadingAttendees = false);

    if (attendee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration link sent to $phone')),
      );
    } else if (attendee.checkedIn) {
      final time = attendee.checkedInAt != null
          ? DateFormat.jm().format(attendee.checkedInAt!.toLocal())
          : 'now';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${attendee.displayName} checked in at $time')),
      );
    }
  }

  Future<void> _handleQRScan() async {
    if (widget.initialEvent.id == null) return;

    try {
      final scannedCode = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );

      if (scannedCode == null || !mounted) return;
      setState(() => _loadingAttendees = true);
      final member = await _repository.previewMemberByUUID(scannedCode.trim());
      if (!mounted) return;
      setState(() => _loadingAttendees = false);

      if (member == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid membership card'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check in member?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name ?? 'Member'),
              if (member.email != null) Text(member.email!),
              if (member.phone != null) Text(member.phone!),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _loadingAttendees = true);

      final attendee = await _repository.checkInByMemberUUID(
        eventId: widget.initialEvent.id!,
        memberUUID: scannedCode.trim(),
      );

      if (!mounted) return;

      setState(() => _loadingAttendees = false);

      if (attendee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to check in member'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (attendee.checkedInAt != null) {
        final time = DateFormat.jm().format(attendee.checkedInAt!.toLocal());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${attendee.displayName} checked in at $time'),
            backgroundColor: _grassrootsGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingAttendees = false);

      // Clean up error message formatting
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }
      if (errorMessage.contains('PostgrestException')) {
        errorMessage = 'Database error: Please try again or contact support.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _pickDateTime({required bool isEndDate}) async {
    final initial = isEndDate ? _eventEndDate ?? _eventDate ?? DateTime.now() : _eventDate ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? initial.hour,
      pickedTime?.minute ?? initial.minute,
    );
    setState(() {
      if (isEndDate) {
        _eventEndDate = result;
      } else {
        _eventDate = result;
      }
      _syncDateDisplays();
    });
  }

  Future<void> _pickRsvpDeadline() async {
    final initial = _rsvpDeadline ?? _eventDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    setState(() {
      _rsvpDeadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? initial.hour,
        time?.minute ?? initial.minute,
      );
    });
  }

  List<EventAttendee> _filteredAttendees() {
    return _attendees.where((attendee) {
      switch (_attendeeFilter) {
        case _AttendeeFilter.checkedIn:
          if (!attendee.checkedIn) return false;
          break;
        case _AttendeeFilter.notCheckedIn:
          if (attendee.checkedIn) return false;
          break;
        case _AttendeeFilter.members:
          if (attendee.memberId == null) return false;
          break;
        case _AttendeeFilter.guests:
          if (attendee.memberId != null) return false;
          break;
        case _AttendeeFilter.all:
          break;
      }
      if (_attendeeSearch.isNotEmpty) {
        final name = attendee.displayName.toLowerCase();
        if (!name.contains(_attendeeSearch.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _toggleCheckInStatus(EventAttendee attendee, bool checkedIn) async {
    setState(() => _loadingAttendees = true);
    try {
      final now = DateTime.now();
      final eventStart = _currentEvent.eventDate?.toLocal();
      DateTime? desiredCheckInAt;

      if (checkedIn) {
        final hasEventStarted = eventStart != null && now.isAfter(eventStart);
        final fourHoursAfterStart =
            eventStart != null ? eventStart.add(const Duration(hours: 4)) : null;
        final isFourHoursAfterStart = fourHoursAfterStart != null && now.isAfter(fourHoursAfterStart);

        if (isFourHoursAfterStart) {
          desiredCheckInAt = eventStart;
        } else if (hasEventStarted) {
          desiredCheckInAt = now;
        }
      }

      final updated = await _repository.updateCheckInStatus(
        attendeeId: attendee.id,
        checkedIn: checkedIn,
        checkedInAt: desiredCheckInAt,
      );
      if (!mounted) return;
      setState(() {
        _attendees = _attendees.map((a) => a.id == updated.id ? updated : a).toList();
        _loadingAttendees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAttendees = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update check-in: $e')),
      );
    }
  }

  String? _memberKey(Member member) => member.id ?? member.phoneE164 ?? member.phone;

  List<Member> _attendeeMembersWithEmails() {
    final seen = <String>{};
    final members = <Member>[];

    for (final attendee in _attendees) {
      final member = attendee.member;
      final email = member?.preferredEmail ?? member?.email;
      if (member == null || email == null || email.trim().isEmpty) continue;

      final key = _memberKey(member);
      if (key != null && seen.add(key)) {
        members.add(member);
      }
    }

    return members;
  }

  List<Member> _attendeeMembersWithPhones() {
    final seen = <String>{};
    final members = <Member>[];

    for (final attendee in _attendees) {
      final member = attendee.member;
      final hasPhone = member?.phoneE164?.trim().isNotEmpty == true ||
          member?.phone?.trim().isNotEmpty == true;

      if (member == null || !hasPhone) continue;

      final key = _memberKey(member);
      if (key != null && seen.add(key)) {
        members.add(member);
      }
    }

    return members;
  }

  List<String> _attendeeGuestEmails() {
    final manualEmails = <String>{};

    for (final attendee in _attendees) {
      final email = attendee.guestEmail?.trim();
      if (email != null && email.isNotEmpty) {
        manualEmails.add(email);
      }
    }

    return manualEmails.toList();
  }

  Future<void> _handleEmailAttendees() async {
    if (_openingAttendeeEmail) return;

    final memberRecipients = _attendeeMembersWithEmails();
    final manualEmails = _attendeeGuestEmails();

    if (memberRecipients.isEmpty && manualEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendee emails available.')),
      );
      return;
    }

    setState(() => _openingAttendeeEmail = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulkEmailScreen(
            initialManualMembers: memberRecipients.isEmpty ? null : memberRecipients,
            initialManualEmails: manualEmails.isEmpty ? null : manualEmails,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingAttendeeEmail = false);
      } else {
        _openingAttendeeEmail = false;
      }
    }
  }

  Future<void> _handleMessageAttendees() async {
    if (_openingAttendeeMessage) return;

    final memberRecipients = _attendeeMembersWithPhones();

    if (memberRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendee phone numbers available to message.')),
      );
      return;
    }

    setState(() => _openingAttendeeMessage = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulkMessageScreen(initialManualMembers: memberRecipients),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingAttendeeMessage = false);
      } else {
        _openingAttendeeMessage = false;
      }
    }
  }

  Future<void> _deleteAttendee(EventAttendee attendee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove attendee'),
        content: Text('Are you sure you want to remove ${attendee.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loadingAttendees = true);
    try {
      await _repository.deleteAttendee(attendee.id);
      if (!mounted) return;
      setState(() {
        _attendees = _attendees.where((a) => a.id != attendee.id).toList();
        _loadingAttendees = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Removed ${attendee.displayName}.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAttendees = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete attendee: $e')));
    }
  }

  Future<void> _showMemberProfile(EventAttendee attendee) async {
    final member = attendee.member;
    if (member == null) return;

    _memberLookup.cacheMember(member);
    await Navigator.of(context, rootNavigator: true).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: MemberDetailScreen(member: member),
        ),
      ),
    );
  }

  Future<String?> _ensureDonorForAttendee(EventAttendee attendee) async {
    if (!_donorRepository.isReady) return null;

    Donor? donor;
    if (attendee.memberId != null) {
      donor = await _donorRepository.findDonorByMemberId(attendee.memberId!);
    }

    donor ??= attendee.guestPhone != null
        ? await _donorRepository.findDonorByPhone(attendee.guestPhone!)
        : null;

    final payload = {
      'name': attendee.member?.name ?? attendee.guestName,
      'email': attendee.member?.email ?? attendee.guestEmail,
      'phone': attendee.member?.phone ?? attendee.guestPhone,
      'phone_e164': attendee.member?.phoneE164 ?? attendee.guestPhone,
      'member_id': attendee.memberId,
      'address': attendee.address,
      'city': attendee.city,
      'state': attendee.state,
      'zip_code': attendee.zip,
      'employer': attendee.employer,
      'occupation': attendee.occupation,
    };

    return _donorRepository.upsertDonor(
      donorId: donor?.id,
      data: payload,
    );
  }

  Future<void> _showManualDonationDialog(EventAttendee attendee) async {
    final eventId = _currentEvent.id;
    if (eventId == null) return;

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final checkNumberController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String paymentMethod = 'cash';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add donation for ${attendee.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'check', child: Text('Check')),
                    DropdownMenuItem(value: 'in-kind', child: Text('In-kind')),
                  ],
                  onChanged: (value) => setDialogState(() => paymentMethod = value ?? 'cash'),
                ),
                if (paymentMethod == 'check')
                  TextField(
                    controller: checkNumberController,
                    decoration: const InputDecoration(labelText: 'Check number'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${DateFormat.yMMMd().format(selectedDate)}')),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDate: selectedDate,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Change'),
                    )
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save donation'),
            )
          ],
        ),
      ),
    );

    if (confirmed != true) {
      amountController.dispose();
      notesController.dispose();
      checkNumberController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid donation amount.')));
      amountController.dispose();
      notesController.dispose();
      checkNumberController.dispose();
      return;
    }

    setState(() => _loadingAttendees = true);
    try {
      final donorId = await _ensureDonorForAttendee(attendee);
      await _donorRepository.addManualDonation(
        donorId: donorId,
        amount: amount,
        donationDate: selectedDate,
        paymentMethod: paymentMethod,
        checkNumber: checkNumberController.text.trim(),
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        eventId: eventId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Donation recorded for ${attendee.displayName}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to record donation: $e')));
    } finally {
      if (mounted) {
        setState(() => _loadingAttendees = false);
      }
      amountController.dispose();
      notesController.dispose();
      checkNumberController.dispose();
    }
  }

  Future<void> _showAddAttendeeDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final guestCountController = TextEditingController(text: '0');
    final dobController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController(text: 'MO');
    final zipController = TextEditingController();
    final employerController = TextEditingController();
    final occupationController = TextEditingController();
    final now = DateTime.now();
    final eventStart = _currentEvent.eventDate?.toLocal();
    final hasEventStarted = eventStart != null && now.isAfter(eventStart);

    bool checkInNow = hasEventStarted;
    DateTime? defaultCheckInAt = hasEventStarted ? eventStart : null;
    bool sendConfirmation = false;

    Member? selectedMember;
    EventAttendee? selectedHistoricalAttendee;
    List<_AttendeeProspect> searchResults = [];
    bool searching = false;
    Timer? debounce;

    final formKey = GlobalKey<FormState>();

    Future<void> runSearch(String value, void Function(void Function()) setDialogState) async {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), () async {
        if (value.trim().length < 2) {
          setDialogState(() => searchResults = []);
          return;
        }

        setDialogState(() => searching = true);
        try {
          final members = await _memberRepository.searchMembers(value.trim());
          final donors = (await _donorRepository.fetchDonors(searchQuery: value.trim(), limit: 10)).donors;
          final pastAttendees = await _repository.searchHistoricalAttendees(value.trim());

          setDialogState(() {
            searchResults = [
              ...members.map((m) => _AttendeeProspect(source: 'Member', member: m)),
              ...donors.map((d) => _AttendeeProspect(source: 'Donor', donor: d)),
              ...pastAttendees.map(
                (a) => _AttendeeProspect(source: 'Previous attendee', attendee: a),
              ),
            ];
            searching = false;
          });
        } catch (_) {
          setDialogState(() {
            searchResults = [];
            searching = false;
          });
        }
      });
    }

    void applyProspect(_AttendeeProspect prospect, void Function(void Function()) setDialogState) {
      setDialogState(() {
        selectedMember = prospect.member;
        selectedHistoricalAttendee = prospect.attendee;

        nameController.text = prospect.displayName;
        emailController.text = prospect.email ?? '';
        phoneController.text = prospect.phone ?? '';

        final sourceAttendee = prospect.attendee;
        final sourceDonor = prospect.donor;
        if (sourceAttendee != null) {
          addressController.text = sourceAttendee.address ?? '';
          cityController.text = sourceAttendee.city ?? '';
          stateController.text = sourceAttendee.state ?? stateController.text;
          zipController.text = sourceAttendee.zip ?? '';
          employerController.text = sourceAttendee.employer ?? '';
          occupationController.text = sourceAttendee.occupation ?? '';
          guestCountController.text = sourceAttendee.guestCount?.toString() ?? '0';
          dobController.text = sourceAttendee.dateOfBirth?.toIso8601String().split('T').first ?? '';
        } else if (sourceDonor != null) {
          addressController.text = sourceDonor.address ?? '';
          cityController.text = sourceDonor.city ?? '';
          stateController.text = sourceDonor.state ?? stateController.text;
          zipController.text = sourceDonor.zipCode ?? '';
          employerController.text = sourceDonor.employer ?? '';
          occupationController.text = sourceDonor.occupation ?? '';
          dobController.text = sourceDonor.dateOfBirth?.toIso8601String().split('T').first ?? '';
        }
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add attendee'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 760),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideForm = constraints.maxWidth > 760;
                final fieldWidth = isWideForm ? (constraints.maxWidth / 2) - 28 : constraints.maxWidth;
                double order = 0;

                Widget ordered({required Widget child}) {
                  return FocusTraversalOrder(
                    order: NumericFocusOrder(order++),
                    child: child,
                  );
                }

                return SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ordered(
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Search name, email, or phone',
                              ),
                              onChanged: (value) => runSearch(value, setDialogState),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (searching) const LinearProgressIndicator(),
                          if (searchResults.isNotEmpty)
                            SizedBox(
                              height: 200,
                              child: ListView.separated(
                                itemBuilder: (context, index) {
                                  final prospect = searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person_search),
                                    title: Text(prospect.displayName),
                                    subtitle: Text(
                                      [
                                        prospect.source,
                                        if (prospect.email != null) prospect.email!,
                                        if (prospect.phone != null) prospect.phone!,
                                      ].join(' • '),
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => applyProspect(prospect, setDialogState),
                                      child: const Text('Use'),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemCount: searchResults.length,
                              ),
                            ),
                          if (searchResults.isNotEmpty) const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Manual details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: nameFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => emailFocus.requestFocus(),
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Name required for guests';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: emailFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => phoneFocus.requestFocus(),
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.alternate_email_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: phoneFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => dobFocus.requestFocus(),
                                  controller: phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: dobFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => addressFocus.requestFocus(),
                                  controller: dobController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date of birth (YYYY-MM-DD)',
                                    prefixIcon: Icon(Icons.cake_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: addressFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => cityFocus.requestFocus(),
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Address',
                                    prefixIcon: Icon(Icons.home_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: cityFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => stateFocus.requestFocus(),
                                  controller: cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'City',
                                    prefixIcon: Icon(Icons.location_city_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: stateFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => zipFocus.requestFocus(),
                                  controller: stateController,
                                  decoration: const InputDecoration(
                                    labelText: 'State',
                                    prefixIcon: Icon(Icons.map_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: zipFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => employerFocus.requestFocus(),
                                  controller: zipController,
                                  decoration: const InputDecoration(
                                    labelText: 'ZIP',
                                    prefixIcon: Icon(Icons.local_post_office_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: employerFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => occupationFocus.requestFocus(),
                                  controller: employerController,
                                  decoration: const InputDecoration(
                                    labelText: 'Employer',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: occupationFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => guestCountFocus.requestFocus(),
                                  controller: occupationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Occupation',
                                    prefixIcon: Icon(Icons.work_outline),
                                  ),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  focusNode: guestCountFocus,
                                  textInputAction: TextInputAction.done,
                                  controller: guestCountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Guest Count',
                                    prefixIcon: Icon(Icons.groups_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: checkInNow,
                                  onChanged: (value) => setDialogState(() => checkInNow = value ?? false),
                                  title: const Text('Check in immediately'),
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                            ),
                            ordered(
                              child: SizedBox(
                                width: fieldWidth,
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: sendConfirmation,
                                  onChanged: (value) => setDialogState(() => sendConfirmation = value ?? false),
                                  title: const Text('Send RSVP confirmation'),
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      guestCountController.dispose();
      dobController.dispose();
      addressController.dispose();
      cityController.dispose();
      stateController.dispose();
      zipController.dispose();
      employerController.dispose();
      occupationController.dispose();
      _resetFocusNodes();
      debounce?.cancel();
      return;
    }

    debounce?.cancel();
    setState(() => _loadingAttendees = true);

    try {
      final eventId = _currentEvent.id!;
      final attendee = await _repository.addAttendee(
        eventId: eventId,
        memberId: selectedMember?.id ?? selectedHistoricalAttendee?.memberId,
        guestName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
        guestEmail: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
        guestPhone: formatToE164(phoneController.text.trim()),
        dateOfBirth: dobController.text.trim().isEmpty
            ? null
            : DateTime.tryParse(dobController.text.trim())?.toLocal(),
        address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
        city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
        state: stateController.text.trim().isEmpty ? null : stateController.text.trim(),
        zip: zipController.text.trim().isEmpty ? null : zipController.text.trim(),
        employer: employerController.text.trim().isEmpty ? null : employerController.text.trim(),
        occupation:
            occupationController.text.trim().isEmpty ? null : occupationController.text.trim(),
        guestCount: int.tryParse(guestCountController.text) ?? 0,
        checkedIn: checkInNow,
        checkedInAt: checkInNow ? defaultCheckInAt : null,
        sendRsvpConfirmation: sendConfirmation,
      );

      if (!mounted) return;
      setState(() {
        _attendees = [attendee, ..._attendees];
        _loadingAttendees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAttendees = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add attendee: $e')));
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      guestCountController.dispose();
      dobController.dispose();
      addressController.dispose();
      cityController.dispose();
      stateController.dispose();
      zipController.dispose();
      employerController.dispose();
      occupationController.dispose();
      _resetFocusNodes();
      debounce?.cancel();
    }
  }

  Widget _buildAttendeeCard(EventAttendee attendee) {
    final subtitle = attendee.member != null
        ? 'Member • ${attendee.member?.email ?? attendee.member?.phone ?? ''}'
        : 'Guest • ${attendee.guestEmail ?? attendee.guestPhone ?? ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attendee.displayName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: attendee.checkedIn,
                      onChanged: (value) => _toggleCheckInStatus(attendee, value),
                      activeColor: _grassrootsGreen,
                    ),
                    Text(attendee.checkedIn ? 'Checked in' : 'Pending'),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(attendee.rsvpStatus.toUpperCase()),
                ),
                if (attendee.guestCount != null)
                  Chip(label: Text('Guests: ${attendee.guestCount}')),
                if (attendee.checkedInAt != null)
                  Chip(
                    label: Text('Checked in at ${DateFormat.jm().format(attendee.checkedInAt!.toLocal())}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (attendee.member != null)
                  TextButton.icon(
                    onPressed: () => _showMemberProfile(attendee),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('View member'),
                  ),
                TextButton.icon(
                  onPressed: () => _showManualDonationDialog(attendee),
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: const Text('Add donation'),
                ),
                TextButton.icon(
                  onPressed: _loadingAttendees ? null : () => _deleteAttendee(attendee),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                const Spacer(),
                if (attendee.checkedIn)
                  TextButton(
                    onPressed: () => _toggleCheckInStatus(attendee, false),
                    child: const Text('Undo check-in'),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesTab() {
    final attendees = _filteredAttendees();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 520),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search attendees',
                ),
                onChanged: (value) => setState(() => _attendeeSearch = value),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingAttendees ? null : _handleMessageAttendees,
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Send message'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingAttendees ? null : _handleEmailAttendees,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Send email'),
                ),
                ElevatedButton.icon(
                  onPressed: _loadingAttendees ? null : _showAddAttendeeDialog,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add attendee'),
                  style: ElevatedButton.styleFrom(backgroundColor: _unityBlue, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _attendeeFilter == _AttendeeFilter.all,
              onSelected: (_) => setState(() => _attendeeFilter = _AttendeeFilter.all),
            ),
            ChoiceChip(
              label: const Text('Checked in'),
              selected: _attendeeFilter == _AttendeeFilter.checkedIn,
              onSelected: (_) => setState(() => _attendeeFilter = _AttendeeFilter.checkedIn),
            ),
            ChoiceChip(
              label: const Text('Not checked in'),
              selected: _attendeeFilter == _AttendeeFilter.notCheckedIn,
              onSelected: (_) => setState(() => _attendeeFilter = _AttendeeFilter.notCheckedIn),
            ),
            ChoiceChip(
              label: const Text('Members'),
              selected: _attendeeFilter == _AttendeeFilter.members,
              onSelected: (_) => setState(() => _attendeeFilter = _AttendeeFilter.members),
            ),
            ChoiceChip(
              label: const Text('Guests'),
              selected: _attendeeFilter == _AttendeeFilter.guests,
              onSelected: (_) => setState(() => _attendeeFilter = _AttendeeFilter.guests),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_attendeeError != null)
          Text(
            _attendeeError!,
            style: const TextStyle(color: Colors.red),
          ),
        if (_loadingAttendees)
          const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Expanded(
          child: attendees.isEmpty
              ? const Center(child: Text('No attendees yet'))
              : ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildAttendeeCard(attendees[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    final socialName = _currentEvent.socialShareImage?['file_name'] ?? 'No image uploaded';
    final websiteName = _currentEvent.websiteImage?['file_name'] ?? 'No image uploaded';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Social share image'),
                subtitle: Text(socialName),
                trailing: ElevatedButton.icon(
                  onPressed: _currentEvent.id == null ? null : () => _pickAndUploadImage(isSocialShare: true),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(backgroundColor: _momentumBlue, foregroundColor: Colors.white),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Website image'),
                subtitle: Text(websiteName),
                trailing: ElevatedButton.icon(
                  onPressed: _currentEvent.id == null ? null : () => _pickAndUploadImage(isSocialShare: false),
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(backgroundColor: _unityBlue, foregroundColor: Colors.white),
                ),
              ),
            ),
          ],
        ),
        if (_currentEvent.id == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text('Save the event to enable uploads.', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    if (_currentEvent.id == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _actionRed,
          side: const BorderSide(color: _actionRed),
        ),
        onPressed: _deleting ? null : _confirmDeleteEvent,
        icon: _deleting
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.delete_outline),
        label: Text(_deleting ? 'Deleting...' : 'Delete Event'),
      ),
    );
  }

  Widget _buildMapCard() {
    final location = _currentEvent.location ?? _currentEvent.locationAddress;
    if (location == null || location.isEmpty) return const SizedBox.shrink();

    final address = _currentEvent.locationAddress ?? location;
    final mapsUri = Uri.https('maps.apple.com', '/', {
      'q': address,
    });

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EventMapWidget(
            location: location,
            locationAddress: _currentEvent.locationAddress,
            eventTitle: _currentEvent.title,
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: _unityBlue),
            title: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: const Text('Open full map in Apple Maps'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(mapsUri, mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_editingDetails || _currentEvent.id == null) {
      return _buildForm();
    }

    final dateFormat = DateFormat.yMMMd().add_jm();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit event',
              onPressed: () => setState(() => _editingDetails = true),
            ),
          ),
          Card(
            color: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_unityBlue, _momentumBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentEvent.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentEvent.description != null)
                      Text(
                        _currentEvent.description!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          dateFormat.format(_currentEvent.eventDate.toLocal()),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    if (_currentEvent.eventEndDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.more_time_outlined, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            dateFormat.format(_currentEvent.eventEndDate!.toLocal()),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                    if (_currentEvent.location != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentEvent.location!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_currentEvent.eventType != null) ...[
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          _currentEvent.eventType!.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.white24,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            _currentEvent.rsvpEnabled ? 'RSVPs enabled' : 'RSVPs disabled',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.white24,
                        ),
                        Chip(
                          label: Text(
                            _currentEvent.checkinEnabled ? 'Check-in on' : 'Check-in off',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.white24,
                        ),
                        Chip(
                          label: Text(
                            _currentEvent.status.toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.white24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildMapCard(),
          const SizedBox(height: 12),
          _buildImageUploadSection(),
          _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = EventStats.fromAttendees(_attendees);
    final theme = Theme.of(context);

    Widget tile(String label, String value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('Total RSVPs', stats.totalRsvps.toString(), _unityBlue, Icons.how_to_reg_outlined),
        const SizedBox(width: 12),
        tile('Checked In', stats.checkedIn.toString(), _grassrootsGreen, Icons.verified_outlined),
        const SizedBox(width: 12),
        tile('Attendance Rate', '${stats.attendanceRate.toStringAsFixed(1)}%', _momentumBlue,
            Icons.percent_outlined),
        const SizedBox(width: 12),
        tile('Members vs Guests', '${stats.members}/${stats.guests}', _justicePurple, Icons.group_outlined),
      ],
    );
  }

  Widget _buildPhoneLookupCard() {
    return Column(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: _momentumBlue),
                    const SizedBox(width: 8),
                    Text('QR Code Check-In',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadingAttendees ? null : _handleQRScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Member QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _momentumBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Scan a member\'s digital membership card to check them in instantly.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_android_outlined, color: _unityBlue),
                    const SizedBox(width: 8),
                    Text('Phone Number Check-In',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: _loadingAttendees ? null : _handlePhoneLookup,
                    ),
                  ),
                  onSubmitted: (_) => _handlePhoneLookup(),
                ),
                const SizedBox(height: 8),
                const Text('Looks up members & donors by phone. Sends a registration link if not found.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final dateFormat = DateFormat.yMMMd().add_jm();

    InputDecoration _decor(String label) => InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: _decor('Title *'),
              onEditingComplete: _ensureDraftSaved,
              onSubmitted: (_) => _ensureDraftSaved(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _decor('Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: _eventDateDisplayController,
                    onTap: () => _pickDateTime(isEndDate: false),
                    decoration: _decor('Event Date & Time')
                        .copyWith(
                      hintText: 'Select start',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: _eventEndDateDisplayController,
                    onTap: () => _pickDateTime(isEndDate: true),
                    decoration: _decor('End Date & Time')
                        .copyWith(
                      hintText: 'Optional end time',
                      suffixIcon: const Icon(Icons.schedule_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: _decor('Location Name'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _locationAddressController,
                    decoration: _decor('Location Address'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _hideAddressBeforeRsvp,
              onChanged: (value) => setState(() => _hideAddressBeforeRsvp = value),
              title: const Text('Hide address until RSVP'),
              subtitle: const Text('Keep the event address hidden until someone RSVPs'),
            ),
            const SizedBox(height: 12),
            _buildImageUploadSection(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _eventType,
                    decoration: _decor('Event Type'),
                    items: const [
                      DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                      DropdownMenuItem(value: 'rally', child: Text('Rally')),
                      DropdownMenuItem(value: 'fundraiser', child: Text('Fundraiser')),
                      DropdownMenuItem(value: 'social', child: Text('Social')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _eventType = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxAttendeesController,
                    keyboardType: TextInputType.number,
                    decoration: _decor('Max Attendees'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _rsvpEnabled,
              onChanged: (value) => setState(() => _rsvpEnabled = value),
              title: const Text('RSVP Enabled'),
              subtitle: const Text('Allow attendees to RSVP for this event'),
            ),
            if (_rsvpEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('RSVP Deadline'),
                subtitle: Text(_rsvpDeadline != null
                    ? dateFormat.format(_rsvpDeadline!)
                    : 'Optional deadline for RSVP'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: _pickRsvpDeadline,
                ),
              ),
            SwitchListTile(
              value: _checkinEnabled,
              onChanged: (value) => setState(() => _checkinEnabled = value),
              title: const Text('Check-in Enabled'),
              subtitle: const Text('Allow staff to check in attendees'),
            ),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: _decor('Status'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 'draft'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveEvent,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Event'),
                style: ElevatedButton.styleFrom(backgroundColor: _unityBlue, foregroundColor: Colors.white),
              ),
            ),
            _buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasEventId = _currentEvent.id != null;
    final tabCount = hasEventId ? 3 : 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _currentEvent.id == null ? 'Create Event' : _currentEvent.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: DefaultTabController(
          key: ValueKey(hasEventId ? _currentEvent.id ?? 'new' : 'new'),
          length: tabCount,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Card(
                color: Colors.black,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 6,
                child: Column(
                  children: [
                    if (hasEventId)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_unityBlue, _momentumBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: const TabBar(
                          indicatorColor: _sunriseGold,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          tabs: [
                            Tab(text: 'Details'),
                            Tab(text: 'Attendees'),
                            Tab(text: 'Check-In'),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TabBarView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            if (hasEventId)
                              _buildOverviewTab()
                            else
                              _buildForm(),
                            if (hasEventId)
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildAttendeesTab(),
                              ),
                            if (hasEventId)
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStats(),
                                    const SizedBox(height: 16),
                                    _buildPhoneLookupCard(),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
