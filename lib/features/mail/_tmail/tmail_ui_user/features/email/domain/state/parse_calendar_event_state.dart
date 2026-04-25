import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/model/blob_calendar_event.dart';

class ParseCalendarEventLoading extends LoadingState {}

class ParseCalendarEventSuccess extends UIState {

  final List<BlobCalendarEvent> blobCalendarEventList;

  ParseCalendarEventSuccess(this.blobCalendarEventList);

  @override
  List<Object> get props => [blobCalendarEventList];
}

class ParseCalendarEventFailure extends FeatureFailure {
  ParseCalendarEventFailure(dynamic exception) : super(exception: exception);
}