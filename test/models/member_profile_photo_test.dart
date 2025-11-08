import 'package:bluebubbles/models/crm/member.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await dotenv.testLoad(fileInput: 'SUPABASE_URL=https://example.supabase.co');
  });

  test('parseList normalizes Supabase public_url payloads', () {
    final payload = [
      {
        'public_url':
            'https://example.supabase.co/storage/v1/object/public/member-photos/avatar.png',
        'bucket_id': 'member-photos',
        'name': 'avatar.png',
      },
    ];

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(1));
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/avatar.png',
    );
    expect(photos.first.bucket, 'member-photos');
    expect(photos.first.filename, 'avatar.png');
  });

  test('parseList recovers bucket/name pairs without explicit public_url', () {
    final payload = [
      {
        'bucket_id': 'member-photos',
        'name': 'member-photos/avatars/headshot.png',
      },
    ];

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(1));
    expect(photos.first.bucket, 'member-photos');
    expect(photos.first.filename, 'avatars/headshot.png');
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/avatars/headshot.png',
    );
  });

  test('parseList infers bucket from public_url when bucket is missing', () {
    final payload = [
      {
        'public_url':
            'https://example.supabase.co/storage/v1/object/public/custom-bucket/profile.jpg',
        'file_name': 'profile.jpg',
      },
    ];

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(1));
    expect(photos.first.bucket, 'custom-bucket');
    expect(photos.first.filename, 'profile.jpg');
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/custom-bucket/profile.jpg',
    );
  });

  test('publicUrl ignores rest path in Supabase URL origin', () async {
    await dotenv.testLoad(
      fileInput: 'SUPABASE_URL=https://example.supabase.co/rest/v1',
    );

    final payload = [
      {
        'bucket_id': 'member-photos',
        'name': 'profile.png',
      },
    ];

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(1));
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/profile.png',
    );
  });

  test('parseList unwraps nested data objects from Supabase storage responses', () {
    final payload = {
      'data': [
        {
          'public_url':
              'https://example.supabase.co/storage/v1/object/public/member-photos/nested.png',
          'bucket_id': 'member-photos',
          'name': 'nested.png',
        },
      ],
    };

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(1));
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/nested.png',
    );
    expect(photos.first.filename, 'nested.png');
  });

  test('parseList supports keyed map payloads', () {
    final payload = {
      '1ab98a1f-fd21-410a-929e-847570452693': {
        'bucket_id': 'member-photos',
        'name': '1ab98a1f-fd21-410a-929e-847570452693-instagram.jpeg',
      },
    };

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(1));
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/1ab98a1f-fd21-410a-929e-847570452693-instagram.jpeg',
    );
  });

  test('parseList converts keyed string map entries into photos', () {
    final payload = {
      'instagram': '1ab98a1f-fd21-410a-929e-847570452693-instagram.jpeg',
      'headshot': 'headshots/member.jpeg',
    };

    final photos = MemberProfilePhoto.parseList(payload);

    expect(photos, hasLength(2));
    expect(
      photos.first.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/1ab98a1f-fd21-410a-929e-847570452693-instagram.jpeg',
    );
    expect(
      photos.last.publicUrl,
      'https://example.supabase.co/storage/v1/object/public/member-photos/headshots/member.jpeg',
    );
  });
}
