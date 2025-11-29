import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';

class ComponentPalette extends StatelessWidget {
  const ComponentPalette({super.key});

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
                    component: EmailComponent.spacer(
                      id: const Uuid().v4(),
                      height: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ComponentCategory(
                title: 'Content',
                components: [
                  _ComponentItem(
                    icon: Icons.text_fields,
                    label: 'Text',
                    component: EmailComponent.text(
                      id: const Uuid().v4(),
                      content: 'Enter your text here...',
                    ),
                  ),
                  _ComponentItem(
                    icon: Icons.image,
                    label: 'Image',
                    component: EmailComponent.image(
                      id: const Uuid().v4(),
                      url: 'https://via.placeholder.com/600x300',
                      alt: 'Placeholder image',
                    ),
                  ),
                  _ComponentItem(
                    icon: Icons.smart_button,
                    label: 'Button',
                    component: EmailComponent.button(
                      id: const Uuid().v4(),
                      text: 'Click Here',
                      url: 'https://example.com',
                    ),
                  ),
                  _ComponentItem(
                    icon: Icons.horizontal_rule,
                    label: 'Divider',
                    component: EmailComponent.divider(
                      id: const Uuid().v4(),
                    ),
                  ),
                  _ComponentItem(
                    icon: Icons.share,
                    label: 'Social',
                    component: EmailComponent.social(
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
                    ),
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
  final EmailComponent? component;
  final VoidCallback? onTap;

  const _ComponentItem({
    required this.icon,
    required this.label,
    this.component,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If there's no component, only show the click handler (for Section and Columns)
    if (component == null) {
      return InkWell(
        onTap: onTap,
        child: _buildCard(context),
      );
    }

    // For actual components, make them draggable
    return Draggable<EmailComponent>(
      data: component,
      feedback: Material(
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
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildCard(context),
      ),
      child: InkWell(
        onTap: onTap,
        child: _buildCard(context),
      ),
    );
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
      title: const Text('Select Column Layout'),
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
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                              Theme.of(context).primaryColor.withOpacity(0.3),
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
