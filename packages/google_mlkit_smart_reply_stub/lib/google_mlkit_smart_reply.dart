library google_mlkit_smart_reply;

class SmartReply {
  Future<void> addMessageToConversationFromLocalUser(String? text, int timestampMillis) async {}
  Future<void> addMessageToConversationFromRemoteUser(String? text, int timestampMillis, String userId) async {}
  Future<SmartReplySuggestionResult> suggestReplies() async => const SmartReplySuggestionResult([], SmartReplySuggestionResultStatus.success);
}

class SmartReplySuggestionResult {
  final List<SmartReplySuggestion> suggestions;
  final SmartReplySuggestionResultStatus status;

  const SmartReplySuggestionResult(this.suggestions, this.status);
}

class SmartReplySuggestion {
  final String text;
  const SmartReplySuggestion(this.text);
}

enum SmartReplySuggestionResultStatus { success, noReply, failed }
