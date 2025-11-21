import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _locationAddressController;
  late TextEditingController _maxAttendeesController;
  late TextEditingController _phoneController;

  DateTime? _eventDate;
  DateTime? _eventEndDate;
  DateTime? _rsvpDeadline;
  String? _eventType;
  String _status = 'draft';
  bool _rsvpEnabled = true;
  bool _checkinEnabled = false;

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
    final event = widget.initialEvent;
    _titleController = TextEditingController(text: event.title);
    _descriptionController = TextEditingController(text: event.description ?? '');
    _locationController = TextEditingController(text: event.location ?? '');
    _locationAddressController = TextEditingController(text: event.locationAddress ?? '');
    _maxAttendeesController = TextEditingController(
      text: event.maxAttendees != null ? event.maxAttendees.toString() : '',
    );
    _phoneController = TextEditingController();
    _eventDate = event.eventDate;
    _eventEndDate = event.eventEndDate;
    _rsvpDeadline = event.rsvpDeadline;
    _eventType = event.eventType;
    _status = event.status;
    _rsvpEnabled = event.rsvpEnabled;
    _checkinEnabled = event.checkinEnabled;

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
    _attendeeSub?.cancel();
    super.dispose();
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

  Future<void> _loadAttendees() async {
    if (widget.initialEvent.id == null) return;
    setState(() {
      _loadingAttendees = true;
      _attendeeError = null;
    });

    try {
      final attendees = await _repository.fetchAttendees(widget.initialEvent.id!);
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
    if (widget.initialEvent.id == null) return;

    _attendeeSub?.cancel();
    _attendeeSub = _repository.watchAttendees(widget.initialEvent.id!).listen(
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

  Future<void> _manualCheckIn(EventAttendee attendee) async {
    setState(() => _loadingAttendees = true);
    try {
      final updated = await _repository.manualCheckIn(attendee.id);
      if (!mounted) return;
      setState(() => _loadingAttendees = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${updated.displayName} checked in.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAttendees = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to check in attendee: $e')));
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

  Widget _buildAttendeeList() {
    final filtered = _filteredAttendees();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, color: _unityBlue),
            const SizedBox(width: 8),
            Text('Attendees', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<_AttendeeFilter>(
              value: _attendeeFilter,
              onChanged: (value) => setState(() => _attendeeFilter = value ?? _AttendeeFilter.all),
              items: const [
                DropdownMenuItem(value: _AttendeeFilter.all, child: Text('All')),
                DropdownMenuItem(value: _AttendeeFilter.checkedIn, child: Text('Checked In')),
                DropdownMenuItem(value: _AttendeeFilter.notCheckedIn, child: Text('Not Checked In')),
                DropdownMenuItem(value: _AttendeeFilter.members, child: Text('Members Only')),
                DropdownMenuItem(value: _AttendeeFilter.guests, child: Text('Guests Only')),
              ],
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 220,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search attendees',
                ),
                onChanged: (value) => setState(() => _attendeeSearch = value.trim()),
              ),
            )
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingAttendees)
          const LinearProgressIndicator(minHeight: 2)
        else if (_attendeeError != null)
          Text(_attendeeError!, style: const TextStyle(color: Colors.red))
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No attendees yet.'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final attendee = filtered[index];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: attendee.checkedIn ? _grassrootsGreen.withOpacity(0.08) : null,
                leading: Icon(
                  attendee.checkedIn ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: attendee.checkedIn ? _grassrootsGreen : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(attendee.displayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (attendee.member != null)
                      Text(attendee.member!.email ?? 'Member')
                    else if (attendee.guestEmail != null)
                      Text(attendee.guestEmail!)
                    else if (attendee.guestPhone != null)
                      Text(attendee.guestPhone!),
                    if (attendee.checkedInAt != null)
                      Text('Checked in at ${DateFormat.jm().format(attendee.checkedInAt!.toLocal())}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (attendee.totalDonated != null)
                      Chip(
                        label: Text('\$${attendee.totalDonated!.toStringAsFixed(0)}'),
                        avatar: const Icon(Icons.volunteer_activism, size: 18),
                      ),
                    if (attendee.isRecurringDonor == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Chip(label: Text('Recurring'), avatar: Icon(Icons.repeat, size: 16)),
                      ),
                    const SizedBox(width: 6),
                    Checkbox(
                      value: attendee.checkedIn,
                      onChanged: attendee.checkedIn ? null : (_) => _manualCheckIn(attendee),
                    ),
                  ],
                ),
              );
            },
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
                    onTap: () => _pickDateTime(isEndDate: false),
                    decoration: _decor('Event Date & Time')
                        .copyWith(hintText: _eventDate != null ? dateFormat.format(_eventDate!) : 'Select'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    onTap: () => _pickDateTime(isEndDate: true),
                    decoration: _decor('End Date & Time')
                        .copyWith(hintText: _eventEndDate != null ? dateFormat.format(_eventEndDate!) : 'Optional'),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(widget.initialEvent.id == null ? 'Create Event' : widget.initialEvent.title),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: hasEventId ? 2 : 1,
          child: Column(
            children: [
              if (hasEventId)
                const TabBar(
                  labelColor: _unityBlue,
                  tabs: [
                    Tab(text: 'Details'),
                    Tab(text: 'Check-In'),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildForm(),
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
                            _buildAttendeeList(),
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
