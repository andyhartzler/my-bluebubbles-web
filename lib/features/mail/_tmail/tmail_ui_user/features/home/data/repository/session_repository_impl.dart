import 'package:bluebubbles/features/mail/_tmail/core/data/model/source_type/data_source_type.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/home/data/datasource/session_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/home/domain/repository/session_repository.dart';

class SessionRepositoryImpl extends SessionRepository {

  final Map<DataSourceType, SessionDataSource> sessionDataSource;

  SessionRepositoryImpl(this.sessionDataSource);

  @override
  Future<Session> getSession() {
    return sessionDataSource[DataSourceType.network]!.getSession();
  }

  @override
  Future<void> storeSession(Session session) {
    return sessionDataSource[DataSourceType.hiveCache]!.storeSession(session);
  }

  @override
  Future<Session> getStoredSession() {
    return sessionDataSource[DataSourceType.hiveCache]!.getStoredSession();
  }
}