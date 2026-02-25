# Donors Page Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the CRM donors page with a tabbed layout (matching the Slack page design), adding MEC campaign finance research and call time list management while preserving all existing fundraising functionality.

**Architecture:** Replace the current single-scroll `DonorsListScreen` with a `TabBar`-driven layout (3 tabs: Fundraising, MEC Research, Call Time). Each tab is its own widget. Two new Supabase repositories query the `mec_contributions`/`mec_committees` and `call_time_lists`/`call_time_list_items` tables. New models map the DB schema. The existing `DonorRepository` and all fundraising features are preserved unchanged inside the Fundraising tab.

**Tech Stack:** Flutter/Dart, Supabase (PostgREST), existing BrandColors theme system

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `lib/models/crm/mec_contribution.dart` | **Create** | Model for `public.mec_contributions` |
| `lib/models/crm/mec_committee.dart` | **Create** | Model for `public.mec_committees` |
| `lib/models/crm/call_time_list.dart` | **Create** | Models for `call_time_lists` + `call_time_list_items` |
| `lib/services/crm/mec_repository.dart` | **Create** | Supabase queries for MEC data |
| `lib/services/crm/call_time_repository.dart` | **Create** | Supabase queries for call time lists |
| `lib/screens/crm/donors_list_screen.dart` | **Modify** | Wrap existing content in TabBar layout |
| `lib/screens/crm/tabs/fundraising_tab.dart` | **Create** | Extract existing fundraising UI |
| `lib/screens/crm/tabs/mec_research_tab.dart` | **Create** | MEC contribution search & donor profiles |
| `lib/screens/crm/tabs/call_time_tab.dart` | **Create** | Call time list CRUD & tracking |

---

### Task 1: MEC Contribution Model

**Files:**
- Create: `lib/models/crm/mec_contribution.dart`

**Step 1: Create the model**

```dart
import 'package:intl/intl.dart';

class MecContribution {
  final int id;
  final String? mecId;
  final String? committeeName;
  final String? report;
  final String? contributorCommittee;
  final String? contributorCompany;
  final String? contributorLastName;
  final String? contributorFirstName;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? zip;
  final String? employer;
  final String? occupation;
  final DateTime? contributionDate;
  final double? contributionAmount;
  final String? monetaryOrInkind;
  final bool isCommitteeContributor;
  final String? reportType;
  final int? filingYear;

  const MecContribution({
    required this.id,
    this.mecId,
    this.committeeName,
    this.report,
    this.contributorCommittee,
    this.contributorCompany,
    this.contributorLastName,
    this.contributorFirstName,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.zip,
    this.employer,
    this.occupation,
    this.contributionDate,
    this.contributionAmount,
    this.monetaryOrInkind,
    this.isCommitteeContributor = false,
    this.reportType,
    this.filingYear,
  });

  factory MecContribution.fromJson(Map<String, dynamic> json) {
    return MecContribution(
      id: (json['id'] as num).toInt(),
      mecId: json['mec_id'] as String?,
      committeeName: json['committee_name'] as String?,
      report: json['report'] as String?,
      contributorCommittee: json['contributor_committee'] as String?,
      contributorCompany: json['contributor_company'] as String?,
      contributorLastName: json['contributor_last_name'] as String?,
      contributorFirstName: json['contributor_first_name'] as String?,
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      contributionDate: _parseDate(json['contribution_date']),
      contributionAmount: (json['contribution_amount'] as num?)?.toDouble(),
      monetaryOrInkind: json['monetary_or_inkind'] as String?,
      isCommitteeContributor: json['is_committee_contributor'] == true,
      reportType: json['report_type'] as String?,
      filingYear: (json['filing_year'] as num?)?.toInt(),
    );
  }

  String get contributorDisplayName {
    if (isCommitteeContributor && contributorCommittee != null) {
      return contributorCommittee!;
    }
    if (contributorCompany != null && contributorCompany!.isNotEmpty) {
      return contributorCompany!;
    }
    final parts = [contributorFirstName, contributorLastName]
        .where((s) => s != null && s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Unknown';
  }

  String get formattedDate {
    if (contributionDate == null) return '';
    return DateFormat.yMMMd().format(contributionDate!);
  }

  String get formattedAmount {
    if (contributionAmount == null) return '';
    return NumberFormat.simpleCurrency().format(contributionAmount);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/crm/mec_contribution.dart
git commit -m "feat: add MecContribution model for MEC campaign finance data"
```

