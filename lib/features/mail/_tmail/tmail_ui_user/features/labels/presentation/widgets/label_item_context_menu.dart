import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/extensions/label_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/model/label.dart';

typedef OnSelectLabelAction = void Function(Label label, bool isSelected);

class LabelItemContextMenu extends StatelessWidget {
  final Label label;
  final ImagePaths imagePaths;
  final bool isSelected;
  final OnSelectLabelAction onSelectLabelAction;

  const LabelItemContextMenu({
    super.key,
    required this.label,
    required this.imagePaths,
    required this.isSelected,
    required this.onSelectLabelAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onSelectLabelAction(label, !isSelected),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              SvgPicture.asset(
                isSelected
                    ? imagePaths.icCheckboxSelected
                    : imagePaths.icCheckboxUnselected,
                width: 20,
                height: 20,
                colorFilter: isSelected
                    ? AppColor.primaryMain.asFilter()
                    : AppColor.steelGrayA540.asFilter(),
                fit: BoxFit.fill,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label.safeDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThemeUtils.textStyleBodyBody3(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
