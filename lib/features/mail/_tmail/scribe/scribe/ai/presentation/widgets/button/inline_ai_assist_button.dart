import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/button/tmail_button_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe.dart';

class InlineAiAssistButton extends StatelessWidget {
  final ImagePaths imagePaths;
  final String? selectedText;
  final OnSelectAiScribeSuggestionAction onSelectAiScribeSuggestionAction;
  final AsyncCallback? onTapFallback;

  const InlineAiAssistButton({
    super.key,
    required this.imagePaths,
    required this.onSelectAiScribeSuggestionAction,
    this.selectedText,
    this.onTapFallback,
  });

  @override
  Widget build(BuildContext context) {
    final isScribeMobile = AiScribeMobileUtils.isScribeInMobileMode(context);
    final iconSize = isScribeMobile
        ? AIScribeSizes.scribeMobileIcon
        : AIScribeSizes.scribeIcon;

    return TMailButtonWidget.fromIcon(
      icon: imagePaths.icSparkle,
      padding: AIScribeSizes.scribeButtonPadding,
      backgroundColor: AIScribeColors.background,
      iconSize: iconSize,
      iconColor: AIScribeColors.scribeIcon,
      borderRadius: AIScribeSizes.scribeButtonRadius,
      boxShadow: AIScribeShadows.sparkleIcon,
      onTapActionCallback: () => _onTapActionCallback(context, isScribeMobile),
    );
  }

  Future<void> _onTapActionCallback(
    BuildContext context,
    bool isScribeMobile,
  ) async {
    final renderBox = context.findRenderObject();

    Offset? position;
    Size? size;

    if (renderBox != null && renderBox is RenderBox) {
      position = renderBox.localToGlobal(Offset.zero);
      size = renderBox.size;
    }

    await onTapFallback?.call();

    await AiScribeModalManager.showAIScribeModal(
      isScribeMobile: isScribeMobile,
      imagePaths: imagePaths,
      availableCategories: AIScribeMenuCategory.values,
      buttonPosition: position,
      content: selectedText,
      buttonSize: size,
      onSelectAiScribeSuggestionAction: onSelectAiScribeSuggestionAction,
    );
  }
}
