import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bluebubbles/services/crm/storage_uri_resolver.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: 'SUPABASE_URL=https://example.supabase.co');
  });

  tearDown(() {
    dotenv.clean();
  });

  test('relative storage path resolves to https link', () async {
    final uri = await CRMStorageUriResolver.resolve(
      'storage/v1/object/public/transcripts/sample.pdf',
    );

    expect(uri, isNotNull);
    expect(uri!.toString(),
        'https://example.supabase.co/storage/v1/object/public/transcripts/sample.pdf');
  });
}
