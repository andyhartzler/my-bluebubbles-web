// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_api_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AIApiResponse _$AIApiResponseFromJson(Map<String, dynamic> json) =>
    AIApiResponse(
      choices: (json['choices'] as List<dynamic>)
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AIApiResponseToJson(AIApiResponse instance) =>
    <String, dynamic>{'choices': instance.choices};

Choice _$ChoiceFromJson(Map<String, dynamic> json) =>
    Choice(message: Message.fromJson(json['message'] as Map<String, dynamic>));

Map<String, dynamic> _$ChoiceToJson(Choice instance) => <String, dynamic>{
  'message': instance.message,
};

Message _$MessageFromJson(Map<String, dynamic> json) =>
    Message(content: json['content'] as String);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'content': instance.content,
};
