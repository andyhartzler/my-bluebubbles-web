import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'email_component.dart';

part 'email_document.freezed.dart';
part 'email_document.g.dart';

const _uuid = Uuid();

@freezed
class EmailDocument with _$EmailDocument {
  const factory EmailDocument({
    @Default([]) List<EmailSection> sections,
    @Default(EmailSettings()) EmailSettings settings,
    @Default({}) Map<String, dynamic> theme,
    DateTime? lastModified,
  }) = _EmailDocument;

  factory EmailDocument.empty() {
    return EmailDocument(
      sections: const [],
      settings: const EmailSettings(),
      theme: const {},
      lastModified: DateTime.now(),
    );
  }

  factory EmailDocument.fromJson(Map<String, dynamic> json) =>
      _$EmailDocumentFromJson(json);
}

@freezed
class EmailSettings with _$EmailSettings {
  const factory EmailSettings({
    @Default(600) int maxWidth,
    @Default('#ffffff') String backgroundColor,
    @Default('#000000') String textColor,
    @Default('Arial, sans-serif') String fontFamily,
    @Default(16) int fontSize,
    @Default(24) int lineHeight,
    @Default(20) int padding,
  }) = _EmailSettings;

  factory EmailSettings.fromJson(Map<String, dynamic> json) =>
      _$EmailSettingsFromJson(json);
}

@freezed
class EmailSection with _$EmailSection {
  const factory EmailSection({
    required String id,
    @Default([]) List<EmailColumn> columns,
    @Default(SectionStyle()) SectionStyle style,
  }) = _EmailSection;

  factory EmailSection.fromJson(Map<String, dynamic> json) =>
      _$EmailSectionFromJson(json);
}

@freezed
class SectionStyle with _$SectionStyle {
  const factory SectionStyle({
    @Default('#ffffff') String backgroundColor,
    @Default(20) double paddingTop,
    @Default(20) double paddingBottom,
    @Default(20) double paddingLeft,
    @Default(20) double paddingRight,
    String? backgroundImage,
    @Default('cover') String backgroundSize,
  }) = _SectionStyle;

  factory SectionStyle.fromJson(Map<String, dynamic> json) =>
      _$SectionStyleFromJson(json);
}

class EmailBlock {
  final String id;
  final EmailBlockType type;
  final Map<String, dynamic> props;
  final List<EmailBlock> children;

  EmailBlock({
    String? id,
    required this.type,
    Map<String, dynamic>? props,
    List<EmailBlock>? children,
  })  : id = id ?? _uuid.v4(),
        props = props ?? <String, dynamic>{},
        children = children ?? <EmailBlock>[];

  factory EmailBlock.container({
    String? id,
    List<EmailBlock>? children,
    ContainerBlockStyle? style,
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.container,
      props: (style ?? const ContainerBlockStyle()).toJson(),
      children: children ?? const [],
    );
  }

  factory EmailBlock.text({
    String? id,
    required String content,
    TextBlockStyle style = const TextBlockStyle(),
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.text,
      props: {
        'content': content,
        ...style.toJson(),
      },
    );
  }

  factory EmailBlock.image({
    String? id,
    required String src,
    ImageBlockStyle style = const ImageBlockStyle(),
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.image,
      props: {
        'src': src,
        ...style.toJson(),
      },
    );
  }

  factory EmailBlock.button({
    String? id,
    required String text,
    required String href,
    ButtonBlockStyle style = const ButtonBlockStyle(),
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.button,
      props: {
        'text': text,
        'href': href,
        ...style.toJson(),
      },
    );
  }

  factory EmailBlock.divider({
    String? id,
    DividerBlockStyle style = const DividerBlockStyle(),
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.divider,
      props: style.toJson(),
    );
  }

  factory EmailBlock.spacer({
    String? id,
    double height = 40,
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.spacer,
      props: {'height': height},
    );
  }

  factory EmailBlock.columns({
    String? id,
    required List<EmailBlock> columns,
    ColumnsBlockStyle style = const ColumnsBlockStyle(),
  }) {
    return EmailBlock(
      id: id,
      type: EmailBlockType.columns,
      props: style.toJson(),
      children: columns,
    );
  }

