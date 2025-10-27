# BlueBubbles CRM Integration - Complete Implementation Instructions

## Table of Contents
1. [Overview](#overview)
2. [Architecture Analysis](#architecture-analysis)
3. [Integration Principles](#integration-principles)
4. [Step-by-Step Implementation](#step-by-step-implementation)
5. [File Structure](#file-structure)
6. [Detailed Implementation](#detailed-implementation)
7. [UI Customization](#ui-customization)
8. [Bulk Messaging System](#bulk-messaging-system)
9. [Testing Strategy](#testing-strategy)
10. [Deployment Checklist](#deployment-checklist)

---

## Overview

### Goal
Integrate Missouri Young Democrats CRM functionality into the existing BlueBubbles web app without breaking any existing messaging infrastructure. The system must:
- Pull member data from Supabase
- Display member information in chat contexts
- Enable bulk individual messaging based on filters (county, congressional district, committee, age, etc.)
- Maintain ALL existing BlueBubbles functionality unchanged

### Critical Constraint
**DO NOT MODIFY OR MIGRATE** the existing BlueBubbles conversation/message storage system (ObjectBox). This is working perfectly and must remain untouched.

### Technology Stack
- **Existing:** Flutter/Dart, ObjectBox (local storage), BlueBubbles Private API
- **New:** Supabase (member data only), Supabase Flutter SDK

---

## Architecture Analysis

### Current BlueBubbles Structure

```
BlueBubbles Storage (ObjectBox - DO NOT TOUCH):
├── Chat (conversations)
│   ├── guid (unique identifier)
│   ├── chatIdentifier (phone/email)
│   ├── displayName
│   ├── participants (List<Handle>)
│   └── messages (relationship)
├── Message (individual messages)
│   ├── guid
│   ├── text
│   ├── dateCreated
│   ├── isFromMe
│   └── chat (relationship)
├── Handle (contacts/participants)
│   ├── address (phone number)
│   ├── formattedAddress
│   ├── service (iMessage/SMS)
│   └── contact (relationship)
└── Contact (local contact info)
    ├── id
    ├── displayName
    ├── phones
    └── emails
```

### New CRM Layer (Supabase Integration)

```
CRM Layer (Supabase - NEW):
└── members (Supabase table)
    ├── All demographic fields
    ├── phone_e164 (KEY: links to Handle.address)
    └── committee, county, congressional_district (filters)

Integration Point:
Handle.address (BlueBubbles) ←→ member.phone_e164 (Supabase)
```

**Key Insight:** We link BlueBubbles Handles to Supabase Members via phone number (E.164 format). This allows us to:
1. Show member data when viewing any chat
2. Start new chats from the CRM member list
3. Send bulk messages by filtering members, then creating individual chats

---

## Integration Principles

### Core Rules
1. **Never modify ObjectBox models** (Chat, Message, Handle, Contact, Attachment)
2. **Never migrate conversation data** to Supabase
3. **Add, don't replace** - all new code should be additive
4. **Use existing messaging APIs** - don't create new message sending logic
5. **Preserve all UI flows** - existing users should see no breaking changes

### Integration Pattern
```
User Action (CRM) → Filter Members (Supabase) → 
Map to phone_e164 → Find/Create Handles (BlueBubbles) → 
Use existing sendMessage() API → Individual messages sent
```

---

## Step-by-Step Implementation

### Step 1: Add Dependencies

**File: `pubspec.yaml`**

Add to dependencies section:
```yaml
dependencies:
  # Existing dependencies remain unchanged
  
  # NEW CRM DEPENDENCIES
  supabase_flutter: ^2.3.4
```

Run:
```bash
flutter pub get
```

---

### Step 2: Create Supabase Configuration

**File: `lib/config/crm_config.dart`** (NEW FILE)

```dart
/// CRM Configuration - Supabase connection details
/// IMPORTANT: Never commit real credentials to Git
class CRMConfig {
  // TODO: Replace with environment variables in production
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Feature flags
  static const bool crmEnabled = true;
  static const bool bulkMessagingEnabled = true;
  
  // Rate limiting for bulk messages
  static const int messagesPerMinute = 30;
  static const Duration messageDelay = Duration(seconds: 2);
}
```

---

### Step 3: Initialize Supabase Service

**File: `lib/services/crm/supabase_service.dart`** (NEW FILE)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/crm_config.dart';

/// Singleton service for Supabase connection
/// This is the ONLY place that interacts with Supabase
class CRMSupabaseService {
  static final CRMSupabaseService _instance = CRMSupabaseService._internal();
  factory CRMSupabaseService() => _instance;
  CRMSupabaseService._internal();

  SupabaseClient? _client;
  bool _initialized = false;

  /// Initialize Supabase connection
  /// Call this once during app startup
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Supabase.initialize(
        url: CRMConfig.supabaseUrl,
        anonKey: CRMConfig.supabaseAnonKey,
      );
      
      _client = Supabase.instance.client;
      _initialized = true;
      print('✅ CRM Supabase initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize CRM Supabase: $e');
      rethrow;
    }
  }

  /// Get Supabase client instance
  SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw Exception('CRMSupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  bool get isInitialized => _initialized;
}
```

---

### Step 4: Create Member Data Model

**File: `lib/models/crm/member.dart`** (NEW FILE)

```dart
/// Member model - maps to Supabase 'members' table
/// This is a separate model from BlueBubbles Contact/Handle
class Member {
  final String id;
  final DateTime? createdAt;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneE164; // KEY FIELD - links to Handle.address
  final DateTime? dateOfBirth;
  final String? preferredPronouns;
  final String? genderIdentity;
  final String? address;
  final String? county;
  final String? congressionalDistrict;
  final String? race;
  final String? sexualOrientation;
  final String? desireToLead;
  final String? hoursPerWeek;
  final String? educationLevel;
  final bool? registeredVoter;
  final String? inSchool;
  final String? schoolName;
  final String? employed;
  final String? industry;
  final bool? hispanicLatino;
  final String? accommodations;
  final String? communityType;
  final String? languages;
  final String? whyJoin;
  final DateTime? lastContacted;
  final bool optOut;
  final List<String>? committee;
  final String? notes;
  final DateTime? introSentAt;
  final String? optOutReason;
  final DateTime? optOutDate;
  final DateTime? optInDate;
  final String? disability;
  final String? politicalExperience;
  final String? currentInvolvement;
  final String? religion;
  final String? instagram;
  final String? tiktok;
  final String? x;
  final String? zodiacSign;
  final String? leadershipExperience;
  final DateTime? dateJoined;
  final String? goalsAndAmbitions;
  final String? qualifiedExperience;
  final String? referralSource;
  final String? passionateIssues;
  final String? whyIssuesMatter;
  final String? areasOfInterest;

  Member({
    required this.id,
    this.createdAt,
    required this.name,
    this.email,
    this.phone,
    this.phoneE164,
    this.dateOfBirth,
    this.preferredPronouns,
    this.genderIdentity,
    this.address,
    this.county,
    this.congressionalDistrict,
    this.race,
    this.sexualOrientation,
    this.desireToLead,
    this.hoursPerWeek,
    this.educationLevel,
    this.registeredVoter,
    this.inSchool,
    this.schoolName,
    this.employed,
    this.industry,
    this.hispanicLatino,
    this.accommodations,
    this.communityType,
    this.languages,
    this.whyJoin,
    this.lastContacted,
    this.optOut = false,
    this.committee,
    this.notes,
    this.introSentAt,
    this.optOutReason,
    this.optOutDate,
    this.optInDate,
    this.disability,
    this.politicalExperience,
    this.currentInvolvement,
    this.religion,
    this.instagram,
    this.tiktok,
    this.x,
    this.zodiacSign,
    this.leadershipExperience,
    this.dateJoined,
    this.goalsAndAmbitions,
    this.qualifiedExperience,
    this.referralSource,
    this.passionateIssues,
    this.whyIssuesMatter,
    this.areasOfInterest,
  });

  /// Create Member from Supabase JSON response
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      phoneE164: json['phone_e164'] as String?,
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.parse(json['date_of_birth'] as String) 
          : null,
      preferredPronouns: json['preferred_pronouns'] as String?,
      genderIdentity: json['gender_identity'] as String?,
      address: json['address'] as String?,
      county: json['county'] as String?,
      congressionalDistrict: json['congressional_district'] as String?,
      race: json['race'] as String?,
      sexualOrientation: json['sexual_orientation'] as String?,
      desireToLead: json['desire_to_lead'] as String?,
      hoursPerWeek: json['hours_per_week'] as String?,
      educationLevel: json['education_level'] as String?,
      registeredVoter: json['registered_voter'] as bool?,
      inSchool: json['in_school'] as String?,
      schoolName: json['school_name'] as String?,
      employed: json['employed'] as String?,
      industry: json['industry'] as String?,
      hispanicLatino: json['hispanic_latino'] as bool?,
      accommodations: json['accommodations'] as String?,
      communityType: json['community_type'] as String?,
      languages: json['languages'] as String?,
      whyJoin: json['why_join'] as String?,
      lastContacted: json['last_contacted'] != null 
          ? DateTime.parse(json['last_contacted'] as String) 
          : null,
      optOut: json['opt_out'] as bool? ?? false,
      committee: json['committee'] != null 
          ? List<String>.from(json['committee'] as List) 
          : null,
      notes: json['notes'] as String?,
      introSentAt: json['intro_sent_at'] != null 
          ? DateTime.parse(json['intro_sent_at'] as String) 
          : null,
      optOutReason: json['opt_out_reason'] as String?,
      optOutDate: json['opt_out_date'] != null 
          ? DateTime.parse(json['opt_out_date'] as String) 
          : null,
      optInDate: json['opt_in_date'] != null 
          ? DateTime.parse(json['opt_in_date'] as String) 
          : null,
      disability: json['disability'] as String?,
      politicalExperience: json['political_experience'] as String?,
      currentInvolvement: json['current_involvement'] as String?,
      religion: json['religion'] as String?,
      instagram: json['instagram'] as String?,
      tiktok: json['tiktok'] as String?,
      x: json['x'] as String?,
      zodiacSign: json['zodiac_sign'] as String?,
      leadershipExperience: json['leadership_experience'] as String?,
      dateJoined: json['date_joined'] != null 
          ? DateTime.parse(json['date_joined'] as String) 
          : null,
      goalsAndAmbitions: json['goals_and_ambitions'] as String?,
      qualifiedExperience: json['qualified_experience'] as String?,
      referralSource: json['referral_source'] as String?,
      passionateIssues: json['passionate_issues'] as String?,
      whyIssuesMatter: json['why_issues_matter'] as String?,
      areasOfInterest: json['areas_of_interest'] as String?,
    );
  }

  /// Convert to JSON for Supabase updates
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'name': name,
      'email': email,
      'phone': phone,
      'phone_e164': phoneE164,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'preferred_pronouns': preferredPronouns,
      'gender_identity': genderIdentity,
      'address': address,
      'county': county,
      'congressional_district': congressionalDistrict,
      'race': race,
      'sexual_orientation': sexualOrientation,
      'desire_to_lead': desireToLead,
      'hours_per_week': hoursPerWeek,
      'education_level': educationLevel,
      'registered_voter': registeredVoter,
      'in_school': inSchool,
      'school_name': schoolName,
      'employed': employed,
      'industry': industry,
      'hispanic_latino': hispanicLatino,
      'accommodations': accommodations,
      'community_type': communityType,
      'languages': languages,
      'why_join': whyJoin,
      'last_contacted': lastContacted?.toIso8601String(),
      'opt_out': optOut,
      'committee': committee,
      'notes': notes,
      'intro_sent_at': introSentAt?.toIso8601String(),
      'opt_out_reason': optOutReason,
      'opt_out_date': optOutDate?.toIso8601String(),
      'opt_in_date': optInDate?.toIso8601String(),
      'disability': disability,
      'political_experience': politicalExperience,
      'current_involvement': currentInvolvement,
      'religion': religion,
      'instagram': instagram,
      'tiktok': tiktok,
      'x': x,
      'zodiac_sign': zodiacSign,
      'leadership_experience': leadershipExperience,
      'date_joined': dateJoined?.toIso8601String().split('T')[0],
      'goals_and_ambitions': goalsAndAmbitions,
      'qualified_experience': qualifiedExperience,
      'referral_source': referralSource,
      'passionate_issues': passionateIssues,
      'why_issues_matter': whyIssuesMatter,
      'areas_of_interest': areasOfInterest,
    };
  }

  /// Helper: Get age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  /// Helper: Check if member can be contacted
  bool get canContact => !optOut && phoneE164 != null && phoneE164!.isNotEmpty;

  /// Helper: Format committees as string
  String get committeesString => committee?.join(', ') ?? 'None';

  /// Copy with method for updates
  Member copyWith({
    String? id,
    DateTime? createdAt,
    String? name,
    String? email,
    String? phone,
    String? phoneE164,
    DateTime? dateOfBirth,
    String? preferredPronouns,
    String? genderIdentity,
    String? address,
    String? county,
    String? congressionalDistrict,
    String? race,
    String? sexualOrientation,
    String? desireToLead,
    String? hoursPerWeek,
    String? educationLevel,
    bool? registeredVoter,
    String? inSchool,
    String? schoolName,
    String? employed,
    String? industry,
    bool? hispanicLatino,
    String? accommodations,
    String? communityType,
    String? languages,
    String? whyJoin,
    DateTime? lastContacted,
    bool? optOut,
    List<String>? committee,
    String? notes,
    DateTime? introSentAt,
    String? optOutReason,
    DateTime? optOutDate,
    DateTime? optInDate,
    String? disability,
    String? politicalExperience,
    String? currentInvolvement,
    String? religion,
    String? instagram,
    String? tiktok,
    String? x,
    String? zodiacSign,
    String? leadershipExperience,
    DateTime? dateJoined,
    String? goalsAndAmbitions,
    String? qualifiedExperience,
    String? referralSource,
    String? passionateIssues,
    String? whyIssuesMatter,
    String? areasOfInterest,
  }) {
    return Member(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneE164: phoneE164 ?? this.phoneE164,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredPronouns: preferredPronouns ?? this.preferredPronouns,
      genderIdentity: genderIdentity ?? this.genderIdentity,
      address: address ?? this.address,
      county: county ?? this.county,
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      race: race ?? this.race,
      sexualOrientation: sexualOrientation ?? this.sexualOrientation,
      desireToLead: desireToLead ?? this.desireToLead,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      educationLevel: educationLevel ?? this.educationLevel,
      registeredVoter: registeredVoter ?? this.registeredVoter,
      inSchool: inSchool ?? this.inSchool,
      schoolName: schoolName ?? this.schoolName,
      employed: employed ?? this.employed,
      industry: industry ?? this.industry,
      hispanicLatino: hispanicLatino ?? this.hispanicLatino,
      accommodations: accommodations ?? this.accommodations,
      communityType: communityType ?? this.communityType,
      languages: languages ?? this.languages,
      whyJoin: whyJoin ?? this.whyJoin,
      lastContacted: lastContacted ?? this.lastContacted,
      optOut: optOut ?? this.optOut,
      committee: committee ?? this.committee,
      notes: notes ?? this.notes,
      introSentAt: introSentAt ?? this.introSentAt,
      optOutReason: optOutReason ?? this.optOutReason,
      optOutDate: optOutDate ?? this.optOutDate,
      optInDate: optInDate ?? this.optInDate,
      disability: disability ?? this.disability,
      politicalExperience: politicalExperience ?? this.politicalExperience,
      currentInvolvement: currentInvolvement ?? this.currentInvolvement,
      religion: religion ?? this.religion,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      x: x ?? this.x,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      leadershipExperience: leadershipExperience ?? this.leadershipExperience,
      dateJoined: dateJoined ?? this.dateJoined,
      goalsAndAmbitions: goalsAndAmbitions ?? this.goalsAndAmbitions,
      qualifiedExperience: qualifiedExperience ?? this.qualifiedExperience,
      referralSource: referralSource ?? this.referralSource,
      passionateIssues: passionateIssues ?? this.passionateIssues,
      whyIssuesMatter: whyIssuesMatter ?? this.whyIssuesMatter,
      areasOfInterest: areasOfInterest ?? this.areasOfInterest,
    );
  }
}
```

---

### Step 5: Create Member Repository

**File: `lib/services/crm/member_repository.dart`** (NEW FILE)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/crm/member.dart';
import 'supabase_service.dart';

/// Repository for member CRUD operations
/// All Supabase queries for members go through here
class MemberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// Get all members (with optional filters)
  Future<List<Member>> getAllMembers({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    int? minAge,
    int? maxAge,
    bool? optedOut,
  }) async {
    try {
      var query = _supabase.client.from('members').select();

      // Apply filters
      if (county != null && county.isNotEmpty) {
        query = query.eq('county', county);
      }
      
      if (congressionalDistrict != null && congressionalDistrict.isNotEmpty) {
        query = query.eq('congressional_district', congressionalDistrict);
      }
      
      if (committees != null && committees.isNotEmpty) {
        query = query.overlaps('committee', committees);
      }
      
      if (optedOut != null) {
        query = query.eq('opt_out', optedOut);
      }

      final response = await query as List<dynamic>;
      
      List<Member> members = response
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();

      // Apply age filter in-memory (since calculated field)
      if (minAge != null || maxAge != null) {
        members = members.where((member) {
          final age = member.age;
          if (age == null) return false;
          if (minAge != null && age < minAge) return false;
          if (maxAge != null && age > maxAge) return false;
          return true;
        }).toList();
      }

      return members;
    } catch (e) {
      print('❌ Error fetching members: $e');
      rethrow;
    }
  }

  /// Get member by ID
  Future<Member?> getMemberById(String id) async {
    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('id', id)
          .single();

      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by ID: $e');
      return null;
    }
  }

  /// Get member by phone number (E.164 format)
  /// This is the KEY lookup for linking to BlueBubbles Handles
  Future<Member?> getMemberByPhone(String phoneE164) async {
    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('phone_e164', phoneE164)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by phone: $e');
      return null;
    }
  }

  /// Get all unique counties (for filter UI)
  Future<List<String>> getUniqueCounties() async {
    try {
      final response = await _supabase.client
          .from('members')
          .select('county')
          .not('county', 'is', null);

      final counties = (response as List<dynamic>)
          .map((item) => item['county'] as String)
          .toSet()
          .toList();
      
      counties.sort();
      return counties;
    } catch (e) {
      print('❌ Error fetching counties: $e');
      return [];
    }
  }

  /// Get all unique congressional districts (for filter UI)
  Future<List<String>> getUniqueCongressionalDistricts() async {
    try {
      final response = await _supabase.client
          .from('members')
          .select('congressional_district')
          .not('congressional_district', 'is', null);

      final districts = (response as List<dynamic>)
          .map((item) => item['congressional_district'] as String)
          .toSet()
          .toList();
      
      districts.sort();
      return districts;
    } catch (e) {
      print('❌ Error fetching congressional districts: $e');
      return [];
    }
  }

  /// Get all unique committees (for filter UI)
  Future<List<String>> getUniqueCommittees() async {
    try {
      final response = await _supabase.client
          .from('members')
          .select('committee')
          .not('committee', 'is', null);

      // Flatten array of arrays
      final allCommittees = <String>{};
      for (var item in response as List<dynamic>) {
        final committees = item['committee'] as List<dynamic>?;
        if (committees != null) {
          allCommittees.addAll(committees.map((c) => c.toString()));
        }
      }
      
      final sortedCommittees = allCommittees.toList();
      sortedCommittees.sort();
      return sortedCommittees;
    } catch (e) {
      print('❌ Error fetching committees: $e');
      return [];
    }
  }

  /// Update member's last contacted timestamp
  Future<void> updateLastContacted(String memberId) async {
    try {
      await _supabase.client
          .from('members')
          .update({'last_contacted': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating last contacted: $e');
    }
  }

  /// Update member's intro sent timestamp
  Future<void> markIntroSent(String memberId) async {
    try {
      await _supabase.client
          .from('members')
          .update({'intro_sent_at': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error marking intro sent: $e');
    }
  }

  /// Update member's opt-out status
  Future<void> updateOptOutStatus(
    String memberId, 
    bool optOut, 
    {String? reason}
  ) async {
    try {
      final data = {
        'opt_out': optOut,
        optOut ? 'opt_out_date' : 'opt_in_date': DateTime.now().toIso8601String(),
      };
      
      if (reason != null) {
        data['opt_out_reason'] = reason;
      }

      await _supabase.client
          .from('members')
          .update(data)
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating opt-out status: $e');
    }
  }

  /// Update member notes
  Future<void> updateNotes(String memberId, String notes) async {
    try {
      await _supabase.client
          .from('members')
          .update({'notes': notes})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating notes: $e');
    }
  }

  /// Search members by name or phone
  Future<List<Member>> searchMembers(String query) async {
    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%,phone_e164.ilike.%$query%');

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error searching members: $e');
      return [];
    }
  }

  /// Get member statistics
  Future<Map<String, dynamic>> getMemberStats() async {
    try {
      // Total members
      final totalResponse = await _supabase.client
          .from('members')
          .select('id', const FetchOptions(count: CountOption.exact));
      final total = totalResponse.count ?? 0;

      // Opted out
      final optedOutResponse = await _supabase.client
          .from('members')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('opt_out', true);
      final optedOut = optedOutResponse.count ?? 0;

      // Has phone
      final withPhoneResponse = await _supabase.client
          .from('members')
          .select('id', const FetchOptions(count: CountOption.exact))
          .not('phone_e164', 'is', null);
      final withPhone = withPhoneResponse.count ?? 0;

      return {
        'total': total,
        'optedOut': optedOut,
        'contactable': total - optedOut,
        'withPhone': withPhone,
      };
    } catch (e) {
      print('❌ Error fetching member stats: $e');
      return {
        'total': 0,
        'optedOut': 0,
        'contactable': 0,
        'withPhone': 0,
      };
    }
  }
}
```

---

### Step 6: Create Message Filter Model

**File: `lib/models/crm/message_filter.dart`** (NEW FILE)

```dart
/// Filter criteria for bulk messaging
/// Used to select which members receive a message
class MessageFilter {
  final String? county;
  final String? congressionalDistrict;
  final List<String>? committees;
  final int? minAge;
  final int? maxAge;
  final bool excludeOptedOut;
  final bool excludeRecentlyContacted;
  final Duration? recentContactThreshold;

  MessageFilter({
    this.county,
    this.congressionalDistrict,
    this.committees,
    this.minAge,
    this.maxAge,
    this.excludeOptedOut = true,
    this.excludeRecentlyContacted = false,
    this.recentContactThreshold = const Duration(days: 7),
  });

  /// Check if any filters are active
  bool get hasActiveFilters =>
      county != null ||
      congressionalDistrict != null ||
      (committees != null && committees!.isNotEmpty) ||
      minAge != null ||
      maxAge != null;

  /// Get human-readable description of filters
  String get description {
    final parts = <String>[];
    
    if (county != null) parts.add('County: $county');
    if (congressionalDistrict != null) parts.add('District: $congressionalDistrict');
    if (committees != null && committees!.isNotEmpty) {
      parts.add('Committees: ${committees!.join(", ")}');
    }
    if (minAge != null || maxAge != null) {
      if (minAge != null && maxAge != null) {
        parts.add('Age: $minAge-$maxAge');
      } else if (minAge != null) {
        parts.add('Age: $minAge+');
      } else {
        parts.add('Age: up to $maxAge');
      }
    }
    
    if (excludeOptedOut) parts.add('Excluding opted-out');
    if (excludeRecentlyContacted) {
      parts.add('Not contacted in ${recentContactThreshold!.inDays} days');
    }

    return parts.isEmpty ? 'All members' : parts.join(' • ');
  }

  MessageFilter copyWith({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    int? minAge,
    int? maxAge,
    bool? excludeOptedOut,
    bool? excludeRecentlyContacted,
    Duration? recentContactThreshold,
  }) {
    return MessageFilter(
      county: county ?? this.county,
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      committees: committees ?? this.committees,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      excludeOptedOut: excludeOptedOut ?? this.excludeOptedOut,
      excludeRecentlyContacted: excludeRecentlyContacted ?? this.excludeRecentlyContacted,
      recentContactThreshold: recentContactThreshold ?? this.recentContactThreshold,
    );
  }
}
```

---

### Step 7: Create CRM Message Service

**File: `lib/services/crm/crm_message_service.dart`** (NEW FILE)

```dart
import 'dart:async';
import '../../models/crm/member.dart';
import '../../models/crm/message_filter.dart';
import '../crm/member_repository.dart';
// TODO: Import existing BlueBubbles message service
// Example: import '../messages/message_service.dart';

/// Bridge between CRM and BlueBubbles messaging
/// Handles bulk messaging by creating individual chats
class CRMMessageService {
  final MemberRepository _memberRepo = MemberRepository();
  
  // Rate limiting
  static const int messagesPerMinute = 30;
  static const Duration delayBetweenMessages = Duration(seconds: 2);

  /// Get filtered members for messaging
  Future<List<Member>> getFilteredMembers(MessageFilter filter) async {
    try {
      var members = await _memberRepo.getAllMembers(
        county: filter.county,
        congressionalDistrict: filter.congressionalDistrict,
        committees: filter.committees,
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        optedOut: filter.excludeOptedOut ? false : null,
      );

      // Filter by recent contact
      if (filter.excludeRecentlyContacted) {
        final threshold = DateTime.now().subtract(
          filter.recentContactThreshold ?? const Duration(days: 7)
        );
        members = members.where((m) {
          return m.lastContacted == null || m.lastContacted!.isBefore(threshold);
        }).toList();
      }

      // Only return members with valid phone numbers
      members = members.where((m) => m.canContact).toList();

      return members;
    } catch (e) {
      print('❌ Error getting filtered members: $e');
      return [];
    }
  }

  /// Send individual messages to filtered members
  /// Returns: Map of member ID to success/failure status
  Future<Map<String, bool>> sendBulkMessages({
    required MessageFilter filter,
    required String messageText,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <String, bool>{};
    
    try {
      // Get filtered members
      final members = await getFilteredMembers(filter);
      final total = members.length;

      if (total == 0) {
        print('⚠️ No members match the filter criteria');
        return results;
      }

      print('📤 Sending messages to $total members...');

      // Send messages with rate limiting
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        
        try {
          // TODO: Replace with actual BlueBubbles message sending
          // Example:
          // final success = await MessageService.sendMessage(
          //   address: member.phoneE164!,
          //   text: messageText,
          // );
          
          // PLACEHOLDER - replace with actual implementation
          final success = await _sendSingleMessage(
            phoneNumber: member.phoneE164!,
            message: messageText,
          );

          results[member.id] = success;

          if (success) {
            // Update last contacted timestamp
            await _memberRepo.updateLastContacted(member.id);
          }

          // Report progress
          onProgress?.call(i + 1, total);

          // Rate limiting: wait between messages
          if (i < members.length - 1) {
            await Future.delayed(delayBetweenMessages);
          }

        } catch (e) {
          print('❌ Failed to send message to ${member.name}: $e');
          results[member.id] = false;
        }
      }

      final successCount = results.values.where((v) => v).length;
      print('✅ Successfully sent $successCount/$total messages');

      return results;
    } catch (e) {
      print('❌ Error in bulk message sending: $e');
      return results;
    }
  }

  /// PLACEHOLDER: Send single message via BlueBubbles
  /// TODO: Replace this with actual BlueBubbles API call
  Future<bool> _sendSingleMessage({
    required String phoneNumber,
    required String message,
  }) async {
    // IMPLEMENTATION NEEDED:
    // 1. Find or create Handle for this phone number in BlueBubbles
    // 2. Find or create Chat for this Handle
    // 3. Use existing BlueBubbles sendMessage() API
    // 4. Return true if successful, false otherwise
    
    print('📨 Would send to $phoneNumber: $message');
    
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 100));
    
    // TODO: Replace with actual implementation
    return true;
  }

  /// Preview: Get count of members that would receive message
  Future<int> previewBulkMessage(MessageFilter filter) async {
    final members = await getFilteredMembers(filter);
    return members.length;
  }

  /// Get member info for a phone number (for displaying in chat)
  Future<Member?> getMemberByPhone(String phoneE164) async {
    return await _memberRepo.getMemberByPhone(phoneE164);
  }
}
```

---

### Step 8: Initialize CRM on App Startup

**File: `lib/main.dart`** (MODIFY EXISTING)

Find the `main()` function and add CRM initialization:

```dart
import 'package:flutter/material.dart';
// ... existing imports ...

// NEW IMPORTS
import 'services/crm/supabase_service.dart';
import 'config/crm_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... existing initialization code ...
  
  // NEW: Initialize CRM Supabase
  if (CRMConfig.crmEnabled) {
    try {
      await CRMSupabaseService().initialize();
      print('✅ CRM system initialized');
    } catch (e) {
      print('⚠️ CRM system failed to initialize: $e');
      // Continue app startup even if CRM fails
    }
  }
  
  runApp(MyApp());
}
```

---

### Step 9: Create Members List Screen

**File: `lib/screens/crm/members_list_screen.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../../models/crm/member.dart';
import '../../services/crm/member_repository.dart';
import 'member_detail_screen.dart';

/// Screen showing all CRM members with search and filters
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({Key? key}) : super(key: key);

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  bool _loading = true;
  String _searchQuery = '';
  
  // Filter state
  String? _selectedCounty;
  String? _selectedDistrict;
  List<String>? _selectedCommittees;
  
  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      // Load members and filter options in parallel
      final results = await Future.wait([
        _memberRepo.getAllMembers(),
        _memberRepo.getUniqueCounties(),
        _memberRepo.getUniqueCongressionalDistricts(),
        _memberRepo.getUniqueCommittees(),
      ]);

      setState(() {
        _members = results[0] as List<Member>;
        _filteredMembers = _members;
        _counties = results[1] as List<String>;
        _districts = results[2] as List<String>;
        _committees = results[3] as List<String>;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading members: $e');
      setState(() => _loading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _members.where((member) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesName = member.name.toLowerCase().contains(query);
          final matchesPhone = member.phone?.toLowerCase().contains(query) ?? false;
          if (!matchesName && !matchesPhone) return false;
        }

        // County filter
        if (_selectedCounty != null && member.county != _selectedCounty) {
          return false;
        }

        // District filter
        if (_selectedDistrict != null && 
            member.congressionalDistrict != _selectedDistrict) {
          return false;
        }

        // Committee filter
        if (_selectedCommittees != null && _selectedCommittees!.isNotEmpty) {
          if (member.committee == null) return false;
          final hasCommittee = _selectedCommittees!.any(
            (c) => member.committee!.contains(c)
          );
          if (!hasCommittee) return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCounty = null;
      _selectedDistrict = null;
      _selectedCommittees = null;
      _filteredMembers = _members;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              // TODO: Navigate to bulk message screen
              // Navigator.push(context, MaterialPageRoute(
              //   builder: (_) => BulkMessageScreen(),
              // ));
            },
            tooltip: 'Bulk Message',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // County filter
                FilterChip(
                  label: Text(_selectedCounty ?? 'County'),
                  selected: _selectedCounty != null,
                  onSelected: (selected) {
                    _showCountyFilter();
                  },
                ),
                const SizedBox(width: 8),

                // District filter
                FilterChip(
                  label: Text(_selectedDistrict ?? 'District'),
                  selected: _selectedDistrict != null,
                  onSelected: (selected) {
                    _showDistrictFilter();
                  },
                ),
                const SizedBox(width: 8),

                // Committee filter
                FilterChip(
                  label: Text(_selectedCommittees == null || _selectedCommittees!.isEmpty
                      ? 'Committee'
                      : '${_selectedCommittees!.length} committees'),
                  selected: _selectedCommittees != null && _selectedCommittees!.isNotEmpty,
                  onSelected: (selected) {
                    _showCommitteeFilter();
                  },
                ),
                const SizedBox(width: 8),

                // Clear filters
                if (_selectedCounty != null || 
                    _selectedDistrict != null || 
                    (_selectedCommittees != null && _selectedCommittees!.isNotEmpty))
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ),

          const Divider(),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Showing ${_filteredMembers.length} of ${_members.length} members',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          // Members list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No members found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          return _buildMemberTile(member);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Member member) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(member.name[0].toUpperCase()),
      ),
      title: Text(member.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (member.phone != null) Text(member.phone!),
          if (member.county != null || member.congressionalDistrict != null)
            Text(
              [
                if (member.county != null) member.county!,
                if (member.congressionalDistrict != null) 'CD-${member.congressionalDistrict}',
              ].join(' • '),
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.optOut)
            const Chip(
              label: Text('Opted Out', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.red,
              labelStyle: TextStyle(color: Colors.white),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(member: member),
          ),
        );
      },
    );
  }

  void _showCountyFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by County'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Counties'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedCounty,
                  onChanged: (value) {
                    setState(() => _selectedCounty = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
              ..._counties.map((county) => ListTile(
                    title: Text(county),
                    leading: Radio<String?>(
                      value: county,
                      groupValue: _selectedCounty,
                      onChanged: (value) {
                        setState(() => _selectedCounty = value);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistrictFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Congressional District'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Districts'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedDistrict,
                  onChanged: (value) {
                    setState(() => _selectedDistrict = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
              ..._districts.map((district) => ListTile(
                    title: Text('District $district'),
                    leading: Radio<String?>(
                      value: district,
                      groupValue: _selectedDistrict,
                      onChanged: (value) {
                        setState(() => _selectedDistrict = value);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommitteeFilter() {
    final tempSelected = List<String>.from(_selectedCommittees ?? []);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Committee'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setDialogState) => ListView(
              shrinkWrap: true,
              children: _committees.map((committee) {
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
                _selectedCommittees = tempSelected.isEmpty ? null : tempSelected;
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
```

---

### Step 10: Create Member Detail Screen

**File: `lib/screens/crm/member_detail_screen.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/crm/member.dart';
import '../../services/crm/member_repository.dart';

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
  late Member _member;
  final TextEditingController _notesController = TextEditingController();
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _notesController.text = _member.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    try {
      await _memberRepo.updateNotes(_member.id, _notesController.text);
      setState(() {
        _member = _member.copyWith(notes: _notesController.text);
        _editingNotes = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notes: $e')),
        );
      }
    }
  }

  Future<void> _toggleOptOut() async {
    final newOptOutStatus = !_member.optOut;
    
    try {
      await _memberRepo.updateOptOutStatus(
        _member.id,
        newOptOutStatus,
        reason: newOptOutStatus ? 'Manually opted out' : null,
      );

      setState(() {
        _member = _member.copyWith(
          optOut: newOptOutStatus,
          optOutDate: newOptOutStatus ? DateTime.now() : _member.optOutDate,
          optInDate: !newOptOutStatus ? DateTime.now() : _member.optInDate,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newOptOutStatus ? 'Member opted out' : 'Member opted in'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating opt-out status: $e')),
        );
      }
    }
  }

  void _startChat() {
    if (_member.phoneE164 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    // TODO: Integrate with BlueBubbles to start/open chat
    // Example:
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => ConversationView(
    //     chat: findOrCreateChat(_member.phoneE164!),
    //   ),
    // ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Would start chat with ${_member.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _member.canContact ? _startChat : null,
            tooltip: 'Start Chat',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header with avatar
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

          // Opt-out status
          if (_member.optOut)
            Center(
              child: Chip(
                label: const Text('OPTED OUT'),
                backgroundColor: Colors.red,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),

          const SizedBox(height: 24),

          // Contact Information
          _buildSection(
            'Contact Information',
            [
              if (_member.phone != null)
                _buildInfoRow('Phone', _member.phone!, 
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _member.phone!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone copied')),
                      );
                    },
                  ),
                ),
              if (_member.email != null)
                _buildInfoRow('Email', _member.email!,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _member.email!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copied')),
                      );
                    },
                  ),
                ),
              if (_member.address != null)
                _buildInfoRow('Address', _member.address!),
            ],
          ),

          // Political Information
          _buildSection(
            'Political Information',
            [
              if (_member.county != null)
                _buildInfoRow('County', _member.county!),
              if (_member.congressionalDistrict != null)
                _buildInfoRow('Congressional District', 'CD-${_member.congressionalDistrict}'),
              if (_member.committee != null && _member.committee!.isNotEmpty)
                _buildInfoRow('Committees', _member.committeesString),
              if (_member.registeredVoter != null)
                _buildInfoRow('Registered Voter', _member.registeredVoter! ? 'Yes' : 'No'),
              if (_member.politicalExperience != null)
                _buildInfoRow('Political Experience', _member.politicalExperience!),
              if (_member.currentInvolvement != null)
                _buildInfoRow('Current Involvement', _member.currentInvolvement!),
            ],
          ),

          // Personal Information
          _buildSection(
            'Personal Information',
            [
              if (_member.age != null)
                _buildInfoRow('Age', '${_member.age} years old'),
              if (_member.preferredPronouns != null)
                _buildInfoRow('Pronouns', _member.preferredPronouns!),
              if (_member.genderIdentity != null)
                _buildInfoRow('Gender Identity', _member.genderIdentity!),
              if (_member.race != null)
                _buildInfoRow('Race', _member.race!),
              if (_member.hispanicLatino != null)
                _buildInfoRow('Hispanic/Latino', _member.hispanicLatino! ? 'Yes' : 'No'),
            ],
          ),

          // Notes
          _buildSection(
            'Notes',
            [
              if (!_editingNotes && (_member.notes == null || _member.notes!.isEmpty))
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add notes'),
                  onPressed: () => setState(() => _editingNotes = true),
                ),
              if (!_editingNotes && _member.notes != null && _member.notes!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_member.notes!),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () => setState(() => _editingNotes = true),
                    ),
                  ],
                ),
              if (_editingNotes)
                Column(
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
                ),
            ],
          ),

          // Metadata
          _buildSection(
            'Metadata',
            [
              if (_member.lastContacted != null)
                _buildInfoRow('Last Contacted', _formatDate(_member.lastContacted!)),
              if (_member.introSentAt != null)
                _buildInfoRow('Intro Sent', _formatDate(_member.introSentAt!)),
              if (_member.dateJoined != null)
                _buildInfoRow('Date Joined', _formatDate(_member.dateJoined!)),
              if (_member.createdAt != null)
                _buildInfoRow('Added to System', _formatDate(_member.createdAt!)),
            ],
          ),

          const SizedBox(height: 24),

          // Actions
          ElevatedButton.icon(
            icon: Icon(_member.optOut ? Icons.check_circle : Icons.block),
            label: Text(_member.optOut ? 'Opt In' : 'Opt Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _member.optOut ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggleOptOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: Text(value)),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
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
}
```

---

### Step 11: Add Navigation to CRM

**File: `lib/layouts/navigation/navigation.dart`** (MODIFY EXISTING)

Find where navigation items are defined and add CRM tab:

```dart
// Add to navigation items list:
NavigationItem(
  icon: Icons.people,
  label: 'CRM',
  route: '/crm',
  screen: const MembersListScreen(),
),
```

---

## Bulk Messaging System

### Step 12: Create Bulk Message Screen

**File: `lib/screens/crm/bulk_message_screen.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../../models/crm/member.dart';
import '../../models/crm/message_filter.dart';
import '../../services/crm/crm_message_service.dart';
import '../../services/crm/member_repository.dart';

/// Screen for sending bulk individual messages
class BulkMessageScreen extends StatefulWidget {
  const BulkMessageScreen({Key? key}) : super(key: key);

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen> {
  final CRMMessageService _messageService = CRMMessageService();
  final MemberRepository _memberRepo = MemberRepository();
  final TextEditingController _messageController = TextEditingController();
  
  // Filter state
  MessageFilter _filter = MessageFilter();
  List<Member> _previewMembers = [];
  bool _loadingPreview = false;
  bool _sending = false;
  int _currentProgress = 0;
  int _totalMessages = 0;
  
  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _updatePreview();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    final results = await Future.wait([
      _memberRepo.getUniqueCounties(),
      _memberRepo.getUniqueCongressionalDistricts(),
      _memberRepo.getUniqueCommittees(),
    ]);

    setState(() {
      _counties = results[0];
      _districts = results[1];
      _committees = results[2];
    });
  }

  Future<void> _updatePreview() async {
    setState(() => _loadingPreview = true);

    try {
      final members = await _messageService.getFilteredMembers(_filter);
      setState(() {
        _previewMembers = members.take(5).toList();
        _totalMessages = members.length;
        _loadingPreview = false;
      });
    } catch (e) {
      print('❌ Error updating preview: $e');
      setState(() => _loadingPreview = false);
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

    // Confirm before sending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Message'),
        content: Text(
          'Send message to $_totalMessages members?\n\n'
          'This will send individual messages at a rate of 30 per minute.',
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
        filter: _filter,
        messageText: _messageController.text,
        onProgress: (current, total) {
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
      );

      final successCount = results.values.where((v) => v).length;
      
      setState(() => _sending = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bulk Message Complete'),
            content: Text(
              'Successfully sent $successCount of $_totalMessages messages',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Message'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Message input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _messageController,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            hintText: 'Enter your message here...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),

                        // County dropdown
                        DropdownButtonFormField<String?>(
                          value: _filter.county,
                          decoration: const InputDecoration(
                            labelText: 'County',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Counties')),
                            ..._counties.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(county: value);
                            });
                            _updatePreview();
                          },
                        ),

                        const SizedBox(height: 12),

                        // District dropdown
                        DropdownButtonFormField<String?>(
                          value: _filter.congressionalDistrict,
                          decoration: const InputDecoration(
                            labelText: 'Congressional District',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Districts')),
                            ..._districts.map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('District $d'),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(congressionalDistrict: value);
                            });
                            _updatePreview();
                          },
                        ),

                        const SizedBox(height: 12),

                        // Age range
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Min Age',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final age = int.tryParse(value);
                                  setState(() {
                                    _filter = _filter.copyWith(minAge: age);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Max Age',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final age = int.tryParse(value);
                                  setState(() {
                                    _filter = _filter.copyWith(maxAge: age);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Checkboxes
                        CheckboxListTile(
                          title: const Text('Exclude opted-out members'),
                          value: _filter.excludeOptedOut,
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(excludeOptedOut: value ?? true);
                            });
                            _updatePreview();
                          },
                        ),

                        CheckboxListTile(
                          title: const Text('Exclude recently contacted (7 days)'),
                          value: _filter.excludeRecentlyContacted,
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(excludeRecentlyContacted: value ?? false);
                            });
                            _updatePreview();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Preview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),

                        if (_loadingPreview)
                          const Center(child: CircularProgressIndicator()),

                        if (!_loadingPreview)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Will send to $_totalMessages members',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filter.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (_previewMembers.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text('First 5 recipients:'),
                                ..._previewMembers.map((m) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.person, size: 16),
                                      title: Text(m.name, style: const TextStyle(fontSize: 14)),
                                      subtitle: Text(m.phone ?? 'No phone', style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Send button / progress
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _sending
                ? Column(
                    children: [
                      LinearProgressIndicator(
                        value: _totalMessages > 0 ? _currentProgress / _totalMessages : 0,
                      ),
                      const SizedBox(height: 8),
                      Text('Sending $_currentProgress of $_totalMessages...'),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: Text('Send to $_totalMessages Members'),
                      onPressed: _messageController.text.trim().isEmpty || _totalMessages == 0
                          ? null
                          : _sendMessages,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
```

---

## UI Customization

### Step 13: Add Member Info Panel to Chat View

**File: `lib/layouts/conversation/widgets/crm_member_panel.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../../../models/crm/member.dart';
import '../../../services/crm/crm_message_service.dart';

/// Side panel showing CRM member info in chat view
class CRMMemberPanel extends StatefulWidget {
  final String phoneNumber; // E.164 format from Handle

  const CRMMemberPanel({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<CRMMemberPanel> createState() => _CRMMemberPanelState();
}

class _CRMMemberPanelState extends State<CRMMemberPanel> {
  final CRMMessageService _messageService = CRMMessageService();
  Member? _member;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    setState(() => _loading = true);
    
    try {
      final member = await _messageService.getMemberByPhone(widget.phoneNumber);
      setState(() {
        _member = member;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading member: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_member == null) {
      return const Center(
        child: Text('No CRM data for this contact'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Header
        Center(
          child: CircleAvatar(
            radius: 40,
            child: Text(_member!.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _member!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        
        if (_member!.optOut)
          Center(
            child: Chip(
              label: const Text('OPTED OUT'),
              backgroundColor: Colors.red,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),

        const Divider(height: 32),

        // Quick info
        if (_member!.county != null)
          _buildInfoTile(Icons.location_on, 'County', _member!.county!),
        
        if (_member!.congressionalDistrict != null)
          _buildInfoTile(Icons.account_balance, 'District', 'CD-${_member!.congressionalDistrict}'),
        
        if (_member!.committee != null && _member!.committee!.isNotEmpty)
          _buildInfoTile(Icons.group, 'Committees', _member!.committeesString),
        
        if (_member!.age != null)
          _buildInfoTile(Icons.cake, 'Age', '${_member!.age} years old'),

        if (_member!.lastContacted != null)
          _buildInfoTile(Icons.schedule, 'Last Contacted', 
            _formatDate(_member!.lastContacted!)),

        const Divider(height: 32),

        // Notes
        if (_member!.notes != null && _member!.notes!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(_member!.notes!),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value),
      dense: true,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
```

---

### Step 14: Integrate Member Panel into Chat View

**Find existing conversation view file** (typically something like `lib/layouts/conversation/conversation_view.dart`) and add:

```dart
// Add import
import 'widgets/crm_member_panel.dart';

// In the build method, add a side panel button/drawer:
IconButton(
  icon: const Icon(Icons.info_outline),
  onPressed: () {
    // Show member panel in a drawer or modal
    showModalBottomSheet(
      context: context,
      builder: (context) => CRMMemberPanel(
        phoneNumber: chat.participants.first.address, // Adjust based on your Chat model
      ),
    );
  },
  tooltip: 'Member Info',
),
```

---

## Testing Strategy

### Step 15: Testing Checklist

```
PHASE 1: Setup & Connection
[ ] Supabase service initializes successfully
[ ] Can fetch all members from Supabase
[ ] Member model correctly parses all fields
[ ] Filter options load (counties, districts, committees)

PHASE 2: Member Display
[ ] Members list screen shows all members
[ ] Search works correctly
[ ] Filters apply correctly (county, district, committee)
[ ] Member detail screen shows all information
[ ] Can view member notes

PHASE 3: Messaging Integration
[ ] Can find member by phone number (E.164)
[ ] Member panel displays in chat view
[ ] "Start Chat" button works from member detail
[ ] BlueBubbles creates/finds correct Handle and Chat

PHASE 4: Bulk Messaging
[ ] Filter preview shows correct member count
[ ] Preview members list is accurate
[ ] Bulk send creates individual messages
[ ] Rate limiting works (30/minute, 2sec delay)
[ ] Progress indicator updates correctly
[ ] Last contacted timestamp updates after send
[ ] Opted-out members are excluded

PHASE 5: Edge Cases
[ ] Handles members without phone numbers
[ ] Handles opted-out members correctly
[ ] Works with empty filter results
[ ] Handles Supabase connection errors gracefully
[ ] Works when CRM is disabled (feature flag)
```

---

## Deployment Checklist

### Step 16: Production Preparation

```
SECURITY
[ ] Move Supabase credentials to environment variables
[ ] Enable Row Level Security (RLS) on Supabase members table
[ ] Add authentication if needed
[ ] Review what member data is exposed in logs

PERFORMANCE
[ ] Add pagination to members list (if > 1000 members)
[ ] Add caching for filter options
[ ] Test with large member datasets
[ ] Optimize Supabase queries with proper indexes

MONITORING
[ ] Add error logging for Supabase operations
[ ] Track bulk message success/failure rates
[ ] Monitor API rate limits
[ ] Set up alerts for failed messages

DOCUMENTATION
[ ] Document Supabase table structure
[ ] Create user guide for CRM features
[ ] Document phone number format requirements (E.164)
[ ] Create troubleshooting guide

FEATURE FLAGS
[ ] Test with CRMConfig.crmEnabled = false
[ ] Test with CRMConfig.bulkMessagingEnabled = false
[ ] Ensure app works if Supabase is unavailable
```

---

## Critical Integration Notes

### BlueBubbles Messaging Integration

**THIS SECTION REQUIRES MANUAL IMPLEMENTATION** - you must integrate with the existing BlueBubbles message sending system. Look for:

1. **Find existing message service:**
   - Search for files like `message_service.dart` or `send_message.dart`
   - Find the function that sends messages (probably takes a phone number and text)

2. **Locate Handle/Chat creation:**
   - Find how BlueBubbles creates or finds a Handle for a phone number
   - Find how BlueBubbles creates or finds a Chat for a Handle

3. **Replace placeholder in `CRMMessageService._sendSingleMessage()`:**
   ```dart
   Future<bool> _sendSingleMessage({
     required String phoneNumber,
     required String message,
   }) async {
     // REPLACE THIS WITH ACTUAL BLUEBUBBLES CODE:
     
     // Step 1: Find or create Handle
     // final handle = await HandleService.findOrCreate(phoneNumber);
     
     // Step 2: Find or create Chat
     // final chat = await ChatService.findOrCreate(handle);
     
     // Step 3: Send message
     // final success = await MessageService.send(chat, message);
     
     // return success;
   }
   ```

### Phone Number Format

**CRITICAL:** All phone numbers must be in E.164 format in Supabase:
- Format: `+[country code][number]`
- Example: `+15551234567` (US number)
- NO spaces, dashes, parentheses

Make sure your Supabase `phone_e164` field matches BlueBubbles `Handle.address` format exactly.

---

## File Structure Summary

```
lib/
├── config/
│   └── crm_config.dart                    # NEW: Configuration
├── models/
│   └── crm/                               # NEW: CRM models
│       ├── member.dart
│       ├── message_filter.dart
│       └── campaign.dart
├── services/
│   └── crm/                               # NEW: CRM services
│       ├── supabase_service.dart
│       ├── member_repository.dart
│       └── crm_message_service.dart
├── screens/
│   └── crm/                               # NEW: CRM screens
│       ├── members_list_screen.dart
│       ├── member_detail_screen.dart
│       └── bulk_message_screen.dart
└── layouts/
    └── conversation/
        └── widgets/
            └── crm_member_panel.dart      # NEW: Chat integration widget
```

---

## Environment Variables

Create `.env` file (DO NOT COMMIT):
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Update `lib/config/crm_config.dart` to read from environment:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CRMConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  // ...
}
```

---

## Next Steps After Implementation

1. **Test locally first**
   - Use a small subset of test members
   - Verify all features work end-to-end

2. **Set up Row Level Security (RLS) on Supabase**
   - Protect member data appropriately
   - Configure authentication if needed

3. **Add analytics tracking**
   - Track message delivery success rates
   - Monitor member engagement
   - Log opt-out/opt-in events

4. **Create user documentation**
   - How to use bulk messaging
   - How to manage members
   - Best practices for political outreach

5. **Consider future enhancements**
   - Message templates
   - Campaign scheduling
   - Response tracking
   - Automated follow-ups

---

## Support & Troubleshooting

### Common Issues

**"CRMSupabaseService not initialized"**
- Ensure `CRMSupabaseService().initialize()` is called in `main()`
- Check Supabase URL and key are correct

**"No members found" when members exist**
- Check phone_e164 format matches E.164 standard
- Verify Supabase table permissions (RLS)
- Check network connectivity

**Messages not sending**
- Verify BlueBubbles integration in `_sendSingleMessage()`
- Check Handle.address format matches member.phoneE164
- Ensure BlueBubbles API is connected

**Member panel not showing in chat**
- Verify phone number lookup is working
- Check that member.phoneE164 matches Handle.address
- Ensure integration point is correct in conversation view

---

## Conclusion

This integration adds powerful CRM functionality to BlueBubbles without touching any existing infrastructure. All conversation data remains in ObjectBox, all messaging goes through existing BlueBubbles APIs, and the CRM layer operates as a pure addition.

The key to success is:
1. Never modifying ObjectBox models
2. Using phone_e164 as the integration point
3. Leveraging existing BlueBubbles message sending
4. Keeping CRM and messaging concerns separate

Good luck with your implementation! 🎉
