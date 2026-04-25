
import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/style_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/avatar/gradient_circle_avatar_icon.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/direction_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/email_address_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/utils/app_utils.dart';

typedef DeleteContactCallbackAction = Function(EmailAddress contactDeleted);

class ContactInputTagItem extends StatelessWidget {

  final EmailAddress contact;
  final bool isTagFocused;
  final DeleteContactCallbackAction? deleteContactCallbackAction;

  const ContactInputTagItem(
    this.contact,
    {
      Key? key,
      this.isTagFocused = false,
      this.deleteContactCallbackAction
    }
  ) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imagePaths = Get.find<ImagePaths>();

    final itemChild = Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: contact.displayName.isNotEmpty
        ? GradientCircleAvatarIcon(
            colors: contact.avatarColors,
            iconSize: 20,
            labelFontSize: 11,
            label: contact.labelAvatar)
        : null,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: DirectionUtils.isDirectionRTLByHasAnyRtl(contact.asString())
        ? EdgeInsets.zero
        : const EdgeInsets.all(6),
      label: Text(
        contact.asString(),
        maxLines: 1,
        softWrap: CommonTextStyle.defaultSoftWrap,
        overflow: CommonTextStyle.defaultTextOverFlow,
        style: ThemeUtils.defaultTextStyleInterFont.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black,
        ),
      ),
      deleteIcon: deleteContactCallbackAction != null
        ? SvgPicture.asset(
            imagePaths.icClose,
            width: 20,
            height: 20,
            colorFilter: AppColor.colorDeleteContactIcon.asFilter(),
            fit: BoxFit.fill)
        : null,
      labelStyle: ThemeUtils.defaultTextStyleInterFont.copyWith(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      backgroundColor: _getTagBackgroundColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: _getTagBorderSide()
      ),
      onDeleted: () => deleteContactCallbackAction?.call(contact),
    );

    if (PlatformInfo.isWeb) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: itemChild
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: itemChild
      );
    }
  }

  bool _isValidEmailAddress(String value) => value.isEmail || AppUtils.isEmailLocalhost(value);

  Color _getTagBackgroundColor() {
    if (isTagFocused) {
      return AppColor.colorItemRecipientSelected;
    } else {
      return _isValidEmailAddress(contact.emailAddress)
        ? AppColor.colorBackgroundContactTagItem
        : Colors.white;
    }
  }

  BorderSide _getTagBorderSide() {
    if (isTagFocused) {
      return const BorderSide(
      width: 1,
      color: AppColor.primaryColor);
    } else {
      return BorderSide(
        width: _isValidEmailAddress(contact.emailAddress) ? 0 : 1,
        color: _isValidEmailAddress(contact.emailAddress)
          ? AppColor.colorBackgroundContactTagItem
          : AppColor.colorBorderEmailAddressInvalid
      );
    }
  }
}