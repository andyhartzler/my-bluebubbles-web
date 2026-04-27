import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/styles/email_view_empty_styles.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

/// Empty-state shown in the right-hand reader pane when no email is
/// selected. Originally a single Inter-bold "no_mail_selected" string on
/// flat white — looked like a stock tmail demo. Reskinned with an MOYD
/// brand mark (navy circular badge + sunrise-gold envelope glyph) and a
/// short tagline so the surface reads as MOYD-owned.
class EmailViewEmptyWidget extends StatelessWidget {
  const EmailViewEmptyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brand mark: gold envelope glyph on navy disc.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.tileGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    offset: Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: BrandColors.sunriseGold,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).no_mail_selected,
              textAlign: TextAlign.center,
              style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                fontSize: EmailViewEmptyStyles.textSize,
                color: EmailViewEmptyStyles.textColor,
                fontWeight: EmailViewEmptyStyles.fontWeight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Missouri Young Democrats',
              textAlign: TextAlign.center,
              style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                fontSize: 13,
                color: BrandColors.unityBlue.withOpacity(0.65),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
