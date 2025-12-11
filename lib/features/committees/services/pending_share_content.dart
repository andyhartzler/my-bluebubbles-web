/// Simple singleton to hold pending share content between navigation
/// Used when navigating from vote detail to email/message tabs
class PendingShareContent {
  static final PendingShareContent _instance = PendingShareContent._internal();
  factory PendingShareContent() => _instance;
  PendingShareContent._internal();

  /// Pending email content
  String? pendingEmailSubject;
  String? pendingEmailBody;

  /// Pending message content
  String? pendingMessageBody;

  /// Check if there's pending email content
  bool get hasPendingEmail => pendingEmailSubject != null || pendingEmailBody != null;

  /// Check if there's pending message content
  bool get hasPendingMessage => pendingMessageBody != null;

  /// Set pending email content for a vote share
  void setVoteEmailContent({
    required String voteTitle,
    required String voteUrl,
    String? voteDescription,
  }) {
    pendingEmailSubject = 'Vote: $voteTitle';
    pendingEmailBody = '''
<p>You are invited to participate in a vote:</p>
<p><strong>$voteTitle</strong></p>
${voteDescription != null && voteDescription.isNotEmpty ? '<p>$voteDescription</p>' : ''}
<p>Cast your vote here: <a href="$voteUrl">$voteUrl</a></p>
''';
  }

  /// Set pending message content for a vote share
  void setVoteMessageContent({
    required String voteTitle,
    required String voteUrl,
  }) {
    pendingMessageBody = 'Vote: $voteTitle\n\nCast your vote here: $voteUrl';
  }

  /// Clear pending email content after consuming
  void clearPendingEmail() {
    pendingEmailSubject = null;
    pendingEmailBody = null;
  }

  /// Clear pending message content after consuming
  void clearPendingMessage() {
    pendingMessageBody = null;
  }

  /// Clear all pending content
  void clearAll() {
    clearPendingEmail();
    clearPendingMessage();
  }
}
