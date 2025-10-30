/// Filter criteria for bulk messaging
/// Used to select which members receive a message
class MessageFilter {
  final String? county;
  final String? congressionalDistrict;
  final List<String>? committees;
  final String? highSchool;
  final String? college;
  final String? chapterName;
  final String? chapterStatus;
  final int? minAge;
  final int? maxAge;
  final bool excludeOptedOut;
  final bool excludeRecentlyContacted;
  final Duration? recentContactThreshold;

  MessageFilter({
    this.county,
    this.congressionalDistrict,
    this.committees,
    this.highSchool,
    this.college,
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
      congressionalDistrict != null ||
      (committees != null && committees!.isNotEmpty) ||
      highSchool != null ||
      college != null ||
      chapterName != null ||
      chapterStatus != null ||
      minAge != null ||
      maxAge != null;

  /// Get human-readable description of filters
  String get description {
    final parts = <String>[];

    if (county != null) parts.add('County: $county');
    if (congressionalDistrict != null) parts.add('District: $congressionalDistrict');
    if (committees != null && committees!.isNotEmpty) {
      parts.add('Committees: ${committees!.join(", ")}');
    }
    if (highSchool != null) parts.add('High School: $highSchool');
    if (college != null) parts.add('College: $college');
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
    String? congressionalDistrict,
    List<String>? committees,
    String? highSchool,
    String? college,
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
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      committees: committees ?? this.committees,
      highSchool: highSchool ?? this.highSchool,
      college: college ?? this.college,
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
    String? congressionalDistrict,
    bool clearCongressionalDistrict = false,
    List<String>? committees,
    bool clearCommittees = false,
    String? highSchool,
    bool clearHighSchool = false,
    String? college,
    bool clearCollege = false,
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
      congressionalDistrict:
          clearCongressionalDistrict ? null : (congressionalDistrict ?? this.congressionalDistrict),
      committees: clearCommittees ? null : (committees ?? this.committees),
      highSchool: clearHighSchool ? null : (highSchool ?? this.highSchool),
      college: clearCollege ? null : (college ?? this.college),
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
