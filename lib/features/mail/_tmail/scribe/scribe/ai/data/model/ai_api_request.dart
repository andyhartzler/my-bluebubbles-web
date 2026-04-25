import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/model/ai_message.dart';

class AIAPIRequest {
  final List<AIMessage> messages;

  const AIAPIRequest({
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
