/// Simple singleton to hold pending share content between navigation
/// Used when navigating from vote detail to email/message tabs
class PendingShareContent {
  static final PendingShareContent _instance = PendingShareContent._internal();
  factory PendingShareContent() => _instance;
  PendingShareContent._internal();

  /// Pending email content
  String? pendingEmailSubject;
  String? pendingEmailBody;
  String? pendingEmailBodyPlainText;

  /// Pending message content
  String? pendingMessageBody;

  /// Check if there's pending email content
  bool get hasPendingEmail => pendingEmailSubject != null || pendingEmailBodyPlainText != null;

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
    // Also store plain text for Quill editor initialization
    pendingEmailBodyPlainText = '''You are invited to participate in a vote:

$voteTitle
${voteDescription != null && voteDescription.isNotEmpty ? '\n$voteDescription' : ''}
Cast your vote here: $voteUrl''';
  }

  /// Set pending email content for a Zoom meeting invite
  void setMeetingEmailContent({
    required String meetingTitle,
    required String meetingDate,
    required String meetingTime,
    required String meetingDuration,
    required String zoomJoinUrl,
    String? zoomPassword,
    String? description,
  }) {
    pendingEmailSubject = 'Meeting Invitation: $meetingTitle';

    final passwordLine = zoomPassword != null
        ? '<p><strong>Password:</strong> $zoomPassword</p>'
        : '';
    final passwordLinePlain = zoomPassword != null
        ? 'Password: $zoomPassword\n'
        : '';
    final descriptionLine = description != null && description.isNotEmpty
        ? '<p>$description</p>'
        : '';
    final descriptionLinePlain = description != null && description.isNotEmpty
        ? '\n$description\n'
        : '';

    pendingEmailBody = '''
<p>You are invited to a Zoom meeting:</p>
<p><strong>$meetingTitle</strong></p>
$descriptionLine
<p><strong>Date:</strong> $meetingDate</p>
<p><strong>Time:</strong> $meetingTime ($meetingDuration)</p>
<p><strong>Join Zoom Meeting:</strong> <a href="$zoomJoinUrl">$zoomJoinUrl</a></p>
$passwordLine
<p>We look forward to seeing you there!</p>
''';

    pendingEmailBodyPlainText = '''You are invited to a Zoom meeting:

$meetingTitle
$descriptionLinePlain
Date: $meetingDate
Time: $meetingTime ($meetingDuration)

Join Zoom Meeting: $zoomJoinUrl
$passwordLinePlain
We look forward to seeing you there!''';
  }

  /// Set pending message content for a vote share
  void setVoteMessageContent({
    required String voteTitle,
    required String voteUrl,
  }) {
    pendingMessageBody = 'Vote: $voteTitle\n\nCast your vote here: $voteUrl';
  }

  /// Set pending message content for a Zoom meeting invite
  void setMeetingMessageContent({
    required String meetingTitle,
    required String meetingDate,
    required String meetingTime,
    required String zoomJoinUrl,
    String? zoomPassword,
  }) {
    final passwordLine = zoomPassword != null ? '\nPassword: $zoomPassword' : '';
    pendingMessageBody = '''$meetingTitle

📅 $meetingDate at $meetingTime

Join Zoom: $zoomJoinUrl$passwordLine''';
  }

  /// Clear pending email content after consuming
  void clearPendingEmail() {
    pendingEmailSubject = null;
    pendingEmailBody = null;
    pendingEmailBodyPlainText = null;
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
