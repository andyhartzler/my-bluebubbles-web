import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

@freezed
class ChatSession with _$ChatSession {
  const factory ChatSession({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'user_id') required String userId,
    String? title,
    @JsonKey(name: 'is_archived') @Default(false) bool isArchived,
  }) = _ChatSession;

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}
