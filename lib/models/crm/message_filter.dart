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
    // Backward-compatible single-value parameters
    String? congressionalDistrict,
    String? highSchool,
    String? college,
  })  : congressionalDistricts = congressionalDistricts ??
            (congressionalDistrict != null ? [congressionalDistrict] : null),
        highSchools = highSchools ??
            (highSchool != null ? [highSchool] : null),
        colleges = colleges ??
            (college != null ? [college] : null);

  // Backward-compatible single-value getters
  String? get congressionalDistrict =>
      congressionalDistricts?.isNotEmpty == true ? congressionalDistricts!.first : null;
  String? get highSchool =>
      highSchools?.isNotEmpty == true ? highSchools!.first : null;
  String? get college =>
      colleges?.isNotEmpty == true ? colleges!.first : null;

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
    // Backward-compatible single-value parameters
    String? congressionalDistrict,
    String? highSchool,
    String? college,
  }) {
    // Handle single-value backward compatibility
    List<String>? newDistricts = congressionalDistricts ?? this.congressionalDistricts;
    if (congressionalDistrict != null) {
      newDistricts = [congressionalDistrict];
    }

    List<String>? newHighSchools = highSchools ?? this.highSchools;
    if (highSchool != null) {
      newHighSchools = [highSchool];
    }

    List<String>? newColleges = colleges ?? this.colleges;
    if (college != null) {
      newColleges = [college];
    }

    return MessageFilter(
      county: county ?? this.county,
      congressionalDistricts: newDistricts,
      committees: committees ?? this.committees,
      highSchools: newHighSchools,
      colleges: newColleges,
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
    // Backward-compatible single-value parameters
    String? congressionalDistrict,
    bool clearCongressionalDistrict = false,
    String? highSchool,
    bool clearHighSchool = false,
    String? college,
    bool clearCollege = false,
  }) {
    // Handle backward-compatible clear flags
    final shouldClearDistricts = clearCongressionalDistricts || clearCongressionalDistrict;
    final shouldClearHighSchools = clearHighSchools || clearHighSchool;
    final shouldClearColleges = clearColleges || clearCollege;

    // Handle single-value backward compatibility
    List<String>? newDistricts;
    if (shouldClearDistricts) {
      newDistricts = null;
    } else if (congressionalDistrict != null) {
      newDistricts = [congressionalDistrict];
    } else {
      newDistricts = congressionalDistricts ?? this.congressionalDistricts;
    }

    List<String>? newHighSchools;
    if (shouldClearHighSchools) {
      newHighSchools = null;
    } else if (highSchool != null) {
      newHighSchools = [highSchool];
    } else {
      newHighSchools = highSchools ?? this.highSchools;
    }

    List<String>? newColleges;
    if (shouldClearColleges) {
      newColleges = null;
    } else if (college != null) {
      newColleges = [college];
    } else {
      newColleges = colleges ?? this.colleges;
    }

    return MessageFilter(
      county: clearCounty ? null : (county ?? this.county),
      congressionalDistricts: newDistricts,
      committees: clearCommittees ? null : (committees ?? this.committees),
      highSchools: newHighSchools,
      colleges: newColleges,
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
