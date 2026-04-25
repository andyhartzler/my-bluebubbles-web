import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/iterable_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/model/popup_menu_item_action.dart';

extension PopupMenuActionListExtension on List<PopupMenuItemAction> {
  Map<int, List<PopupMenuItemAction>> groupByCategory() {
    return groupBy<int>((action) => action.category, sortKeys: true);
  }
}
