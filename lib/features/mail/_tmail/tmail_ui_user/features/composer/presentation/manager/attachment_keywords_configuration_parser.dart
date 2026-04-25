import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/config/app_config_parser.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/model/attachment_keyword_config.dart';

class AttachmentKeywordsConfigurationParser
    extends AppConfigParser<AttachmentKeywordConfig> {
  @override
  Future<AttachmentKeywordConfig> parse(String value) async {
    try {
      final jsonObject = jsonDecode(value);
      return AttachmentKeywordConfig.fromJson(jsonObject);
    } catch (e) {
      logWarning('AttachmentKeywordsConfigurationParser::parse(): $e');
      rethrow;
    }
  }

  @override
  Future<AttachmentKeywordConfig> parseData(ByteData data) {
    throw UnimplementedError();
  }
}
