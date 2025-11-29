import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';

class ComponentPalette extends StatelessWidget {
  const ComponentPalette({super.key});

  // Create component templates as static methods to avoid regenerating UUIDs
  static EmailComponent _createSpacerTemplate() => EmailComponent.spacer(
        id: const Uuid().v4(),
        height: 40,
      );

  static EmailComponent _createTextTemplate() => EmailComponent.text(
        id: const Uuid().v4(),
        content: 'Enter your text here...',
      );

  static EmailComponent _createImageTemplate() => EmailComponent.image(
        id: const Uuid().v4(),
        url: 'https://via.placeholder.com/600x300',
        alt: 'Placeholder image',
      );

  static EmailComponent _createButtonTemplate() => EmailComponent.button(
        id: const Uuid().v4(),
        text: 'Click Here',
        url: 'https://example.com',
      );

  static EmailComponent _createDividerTemplate() => EmailComponent.divider(
        id: const Uuid().v4(),
      );

  static EmailComponent _createSocialTemplate() => EmailComponent.social(
        id: const Uuid().v4(),
        links: const [
          SocialLink(
            platform: 'facebook',
            url: 'https://facebook.com',
          ),
          SocialLink(
            platform: 'twitter',
            url: 'https://twitter.com',
          ),
          SocialLink(
            platform: 'instagram',
            url: 'https://instagram.com',
          ),
        ],
      );

  // New email-builder-js block templates
  static EmailComponent _createAvatarTemplate() => EmailComponent.avatar(
        id: const Uuid().v4(),
        imageUrl: 'https://via.placeholder.com/80',
        alt: 'Avatar',
      );

  static EmailComponent _createHeadingTemplate() => EmailComponent.heading(
        id: const Uuid().v4(),
        content: 'Your Heading Here',
      );

  static EmailComponent _createHtmlTemplate() => EmailComponent.html(
        id: const Uuid().v4(),
        htmlContent: '<p>Your custom HTML here</p>',
      );

  static EmailComponent _createContainerTemplate() => EmailComponent.container(
        id: const Uuid().v4(),
        children: [],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Components',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ComponentCategory(
                title: 'Structure',
                components: [
                  _ComponentItem(
                    icon: Icons.view_day,
                    label: 'Section',
                    onTap: () => _addSection(context),
                  ),
                  _ComponentItem(
                    icon: Icons.view_column,
                    label: 'Columns',
                    onTap: () => _addColumnsSection(context),
                  ),
                  _ComponentItem(
                    icon: Icons.space_bar,
                    label: 'Spacer',
                    componentFactory: _createSpacerTemplate,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ComponentCategory(
                title: 'Content',
                components: [
                  _ComponentItem(
                    icon: Icons.title,
                    label: 'Heading',
                    componentFactory: _createHeadingTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.text_fields,
                    label: 'Text',
                    componentFactory: _createTextTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.image,
                    label: 'Image',
                    componentFactory: _createImageTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.account_circle,
                    label: 'Avatar',
                    componentFactory: _createAvatarTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.smart_button,
                    label: 'Button',
                    componentFactory: _createButtonTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.horizontal_rule,
                    label: 'Divider',
                    componentFactory: _createDividerTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.share,
                    label: 'Social',
                    componentFactory: _createSocialTemplate,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ComponentCategory(
                title: 'Advanced',
                components: [
                  _ComponentItem(
                    icon: Icons.code,
                    label: 'HTML',
                    componentFactory: _createHtmlTemplate,
                  ),
                  _ComponentItem(
                    icon: Icons.inbox,
                    label: 'Container',
                    componentFactory: _createContainerTemplate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addSection(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    provider.addSection();
  }

  void _addColumnsSection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ColumnLayoutDialog(),
    );
  }
}

class _ComponentCategory extends StatelessWidget {
  final String title;
  final List<_ComponentItem> components;

  const _ComponentCategory({
    required this.title,
    required this.components,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...components,
      ],
    );
  }
}

class _ComponentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final EmailComponent Function()? componentFactory;
  final VoidCallback? onTap;

  const _ComponentItem({
    required this.icon,
    required this.label,
    this.componentFactory,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If there's no component factory, only show the click handler (for Section and Columns)
    if (componentFactory == null) {
      return InkWell(
        onTap: onTap,
        child: _buildCard(context),
      );
    }

    // For actual components, make them draggable
    final feedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 140,
        height: 70,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    final draggable = Draggable<EmailComponent>(
      data: componentFactory!(),
      feedback: feedback,
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildCard(context),
      ),
      child: _buildCard(context),
    );

    final useLongPress = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (useLongPress) {
      return LongPressDraggable<EmailComponent>(
        data: componentFactory!(),
        feedback: feedback,
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: _buildCard(context),
        ),
        child: _buildCard(context),
      );
    }

    return draggable;
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnLayoutDialog extends StatelessWidget {
  const _ColumnLayoutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B), // slate color for dark theme
      title: const Text(
        'Select Column Layout',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayoutOption(
            label: 'Single Column',
            columns: const [1],
            onTap: () => _createSection(context, const [1]),
          ),
          _LayoutOption(
            label: 'Two Columns (Equal)',
            columns: const [1, 1],
            onTap: () => _createSection(context, const [1, 1]),
          ),
          _LayoutOption(
            label: 'Two Columns (1:2)',
            columns: const [1, 2],
            onTap: () => _createSection(context, const [1, 2]),
          ),
          _LayoutOption(
            label: 'Two Columns (2:1)',
            columns: const [2, 1],
            onTap: () => _createSection(context, const [2, 1]),
          ),
          _LayoutOption(
            label: 'Three Columns',
            columns: const [1, 1, 1],
            onTap: () => _createSection(context, const [1, 1, 1]),
          ),
        ],
      ),
    );
  }

  void _createSection(BuildContext context, List<int> columnFlexes) {
    final provider = context.read<EmailBuilderProvider>();
    final uuid = const Uuid();

    final section = EmailSection(
      id: uuid.v4(),
      columns: columnFlexes
          .map(
            (flex) => EmailColumn(
              id: uuid.v4(),
              flex: flex,
            ),
          )
          .toList(),
    );

    final sections = List<EmailSection>.from(provider.document.sections);
    sections.add(section);
    provider.loadDocument(provider.document.copyWith(sections: sections));

    Navigator.pop(context);
  }
}

class _LayoutOption extends StatelessWidget {
  final String label;
  final List<int> columns;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.label,
    required this.columns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // darkNavy
          border: Border.all(color: const Color(0xFF334155)), // slateLight
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: columns
                  .map(
                    (flex) => Flexible(
                      flex: flex,
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.5),
                          border:
                              Border.all(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
