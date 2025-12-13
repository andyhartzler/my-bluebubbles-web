import 'package:flutter/material.dart';

/// Represents a note on a tracked bill
class BillNote {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String billId;
  final String authorId;
  final String content;
  final String noteType;
  final bool isPinned;
  final bool isInternal;
  final List<String> mentionedMemberIds;

  // Joined data
  final String? authorName;
  final String? authorAvatarUrl;

  BillNote({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.billId,
    required this.authorId,
    required this.content,
    this.noteType = 'general',
    this.isPinned = false,
    this.isInternal = true,
    this.mentionedMemberIds = const [],
    this.authorName,
    this.authorAvatarUrl,
  });

  factory BillNote.fromJson(Map<String, dynamic> json) {
    return BillNote(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      billId: json['bill_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      noteType: json['note_type'] as String? ?? 'general',
      isPinned: json['is_pinned'] as bool? ?? false,
      isInternal: json['is_internal'] as bool? ?? true,
      mentionedMemberIds: _parseStringList(json['mentioned_member_ids']),
      authorName: json['author_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'bill_id': billId,
      'author_id': authorId,
      'content': content,
      'note_type': noteType,
      'is_pinned': isPinned,
      'is_internal': isInternal,
      'mentioned_member_ids': mentionedMemberIds,
    };
  }

  BillNote copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? billId,
    String? authorId,
    String? content,
    String? noteType,
    bool? isPinned,
    bool? isInternal,
    List<String>? mentionedMemberIds,
    String? authorName,
    String? authorAvatarUrl,
  }) {
    return BillNote(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billId: billId ?? this.billId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      noteType: noteType ?? this.noteType,
      isPinned: isPinned ?? this.isPinned,
      isInternal: isInternal ?? this.isInternal,
      mentionedMemberIds: mentionedMemberIds ?? this.mentionedMemberIds,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}

/// Note type enum
enum NoteType {
  general('general', 'General Note', Icons.note),
  analysis('analysis', 'Analysis', Icons.analytics),
  talkingPoint('talking_point', 'Talking Point', Icons.chat_bubble),
  actionItem('action_item', 'Action Item', Icons.task_alt),
  meetingNote('meeting_note', 'Meeting Note', Icons.groups);

  const NoteType(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static NoteType fromString(String value) {
    return NoteType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NoteType.general,
    );
  }
}
