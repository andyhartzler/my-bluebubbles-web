import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

enum GlobalSearchItemType { member, meeting, transcript, document }

class GlobalSearchResults {
  const GlobalSearchResults({
    required this.query,
    this.members = const <Member>[],
    this.meetings = const <Meeting>[],
    this.transcripts = const <GlobalSearchTranscript>[],
    this.documents = const <GlobalSearchDocument>[],
  });

  final String query;
  final List<Member> members;
  final List<Meeting> meetings;
  final List<GlobalSearchTranscript> transcripts;
  final List<GlobalSearchDocument> documents;

  bool get isEmpty =>
      members.isEmpty && meetings.isEmpty && transcripts.isEmpty && documents.isEmpty;

  Map<GlobalSearchItemType, int> get facetCounts {
    final counts = <GlobalSearchItemType, int>{};
    if (members.isNotEmpty) {
      counts[GlobalSearchItemType.member] = members.length;
    }
    if (meetings.isNotEmpty) {
      counts[GlobalSearchItemType.meeting] = meetings.length;
    }
    if (transcripts.isNotEmpty) {
      counts[GlobalSearchItemType.transcript] = transcripts.length;
    }
    if (documents.isNotEmpty) {
      counts[GlobalSearchItemType.document] = documents.length;
    }
    return counts;
  }

  List<GlobalSearchResultItem> items([GlobalSearchItemType? facet]) {
    final filtered = <GlobalSearchResultItem>[];

    void addAll(GlobalSearchItemType type, Iterable<Object> entries) {
      if (facet != null && facet != type) {
        return;
      }
      for (final entry in entries) {
        filtered.add(GlobalSearchResultItem(type: type, payload: entry));
      }
    }

    addAll(GlobalSearchItemType.member, members);
    addAll(GlobalSearchItemType.meeting, meetings);
    addAll(GlobalSearchItemType.transcript, transcripts);
    addAll(GlobalSearchItemType.document, documents);

    return filtered;
  }
}

class GlobalSearchResultItem {
  const GlobalSearchResultItem({
    required this.type,
    required this.payload,
  });

  final GlobalSearchItemType type;
  final Object payload;
}

class GlobalSearchTranscript {
  const GlobalSearchTranscript({
    required this.id,
    this.meetingId,
    this.meetingTitle,
    this.title,
    this.summary,
    this.storageUri,
    this.createdAt,
  });

  final String id;
  final String? meetingId;
  final String? meetingTitle;
  final String? title;
  final String? summary;
  final String? storageUri;
  final DateTime? createdAt;

  static GlobalSearchTranscript fromJson(Map<String, dynamic> json) {
    final idValue = json['id']?.toString() ?? '';
    final meetingId = json['meeting_id']?.toString();
    final createdAt = _tryParseDateTime(json['created_at']) ?? _tryParseDateTime(json['indexed_at']);

    final rawStorage = json['storage_path'] ?? json['file_path'] ?? json['transcript_path'];
    final bucket = json['bucket']?.toString();
    String? storageUri;
    if (rawStorage is String && rawStorage.isNotEmpty) {
      if (rawStorage.startsWith('storage://') || rawStorage.startsWith('http')) {
        storageUri = rawStorage;
      } else {
        final normalized = rawStorage.startsWith('/') ? rawStorage.substring(1) : rawStorage;
        final bucketName = (bucket != null && bucket.isNotEmpty) ? bucket : 'meetings';
        storageUri = 'storage://$bucketName/$normalized';
      }
    }

    return GlobalSearchTranscript(
      id: idValue,
      meetingId: meetingId?.isEmpty ?? true ? null : meetingId,
      meetingTitle: json['meeting_title']?.toString(),
      title: json['title']?.toString() ?? json['name']?.toString(),
      summary: json['summary']?.toString() ?? json['description']?.toString(),
      storageUri: storageUri,
      createdAt: createdAt,
    );
  }
}

class GlobalSearchDocument {
  const GlobalSearchDocument({
    required this.bucket,
    required this.path,
    required this.name,
    this.sizeBytes,
    this.updatedAt,
    this.createdAt,
  });

  final String bucket;
  final String path;
  final String name;
  final int? sizeBytes;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  String get storageUri => 'storage://$bucket/$path';
}

class GlobalSearchService {
  GlobalSearchService._();

  static final GlobalSearchService _instance = GlobalSearchService._();

  factory GlobalSearchService() => _instance;

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => _supabase.isInitialized;

