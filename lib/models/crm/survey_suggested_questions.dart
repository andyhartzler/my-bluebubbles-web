/// Static library of suggested survey questions, grouped by category.
///
/// Used by the Survey Builder to let admins quickly pick from pre-written
/// questions and by the Event Detail screen to pre-populate post-event surveys.

// ─── SuggestedQuestion ──────────────────────────────────────────────────────

class SuggestedQuestion {
  /// The question text (e.g. "How would you rate the overall event experience?")
  final String text;

  /// One of: yes_no, rating, multiple_choice, short_answer
  /// Matches the `questionType` values in [SurveyQuestion].
  final String type;

  /// Pre-defined answer options (only relevant for multiple_choice).
  final List<String> options;

  /// Grouping category (e.g. 'Post-Event Feedback', 'Satisfaction').
  final String category;

  const SuggestedQuestion({
    required this.text,
    required this.type,
    this.options = const [],
    required this.category,
  });
}

// ─── SurveyQuestionSuggestions ──────────────────────────────────────────────

class SurveyQuestionSuggestions {
  SurveyQuestionSuggestions._();

  /// All available suggestion categories.
  static const List<String> categories = [
    'Post-Event Feedback',
    'Satisfaction',
    'Program Evaluation',
    'Demographics',
    'General Feedback',
    'Engagement',
  ];

  /// Complete library of suggested questions.
  static const List<SuggestedQuestion> all = [
    // ── Post-Event Feedback ───────────────────────────────────────────────
    SuggestedQuestion(
      text: 'How would you rate the overall event experience?',
      type: 'rating',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'Would you attend a similar event in the future?',
      type: 'yes_no',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'What was your favorite part of the event?',
      type: 'short_answer',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'How did you hear about this event?',
      type: 'multiple_choice',
      options: ['Social media', 'Email', 'Word of mouth', 'Website', 'Other'],
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'How would you rate the venue/location?',
      type: 'rating',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'What could we improve for next time?',
      type: 'short_answer',
      category: 'Post-Event Feedback',
    ),

    // ── Satisfaction ──────────────────────────────────────────────────────
    SuggestedQuestion(
      text: 'How satisfied are you with our organization overall?',
      type: 'rating',
      category: 'Satisfaction',
    ),
    SuggestedQuestion(
      text: 'How likely are you to recommend us to a friend or colleague?',
      type: 'rating',
      category: 'Satisfaction',
    ),
    SuggestedQuestion(
      text: 'How would you rate the quality of communication you receive from us?',
      type: 'rating',
      category: 'Satisfaction',
    ),
    SuggestedQuestion(
      text: 'Do you feel valued as a member of our community?',
      type: 'yes_no',
      category: 'Satisfaction',
    ),

    // ── Program Evaluation ────────────────────────────────────────────────
    SuggestedQuestion(
      text: 'How would you rate the content/programming quality?',
      type: 'rating',
      category: 'Program Evaluation',
    ),
    SuggestedQuestion(
      text: 'Did you learn something new from this program?',
      type: 'yes_no',
      category: 'Program Evaluation',
    ),
    SuggestedQuestion(
      text: 'Which topics would you like to see covered in the future?',
      type: 'short_answer',
      category: 'Program Evaluation',
    ),
    SuggestedQuestion(
      text: 'How would you rate the speakers/presenters?',
      type: 'rating',
      category: 'Program Evaluation',
    ),

    // ── Demographics ──────────────────────────────────────────────────────
    SuggestedQuestion(
      text: 'What is your age range?',
      type: 'multiple_choice',
      options: ['Under 18', '18-24', '25-34', '35-44', '45-54', '55-64', '65+'],
      category: 'Demographics',
    ),
    SuggestedQuestion(
      text: 'How often do you attend our events?',
      type: 'multiple_choice',
      options: ['This was my first time', 'A few times a year', 'Monthly', 'Weekly'],
      category: 'Demographics',
    ),
    SuggestedQuestion(
      text: 'Which of the following best describes you?',
      type: 'multiple_choice',
      options: ['Member', 'Non-member', 'Volunteer', 'Sponsor/Partner', 'Other'],
      category: 'Demographics',
    ),

    // ── General Feedback ──────────────────────────────────────────────────
    SuggestedQuestion(
      text: 'Is there anything else you would like to share with us?',
      type: 'short_answer',
      category: 'General Feedback',
    ),
    SuggestedQuestion(
      text: 'Would you be interested in volunteering with us?',
      type: 'yes_no',
      category: 'General Feedback',
    ),
    SuggestedQuestion(
      text: 'What other programs or services would you like us to offer?',
      type: 'short_answer',
      category: 'General Feedback',
    ),

    // ── Engagement ────────────────────────────────────────────────────────
    SuggestedQuestion(
      text: 'Have you visited our website in the past month?',
      type: 'yes_no',
      category: 'Engagement',
    ),
    SuggestedQuestion(
      text: 'How often do you engage with our social media content?',
      type: 'multiple_choice',
      options: ['Daily', 'A few times a week', 'Occasionally', 'Rarely', 'Never'],
      category: 'Engagement',
    ),
    SuggestedQuestion(
      text: 'On a scale of 1-5, how connected do you feel to our community?',
      type: 'rating',
      category: 'Engagement',
    ),
    SuggestedQuestion(
      text: 'Will you participate in our next event?',
      type: 'yes_no',
      category: 'Engagement',
    ),
  ];

  /// Questions in the 'Post-Event Feedback' category -- a sensible default
  /// set when creating a post-event survey.
  static List<SuggestedQuestion> get defaultPostEventQuestions =>
      all.where((q) => q.category == 'Post-Event Feedback').toList();

  /// Return all suggested questions that belong to [category].
  static List<SuggestedQuestion> byCategory(String category) =>
      all.where((q) => q.category == category).toList();

  // ── Intelligent type suggestion ─────────────────────────────────────────

  /// Pattern-matching RegExps compiled once and reused.
  static final RegExp _ratingPattern = RegExp(
    r'how would you rate|how likely|how satisfied|on a scale',
    caseSensitive: false,
  );

  static final RegExp _yesNoPattern = RegExp(
    r'^(do you|did you|are you|would you|will you|have you)\b',
    caseSensitive: false,
  );

  static final RegExp _multipleChoicePattern = RegExp(
    r'which of|what is your age|how often|how did you hear',
    caseSensitive: false,
  );

  /// Suggest the most appropriate question type for arbitrary [questionText].
  ///
  /// Returns one of `'rating'`, `'yes_no'`, `'multiple_choice'`, or
  /// `'short_answer'` (the default).
  static String suggestType(String questionText) {
    final text = questionText.trim();
    if (_ratingPattern.hasMatch(text)) return 'rating';
    if (_yesNoPattern.hasMatch(text)) return 'yes_no';
    if (_multipleChoicePattern.hasMatch(text)) return 'multiple_choice';
    return 'short_answer';
  }
}
