import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import 'component_renderers.dart';

class _ComponentDragPayload {
  final EmailComponent? newComponent;
  final String? fromSectionId;
  final String? fromColumnId;
  final String? componentId;
  final int? fromIndex;

  const _ComponentDragPayload.newComponent(this.newComponent)
      : fromSectionId = null,
        fromColumnId = null,
        componentId = null,
        fromIndex = null;

  const _ComponentDragPayload.existing({
    required this.componentId,
    required this.fromSectionId,
    required this.fromColumnId,
    required this.fromIndex,
  }) : newComponent = null;

  bool get isExisting =>
      componentId != null && fromSectionId != null && fromColumnId != null;
}

String _componentId(EmailComponent component) {
  return component.when(
    text: (id, _, __) => id,
    image: (id, _, __, ___, ____) => id,
    button: (id, _, __, ___) => id,
    divider: (id, _) => id,
    spacer: (id, _) => id,
    social: (id, _, __) => id,
    avatar: (id, _, __, ___) => id,
    heading: (id, _, __) => id,
    html: (id, _, __) => id,
    container: (id, _, __) => id,
  );
}

class CanvasArea extends StatelessWidget {
  const CanvasArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();
    final document = provider.document;
    final maxWidth = provider.previewDevice == 'mobile' ? 375.0 : 600.0;
    final zoom = provider.zoomLevel;

