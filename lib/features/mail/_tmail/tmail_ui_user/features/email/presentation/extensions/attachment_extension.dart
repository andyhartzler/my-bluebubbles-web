import 'package:bluebubbles/features/mail/_tmail/core/data/constants/constant.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/extensions/media_type_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/model/file_category.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:bluebubbles/features/mail/_tmail/model/download/download_task_id.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/app_routes.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/route_utils.dart';

extension AttachmentExtension on Attachment {
  String getIcon(ImagePaths imagePaths) => type?.getIcon(imagePaths, fileName: name) ?? imagePaths.icFileDefault;

  bool get isPDFFile => type?.isPDFFile(fileName: name) ?? false;

  bool get isEMLFile => type?.isEMLFile ?? false;

  String get hyperLink => isEMLFile ? emlLink : attachmentLink;

  String get emlLink {
    if (blobId == null) return '';

    if (PlatformInfo.isWeb) {
      return RouteUtils.createUrlWebLocationBar(
        AppRoutes.emailEMLPreviewer,
        previewId: blobId!.value,
      ).toString();
    } else if (PlatformInfo.isMobile) {
      return '${Constant.emlPreviewerScheme}:${blobId!.value}';
    } else {
      return '';
    }
  }

  String get attachmentLink {
    if (blobId == null) return '';

    return '${Constant.attachmentScheme}:${blobId!.value}?name=${name ?? ''}&size=${size?.value ?? ''}&type=${type?.mimeType ?? ''}';
  }

  DownloadTaskId get downloadTaskId => DownloadTaskId(blobId!.value);

  bool get isHTMLFile => type?.isHTMLFile(fileName: name) ?? false;

  bool get isImage => type?.getFileCategory(fileName: name) == FileCategory.image;

  bool get isText => type?.getFileCategory(fileName: name) == FileCategory.text;

  bool get isJson => (type?.isJsonFile() ?? false)
    || name?.endsWith('.json') == true;

  bool get isPreviewSupported {
    return isImage || isText || isJson || isPDFFile || isEMLFile || isHTMLFile;
  }
}