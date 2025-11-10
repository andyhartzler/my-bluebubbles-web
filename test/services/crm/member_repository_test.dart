import 'package:flutter_test/flutter_test.dart';

import 'package:bluebubbles/models/crm/member.dart';

void main() {
  group('MemberRepository county normalization', () {
    test('Jackson variants collapse into a single county option', () {
      final response = [
        {'county': 'Jackson'},
        {'county': 'Jackson County'},
        {'county': '  jackson county  '},
      ];

      final counties = (response as List<dynamic>)
          .map((item) => Member.normalizeCountyLabel(item['county']))
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      expect(counties, equals(['Jackson']));
    });
  });
}
