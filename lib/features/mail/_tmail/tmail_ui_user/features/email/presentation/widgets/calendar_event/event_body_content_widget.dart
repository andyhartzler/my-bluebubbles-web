import 'package:bluebubbles/features/mail/_tmail/core/presentation/constants/constants_ui.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/theme_utils.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/html_viewer/html_content_viewer_on_web_widget.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/html_viewer/html_content_viewer_widget.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/tooltip/iframe_tooltip_overlay.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/styles/event_description_detail_widget_styles.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/utils/app_utils.dart';

class EventBodyContentWidget extends StatelessWidget {

  final String content;
  final OnMailtoDelegateAction? onMailtoDelegateAction;
  final ScrollController? scrollController;
  final bool isInsideThreadDetailView;
  final OnIFrameClickAction? onIFrameClickAction;

  const EventBodyContentWidget({
    super.key,
    required this.content,
    this.onMailtoDelegateAction,
    this.scrollController,
    this.isInsideThreadDetailView = false,
    this.onIFrameClickAction,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = Get.find<ImagePaths>();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColor.colorEventDescriptionBackground,
        borderRadius: BorderRadius.all(Radius.circular(EventDescriptionDetailWidgetStyles.borderRadius)),
      ),
      width: double.infinity,
      padding: const EdgeInsetsDirectional.only(
        top: EventDescriptionDetailWidgetStyles.contentPadding,
        bottom: EventDescriptionDetailWidgetStyles.contentPadding,
        start: EventDescriptionDetailWidgetStyles.contentPadding,
        end: EventDescriptionDetailWidgetStyles.quotedPadding
      ),
      child: Stack(
        children: [
          if (PlatformInfo.isWeb)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: EventDescriptionDetailWidgetStyles.webContentPadding),
              child: LayoutBuilder(builder: (context, constraints) {
                return HtmlContentViewerOnWeb(
                  widthContent: constraints.maxWidth,
                  contentHtml: content,
                  useDefaultFontStyle: true,
                  useLinkTooltipOverlay: true,
                  mailtoDelegate: onMailtoDelegateAction,
                  direction: AppUtils.getCurrentDirection(context),
                  scrollController: scrollController,
                  onIFrameClickAction: onIFrameClickAction,
                  iframeTooltipOptions: IframeTooltipOptions(
                    tooltipTextStyle: ThemeUtils.textStyleInter400.copyWith(
                      color: Colors.white,
                    ),
                  ),
                );
              })
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              return HtmlContentViewer(
                contentHtml: content,
                initialWidth: constraints.maxWidth,
                maxHtmlContentHeight: PlatformInfo.isIOS
                  ? ConstantsUI.htmlContentMaxHeight
                  : null,
                useDefaultFontStyle: true,
                direction: AppUtils.getCurrentDirection(context),
                onMailtoDelegateAction: onMailtoDelegateAction
              );
            }),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: SvgPicture.asset(imagePath.icFormatQuote)
          )
        ],
      ),
    );
  }
}