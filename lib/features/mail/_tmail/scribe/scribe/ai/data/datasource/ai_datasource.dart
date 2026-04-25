import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/model/ai_message.dart';
import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/model/ai_response.dart';

abstract class AIDataSource {
  Future<AIResponse> generateMessage(List<AIMessage> messages);
}
