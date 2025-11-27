import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Segment types for recipient selection
enum SegmentType {
  allSubscribers,
  allMembers,
  allDonors,
  eventAttendees,
  everyone,
}

/// Premium Campaign Wizard Provider
/// Handles all state management for the multi-step campaign creation wizard
/// Features: Auto-save drafts, recipient estimation, deliverability scoring
class CampaignWizardProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // === DRAFT STATE ===
  String? _draftId;
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSavedAt;

  // === STEP 1: Campaign Details ===
  String _campaignName = '';
  String _subjectLine = '';
  String _previewText = '';
  String _fromEmail = 'info@moyoungdemocrats.org';

  // === STEP 2: Email Content ===
  String? _htmlContent;
  Map<String, dynamic>? _designJson;

  // === STEP 3: Recipient Selection ===
  SegmentType? _selectedSegmentType;
  List<String> _selectedCongressionalDistricts = [];
  List<String> _selectedCounties = [];
  List<String> _selectedEventIds = [];
  int _estimatedRecipients = 0;
  bool _loadingEstimate = false;

  // === STEP 4: Schedule & Send ===
  DateTime? _scheduledFor;
  bool _sendImmediately = true;
  bool _enableABTesting = false;
  String? _variantBSubject;

  // === DELIVERABILITY SCORE ===
  int? _deliverabilityScore;
  int? _spamScore;
  List<String> _deliverabilityIssues = [];
  bool _calculatingScore = false;

  // === AI SUGGESTIONS ===
  List<String> _subjectLineSuggestions = [];
  bool _loadingSuggestions = false;

  // === GETTERS ===

  // Draft & Auto-save
  String? get draftId => _draftId;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  DateTime? get lastSavedAt => _lastSavedAt;

  // Step 1
  String get campaignName => _campaignName;
  String get subjectLine => _subjectLine;
  String get previewText => _previewText;
  String get fromEmail => _fromEmail;

  // Step 2
  String? get htmlContent => _htmlContent;
  Map<String, dynamic>? get designJson => _designJson;
  bool get hasEmailContent => _htmlContent != null && _htmlContent!.isNotEmpty;

  // Step 3
  SegmentType? get selectedSegmentType => _selectedSegmentType;
  List<String> get selectedCongressionalDistricts => _selectedCongressionalDistricts;
  List<String> get selectedCounties => _selectedCounties;
  List<String> get selectedEventIds => _selectedEventIds;
  int get estimatedRecipients => _estimatedRecipients;
  bool get loadingEstimate => _loadingEstimate;
  bool get hasRecipients => _estimatedRecipients > 0;

  // Step 4
  DateTime? get scheduledFor => _scheduledFor;
  bool get sendImmediately => _sendImmediately;
  bool get enableABTesting => _enableABTesting;
  String? get variantBSubject => _variantBSubject;

  // Deliverability
  int? get deliverabilityScore => _deliverabilityScore;
  int? get spamScore => _spamScore;
  List<String> get deliverabilityIssues => _deliverabilityIssues;
  bool get calculatingScore => _calculatingScore;

  // AI Suggestions
  List<String> get subjectLineSuggestions => _subjectLineSuggestions;
  bool get loadingSuggestions => _loadingSuggestions;

  // === VALIDATION ===

  bool get canProceedFromStep1 =>
      _campaignName.isNotEmpty && _subjectLine.isNotEmpty;

  bool get canProceedFromStep2 => hasEmailContent;

  bool get canProceedFromStep3 => hasRecipients;

  bool get canCreateCampaign =>
      canProceedFromStep1 && canProceedFromStep2 && canProceedFromStep3;

  // === METHODS ===

  CampaignWizardProvider() {
    _initializeAutoSave();
  }

  /// Initialize auto-save timer (saves every 30 seconds)
  void _initializeAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasUnsavedChanges) {
        _saveDraft();
      }
    });
  }

  // === STEP 1: CAMPAIGN DETAILS ===

  void updateCampaignName(String value) {
    _campaignName = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateSubjectLine(String value) {
    _subjectLine = value;
    _hasUnsavedChanges = true;
    notifyListeners();

    // Clear suggestions when user types
    if (_subjectLineSuggestions.isNotEmpty) {
      _subjectLineSuggestions.clear();
    }
  }

  void updatePreviewText(String value) {
    _previewText = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateFromEmail(String value) {
    _fromEmail = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  /// Generate AI-powered subject line suggestions
  Future<void> generateSubjectLineSuggestions() async {
    if (_loadingSuggestions) return;

    _loadingSuggestions = true;
    notifyListeners();

    try {
      // Call AI service (placeholder - integrate with your AI service)
      // For now, providing smart templates based on campaign context
      _subjectLineSuggestions = _generateSmartSuggestions();

      _loadingSuggestions = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error generating suggestions: $e');
      _loadingSuggestions = false;
      notifyListeners();
    }
  }

  List<String> _generateSmartSuggestions() {
    final baseName = _campaignName.isNotEmpty ? _campaignName : 'Update';

    return [
      '🔵 $baseName - Important News from MOYD',
      'You\'re Invited: $baseName',
      'Breaking: $baseName',
      'Don\'t Miss: $baseName',
      '📣 ${baseName.toUpperCase()}: Take Action Now',
      'Join Us for $baseName',
      'Your Voice Matters: $baseName',
      'MOYD Update: $baseName',
    ];
  }

  void selectSubjectSuggestion(String suggestion) {
    _subjectLine = suggestion;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  // === STEP 2: EMAIL CONTENT ===

  void updateEmailContent({
    required String htmlContent,
    required Map<String, dynamic> designJson,
  }) {
    _htmlContent = htmlContent;
    _designJson = designJson;
    _hasUnsavedChanges = true;
    notifyListeners();

    // Calculate deliverability score when content changes
    calculateDeliverabilityScore();
  }

  void clearEmailContent() {
    _htmlContent = null;
    _designJson = null;
    _deliverabilityScore = null;
    _spamScore = null;
    _deliverabilityIssues.clear();
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  // === STEP 3: RECIPIENT SELECTION ===

  Future<void> selectSegmentType(SegmentType type) async {
    _selectedSegmentType = type;
    _selectedCongressionalDistricts.clear();
    _selectedCounties.clear();
    _selectedEventIds.clear();
    _hasUnsavedChanges = true;
    notifyListeners();

    // Automatically estimate recipients
    await estimateRecipients();
  }

  void toggleCongressionalDistrict(String district) {
    if (_selectedCongressionalDistricts.contains(district)) {
      _selectedCongressionalDistricts.remove(district);
    } else {
      _selectedCongressionalDistricts.add(district);
    }
    _hasUnsavedChanges = true;
    notifyListeners();

    // Re-estimate with new filters
    estimateRecipients();
  }

  void toggleCounty(String county) {
    if (_selectedCounties.contains(county)) {
      _selectedCounties.remove(county);
    } else {
      _selectedCounties.add(county);
    }
    _hasUnsavedChanges = true;
    notifyListeners();

    // Re-estimate with new filters
    estimateRecipients();
  }

  void toggleEvent(String eventId) {
    if (_selectedEventIds.contains(eventId)) {
      _selectedEventIds.remove(eventId);
    } else {
      _selectedEventIds.add(eventId);
    }
    _hasUnsavedChanges = true;
    notifyListeners();

    // Re-estimate with new filters
    estimateRecipients();
  }

  void clearAllFilters() {
    _selectedCongressionalDistricts.clear();
    _selectedCounties.clear();
    _hasUnsavedChanges = true;
    notifyListeners();

    estimateRecipients();
  }

  /// Estimate recipient count using database functions
  Future<void> estimateRecipients() async {
    if (_selectedSegmentType == null) {
      _estimatedRecipients = 0;
      notifyListeners();
      return;
    }

    _loadingEstimate = true;
    notifyListeners();

    try {
      int count = 0;

      final districts = _selectedCongressionalDistricts.isEmpty
          ? null
          : _selectedCongressionalDistricts;
      final counties = _selectedCounties.isEmpty ? null : _selectedCounties;

      switch (_selectedSegmentType!) {
        case SegmentType.allSubscribers:
          count = await _supabase.rpc('count_subscribers_filtered', params: {
            'p_congressional_districts': districts,
            'p_counties': counties,
          });
          break;

        case SegmentType.allMembers:
          count = await _supabase.rpc('count_members_filtered', params: {
            'p_congressional_districts': districts,
            'p_counties': counties,
          });
          break;

        case SegmentType.allDonors:
          count = await _supabase.rpc('count_donors_filtered', params: {
            'p_congressional_districts': districts,
            'p_counties': counties,
          });
          break;

        case SegmentType.eventAttendees:
          if (_selectedEventIds.isEmpty) {
            count = 0;
          } else {
            count = await _supabase.rpc('count_unique_event_attendees',
                params: {'event_ids': _selectedEventIds});
          }
          break;

        case SegmentType.everyone:
          count = await _supabase.rpc('count_all_unique_contacts', params: {
            'p_congressional_districts': districts,
            'p_counties': counties,
          });
          break;
      }

      _estimatedRecipients = count;
      _loadingEstimate = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error estimating recipients: $e');
      _estimatedRecipients = 0;
      _loadingEstimate = false;
      notifyListeners();
    }
  }

  // === STEP 4: SCHEDULE & SEND ===

  void toggleSendImmediately(bool value) {
    _sendImmediately = value;
    if (value) {
      _scheduledFor = null;
    }
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void setScheduledTime(DateTime? dateTime) {
    _scheduledFor = dateTime;
    _sendImmediately = dateTime == null;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void toggleABTesting(bool value) {
    _enableABTesting = value;
    if (!value) {
      _variantBSubject = null;
    }
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateVariantBSubject(String value) {
    _variantBSubject = value;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  // === DELIVERABILITY SCORING ===

  /// Calculate deliverability score based on email content
  Future<void> calculateDeliverabilityScore() async {
    if (_htmlContent == null || _htmlContent!.isEmpty) {
      _deliverabilityScore = null;
      _spamScore = null;
      _deliverabilityIssues.clear();
      notifyListeners();
      return;
    }

    _calculatingScore = true;
    notifyListeners();

    try {
      // Analyze email content
      final analysis = _analyzeEmailContent(_htmlContent!);

      _deliverabilityScore = analysis['score'];
      _spamScore = analysis['spamScore'];
      _deliverabilityIssues = List<String>.from(analysis['issues']);

      _calculatingScore = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating deliverability: $e');
      _calculatingScore = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _analyzeEmailContent(String html) {
    int score = 100;
    int spamScore = 0;
    final List<String> issues = [];

    final htmlLower = html.toLowerCase();

    // Check for unsubscribe link
    if (!htmlLower.contains('unsubscribe')) {
      score -= 15;
      spamScore += 20;
      issues.add('Missing unsubscribe link (required by law)');
    }

    // Check for physical address
    if (!htmlLower.contains('address') && !htmlLower.contains('missouri')) {
      score -= 10;
      spamScore += 15;
      issues.add('Missing physical mailing address (CAN-SPAM requirement)');
    }

    // Check for spam trigger words
    final spamWords = [
      'free money',
      'click here now',
      'act now',
      '100% free',
      'winner',
      'congratulations you won',
      'urgent action required'
    ];

    int spamWordCount = 0;
    for (final word in spamWords) {
      if (htmlLower.contains(word)) {
        spamWordCount++;
      }
    }

    if (spamWordCount > 0) {
      score -= spamWordCount * 5;
      spamScore += spamWordCount * 10;
      issues.add('Contains $spamWordCount spam trigger words');
    }

    // Check for excessive links
    final linkCount = 'href='.allMatches(htmlLower).length;
    if (linkCount > 15) {
      score -= 10;
      spamScore += 10;
      issues.add('Too many links ($linkCount) - keep under 15');
    }

    // Check for excessive images
    final imageCount = '<img'.allMatches(htmlLower).length;
    if (imageCount > 10) {
      score -= 5;
      spamScore += 5;
      issues.add('Too many images ($imageCount) - keep under 10');
    }

    // Check for all caps in content (excluding HTML tags)
    final textContent = html.replaceAll(RegExp(r'<[^>]*>'), '');
    final capsRatio = textContent.split('').where((c) => c == c.toUpperCase() && c != c.toLowerCase()).length /
        textContent.length;

    if (capsRatio > 0.3) {
      score -= 15;
      spamScore += 20;
      issues.add('Excessive use of CAPITAL LETTERS');
    }

    // Ensure scores are in valid range
    score = score.clamp(0, 100);
    spamScore = spamScore.clamp(0, 100);

    return {
      'score': score,
      'spamScore': spamScore,
      'issues': issues,
    };
  }

  // === AUTO-SAVE DRAFTS ===

  Future<void> _saveDraft() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final draftData = {
        'user_id': userId,
        'campaign_name': _campaignName.isEmpty ? null : _campaignName,
        'subject_line': _subjectLine.isEmpty ? null : _subjectLine,
        'preview_text': _previewText.isEmpty ? null : _previewText,
        'from_email': _fromEmail,
        'html_content': _htmlContent,
        'design_json': _designJson,
        'segment_type': _selectedSegmentType?.name,
        'segment_filters': {
          'congressional_districts': _selectedCongressionalDistricts,
          'counties': _selectedCounties,
        },
        'selected_events': _selectedEventIds.isEmpty ? null : _selectedEventIds,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_draftId == null) {
        // Create new draft
        final response = await _supabase
            .from('campaign_drafts')
            .insert(draftData)
            .select('id')
            .single();

        _draftId = response['id'] as String;
      } else {
        // Update existing draft
        await _supabase
            .from('campaign_drafts')
            .update(draftData)
            .eq('id', _draftId!);
      }

      _hasUnsavedChanges = false;
      _lastSavedAt = DateTime.now();
      notifyListeners();

      debugPrint('Draft auto-saved: $_draftId');
    } catch (e) {
      debugPrint('Error auto-saving draft: $e');
    }
  }

  /// Manually save draft
  Future<void> saveDraft() async {
    await _saveDraft();
  }

  /// Load draft from database
  Future<void> loadDraft(String draftId) async {
    try {
      final response = await _supabase
          .from('campaign_drafts')
          .select()
          .eq('id', draftId)
          .single();

      _draftId = draftId;
      _campaignName = response['campaign_name'] ?? '';
      _subjectLine = response['subject_line'] ?? '';
      _previewText = response['preview_text'] ?? '';
      _fromEmail = response['from_email'] ?? 'info@moyoungdemocrats.org';
      _htmlContent = response['html_content'];
      _designJson = response['design_json'];

      final segmentTypeStr = response['segment_type'] as String?;
      if (segmentTypeStr != null) {
        _selectedSegmentType =
            SegmentType.values.firstWhere((e) => e.name == segmentTypeStr);
      }

      final filters = response['segment_filters'] as Map<String, dynamic>?;
      if (filters != null) {
        _selectedCongressionalDistricts =
            List<String>.from(filters['congressional_districts'] ?? []);
        _selectedCounties = List<String>.from(filters['counties'] ?? []);
      }

      final events = response['selected_events'];
      if (events != null) {
        _selectedEventIds = List<String>.from(events);
      }

      _hasUnsavedChanges = false;
      _lastSavedAt = DateTime.parse(response['updated_at']);

      notifyListeners();

      // Re-estimate recipients
      if (_selectedSegmentType != null) {
        await estimateRecipients();
      }

      // Re-calculate deliverability
      if (_htmlContent != null) {
        await calculateDeliverabilityScore();
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  /// Delete current draft
  Future<void> deleteDraft() async {
    if (_draftId == null) return;

    try {
      await _supabase.from('campaign_drafts').delete().eq('id', _draftId!);

      _draftId = null;
      _hasUnsavedChanges = false;
      _lastSavedAt = null;

      debugPrint('Draft deleted');
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }
  }

  /// Reset wizard to initial state
  void reset() {
    _draftId = null;
    _campaignName = '';
    _subjectLine = '';
    _previewText = '';
    _fromEmail = 'info@moyoungdemocrats.org';
    _htmlContent = null;
    _designJson = null;
    _selectedSegmentType = null;
    _selectedCongressionalDistricts.clear();
    _selectedCounties.clear();
    _selectedEventIds.clear();
    _estimatedRecipients = 0;
    _scheduledFor = null;
    _sendImmediately = true;
    _enableABTesting = false;
    _variantBSubject = null;
    _deliverabilityScore = null;
    _spamScore = null;
    _deliverabilityIssues.clear();
    _subjectLineSuggestions.clear();
    _hasUnsavedChanges = false;
    _lastSavedAt = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
