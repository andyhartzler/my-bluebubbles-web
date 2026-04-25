import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class EmptyFolderNameException extends AppBaseException {
  final String folderName;

  EmptyFolderNameException(this.folderName)
      : super('Folder name should not be empty: $folderName');

  @override
  String get exceptionName => 'EmptyFolderNameException';
}
