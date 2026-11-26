import 'package:flutter_test/flutter_test.dart';

import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_hub.dart';

Chapter _chapter(String name, String school, String type) => Chapter(
      id: name,
      chapterName: name,
      standardizedName: name,
      schoolName: school,
      chapterType: type,
    );

void main() {
  group('ChapterHubKeys.school', () {
    test('groups misspellings of one high school', () {
      final keys = {
        ChapterHubKeys.school(_chapter('Ladue Young Dems', 'Ladue Horton Watkins High School', 'highschool')),
        ChapterHubKeys.school(_chapter('Ladue Young Dems ', 'Ladue Horton Walkins High School', 'highschool')),
        ChapterHubKeys.school(_chapter('Young Democrats Club', 'Ladue Horton Watkins High Schol', 'highschool')),
        ChapterHubKeys.school(_chapter('I don’t know', 'Ladue Horton Watkins', 'highschool')),
      };
      expect(keys, hasLength(1));
    });

    test('a pending row and a chartered chapter at the same college match', () {
      expect(
        ChapterHubKeys.school(_chapter('Mizzou College Democrats', 'University of Missouri-Columbia', 'college')),
        ChapterHubKeys.school(_chapter('University of Missouri Democrats', 'University of Missouri-Columbia', 'college')),
      );
    });

    test('different colleges stay apart', () {
      expect(
        ChapterHubKeys.school(_chapter('Missouri State College Democrats', 'Missouri State University', 'college')),
        isNot(ChapterHubKeys.school(_chapter('University of Missouri Democrats', 'University of Missouri-Columbia', 'college'))),
      );
      expect(
        ChapterHubKeys.school(_chapter('College Democrats at Truman State University', 'Truman State University', 'college')),
        isNot(ChapterHubKeys.school(_chapter('mwsu', 'mwsu', 'college'))),
      );
    });

    test('schools that share a city or system name stay apart', () {
      final mu = ChapterHubKeys.school(_chapter('University of Missouri Democrats', 'University of Missouri-Columbia', 'college'));
      final columbiaCollege = ChapterHubKeys.school(_chapter('Columbia College Democrats', 'Columbia College', 'college'));
      final umsl = ChapterHubKeys.school(_chapter('UMSL College Democrats', 'University of Missouri-St. Louis', 'college'));
      final stlcc = ChapterHubKeys.school(_chapter('STLCC Democrats', 'St. Louis Community College', 'college'));
      final umkc = ChapterHubKeys.school(_chapter('UMKC Democrats', 'University of Missouri-Kansas City', 'college'));
      expect({mu, columbiaCollege, umsl, stlcc, umkc}, hasLength(5));
    });

    test('a county chapter and a high school row in that county land together', () {
      expect(
        ChapterHubKeys.school(_chapter('Lafayette County Young Democrats ', 'Lafayette County C-1 High School ', 'highschool')),
        ChapterHubKeys.school(_chapter('Lafayette County Young Democrats', 'Lafayette County Young Democrats', 'county')),
      );
    });
  });

  test('the live chapter list sorts into one group per school', () {
    // Names and schools as they stand in the chapters table on Nov 26, 2026.
    final rows = <List<String>>[
      ['Missouri State College Democrats', 'Missouri State University', 'college'],
      ['College Democrats at Truman State University', 'Truman State University', 'college'],
      ['University of Missouri Democrats', 'University of Missouri-Columbia', 'college'],
      ['Washington University in St. Louis College Democrats', 'Washington University in St. Louis', 'college'],
      ['NKCHS Young Progressives', 'North Kansas City High School', 'highschool'],
      ['mwsu', 'mwsu', 'college'],
      ['Mizzou College Democrats', 'University of Missouri-Columbia', 'college'],
      ['UMSL does not offer a young democrats chapter.', 'University of Missouri-St.Louis', 'college'],
      ['Lafayette County Young Democrats', 'Lafayette County Young Democrats', 'county'],
      ['KC HSDA', 'Central High School', 'highschool'],
      ['Ladue Young Dems ', 'Ladue Horton Walkins High School', 'highschool'],
      ['I don’t know', 'Ladue Horton Watkins', 'highschool'],
      ['Young Democrats Club', 'Ladue Horton Watkins High Schol', 'highschool'],
      ['The name of the Chapter is Ladue Young Democrats.', 'Ladue Horton Watkins High School', 'highschool'],
      ['Ladue Young Dems', 'Ladue Horton Watkins High School', 'highschool'],
      ['The High School Democrats of Ladue', 'Ladue Horton Watkins High School', 'highschool'],
      ['Ladue Horton Watkins Young Democrats', 'Ladue Horton Watkins High School', 'highschool'],
      ["We haven't started.", 'Ladue Horton Watkins High School', 'highschool'],
      ['Ladue', 'Ladue Horton Watkins High School', 'highschool'],
      ['Young Democrats', 'Ladue Horton Watkins High School', 'highschool'],
      ['Young Democrats club?', 'Ladue Horton Watkins High School', 'highschool'],
      ['Lafayette County Young Democrats ', 'Lafayette County C-1 High School ', 'highschool'],
      ['Nixa High School Democrats', 'Nixa High School', 'highschool'],
      ['Parkway North Civics Club', 'Parkway North High School', 'highschool'],
    ];
    final groups = <String, int>{};
    for (final r in rows) {
      final key = ChapterHubKeys.school(_chapter(r[0], r[1], r[2]));
      groups[key] = (groups[key] ?? 0) + 1;
    }
    // 5 chartered schools + mwsu, UMSL, Lafayette, Central, Ladue, Nixa,
    // Parkway (Mizzou joins the chartered MU group).
    expect(groups, hasLength(12));
    expect(groups.values.reduce((a, b) => a > b ? a : b), 11); // Ladue
  });

  group('ChapterHubKeys.looksLikeAnswer', () {
    test('flags answers typed into the chapter name field', () {
      for (final value in [
        'I don’t know',
        "We haven't started.",
        'Young Democrats club?',
        'UMSL does not offer a young democrats chapter.',
        'The name of the Chapter is Ladue Young Democrats.',
        'na',
      ]) {
        expect(ChapterHubKeys.looksLikeAnswer(value), isTrue, reason: value);
      }
    });

    test('leaves real chapter names alone', () {
      for (final value in [
        'Ladue Young Dems',
        'NKCHS Young Progressives',
        'Lafayette County Young Democrats',
        'Parkway North Civics Club',
        'KC HSDA',
        'mwsu',
      ]) {
        expect(ChapterHubKeys.looksLikeAnswer(value), isFalse, reason: value);
      }
    });
  });

  test('names match regardless of case and spacing', () {
    expect(ChapterHubKeys.name('Ladue Young Dems '), ChapterHubKeys.name('ladue  young dems'));
  });
}
