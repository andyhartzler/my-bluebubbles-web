import '../models/email_component.dart';
import '../models/email_document.dart';

class HtmlExporter {
  String export(EmailDocument document) {
    final settings = document.settings;

    return '''
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="x-apple-disable-message-reformatting">
  <meta name="format-detection" content="telephone=no,address=no,email=no,date=no">
  <!--[if mso]>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <![endif]-->
  <title>Missouri Young Democrats</title>
  <style type="text/css">
    /* Reset styles */
    body {
      margin: 0;
      padding: 0;
      -webkit-text-size-adjust: 100%;
      -ms-text-size-adjust: 100%;
      font-family: ${settings.fontFamily}, Arial, sans-serif;
      font-size: ${settings.fontSize}px;
      line-height: ${settings.lineHeight};
      color: ${settings.textColor};
      background-color: ${settings.backgroundColor};
    }

    table {
      border-collapse: collapse;
      border-spacing: 0;
      mso-table-lspace: 0pt;
      mso-table-rspace: 0pt;
    }

    img {
      border: 0;
      height: auto;
      line-height: 100%;
      outline: none;
      text-decoration: none;
      -ms-interpolation-mode: bicubic;
      max-width: 100%;
      display: block;
    }

    p {
      margin: 0;
    }

    /* Prevent Gmail from changing text color */
    a {
      color: inherit;
      text-decoration: underline;
    }

    /* iOS blue links */
    a[x-apple-data-detectors] {
      color: inherit !important;
      text-decoration: none !important;
      font-size: inherit !important;
      font-family: inherit !important;
      font-weight: inherit !important;
      line-height: inherit !important;
    }

    /* Mobile styles */
    @media only screen and (max-width: 600px) {
      .mobile-full-width {
        width: 100% !important;
        max-width: 100% !important;
      }

      .mobile-padding {
        padding: 10px !important;
      }

      .mobile-hide {
        display: none !important;
        max-height: 0 !important;
        overflow: hidden !important;
        visibility: hidden !important;
      }

      .mobile-stack {
        display: block !important;
        width: 100% !important;
      }

      .mobile-text-center {
        text-align: center !important;
      }

      .mobile-text-left {
        text-align: left !important;
      }

      .mobile-font-size-16 {
        font-size: 16px !important;
      }
    }

    /* Outlook-specific fixes */
    <!--[if mso]>
    table {
      border-collapse: collapse;
    }
    <![endif]-->
  </style>
</head>
<body style="margin: 0; padding: 0; background-color: ${settings.backgroundColor};">
  <!-- Preheader text (hidden from view) -->
  <div style="display: none; max-height: 0px; overflow: hidden;">
    Missouri Young Democrats - Stay informed and get involved!
  </div>

  <!-- Main email container -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: ${settings.backgroundColor};">
    <tr>
      <td align="center" style="padding: ${settings.padding}px;">
        <!--[if mso]>
        <table role="presentation" width="${settings.maxWidth}" cellpadding="0" cellspacing="0" border="0">
        <tr>
        <td>
        <![endif]-->
        <table role="presentation" class="mobile-full-width" width="${settings.maxWidth}" cellpadding="0" cellspacing="0" border="0" style="max-width: ${settings.maxWidth}px; margin: 0 auto;">
          ${_exportSections(document.sections)}
        </table>
        <!--[if mso]>
        </td>
        </tr>
        </table>
        <![endif]-->
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
    // Process merge tags
    final processedContent = _processMergeTags(content);

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
  $processedContent
</p>
''';
  }

  /// Convert merge tags from {{tag}} format to email service format
  /// Currently supports Mailchimp-style *|TAG|* format
  String _processMergeTags(String content) {
    // Replace {{tag_name}} with *|TAG_NAME|* (Mailchimp format)
    final mergeTagPattern = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');

    return content.replaceAllMapped(mergeTagPattern, (match) {
      final tagName = match.group(1)!.toUpperCase();
      return '*|$tagName|*';
    });
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
