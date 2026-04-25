import 'package:core/presentation/resources/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe.dart';

class AiScribeMobileActionsItem extends StatelessWidget {
  final AiScribeContextMenuAction menuAction;
  final ImagePaths imagePaths;
  final ValueChanged<AiScribeCategoryContextMenuAction> onCategorySelected;
  final ValueChanged<AiScribeContextMenuAction> onActionSelected;

  const AiScribeMobileActionsItem({
    super.key,
    required this.menuAction,
    required this.imagePaths,
    required this.onCategorySelected,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    // When category
    if (menuAction.hasSubmenu) {
      return AiScribeMenuItem(
        menuAction: menuAction,
        imagePaths: imagePaths,
        onSelectAction: (selectedAction) {
          if (selectedAction is AiScribeCategoryContextMenuAction) {
            onCategorySelected.call(selectedAction);
          } else {
            onActionSelected.call(selectedAction);
          }
        }
      );
    }

    // When action alongside category
    final submenuActions = menuAction.submenuActions;
    if (submenuActions?.length == 1) {
      return AiScribeSubmenuItem(
        menuAction: submenuActions!.first,
        onSelectAction: onActionSelected,
      );
    }

    // When action inside category
    return AiScribeMenuItem(
      menuAction: menuAction,
      imagePaths: imagePaths,
      onSelectAction: onActionSelected,
    );
  }
}