---

### Task 2: MEC Committee Model

**Files:**
- Create: `lib/models/crm/mec_committee.dart`

**Step 1: Create the model**

```dart
class MecCommittee {
  final int id;
  final String? mecId;
  final String? committeeName;
  final String? committeeType;
  final String? committeeStatus;
  final DateTime? terminatedDate;
  final String? committeeAddress;
  final String? committeePhone;
  final String? candidateName;
  final String? candidateAddress;
  final String? candidatePhone;
  final String? partyAffiliation;
  final String? treasurerName;
  final String? treasurerAddress;
  final String? treasurerPhone;
  final List<dynamic>? electionHistory;

  const MecCommittee({
    required this.id,
    this.mecId,
    this.committeeName,
    this.committeeType,
    this.committeeStatus,
    this.terminatedDate,
    this.committeeAddress,
    this.committeePhone,
    this.candidateName,
    this.candidateAddress,
    this.candidatePhone,
    this.partyAffiliation,
    this.treasurerName,
    this.treasurerAddress,
    this.treasurerPhone,
    this.electionHistory,
  });

  factory MecCommittee.fromJson(Map<String, dynamic> json) {
    return MecCommittee(
      id: (json['id'] as num).toInt(),
      mecId: json['mec_id'] as String?,
      committeeName: json['committee_name'] as String?,
      committeeType: json['committee_type'] as String?,
      committeeStatus: json['committee_status'] as String?,
      terminatedDate: _parseDate(json['terminated_date']),
      committeeAddress: json['committee_address'] as String?,
      committeePhone: json['committee_phone'] as String?,
      candidateName: json['candidate_name'] as String?,
      candidateAddress: json['candidate_address'] as String?,
      candidatePhone: json['candidate_phone'] as String?,
      partyAffiliation: json['party_affiliation'] as String?,
      treasurerName: json['treasurer_name'] as String?,
      treasurerAddress: json['treasurer_address'] as String?,
      treasurerPhone: json['treasurer_phone'] as String?,
      electionHistory: json['election_history'] as List<dynamic>?,
    );
  }

  bool get isDemocrat =>
      partyAffiliation?.toLowerCase().contains('democrat') == true;
  bool get isRepublican =>
      partyAffiliation?.toLowerCase().contains('republican') == true;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/crm/mec_committee.dart
git commit -m "feat: add MecCommittee model"
```

---

### Task 3: Call Time List Models

**Files:**
- Create: `lib/models/crm/call_time_list.dart`

**Step 1: Create models for both tables**

