
import 'package:bluebubbles/features/mail/_tmail/core/data/network/dio_client.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/file_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:bluebubbles/features/mail/_tmail/model/upload/file_info.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/isolate/background_isolate_binary_messenger/background_isolate_binary_messenger.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/upload/domain/model/upload_task_id.dart';

class UploadFileArguments with EquatableMixin {

  final DioClient dioClient;
  final FileUtils fileUtils;
  final UploadTaskId uploadId;
  final FileInfo fileInfo;
  final Uri uploadUri;
  final RootIsolateToken isolateToken;

  UploadFileArguments(
    this.dioClient,
    this.fileUtils,
    this.uploadId,
    this.fileInfo,
    this.uploadUri,
    this.isolateToken,
  );

  @override
  List<Object?> get props => [
    dioClient,
    fileUtils,
    uploadId,
    fileInfo,
    uploadUri,
    isolateToken,
  ];
}