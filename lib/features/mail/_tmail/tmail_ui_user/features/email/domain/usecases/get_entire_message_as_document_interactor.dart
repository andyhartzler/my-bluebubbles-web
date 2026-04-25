import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/view_entire_message_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/repository/email_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/state/get_entire_message_as_document_state.dart';

class GetEntireMessageAsDocumentInteractor {
  final EmailRepository _emailRepository;

  GetEntireMessageAsDocumentInteractor(this._emailRepository);

  Stream<Either<Failure, Success>> execute(ViewEntireMessageRequest messageRequest) async* {
    try {
      yield Right(GettingEntireMessageAsDocument());
      final messageDocument = await _emailRepository.generateEntireMessageAsDocument(messageRequest);
      yield Right(GetEntireMessageAsDocumentSuccess(messageDocument));
    } catch (e) {
      yield Left(GetEntireMessageAsDocumentFailure(exception: e));
    }
  }
}