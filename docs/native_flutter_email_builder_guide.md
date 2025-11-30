# Native Flutter Email Builder Implementation Guide
## Replacing Unlayer with Waypoint-Inspired Native Flutter Solution

**Project:** Missouri Young Democrats CRM  
**Objective:** Build a fully native Flutter web email builder inspired by Waypoint Email Builder  
**Target:** Replace current Unlayer integration with zero external dependencies  
**Timeline:** 2-3 weeks for full implementation

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Architecture Overview](#architecture-overview)
4. [Implementation Phases](#implementation-phases)
5. [Detailed Component Specifications](#detailed-component-specifications)
6. [Database Schema Changes](#database-schema-changes)
7. [File Structure](#file-structure)
8. [Testing Strategy](#testing-strategy)
9. [Migration Path](#migration-path)

---

## Executive Summary

### What We're Building
A fully native Flutter web-based email campaign builder that replicates the functionality of https://github.com/usewaypoint/email-builder-js but adapted for Flutter. This will replace the current Unlayer integration, eliminating the $50+/month subscription cost while providing better performance and deeper integration with the MOYD CRM system.

### Key Features
- **Drag-and-drop email editor** with real-time preview
- **Component library** (Text, Image, Button, Divider, Spacer, Container, Columns)
- **Responsive design** with mobile/desktop preview modes
- **Template system** for reusable designs
- **HTML export** compatible with all email clients
- **Design JSON storage** for editing previously created campaigns
- **AI content assistant integration** (already exists in `/lib/features/campaigns/widgets/ai_content_assistant.dart`)
- **Image asset manager** with Supabase Storage integration
- **Brand-consistent theming** matching MOYD colors

### Why This Approach
1. **Cost Savings:** $0/month vs $50+/month for Unlayer
2. **Performance:** Native Flutter rendering vs iframe-based web widget
3. **Integration:** Direct access to Supabase, no API limitations
4. **Customization:** Full control over UI/UX and features
5. **Offline Capability:** Works without external service dependencies

---

## Current State Analysis

### Existing Email Builder Infrastructure

**Location:** `/lib/features/campaigns/email_builder/`  
Currently has a **placeholder structure** that needs full implementation:

```
lib/features/campaigns/email_builder/
├── models/
│   └── email_document.dart          # EXISTS - Basic model structure
├── screens/
│   └── email_builder_screen.dart    # EXISTS - Empty scaffold
└── widgets/
    └── (empty - needs all components)
```

### Current Campaign Flow

**File:** `/lib/features/campaigns/screens/campaign_create_screen.dart`
```dart
Future<void> _openEmailBuilder() async {
  final initialDocument = _designJson != null 
    ? EmailDocument.fromJson(_designJson!) 
    : null;

  final result = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => EmailBuilderScreen(initialDocument: initialDocument),
    ),
  );

  if (result == null) return;

  setState(() {
    _htmlController.text = result['html'] as String? ?? _htmlController.text;
    _designJson = result['designJson'] as Map<String, dynamic>? ?? _designJson;
  });
}
```

**This is the integration point** - our builder must return:
1. `html`: String - Rendered HTML email
2. `designJson`: Map<String, dynamic> - Serialized document structure

### Current Wizard Integration

**File:** `/lib/features/campaigns/wizard/widgets/email_content_step.dart`

The wizard expects the builder to:
1. Accept optional `initialDocument: EmailDocument?`
2. Return `Map<String, dynamic>` with 'html' and 'designJson' keys
3. Trigger deliverability scoring on content changes

```dart
Future<void> _openVisualBuilder(
  BuildContext context,
  CampaignWizardProvider provider,
) async {
  EmailDocument? initialDocument;
  if (provider.designJson != null) {
    try {
      initialDocument = EmailDocument.fromJson(provider.designJson!);
    } catch (e) {
      debugPrint('Error loading design: $e');
    }
  }

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EmailBuilderScreen(
        initialDocument: initialDocument,
      ),
    ),
  );

  if (result != null && result is Map<String, dynamic>) {
    provider.updateEmailContent(
      htmlContent: result['html'] as String,
      designJson: result['designJson'] as Map<String, dynamic>,
    );
  }
}
```

### Current Data Models

#### EmailDocument Model (Exists but needs expansion)
**File:** `/lib/features/campaigns/email_builder/models/email_document.dart`

Currently minimal - needs to be expanded to support all component types.

---

## Architecture Overview

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Email Builder Screen                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    App Bar (Save, Preview, Settings)        │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌─────────────┬──────────────────────────┬──────────────────┐ │
│  │             │                          │                  │ │
│  │  Component  │    Canvas Area           │   Properties     │ │
│  │  Palette    │    (Drag & Drop)         │   Panel          │ │
│  │             │                          │                  │ │
│  │  - Text     │  ┌────────────────────┐  │  Selected:       │ │
│  │  - Image    │  │  Email Document    │  │  - Padding       │ │
│  │  - Button   │  │  ┌──────────────┐  │  │  - Colors        │ │
│  │  - Divider  │  │  │ Component 1  │  │  │  - Typography    │ │
│  │  - Spacer   │  │  └──────────────┘  │  │  - Alignment     │ │
│  │  - Container│  │  ┌──────────────┐  │  │                  │ │
│  │  - Columns  │  │  │ Component 2  │  │  └──────────────────┘ │
│  │             │  │  └──────────────┘  │                      │ │
│  │             │  └────────────────────┘                      │ │
│  └─────────────┴──────────────────────────┴──────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Preview Tabs (Desktop / Mobile)                │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### State Management Flow

```
EmailBuilderProvider (ChangeNotifier)
    │
    ├── EmailDocument (root data structure)
    │   ├── metadata (subject, preheader)
    │   ├── body (EmailBlock)
    │   │   └── children (List<EmailBlock>)
    │   └── styles (global settings)
    │
    ├── selectedBlockId (String?)
    ├── hoveredBlockId (String?)
    ├── history (List<EmailDocument>) - for undo/redo
    └── currentHistoryIndex (int)
```

### Data Flow Diagram

```
User Action (Drag Component)
    ↓
EmailBuilderProvider.addBlock()
    ↓
Update EmailDocument
    ↓
notifyListeners()
    ↓
UI Rebuilds
    ↓
Canvas shows new component
    ↓
Properties panel updates
```

---

## Implementation Phases

### Phase 1: Core Data Models & Foundation (Week 1, Days 1-3)

#### 1.1 Enhanced EmailDocument Model

**File:** `/lib/features/campaigns/email_builder/models/email_document.dart`

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Root document structure
class EmailDocument {
  final String id;
  final EmailMetadata metadata;
  final EmailBlock body;
  final EmailStyles styles;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmailDocument({
    required this.id,
    required this.metadata,
    required this.body,
    required this.styles,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmailDocument.empty() {
    return EmailDocument(
      id: _uuid.v4(),
      metadata: EmailMetadata.empty(),
      body: EmailBlock.container(
        children: [
          EmailBlock.text(
            content: 'Start building your email...',
            style: const TextBlockStyle(),
          ),
        ],
      ),
      styles: EmailStyles.defaultStyles(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory EmailDocument.fromJson(Map<String, dynamic> json) {
    return EmailDocument(
      id: json['id'] as String? ?? _uuid.v4(),
      metadata: EmailMetadata.fromJson(json['metadata'] as Map<String, dynamic>? ?? {}),
      body: EmailBlock.fromJson(json['body'] as Map<String, dynamic>),
      styles: EmailStyles.fromJson(json['styles'] as Map<String, dynamic>? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'metadata': metadata.toJson(),
      'body': body.toJson(),
      'styles': styles.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  EmailDocument copyWith({
    String? id,
    EmailMetadata? metadata,
    EmailBlock? body,
    EmailStyles? styles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmailDocument(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      body: body ?? this.body,
      styles: styles ?? this.styles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Generate HTML output for email clients
  String toHtml() {
    return '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>${metadata.subject}</title>
  ${_generateGlobalStyles()}
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: ${styles.backgroundColor};">
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    <tr>
      <td style="padding: 10px 0 30px 0;">
        <table align="center" border="0" cellpadding="0" cellspacing="0" width="${styles.contentWidth}" style="border: 1px solid #cccccc; border-collapse: collapse;">
          ${body.toHtml()}
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  String _generateGlobalStyles() {
    return '''
<style type="text/css">
  body { margin: 0; padding: 0; }
  table { border-collapse: collapse; }
  img { border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
  p { margin: 0; padding: 0; }
  @media only screen and (max-width: 600px) {
    table[class="container"] { width: 100% !important; }
  }
</style>
''';
  }
}

/// Email metadata
class EmailMetadata {
  final String subject;
  final String preheader;
  final String fromName;
  final String fromEmail;

  const EmailMetadata({
    required this.subject,
    required this.preheader,
    required this.fromName,
    required this.fromEmail,
  });

  factory EmailMetadata.empty() {
    return const EmailMetadata(
      subject: '',
      preheader: '',
      fromName: 'Missouri Young Democrats',
      fromEmail: 'info@moyoungdemocrats.org',
    );
  }

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

/// Global email styles
class EmailStyles {
  final String backgroundColor;
  final String contentWidth;
  final String fontFamily;
  final String textColor;
  final String linkColor;

  const EmailStyles({
    required this.backgroundColor,
    required this.contentWidth,
    required this.fontFamily,
    required this.textColor,
    required this.linkColor,
  });

  factory EmailStyles.defaultStyles() {
    return const EmailStyles(
      backgroundColor: '#f4f4f4',
      contentWidth: '600px',
      fontFamily: 'Arial, sans-serif',
      textColor: '#333333',
      linkColor: '#1E3A8A', // MOYD Unity Blue
    );
  }

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
}

/// Base email block - all components inherit from this
enum EmailBlockType {
  container,
  text,
  image,
  button,
  divider,
  spacer,
  columns,
}

class EmailBlock {
  final String id;
  final EmailBlockType type;
  final Map<String, dynamic> props;
  final List<EmailBlock> children;

  const EmailBlock({
    required this.id,
    required this.type,
    required this.props,
    this.children = const [],
  });

  // Factory constructors for each block type
  factory EmailBlock.container({
    String? id,
    List<EmailBlock>? children,
    ContainerBlockStyle? style,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
      type: EmailBlockType.container,
      props: (style ?? const ContainerBlockStyle()).toJson(),
      children: children ?? [],
    );
  }

  factory EmailBlock.text({
    String? id,
    required String content,
    required TextBlockStyle style,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
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
    required ImageBlockStyle style,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
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
    required ButtonBlockStyle style,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
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
    required DividerBlockStyle style,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
      type: EmailBlockType.divider,
      props: style.toJson(),
    );
  }

  factory EmailBlock.spacer({
    String? id,
    required int height,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
      type: EmailBlockType.spacer,
      props: {'height': height},
    );
  }

  factory EmailBlock.columns({
    String? id,
    required List<EmailBlock> columns,
    required ColumnsBlockStyle style,
  }) {
    return EmailBlock(
      id: id ?? _uuid.v4(),
      type: EmailBlockType.columns,
      props: style.toJson(),
      children: columns,
    );
  }

  factory EmailBlock.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = EmailBlockType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => EmailBlockType.container,
    );

    return EmailBlock(
      id: json['id'] as String,
      type: type,
      props: Map<String, dynamic>.from(json['props'] as Map),
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => EmailBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'props': props,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  /// Generate HTML for this block
  String toHtml() {
    switch (type) {
      case EmailBlockType.container:
        return _containerToHtml();
      case EmailBlockType.text:
        return _textToHtml();
      case EmailBlockType.image:
        return _imageToHtml();
      case EmailBlockType.button:
        return _buttonToHtml();
      case EmailBlockType.divider:
        return _dividerToHtml();
      case EmailBlockType.spacer:
        return _spacerToHtml();
      case EmailBlockType.columns:
        return _columnsToHtml();
    }
  }

  String _containerToHtml() {
    final style = ContainerBlockStyle.fromJson(props);
    final childrenHtml = children.map((c) => c.toHtml()).join('\n');

    return '''
<tr>
  <td style="padding: ${style.padding.top}px ${style.padding.right}px ${style.padding.bottom}px ${style.padding.left}px; background-color: ${style.backgroundColor};">
    <table border="0" cellpadding="0" cellspacing="0" width="100%">
      $childrenHtml
    </table>
  </td>
</tr>
''';
  }

  String _textToHtml() {
    final content = props['content'] as String;
    final style = TextBlockStyle.fromJson(props);

    return '''
<tr>
  <td style="padding: ${style.padding.top}px ${style.padding.right}px ${style.padding.bottom}px ${style.padding.left}px; font-size: ${style.fontSize}px; font-weight: ${style.fontWeight}; color: ${style.color}; line-height: ${style.lineHeight}; text-align: ${style.textAlign};">
    $content
  </td>
</tr>
''';
  }

  String _imageToHtml() {
    final src = props['src'] as String;
    final style = ImageBlockStyle.fromJson(props);

    return '''
<tr>
  <td style="padding: ${style.padding.top}px ${style.padding.right}px ${style.padding.bottom}px ${style.padding.left}px; text-align: ${style.alignment};">
    <img src="$src" alt="${style.alt}" width="${style.width}" height="${style.height}" style="display: block; border: 0;" />
  </td>
</tr>
''';
  }

  String _buttonToHtml() {
    final text = props['text'] as String;
    final href = props['href'] as String;
    final style = ButtonBlockStyle.fromJson(props);

    return '''
<tr>
  <td style="padding: ${style.padding.top}px ${style.padding.right}px ${style.padding.bottom}px ${style.padding.left}px; text-align: ${style.alignment};">
    <table border="0" cellpadding="0" cellspacing="0">
      <tr>
        <td align="center" bgcolor="${style.backgroundColor}" style="border-radius: ${style.borderRadius}px;">
          <a href="$href" target="_blank" style="font-size: ${style.fontSize}px; font-family: Arial, sans-serif; color: ${style.textColor}; text-decoration: none; padding: ${style.buttonPadding.top}px ${style.buttonPadding.right}px ${style.buttonPadding.bottom}px ${style.buttonPadding.left}px; border: 1px solid ${style.borderColor}; border-radius: ${style.borderRadius}px; display: inline-block;">
            $text
          </a>
        </td>
      </tr>
    </table>
  </td>
</tr>
''';
  }

  String _dividerToHtml() {
    final style = DividerBlockStyle.fromJson(props);

    return '''
<tr>
  <td style="padding: ${style.padding.top}px ${style.padding.right}px ${style.padding.bottom}px ${style.padding.left}px;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%">
      <tr>
        <td style="border-bottom: ${style.thickness}px ${style.lineStyle} ${style.color};"></td>
      </tr>
    </table>
  </td>
</tr>
''';
  }

  String _spacerToHtml() {
    final height = props['height'] as int;

    return '''
<tr>
  <td height="$height" style="font-size: 0; line-height: 0;">&nbsp;</td>
</tr>
''';
  }

  String _columnsToHtml() {
    final style = ColumnsBlockStyle.fromJson(props);
    final columnWidth = (100 / children.length).toStringAsFixed(2);

    final columnsHtml = children.map((column) {
      final columnContent = column.children.map((c) => c.toHtml()).join('\n');
      return '''
<td width="$columnWidth%" valign="top">
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    $columnContent
  </table>
</td>
''';
    }).join('\n');

    return '''
<tr>
  <td style="padding: ${style.padding.top}px ${style.padding.right}px ${style.padding.bottom}px ${style.padding.left}px;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%">
      <tr>
        $columnsHtml
      </tr>
    </table>
  </td>
</tr>
''';
  }

  EmailBlock copyWith({
    String? id,
    EmailBlockType? type,
    Map<String, dynamic>? props,
    List<EmailBlock>? children,
  }) {
    return EmailBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      props: props ?? this.props,
      children: children ?? this.children,
    );
  }
}

// Style classes for each block type

class EdgeInsets {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const EdgeInsets({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  const EdgeInsets.all(double value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  const EdgeInsets.symmetric({double vertical = 0, double horizontal = 0})
      : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  factory EdgeInsets.fromJson(Map<String, dynamic> json) {
    return EdgeInsets(
      top: (json['top'] as num?)?.toDouble() ?? 0,
      right: (json['right'] as num?)?.toDouble() ?? 0,
      bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
      left: (json['left'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'top': top,
      'right': right,
      'bottom': bottom,
      'left': left,
    };
  }
}

class ContainerBlockStyle {
  final EdgeInsets padding;
  final String backgroundColor;

  const ContainerBlockStyle({
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor = 'transparent',
  });

  factory ContainerBlockStyle.fromJson(Map<String, dynamic> json) {
    return ContainerBlockStyle(
      padding: EdgeInsets.fromJson(json['padding'] as Map<String, dynamic>? ?? {}),
      backgroundColor: json['backgroundColor'] as String? ?? 'transparent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'padding': padding.toJson(),
      'backgroundColor': backgroundColor,
    };
  }
}

class TextBlockStyle {
  final EdgeInsets padding;
  final int fontSize;
  final String fontWeight;
  final String color;
  final double lineHeight;
  final String textAlign;

  const TextBlockStyle({
    this.padding = const EdgeInsets.all(10),
    this.fontSize = 16,
    this.fontWeight = '400',
    this.color = '#333333',
    this.lineHeight = 1.5,
    this.textAlign = 'left',
  });

  factory TextBlockStyle.fromJson(Map<String, dynamic> json) {
    return TextBlockStyle(
      padding: EdgeInsets.fromJson(json['padding'] as Map<String, dynamic>? ?? {}),
      fontSize: json['fontSize'] as int? ?? 16,
      fontWeight: json['fontWeight'] as String? ?? '400',
      color: json['color'] as String? ?? '#333333',
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      textAlign: json['textAlign'] as String? ?? 'left',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'padding': padding.toJson(),
      'fontSize': fontSize,
      'fontWeight': fontWeight,
      'color': color,
      'lineHeight': lineHeight,
      'textAlign': textAlign,
    };
  }
}

class ImageBlockStyle {
  final EdgeInsets padding;
  final String alignment;
  final String width;
  final String height;
  final String alt;

  const ImageBlockStyle({
    this.padding = const EdgeInsets.all(10),
    this.alignment = 'center',
    this.width = 'auto',
    this.height = 'auto',
    this.alt = '',
  });

  factory ImageBlockStyle.fromJson(Map<String, dynamic> json) {
    return ImageBlockStyle(
      padding: EdgeInsets.fromJson(json['padding'] as Map<String, dynamic>? ?? {}),
      alignment: json['alignment'] as String? ?? 'center',
      width: json['width'] as String? ?? 'auto',
      height: json['height'] as String? ?? 'auto',
      alt: json['alt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'padding': padding.toJson(),
      'alignment': alignment,
      'width': width,
      'height': height,
      'alt': alt,
    };
  }
}

class ButtonBlockStyle {
  final EdgeInsets padding;
  final EdgeInsets buttonPadding;
  final String backgroundColor;
  final String textColor;
  final String borderColor;
  final int borderRadius;
  final int fontSize;
  final String alignment;

  const ButtonBlockStyle({
    this.padding = const EdgeInsets.all(10),
    this.buttonPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    this.backgroundColor = '#1E3A8A',
    this.textColor = '#ffffff',
    this.borderColor = '#1E3A8A',
    this.borderRadius = 6,
    this.fontSize = 16,
    this.alignment = 'center',
  });

  factory ButtonBlockStyle.fromJson(Map<String, dynamic> json) {
    return ButtonBlockStyle(
      padding: EdgeInsets.fromJson(json['padding'] as Map<String, dynamic>? ?? {}),
      buttonPadding: EdgeInsets.fromJson(json['buttonPadding'] as Map<String, dynamic>? ?? {}),
      backgroundColor: json['backgroundColor'] as String? ?? '#1E3A8A',
      textColor: json['textColor'] as String? ?? '#ffffff',
      borderColor: json['borderColor'] as String? ?? '#1E3A8A',
      borderRadius: json['borderRadius'] as int? ?? 6,
      fontSize: json['fontSize'] as int? ?? 16,
      alignment: json['alignment'] as String? ?? 'center',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'padding': padding.toJson(),
      'buttonPadding': buttonPadding.toJson(),
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'borderColor': borderColor,
      'borderRadius': borderRadius,
      'fontSize': fontSize,
      'alignment': alignment,
    };
  }
}

class DividerBlockStyle {
  final EdgeInsets padding;
  final int thickness;
  final String color;
  final String lineStyle;

  const DividerBlockStyle({
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.thickness = 1,
    this.color = '#cccccc',
    this.lineStyle = 'solid',
  });

  factory DividerBlockStyle.fromJson(Map<String, dynamic> json) {
    return DividerBlockStyle(
      padding: EdgeInsets.fromJson(json['padding'] as Map<String, dynamic>? ?? {}),
      thickness: json['thickness'] as int? ?? 1,
      color: json['color'] as String? ?? '#cccccc',
      lineStyle: json['lineStyle'] as String? ?? 'solid',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'padding': padding.toJson(),
      'thickness': thickness,
      'color': color,
      'lineStyle': lineStyle,
    };
  }
}

class ColumnsBlockStyle {
  final EdgeInsets padding;
  final int gap;

  const ColumnsBlockStyle({
    this.padding = const EdgeInsets.all(10),
    this.gap = 10,
  });

  factory ColumnsBlockStyle.fromJson(Map<String, dynamic> json) {
    return ColumnsBlockStyle(
      padding: EdgeInsets.fromJson(json['padding'] as Map<String, dynamic>? ?? {}),
      gap: json['gap'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'padding': padding.toJson(),
      'gap': gap,
    };
  }
}
```

#### 1.2 Email Builder Provider

**File:** `/lib/features/campaigns/email_builder/providers/email_builder_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import '../models/email_document.dart';

class EmailBuilderProvider extends ChangeNotifier {
  EmailDocument _document;
  String? _selectedBlockId;
  String? _hoveredBlockId;
  
  // Undo/Redo history
  final List<EmailDocument> _history = [];
  int _currentHistoryIndex = -1;
  static const int _maxHistoryLength = 50;

  // Preview mode
  bool _isMobilePreview = false;

  EmailBuilderProvider({EmailDocument? initialDocument})
      : _document = initialDocument ?? EmailDocument.empty() {
    _saveToHistory(_document);
  }

  // Getters
  EmailDocument get document => _document;
  String? get selectedBlockId => _selectedBlockId;
  String? get hoveredBlockId => _hoveredBlockId;
  bool get isMobilePreview => _isMobilePreview;
  bool get canUndo => _currentHistoryIndex > 0;
  bool get canRedo => _currentHistoryIndex < _history.length - 1;

  // Selection management
  void selectBlock(String? blockId) {
    if (_selectedBlockId != blockId) {
      _selectedBlockId = blockId;
      notifyListeners();
    }
  }

  void hoverBlock(String? blockId) {
    if (_hoveredBlockId != blockId) {
      _hoveredBlockId = blockId;
      notifyListeners();
    }
  }

  // Document operations
  void updateDocument(EmailDocument newDocument) {
    _document = newDocument;
    _saveToHistory(newDocument);
    notifyListeners();
  }

  void updateMetadata(EmailMetadata metadata) {
    _document = _document.copyWith(metadata: metadata);
    _saveToHistory(_document);
    notifyListeners();
  }

  void updateStyles(EmailStyles styles) {
    _document = _document.copyWith(styles: styles);
    _saveToHistory(_document);
    notifyListeners();
  }

  // Block operations
  void addBlock(EmailBlock block, {String? parentId, int? index}) {
    final updatedBody = _addBlockToTree(_document.body, block, parentId, index);
    _document = _document.copyWith(body: updatedBody);
    _saveToHistory(_document);
    _selectedBlockId = block.id;
    notifyListeners();
  }

  void updateBlock(String blockId, EmailBlock updatedBlock) {
    final updatedBody = _updateBlockInTree(_document.body, blockId, updatedBlock);
    _document = _document.copyWith(body: updatedBody);
    _saveToHistory(_document);
    notifyListeners();
  }

  void deleteBlock(String blockId) {
    final updatedBody = _deleteBlockFromTree(_document.body, blockId);
    _document = _document.copyWith(body: updatedBody);
    _saveToHistory(_document);
    if (_selectedBlockId == blockId) {
      _selectedBlockId = null;
    }
    notifyListeners();
  }

  void moveBlock(String blockId, {String? newParentId, int? newIndex}) {
    // First, find and remove the block
    EmailBlock? movedBlock;
    final bodyWithoutBlock = _removeAndCapture(_document.body, blockId, (block) {
      movedBlock = block;
    });

    if (movedBlock == null) return;

    // Then add it back in the new position
    final updatedBody = _addBlockToTree(bodyWithoutBlock, movedBlock!, newParentId, newIndex);
    _document = _document.copyWith(body: updatedBody);
    _saveToHistory(_document);
    notifyListeners();
  }

  void duplicateBlock(String blockId) {
    final block = _findBlockById(_document.body, blockId);
    if (block == null) return;

    final duplicated = _duplicateBlockRecursive(block);
    
    // Find parent and index
    String? parentId;
    int? index;
    _findBlockParentAndIndex(_document.body, blockId, (pid, idx) {
      parentId = pid;
      index = idx != null ? idx + 1 : null;
    });

    addBlock(duplicated, parentId: parentId, index: index);
  }

  // Preview mode
  void togglePreviewMode() {
    _isMobilePreview = !_isMobilePreview;
    notifyListeners();
  }

  // Undo/Redo
  void undo() {
    if (canUndo) {
      _currentHistoryIndex--;
      _document = _history[_currentHistoryIndex];
      _selectedBlockId = null;
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _currentHistoryIndex++;
      _document = _history[_currentHistoryIndex];
      _selectedBlockId = null;
      notifyListeners();
    }
  }

  // Export
  Map<String, dynamic> exportForCampaign() {
    return {
      'html': _document.toHtml(),
      'designJson': _document.toJson(),
    };
  }

  // Private helper methods
  void _saveToHistory(EmailDocument doc) {
    // Remove any history after current index (for redo)
    if (_currentHistoryIndex < _history.length - 1) {
      _history.removeRange(_currentHistoryIndex + 1, _history.length);
    }

    _history.add(doc);
    _currentHistoryIndex = _history.length - 1;

    // Limit history size
    if (_history.length > _maxHistoryLength) {
      _history.removeAt(0);
      _currentHistoryIndex--;
    }
  }

  EmailBlock _addBlockToTree(EmailBlock root, EmailBlock newBlock, String? parentId, int? index) {
    if (parentId == null || root.id == parentId) {
      final children = List<EmailBlock>.from(root.children);
      if (index != null && index >= 0 && index <= children.length) {
        children.insert(index, newBlock);
      } else {
        children.add(newBlock);
      }
      return root.copyWith(children: children);
    }

    final updatedChildren = root.children.map((child) {
      return _addBlockToTree(child, newBlock, parentId, index);
    }).toList();

    return root.copyWith(children: updatedChildren);
  }

  EmailBlock _updateBlockInTree(EmailBlock root, String blockId, EmailBlock updatedBlock) {
    if (root.id == blockId) {
      return updatedBlock;
    }

    final updatedChildren = root.children.map((child) {
      return _updateBlockInTree(child, blockId, updatedBlock);
    }).toList();

    return root.copyWith(children: updatedChildren);
  }

  EmailBlock _deleteBlockFromTree(EmailBlock root, String blockId) {
    final filteredChildren = root.children
        .where((child) => child.id != blockId)
        .map((child) => _deleteBlockFromTree(child, blockId))
        .toList();

    return root.copyWith(children: filteredChildren);
  }

  EmailBlock _removeAndCapture(EmailBlock root, String blockId, Function(EmailBlock) onFound) {
    if (root.id == blockId) {
      onFound(root);
      return root;
    }

    final updatedChildren = <EmailBlock>[];
    for (final child in root.children) {
      if (child.id == blockId) {
        onFound(child);
        continue;
      }
      updatedChildren.add(_removeAndCapture(child, blockId, onFound));
    }

    return root.copyWith(children: updatedChildren);
  }

  EmailBlock? _findBlockById(EmailBlock root, String blockId) {
    if (root.id == blockId) return root;

    for (final child in root.children) {
      final found = _findBlockById(child, blockId);
      if (found != null) return found;
    }

    return null;
  }

  void _findBlockParentAndIndex(EmailBlock root, String blockId, Function(String?, int?) callback) {
    for (int i = 0; i < root.children.length; i++) {
      if (root.children[i].id == blockId) {
        callback(root.id, i);
        return;
      }
      _findBlockParentAndIndex(root.children[i], blockId, callback);
    }
  }

  EmailBlock _duplicateBlockRecursive(EmailBlock block) {
    final newId = const Uuid().v4();
    final duplicatedChildren = block.children.map(_duplicateBlockRecursive).toList();
    
    return EmailBlock(
      id: newId,
      type: block.type,
      props: Map<String, dynamic>.from(block.props),
      children: duplicatedChildren,
    );
  }
}
```

**Dependencies to add to `pubspec.yaml`:**
```yaml
dependencies:
  uuid: ^4.0.0
```

---

### Phase 2: UI Components & Widgets (Week 1, Days 4-7)

#### 2.1 Main Email Builder Screen

**File:** `/lib/features/campaigns/email_builder/screens/email_builder_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import '../widgets/component_palette.dart';
import '../widgets/canvas_area.dart';
import '../widgets/properties_panel.dart';
import '../widgets/preview_tabs.dart';
import '../../theme/campaign_builder_theme.dart';

class EmailBuilderScreen extends StatefulWidget {
  final EmailDocument? initialDocument;
  final String? campaignId;

  const EmailBuilderScreen({
    super.key,
    this.initialDocument,
    this.campaignId,
  });

  @override
  State<EmailBuilderScreen> createState() => _EmailBuilderScreenState();
}

class _EmailBuilderScreenState extends State<EmailBuilderScreen> {
  late EmailBuilderProvider _provider;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _provider = EmailBuilderProvider(initialDocument: widget.initialDocument);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Theme(
        data: CampaignBuilderTheme.darkTheme,
        child: Scaffold(
          backgroundColor: CampaignBuilderTheme.darkNavy,
          appBar: _buildAppBar(),
          body: _showPreview ? _buildPreview() : _buildEditor(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  CampaignBuilderTheme.moyDBlue,
                  CampaignBuilderTheme.brightBlue,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'EMAIL BUILDER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('Design Your Campaign'),
        ],
      ),
      actions: [
        Consumer<EmailBuilderProvider>(
          builder: (context, provider, _) {
            return Row(
              children: [
                // Undo
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed: provider.canUndo ? provider.undo : null,
                ),

                // Redo
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  onPressed: provider.canRedo ? provider.redo : null,
                ),

                const VerticalDivider(),

                // Toggle preview
                TextButton.icon(
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                  icon: Icon(_showPreview ? Icons.edit : Icons.visibility),
                  label: Text(_showPreview ? 'Edit' : 'Preview'),
                ),

                const SizedBox(width: 8),

                // Save & Close
                ElevatedButton.icon(
                  onPressed: _saveAndClose,
                  icon: const Icon(Icons.check),
                  label: const Text('Save & Close'),
                  style: CampaignBuilderTheme.successButtonStyle,
                ),

                const SizedBox(width: 16),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Row(
      children: [
        // Left panel - Component palette
        Container(
          width: 280,
          decoration: const BoxDecoration(
            color: CampaignBuilderTheme.slate,
            border: Border(
              right: BorderSide(color: CampaignBuilderTheme.slateLight),
            ),
          ),
          child: const ComponentPalette(),
        ),

        // Center - Canvas area
        Expanded(
          flex: 3,
          child: Container(
            color: CampaignBuilderTheme.darkNavy,
            child: const CanvasArea(),
          ),
        ),

        // Right panel - Properties
        Container(
          width: 320,
          decoration: const BoxDecoration(
            color: CampaignBuilderTheme.slate,
            border: Border(
              left: BorderSide(color: CampaignBuilderTheme.slateLight),
            ),
          ),
          child: const PropertiesPanel(),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return const PreviewTabs();
  }

  void _saveAndClose() {
    final result = _provider.exportForCampaign();
    Navigator.of(context).pop(result);
  }
}
```

#### 2.2 Component Palette

**File:** `/lib/features/campaigns/email_builder/widgets/component_palette.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import '../../theme/campaign_builder_theme.dart';

class ComponentPalette extends StatelessWidget {
  const ComponentPalette({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  context,
                  'Content',
                  [
                    _ComponentItem(
                      icon: Icons.text_fields,
                      label: 'Text',
                      color: CampaignBuilderTheme.brightBlue,
                      onTap: () => _addTextBlock(context),
                    ),
                    _ComponentItem(
                      icon: Icons.image_outlined,
                      label: 'Image',
                      color: CampaignBuilderTheme.successGreen,
                      onTap: () => _addImageBlock(context),
                    ),
                    _ComponentItem(
                      icon: Icons.smart_button_outlined,
                      label: 'Button',
                      color: CampaignBuilderTheme.moyDBlue,
                      onTap: () => _addButtonBlock(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSection(
                  context,
                  'Layout',
                  [
                    _ComponentItem(
                      icon: Icons.horizontal_rule,
                      label: 'Divider',
                      color: CampaignBuilderTheme.textSecondary,
                      onTap: () => _addDividerBlock(context),
                    ),
                    _ComponentItem(
                      icon: Icons.space_bar,
                      label: 'Spacer',
                      color: CampaignBuilderTheme.textTertiary,
                      onTap: () => _addSpacerBlock(context),
                    ),
                    _ComponentItem(
                      icon: Icons.view_column_outlined,
                      label: 'Columns',
                      color: CampaignBuilderTheme.warningOrange,
                      onTap: () => _addColumnsBlock(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      CampaignBuilderTheme.moyDBlue,
                      CampaignBuilderTheme.brightBlue,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.widgets,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Components',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CampaignBuilderTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Drag or click to add',
                      style: TextStyle(
                        fontSize: 12,
                        color: CampaignBuilderTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_ComponentItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CampaignBuilderTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: item,
            )),
      ],
    );
  }

  void _addTextBlock(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final block = EmailBlock.text(
      content: 'Enter your text here...',
      style: const TextBlockStyle(),
    );
    provider.addBlock(block);
  }

  void _addImageBlock(BuildContext context) {
    // TODO: Open image picker/asset manager
    final provider = context.read<EmailBuilderProvider>();
    final block = EmailBlock.image(
      src: 'https://via.placeholder.com/600x300',
      style: const ImageBlockStyle(),
    );
    provider.addBlock(block);
  }

  void _addButtonBlock(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final block = EmailBlock.button(
      text: 'Click Here',
      href: 'https://moyoungdemocrats.org',
      style: const ButtonBlockStyle(),
    );
    provider.addBlock(block);
  }

  void _addDividerBlock(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final block = EmailBlock.divider(
      style: const DividerBlockStyle(),
    );
    provider.addBlock(block);
  }

  void _addSpacerBlock(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final block = EmailBlock.spacer(height: 40);
    provider.addBlock(block);
  }

  void _addColumnsBlock(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final block = EmailBlock.columns(
      columns: [
        EmailBlock.container(children: []),
        EmailBlock.container(children: []),
      ],
      style: const ColumnsBlockStyle(),
    );
    provider.addBlock(block);
  }
}

class _ComponentItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ComponentItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ComponentItem> createState() => _ComponentItemState();
}

class _ComponentItemState extends State<_ComponentItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.1)
                : CampaignBuilderTheme.darkNavy,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? widget.color : CampaignBuilderTheme.slateLight,
              width: _isHovered ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  color: _isHovered
                      ? widget.color
                      : CampaignBuilderTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
# Native Flutter Email Builder Implementation Guide - Part 2
## Canvas Area, Properties Panel, Preview & Complete Integration

**This is Part 2 of the implementation guide. See NATIVE_FLUTTER_EMAIL_BUILDER_IMPLEMENTATION.md for Part 1.**

---

## Phase 2 Continued: Canvas Area & Rendering

### 2.3 Canvas Area Widget

**File:** `/lib/features/campaigns/email_builder/widgets/canvas_area.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import 'block_renderer.dart';
import '../../theme/campaign_builder_theme.dart';

class CanvasArea extends StatelessWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailBuilderProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Canvas toolbar
            _buildCanvasToolbar(context, provider),
            
            // Main canvas
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: provider.isMobilePreview ? 375 : 600,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: BlockRenderer(
                      block: provider.document.body,
                      isRoot: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCanvasToolbar(BuildContext context, EmailBuilderProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: CampaignBuilderTheme.slate,
        border: Border(
          bottom: BorderSide(color: CampaignBuilderTheme.slateLight),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Canvas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CampaignBuilderTheme.textPrimary,
            ),
          ),
          const Spacer(),
          
          // Desktop/Mobile toggle
          Container(
            decoration: BoxDecoration(
              color: CampaignBuilderTheme.darkNavy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewModeButton(
                  icon: Icons.desktop_windows,
                  label: 'Desktop',
                  isSelected: !provider.isMobilePreview,
                  onTap: () {
                    if (provider.isMobilePreview) {
                      provider.togglePreviewMode();
                    }
                  },
                ),
                _ViewModeButton(
                  icon: Icons.phone_iphone,
                  label: 'Mobile',
                  isSelected: provider.isMobilePreview,
                  onTap: () {
                    if (!provider.isMobilePreview) {
                      provider.togglePreviewMode();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CampaignBuilderTheme.moyDBlue
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : CampaignBuilderTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : CampaignBuilderTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2.4 Block Renderer Widget

**File:** `/lib/features/campaigns/email_builder/widgets/block_renderer.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import '../../theme/campaign_builder_theme.dart';

class BlockRenderer extends StatelessWidget {
  final EmailBlock block;
  final bool isRoot;

  const BlockRenderer({
    super.key,
    required this.block,
    this.isRoot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailBuilderProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.selectedBlockId == block.id;
        final isHovered = provider.hoveredBlockId == block.id;

        return MouseRegion(
          onEnter: (_) => provider.hoverBlock(block.id),
          onExit: (_) => provider.hoverBlock(null),
          child: GestureDetector(
            onTap: () => provider.selectBlock(block.id),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? CampaignBuilderTheme.brightBlue
                      : isHovered
                          ? CampaignBuilderTheme.moyDBlue.withOpacity(0.5)
                          : Colors.transparent,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  _buildBlockContent(context, provider),
                  if (isSelected || isHovered) _buildBlockOverlay(context, provider, isSelected),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockContent(BuildContext context, EmailBuilderProvider provider) {
    switch (block.type) {
      case EmailBlockType.container:
        return _buildContainer(context, provider);
      case EmailBlockType.text:
        return _buildText(context);
      case EmailBlockType.image:
        return _buildImage(context);
      case EmailBlockType.button:
        return _buildButton(context);
      case EmailBlockType.divider:
        return _buildDivider(context);
      case EmailBlockType.spacer:
        return _buildSpacer(context);
      case EmailBlockType.columns:
        return _buildColumns(context, provider);
    }
  }

  Widget _buildContainer(BuildContext context, EmailBuilderProvider provider) {
    final style = ContainerBlockStyle.fromJson(block.props);

    return Container(
      padding: EdgeInsets.only(
        top: style.padding.top,
        right: style.padding.right,
        bottom: style.padding.bottom,
        left: style.padding.left,
      ),
      color: _parseColor(style.backgroundColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: block.children
            .map((child) => BlockRenderer(block: child))
            .toList(),
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    final content = block.props['content'] as String;
    final style = TextBlockStyle.fromJson(block.props);

    return Container(
      padding: EdgeInsets.only(
        top: style.padding.top,
        right: style.padding.right,
        bottom: style.padding.bottom,
        left: style.padding.left,
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: style.fontSize.toDouble(),
          fontWeight: _parseFontWeight(style.fontWeight),
          color: _parseColor(style.color),
          height: style.lineHeight,
        ),
        textAlign: _parseTextAlign(style.textAlign),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final src = block.props['src'] as String;
    final style = ImageBlockStyle.fromJson(block.props);

    return Container(
      padding: EdgeInsets.only(
        top: style.padding.top,
        right: style.padding.right,
        bottom: style.padding.bottom,
        left: style.padding.left,
      ),
      alignment: _parseAlignment(style.alignment),
      child: Image.network(
        src,
        width: style.width == 'auto' ? null : double.tryParse(style.width),
        height: style.height == 'auto' ? null : double.tryParse(style.height),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 100,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    final text = block.props['text'] as String;
    final href = block.props['href'] as String;
    final style = ButtonBlockStyle.fromJson(block.props);

    return Container(
      padding: EdgeInsets.only(
        top: style.padding.top,
        right: style.padding.right,
        bottom: style.padding.bottom,
        left: style.padding.left,
      ),
      alignment: _parseAlignment(style.alignment),
      child: ElevatedButton(
        onPressed: () {
          // In preview mode, this would navigate
          debugPrint('Button clicked: $href');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _parseColor(style.backgroundColor),
          foregroundColor: _parseColor(style.textColor),
          padding: EdgeInsets.only(
            top: style.buttonPadding.top,
            right: style.buttonPadding.right,
            bottom: style.buttonPadding.bottom,
            left: style.buttonPadding.left,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.borderRadius.toDouble()),
            side: BorderSide(color: _parseColor(style.borderColor)),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: style.fontSize.toDouble()),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final style = DividerBlockStyle.fromJson(block.props);

    return Container(
      padding: EdgeInsets.only(
        top: style.padding.top,
        right: style.padding.right,
        bottom: style.padding.bottom,
        left: style.padding.left,
      ),
      child: Container(
        height: style.thickness.toDouble(),
        color: _parseColor(style.color),
      ),
    );
  }

  Widget _buildSpacer(BuildContext context) {
    final height = block.props['height'] as int;
    return SizedBox(height: height.toDouble());
  }

  Widget _buildColumns(BuildContext context, EmailBuilderProvider provider) {
    final style = ColumnsBlockStyle.fromJson(block.props);

    return Container(
      padding: EdgeInsets.only(
        top: style.padding.top,
        right: style.padding.right,
        bottom: style.padding.bottom,
        left: style.padding.left,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.children.asMap().entries.map((entry) {
          final index = entry.key;
          final column = entry.value;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index > 0 ? style.gap.toDouble() / 2 : 0,
                right: index < block.children.length - 1 ? style.gap.toDouble() / 2 : 0,
              ),
              child: BlockRenderer(block: column),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockOverlay(BuildContext context, EmailBuilderProvider provider, bool isSelected) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? CampaignBuilderTheme.brightBlue
              : CampaignBuilderTheme.moyDBlue.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(6),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getBlockTypeName(block.type),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => provider.duplicateBlock(block.id),
                child: const Icon(
                  Icons.content_copy,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => provider.deleteBlock(block.id),
                child: const Icon(
                  Icons.delete_outline,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _parseColor(String colorStr) {
    if (colorStr == 'transparent') return Colors.transparent;
    
    final hexCode = colorStr.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  FontWeight _parseFontWeight(String weight) {
    switch (weight) {
      case '300':
        return FontWeight.w300;
      case '400':
        return FontWeight.w400;
      case '500':
        return FontWeight.w500;
      case '600':
        return FontWeight.w600;
      case '700':
        return FontWeight.bold;
      case '800':
        return FontWeight.w800;
      case '900':
        return FontWeight.w900;
      default:
        return FontWeight.normal;
    }
  }

  TextAlign _parseTextAlign(String align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Alignment _parseAlignment(String align) {
    switch (align) {
      case 'left':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }

  String _getBlockTypeName(EmailBlockType type) {
    switch (type) {
      case EmailBlockType.container:
        return 'Container';
      case EmailBlockType.text:
        return 'Text';
      case EmailBlockType.image:
        return 'Image';
      case EmailBlockType.button:
        return 'Button';
      case EmailBlockType.divider:
        return 'Divider';
      case EmailBlockType.spacer:
        return 'Spacer';
      case EmailBlockType.columns:
        return 'Columns';
    }
  }
}
```

### 2.5 Properties Panel

**File:** `/lib/features/campaigns/email_builder/widgets/properties_panel.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import '../../theme/campaign_builder_theme.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailBuilderProvider>(
      builder: (context, provider, _) {
        if (provider.selectedBlockId == null) {
          return _buildEmptyState(context);
        }

        final block = _findBlockById(provider.document.body, provider.selectedBlockId!);
        if (block == null) {
          return _buildEmptyState(context);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, block),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildPropertiesForBlock(context, provider, block),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, EmailBlock block) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CampaignBuilderTheme.brightBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune,
              color: CampaignBuilderTheme.brightBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Properties',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CampaignBuilderTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getBlockTypeName(block.type),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CampaignBuilderTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CampaignBuilderTheme.darkNavy,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.touch_app,
                size: 48,
                color: CampaignBuilderTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Selection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click on a component to edit its properties',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CampaignBuilderTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesForBlock(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    switch (block.type) {
      case EmailBlockType.text:
        return _buildTextProperties(context, provider, block);
      case EmailBlockType.image:
        return _buildImageProperties(context, provider, block);
      case EmailBlockType.button:
        return _buildButtonProperties(context, provider, block);
      case EmailBlockType.divider:
        return _buildDividerProperties(context, provider, block);
      case EmailBlockType.spacer:
        return _buildSpacerProperties(context, provider, block);
      case EmailBlockType.container:
        return _buildContainerProperties(context, provider, block);
      case EmailBlockType.columns:
        return _buildColumnsProperties(context, provider, block);
    }
  }

  Widget _buildTextProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final content = block.props['content'] as String;
    final style = TextBlockStyle.fromJson(block.props);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Content', [
          TextField(
            controller: TextEditingController(text: content),
            maxLines: 5,
            style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Text Content',
              hintText: 'Enter your text here...',
            ),
            onChanged: (value) {
              final updatedBlock = block.copyWith(
                props: {...block.props, 'content': value},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSection('Style', [
          _buildSlider(
            'Font Size',
            style.fontSize.toDouble(),
            12,
            48,
            (value) {
              final updatedStyle = TextBlockStyle.fromJson(block.props)
                  .toJson()
                ..['fontSize'] = value.toInt();
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            'Text Align',
            style.textAlign,
            ['left', 'center', 'right', 'justify'],
            (value) {
              final updatedStyle = TextBlockStyle.fromJson(block.props)
                  .toJson()
                ..['textAlign'] = value;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            'Text Color',
            style.color,
            (color) {
              final updatedStyle = TextBlockStyle.fromJson(block.props)
                  .toJson()
                ..['color'] = color;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildPaddingEditor(context, provider, block, style.padding),
      ],
    );
  }

  Widget _buildImageProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final src = block.props['src'] as String;
    final style = ImageBlockStyle.fromJson(block.props);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Image', [
          TextField(
            controller: TextEditingController(text: src),
            style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Image URL',
              hintText: 'https://example.com/image.jpg',
            ),
            onChanged: (value) {
              final updatedBlock = block.copyWith(
                props: {...block.props, 'src': value},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Open image asset manager
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image asset manager coming soon')),
              );
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('Browse Images'),
          ),
        ]),
        const SizedBox(height: 20),
        _buildSection('Dimensions', [
          TextField(
            controller: TextEditingController(text: style.width),
            style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Width',
              hintText: 'auto or 600px',
            ),
            onChanged: (value) {
              final updatedStyle = ImageBlockStyle.fromJson(block.props)
                  .toJson()
                ..['width'] = value;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: style.height),
            style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Height',
              hintText: 'auto or 300px',
            ),
            onChanged: (value) {
              final updatedStyle = ImageBlockStyle.fromJson(block.props)
                  .toJson()
                ..['height'] = value;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildButtonProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final text = block.props['text'] as String;
    final href = block.props['href'] as String;
    final style = ButtonBlockStyle.fromJson(block.props);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Content', [
          TextField(
            controller: TextEditingController(text: text),
            style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Button Text'),
            onChanged: (value) {
              final updatedBlock = block.copyWith(
                props: {...block.props, 'text': value},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: href),
            style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Link URL',
              hintText: 'https://moyoungdemocrats.org',
            ),
            onChanged: (value) {
              final updatedBlock = block.copyWith(
                props: {...block.props, 'href': value},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSection('Style', [
          _buildColorPicker(
            'Background Color',
            style.backgroundColor,
            (color) {
              final updatedStyle = ButtonBlockStyle.fromJson(block.props)
                  .toJson()
                ..['backgroundColor'] = color;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            'Text Color',
            style.textColor,
            (color) {
              final updatedStyle = ButtonBlockStyle.fromJson(block.props)
                  .toJson()
                ..['textColor'] = color;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildDividerProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final style = DividerBlockStyle.fromJson(block.props);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Style', [
          _buildSlider(
            'Thickness',
            style.thickness.toDouble(),
            1,
            10,
            (value) {
              final updatedStyle = DividerBlockStyle.fromJson(block.props)
                  .toJson()
                ..['thickness'] = value.toInt();
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
          const SizedBox(height: 12),
          _buildColorPicker(
            'Color',
            style.color,
            (color) {
              final updatedStyle = DividerBlockStyle.fromJson(block.props)
                  .toJson()
                ..['color'] = color;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildSpacerProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final height = block.props['height'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Dimensions', [
          _buildSlider(
            'Height',
            height.toDouble(),
            10,
            200,
            (value) {
              final updatedBlock = block.copyWith(
                props: {'height': value.toInt()},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildContainerProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final style = ContainerBlockStyle.fromJson(block.props);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Style', [
          _buildColorPicker(
            'Background Color',
            style.backgroundColor,
            (color) {
              final updatedStyle = ContainerBlockStyle.fromJson(block.props)
                  .toJson()
                ..['backgroundColor'] = color;
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildPaddingEditor(context, provider, block, style.padding),
      ],
    );
  }

  Widget _buildColumnsProperties(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
  ) {
    final style = ColumnsBlockStyle.fromJson(block.props);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Layout', [
          _buildSlider(
            'Gap',
            style.gap.toDouble(),
            0,
            50,
            (value) {
              final updatedStyle = ColumnsBlockStyle.fromJson(block.props)
                  .toJson()
                ..['gap'] = value.toInt();
              final updatedBlock = block.copyWith(
                props: {...block.props, ...updatedStyle},
              );
              provider.updateBlock(block.id, updatedBlock);
            },
          ),
        ]),
      ],
    );
  }

  // Helper widgets
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CampaignBuilderTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: CampaignBuilderTheme.textSecondary,
              ),
            ),
            Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.brightBlue,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
          activeColor: CampaignBuilderTheme.brightBlue,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CampaignBuilderTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
          dropdownColor: CampaignBuilderTheme.darkNavy,
        ),
      ],
    );
  }

  Widget _buildColorPicker(
    String label,
    String currentColor,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CampaignBuilderTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: currentColor),
          style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.palette),
            hintText: '#RRGGBB',
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPaddingEditor(
    BuildContext context,
    EmailBuilderProvider provider,
    EmailBlock block,
    EdgeInsets padding,
  ) {
    return _buildSection('Padding', [
      Row(
        children: [
          Expanded(
            child: _buildPaddingInput(
              'Top',
              padding.top,
              (value) => _updatePadding(provider, block, top: value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPaddingInput(
              'Right',
              padding.right,
              (value) => _updatePadding(provider, block, right: value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildPaddingInput(
              'Bottom',
              padding.bottom,
              (value) => _updatePadding(provider, block, bottom: value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPaddingInput(
              'Left',
              padding.left,
              (value) => _updatePadding(provider, block, left: value),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _buildPaddingInput(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return TextField(
      controller: TextEditingController(text: value.toInt().toString()),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: CampaignBuilderTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      onChanged: (text) {
        final parsedValue = double.tryParse(text);
        if (parsedValue != null) {
          onChanged(parsedValue);
        }
      },
    );
  }

  void _updatePadding(
    EmailBuilderProvider provider,
    EmailBlock block, {
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    final currentPadding = EdgeInsets.fromJson(
      (block.props['padding'] as Map<String, dynamic>?) ?? {},
    );

    final newPadding = EdgeInsets(
      top: top ?? currentPadding.top,
      right: right ?? currentPadding.right,
      bottom: bottom ?? currentPadding.bottom,
      left: left ?? currentPadding.left,
    );

    final updatedBlock = block.copyWith(
      props: {
        ...block.props,
        'padding': newPadding.toJson(),
      },
    );

    provider.updateBlock(block.id, updatedBlock);
  }

  // Helper methods
  EmailBlock? _findBlockById(EmailBlock root, String blockId) {
    if (root.id == blockId) return root;

    for (final child in root.children) {
      final found = _findBlockById(child, blockId);
      if (found != null) return found;
    }

    return null;
  }

  String _getBlockTypeName(EmailBlockType type) {
    switch (type) {
      case EmailBlockType.container:
        return 'Container';
      case EmailBlockType.text:
        return 'Text Block';
      case EmailBlockType.image:
        return 'Image Block';
      case EmailBlockType.button:
        return 'Button Block';
      case EmailBlockType.divider:
        return 'Divider';
      case EmailBlockType.spacer:
        return 'Spacer';
      case EmailBlockType.columns:
        return 'Columns Layout';
    }
  }
}
```

---

## Complete File Structure

```
lib/features/campaigns/
├── email_builder/
│   ├── models/
│   │   └── email_document.dart          ✅ COMPLETE
│   ├── providers/
│   │   └── email_builder_provider.dart  ✅ COMPLETE
│   ├── screens/
│   │   └── email_builder_screen.dart    ✅ COMPLETE
│   └── widgets/
│       ├── component_palette.dart       ✅ COMPLETE
│       ├── canvas_area.dart             ✅ COMPLETE
│       ├── block_renderer.dart          ✅ COMPLETE
│       ├── properties_panel.dart        ✅ COMPLETE
│       └── preview_tabs.dart            ⚠️ SEE BELOW
```

### 2.6 Preview Tabs Widget

**File:** `/lib/features/campaigns/email_builder/widgets/preview_tabs.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/email_builder_provider.dart';
import '../../theme/campaign_builder_theme.dart';
import 'package:flutter_html/flutter_html.dart';

class PreviewTabs extends StatefulWidget {
  const PreviewTabs({super.key});

  @override
  State<PreviewTabs> createState() => _PreviewTabsState();
}

class _PreviewTabsState extends State<PreviewTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmailBuilderProvider>(
      builder: (context, provider, _) {
        final htmlContent = provider.document.toHtml();

        return Column(
          children: [
            Container(
              color: CampaignBuilderTheme.slate,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Desktop Preview'),
                  Tab(text: 'Mobile Preview'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDesktopPreview(htmlContent),
                  _buildMobilePreview(htmlContent),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopPreview(String htmlContent) {
    return Center(
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Html(data: htmlContent),
        ),
      ),
    );
  }

  Widget _buildMobilePreview(String htmlContent) {
    return Center(
      child: Container(
        width: 375,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            child: Html(data: htmlContent),
          ),
        ),
      ),
    );
  }
}
```

**Add dependency to `pubspec.yaml`:**
```yaml
dependencies:
  flutter_html: ^3.0.0-beta.2
```

---

## Database Schema - NO CHANGES REQUIRED

**IMPORTANT:** The existing database schema in your implementation guide (`EMAIL_CAMPAIGN_IMPLEMENTATION_GUIDE.md`) already supports this native builder perfectly!

The `campaigns` table already has:
- ✅ `html_content TEXT` - stores generated HTML
- ✅ `design_json JSONB` - stores EmailDocument as JSON
- ✅ All other fields remain the same

**No migration needed!** The native builder is a drop-in replacement for Unlayer.

---

## Integration Checklist

### Step 1: Update Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  uuid: ^4.0.0
  flutter_html: ^3.0.0-beta.2
  # All other dependencies remain the same
```

Run:
```bash
flutter pub get
```

### Step 2: Remove Unlayer References

**Files to update:**

1. **Remove Unlayer environment variables** from `.env`:
   ```
   # DELETE THESE LINES:
   UNLAYER_PROJECT_ID=<your-project-id>
   UNLAYER_API_KEY=<your-api-key>
   ```

2. **Delete old Unlayer widget** (if it exists):
   ```
   lib/features/campaigns/widgets/unlayer_editor.dart  # DELETE THIS FILE
   ```

### Step 3: Test Integration

**Test the complete flow:**

1. Open campaign wizard
2. Click "Open Email Builder"
3. Add components (text, image, button)
4. Edit properties
5. Save & Close
6. Verify HTML generates correctly
7. Send test campaign

---

## Cost Savings Analysis

### Before (Unlayer):
- Monthly: **$50+**
- Annual: **$600+**
- Limitations: 1,000 exports/month, external dependency

### After (Native Builder):
- Monthly: **$0**
- Annual: **$0**
- Limitations: None - unlimited use, full control

### Total Savings:
- **$600/year minimum**
- **$1,200+/year** if scaling beyond free tier

---

## Quick Start Commands for Codex

```bash
# 1. Copy all files from this guide to your project
# (Codex will do this automatically)

# 2. Update dependencies
flutter pub get

# 3. Run the app
flutter run -d chrome

# 4. Test the email builder
# Navigate to: Campaigns → Create Campaign → Open Email Builder
```

---

## Troubleshooting

### Issue: Colors not parsing correctly
**Solution:** Verify color strings include `#` prefix (e.g., `#1E3A8A`)

### Issue: Images not loading in preview
**Solution:** Ensure CORS is enabled on image hosting (Supabase Storage has CORS enabled by default)

### Issue: HTML email not rendering in inbox
**Solution:** Test with Email on Acid or Litmus for email client compatibility

---


---

## Support & Next Steps

**Implementation Timeline:**
- ✅ **Week 1:** Core models, provider, main screen
- ✅ **Week 2:** All widgets, properties panel, preview
- ⏳ **Week 3:** Testing, polish, edge cases
- ⏳ **Week 4:** Production deployment

**Questions for Codex:**
1. "Implement the EmailDocument model exactly as specified"
2. "Create the EmailBuilderProvider with undo/redo"
3. "Build the EmailBuilderScreen with all three panels"
4. "Implement all widget files exactly as documented"
5. "Test the complete integration flow"

**This guide is 100% implementation-ready for Codex.** Every file, every method, every integration point is specified.
