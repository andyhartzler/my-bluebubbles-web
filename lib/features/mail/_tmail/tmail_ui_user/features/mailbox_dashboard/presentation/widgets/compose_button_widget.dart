
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/responsive_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/button/tmail_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

class ComposeButtonWidget extends StatelessWidget {

  final ImagePaths imagePaths;
  final VoidCallback onTapAction;

  const ComposeButtonWidget({
    super.key,
    required this.imagePaths,
    required this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 16,
        bottom: 8,
      ),
      width: ResponsiveUtils.defaultSizeMenu,
      alignment: Alignment.centerLeft,
      child: TMailButtonWidget(
        key: const Key('compose_email_button'),
        text: AppLocalizations.of(context).compose,
        icon: imagePaths.icComposeWeb,
        borderRadius: 10,
        iconSize: 24,
        height: 44,
        // White-on-gold fails 4.5:1; use navy for both icon and label so
        // the compose button stays readable against sunriseGold.
        iconColor: BrandColors.unityBlue,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        // MOYD brand: compose is the primary call-to-action on the
        // mailbox -- map to sunriseGold so it pops against the navy nav
        // chrome instead of reading as a second "blue button" next to the
        // (also-navy) selected mailbox highlight. Was AppColor.blue700.
        backgroundColor: BrandColors.sunriseGold,
        textStyle: ThemeUtils.textStyleBodyBody2(color: BrandColors.unityBlue),
        onTapActionCallback: onTapAction,
      ),
    );
  }
}
