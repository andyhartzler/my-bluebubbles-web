import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

Member _execMember(
  String id,
  String name, {
  String? role,
  String? roleShort,
  String? executiveTitle,
  bool executive = true,
  bool hasPhoto = false,
}) {
  return Member(
    id: id,
    name: name,
    executiveCommittee: executive,
    executiveTitle: executiveTitle,
    executiveRole: role,
    executiveRoleShort: roleShort,
    profilePhotos:
        hasPhoto ? [MemberProfilePhoto(path: '$id.jpg', isPrimary: true)] : const [],
  );
}

Future<void> _pumpMemberListWith(
  WidgetTester tester,
  Member member,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: MembersListScreen(embed: true),
    ),
  );

  await tester.pump();

  final state = tester.state(find.byType(MembersListScreen)) as dynamic;

  state.setState(() {
    state._crmReady = true;
    state._loading = false;
    state._isLoadingPage = false;
    state._hasMoreMembers = false;
    state._members = <Member>[member];
    state._filteredMembers = <Member>[member];
    state._agedOutMembers = <Member>[];
    state._totalAvailableMembers = 1;
    state._activeView = 0;
  });

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    CRMSupabaseService().debugSetInitialized(false);
  });

  test('Executive comparator sorts members by new stakeholder hierarchy', () {
    final members = <Member>[
      _execMember('1', 'Paula President', role: 'President'),
      _execMember('2', 'Victor Vice', role: 'Executive Vice-President'),
      _execMember('3', 'Sally Secretary', roleShort: 'Secretary'),
      _execMember('4', 'Terry Treasurer', role: 'Treasurer'),
      _execMember('5', 'Chloe Chief', role: 'Chief of Staff'),
      _execMember('6', 'Yara YDA', role: 'Young Democrats of America Representative'),
      _execMember('7', 'Yuri YDA', roleShort: 'YDA Rep'),
      _execMember('8', 'Dana District 1', role: '1st District Representative'),
      _execMember('9', 'Derek District 2', role: 'Representative - 2nd Congressional District'),
      _execMember('10', 'Dina District 3', role: 'Third District Representative'),
      _execMember('11', 'Duke District 8', role: 'Eighth Congressional District Representative'),
      _execMember('12', 'Cathy College Chair', role: 'Chair, College Democrats'),
      _execMember('13', 'Connor College Co', role: 'Co-Chair, College Democrats'),
      _execMember('14', 'Hannah HS Chair', roleShort: 'High School Democrats Chair'),
      _execMember('15', 'Hugo HS Co', roleShort: 'High School Democrats CoChair'),
      _execMember('16', 'Camille Comms Chair', role: 'Chair - Communications Committee'),
      _execMember('17', 'Carl Comms Co', role: 'Co-Chair – Communications'),
      _execMember('18', 'Fiona Fundraising Chair', role: 'Chair, Fundraising Committee'),
      _execMember('19', 'Frank Fundraising Co', roleShort: 'Fundraising Co-Chair'),
      _execMember('20', 'Mira Membership Chair', role: 'Chair - Membership & Outreach'),
      _execMember('21', 'Mark Membership Co', role: 'Co-chair membership and outreach'),
      _execMember('22', 'Pia Policy Chair', role: 'Chair Policy & Advocacy'),
      _execMember('23', 'Paul Policy Co', roleShort: 'Co-Chair Policy and Advocacy'),
      _execMember('24', 'Polly Political Chair', roleShort: 'Chair Political Affairs'),
      _execMember('25', 'Pete Political Co', role: 'Co-Chair Political Affairs'),
      _execMember('26', 'Eddie Executive Director', role: 'Executive Director'),
    ];

    members.sort(
      MembersListScreen.compareMembersForTesting(prioritizeExecutives: true),
    );

    expect(
      members.map((member) => member.name).toList(),
      [
        'Paula President',
        'Victor Vice',
        'Sally Secretary',
        'Terry Treasurer',
        'Chloe Chief',
        'Yara YDA',
        'Yuri YDA',
        'Dana District 1',
        'Derek District 2',
        'Dina District 3',
        'Duke District 8',
        'Cathy College Chair',
        'Connor College Co',
        'Hannah HS Chair',
        'Hugo HS Co',
        'Camille Comms Chair',
        'Carl Comms Co',
        'Fiona Fundraising Chair',
        'Frank Fundraising Co',
        'Mira Membership Chair',
        'Mark Membership Co',
        'Pia Policy Chair',
        'Paul Policy Co',
        'Polly Political Chair',
        'Pete Political Co',
        'Eddie Executive Director',
      ],
    );
  });

  test('Executive comparator derives district ranking from long role labels', () {
    final members = <Member>[
      _execMember('1', 'Darla District 1', role: '1st Congressional District', roleShort: 'Representative'),
      _execMember('2', 'Derek District 2', role: '2nd Congressional District', roleShort: 'Representative'),
      _execMember('3', 'Dina District 3', role: 'Third Congressional District', roleShort: 'Representative'),
    ];

    members.sort(
      MembersListScreen.compareMembersForTesting(prioritizeExecutives: true),
    );

    expect(
      members.map((member) => member.name).toList(),
      ['Darla District 1', 'Derek District 2', 'Dina District 3'],
    );
  });

  test('Executive comparator respects hierarchy even when flag missing', () {
    final members = <Member>[
      _execMember('1', 'Tina Treasurer', role: 'Treasurer', executive: false),
      _execMember('2', 'Paula President', role: 'President', executive: false),
    ];

    members.sort(
      MembersListScreen.compareMembersForTesting(prioritizeExecutives: true),
    );

    expect(
      members.map((member) => member.name).toList(),
      ['Paula President', 'Tina Treasurer'],
    );
  });

  test('Executive comparator combines short and long committee labels', () {
    final members = <Member>[
      _execMember('1', 'Carla Communications', role: 'Communications Committee', roleShort: 'Chair'),
      _execMember('2', 'Colin Communications', role: 'Communications Committee', roleShort: 'Co-Chair'),
      _execMember('3', 'Polly Political', role: 'Political Affairs Committee', roleShort: 'Chair'),
    ];

    members.sort(
      MembersListScreen.compareMembersForTesting(prioritizeExecutives: true),
    );

    expect(
      members.map((member) => member.name).toList(),
      ['Carla Communications', 'Colin Communications', 'Polly Political'],
    );
  });

  test('Executive comparator prioritizes executive titles without role fields', () {
    final members = <Member>[
      _execMember('1', 'Daria District', role: 'District 3 Representative'),
      _execMember('2', 'Paula President', executiveTitle: 'President'),
      _execMember('3', 'Vince Vice', executiveTitle: 'Vice President'),
    ];

    members.sort(
      MembersListScreen.compareMembersForTesting(prioritizeExecutives: true),
    );

    expect(
      members.map((member) => member.name).toList(),
      ['Paula President', 'Vince Vice', 'Daria District'],
    );
  });

  testWidgets('Embedded layout shows disabled refresh control when CRM unavailable', (tester) async {
    final supabaseService = CRMSupabaseService();
    supabaseService.debugSetInitialized(false);

    await tester.pumpWidget(const MaterialApp(home: MembersListScreen(embed: true)));
    await tester.pump();

    final refreshButtonFinder = find.widgetWithIcon(IconButton, Icons.refresh);
    expect(refreshButtonFinder, findsOneWidget);

    final iconButton = tester.widget<IconButton>(refreshButtonFinder);
    expect(iconButton.onPressed, isNull);
    expect(iconButton.tooltip, 'Refresh');
  });

  testWidgets('MembersListScreen loads additional pages on demand', (tester) async {
    CRMSupabaseService().debugSetInitialized(true);

    final members = List<Member>.generate(
      12,
      (index) => _buildTestMember(
        index,
        chapterName: index.isEven ? 'Chapter A' : 'Chapter B',
        county: 'County ${(index % 3) + 1}',
        district: 'District ${(index % 2) + 1}',
        leadership: index % 4 == 0,
      ),
    );

    final chapters = [
      _buildTestChapter('chapter-a', 'Chapter A'),
      _buildTestChapter('chapter-b', 'Chapter B'),
    ];

    final memberRepository = _FakeMemberRepository(members);
    final chapterRepository = _FakeChapterRepository(chapters);

    await tester.pumpWidget(
      MaterialApp(
        home: MembersListScreen(
          embed: true,
          memberRepository: memberRepository,
          chapterRepository: chapterRepository,
          pageSize: 5,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(memberRepository.requestCount, greaterThanOrEqualTo(1));
    expect(find.text('Member 0'), findsOneWidget);
    expect(find.text('Member 5'), findsNothing);

    final state = tester.state(find.byType(MembersListScreen)) as dynamic;

    await state.fetchNextPageForTesting();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(memberRepository.requestCount, greaterThanOrEqualTo(2));
    expect(find.text('Member 5'), findsOneWidget);

    await state.fetchNextPageForTesting();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(memberRepository.requestCount, equals(3));
    expect(find.text('Member 10'), findsOneWidget);
  });
}

Member _buildTestMember(
  int index, {
  required String chapterName,
  required String county,
  required String district,
  bool leadership = false,
}) {
  final now = DateTime.now();
  final dateOfBirth = DateTime(now.year - (20 + index), now.month, 1);
  return Member(
    id: 'member-$index',
    name: 'Member $index',
    chapterName: chapterName,
    county: county,
    congressionalDistrict: district,
    chapterPosition: leadership ? 'Leader' : null,
    dateOfBirth: dateOfBirth,
    committee: leadership ? ['Leadership'] : null,
  );
}

Chapter _buildTestChapter(String id, String name) {
  return Chapter(
    id: id,
    chapterName: name,
    standardizedName: name.toLowerCase().replaceAll(' ', '-'),
    schoolName: '$name School',
    chapterType: 'Student',
    isChartered: true,
  );
}

class _FakeMemberRepository extends MemberRepository {
  _FakeMemberRepository(this.members);

  final List<Member> members;
  int requestCount = 0;

  @override
  Future<MemberFetchResult> getAllMembers({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    String? highSchool,
    String? college,
    String? chapterName,
    String? chapterStatus,
    int? minAge,
    int? maxAge,
    bool? optedOut,
    bool? registeredVoter,
    String? searchQuery,
    int? limit,
    int? offset,
    bool fetchTotalCount = false,
    List<String>? columns,
  }) async {
    final start = offset ?? 0;
    final effectiveLimit = limit ?? members.length;
    final end = (start + effectiveLimit).clamp(0, members.length).toInt();
    final slice = members.sublist(start, end);
    requestCount++;
    return MemberFetchResult(
      members: slice,
      totalCount: fetchTotalCount ? members.length : null,
    );
  }

  List<String> _uniqueStrings(Iterable<String?> values) {
    final entries = <String>{};
    for (final value in values) {
      final cleaned = value?.trim();
      if (cleaned == null || cleaned.isEmpty) continue;
      entries.add(cleaned);
    }
    final list = entries.toList()..sort();
    return list;
  }

  @override
  Future<List<String>> getUniqueCounties() async => _uniqueStrings(members.map((m) => m.county));

  @override
  Future<List<String>> getUniqueCongressionalDistricts() async =>
      _uniqueStrings(members.map((m) => m.congressionalDistrict));

  @override
  Future<List<String>> getUniqueCommittees() async {
    final set = <String>{};
    for (final member in members) {
      final committees = member.committee;
      if (committees == null) continue;
      for (final value in committees) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        set.add(trimmed);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Future<Map<String, int>> getChapterCounts() async =>
      _countOccurrences(members.map((member) => member.chapterName));

  @override
  Future<Map<String, int>> getLeadershipCountsByChapter() async => _countOccurrences(
        members
            .where((member) => member.chapterPosition != null && member.chapterPosition!.trim().isNotEmpty)
            .map((member) => member.chapterName),
      );

  @override
  Future<AgeBounds> getAgeBounds() async {
    final ages = members.map((member) => member.age).whereType<int>().toList()..sort();
    if (ages.isEmpty) {
      return const AgeBounds();
    }
    return AgeBounds(min: ages.first, max: ages.last);
  }

  Map<String, int> _countOccurrences(Iterable<String?> values) {
    final counts = <String, int>{};
    for (final value in values) {
      final cleaned = value?.trim();
      if (cleaned == null || cleaned.isEmpty) continue;
      counts[cleaned] = (counts[cleaned] ?? 0) + 1;
    }
    return counts;
  }
}

class _FakeChapterRepository extends ChapterRepository {
  _FakeChapterRepository(this.chapters);

  final List<Chapter> chapters;

  @override
  Future<List<Chapter>> getAllChapters() async => chapters;
}
