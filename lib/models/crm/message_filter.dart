/// Filter criteria for bulk messaging
/// Used to select which members receive a message
class MessageFilter {
  final String? county;
  final List<String>? congressionalDistricts;
  final List<String>? committees;
  final List<String>? highSchools;
  final List<String>? colleges;
  final bool anyHighSchool;
  final String? chapterName;
  final String? chapterStatus;
  final int? minAge;
  final int? maxAge;
  final bool excludeOptedOut;
  final bool excludeRecentlyContacted;
  final Duration? recentContactThreshold;

  MessageFilter({
    this.county,
    this.congressionalDistricts,
    this.committees,
    this.highSchools,
    this.colleges,
    this.anyHighSchool = false,
    this.chapterName,
    this.chapterStatus,
    this.minAge,
    this.maxAge,
    this.excludeOptedOut = true,
    this.excludeRecentlyContacted = false,
    this.recentContactThreshold = const Duration(days: 7),
  });

  /// Check if any filters are active
  bool get hasActiveFilters =>
      county != null ||
      (congressionalDistricts != null && congressionalDistricts!.isNotEmpty) ||
      (committees != null && committees!.isNotEmpty) ||
      (highSchools != null && highSchools!.isNotEmpty) ||
      (colleges != null && colleges!.isNotEmpty) ||
      anyHighSchool ||
      chapterName != null ||
      chapterStatus != null ||
      minAge != null ||
      maxAge != null;

  /// Get human-readable description of filters
  String get description {
    final parts = <String>[];

    if (county != null) parts.add('County: $county');
    if (congressionalDistricts != null && congressionalDistricts!.isNotEmpty) {
      parts.add('Districts: ${congressionalDistricts!.join(", ")}');
    }
    if (committees != null && committees!.isNotEmpty) {
      parts.add('Committees: ${committees!.join(", ")}');
    }
    if (anyHighSchool) {
      parts.add('All High School Members');
    } else if (highSchools != null && highSchools!.isNotEmpty) {
      parts.add('High Schools: ${highSchools!.join(", ")}');
    }
    if (colleges != null && colleges!.isNotEmpty) {
      parts.add('Colleges: ${colleges!.join(", ")}');
    }
    if (chapterName != null) parts.add('Chapter: $chapterName');
    if (chapterStatus != null) parts.add('Chapter Status: $chapterStatus');
    if (minAge != null || maxAge != null) {
      if (minAge != null && maxAge != null) {
        parts.add('Age: $minAge-$maxAge');
      } else if (minAge != null) {
        parts.add('Age: $minAge+');
      } else {
        parts.add('Age: up to $maxAge');
      }
    }

    if (excludeOptedOut) parts.add('Excluding opted-out');
    if (excludeRecentlyContacted) {
      parts.add('Not contacted in ${recentContactThreshold!.inDays} days');
    }

    return parts.isEmpty ? 'All members' : parts.join(' • ');
  }

  MessageFilter copyWith({
    String? county,
    List<String>? congressionalDistricts,
    List<String>? committees,
    List<String>? highSchools,
    List<String>? colleges,
    bool? anyHighSchool,
    String? chapterName,
    String? chapterStatus,
    int? minAge,
    int? maxAge,
    bool? excludeOptedOut,
    bool? excludeRecentlyContacted,
    Duration? recentContactThreshold,
  }) {
    return MessageFilter(
      county: county ?? this.county,
      congressionalDistricts: congressionalDistricts ?? this.congressionalDistricts,
      committees: committees ?? this.committees,
      highSchools: highSchools ?? this.highSchools,
      colleges: colleges ?? this.colleges,
      anyHighSchool: anyHighSchool ?? this.anyHighSchool,
      chapterName: chapterName ?? this.chapterName,
      chapterStatus: chapterStatus ?? this.chapterStatus,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      excludeOptedOut: excludeOptedOut ?? this.excludeOptedOut,
      excludeRecentlyContacted: excludeRecentlyContacted ?? this.excludeRecentlyContacted,
      recentContactThreshold: recentContactThreshold ?? this.recentContactThreshold,
    );
  }

  MessageFilter copyWithOverrides({
    String? county,
    bool clearCounty = false,
    List<String>? congressionalDistricts,
    bool clearCongressionalDistricts = false,
    List<String>? committees,
    bool clearCommittees = false,
    List<String>? highSchools,
    bool clearHighSchools = false,
    List<String>? colleges,
    bool clearColleges = false,
    bool? anyHighSchool,
    String? chapterName,
    bool clearChapterName = false,
    String? chapterStatus,
    bool clearChapterStatus = false,
    int? minAge,
    bool clearMinAge = false,
    int? maxAge,
    bool clearMaxAge = false,
    bool? excludeOptedOut,
    bool? excludeRecentlyContacted,
    Duration? recentContactThreshold,
  }) {
    return MessageFilter(
      county: clearCounty ? null : (county ?? this.county),
      congressionalDistricts:
          clearCongressionalDistricts ? null : (congressionalDistricts ?? this.congressionalDistricts),
      committees: clearCommittees ? null : (committees ?? this.committees),
      highSchools: clearHighSchools ? null : (highSchools ?? this.highSchools),
      colleges: clearColleges ? null : (colleges ?? this.colleges),
      anyHighSchool: anyHighSchool ?? this.anyHighSchool,
      chapterName: clearChapterName ? null : (chapterName ?? this.chapterName),
      chapterStatus: clearChapterStatus ? null : (chapterStatus ?? this.chapterStatus),
      minAge: clearMinAge ? null : (minAge ?? this.minAge),
      maxAge: clearMaxAge ? null : (maxAge ?? this.maxAge),
      excludeOptedOut: excludeOptedOut ?? this.excludeOptedOut,
      excludeRecentlyContacted: excludeRecentlyContacted ?? this.excludeRecentlyContacted,
      recentContactThreshold: recentContactThreshold ?? this.recentContactThreshold,
    );
  }
}
