import 'package:bluebubbles/models/crm/member.dart';
import 'package:test/test.dart';

void main() {
  group('MemberProfilePhoto publicUrl normalization', () {
    test('removes duplicate bucket segments from stored paths', () {
      final variations = <String>[
        'profile.jpg',
        'member-photos/profile.jpg',
        'public/member-photos/profile.jpg',
        'storage/v1/object/member-photos/profile.jpg',
        'storage/v1/object/public/member-photos/profile.jpg',
        '/member-photos/profile.jpg',
        '/storage/v1/object/public/member-photos/profile.jpg',
      ];

      String? expected;
      for (final path in variations) {
        final photo = MemberProfilePhoto(path: path, bucket: 'member-photos');
        final normalized = photo.publicUrl;
        expect(normalized, isNotNull);
        expected ??= normalized;
        expect(normalized, expected);
      }

      expect(
        expected,
        'storage/v1/object/public/member-photos/profile.jpg',
      );
    });

    test('normalizes using default bucket when not provided', () {
      final withBucket = MemberProfilePhoto(
        path: 'storage/v1/object/public/member-photos/profile.jpg',
      );
      final withoutBucket = MemberProfilePhoto(path: 'member-photos/profile.jpg');

      expect(withBucket.publicUrl, withoutBucket.publicUrl);
      expect(
        withBucket.publicUrl,
        'storage/v1/object/public/member-photos/profile.jpg',
      );
    });
  });
}
