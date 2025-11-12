import 'dart:typed_data';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/quick_link.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQuickLinksRepository extends QuickLinksRepository {
  _FakeQuickLinksRepository({
    List<Map<String, dynamic>> initialRows = const [],
    DateTime? now,
    this.fixedSignedUrl,
  })  : _rows = initialRows,
        super(clock: () => now ?? DateTime.utc(2024, 1, 1, 12));

  List<Map<String, dynamic>> _rows;
  Map<String, dynamic>? lastInsertPayload;
  Map<String, dynamic>? lastUpdatePayload;
  String? lastUpdateId;
  String? lastDeleteId;
  Uint8List? lastUploadedBytes;
  String? lastUploadedPath;
  String? lastUploadedContentType;
  bool removeCalled = false;
  final List<String> signedUrlRequests = [];
  final String? fixedSignedUrl;

  @override
  Future<List<Map<String, dynamic>>> fetchQuickLinkRows() async {
    return _rows.map((row) => {...row}).toList();
  }

  @override
  Future<Map<String, dynamic>> insertQuickLinkRow(Map<String, dynamic> payload) async {
    lastInsertPayload = {...payload};
    final newRow = {
      'id': payload['id'] ?? 'id-${_rows.length + 1}',
      ...payload,
    };
    _rows = [..._rows, newRow];
    return {...newRow};
  }

  @override
  Future<Map<String, dynamic>> updateQuickLinkRow(String id, Map<String, dynamic> payload) async {
    lastUpdateId = id;
    lastUpdatePayload = {...payload};
    _rows = _rows
        .map((row) => row['id'] == id
            ? {
                ...row,
                ...payload,
              }
            : row)
        .toList();
    return {..._rows.firstWhere((row) => row['id'] == id)};
  }

  @override
  Future<void> deleteQuickLinkRow(String id) async {
    lastDeleteId = id;
    _rows = _rows.where((row) => row['id'] != id).toList();
  }

  @override
  Future<void> uploadBinary(
    String bucket,
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    lastUploadedPath = path;
    lastUploadedBytes = Uint8List.fromList(bytes);
    lastUploadedContentType = contentType;
  }

  @override
  Future<void> removeStorageReference(String bucket, String path) async {
    removeCalled = true;
  }

  @override
  Future<String?> createSignedUrl(String bucket, String path, Duration ttl) async {
    signedUrlRequests.add(path);
    if (fixedSignedUrl != null) {
      return fixedSignedUrl;
    }
    return 'https://signed.example/$path';
  }
}

