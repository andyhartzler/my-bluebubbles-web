import 'package:bluebubbles/models/crm/meeting_agenda.dart';

/// One meeting to pair with an agenda: its title and its day in Missouri.
class AgendaMatchTarget {
  final String key;
  final String title;
  final DateTime centralDay;

  const AgendaMatchTarget({
    required this.key,
    required this.title,
    required this.centralDay,
  });
}

/// Pairs meetings with agendas held for the same Missouri day.
///
/// On a day with one meeting and one agenda they pair. When a day holds more
/// than one of either, an agenda pairs only with a meeting of the same kind
/// (Executive Committee with an executive agenda, all-member with
/// all-member), so a one-on-one recorded the same evening does not take the
/// board's agenda. Each agenda pairs at most once.
Map<String, MeetingAgenda> matchAgendas(
  List<AgendaMatchTarget> targets,
  List<MeetingAgenda> agendas,
) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  final agendasByDay = <DateTime, List<MeetingAgenda>>{};
  for (final agenda in agendas) {
    agendasByDay.putIfAbsent(day(agenda.meetingDate), () => []).add(agenda);
  }
  final targetsByDay = <DateTime, List<AgendaMatchTarget>>{};
  for (final target in targets) {
    targetsByDay.putIfAbsent(day(target.centralDay), () => []).add(target);
  }

  final result = <String, MeetingAgenda>{};
  targetsByDay.forEach((date, dayTargets) {
    final available = [...?agendasByDay[date]];
    if (available.isEmpty) return;

    if (dayTargets.length == 1 && available.length == 1) {
      result[dayTargets.single.key] = available.single;
      return;
    }

    for (final target in dayTargets) {
      final kind = MeetingAgendaKind.ofTitle(target.title);
      if (kind == MeetingAgendaKind.other) continue;
      final index = available.indexWhere((a) => a.kind == kind);
      if (index < 0) continue;
      result[target.key] = available.removeAt(index);
    }
  });
  return result;
}
