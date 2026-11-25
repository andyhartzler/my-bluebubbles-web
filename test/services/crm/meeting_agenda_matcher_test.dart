import 'package:flutter_test/flutter_test.dart';

import 'package:bluebubbles/models/crm/meeting_agenda.dart';
import 'package:bluebubbles/services/crm/meeting_agenda_matcher.dart';

MeetingAgenda _agenda(String id, String title, DateTime date) => MeetingAgenda(
      fileId: id,
      title: title,
      meetingDate: date,
      kind: MeetingAgendaKind.ofTitle(title),
      url: Uri.parse('https://docs.google.com/document/d/$id/edit'),
    );

void main() {
  final day = DateTime(2026, 9, 1);

  test('pairs the only meeting and the only agenda on a day', () {
    final result = matchAgendas(
      [AgendaMatchTarget(key: 'm1', title: 'Zoom meeting', centralDay: day)],
      [_agenda('a1', 'Executive Committee Agenda 09/01/26', day)],
    );
    expect(result['m1']?.fileId, 'a1');
  });

  test('on a busy day an agenda only pairs with a meeting of its kind', () {
    final result = matchAgendas(
      [
        AgendaMatchTarget(key: 'one-on-one', title: 'Check-in', centralDay: day),
        AgendaMatchTarget(key: 'exec', title: 'Executive Committee Meeting', centralDay: day),
      ],
      [_agenda('a1', 'Executive Committee Agenda 09/01/26', day)],
    );
    expect(result.keys, ['exec']);
  });

  test('each agenda pairs once, and other days are left alone', () {
    final result = matchAgendas(
      [
        AgendaMatchTarget(key: 'exec-a', title: 'Executive Committee', centralDay: day),
        AgendaMatchTarget(key: 'exec-b', title: 'Exec follow-up', centralDay: day),
        AgendaMatchTarget(key: 'later', title: 'Executive Committee', centralDay: DateTime(2026, 9, 15)),
      ],
      [_agenda('a1', 'Executive Committee Agenda 09/01/26', day)],
    );
    expect(result.length, 1);
    expect(result['exec-a']?.fileId, 'a1');
  });
}
