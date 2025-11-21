import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as file_picker;

import 'package:bluebubbles/database/global/platform_file.dart'
    as bluebubbles_file;
import 'package:bluebubbles/models/crm/event.dart';
import 'package:bluebubbles/services/crm/event_repository.dart';
import 'package:bluebubbles/screens/crm/qr_scanner_screen.dart';

const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

class EventDetailScreen extends StatefulWidget {
  final Event initialEvent;

  const EventDetailScreen({super.key, required this.initialEvent});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

enum _AttendeeFilter { all, checkedIn, notCheckedIn, members, guests }

class _EventDetailScreenState extends State<EventDetailScreen> with TickerProviderStateMixin {
  final EventRepository _repository = EventRepository();

  late Event _currentEvent;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _locationAddressController;
  late TextEditingController _maxAttendeesController;
  late TextEditingController _phoneController;
  late TextEditingController _eventDateDisplayController;
  late TextEditingController _eventEndDateDisplayController;

  DateTime? _eventDate;
  DateTime? _eventEndDate;
  DateTime? _rsvpDeadline;
  String? _eventType;
  String _status = 'draft';
  bool _rsvpEnabled = true;
  bool _checkinEnabled = false;
  bool _editingDetails = false;

  bool _saving = false;
  bool _loadingAttendees = false;
  List<EventAttendee> _attendees = [];
  String? _attendeeError;
  _AttendeeFilter _attendeeFilter = _AttendeeFilter.all;
  String _attendeeSearch = '';
  StreamSubscription<List<EventAttendee>>? _attendeeSub;

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
    _rsvpEnabled = event.rsvpEnabled;
    _checkinEnabled = event.checkinEnabled;
    _editingDetails = event.id == null;

    _syncDateDisplays();

    if (event.id != null) {
      _loadAttendees();
      _startAttendeeStream();
    }
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

