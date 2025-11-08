import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Member _execMember(
  String id,
  String name, {
  String? role,
  String? roleShort,
}) {
  return Member(
    id: id,
    name: name,
    executiveCommittee: true,
    executiveRole: role,
    executiveRoleShort: roleShort,
  );
}

void main() {
  test('Executive comparator sorts members by stakeholder hierarchy', () {
    final members = <Member>[
      _execMember('8', 'Zara Co-Political', role: 'Co-Chair, Political Affairs'),
      _execMember('1', 'Anna President', role: 'President'),
      _execMember('2', 'Elliot EVP', role: 'Executive Vice-President'),
      _execMember('3', 'Eddie Executive Director', role: 'Executive Director'),
      _execMember('4', 'Yara Rep 1', role: 'Young Democrats of America Representative'),
      _execMember('5', 'Yves Rep 2', roleShort: 'Young Democrats of America Representative'),
      _execMember('6', 'Clara Chair Comms', roleShort: 'Chair - Communications'),
      _execMember('7', 'Calvin Co-Chair Comms', roleShort: 'Co-Chair – Communications'),
      _execMember('9', 'Polly Chair Political', roleShort: 'Chair Political Affairs'),
    ];

    members.sort(MembersListScreen.compareMembersForTesting);

    expect(
      members.map((member) => member.name).toList(),
      [
        'Anna President',
        'Elliot EVP',
        'Eddie Executive Director',
        'Yara Rep 1',
        'Yves Rep 2',
        'Clara Chair Comms',
        'Calvin Co-Chair Comms',
        'Polly Chair Political',
        'Zara Co-Political',
      ],
    );
  });
}
