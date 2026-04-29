import 'package:freezed_annotation/freezed_annotation.dart';
import 'source_document.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Feedback state for AI responses
enum FeedbackState { none, positive, negative }

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'session_id') required String sessionId,
    required String role,
    required String content,
    @JsonKey(name: 'source_documents') @Default([]) List<SourceDocument> sourceDocuments,
    @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(FeedbackState.none) FeedbackState feedbackState,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}

/// Temporary message for optimistic UI updates
class PendingMessage {
  final String id;
  final DateTime createdAt;
  final String role;
  final String content;
  final bool isPending;

  PendingMessage({
    required this.id,
    required this.createdAt,
    required this.role,
    required this.content,
    this.isPending = true,
  });

  ChatMessage toChatMessage(String sessionId) => ChatMessage(
    id: id,
    createdAt: createdAt,
    sessionId: sessionId,
    role: role,
    content: content,
  );
}
