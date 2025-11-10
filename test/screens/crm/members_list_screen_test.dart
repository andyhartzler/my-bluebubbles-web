import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    state._filteredMembers = <Member>[member];
    state._agedOutMembers = <Member>[];
    state._activeView = 0;
  });

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
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
}
