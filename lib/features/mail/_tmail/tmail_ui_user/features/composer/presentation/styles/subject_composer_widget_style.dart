
import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';

class SubjectComposerWidgetStyle {
  static const double space = 12;

  static const Color cursorColor = AppColor.primaryColor;
  static const Color borderColor = AppColor.colorLineComposer;

  static final TextStyle hintTextStyle = ThemeUtils.textStyleBodyBody1(
    color: AppColor.m3Tertiary,
  );
  static final TextStyle inputTextStyle = ThemeUtils.textStyleBodyBody1(
    color: Colors.black,
  );
}