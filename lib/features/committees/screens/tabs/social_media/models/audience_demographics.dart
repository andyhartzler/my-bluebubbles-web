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

  /// Safely parse a field that could be a Map, List, or null
  /// - If it's a Map, return it as-is
  /// - If it's a List of objects with a key field (e.g., country, city), convert to Map
  /// - Otherwise, return an empty Map
  static Map<String, dynamic> _parseFlexibleJson(
    dynamic value, {
    String? keyField,
    String? valueField,
  }) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      // Handle Map<dynamic, dynamic> case
      return Map<String, dynamic>.from(value);
    }

    if (value is List) {
      // Convert list to map using specified key/value fields
      final result = <String, dynamic>{};
      for (final item in value) {
        if (item is Map) {
          // Try common key patterns: country, city, source, device, etc.
          final possibleKeys = [
            keyField,
            'country',
            'city',
            'source',
            'device',
            'name',
            'key',
            'label',
          ].whereType<String>();

          String? key;
          for (final k in possibleKeys) {
            if (item.containsKey(k)) {
              key = item[k]?.toString();
              break;
            }
          }

          if (key != null && key.isNotEmpty) {
            // Use specified value field, or common patterns, or the whole item
            dynamic val;
            final possibleValues = [
              valueField,
              'views',
              'count',
              'value',
              'watchTimeMinutes',
            ].whereType<String>();

            for (final v in possibleValues) {
              if (item.containsKey(v)) {
                val = item[v];
                break;
              }
            }

            result[key] = val ?? item;
          }
        }
      }
      return result;
    }

    return {};
  }

  factory AudienceDemographics.fromJson(Map<String, dynamic> json) {
    return AudienceDemographics(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      metricDate: json['metric_date'] as String,
      ageGenderBreakdown: _parseFlexibleJson(json['age_gender_breakdown']),
      topCountries: _parseFlexibleJson(
        json['top_countries'],
        keyField: 'country',
        valueField: 'views',
      ),
      topCities: _parseFlexibleJson(
        json['top_cities'],
        keyField: 'city',
        valueField: 'views',
      ),
      topLanguages: _parseFlexibleJson(
        json['top_languages'],
        keyField: 'language',
        valueField: 'count',
      ),
      platformDemographics: _parseFlexibleJson(json['platform_demographics']),
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
