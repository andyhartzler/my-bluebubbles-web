/// Represents audience demographics data for a social media account
class AudienceDemographics {
  final String id;
  final String accountId;
  final String metricDate;
  final Map<String, dynamic> ageGenderBreakdown;
  final Map<String, dynamic> topCountries;
  final Map<String, dynamic> topCities;
  final Map<String, dynamic> topLanguages;
  final Map<String, dynamic> platformDemographics;

  const AudienceDemographics({
    required this.id,
    required this.accountId,
    required this.metricDate,
    this.ageGenderBreakdown = const {},
    this.topCountries = const {},
    this.topCities = const {},
    this.topLanguages = const {},
    this.platformDemographics = const {},
  });

  factory AudienceDemographics.fromJson(Map<String, dynamic> json) {
    return AudienceDemographics(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      metricDate: json['metric_date'] as String,
      ageGenderBreakdown: json['age_gender_breakdown'] as Map<String, dynamic>? ?? {},
      topCountries: json['top_countries'] as Map<String, dynamic>? ?? {},
      topCities: json['top_cities'] as Map<String, dynamic>? ?? {},
      topLanguages: json['top_languages'] as Map<String, dynamic>? ?? {},
      platformDemographics: json['platform_demographics'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'metric_date': metricDate,
      'age_gender_breakdown': ageGenderBreakdown,
      'top_countries': topCountries,
      'top_cities': topCities,
      'top_languages': topLanguages,
      'platform_demographics': platformDemographics,
    };
  }

  /// Check if there's any demographic data available
  bool get hasData =>
      ageGenderBreakdown.isNotEmpty ||
      topCountries.isNotEmpty ||
      topCities.isNotEmpty ||
      topLanguages.isNotEmpty;
}
