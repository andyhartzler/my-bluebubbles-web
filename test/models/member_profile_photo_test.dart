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
}
