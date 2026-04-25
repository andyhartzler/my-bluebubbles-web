import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/config/app_config_parser.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/app_dashboard/linagora_applications.dart';

class AppDashboardConfigurationParser extends AppConfigParser<LinagoraApplications> {
  @override
  Future<LinagoraApplications> parse(String value) async {
    try {
      final jsonObject = jsonDecode(value);
      return LinagoraApplications.fromJson(jsonObject);
    } catch (e) {
      logWarning('AppDashboardConfigurationParser::parse(): $e');
      rethrow;
    }
  }

  @override
  Future<LinagoraApplications> parseData(ByteData data) {
    throw UnimplementedError();
  }
}