```dart
class CallTimeList {
  final int id;
  final String name;
  final String? description;
  final String status; // 'active', 'completed', 'archived'
  final Map<String, dynamic>? filters;
  final String? createdBy;
  final int totalItems;
  final int totalCalled;
  final double totalPledged;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<CallTimeListItem> items;

  const CallTimeList({
    required this.id,
    required this.name,
    this.description,
    this.status = 'active',
    this.filters,
    this.createdBy,
    this.totalItems = 0,
    this.totalCalled = 0,
    this.totalPledged = 0,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory CallTimeList.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['call_time_list_items'] as List<dynamic>?;
    return CallTimeList(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      filters: json['filters'] as Map<String, dynamic>?,
      createdBy: json['created_by'] as String?,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalCalled: (json['total_called'] as num?)?.toInt() ?? 0,
      totalPledged: (json['total_pledged'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      items: itemsJson
              ?.whereType<Map<String, dynamic>>()
              .map(CallTimeListItem.fromJson)
              .toList() ??
          [],
    );
  }

  double get progressPercent =>
      totalItems == 0 ? 0 : totalCalled / totalItems;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class CallTimeListItem {
  final int id;
  final int listId;
  final int? donorId;
  final int priority;
  final double? suggestedAsk;
  final String callStatus; // 'pending', 'called', 'no_answer', 'left_message', 'pledged', 'declined', 'skipped'
  final String? callNotes;
  final double? pledgedAmount;
  final DateTime? calledAt;
  final String? calledBy;
  final DateTime? createdAt;
  // Joined MEC donor data
  final Map<String, dynamic>? mecDonor;

  const CallTimeListItem({
    required this.id,
    required this.listId,
    this.donorId,
    this.priority = 0,
    this.suggestedAsk,
    this.callStatus = 'pending',
    this.callNotes,
    this.pledgedAmount,
    this.calledAt,
    this.calledBy,
    this.createdAt,
    this.mecDonor,
  });

  factory CallTimeListItem.fromJson(Map<String, dynamic> json) {
    return CallTimeListItem(
      id: (json['id'] as num).toInt(),
      listId: (json['list_id'] as num).toInt(),
      donorId: (json['donor_id'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      suggestedAsk: (json['suggested_ask'] as num?)?.toDouble(),
      callStatus: json['call_status'] as String? ?? 'pending',
      callNotes: json['call_notes'] as String?,
      pledgedAmount: (json['pledged_amount'] as num?)?.toDouble(),
      calledAt: _parseDate(json['called_at']),
      calledBy: json['called_by'] as String?,
      createdAt: _parseDate(json['created_at']),
      mecDonor: json['mec_donors'] as Map<String, dynamic>?,
    );
  }

  String get displayName {
    if (mecDonor == null) return 'Donor #$donorId';
    final first = mecDonor!['first_name'] as String? ?? '';
    final last = mecDonor!['last_name'] as String? ?? '';
    final company = mecDonor!['company_name'] as String? ?? '';
    final committee = mecDonor!['committee_name'] as String? ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    if (company.isNotEmpty) return company;
    if (committee.isNotEmpty) return committee;
    return 'Donor #$donorId';
  }

  bool get isCalled => callStatus != 'pending' && callStatus != 'skipped';

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/crm/call_time_list.dart
git commit -m "feat: add CallTimeList and CallTimeListItem models"
```

---

### Task 4: MEC Repository

**Files:**
- Create: `lib/services/crm/mec_repository.dart`

**Step 1: Create the repository**

This repository queries `public.mec_contributions` and `public.mec_committees`. Key features:
- Search by contributor name (first/last), company, committee
- Filter by year range, amount range, committee MECID
- Get aggregated donor profile (total given, committees donated to, giving timeline)
- Fetch committee details

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/mec_contribution.dart';
import 'package:bluebubbles/models/crm/mec_committee.dart';

import 'supabase_service.dart';

class MecRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Search contributions by contributor name, company, or committee
  Future<List<MecContribution>> searchContributions({
    String? query,
    String? mecId,
    int? yearFrom,
    int? yearTo,
    double? minAmount,
    double? maxAmount,
    bool? committeeOnly,
    String sortBy = 'contribution_date',
    bool ascending = false,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    var q = _client.from('mec_contributions').select();

    if (query != null && query.trim().isNotEmpty) {
      final terms = query.trim().split(RegExp(r'\s+'));
      final conditions = <String>[];
      for (final term in terms) {
        conditions.add('contributor_last_name.ilike.%$term%');
        conditions.add('contributor_first_name.ilike.%$term%');
        conditions.add('contributor_company.ilike.%$term%');
        conditions.add('contributor_committee.ilike.%$term%');
        conditions.add('committee_name.ilike.%$term%');
      }
      q = q.or(conditions.join(','));
    }

    if (mecId != null) q = q.eq('mec_id', mecId);
    if (yearFrom != null) q = q.gte('filing_year', yearFrom);
    if (yearTo != null) q = q.lte('filing_year', yearTo);
    if (minAmount != null) q = q.gte('contribution_amount', minAmount);
    if (maxAmount != null) q = q.lte('contribution_amount', maxAmount);
    if (committeeOnly != null) q = q.eq('is_committee_contributor', committeeOnly);

    final data = await q
        .order(sortBy, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MecContribution.fromJson)
        .toList();
  }

  /// Get aggregate stats for a specific contributor name
  /// Returns: total amount, count, committees list, year range
  Future<Map<String, dynamic>> getContributorProfile({
    required String lastName,
    String? firstName,
    String? company,
  }) async {
    if (!isReady) return {};

    var q = _client.from('mec_contributions').select();

    if (company != null && company.isNotEmpty) {
      q = q.ilike('contributor_company', '%$company%');
    } else {
      q = q.ilike('contributor_last_name', lastName);
      if (firstName != null && firstName.isNotEmpty) {
        q = q.ilike('contributor_first_name', '$firstName%');
      }
    }

    final data = await q.order('contribution_date', ascending: false);
    final contributions = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MecContribution.fromJson)
        .toList();

    if (contributions.isEmpty) return {'contributions': <MecContribution>[]};

    final totalAmount = contributions.fold<double>(
        0, (sum, c) => sum + (c.contributionAmount ?? 0));
    final committees = <String, double>{};
    for (final c in contributions) {
      final name = c.committeeName ?? c.mecId ?? 'Unknown';
      committees[name] = (committees[name] ?? 0) + (c.contributionAmount ?? 0);
    }
    // Sort committees by total descending
    final sortedCommittees = committees.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'contributions': contributions,
      'totalAmount': totalAmount,
      'count': contributions.length,
      'committees': sortedCommittees,
      'firstYear': contributions.last.filingYear,
      'lastYear': contributions.first.filingYear,
    };
  }

  /// Fetch committee info by MECID
  Future<MecCommittee?> getCommittee(String mecId) async {
    if (!isReady) return null;
    final data = await _client
        .from('mec_committees')
        .select()
        .eq('mec_id', mecId)
        .maybeSingle();
    if (data == null) return null;
    return MecCommittee.fromJson(data as Map<String, dynamic>);
  }

  /// Get top contributors to a specific committee
  Future<List<Map<String, dynamic>>> getTopContributors({
    required String mecId,
    int limit = 25,
  }) async {
    if (!isReady) return [];

    // Use RPC or raw query to aggregate - for now, fetch and aggregate client-side
    final data = await _client
        .from('mec_contributions')
        .select()
        .eq('mec_id', mecId)
        .order('contribution_amount', ascending: false)
        .limit(500);

    final contributions = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MecContribution.fromJson)
        .toList();

    // Aggregate by contributor
    final Map<String, Map<String, dynamic>> byContributor = {};
    for (final c in contributions) {
      final key = c.contributorDisplayName.toLowerCase();
      final existing = byContributor[key];
      if (existing == null) {
        byContributor[key] = {
          'name': c.contributorDisplayName,
          'total': c.contributionAmount ?? 0,
          'count': 1,
          'city': c.city,
          'state': c.state,
          'employer': c.employer,
          'occupation': c.occupation,
          'lastDate': c.contributionDate,
        };
      } else {
        existing['total'] = (existing['total'] as double) + (c.contributionAmount ?? 0);
        existing['count'] = (existing['count'] as int) + 1;
      }
    }

    final sorted = byContributor.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return sorted.take(limit).toList();
  }

  /// Quick stats for dashboard
  Future<Map<String, dynamic>> getStats() async {
    if (!isReady) return {};
    // Get counts efficiently
    final data = await _client
        .from('mec_contributions')
        .select('id', const FetchOptions(count: CountOption.exact, head: true));
    return {
      'totalContributions': data.count ?? 0,
    };
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/crm/mec_repository.dart
git commit -m "feat: add MecRepository for querying MEC campaign finance data"
```

---

### Task 5: Call Time Repository

**Files:**
- Create: `lib/services/crm/call_time_repository.dart`

**Step 1: Create the repository**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/call_time_list.dart';

import 'supabase_service.dart';

class CallTimeRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Fetch all call time lists with summary counts
  Future<List<CallTimeList>> fetchLists({String? status}) async {
    if (!isReady) return [];

    var q = _client.from('call_time_lists').select();
    if (status != null) q = q.eq('status', status);
    final data = await q.order('created_at', ascending: false);

    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CallTimeList.fromJson)
        .toList();
  }

  /// Fetch a single list with all its items (joined with mec_donors)
  Future<CallTimeList?> fetchListWithItems(int listId) async {
    if (!isReady) return null;

    final data = await _client
        .from('call_time_lists')
        .select('*, call_time_list_items(*, mec_donors(*))')
        .eq('id', listId)
        .maybeSingle();

    if (data == null) return null;
    return CallTimeList.fromJson(data as Map<String, dynamic>);
  }

  /// Create a new call time list
  Future<CallTimeList?> createList({
    required String name,
    String? description,
    Map<String, dynamic>? filters,
    String? createdBy,
  }) async {
    if (!isReady) return null;

    final payload = {
      'name': name,
      'description': description,
      'status': 'active',
      'filters': filters,
      'created_by': createdBy,
      'total_items': 0,
      'total_called': 0,
      'total_pledged': 0,
    };

    final data = await _client
        .from('call_time_lists')
        .insert(payload)
        .select()
        .single();

    return CallTimeList.fromJson(data as Map<String, dynamic>);
  }

  /// Update list metadata
  Future<void> updateList(int listId, Map<String, dynamic> updates) async {
    if (!isReady) return;
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('call_time_lists').update(updates).eq('id', listId);
  }

  /// Delete a list and all its items (cascade)
  Future<void> deleteList(int listId) async {
    if (!isReady) return;
    // Items cascade-delete via FK
    await _client.from('call_time_lists').delete().eq('id', listId);
  }

  /// Add a donor to a call time list
  Future<CallTimeListItem?> addItem({
    required int listId,
    required int donorId,
    int priority = 0,
    double? suggestedAsk,
  }) async {
    if (!isReady) return null;

    final payload = {
      'list_id': listId,
      'donor_id': donorId,
      'priority': priority,
      'suggested_ask': suggestedAsk,
      'call_status': 'pending',
    };

    final data = await _client
        .from('call_time_list_items')
        .insert(payload)
        .select('*, mec_donors(*)')
        .single();

    // Update total_items count
    await _client.rpc('', params: {});
    // Simple approach: update count
    await _refreshListCounts(listId);

    return CallTimeListItem.fromJson(data as Map<String, dynamic>);
  }

  /// Batch-add multiple donors to a list
  Future<void> addItems({
    required int listId,
    required List<int> donorIds,
    double? suggestedAsk,
  }) async {
    if (!isReady) return;

    final payloads = donorIds.map((id) => {
      'list_id': listId,
      'donor_id': id,
      'priority': 0,
      'suggested_ask': suggestedAsk,
      'call_status': 'pending',
    }).toList();

    await _client.from('call_time_list_items').insert(payloads);
    await _refreshListCounts(listId);
  }

  /// Update a call time list item (log call result)
  Future<void> updateItem(int itemId, {
    String? callStatus,
    String? callNotes,
    double? pledgedAmount,
    String? calledBy,
  }) async {
    if (!isReady) return;

    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (callStatus != null) {
      payload['call_status'] = callStatus;
      payload['called_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (callNotes != null) payload['call_notes'] = callNotes;
    if (pledgedAmount != null) payload['pledged_amount'] = pledgedAmount;
    if (calledBy != null) payload['called_by'] = calledBy;

    await _client.from('call_time_list_items').update(payload).eq('id', itemId);
  }

  /// Remove an item from a list
  Future<void> removeItem(int itemId, int listId) async {
    if (!isReady) return;
    await _client.from('call_time_list_items').delete().eq('id', itemId);
    await _refreshListCounts(listId);
  }

  /// Refresh the summary counts on a list
  Future<void> _refreshListCounts(int listId) async {
    final items = await _client
        .from('call_time_list_items')
        .select('call_status, pledged_amount')
        .eq('list_id', listId);

    final list = items as List<dynamic>;
    final totalItems = list.length;
    final totalCalled = list.where((i) {
      final status = (i as Map<String, dynamic>)['call_status'] as String?;
      return status != null && status != 'pending' && status != 'skipped';
    }).length;
    final totalPledged = list.fold<double>(0, (sum, i) {
      return sum + ((i as Map<String, dynamic>)['pledged_amount'] as num? ?? 0).toDouble();
    });

    await _client.from('call_time_lists').update({
      'total_items': totalItems,
      'total_called': totalCalled,
      'total_pledged': totalPledged,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', listId);
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/crm/call_time_repository.dart
git commit -m "feat: add CallTimeRepository for call time list CRUD"
```

---

### Task 6: Extract Fundraising Tab

**Files:**
- Create: `lib/screens/crm/tabs/fundraising_tab.dart`
- Modify: `lib/screens/crm/donors_list_screen.dart`

**Step 1: Create the fundraising tab**

Extract the entire body of the current `DonorsListScreen` build method into `FundraisingTab`. This is a straight extraction — move all the stat cards, filters, donation list, add donation dialog, and export into their own widget. Keep every import, every helper method, every line of code.

The key change: `FundraisingTab` is a `StatefulWidget` that receives no special params (it creates its own repositories internally, same as the current screen).

Move these from `_DonorsListScreenState`:
- All state variables (`_donors`, `_visibleDonors`, `_recentDonations`, `_loading`, etc.)
- All methods (`_loadData`, `_applyFilters`, `_searchDonationSubjects`, `_showAddDonationDialog`, `_showExportDialog`, etc.)
- All build helpers (`_buildHeroCard`, `_buildFilters`, `_buildDonationList`, `_buildRowActions`, etc.)
- The `_DonationSearchResult` and `_DonationSearchResultType` classes

The `FundraisingTab.build()` returns what the current `_DonorsListScreenState.build()` returns (the `SelectionArea(child: ListView(...))` part), WITHOUT the scaffold wrapper.

**Step 2: Commit**

```bash
git add lib/screens/crm/tabs/fundraising_tab.dart
git commit -m "feat: extract FundraisingTab from DonorsListScreen"
```

---

### Task 7: MEC Research Tab

**Files:**
- Create: `lib/screens/crm/tabs/mec_research_tab.dart`

**Step 1: Create the MEC research tab**

This tab has two modes:
1. **Search mode** — search bar at top, results below as a data table
2. **Profile mode** — when a contributor is tapped, show their full giving profile

Design follows the BrandColors system: gradient cards, white text, gold accents.

Key UI elements:
- Search bar with filters (year range dropdown, min amount)
- Results shown in a scrollable data table (date, contributor, committee, amount, type)
- Tapping a row opens a contributor profile panel showing:
  - Total given across all committees
  - Breakdown by committee (sorted by total)
  - Timeline of all contributions
  - Employer/occupation info
  - City/state

The implementation should use `MecRepository` and display `MecContribution` data. Search should debounce 500ms.

**Step 2: Commit**

```bash
git add lib/screens/crm/tabs/mec_research_tab.dart
git commit -m "feat: add MEC Research tab with contribution search and donor profiles"
```

---

### Task 8: Call Time Tab

**Files:**
- Create: `lib/screens/crm/tabs/call_time_tab.dart`

**Step 1: Create the call time lists tab**

This tab has two views:
1. **Lists view** — shows all call time lists as branded cards with progress bars
2. **List detail view** — shows the items in a selected list with call tracking

Lists view shows:
- Each list as a BrandedCard with name, description, progress bar (called/total), total pledged
- FAB to create new list
- Status filter chips (active, completed, archived)

List detail view shows:
- Header with list name, stats
- Each item as a card showing donor name, suggested ask, employer, city
- Call status dropdown (pending, called, no_answer, left_message, pledged, declined, skipped)
- Notes field and pledged amount field
- Quick actions: call button (tel: link), skip button
- Back button to return to lists view

Creating a new list:
- Dialog with name, description
- Then ability to search MEC donors and add them to the list

Uses `CallTimeRepository` for all data operations.

**Step 2: Commit**

```bash
git add lib/screens/crm/tabs/call_time_tab.dart
git commit -m "feat: add Call Time tab with list management and call tracking"
```

---

### Task 9: Rewire DonorsListScreen with TabBar

**Files:**
- Modify: `lib/screens/crm/donors_list_screen.dart`

**Step 1: Rewrite the screen to use TabBar layout**

Replace the current 1537-line monolithic screen with a thin TabBar wrapper (matching `SlackManagementScreen` pattern). The screen becomes ~80 lines:

```dart
import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/tabs/fundraising_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/mec_research_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/call_time_tab.dart';

class DonorsListScreen extends StatefulWidget {
  final bool embed;

  const DonorsListScreen({super.key, this.embed = false});

  @override
  State<DonorsListScreen> createState() => _DonorsListScreenState();
}

class _DonorsListScreenState extends State<DonorsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.volunteer_activism), text: 'Fundraising'),
                Tab(icon: Icon(Icons.search), text: 'MEC Research'),
                Tab(icon: Icon(Icons.phone_callback), text: 'Call Time'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
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
            ),
          ),
        ),
        Expanded(
          child: BrandedBackground(
            child: TabBarView(
              controller: _tabController,
              children: const [
                FundraisingTab(),
                MecResearchTab(),
                CallTimeTab(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embed) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donors & Research',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
      ),
      body: content,
    );
  }
}
```

Note: The `_DonationSearchResult` and `_DonationSearchResultType` classes that were at the top of the old file need to move to `fundraising_tab.dart`.

**Step 2: Verify no import breakage**

Run: `cd /Users/andrew/my-bluebubbles-web && flutter analyze lib/screens/crm/donors_list_screen.dart`

**Step 3: Commit**

```bash
git add lib/screens/crm/donors_list_screen.dart
git commit -m "feat: rewire DonorsListScreen with TabBar layout (Fundraising, MEC Research, Call Time)"
```

---

### Task 10: Add FK from call_time_list_items to mec_donors

**Files:**
- Supabase migration

**Step 1: Apply migration**

The `call_time_list_items.donor_id` references `mec_donors.id`. We need a FK so PostgREST can do joins with `mec_donors(*)` syntax. Apply migration:

```sql
ALTER TABLE public.call_time_list_items
  ADD CONSTRAINT call_time_list_items_donor_fk
  FOREIGN KEY (donor_id) REFERENCES public.mec_donors(id);

NOTIFY pgrst, 'reload schema';
```

**Step 2: Commit migration**

This is a Supabase migration, not a code commit.

---

### Task 11: Build & Smoke Test

**Step 1: Run flutter analyze**

```bash
cd /Users/andrew/my-bluebubbles-web && flutter analyze
```

Fix any warnings or errors.

**Step 2: Run flutter build web**

```bash
cd /Users/andrew/my-bluebubbles-web && flutter build web
```

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve analyzer warnings from donors redesign"
```

---

## Execution Notes

- Tasks 1-5 (models + repos) are independent and can be parallelized
- Task 6 (extract fundraising tab) depends on having the current `donors_list_screen.dart` unchanged
- Tasks 7-8 (MEC tab + call time tab) depend on Tasks 4-5 (repos) but are independent of each other
- Task 9 (rewire) depends on Tasks 6-8
- Task 10 (FK migration) can run anytime
- Task 11 (build) depends on all previous tasks
