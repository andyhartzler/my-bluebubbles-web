
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/upload/file_info.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/upload/domain/model/upload_attachment.dart';

class UploadAttachmentSuccess extends UIState {

  final UploadAttachment uploadAttachment;

  UploadAttachmentSuccess(this.uploadAttachment);

  @override
  List<Object?> get props => [uploadAttachment];
}

class UploadAttachmentFailure extends FeatureFailure {

  final FileInfo fileInfo;

  UploadAttachmentFailure(dynamic exception, this.fileInfo) : super(exception: exception);

  @override
  List<Object?> get props => [...super.props, fileInfo];
}