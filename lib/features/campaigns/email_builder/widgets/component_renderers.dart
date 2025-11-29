import 'package:flutter/material.dart';

import '../models/email_component.dart';

class TextComponentRenderer extends StatelessWidget {
  final String content;
  final TextComponentStyle style;

  const TextComponentRenderer({
    super.key,
    required this.content,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: style.paddingTop,
        bottom: style.paddingBottom,
        left: style.paddingLeft,
        right: style.paddingRight,
      ),
      child: Text(
        content,
        textAlign: _getTextAlign(style.alignment),
        style: TextStyle(
          fontSize: style.fontSize,
          color: _hexToColor(style.color),
          fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
          decoration:
              style.underline ? TextDecoration.underline : TextDecoration.none,
          height: style.lineHeight,
          fontFamily: style.fontFamily,
        ),
      ),
    );
  }

  TextAlign _getTextAlign(String alignment) {
    switch (alignment) {
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class ImageComponentRenderer extends StatelessWidget {
  final String url;
  final String? alt;
  final String? link;
  final ImageComponentStyle style;

  const ImageComponentRenderer({
    super.key,
    required this.url,
    this.alt,
    this.link,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(style.borderRadius),
      child: Image.network(
        url,
        width: style.width == '100%'
            ? double.infinity
            : double.tryParse(style.width.replaceAll('px', '')),
        height: style.height != null
            ? double.tryParse(style.height!.replaceAll('px', ''))
            : null,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Image failed to load',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (link != null && link!.isNotEmpty) {
      image = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            debugPrint('Link clicked: $link');
          },
          child: image,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: style.paddingTop,
        bottom: style.paddingBottom,
        left: style.paddingLeft,
        right: style.paddingRight,
      ),
      child: _alignWidget(image, style.alignment),
    );
  }

  Widget _alignWidget(Widget child, String alignment) {
    switch (alignment) {
      case 'left':
        return Align(alignment: Alignment.centerLeft, child: child);
      case 'center':
        return Center(child: child);
      case 'right':
        return Align(alignment: Alignment.centerRight, child: child);
      default:
        return child;
    }
  }
}

class ButtonComponentRenderer extends StatelessWidget {
  final String text;
  final String url;
  final ButtonComponentStyle style;

  const ButtonComponentRenderer({
    super.key,
    required this.text,
    required this.url,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: () {
        debugPrint('Button clicked: $url');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _hexToColor(style.backgroundColor),
        foregroundColor: _hexToColor(style.textColor),
        padding: EdgeInsets.symmetric(
          vertical: style.paddingVertical,
          horizontal: style.paddingHorizontal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.borderRadius),
        ),
        minimumSize:
            style.width == 'auto' ? null : const Size(double.infinity, 0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: style.fontSize,
          fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: style.marginTop,
        bottom: style.marginBottom,
      ),
      child: _alignWidget(button, style.alignment),
    );
  }

  Widget _alignWidget(Widget child, String alignment) {
    switch (alignment) {
      case 'left':
        return Align(alignment: Alignment.centerLeft, child: child);
      case 'center':
        return Center(child: child);
      case 'right':
        return Align(alignment: Alignment.centerRight, child: child);
      default:
        return child;
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class DividerComponentRenderer extends StatelessWidget {
  final DividerComponentStyle style;

  const DividerComponentRenderer({
    super.key,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: style.marginTop,
        bottom: style.marginBottom,
      ),
      child: Container(
        height: style.thickness,
        decoration: BoxDecoration(
          color: style.style == 'solid' ? _hexToColor(style.color) : null,
          border: style.style != 'solid'
              ? Border(
                  bottom: BorderSide(
                    color: _hexToColor(style.color),
                    width: style.thickness,
                    style: style.style == 'dashed'
                        ? BorderStyle.none
                        : BorderStyle.solid,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class SpacerComponentRenderer extends StatelessWidget {
  final double height;

  const SpacerComponentRenderer({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}

class SocialComponentRenderer extends StatelessWidget {
  final List<SocialLink> links;
  final SocialComponentStyle style;

  const SocialComponentRenderer({
    super.key,
    required this.links,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: style.marginTop,
        bottom: style.marginBottom,
      ),
      child: _alignWidget(
        Wrap(
          spacing: style.spacing,
          children: links.map(_buildSocialIcon).toList(),
        ),
        style.alignment,
      ),
    );
  }

  Widget _buildSocialIcon(SocialLink link) {
    IconData icon;
    Color color;

    switch (link.platform.toLowerCase()) {
      case 'facebook':
        icon = Icons.facebook;
        color = const Color(0xFF1877F2);
        break;
      case 'twitter':
        icon = Icons.message;
        color = const Color(0xFF1DA1F2);
        break;
      case 'instagram':
        icon = Icons.camera_alt;
        color = const Color(0xFFE4405F);
        break;
      case 'linkedin':
        icon = Icons.business;
        color = const Color(0xFF0A66C2);
        break;
      default:
        icon = Icons.link;
        color = Colors.grey;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          debugPrint('Social link clicked: ${link.url}');
        },
        child: Container(
          width: style.iconSize,
          height: style.iconSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: style.iconSize * 0.6,
          ),
        ),
      ),
    );
  }

  Widget _alignWidget(Widget child, String alignment) {
    switch (alignment) {
      case 'left':
        return Align(alignment: Alignment.centerLeft, child: child);
      case 'center':
        return Center(child: child);
      case 'right':
        return Align(alignment: Alignment.centerRight, child: child);
      default:
        return child;
    }
  }
}

// New email-builder-js component renderers
class AvatarComponentRenderer extends StatelessWidget {
  final String imageUrl;
  final String? alt;
  final AvatarComponentStyle style;

  const AvatarComponentRenderer({
    super.key,
    required this.imageUrl,
    this.alt,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: style.size,
      height: style.size,
      decoration: BoxDecoration(
        shape: style.shape ? BoxShape.circle : BoxShape.rectangle,
        border: style.borderColor != null && style.borderWidth > 0
            ? Border.all(
                color: _hexToColor(style.borderColor!),
                width: style.borderWidth,
              )
            : null,
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: style.paddingTop,
        bottom: style.paddingBottom,
        left: style.paddingLeft,
        right: style.paddingRight,
      ),
      child: _alignWidget(avatar, style.alignment),
    );
  }

  Widget _alignWidget(Widget child, String alignment) {
    switch (alignment) {
      case 'left':
        return Align(alignment: Alignment.centerLeft, child: child);
      case 'center':
        return Center(child: child);
      case 'right':
        return Align(alignment: Alignment.centerRight, child: child);
      default:
        return Center(child: child);
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class HeadingComponentRenderer extends StatelessWidget {
  final String content;
  final HeadingComponentStyle style;

  const HeadingComponentRenderer({
    super.key,
    required this.content,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: style.paddingTop,
        bottom: style.paddingBottom,
        left: style.paddingLeft,
        right: style.paddingRight,
      ),
      child: Text(
        content,
        textAlign: _getTextAlign(style.alignment),
        style: TextStyle(
          fontSize: style.fontSize,
          color: _hexToColor(style.color),
          fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
          decoration:
              style.underline ? TextDecoration.underline : TextDecoration.none,
          height: style.lineHeight,
          fontFamily: style.fontFamily,
        ),
      ),
    );
  }

  TextAlign _getTextAlign(String alignment) {
    switch (alignment) {
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class HtmlComponentRenderer extends StatelessWidget {
  final String htmlContent;
  final HtmlComponentStyle style;

  const HtmlComponentRenderer({
    super.key,
    required this.htmlContent,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: style.paddingTop,
        bottom: style.paddingBottom,
        left: style.paddingLeft,
        right: style.paddingRight,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'HTML Content',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              htmlContent.isEmpty ? '<empty>' : htmlContent,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontFamily: 'monospace',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class ContainerComponentRenderer extends StatelessWidget {
  final List<EmailComponent> children;
  final ContainerComponentStyle style;

  const ContainerComponentRenderer({
    super.key,
    required this.children,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: style.paddingTop,
        bottom: style.paddingBottom,
        left: style.paddingLeft,
        right: style.paddingRight,
      ),
      decoration: BoxDecoration(
        color: _hexToColor(style.backgroundColor),
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: style.borderColor != null && style.borderWidth > 0
            ? Border.all(
                color: _hexToColor(style.borderColor!),
                width: style.borderWidth,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((child) {
          return child.when(
            text: (id, content, style) =>
                TextComponentRenderer(content: content, style: style),
            image: (id, url, alt, link, style) =>
                ImageComponentRenderer(url: url, alt: alt, link: link, style: style),
            button: (id, text, url, style) =>
                ButtonComponentRenderer(text: text, url: url, style: style),
            divider: (id, style) => DividerComponentRenderer(style: style),
            spacer: (id, height) => SpacerComponentRenderer(height: height),
            social: (id, links, style) =>
                SocialComponentRenderer(links: links, style: style),
            avatar: (id, imageUrl, alt, style) =>
                AvatarComponentRenderer(imageUrl: imageUrl, alt: alt, style: style),
            heading: (id, content, style) =>
                HeadingComponentRenderer(content: content, style: style),
            html: (id, htmlContent, style) =>
                HtmlComponentRenderer(htmlContent: htmlContent, style: style),
            container: (id, children, style) =>
                ContainerComponentRenderer(children: children, style: style),
          );
        }).toList(),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
