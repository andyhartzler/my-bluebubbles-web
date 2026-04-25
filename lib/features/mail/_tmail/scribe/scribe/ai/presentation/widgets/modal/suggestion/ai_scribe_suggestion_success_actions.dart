import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/views/dialog/confirm_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe.dart';

class AiScribeSuggestionSuccessActions extends StatelessWidget {
  final ImagePaths imagePaths;
  final String suggestionText;
  final bool hasContent;
  final OnSelectAiScribeSuggestionAction onSelectAction;
  final OnLoadSuggestion onLoadSuggestion;

  const AiScribeSuggestionSuccessActions({
    super.key,
    required this.imagePaths,
    required this.suggestionText,
    required this.onSelectAction,
    required this.onLoadSuggestion,
    this.hasContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AiScribeImproveButton(
          imagePaths: imagePaths,
          suggestionText: suggestionText,
          onLoadSuggestion: onLoadSuggestion,
        ),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasContent) _buildReplaceButton(context),
              _buildInsertButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplaceButton(BuildContext context) {
    final localizations = ScribeLocalizations.of(context);
    return _buildActionButton(
      context: context,
      label: AiScribeSuggestionActions.replace.getLabel(localizations),
      textColor: AppColor.primaryMain,
      action: AiScribeSuggestionActions.replace,
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    Color? backgroundColor,
    required Color textColor,
    required AiScribeSuggestionActions action,
  }) {
    final isMobileScribe = AiScribeMobileUtils.isScribeInMobileMode(context);
    return Flexible(
      child: Container(
        constraints: BoxConstraints(
          minWidth: isMobileScribe
              ? AIScribeSizes.minButtonMobileWidth
              : AIScribeSizes.minButtonWidth,
        ),
        height: isMobileScribe
            ? AIScribeSizes.buttonMobileHeight
            : AIScribeSizes.buttonHeight,
        child: ConfirmDialogButton(
          label: label,
          backgroundColor: backgroundColor,
          textColor: textColor,
          onTapAction: () {
            Navigator.of(context).pop();
            onSelectAction(action, suggestionText);
          },
        ),
      ),
    );
  }

  Widget _buildInsertButton(BuildContext context) {
    final localizations = ScribeLocalizations.of(context);
    return _buildActionButton(
      context: context,
      label: AiScribeSuggestionActions.insert.getLabel(localizations),
      backgroundColor: AppColor.primaryMain,
      textColor: Colors.white,
      action: AiScribeSuggestionActions.insert,
    );
  }
}