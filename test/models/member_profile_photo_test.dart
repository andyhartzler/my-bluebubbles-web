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
  });
}
