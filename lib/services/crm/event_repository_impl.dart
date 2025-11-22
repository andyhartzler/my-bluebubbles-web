part of 'event_repository.dart';

class EventRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

  Future<List<Event>> fetchEvents({
    String? searchQuery,
    String? status,
    String? eventType,
    bool upcomingOnly = false,
    bool pastOnly = false,
  }) async {
    if (!isReady) return [];

    var query = _readClient.from('events').select('*');

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    if (eventType != null && eventType.isNotEmpty) {
      query = query.eq('event_type', eventType);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    if (upcomingOnly) {
      query = query.gte('event_date', now);
    } else if (pastOnly) {
      query = query.lt('event_date', now);
    }

    final data = await query.order('event_date', ascending: false);
    final list = (data as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    return list.map((json) => Event.fromJson(json)).toList();
  }

  Future<Event> createEvent(Event event) async {
    if (!isReady) {
      throw Exception('CRM not configured');
    }

    final payload = event.toInsertPayload();
    final response = await _writeClient.from('events').insert(payload).select('*').single();
    return Event.fromJson(response as Map<String, dynamic>);
  }

  Future<Event> updateEvent(Event event) async {
    if (!isReady) {
      throw Exception('CRM not configured');
    }
    final eventId = event.id;
    if (eventId == null) {
      throw Exception('Cannot update event without id');
    }

    final payload = event.toUpdatePayload();
    final response = await _writeClient
        .from('events')
        .update(payload)
        .eq('id', eventId)
        .select('*')
        .single();
    return Event.fromJson(response as Map<String, dynamic>);
  }

  Future<List<EventAttendee>> fetchAttendees(String eventId) async {
    if (!isReady) return [];

    final attendeeData = await _readClient
        .from('event_attendees')
        .select('*, members:member_id(*)')
        .eq('event_id', eventId)
        .order('rsvp_at', ascending: false);

    final attendees = (attendeeData as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(EventAttendee.fromJson)
        .toList();

    await _hydrateMembers(attendees);
    await _enrichDonorBadges(attendees);
    return attendees;
  }

  Future<void> _enrichDonorBadges(List<EventAttendee> attendees) async {
    final memberIds = attendees.map((a) => a.memberId).whereType<String>().toSet();
    final guestPhones = attendees.map((a) => a.guestPhone).whereType<String>().toSet();

    if (memberIds.isEmpty && guestPhones.isEmpty) return;

    final donorsByMemberId = <String, Map<String, dynamic>>{};
    if (memberIds.isNotEmpty) {
      final donorData = await _readClient
          .from('donors')
          .select('member_id,total_donated,is_recurring_donor')
          .inFilter('member_id', memberIds.toList());
      for (final row in donorData as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final memberId = map['member_id'] as String?;
        if (memberId != null) {
          donorsByMemberId[memberId] = map;
        }
      }
    }

    final donorsByPhone = <String, Map<String, dynamic>>{};
    if (guestPhones.isNotEmpty) {
      final donorData = await _readClient
          .from('donors')
          .select('phone,total_donated,is_recurring_donor')
          .inFilter('phone', guestPhones.toList());
      for (final row in donorData as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final phone = map['phone'] as String?;
        if (phone != null) {
          donorsByPhone[phone] = map;
        }
      }
    }

    for (var i = 0; i < attendees.length; i++) {
      final attendee = attendees[i];
      Map<String, dynamic>? donorRow;
      if (attendee.memberId != null) {
        donorRow = donorsByMemberId[attendee.memberId!];
      } else if (attendee.guestPhone != null) {
        donorRow = donorsByPhone[attendee.guestPhone!];
      }
      if (donorRow != null) {
        attendees[i] = attendee.copyWith(
          totalDonated: (donorRow['total_donated'] as num?)?.toDouble(),
          isRecurringDonor: donorRow['is_recurring_donor'] as bool?,
        );
      }
    }
  }

  Future<EventAttendee> _insertAttendee(Map<String, dynamic> payload) async {
    final response = await _writeClient.from('event_attendees').insert(payload).select('*, members:member_id(*)').single();
    return EventAttendee.fromJson(response as Map<String, dynamic>);
  }

  Future<void> _hydrateMembers(List<EventAttendee> attendees) async {
    final memberIds = attendees.map((a) => a.memberId).whereType<String>().toSet();
    if (memberIds.isEmpty) return;

    final memberData = await _readClient
        .from('members')
        .select('id,name,email,phone,phone_e164')
        .inFilter('id', memberIds.toList());

    final members = <String, Member>{};
    for (final row in memberData as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id != null) {
        members[id] = Member.fromJson(map);
      }
    }

    for (var i = 0; i < attendees.length; i++) {
      final attendee = attendees[i];
      final memberId = attendee.memberId;
      if (memberId != null && members.containsKey(memberId)) {
        attendees[i] = attendee.copyWith(member: members[memberId]);
      }
    }
  }

  Future<List<EventAttendee>> searchHistoricalAttendees(String query, {int limit = 10}) async {
    if (!isReady) return [];
    if (query.trim().isEmpty) return [];

    final response = await _readClient
        .from('event_attendees')
        .select('*, members:member_id(*)')
        .or('guest_name.ilike.%$query%,guest_email.ilike.%$query%,guest_phone.ilike.%$query%')
        .order('rsvp_at', ascending: false)
        .limit(limit);

    final attendees = (response as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(EventAttendee.fromJson)
        .toList();

    await _hydrateMembers(attendees);
    await _enrichDonorBadges(attendees);
    return attendees;
  }

  Stream<List<EventAttendee>> watchAttendees(String eventId) {
    if (!isReady) return const Stream.empty();

    return _readClient
        .from('event_attendees')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('rsvp_at', ascending: false)
        .asyncMap((rows) async {
      final attendees = rows.whereType<Map<String, dynamic>>().map(EventAttendee.fromJson).toList();
      await _hydrateMembers(attendees);
      await _enrichDonorBadges(attendees);
      return attendees;
    });
  }

  Future<Member?> previewMemberByUUID(String memberUUID) async {
    if (!isReady) return null;

    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    if (!uuidRegex.hasMatch(memberUUID.trim())) return null;

    final memberData = await _readClient
        .from('members')
        .select('id,name,email,phone,phone_e164,date_joined')
        .eq('id', memberUUID)
        .maybeSingle();

    if (memberData == null) return null;
    return Member.fromJson(memberData as Map<String, dynamic>);
  }

  Future<Member?> previewMemberByPhone(String phoneNumber) async {
    if (!isReady) return null;
    final candidates = buildPhoneLookupCandidates(phoneNumber);
    if (candidates.isEmpty) return null;

    for (final candidate in candidates) {
      final data = await _readClient
          .from('members')
          .select('id,name,email,phone,phone_e164,date_joined')
          .or('phone.eq.$candidate,phone_e164.eq.$candidate')
          .limit(1);
      if (data is List && data.isNotEmpty) {
        return Member.fromJson(data.first as Map<String, dynamic>);
      }
    }
    return null;
  }

  Future<EventAttendee?> checkInByMemberUUID({
    required String eventId,
    required String memberUUID,
  }) async {
    if (!isReady) return null;

    // Validate UUID format before querying database
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    if (!uuidRegex.hasMatch(memberUUID.trim())) {
      throw Exception('Invalid QR code format. Please scan a valid membership card.');
    }

    // First, verify the member exists in the members table
    final memberData = await _readClient
        .from('members')
        .select('id,name,email,phone,date_joined')
        .eq('id', memberUUID)
        .maybeSingle();

    if (memberData == null) {
      throw Exception('Member not found. Please ensure this is a valid membership card.');
    }

    // Check if they already have an attendee record for this event
    final existing = await _readClient
        .from('event_attendees')
        .select('*, members:member_id(*)')
        .eq('event_id', eventId)
        .eq('member_id', memberUUID)
        .maybeSingle();

    if (existing != null) {
      final attendee = EventAttendee.fromJson(existing as Map<String, dynamic>);

      // If already checked in, return existing record
      if (attendee.checkedIn) {
        return attendee;
      }

      // Update existing RSVP to checked in
      final now = DateTime.now();
      await _writeClient
          .from('event_attendees')
          .update({
            'checked_in': true,
            'checked_in_at': now.toUtc().toIso8601String(),
            'checked_in_by': 'qr_code',
          })
          .eq('id', attendee.id);

      return attendee.copyWith(
        checkedIn: true,
        checkedInAt: now,
        checkedInBy: 'qr_code',
      );
    }

    // Member exists but hasn't RSVP'd - create walk-in attendee record
    final now = DateTime.now();
    final payload = {
      'event_id': eventId,
      'member_id': memberUUID,
      'rsvp_status': 'attending',
      'guest_count': 0,
      'checked_in': true,
      'checked_in_at': now.toUtc().toIso8601String(),
      'checked_in_by': 'qr_code',
    };

    return _insertAttendee(payload);
  }

  Future<EventAttendee?> checkInByPhone({
    required String eventId,
    required String phoneNumber,
    required String eventName,
  }) async {
    if (!isReady) return null;

    final candidates = buildPhoneLookupCandidates(phoneNumber);
    if (candidates.isEmpty) return null;

    Map<String, dynamic>? memberRow;
    Map<String, dynamic>? donorRow;

    for (final candidate in candidates) {
      final data = await _readClient
          .from('members')
          .select('id,name,email,phone,date_joined')
          .or('phone.eq.$candidate,phone_e164.eq.$candidate')
          .limit(1);
      if (data is List && data.isNotEmpty) {
        memberRow = data.first as Map<String, dynamic>;
        break;
      }
    }

    if (memberRow == null) {
      for (final candidate in candidates) {
        final donorData = await _readClient
            .from('donors')
            .select('id,name,email,phone,member_id,total_donated,is_recurring_donor')
            .eq('phone', candidate)
            .isFilter('member_id', null)
            .limit(1);
        if (donorData is List && donorData.isNotEmpty) {
          donorRow = donorData.first as Map<String, dynamic>;
          break;
        }
      }
    }

    if (memberRow != null) {
      final memberId = memberRow['id'] as String;
      final existing = await _readClient
          .from('event_attendees')
          .select('*, members:member_id(*)')
          .eq('event_id', eventId)
          .eq('member_id', memberId)
          .maybeSingle();

      if (existing != null) {
        final attendee = EventAttendee.fromJson(existing as Map<String, dynamic>);
        if (!attendee.checkedIn) {
          await _writeClient
              .from('event_attendees')
              .update({
                'checked_in': true,
                'checked_in_at': DateTime.now().toUtc().toIso8601String(),
                'checked_in_by': 'phone_lookup',
              })
              .eq('id', attendee.id);
          return attendee.copyWith(checkedIn: true, checkedInAt: DateTime.now());
        }
        return attendee;
      }

      final payload = {
        'event_id': eventId,
        'member_id': memberId,
        'rsvp_status': 'attending',
        'guest_count': 0,
        'checked_in': true,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
        'checked_in_by': 'phone_lookup',
      };
      return _insertAttendee(payload);
    }

    if (donorRow != null) {
      final phone = donorRow['phone'] as String? ?? phoneNumber;
      final name = donorRow['name'] as String?;
      final email = donorRow['email'] as String?;

      final existing = await _readClient
          .from('event_attendees')
          .select('*, members:member_id(*)')
          .eq('event_id', eventId)
          .eq('guest_phone', phone)
          .maybeSingle();

      if (existing != null) {
        final attendee = EventAttendee.fromJson(existing as Map<String, dynamic>);
        if (!attendee.checkedIn) {
          await _writeClient
              .from('event_attendees')
              .update({
                'checked_in': true,
                'checked_in_at': DateTime.now().toUtc().toIso8601String(),
                'checked_in_by': 'phone_lookup',
              })
              .eq('id', attendee.id);
          return attendee.copyWith(checkedIn: true, checkedInAt: DateTime.now());
        }
        return attendee;
      }

      final payload = {
        'event_id': eventId,
        'member_id': null,
        'guest_name': name,
        'guest_email': email,
        'guest_phone': phone,
        'rsvp_status': 'attending',
        'guest_count': 0,
        'checked_in': true,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
        'checked_in_by': 'phone_lookup',
        'total_donated': donorRow['total_donated'],
        'is_recurring_donor': donorRow['is_recurring_donor'],
      };
      return _insertAttendee(payload);
    }

    final registrationLink =
        'https://events.moyoungdemocrats.org/events/$eventId/register?phone=${Uri.encodeComponent(phoneNumber)}';
    await CRMMessageService.instance.sendRegistrationLink(
      phoneNumber: phoneNumber,
      eventName: eventName,
      registrationLink: registrationLink,
    );
    return null;
  }

  Future<EventAttendee> manualCheckIn(String attendeeId) async {
    final response = await _writeClient
        .from('event_attendees')
        .update({
          'checked_in': true,
          'checked_in_at': DateTime.now().toUtc().toIso8601String(),
          'checked_in_by': 'admin',
        })
        .eq('id', attendeeId)
        .select('*, members:member_id(*)')
        .single();
    return EventAttendee.fromJson(response as Map<String, dynamic>);
  }

  Future<EventAttendee> updateCheckInStatus({
    required String attendeeId,
    required bool checkedIn,
  }) async {
    final now = DateTime.now();
    final response = await _writeClient
        .from('event_attendees')
        .update({
          'checked_in': checkedIn,
          'checked_in_at': checkedIn ? now.toUtc().toIso8601String() : null,
          'checked_in_by': checkedIn ? 'manual' : null,
        })
        .eq('id', attendeeId)
        .select('*, members:member_id(*)')
        .single();

    return EventAttendee.fromJson(response as Map<String, dynamic>);
  }

  Future<EventAttendee> addAttendee({
    required String eventId,
    String? memberId,
    String? guestName,
    String? guestEmail,
    String? guestPhone,
    DateTime? dateOfBirth,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? employer,
    String? occupation,
    int guestCount = 0,
    String rsvpStatus = 'attending',
    bool checkedIn = false,
    bool sendRsvpConfirmation = false,
  }) async {
    final payload = {
      'event_id': eventId,
      'member_id': memberId,
      'guest_name': guestName,
      'guest_email': guestEmail,
      'guest_phone': guestPhone,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'address': address,
      'city': city,
      'state': state,
      'zip': zip,
      'employer': employer,
      'occupation': occupation,
      'guest_count': guestCount,
      'rsvp_status': rsvpStatus,
      'checked_in': checkedIn,
      'checked_in_at': checkedIn ? DateTime.now().toUtc().toIso8601String() : null,
      'checked_in_by': checkedIn ? 'manual' : null,
      'rsvp_at': DateTime.now().toUtc().toIso8601String(),
    };

    final attendee = await _insertAttendee(payload);

    if (sendRsvpConfirmation && guestPhone != null && guestPhone.isNotEmpty) {
      final registrationLink =
          'https://events.moyoungdemocrats.org/events/$eventId/register?phone=${Uri.encodeComponent(guestPhone)}';
      await CRMMessageService.instance.sendRegistrationLink(
        phoneNumber: guestPhone,
        eventName: attendee.displayName,
        registrationLink: registrationLink,
      );
    }

    return attendee;
  }

  Future<Event> uploadEventImage({
    required String eventId,
    required PlatformFile file,
    required bool isSocialShare,
  }) async {
    if (!isReady) {
      throw Exception('CRM not configured');
    }

    final bytes = await _resolveFileBytes(file);
    final extension = p.extension(file.name);
    final contentType = lookupMimeType(file.name) ?? 'application/octet-stream';
    final now = DateTime.now().toUtc();
    final path = 'event_$eventId/${isSocialShare ? 'social_share' : 'website_image'}-${now.millisecondsSinceEpoch}$extension';

    await _writeClient.storage.from('events').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    final publicUrl = _writeClient.storage.from('events').getPublicUrl(path);
    final metadata = {
      'storage_bucket': 'events',
      'storage_path': path,
      'storage_url': publicUrl,
      'file_name': file.name,
      'content_type': contentType,
      'uploaded_at': now.toIso8601String(),
    };

    final response = await _writeClient
        .from('events')
        .update({isSocialShare ? 'social_share_image' : 'website_image': metadata})
        .eq('id', eventId)
        .select('*')
        .single();

    return Event.fromJson(response as Map<String, dynamic>);
  }

  Future<Uint8List> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    if (file.path != null) {
      final ioFile = File(file.path!);
      return await ioFile.readAsBytes();
    }

    throw Exception('No file data available for upload');
  }
}
