import 'package:bluebubbles/features/mail/_tmail/scribe/scribe/ai/domain/model/ai_message.dart';

class PromptData {
  final List<Prompt> prompts;

  PromptData({
    required this.prompts,
  });

factory PromptData.fromJson(Map<String, dynamic> json) {
    final promptsJson = json['prompts'] as List?;

    return PromptData(
      prompts: promptsJson
            ?.whereType<Map<String, dynamic>>()
            .map(Prompt.fromJson)
            .toList() ??
          const [],
    );
  }
}

class Prompt {
  static final _inputPlaceholder = RegExp(r'\{\{\s*input\s*\}\}');
  static final _taskPlaceholder = RegExp(r'\{\{\s*task\s*\}\}');

  final String name;
  final List<AIMessage> messages;

  Prompt({
    required this.name,
    required this.messages,
  });

  factory Prompt.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) {
      throw const FormatException('Prompt name must be a non-null String');
    }

    final messagesJson = json['messages'] as List?;

    return Prompt(
      name: name,
      messages: messagesJson
              ?.whereType<Map<String, dynamic>>()
              .map(AIMessage.fromJson)
              .toList() ??
          const [],
    );
  }

  List<AIMessage> buildPrompt(String inputText, {String? task}) {
    return [
      for (final message in messages)
        switch (message.role) {
          AIRole.system => AIMessage.ofSystem(message.content),
          AIRole.user => AIMessage.ofUser(
              _replacePlaceholders(message.content, inputText, task),
            ),
        }
    ];
  }

  String _replacePlaceholders(String content, String inputText, String? task) {
    var result = content.replaceAll(_inputPlaceholder, inputText);
    result = result.replaceAll(_taskPlaceholder, task ?? '');
    return result;
  }
}