void main() {
  group('QuickLinksRepository', () {
    test('fetchQuickLinks hydrates signed URLs and sorts categories', () async {
      final repo = _FakeQuickLinksRepository(
        initialRows: [
          {
            'id': 'b',
            'title': 'Zeta Plan',
            'category': 'Documents',
            'storage_bucket': 'quick-access-files',
            'storage_path': 'docs/zeta.pdf',
            'file_name': 'zeta.pdf',
            'icon_url': 'https://example.com/icons/zeta.png',
          },
          {
            'id': 'a',
            'title': 'Alpha Site',
            'category': 'Links',
            'url': 'https://alpha.example',
            'icon_url': 'https://example.com/icons/alpha.png',
          },
        ],
        fixedSignedUrl: 'https://signed.example/docs/zeta.pdf',
      )..debugOverrideClients(isInitialized: true);

      final links = await repo.fetchQuickLinks(signedUrlTTL: const Duration(minutes: 15));

      expect(links, hasLength(2));
      expect(links.first.title, 'Zeta Plan'); // Documents should come before Links alphabetically.
      expect(links.last.title, 'Alpha Site');
      expect(links.first.signedUrl, 'https://signed.example/docs/zeta.pdf');
      expect(repo.signedUrlRequests, contains('docs/zeta.pdf'));
    });

    test('createQuickLink uploads file and returns hydrated record', () async {
      final now = DateTime.utc(2024, 01, 02, 03, 04, 05);
      final repo = _FakeQuickLinksRepository(now: now)..debugOverrideClients(isInitialized: true);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final file = PlatformFile(name: 'Report 2024.pdf', size: bytes.length, bytes: bytes);

      final link = await repo.createQuickLink(
        title: 'Quarterly Report',
        category: 'Documents',
        description: 'Latest internal report',
        externalUrl: 'https://example.com/report',
        iconUrl: ' https://example.com/icon.png ',
        file: file,
        signedUrlTTL: const Duration(minutes: 5),
      );

      expect(repo.lastUploadedBytes, isNotNull);
      expect(repo.lastUploadedBytes, bytes);
      expect(repo.lastUploadedContentType, 'application/pdf');
      expect(repo.lastInsertPayload?['file_name'], 'Report 2024.pdf');
      expect(repo.lastInsertPayload?['url'], 'https://example.com/report');
      final expectedPathPrefix = '${now.toUtc().millisecondsSinceEpoch}-Report_2024.pdf';
      expect(repo.lastUploadedPath, expectedPathPrefix);
      expect(link.storagePath, expectedPathPrefix);
      expect(link.signedUrl, isNotEmpty);
      expect(link.fileSize, bytes.length);
      expect(repo.lastInsertPayload?['icon_url'], 'https://example.com/icon.png');
      expect(link.iconUrl, 'https://example.com/icon.png');
      expect(link.externalUrl, 'https://example.com/report');
    });

    test('createQuickLink falls back to empty url when only a file is provided', () async {
      final now = DateTime.utc(2024, 06, 01, 08, 30);
      final repo = _FakeQuickLinksRepository(now: now)..debugOverrideClients(isInitialized: true);
      final bytes = Uint8List.fromList([9, 8, 7, 6]);
      final file = PlatformFile(name: 'agenda.docx', size: bytes.length, bytes: bytes);

      final link = await repo.createQuickLink(
        title: 'General Meeting Agenda',
        category: 'Documents',
        description: 'Latest agenda draft',
        file: file,
      );

      expect(repo.lastInsertPayload?['url'], isA<String>());
      expect(repo.lastInsertPayload?['url'], isEmpty);
      expect(link.externalUrl, isEmpty);
      expect(link.signedUrl, isNotEmpty);
    });

    test('updateQuickLink replaces stored file and clears metadata when requested', () async {
      final existing = QuickLink(
        id: 'link-1',
        title: 'Field Script',
        category: 'Guides',
        storageBucket: QuickLinksRepository.storageBucket,
        storagePath: 'old/path/script.pdf',
        fileName: 'script.pdf',
        contentType: 'application/pdf',
        fileSize: 1024,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
        description: 'Old script',
        externalUrl: null,
        iconUrl: 'https://example.com/icons/script.png',
      );

      final repo = _FakeQuickLinksRepository(
        initialRows: [
          existing.toJson(),
        ],
      )..debugOverrideClients(isInitialized: true);

      final bytes = Uint8List.fromList(List<int>.generate(8, (index) => index));
      final file = PlatformFile(name: 'New Script.docx', size: bytes.length, bytes: bytes);

      final updated = await repo.updateQuickLink(
        existing,
        file: file,
        signedUrlTTL: const Duration(minutes: 30),
      );

      expect(repo.removeCalled, isTrue);
      expect(repo.lastUpdateId, existing.id);
      expect(repo.lastUpdatePayload?['file_name'], 'New Script.docx');
      expect(repo.lastUpdatePayload?['url'], isA<String>());
      expect(repo.lastUploadedPath, endsWith('New_Script.docx'));
      expect(updated.fileName, 'New Script.docx');
      expect(updated.signedUrl, isNotNull);
    });

    test('updateQuickLink can clear icon URL when empty string is provided', () async {
      final existing = QuickLink(
        id: 'link-3',
        title: 'Volunteer Hub',
        category: 'Links',
        externalUrl: 'https://volunteer.example',
        iconUrl: 'https://example.com/icons/volunteer.png',
      );

      final repo = _FakeQuickLinksRepository(
        initialRows: [existing.toJson()],
      )..debugOverrideClients(isInitialized: true);

      final updated = await repo.updateQuickLink(
        existing,
        iconUrl: '',
      );

      expect(repo.lastUpdatePayload?['icon_url'], isNull);
      expect(updated.iconUrl, isNull);
    });

    test('deleteQuickLink removes storage reference first', () async {
      final link = QuickLink(
        id: 'link-2',
        title: 'Meeting Deck',
        category: 'Meetings',
        storageBucket: QuickLinksRepository.storageBucket,
        storagePath: 'files/deck.pdf',
        fileName: 'deck.pdf',
        contentType: 'application/pdf',
        fileSize: 2048,
        description: 'Slide deck',
        externalUrl: null,
      );

      final repo = _FakeQuickLinksRepository(
        initialRows: [link.toJson()],
      )..debugOverrideClients(isInitialized: true);

      await repo.deleteQuickLink(link);

      expect(repo.removeCalled, isTrue);
      expect(repo.lastDeleteId, link.id);
    });
  });
}
