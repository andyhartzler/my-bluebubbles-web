import 'package:bluebubbles/models/crm/meeting_agenda.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Reads meeting agendas from Google Drive through the `meeting-agendas` edge
/// function. Drive stays the only copy: nothing here is stored in Postgres.
class MeetingAgendaRepository {
  MeetingAgendaRepository._();

  static final MeetingAgendaRepository _instance = MeetingAgendaRepository._();

  factory MeetingAgendaRepository() => _instance;

  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// Agenda text by Drive file id, for the life of the app session. Agendas
  /// change rarely once a meeting is over, and Refresh on the page clears it.
  final Map<String, String> _textCache = {};

  Future<List<MeetingAgenda>> listAgendas() async {
    _textCache.clear();
    final data = await _invoke({'action': 'list'});
    final rows = data['agendas'];
    if (rows is! List) {
      throw const MeetingAgendaException('The agenda list came back in an unexpected shape.');
    }
    return rows
        .whereType<Map>()
        .map((row) => MeetingAgenda.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<String> agendaText(String fileId) async {
    final cached = _textCache[fileId];
    if (cached != null) return cached;
    final data = await _invoke({'action': 'content', 'file_id': fileId});
    final text = data['text'];
    if (text is! String) {
      throw const MeetingAgendaException('The agenda came back in an unexpected shape.');
    }
    _textCache[fileId] = text;
    return text;
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (!_supabase.isInitialized) {
      throw const MeetingAgendaException('CRM Supabase is not configured.');
    }
    final response = await _supabase.client.functions.invoke('meeting-agendas', body: body);
    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final error = data is Map ? data['error']?.toString() : null;
      throw MeetingAgendaException(error ?? 'Agendas could not be loaded (HTTP ${response.status}).');
    }
    return Map<String, dynamic>.from(data);
  }
}

class MeetingAgendaException implements Exception {
  final String message;
  const MeetingAgendaException(this.message);

  @override
  String toString() => message;
}
