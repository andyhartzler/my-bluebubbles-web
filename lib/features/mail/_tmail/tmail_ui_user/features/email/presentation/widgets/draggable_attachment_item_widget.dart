
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/widgets/attachment_item_widget.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/widgets/feedback_draggable_attachment_item_widget.dart';

typedef OnDragAttachmentStarted = Function();
typedef OnDragAttachmentEnd = Function(DraggableDetails details);

class DraggableAttachmentItemWidget extends StatelessWidget{

  final Attachment attachment;
  final ImagePaths imagePaths;
  final double? width;
  final OnDragAttachmentStarted? onDragStarted;
  final OnDragAttachmentEnd? onDragEnd;
  final OnDownloadAttachmentFileAction? downloadAttachmentAction;
  final OnViewAttachmentFileAction? viewAttachmentAction;
  final String? singleEmailControllerTag;

  const DraggableAttachmentItemWidget({
    Key? key,
    required this.attachment,
    required this.imagePaths,
    this.width,
    this.onDragStarted,
    this.onDragEnd,
    this.downloadAttachmentAction,
    this.viewAttachmentAction,
    this.singleEmailControllerTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Draggable(
      data: attachment,
      feedback: FeedbackDraggableAttachmentItemWidget(attachment: attachment),
      onDragStarted: onDragStarted,
      onDragEnd: onDragEnd,
      child: AttachmentItemWidget(
        attachment: attachment,
        imagePaths: imagePaths,
        width: width,
        downloadAttachmentAction: downloadAttachmentAction,
        viewAttachmentAction: viewAttachmentAction,
        singleEmailControllerTag: singleEmailControllerTag,
      ),
    );
  }
}