  factory EmailBlock.fromJson(Map<String, dynamic> json) {
    final type = EmailBlockType.values.firstWhere(
      (value) => value.name == (json['type'] as String? ?? 'container'),
      orElse: () => EmailBlockType.container,
    );

    return EmailBlock(
      id: json['id'] as String?,
      type: type,
      props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
      children: (json['children'] as List<dynamic>? ?? [])
          .map((child) => EmailBlock.fromJson(child as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'props': props,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }

  String toHtml(EmailStyles styles) {
    switch (type) {
      case EmailBlockType.container:
        return _containerToHtml(styles);
      case EmailBlockType.text:
        return _textToHtml(styles);
      case EmailBlockType.image:
        return _imageToHtml(styles);
      case EmailBlockType.button:
        return _buttonToHtml(styles);
      case EmailBlockType.divider:
        return _dividerToHtml();
      case EmailBlockType.spacer:
        return _spacerToHtml();
      case EmailBlockType.columns:
        return _columnsToHtml(styles);
    }
  }

  String _containerToHtml(EmailStyles styles) {
    final style = ContainerBlockStyle.fromJson(props);
    final childrenHtml = children.map((child) => child.toHtml(styles)).join('\n');
    final border = style.borderWidth > 0 && style.borderColor != null
        ? 'border: ${style.borderWidth}px solid ${style.borderColor};'
        : '';

    return '''
<tr>
  <td style="${style.padding.toCssPadding()}; background-color: ${style.backgroundColor}; border-radius: ${style.borderRadius}px; $border">
    <table border="0" cellpadding="0" cellspacing="0" width="100%" role="presentation">
      $childrenHtml
    </table>
  </td>
</tr>
''';
  }

  String _textToHtml(EmailStyles styles) {
    final textStyle = TextBlockStyle.fromJson(props);
    final processedContent = textStyle.processContent(props['content'] as String? ?? '');

    return '''
<tr>
  <td style="${textStyle.padding.toCssPadding()};">
    <p style="margin: 0; font-size: ${textStyle.fontSize}px; color: ${textStyle.color}; text-align: ${textStyle.alignment}; font-weight: ${textStyle.bold ? 'bold' : 'normal'}; font-style: ${textStyle.italic ? 'italic' : 'normal'}; text-decoration: ${textStyle.underline ? 'underline' : 'none'}; line-height: ${textStyle.lineHeight}; font-family: ${textStyle.fontFamily ?? styles.fontFamily};">
      $processedContent
    </p>
  </td>
</tr>
''';
  }

  String _imageToHtml(EmailStyles styles) {
    final imageStyle = ImageBlockStyle.fromJson(props);
    final src = props['src'] as String? ?? '';
    final borderRadius = imageStyle.borderRadius;
    final alignment = imageStyle.alignment;

    return '''
<tr>
  <td style="${imageStyle.padding.toCssPadding()}; text-align: $alignment;">
    <img src="$src" alt="${imageStyle.alt ?? ''}" class="responsive-img" style="display: block; width: ${imageStyle.width}; ${imageStyle.height != null ? 'height: ${imageStyle.height};' : ''} border-radius: ${borderRadius}px;" />
  </td>
</tr>
''';
  }

  String _buttonToHtml(EmailStyles styles) {
    final buttonStyle = ButtonBlockStyle.fromJson(props);
    final href = props['href'] as String? ?? '#';
    final text = props['text'] as String? ?? '';
    final border = buttonStyle.borderColor.isNotEmpty
        ? 'border: 1px solid ${buttonStyle.borderColor};'
        : 'border: none;';

    return '''
<tr>
  <td style="${buttonStyle.padding.toCssPadding()}; text-align: ${buttonStyle.alignment};">
    <a href="$href" style="display: inline-block; text-decoration: none; background-color: ${buttonStyle.backgroundColor}; color: ${buttonStyle.textColor}; font-size: ${buttonStyle.fontSize}px; font-weight: ${buttonStyle.bold ? 'bold' : 'normal'}; border-radius: ${buttonStyle.borderRadius}px; ${border} padding: ${buttonStyle.buttonPadding.toCssPaddingValue()}; width: ${buttonStyle.width}; text-align: center;">
      $text
    </a>
  </td>
</tr>
''';
  }

  String _dividerToHtml() {
    final dividerStyle = DividerBlockStyle.fromJson(props);
    return '''
<tr>
  <td style="${dividerStyle.padding.toCssPadding()};">
    <hr style="border: none; border-top: ${dividerStyle.thickness}px ${dividerStyle.lineStyle} ${dividerStyle.color}; margin: 0;" />
  </td>
</tr>
''';
  }

  String _spacerToHtml() {
    final height = (props['height'] as num?)?.toDouble() ?? 16;
    return '''
<tr>
  <td style="height: ${height}px; line-height: ${height}px;">&nbsp;</td>
</tr>
''';
  }

  String _columnsToHtml(EmailStyles styles) {
    final columnStyle = ColumnsBlockStyle.fromJson(props);
    final columnCount = children.isEmpty ? 1 : children.length;
    final widths = columnStyle.columnPercents(columnCount);

    final columnsHtml = List.generate(children.length, (index) {
      final child = children[index];
      final width = widths[index];
      return '''
<td class="stack-column" width="$width%" valign="top" style="padding-right: ${index < children.length - 1 ? columnStyle.gap / 2 : 0}px; padding-left: ${index > 0 ? columnStyle.gap / 2 : 0}px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">${child.toHtml(styles)}</table>
</td>''';
    }).join('\n');

    return '''
<tr>
  <td style="${columnStyle.padding.toCssPadding()};">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        $columnsHtml
      </tr>
    </table>
  </td>
</tr>
''';
  }
}

enum EmailBlockType {
  container,
  text,
  image,
  button,
  divider,
  spacer,
  columns,
}

class EmailMetadata {
  final String subject;
  final String preheader;
  final String fromName;
  final String fromEmail;

  const EmailMetadata({
    this.subject = '',
    this.preheader = '',
    this.fromName = 'Missouri Young Democrats',
    this.fromEmail = 'info@moyoungdemocrats.org',
  });

  factory EmailMetadata.empty() => const EmailMetadata();

  factory EmailMetadata.fromJson(Map<String, dynamic> json) {
    return EmailMetadata(
      subject: json['subject'] as String? ?? '',
      preheader: json['preheader'] as String? ?? '',
      fromName: json['fromName'] as String? ?? 'Missouri Young Democrats',
      fromEmail: json['fromEmail'] as String? ?? 'info@moyoungdemocrats.org',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'preheader': preheader,
      'fromName': fromName,
      'fromEmail': fromEmail,
    };
  }

  EmailMetadata copyWith({
    String? subject,
    String? preheader,
    String? fromName,
    String? fromEmail,
  }) {
    return EmailMetadata(
      subject: subject ?? this.subject,
      preheader: preheader ?? this.preheader,
      fromName: fromName ?? this.fromName,
      fromEmail: fromEmail ?? this.fromEmail,
    );
  }
}

class EmailStyles {
  final String backgroundColor;
  final String contentWidth;
  final String fontFamily;
  final String textColor;
  final String linkColor;

  const EmailStyles({
    this.backgroundColor = '#f4f4f4',
    this.contentWidth = '600px',
    this.fontFamily = 'Arial, sans-serif',
    this.textColor = '#333333',
    this.linkColor = '#1E3A8A',
  });

  factory EmailStyles.defaultStyles() => const EmailStyles();

  factory EmailStyles.fromJson(Map<String, dynamic> json) {
    return EmailStyles(
      backgroundColor: json['backgroundColor'] as String? ?? '#f4f4f4',
      contentWidth: json['contentWidth'] as String? ?? '600px',
      fontFamily: json['fontFamily'] as String? ?? 'Arial, sans-serif',
      textColor: json['textColor'] as String? ?? '#333333',
      linkColor: json['linkColor'] as String? ?? '#1E3A8A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundColor': backgroundColor,
      'contentWidth': contentWidth,
      'fontFamily': fontFamily,
      'textColor': textColor,
      'linkColor': linkColor,
    };
  }

  EmailStyles copyWith({
    String? backgroundColor,
    String? contentWidth,
    String? fontFamily,
    String? textColor,
    String? linkColor,
  }) {
    return EmailStyles(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      contentWidth: contentWidth ?? this.contentWidth,
      fontFamily: fontFamily ?? this.fontFamily,
      textColor: textColor ?? this.textColor,
      linkColor: linkColor ?? this.linkColor,
    );
  }

  String globalStyles() {
    return '''
<style type="text/css">
  body { margin: 0; padding: 0; background-color: $backgroundColor; }
  table { border-collapse: collapse; }
  img { border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; max-width: 100%; }
  p { margin: 0; padding: 0; }
  a { color: $linkColor; }
  .container { width: 100%; max-width: $contentWidth; }
  .responsive-img { width: 100%; height: auto; }
  .stack-column { vertical-align: top; }
  @media only screen and (max-width: 600px) {
    .container { width: 100% !important; }
    .stack-column { display: block !important; width: 100% !important; max-width: 100% !important; }
  }
</style>
''';
  }
}


class EmailColumn {
  final String id;
  final int flex;
  final List<EmailComponent> components;
  final ColumnStyle style;

  const EmailColumn({
    required this.id,
    this.flex = 1,
    this.components = const [],
    this.style = const ColumnStyle(),
  });

  factory EmailColumn.fromJson(Map<String, dynamic> json) {
    return EmailColumn(
      id: json['id'] as String,
      flex: json['flex'] as int? ?? 1,
      components: (json['components'] as List<dynamic>? ?? [])
          .map((component) => EmailComponent.fromJson(component as Map<String, dynamic>))
          .toList(),
      style: ColumnStyle.fromJson(json['style'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flex': flex,
      'components': components.map((component) => component.toJson()).toList(),
      'style': style.toJson(),
    };
  }

  EmailColumn copyWith({
    String? id,
    int? flex,
    List<EmailComponent>? components,
    ColumnStyle? style,
  }) {
    return EmailColumn(
      id: id ?? this.id,
      flex: flex ?? this.flex,
      components: components ?? this.components,
      style: style ?? this.style,
    );
  }
}

class ColumnStyle {
  final String backgroundColor;
  final double padding;
  final double borderRadius;
  final String? borderColor;
  final double borderWidth;

  const ColumnStyle({
    this.backgroundColor = '#ffffff',
    this.padding = 10,
    this.borderRadius = 0,
    this.borderColor,
    this.borderWidth = 0,
  });

  factory ColumnStyle.fromJson(Map<String, dynamic> json) {
    return ColumnStyle(
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff',
      padding: (json['padding'] as num?)?.toDouble() ?? 10,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      borderColor: json['borderColor'] as String?,
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundColor': backgroundColor,
      'padding': padding,
      'borderRadius': borderRadius,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
    };
  }

  ColumnStyle copyWith({
    String? backgroundColor,
    double? padding,
    double? borderRadius,
    String? borderColor,
    double? borderWidth,
  }) {
    return ColumnStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }
}

class Spacing {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const Spacing({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  const Spacing.all(double value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  const Spacing.symmetric({double vertical = 0, double horizontal = 0})
      : top = vertical,
        right = horizontal,
        bottom = vertical,
        left = horizontal;

  Map<String, dynamic> toJson() => {
        'top': top,
        'right': right,
        'bottom': bottom,
        'left': left,
      };

  factory Spacing.fromJson(Map<String, dynamic> json) {
    return Spacing(
      top: (json['top'] as num?)?.toDouble() ?? 0,
      right: (json['right'] as num?)?.toDouble() ?? 0,
      bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
      left: (json['left'] as num?)?.toDouble() ?? 0,
    );
  }

  String toCssPadding() {
    return 'padding: ${top}px ${right}px ${bottom}px ${left}px;';
  }

  String toCssPaddingValue() {
    return '${top}px ${right}px ${bottom}px ${left}px';
  }
}

class ContainerBlockStyle {
  final String backgroundColor;
  final Spacing padding;
  final double borderRadius;
  final String? borderColor;
  final double borderWidth;

  const ContainerBlockStyle({
    this.backgroundColor = '#ffffff',
    this.padding = const Spacing(),
    this.borderRadius = 0,
    this.borderColor,
    this.borderWidth = 0,
  });

  factory ContainerBlockStyle.fromJson(Map<String, dynamic> json) {
    return ContainerBlockStyle(
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff',
      padding: json['padding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['padding'] as Map<String, dynamic>)
          : const Spacing(),
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      borderColor: json['borderColor'] as String?,
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'backgroundColor': backgroundColor,
        'padding': padding.toJson(),
        'borderRadius': borderRadius,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
      };
}

class TextBlockStyle {
  final double fontSize;
  final String color;
  final String alignment;
  final bool bold;
  final bool italic;
  final bool underline;
  final double lineHeight;
  final Spacing padding;
  final String? fontFamily;

  const TextBlockStyle({
    this.fontSize = 16,
    this.color = '#000000',
    this.alignment = 'left',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.lineHeight = 1.5,
    this.padding = const Spacing(),
    this.fontFamily,
  });

  factory TextBlockStyle.fromJson(Map<String, dynamic> json) {
    return TextBlockStyle(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      color: json['color'] as String? ?? '#000000',
      alignment: json['alignment'] as String? ?? 'left',
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      padding: json['padding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['padding'] as Map<String, dynamic>)
          : const Spacing(),
      fontFamily: json['fontFamily'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'color': color,
        'alignment': alignment,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'lineHeight': lineHeight,
        'padding': padding.toJson(),
        'fontFamily': fontFamily,
      };

  String processContent(String content) {
    final mergeTagPattern = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');
    return content.replaceAllMapped(mergeTagPattern, (match) {
      final tagName = match.group(1)!.toUpperCase();
      return '*|$tagName|*';
    });
  }
}

class ImageBlockStyle {
  final String width;
  final String? height;
  final String alignment;
  final double borderRadius;
  final Spacing padding;
  final String? alt;

  const ImageBlockStyle({
    this.width = '100%',
    this.height,
    this.alignment = 'center',
    this.borderRadius = 0,
    this.padding = const Spacing(),
    this.alt,
  });

  factory ImageBlockStyle.fromJson(Map<String, dynamic> json) {
    return ImageBlockStyle(
      width: json['width'] as String? ?? '100%',
      height: json['height'] as String?,
      alignment: json['alignment'] as String? ?? 'center',
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      padding: json['padding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['padding'] as Map<String, dynamic>)
          : const Spacing(),
      alt: json['alt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'alignment': alignment,
        'borderRadius': borderRadius,
        'padding': padding.toJson(),
        'alt': alt,
      };
}

class ButtonBlockStyle {
  final Spacing padding;
  final Spacing buttonPadding;
  final String backgroundColor;
  final String textColor;
  final String borderColor;
  final double borderRadius;
  final double fontSize;
  final String alignment;
  final bool bold;
  final String width;

  const ButtonBlockStyle({
    this.padding = const Spacing(),
    this.buttonPadding = const Spacing.symmetric(vertical: 12, horizontal: 24),
    this.backgroundColor = '#1E3A8A',
    this.textColor = '#ffffff',
    this.borderColor = '#1E3A8A',
    this.borderRadius = 6,
    this.fontSize = 16,
    this.alignment = 'center',
    this.bold = true,
    this.width = 'auto',
  });

  factory ButtonBlockStyle.fromJson(Map<String, dynamic> json) {
    return ButtonBlockStyle(
      padding: json['padding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['padding'] as Map<String, dynamic>)
          : const Spacing(),
      buttonPadding: json['buttonPadding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['buttonPadding'] as Map<String, dynamic>)
          : const Spacing.symmetric(vertical: 12, horizontal: 24),
      backgroundColor: json['backgroundColor'] as String? ?? '#1E3A8A',
      textColor: json['textColor'] as String? ?? '#ffffff',
      borderColor: json['borderColor'] as String? ?? '#1E3A8A',
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 6,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      alignment: json['alignment'] as String? ?? 'center',
      bold: json['bold'] as bool? ?? true,
      width: json['width'] as String? ?? 'auto',
    );
  }

  Map<String, dynamic> toJson() => {
        'padding': padding.toJson(),
        'buttonPadding': buttonPadding.toJson(),
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'borderColor': borderColor,
        'borderRadius': borderRadius,
        'fontSize': fontSize,
        'alignment': alignment,
        'bold': bold,
        'width': width,
      };
}

class DividerBlockStyle {
  final Spacing padding;
  final double thickness;
  final String color;
  final String lineStyle;

  const DividerBlockStyle({
    this.padding = const Spacing.symmetric(vertical: 16),
    this.thickness = 1,
    this.color = '#cccccc',
    this.lineStyle = 'solid',
  });

  factory DividerBlockStyle.fromJson(Map<String, dynamic> json) {
    return DividerBlockStyle(
      padding: json['padding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['padding'] as Map<String, dynamic>)
          : const Spacing.symmetric(vertical: 16),
      thickness: (json['thickness'] as num?)?.toDouble() ?? 1,
      color: json['color'] as String? ?? '#cccccc',
      lineStyle: json['lineStyle'] as String? ?? 'solid',
    );
  }

  Map<String, dynamic> toJson() => {
        'padding': padding.toJson(),
        'thickness': thickness,
        'color': color,
        'lineStyle': lineStyle,
      };
}

class ColumnsBlockStyle {
  final Spacing padding;
  final double gap;
  final List<int>? widths;

  const ColumnsBlockStyle({
    this.padding = const Spacing(),
    this.gap = 10,
    this.widths,
  });

  factory ColumnsBlockStyle.fromJson(Map<String, dynamic> json) {
    return ColumnsBlockStyle(
      padding: json['padding'] is Map<String, dynamic>
          ? Spacing.fromJson(json['padding'] as Map<String, dynamic>)
          : const Spacing(),
      gap: (json['gap'] as num?)?.toDouble() ?? 10,
      widths: (json['widths'] as List<dynamic>?)?.map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'padding': padding.toJson(),
        'gap': gap,
        'widths': widths,
      };

  List<double> columnPercents(int count) {
    if (widths != null && widths!.length == count) {
      final total = widths!.fold<int>(0, (sum, value) => sum + value);
      if (total > 0) {
        return widths!
            .map((value) => (value / total * 100).clamp(0, 100).toDouble())
            .toList();
      }
    }
    return List<double>.filled(count, (100 / count).clamp(0, 100));
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
