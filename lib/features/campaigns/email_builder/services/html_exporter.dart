import '../models/email_component.dart';
import '../models/email_document.dart';

class HtmlExporter {
  String export(EmailDocument document) {
    final settings = document.settings;

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <style>
    body {
      margin: 0;
      padding: 0;
      font-family: ${settings.fontFamily};
      font-size: ${settings.fontSize}px;
      line-height: ${settings.lineHeight}px;
      color: ${settings.textColor};
      background-color: ${settings.backgroundColor};
    }
    table {
      border-collapse: collapse;
      width: 100%;
    }
    img {
      max-width: 100%;
      height: auto;
      display: block;
    }
  </style>
</head>
<body>
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr>
      <td align="center" style="padding: ${settings.padding}px;">
        <table width="${settings.maxWidth}" cellpadding="0" cellspacing="0">
          ${_exportSections(document.sections)}
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  String _exportSections(List<EmailSection> sections) {
    return sections.map(_exportSection).join('\n');
  }

  String _exportSection(EmailSection section) {
    final style = section.style;
    return '''
<tr>
  <td style="background-color: ${style.backgroundColor}; padding: ${style.paddingTop}px ${style.paddingRight}px ${style.paddingBottom}px ${style.paddingLeft}px;">
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        ${_exportColumns(section.columns)}
      </tr>
    </table>
  </td>
</tr>
''';
  }

  String _exportColumns(List<EmailColumn> columns) {
    final totalFlex = columns.fold(0, (sum, col) => sum + col.flex);
    return columns.map((column) {
      final widthPercent = (column.flex / totalFlex * 100).toStringAsFixed(0);
      return _exportColumn(column, widthPercent);
    }).join('\n');
  }

  String _exportColumn(EmailColumn column, String widthPercent) {
    final style = column.style;
    return '''
<td width="$widthPercent%" valign="top" style="background-color: ${style.backgroundColor}; padding: ${style.padding}px;">
  ${_exportComponents(column.components)}
</td>
''';
  }

  String _exportComponents(List<EmailComponent> components) {
    return components.map(_exportComponent).join('\n');
  }

  String _exportComponent(EmailComponent component) {
    return component.when(
      text: (id, content, style) => _exportTextComponent(content, style),
      image: (id, url, alt, link, style) =>
          _exportImageComponent(url, alt, link, style),
      button: (id, text, url, style) =>
          _exportButtonComponent(text, url, style),
      divider: (id, style) => _exportDividerComponent(style),
      spacer: (id, height) => _exportSpacerComponent(height),
      social: (id, links, style) => _exportSocialComponent(links, style),
    );
  }

  String _exportTextComponent(String content, TextComponentStyle style) {
    return '''
<p style="
  font-size: ${style.fontSize}px;
  color: ${style.color};
  text-align: ${style.alignment};
  font-weight: ${style.bold ? 'bold' : 'normal'};
  font-style: ${style.italic ? 'italic' : 'normal'};
  text-decoration: ${style.underline ? 'underline' : 'none'};
  line-height: ${style.lineHeight};
  margin-top: ${style.paddingTop}px;
  margin-bottom: ${style.paddingBottom}px;
">
  $content
</p>
''';
  }

  String _exportImageComponent(
    String url,
    String? alt,
    String? link,
    ImageComponentStyle style,
  ) {
    final img =
        '<img src="$url" alt="${alt ?? ''}" style="width: ${style.width}; border-radius: ${style.borderRadius}px; display: block;">';

    if (link != null && link.isNotEmpty) {
      return '''
<div style="text-align: ${style.alignment}; margin-top: ${style.paddingTop}px; margin-bottom: ${style.paddingBottom}px;">
  <a href="$link">$img</a>
</div>
''';
    }

    return '''
<div style="text-align: ${style.alignment}; margin-top: ${style.paddingTop}px; margin-bottom: ${style.paddingBottom}px;">
  $img
</div>
''';
  }

  String _exportButtonComponent(
      String text, String url, ButtonComponentStyle style) {
    return '''
<div style="text-align: ${style.alignment}; margin-top: ${style.marginTop}px; margin-bottom: ${style.marginBottom}px;">
  <a href="$url" style="
    display: inline-block;
    background-color: ${style.backgroundColor};
    color: ${style.textColor};
    font-size: ${style.fontSize}px;
    font-weight: ${style.bold ? 'bold' : 'normal'};
    padding: ${style.paddingVertical}px ${style.paddingHorizontal}px;
    border-radius: ${style.borderRadius}px;
    text-decoration: none;
  ">
    $text
  </a>
</div>
''';
  }

  String _exportDividerComponent(DividerComponentStyle style) {
    return '''
<hr style="
  border: none;
  border-top: ${style.thickness}px ${style.style} ${style.color};
  margin-top: ${style.marginTop}px;
  margin-bottom: ${style.marginBottom}px;
">
''';
  }

  String _exportSpacerComponent(double height) {
    return '<div style="height: ${height}px;"></div>';
  }

  String _exportSocialComponent(
    List<SocialLink> links,
    SocialComponentStyle style,
  ) {
    final icons = links.map((link) {
      return '<a href="${link.url}" style="margin-right: ${style.spacing}px;">${link.platform}</a>';
    }).join();

    return '''
<div style="text-align: ${style.alignment}; margin-top: ${style.marginTop}px; margin-bottom: ${style.marginBottom}px;">
  $icons
</div>
''';
  }
}
