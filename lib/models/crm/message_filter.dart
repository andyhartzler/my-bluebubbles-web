/// Filter criteria for bulk messaging
/// Used to select which members receive a message
class MessageFilter {
  final String? county;
  final String? congressionalDistrict;
  final List<String>? committees;
  final String? schoolName;
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
    this.schoolName,
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
      schoolName != null ||
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
    if (schoolName != null) parts.add('School: $schoolName');
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
    String? schoolName,
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
      schoolName: schoolName ?? this.schoolName,
      chapterName: chapterName ?? this.chapterName,
      chapterStatus: chapterStatus ?? this.chapterStatus,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      excludeOptedOut: excludeOptedOut ?? this.excludeOptedOut,
      excludeRecentlyContacted: excludeRecentlyContacted ?? this.excludeRecentlyContacted,
      recentContactThreshold: recentContactThreshold ?? this.recentContactThreshold,
    );
  }
}