    final focusNode = FocusNode();

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.delete): const _DeleteIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): const _DeleteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD):
            const _DuplicateIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD):
            const _DuplicateIntent(),
      },
      child: Actions(
        actions: {
          _DeleteIntent: CallbackAction<_DeleteIntent>(
            onInvoke: (_) => _handleDelete(provider),
          ),
          _DuplicateIntent: CallbackAction<_DuplicateIntent>(
            onInvoke: (_) => _handleDuplicate(provider),
          ),
        },
        child: Focus(
          autofocus: true,
          focusNode: focusNode,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F172A),
                  const Color(0xFF0F172A).withBlue(30),
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Transform.scale(
                  scale: zoom,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: provider.previewDevice == 'mobile'
                          ? 400
                          : document.settings.maxWidth.toDouble(),
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _hexToColor(document.settings.backgroundColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Empty state
                          if (document.sections.isEmpty)
                            _EmptyState(),

                          // Sections
                          ...document.sections.asMap().entries.map((entry) {
                            final index = entry.key;
                            final section = entry.value;
                            return _SectionWidget(
                              section: section,
                              isSelected:
                                  provider.selectedSectionId == section.id,
                              onTap: () => provider.selectSection(section.id),
                              onDelete: () => provider.deleteSection(section.id),
                              onDuplicate:
                                  () => provider.duplicateSection(section.id),
                              onMoveUp: index > 0
                                  ? () => provider.moveSectionUp(section.id)
                                  : null,
                              onMoveDown: index < document.sections.length - 1
                                  ? () => provider.moveSectionDown(section.id)
                                  : null,
                            );
                          }).toList(),

                          // Add section button
                          if (!provider.isPreviewMode)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddSectionDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Section'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddSectionDialog(),
    );
  }

  void _handleDelete(EmailBuilderProvider provider) {
    if (provider.selectedComponentId != null) {
      final selection = provider.findComponentById(provider.selectedComponentId!);
      if (selection != null) {
        provider.deleteComponent(
          selection.section.id,
          selection.column.id,
          provider.selectedComponentId!,
        );
      }
      return;
    }

    if (provider.selectedSectionId != null) {
      provider.deleteSection(provider.selectedSectionId!);
    }
  }

  void _handleDuplicate(EmailBuilderProvider provider) {
    if (provider.selectedComponentId != null) {
      final selection = provider.findComponentById(provider.selectedComponentId!);
      if (selection != null) {
        provider.duplicateComponent(
          selection.section.id,
          selection.column.id,
          provider.selectedComponentId!,
        );
      }
      return;
    }

    if (provider.selectedSectionId != null) {
      provider.duplicateSection(provider.selectedSectionId!);
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _DuplicateIntent extends Intent {
  const _DuplicateIntent();
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
    final children = <Widget>[];

    if (column.components.isEmpty) {
      children.add(_ComponentDropZone(
        sectionId: sectionId,
        columnId: column.id,
        insertIndex: 0,
        isEmpty: true,
      ));
    } else {
      for (final entry in column.components.asMap().entries) {
        children.add(_ComponentDropZone(
          sectionId: sectionId,
          columnId: column.id,
          insertIndex: entry.key,
        ));
        children.add(_ComponentWidget(
          sectionId: sectionId,
          columnId: column.id,
          component: entry.value,
          index: entry.key,
        ));
      }
      children.add(_ComponentDropZone(
        sectionId: sectionId,
        columnId: column.id,
        insertIndex: column.components.length,
      ));
    }

    return Container(
      margin: const EdgeInsets.all(4),
      padding: EdgeInsets.all(column.style.padding),
      decoration: BoxDecoration(
        color: _hexToColor(column.style.backgroundColor),
        borderRadius: BorderRadius.circular(column.style.borderRadius),
        border: column.style.borderWidth > 0 && column.style.borderColor != null
            ? Border.all(
                color: _hexToColor(column.style.borderColor!),
                width: column.style.borderWidth,
              )
            : null,
      ),
      child: Column(children: children),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class _ComponentDropZone extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final int insertIndex;
  final bool isEmpty;

  const _ComponentDropZone({
    required this.sectionId,
    required this.columnId,
    required this.insertIndex,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) =>
          !provider.isPreviewMode &&
          (details.data is EmailComponent ||
              details.data is _ComponentDragPayload),
      onAcceptWithDetails: (details) {
        final payload = details.data is _ComponentDragPayload
            ? details.data as _ComponentDragPayload
            : _ComponentDragPayload.newComponent(details.data as EmailComponent);

        if (payload.newComponent != null) {
          final newComponent = payload.newComponent!;
          context.read<EmailBuilderProvider>().insertComponent(
                sectionId,
                columnId,
                newComponent,
                insertIndex,
              );
          provider.selectComponent(_componentId(newComponent));
          return;
        }

        if (payload.isExisting &&
            payload.componentId != null &&
            payload.fromSectionId != null &&
            payload.fromColumnId != null) {
          context.read<EmailBuilderProvider>().moveComponent(
                payload.fromSectionId!,
                payload.fromColumnId!,
                sectionId,
                columnId,
                payload.componentId!,
                insertIndex,
              );
          provider.selectComponent(payload.componentId!);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.symmetric(vertical: isEmpty ? 8 : 4),
          padding: EdgeInsets.symmetric(vertical: isEmpty ? 18 : 6),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Theme.of(context).primaryColor.withOpacity(0.08)
                : Colors.transparent,
            border: Border.all(
              color: isHighlighted
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: isEmpty ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isEmpty
              ? Column(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: isHighlighted
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600]),
                    const SizedBox(height: 6),
                    Text(
                      'Drop components here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isHighlighted
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        );
      },
    );
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
    final componentId = _componentId(widget.component);
    final isSelected = provider.selectedComponentId == componentId;
    final canDrag = !provider.isPreviewMode;

    final card = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => provider.selectComponent(componentId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : _isHovered
                      ? Theme.of(context).primaryColor.withOpacity(0.35)
                      : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
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
                avatar: (id, imageUrl, alt, style) => AvatarComponentRenderer(
                  imageUrl: imageUrl,
                  alt: alt,
                  style: style,
                ),
                heading: (id, content, style) => HeadingComponentRenderer(
                  content: content,
                  style: style,
                ),
                html: (id, htmlContent, style) => HtmlComponentRenderer(
                  htmlContent: htmlContent,
                  style: style,
                ),
                container: (id, children, style) => ContainerComponentRenderer(
                  children: children,
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
                      const SizedBox(width: 4),
                      _ActionButton(
                        icon: Icons.control_point_duplicate,
                        onPressed: () => provider.duplicateComponent(
                          widget.sectionId,
                          widget.columnId,
                          componentId,
                        ),
                        tooltip: 'Duplicate',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!canDrag) {
      return card;
    }

    final payload = _ComponentDragPayload.existing(
      componentId: componentId,
      fromSectionId: widget.sectionId,
      fromColumnId: widget.columnId,
      fromIndex: widget.index,
    );

    return LongPressDraggable<_ComponentDragPayload>(
      data: payload,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Opacity(opacity: 0.9, child: card),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: card,
      ),
      child: card,
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();
    final theme = Theme.of(context);

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) =>
          !provider.isPreviewMode &&
          (details.data is EmailComponent ||
              details.data is _ComponentDragPayload),
      onAcceptWithDetails: (details) {
        final payload = details.data is _ComponentDragPayload
            ? details.data as _ComponentDragPayload
            : _ComponentDragPayload.newComponent(details.data as EmailComponent);
        final newSection = context.read<EmailBuilderProvider>().addSection();
        final newColumnId = newSection.columns.first.id;

        if (payload.newComponent != null) {
          context.read<EmailBuilderProvider>().insertComponent(
                newSection.id,
                newColumnId,
                payload.newComponent!,
                0,
              );
          provider.selectComponent(_componentId(payload.newComponent!));
          return;
        }

        if (payload.isExisting &&
            payload.componentId != null &&
            payload.fromSectionId != null &&
            payload.fromColumnId != null) {
          context.read<EmailBuilderProvider>().moveComponent(
                payload.fromSectionId!,
                payload.fromColumnId!,
                newSection.id,
                newColumnId,
                payload.componentId!,
                0,
              );
          provider.selectComponent(payload.componentId!);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(64),
          decoration: BoxDecoration(
            color: isHighlighted
                ? theme.primaryColor.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted
                  ? theme.primaryColor.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 80,
                color: isHighlighted
                    ? theme.primaryColor
                    : Colors.grey[600],
              ),
              const SizedBox(height: 24),
              Text(
                'Start building your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Drag content blocks from the left sidebar\nor click "Add Section" below',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _showAddSectionDialog(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Section'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddSectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddSectionDialog(),
    );
  }
}

class _AddSectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B), // slate color for dark theme
      title: const Text(
        'Add New Section',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a layout for your new section:',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 16),
            _LayoutOption(
              label: 'Single Column',
              description: 'Full width content',
              columns: const [1],
              onTap: () {
                Navigator.pop(context);
                context.read<EmailBuilderProvider>().addSectionWithLayout([1]);
              },
            ),
            _LayoutOption(
              label: 'Two Columns (Equal)',
              description: '50% / 50% split',
              columns: const [1, 1],
              onTap: () {
                Navigator.pop(context);
                context.read<EmailBuilderProvider>().addSectionWithLayout([1, 1]);
              },
            ),
            _LayoutOption(
              label: 'Two Columns (2:1)',
              description: '66% / 33% split',
              columns: const [2, 1],
              onTap: () {
                Navigator.pop(context);
                context.read<EmailBuilderProvider>().addSectionWithLayout([2, 1]);
              },
            ),
            _LayoutOption(
              label: 'Two Columns (1:2)',
              description: '33% / 66% split',
              columns: const [1, 2],
              onTap: () {
                Navigator.pop(context);
                context.read<EmailBuilderProvider>().addSectionWithLayout([1, 2]);
              },
            ),
            _LayoutOption(
              label: 'Three Columns',
              description: '33% / 33% / 33% split',
              columns: const [1, 1, 1],
              onTap: () {
                Navigator.pop(context);
                context.read<EmailBuilderProvider>().addSectionWithLayout([1, 1, 1]);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _LayoutOption extends StatefulWidget {
  final String label;
  final String description;
  final List<int> columns;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.label,
    required this.description,
    required this.columns,
    required this.onTap,
  });

  @override
  State<_LayoutOption> createState() => _LayoutOptionState();
}

class _LayoutOptionState extends State<_LayoutOption> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        color: const Color(0xFF0F172A), // darkNavy for card background
        elevation: _isHovered ? 4 : 1,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Visual layout preview
                Container(
                  width: 80,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF334155)), // slateLight
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: widget.columns.map((flex) {
                      return Expanded(
                        flex: flex,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white, // Ensure text is white
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8), // textTertiary
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF94A3B8), // textTertiary
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
