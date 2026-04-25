
import 'package:bluebubbles/features/mail/_tmail/core/presentation/constants/constants_ui.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/color_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/composer_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/view/mobile/editor_fullscreen_dialog_view.dart';

extension HandleContentHeightExceededExtension on ComposerController {

  void onEditorContentHeightChangedOnIOS(double height) {
    log('HandleContentHeightExceededExtension::onEditorContentHeightChangedOnIOS:height: $height');
    isContentHeightExceeded.value = height == ConstantsUI.composerHtmlContentMaxHeight;
  }

  Future<void> viewEntireContent() async {
    clearFocus();

    final currentContent = await getContentInEditor();
    log('HandleContentHeightExceededExtension::showComposerFullscreen:currentContent = $currentContent');
    Get.dialog(
      EditorFullscreenDialogView(
        content: currentContent,
        imagePaths: imagePaths,
        subject: subjectEmail.value,
      ),
      barrierColor: AppColor.colorDefaultCupertinoActionSheet,
    );
  }
}