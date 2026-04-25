import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/upload/file_info.dart';

class LocalImagePickerLoading extends LoadingState {}

class LocalImagePickerSuccess extends UIState {
  final FileInfo fileInfo;

  LocalImagePickerSuccess(this.fileInfo);

  @override
  List<Object> get props => [fileInfo];
}

class LocalImagePickerFailure extends FeatureFailure {

  LocalImagePickerFailure(dynamic exception) : super(exception: exception);
}
