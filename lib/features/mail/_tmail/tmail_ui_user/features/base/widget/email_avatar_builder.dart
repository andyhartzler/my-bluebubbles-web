
import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/image/avatar_builder.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/presentation_email_extension.dart';

class EmailAvatarBuilder extends StatelessWidget {

  final PresentationEmail emailSelected;
  final OnTapAvatarActionClick? onTapAvatarActionClick;
  final double? size;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const EmailAvatarBuilder({
    Key? key,
    required this.emailSelected,
    this.onTapAvatarActionClick,
    this.size,
    this.textStyle,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return (AvatarBuilder()
      ..text(emailSelected.getAvatarText())
      ..size(size ?? 50)
      ..addTextStyle(textStyle ?? ThemeUtils.textStyleHeadingH4(color: Colors.white))
      ..backgroundColor(AppColor.colorAvatar)
      ..addPadding(padding)
      ..addOnTapActionClick(onTapAvatarActionClick ?? () {})
      ..avatarColor(emailSelected.avatarColors))
    .build();
  }
}