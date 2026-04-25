import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:flutter/cupertino.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/extensions/label_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/model/label.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/model/popup_menu_item_action.dart';

class PopupMenuItemLabelTypeAction
    extends PopupMenuItemActionRequiredSelectedIcon<Label> {
  final ImagePaths imagePaths;

  PopupMenuItemLabelTypeAction(
    super.action,
    super.selectedAction,
    this.imagePaths,
  );

  bool get isSelected => action.id == selectedAction?.id;

  @override
  String get actionName => action.safeDisplayName;

  @override
  String get selectedIcon => isSelected
      ? imagePaths.icCheckboxSelected
      : imagePaths.icCheckboxUnselected;

  @override
  Color get selectedIconColor => isSelected
      ? AppColor.primaryMain
      : AppColor.gray424244.withOpacity(0.72);

  @override
  bool get isArrangeRTL => false;

  @override
  EdgeInsetsGeometry get itemPadding =>  const EdgeInsetsDirectional.only(
    end: 12,
  );
}
