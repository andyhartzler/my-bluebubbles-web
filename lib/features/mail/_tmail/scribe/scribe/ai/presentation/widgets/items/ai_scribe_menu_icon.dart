import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AiScribeMenuIcon extends StatelessWidget {
  final String iconPath;

  const AiScribeMenuIcon({super.key, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: SvgPicture.asset(
        iconPath,
        width: 20,
        height: 20,
        fit: BoxFit.fill,
        colorFilter:
            AppColor.gray424244.withOpacity(0.72).asFilter(),
      ),
    );
  }
}