
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/cleanup/domain/model/cleanup_rule.dart';

class RecentLoginUrlCleanupRule extends CleanupRule {
  final int storageLimit;

  RecentLoginUrlCleanupRule({this.storageLimit = 10}) : super();

  @override
  List<Object?> get props => [storageLimit];
}