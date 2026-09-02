import 'package:bluebubbles/utils/quill_html_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A delta op carrying text, optionally with inline attributes.
Map<String, dynamic> _text(String value, [Map<String, dynamic>? attributes]) {
  return attributes == null
      ? <String, dynamic>{'insert': value}
      : <String, dynamic>{'insert': value, 'attributes': attributes};
}

/// The newline op that terminates a line and carries its BLOCK formatting.
/// Quill puts list, blockquote and header on the newline rather than on the
/// text, so a test that attaches them to the text op exercises nothing.
Map<String, dynamic> _newline([Map<String, dynamic>? attributes]) =>
    _text('\n', attributes);

const String _lineStyle = ' style="margin: 0; line-height: 1.6;"';
const String _listStyle = ' style="margin: 0; padding-left: 24px;"';

String _html(List<Map<String, dynamic>> delta) {
  final plainText = delta
      .map((op) => op['insert'])
      .whereType<String>()
      .join();
  return QuillHtmlConverter.generateHtml(delta, plainText);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuillHtmlConverter escaping', () {
    test('text is escaped exactly once', () {
      final html = _html([
        _text('A & B < C > D "E" \'F\''),
        _newline(),
      ]);

      expect(
        html,
        '<div$_lineStyle>A &amp; B &lt; C &gt; D &quot;E&quot; &#39;F&#39;</div>',
      );
      // Double escaping would turn the ampersand of each entity into &amp;.
      expect(html, isNot(contains('&amp;amp;')));
      expect(html, isNot(contains('&amp;lt;')));
      expect(html, isNot(contains('&amp;quot;')));
    });

    test('escaping runs once on text that also carries a link', () {
      final html = _html([
        _text('Tom & Jerry', {'link': 'https://example.org/a?x=1&y=2'}),
        _newline(),
      ]);

      // Anchor text takes the TEXT escape and the href takes the ATTRIBUTE
      // escape, so the ampersand is entity-encoded in both, once each.
      expect(
        html,
        '<div$_lineStyle>'
        '<a href="https://example.org/a?x=1&amp;y=2">Tom &amp; Jerry</a>'
        '</div>',
      );
      expect(html, isNot(contains('&amp;amp;')));
    });
  });

  group('QuillHtmlConverter block grouping', () {
    test('consecutive bullet items group into one ul', () {
      final html = _html([
        _text('Alpha'),
        _newline({'list': 'bullet'}),
        _text('Beta'),
        _newline({'list': 'bullet'}),
        _text('Gamma'),
        _newline({'list': 'bullet'}),
        _text('After'),
        _newline(),
      ]);

      expect(
        html,
        '<ul$_listStyle>'
        '<li$_lineStyle>Alpha</li>'
        '<li$_lineStyle>Beta</li>'
        '<li$_lineStyle>Gamma</li>'
        '</ul>'
        '<div$_lineStyle>After</div>',
      );
      // One container for three items, not three one-item lists.
      expect('<ul'.allMatches(html).length, 1);
      expect('<li'.allMatches(html).length, 3);
    });

    test('a plain line between bullets splits them into two lists', () {
      final html = _html([
        _text('Alpha'),
        _newline({'list': 'bullet'}),
        _text('Interruption'),
        _newline(),
        _text('Beta'),
        _newline({'list': 'bullet'}),
      ]);

      expect('<ul'.allMatches(html).length, 2);
      expect('<li'.allMatches(html).length, 2);
    });

    test('ordered list items produce a single ol', () {
      final html = _html([
        _text('First'),
        _newline({'list': 'ordered'}),
        _text('Second'),
        _newline({'list': 'ordered'}),
      ]);

      expect(
        html,
        '<ol$_listStyle>'
        '<li$_lineStyle>First</li>'
        '<li$_lineStyle>Second</li>'
        '</ol>',
      );
      expect(html, isNot(contains('<ul')));
    });

    test('blockquote renders as a blockquote wrapping its lines', () {
      final html = _html([
        _text('Quoted line'),
        _newline({'blockquote': true}),
      ]);

      expect(html, startsWith('<blockquote style="margin: 0 0 0 8px;'));
      expect(html, contains('border-left: 3px solid #cccccc;'));
      expect(html, contains('<div$_lineStyle>Quoted line</div>'));
      expect(html, endsWith('</blockquote>'));
      expect('<blockquote'.allMatches(html).length, 1);
    });
  });

  group('QuillHtmlConverter inline styles', () {
    test('strikethrough renders as s', () {
      final html = _html([
        _text('gone', {'strike': true}),
        _newline(),
      ]);

      expect(html, '<div$_lineStyle><s>gone</s></div>');
    });

    test('bold, italic and underline nest around strikethrough', () {
      final html = _html([
        _text('all', {
          'bold': true,
          'italic': true,
          'underline': true,
          'strike': true,
        }),
        _newline(),
      ]);

      expect(html, contains('<s>'));
      expect(html, contains('<strong>'));
      expect(html, contains('<em>'));
      expect(html, contains('<u>'));
      expect(html, contains('all'));
    });
  });

  group('QuillHtmlConverter link scheme allowlist', () {
    test('a javascript: link is stripped to plain text', () {
      final html = _html([
        _text('click me', {'link': 'javascript:alert(1)'}),
        _newline(),
      ]);

      expect(html, '<div$_lineStyle>click me</div>');
      expect(html, isNot(contains('<a ')));
      expect(html, isNot(contains('javascript')));
    });

    test('a javascript: link split by a control character is still stripped',
        () {
      // Browsers strip whitespace and control characters before resolving a
      // URL, so this reaches the parser as javascript: and must not walk past
      // the allowlist.
      final html = _html([
        _text('click me', {'link': 'java\tscript:alert(1)'}),
        _newline(),
      ]);

      expect(html, '<div$_lineStyle>click me</div>');
      expect(html, isNot(contains('<a ')));
    });

    test('a data: link is stripped to plain text', () {
      final html = _html([
        _text('open', {'link': 'data:text/html;base64,PHNjcmlwdD4='}),
        _newline(),
      ]);

      expect(html, '<div$_lineStyle>open</div>');
      expect(html, isNot(contains('<a ')));
      expect(html, isNot(contains('base64')));
    });

    test('a scheme-relative link is stripped to plain text', () {
      final html = _html([
        _text('elsewhere', {'link': '//evil.example/path'}),
        _newline(),
      ]);

      expect(html, '<div$_lineStyle>elsewhere</div>');
      expect(html, isNot(contains('<a ')));
    });

    test('https, mailto and tel links survive', () {
      final html = _html([
        _text('site', {'link': 'https://example.org/page'}),
        _text(' '),
        _text('write', {'link': 'mailto:info@example.org'}),
        _text(' '),
        _text('call', {'link': 'tel:+15555550123'}),
        _newline(),
      ]);

      expect(html, contains('<a href="https://example.org/page">site</a>'));
      expect(html, contains('<a href="mailto:info@example.org">write</a>'));
      expect(html, contains('<a href="tel:+15555550123">call</a>'));
      expect('<a href='.allMatches(html).length, 3);
    });

    test('an image embed with a rejected scheme is dropped entirely', () {
      final html = QuillHtmlConverter.generateHtml(
        [
          <String, dynamic>{
            'insert': <String, dynamic>{'image': 'javascript:alert(1)'},
          },
          _newline(),
        ],
        '',
      );

      // An embed has no visible text to fall back to, so nothing is emitted
      // for it rather than a src the client would fetch.
      expect(html, isNot(contains('<img')));
      expect(html, isNot(contains('javascript')));
    });

    test('an https image embed survives', () {
      final html = QuillHtmlConverter.generateHtml(
        [
          <String, dynamic>{
            'insert': <String, dynamic>{'image': 'https://example.org/a.png'},
          },
          _newline(),
        ],
        '',
      );

      expect(html, contains('<img src="https://example.org/a.png" />'));
    });
  });

  group('QuillHtmlConverter plain text', () {
    test('a link target is preserved beside its anchor text', () {
      final text = QuillHtmlConverter.generatePlainText([
        _text('our site', {'link': 'https://example.org'}),
        _newline(),
      ]);

      expect(text, 'our site (https://example.org)\n');
    });

    test('an anchor whose text is its own url is written once', () {
      final text = QuillHtmlConverter.generatePlainText([
        _text('https://example.org', {'link': 'https://example.org'}),
        _newline(),
      ]);

      expect(text, 'https://example.org\n');
    });

    test('a rejected scheme drops the target and keeps the visible text', () {
      final text = QuillHtmlConverter.generatePlainText([
        _text('click me', {'link': 'javascript:alert(1)'}),
        _newline(),
      ]);

      // The two alternatives cannot disagree about what a message points at.
      expect(text, 'click me\n');
      expect(text, isNot(contains('javascript')));
    });

    test('plain text carries no html entities', () {
      final text = QuillHtmlConverter.generatePlainText([
        _text('A & B < C'),
        _newline(),
      ]);

      expect(text, 'A & B < C\n');
      expect(text, isNot(contains('&amp;')));
    });

    test('a link is closed before the newline that follows it', () {
      final text = QuillHtmlConverter.generatePlainText([
        _text('first', {'link': 'https://example.org/one'}),
        _newline(),
        _text('second'),
        _newline(),
      ]);

      expect(text, 'first (https://example.org/one)\nsecond\n');
    });
  });

  group('QuillHtmlConverter empty content', () {
    test('a whitespace-only document produces no html', () {
      expect(QuillHtmlConverter.generateHtml([_text('   \n')], '   \n'), '');
    });
  });
}
