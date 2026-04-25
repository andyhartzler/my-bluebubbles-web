
import 'package:dio/dio.dart';
import 'package:bluebubbles/features/mail/_tmail/model/upload/file_info.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/upload/domain/model/upload_attachment.dart';

abstract class AttachmentUploadDataSource {
  Future<UploadAttachment> uploadAttachment(FileInfo fileInfo, Uri uploadUri, {CancelToken? cancelToken});
}