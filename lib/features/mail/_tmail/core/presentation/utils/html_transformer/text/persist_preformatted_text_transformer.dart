import 'dart:convert';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/html_transformer/base/text_transformer.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/html/html_template.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/string_convert.dart';

class PersistPreformattedTextTransformer extends TextTransformer {
  const PersistPreformattedTextTransformer();

  @override
  String process(String text, HtmlEscape htmlEscape) {
    if (StringConvert.isTextTable(text)) {
      return '<div style="${HtmlTemplate.markDownAndASCIIArtStyleCSS}">$text</div>';
    } else {
      return text;
    }
  }
}