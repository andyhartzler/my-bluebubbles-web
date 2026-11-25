/// A meeting agenda kept as a Google Doc in Drive, as listed by the
/// `meeting-agendas` edge function.
///
/// [meetingDate] is the date written in the doc's title, which is the meeting
/// day in Missouri (America/Chicago). It carries no time and no zone.
class MeetingAgenda {
  final String fileId;
  final String title;
  final DateTime meetingDate;
  final MeetingAgendaKind kind;
  final Uri url;
  final DateTime? modifiedTime;

  const MeetingAgenda({
    required this.fileId,
    required this.title,
    required this.meetingDate,
    required this.kind,
    required this.url,
    this.modifiedTime,
  });

  factory MeetingAgenda.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['meeting_date'] as String);
    final modified = json['modified_time'] as String?;
    return MeetingAgenda(
      fileId: json['file_id'] as String,
      title: json['title'] as String,
      meetingDate: DateTime(date.year, date.month, date.day),
      kind: MeetingAgendaKind.fromString(json['kind'] as String?),
      url: Uri.parse(json['url'] as String),
      modifiedTime: modified == null ? null : DateTime.parse(modified).toLocal(),
    );
  }
}

enum MeetingAgendaKind {
  executive,
  allMember,
  other;

  static MeetingAgendaKind fromString(String? value) {
    switch (value) {
      case 'executive':
        return MeetingAgendaKind.executive;
      case 'all_member':
        return MeetingAgendaKind.allMember;
      default:
        return MeetingAgendaKind.other;
    }
  }

  /// The kind a meeting or calendar title describes, using the same rules the
  /// edge function applies to agenda titles.
  static MeetingAgendaKind ofTitle(String title) {
    if (RegExp('exec', caseSensitive: false).hasMatch(title)) {
      return MeetingAgendaKind.executive;
    }
    if (RegExp(r'all[\s_-]*members?', caseSensitive: false).hasMatch(title)) {
      return MeetingAgendaKind.allMember;
    }
    return MeetingAgendaKind.other;
  }
}
