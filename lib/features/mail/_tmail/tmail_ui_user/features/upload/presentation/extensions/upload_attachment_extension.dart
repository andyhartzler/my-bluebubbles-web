
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/upload/domain/model/upload_attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/upload/presentation/model/upload_file_state.dart';

extension UploadAttachmentExtension on UploadAttachment {

  UploadFileState toUploadFileState() {
    return UploadFileState(
      uploadTaskId,
      file: fileInfo,
      cancelToken: cancelToken,
    );
  }
}