import 'package:flutter/material.dart';

/// Represents a single talking point
class TalkingPoint {
  final String type; // 'values', 'impact', 'factual', 'emotional', 'counter'
  final String point;
  final String? supportingDetail;

  TalkingPoint({
    required this.type,
    required this.point,
    this.supportingDetail,
  });

  factory TalkingPoint.fromJson(Map<String, dynamic> json) {
    return TalkingPoint(
      type: json['type'] as String? ?? 'general',
      point: json['point'] as String,
      supportingDetail: json['supporting_detail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'point': point,
        'supporting_detail': supportingDetail,
      };

  String get typeLabel {
    switch (type) {
      case 'values':
        return 'Values-Based';
      case 'impact':
        return 'Impact';
      case 'factual':
        return 'Factual';
      case 'emotional':
        return 'Human Story';
      case 'counter':
        return 'Counter-Argument';
      default:
        return 'General';
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'values':
        return '💙';
      case 'impact':
        return '🎯';
      case 'factual':
        return '📊';
      case 'emotional':
        return '❤️';
      case 'counter':
        return '🛡️';
      default:
        return '📝';
    }
  }

  Color get typeColor {
    switch (type) {
      case 'values':
        return const Color(0xFF3B82F6); // Blue
      case 'impact':
        return const Color(0xFFF97316); // Orange
      case 'factual':
        return const Color(0xFF22C55E); // Green
      case 'emotional':
        return const Color(0xFFEF4444); // Red
      case 'counter':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

/// Represents a pre-written tweet/social media post
class TwitterPost {
  final String text;
  final List<String> hashtags;

  TwitterPost({
    required this.text,
    this.hashtags = const [],
  });

  factory TwitterPost.fromJson(Map<String, dynamic> json) {
    return TwitterPost(
      text: json['text'] as String,
      hashtags:
          (json['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'hashtags': hashtags,
      };

  String get fullText {
    final tags = hashtags.map((h) => '#$h').join(' ');
    return '$text${tags.isNotEmpty ? '\n$tags' : ''}';
  }

  int get characterCount => fullText.length;
  bool get isValidLength => characterCount <= 280;
}

/// Audience types for targeted talking points
enum TargetAudience {
  generalPublic('general_public', 'General Public', Icons.people),
  legislators('legislators', 'Legislators', Icons.account_balance),
  students('students', 'Students', Icons.school),
  workingFamilies('working_families', 'Working Families', Icons.family_restroom),
  ruralMissouri('rural_missouri', 'Rural Missouri', Icons.agriculture);

  const TargetAudience(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static TargetAudience fromKey(String key) {
    return TargetAudience.values.firstWhere(
      (e) => e.key == key,
      orElse: () => TargetAudience.generalPublic,
    );
  }
}