  Future<GlobalSearchResults> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || !isReady) {
      return GlobalSearchResults(query: query);
    }

    final sanitized = _escapeForIlike(query);
    final futures = await Future.wait<List<Object>>([
      _searchMembers(sanitized),
      _searchMeetings(sanitized),
      _searchTranscripts(sanitized),
      _enumerateDocuments(query),
    ]);

    final members = futures[0].whereType<Member>().toList();
    final meetings = futures[1].whereType<Meeting>().toList();
    final transcripts = futures[2].whereType<GlobalSearchTranscript>().toList();
    final documents = futures[3].whereType<GlobalSearchDocument>().toList();

    return GlobalSearchResults(
      query: query,
      members: members,
      meetings: meetings,
      transcripts: transcripts,
      documents: documents,
    );
  }

  Future<List<Object>> _searchMembers(String ilikeTerm) async {
    if (!isReady) return const [];

    try {
      final client = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;
      final pattern = '%$ilikeTerm%';
      var query = client.from('members').select();
      query = query.or([
        'name.ilike.$pattern',
        'email.ilike.$pattern',
        'phone.ilike.$pattern',
        'phone_e164.ilike.$pattern',
        'county.ilike.$pattern',
        'chapter_name.ilike.$pattern',
      ].join(','));
      final response = await query.limit(25);
      final rows = _coerceList(response);
      final members = rows
          .map((row) => Member.fromJson(row))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return members;
    } catch (error) {
      debugPrint('⚠️ CRM global search (members) failed: $error');
      return const [];
    }
  }

  Future<List<Object>> _searchMeetings(String ilikeTerm) async {
    if (!isReady) return const [];

    try {
      final client = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;
      final pattern = '%$ilikeTerm%';
      var query = client.from('meetings').select('*');
      query = query.or([
        'meeting_title.ilike.$pattern',
        'action_items.ilike.$pattern',
        'executive_recap.ilike.$pattern',
        'discussion_highlights.ilike.$pattern',
        'decisions_rationales.ilike.$pattern',
        'risks_open_questions.ilike.$pattern',
      ].join(','));
      final response = await query.limit(25);
      final rows = _coerceList(response);
      final meetings = rows
          .map((row) => Meeting.fromJson(row, includeAttendance: false))
          .toList()
        ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
      return meetings;
    } catch (error) {
      debugPrint('⚠️ CRM global search (meetings) failed: $error');
      return const [];
    }
  }

  Future<List<Object>> _searchTranscripts(String ilikeTerm) async {
    if (!isReady) return const [];

    try {
      final client = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;
      final pattern = '%$ilikeTerm%';
      var query = client.from('meeting_transcripts').select('*');
      query = query.or([
        'title.ilike.$pattern',
        'summary.ilike.$pattern',
        'meeting_title.ilike.$pattern',
      ].join(','));
      final response = await query.limit(25);
      final rows = _coerceList(response);
      final transcripts = rows
          .map(GlobalSearchTranscript.fromJson)
          .where((transcript) => transcript.id.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
      return transcripts;
    } on PostgrestException catch (error) {
      debugPrint('⚠️ CRM global search (transcripts) unavailable: ${error.message}');
      return const [];
    } catch (error) {
      debugPrint('⚠️ CRM global search (transcripts) failed: $error');
      return const [];
    }
  }

  Future<List<Object>> _enumerateDocuments(String rawTerm) async {
    if (!isReady) return const [];

    final lowerTerm = rawTerm.trim().toLowerCase();
    final client = _supabase.client;
    final results = <GlobalSearchDocument>[];

    final scopes = <_StorageScope>[
      const _StorageScope(bucket: 'meetings', prefixes: <String>['transcripts', 'documents']),
      const _StorageScope(bucket: 'chapter-documents', prefixes: <String>['']),
    ];

    for (final scope in scopes) {
      for (final prefix in scope.prefixes) {
        try {
          final objects = await client.storage.from(scope.bucket).list(
                path: prefix,
                searchOptions: const SearchOptions(limit: 100),
              );
          for (final object in objects) {
            if (object.id == null || object.name.isEmpty) {
              continue; // directories or invalid entries
            }

            final relativePath = prefix.isEmpty ? object.name : '$prefix/${object.name}';
            final compareTarget = relativePath.toLowerCase();
            if (lowerTerm.isNotEmpty &&
                !object.name.toLowerCase().contains(lowerTerm) &&
                !compareTarget.contains(lowerTerm)) {
              continue;
            }

            final size = object.metadata?['size'];
            results.add(
              GlobalSearchDocument(
                bucket: scope.bucket,
                path: relativePath,
                name: object.name,
                sizeBytes: size is num ? size.toInt() : null,
                createdAt: object.createdAt,
                updatedAt: object.updatedAt,
              ),
            );
          }
        } on StorageException catch (error) {
          debugPrint('⚠️ CRM global search (storage ${scope.bucket}) failed: ${error.message}');
        } catch (error) {
          debugPrint('⚠️ CRM global search (storage ${scope.bucket}) error: $error');
        }
      }
    }

    results.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return results.take(30).toList();
  }

  static String _escapeForIlike(String input) {
    return input
        .replaceAll('\\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_')
        .trim();
  }

  static List<Map<String, dynamic>> _coerceList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((raw) => raw.map((key, dynamic value) => MapEntry(key.toString(), value)))
          .toList();
    }
    return const [];
  }

  static DateTime? _tryParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

class _StorageScope {
  const _StorageScope({
    required this.bucket,
    required this.prefixes,
  });

  final String bucket;
  final List<String> prefixes;
}
