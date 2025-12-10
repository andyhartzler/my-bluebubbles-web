/// Vote analytics data models for displaying engagement funnel,
/// participation metrics, and vote results

/// Complete vote analytics including engagement funnel and activity data
class VoteAnalytics {
  final String formId;
  final int totalViews;
  final int uniqueViewers;
  final int totalStarts;
  final int totalSubmissions;
  final int totalAbandons;
  final double viewToStartRate;
  final double startToSubmitRate;
  final double overallConversionRate;
  final double averageTimeToComplete;
  final List<VoteFieldAnalytics> fieldAnalytics;
  final List<HourlyActivityData> hourlyActivity;
  final List<DailyActivityData> dailyActivity;

  const VoteAnalytics({
    required this.formId,
    required this.totalViews,
    required this.uniqueViewers,
    required this.totalStarts,
    required this.totalSubmissions,
    required this.totalAbandons,
    required this.viewToStartRate,
    required this.startToSubmitRate,
    required this.overallConversionRate,
    required this.averageTimeToComplete,
    required this.fieldAnalytics,
    required this.hourlyActivity,
    required this.dailyActivity,
  });

  /// Create from form analytics summary
  factory VoteAnalytics.fromFormAnalytics({
    required String formId,
    required int totalViews,
    required int totalStarts,
    required int totalSubmissions,
    required int totalAbandons,
    List<VoteFieldAnalytics>? fieldAnalytics,
    List<HourlyActivityData>? hourlyActivity,
    List<DailyActivityData>? dailyActivity,
  }) {
    final viewToStart = totalViews > 0
        ? (totalStarts / totalViews * 100)
        : 0.0;
    final startToSubmit = totalStarts > 0
        ? (totalSubmissions / totalStarts * 100)
        : 0.0;
    final overall = totalViews > 0
        ? (totalSubmissions / totalViews * 100)
        : 0.0;

    return VoteAnalytics(
      formId: formId,
      totalViews: totalViews,
      uniqueViewers: totalViews, // Approximate if not tracked separately
      totalStarts: totalStarts,
      totalSubmissions: totalSubmissions,
      totalAbandons: totalAbandons,
      viewToStartRate: viewToStart,
      startToSubmitRate: startToSubmit,
      overallConversionRate: overall,
      averageTimeToComplete: 0, // Not tracked yet
      fieldAnalytics: fieldAnalytics ?? [],
      hourlyActivity: hourlyActivity ?? [],
      dailyActivity: dailyActivity ?? [],
    );
  }

  /// Empty analytics for when no data exists
  factory VoteAnalytics.empty(String formId) {
    return VoteAnalytics(
      formId: formId,
      totalViews: 0,
      uniqueViewers: 0,
      totalStarts: 0,
      totalSubmissions: 0,
      totalAbandons: 0,
      viewToStartRate: 0,
      startToSubmitRate: 0,
      overallConversionRate: 0,
      averageTimeToComplete: 0,
      fieldAnalytics: [],
      hourlyActivity: [],
      dailyActivity: [],
    );
  }
}

/// Field-level analytics for vote questions
class VoteFieldAnalytics {
  final String fieldId;
  final String? fieldLabel;
  final int interactions;
  final int completions;
  final double averageTimeSpent;
  final double dropOffRate;

  const VoteFieldAnalytics({
    required this.fieldId,
    this.fieldLabel,
    required this.interactions,
    required this.completions,
    required this.averageTimeSpent,
    required this.dropOffRate,
  });

  double get completionRate =>
      interactions > 0 ? (completions / interactions * 100) : 0;
}

/// Hourly activity data for charts
class HourlyActivityData {
  final DateTime hour;
  final int views;
  final int submissions;

  const HourlyActivityData({
    required this.hour,
    required this.views,
    required this.submissions,
  });
}

/// Daily activity data with cumulative vote tracking
class DailyActivityData {
  final DateTime date;
  final int views;
  final int submissions;
  final int cumulativeVotes;

  const DailyActivityData({
    required this.date,
    required this.views,
    required this.submissions,
    required this.cumulativeVotes,
  });
}

/// Vote results summary with participation metrics
class VoteResultsSummary {
  final String formId;
  final int totalVotes;
  final int eligibleVoters;
  final double participationRate;
  final List<QuestionResultData> questionResults;

  const VoteResultsSummary({
    required this.formId,
    required this.totalVotes,
    required this.eligibleVoters,
    required this.participationRate,
    required this.questionResults,
  });

  factory VoteResultsSummary.fromVoteData({
    required String formId,
    required int totalVotes,
    required int eligibleVoters,
    required List<QuestionResultData> questionResults,
  }) {
    final participationRate = eligibleVoters > 0
        ? (totalVotes / eligibleVoters * 100)
        : 0.0;

    return VoteResultsSummary(
      formId: formId,
      totalVotes: totalVotes,
      eligibleVoters: eligibleVoters,
      participationRate: participationRate,
      questionResults: questionResults,
    );
  }
}

/// Results for a single question
class QuestionResultData {
  final String fieldId;
  final String question;
  final String questionType;
  final List<OptionResultData> options;
  final String? winner; // For single-choice questions

  const QuestionResultData({
    required this.fieldId,
    required this.question,
    required this.questionType,
    required this.options,
    this.winner,
  });

  /// Total votes for this question
  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.count);
}

/// Results for a single option
class OptionResultData {
  final String value;
  final String label;
  final int count;
  final double percentage;

  const OptionResultData({
    required this.value,
    required this.label,
    required this.count,
    required this.percentage,
  });
}
