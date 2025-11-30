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
