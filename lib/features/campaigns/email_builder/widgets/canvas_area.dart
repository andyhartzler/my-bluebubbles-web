import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import 'component_renderers.dart';

class CanvasArea extends StatelessWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();
    final document = provider.document;
    final maxWidth = provider.previewDevice == 'mobile' ? 375.0 : 600.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          width: maxWidth,
          decoration: BoxDecoration(
            color: _hexToColor(document.settings.backgroundColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ...document.sections.asMap().entries.map((entry) {
                final index = entry.key;
                final section = entry.value;
                return _SectionWidget(
                  section: section,
                  isSelected: provider.selectedSectionId == section.id,
                  onTap: () => provider.selectSection(section.id),
                  onDelete: () => provider.deleteSection(section.id),
                  onDuplicate: () => provider.duplicateSection(section.id),
                  onMoveUp: index > 0
                      ? () => provider.moveSectionUp(section.id)
                      : null,
                  onMoveDown: index < document.sections.length - 1
                      ? () => provider.moveSectionDown(section.id)
                      : null,
                );
              }).toList(),
              if (!provider.isPreviewMode)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: provider.addSection,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Section'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _SectionWidget extends StatefulWidget {
  final EmailSection section;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _SectionWidget({
    required this.section,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<_SectionWidget> createState() => _SectionWidgetState();
}

class _SectionWidgetState extends State<_SectionWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();
    final style = widget.section.style;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _hexToColor(style.backgroundColor),
            border: Border.all(
              color: widget.isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: style.paddingTop,
                  bottom: style.paddingBottom,
                  left: style.paddingLeft,
                  right: style.paddingRight,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.section.columns.map((column) {
                    return Expanded(
                      flex: column.flex,
                      child: _ColumnWidget(
                        sectionId: widget.section.id,
                        column: column,
                      ),
                    );
                  }).toList(),
                ),
              ),
              if ((_isHovered || widget.isSelected) && !provider.isPreviewMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onMoveUp != null)
                        _ActionButton(
                          icon: Icons.arrow_upward,
                          onPressed: widget.onMoveUp,
                          tooltip: 'Move Up',
                        ),
                      if (widget.onMoveDown != null)
                        _ActionButton(
                          icon: Icons.arrow_downward,
                          onPressed: widget.onMoveDown,
                          tooltip: 'Move Down',
                        ),
                      _ActionButton(
                        icon: Icons.content_copy,
                        onPressed: widget.onDuplicate,
                        tooltip: 'Duplicate',
                      ),
                      _ActionButton(
                        icon: Icons.delete,
                        onPressed: widget.onDelete,
                        tooltip: 'Delete',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _ColumnWidget extends StatelessWidget {
  final String sectionId;
  final EmailColumn column;

  const _ColumnWidget({
    required this.sectionId,
    required this.column,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return DragTarget<EmailComponent>(
      onAccept: (component) {
        if (component != null) {
          provider.addComponent(sectionId, column.id, component);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.all(4),
          padding: EdgeInsets.all(column.style.padding),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : _hexToColor(column.style.backgroundColor),
            border: Border.all(
              color: isHighlighted
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(column.style.borderRadius),
          ),
          child: column.components.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Drop components here',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: column.components.asMap().entries.map((entry) {
                    final index = entry.key;
                    final component = entry.value;
                    return _ComponentWidget(
                      sectionId: sectionId,
                      columnId: column.id,
                      component: component,
                      index: index,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _ComponentWidget extends StatefulWidget {
  final String sectionId;
  final String columnId;
  final EmailComponent component;
  final int index;

  const _ComponentWidget({
    required this.sectionId,
    required this.columnId,
    required this.component,
    required this.index,
  });

  @override
  State<_ComponentWidget> createState() => _ComponentWidgetState();
}

class _ComponentWidgetState extends State<_ComponentWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();
    final componentId = widget.component.when(
      text: (id, _, __) => id,
      image: (id, _, __, ___, ____) => id,
      button: (id, _, __, ___) => id,
      divider: (id, _) => id,
      spacer: (id, _) => id,
      social: (id, _, __) => id,
    );
    final isSelected = provider.selectedComponentId == componentId;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => provider.selectComponent(componentId),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              widget.component.when(
                text: (id, content, style) => TextComponentRenderer(
                  content: content,
                  style: style,
                ),
                image: (id, url, alt, link, style) => ImageComponentRenderer(
                  url: url,
                  alt: alt,
                  link: link,
                  style: style,
                ),
                button: (id, text, url, style) => ButtonComponentRenderer(
                  text: text,
                  url: url,
                  style: style,
                ),
                divider: (id, style) => DividerComponentRenderer(style: style),
                spacer: (id, height) => SpacerComponentRenderer(height: height),
                social: (id, links, style) => SocialComponentRenderer(
                  links: links,
                  style: style,
                ),
              ),
              if ((_isHovered || isSelected) && !provider.isPreviewMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(
                        icon: Icons.delete,
                        onPressed: () => provider.deleteComponent(
                          widget.sectionId,
                          widget.columnId,
                          componentId,
                        ),
                        tooltip: 'Delete',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: onPressed,
          color: color ?? Colors.grey[700],
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ),
    );
  }
}