  Event _buildEventFromForm({String? id}) {
    return Event(
      id: id ?? widget.initialEvent.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      eventDate: _eventDate ?? DateTime.now(),
      eventEndDate: _eventEndDate,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      locationAddress: _locationAddressController.text.trim().isEmpty ? null : _locationAddressController.text.trim(),
      eventType: _eventType,
      rsvpEnabled: _rsvpEnabled,
      rsvpDeadline: _rsvpDeadline,
      maxAttendees: int.tryParse(_maxAttendeesController.text),
      checkinEnabled: _checkinEnabled,
      status: _status,
      createdBy: widget.initialEvent.createdBy,
      createdAt: widget.initialEvent.createdAt,
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

    setState(() => _saving = true);
    try {
      Event saved;
      if (widget.initialEvent.id == null) {
        saved = await _repository.createEvent(_buildEventFromForm());
      } else {
        saved = await _repository.updateEvent(_buildEventFromForm());
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _currentEvent = saved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event saved successfully.')),
      );

      if (widget.initialEvent.id == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(initialEvent: saved),
          ),
        );
      } else {
        setState(() => _editingDetails = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the event before uploading images.')),
      );
      return;
    }

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: file_picker.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _saving = true);
    try {
      final pickedFile = result.files.first;
      final platformFile = bluebubbles_file.PlatformFile(
        path: pickedFile.path,
        name: pickedFile.name,
        size: pickedFile.size,
        bytes: pickedFile.bytes,
      );

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
      final updated = await _repository.updateCheckInStatus(
        attendeeId: attendee.id,
        checkedIn: checkedIn,
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

  Future<void> _showMemberProfile(EventAttendee attendee) async {
    final member = attendee.member;
    if (member == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.name ?? 'Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email != null) Text(member.email!),
            if (member.phone != null) Text(member.phone!),
            if (member.city != null)
              Text(member.city!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAttendeeDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final memberIdController = TextEditingController();
    final guestCountController = TextEditingController(text: '0');
    bool checkInNow = false;
    bool sendConfirmation = false;

    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add attendee'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: memberIdController,
                    decoration: const InputDecoration(labelText: 'Member UUID (optional)'),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final uuidRegex = RegExp(
                          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                          caseSensitive: false,
                        );
                        if (!uuidRegex.hasMatch(value.trim())) {
                          return 'Enter a valid UUID';
                        }
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) {
                      if ((value == null || value.trim().isEmpty) && memberIdController.text.isEmpty) {
                        return 'Name required for guests';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  TextFormField(
                    controller: guestCountController,
                    decoration: const InputDecoration(labelText: 'Guest Count'),
                    keyboardType: TextInputType.number,
                  ),
                  CheckboxListTile(
                    value: checkInNow,
                    onChanged: (value) => setDialogState(() => checkInNow = value ?? false),
                    title: const Text('Check in immediately'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: sendConfirmation,
                    onChanged: (value) => setDialogState(() => sendConfirmation = value ?? false),
                    title: const Text('Send RSVP confirmation'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
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
      memberIdController.dispose();
      guestCountController.dispose();
      return;
    }

    setState(() => _loadingAttendees = true);

    try {
      final eventId = _currentEvent.id!;
      final attendee = await _repository.addAttendee(
        eventId: eventId,
        memberId: memberIdController.text.trim().isEmpty ? null : memberIdController.text.trim(),
        guestName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
        guestEmail: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
        guestPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        guestCount: int.tryParse(guestCountController.text) ?? 0,
        checkedIn: checkInNow,
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
      memberIdController.dispose();
      guestCountController.dispose();
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
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search attendees',
                ),
                onChanged: (value) => setState(() => _attendeeSearch = value),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _loadingAttendees ? null : _showAddAttendeeDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add attendee'),
              style: ElevatedButton.styleFrom(backgroundColor: _unityBlue, foregroundColor: Colors.white),
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

  Widget _buildMapCard() {
    final address = _currentEvent.locationAddress;
    if (address == null || address.isEmpty) return const SizedBox.shrink();

    final mapsUri = Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(address)}');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => launchUrl(mapsUri, mode: LaunchMode.externalApplication),
        child: Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_unityBlue, _momentumBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.map_outlined, color: Colors.white, size: 72),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(address, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Tap to open in Apple Maps', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              icon: const Icon(Icons.edit),
              tooltip: 'Edit event',
              onPressed: () => setState(() => _editingDetails = true),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentEvent.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  if (_currentEvent.description != null)
                    Text(_currentEvent.description!),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 8),
                      Text(dateFormat.format(_currentEvent.eventDate.toLocal())),
                    ],
                  ),
                  if (_currentEvent.eventEndDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.more_time_outlined),
                        const SizedBox(width: 8),
                        Text(dateFormat.format(_currentEvent.eventEndDate!.toLocal())),
                      ],
                    ),
                  ],
                  if (_currentEvent.location != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_currentEvent.location!)),
                      ],
                    ),
                  ],
                  if (_currentEvent.eventType != null) ...[
                    const SizedBox(height: 8),
                    Chip(label: Text(_currentEvent.eventType!.toUpperCase())),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(_currentEvent.rsvpEnabled ? 'RSVPs enabled' : 'RSVPs disabled')),
                      Chip(label: Text(_currentEvent.checkinEnabled ? 'Check-in on' : 'Check-in off')),
                      Chip(label: Text(_currentEvent.status.toUpperCase())),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildMapCard(),
          const SizedBox(height: 12),
          _buildImageUploadSection(),
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
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color)),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEventId = widget.initialEvent.id != null;
    final tabCount = hasEventId ? 3 : 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(_currentEvent.id == null ? 'Create Event' : _currentEvent.title),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: tabCount,
          child: Column(
            children: [
              if (hasEventId)
                const TabBar(
                  labelColor: _unityBlue,
                  tabs: [
                    Tab(text: 'Details'),
                    Tab(text: 'Attendees'),
                    Tab(text: 'Check-In'),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (hasEventId)
                      _buildOverviewTab()
                    else
                      _buildForm(),
                    if (hasEventId) _buildAttendeesTab(),
                    if (hasEventId)
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
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
            ],
          ),
        ),
      ),
    );
  }
}
