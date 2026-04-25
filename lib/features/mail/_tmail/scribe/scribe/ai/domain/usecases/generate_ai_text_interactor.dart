import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/constants/ai_prompts.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/repository/ai_scribe_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/state/generate_ai_text_state.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/presentation/model/ai_action.dart';

class GenerateAITextInteractor {
  final AIScribeRepository _repository;

  GenerateAITextInteractor(this._repository);

  Future<Either<Failure, Success>> execute(
    AIAction action,
    String? selectedText,
  ) async {
    try {
      final prompt = await AIPrompts.buildPrompt(action, selectedText);
      final response = await _repository.generateMessage(prompt);
      return Right(GenerateAITextSuccess(response));
    } catch (e) {
      return Left(GenerateAITextFailure(e));
    }
  }
}
