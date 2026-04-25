import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe.dart';

class AiScribeCategoryContextMenuAction
    extends AiScribeContextMenuAction<AIScribeMenuCategory> {
  AiScribeCategoryContextMenuAction(
    super.action,
    this.localizations,
    this.imagePaths,
  );

  final ScribeLocalizations localizations;
  final ImagePaths imagePaths;

  @override
  String get actionName => action.getLabel(localizations);

  @override
  String? get actionIcon => action.getIcon(imagePaths);

  @override
  bool get hasSubmenu => action.hasSubmenu;

  @override
  List<AiScribeContextMenuAction>? get submenuActions => action.actions
      .map((action) => AiScribeActionContextMenuAction(
            action,
            localizations,
            imagePaths,
          ))
      .toList();
}
