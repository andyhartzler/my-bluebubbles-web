import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/email_component.dart';
import '../providers/email_builder_provider.dart';
import 'color_picker_field.dart';
import '../../widgets/image_asset_manager.dart';
import '../../widgets/ai_content_assistant.dart';

Future<void> _openAIContentAssistant(
  BuildContext context,
  EmailBuilderProvider provider, {
  required String sectionId,
  required String columnId,
  required EmailComponent component,
  String successMessage = 'Content inserted from AI assistant',
}) async {
  final generatedContent = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        child: SizedBox(
          width: 520,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AIContentAssistant(
              onContentGenerated: (content) {
                Navigator.of(dialogContext).pop(content);
              },
            ),
          ),
        ),
      );
    },
  );

  if (generatedContent == null || generatedContent.isEmpty) return;

  provider.updateComponent(
    sectionId,
    columnId,
    component.copyWith(content: generatedContent),
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }
}

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Properties',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildPropertiesContent(context, provider),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertiesContent(
    BuildContext context,
    EmailBuilderProvider provider,
  ) {
    if (provider.selectedComponentId != null) {
      return _buildComponentProperties(context, provider);
    } else if (provider.selectedSectionId != null) {
      return _buildSectionProperties(context, provider);
    } else {
      return _buildDocumentProperties(context, provider);
    }
  }

  Widget _buildComponentProperties(
    BuildContext context,
    EmailBuilderProvider provider,
  ) {
    EmailComponent? selectedComponent;
    String? sectionId;
    String? columnId;

    for (final section in provider.document.sections) {
      for (final column in section.columns) {
        for (final component in column.components) {
          final id = component.when(
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
          if (id == provider.selectedComponentId) {
            selectedComponent = component;
            sectionId = section.id;
            columnId = column.id;
            break;
          }
        }
      }
    }

    if (selectedComponent == null || sectionId == null || columnId == null) {
      return const Center(child: Text('Component not found'));
    }

    return selectedComponent.when(
      text: (id, content, style) => _TextComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as TextComponent,
      ),
      image: (id, url, alt, link, style) => _ImageComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as ImageComponent,
      ),
      button: (id, text, url, style) => _ButtonComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as ButtonComponent,
      ),
      divider: (id, style) => _DividerComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as DividerComponent,
      ),
      spacer: (id, height) => _SpacerComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as SpacerComponent,
      ),
      social: (id, links, style) => _SocialComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as SocialComponent,
      ),
      avatar: (id, imageUrl, alt, style) => _AvatarComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as AvatarComponent,
      ),
      heading: (id, content, style) => _HeadingComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as HeadingComponent,
      ),
      html: (id, htmlContent, style) => _HtmlComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as HtmlComponent,
      ),
      container: (id, children, style) => _ContainerComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as ContainerComponent,
      ),
    );
  }

  Widget _buildPlaceholderProperties(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionProperties(
    BuildContext context,
    EmailBuilderProvider provider,
  ) {
    final section = provider.document.sections
        .firstWhere((s) => s.id == provider.selectedSectionId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Section Settings',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ColorPickerField(
          label: 'Background Color',
          value: section.style.backgroundColor,
          onChanged: (color) {
            provider.updateSectionStyle(
              section.id,
              section.style.copyWith(backgroundColor: color),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Padding', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildSlider(
          label: 'Top',
          value: section.style.paddingTop,
          onChanged: (value) {
            provider.updateSectionStyle(
              section.id,
              section.style.copyWith(paddingTop: value),
            );
          },
        ),
        _buildSlider(
          label: 'Bottom',
          value: section.style.paddingBottom,
          onChanged: (value) {
            provider.updateSectionStyle(
              section.id,
              section.style.copyWith(paddingBottom: value),
            );
          },
        ),
        _buildSlider(
          label: 'Left',
          value: section.style.paddingLeft,
          onChanged: (value) {
            provider.updateSectionStyle(
              section.id,
              section.style.copyWith(paddingLeft: value),
            );
          },
        ),
        _buildSlider(
          label: 'Right',
          value: section.style.paddingRight,
          onChanged: (value) {
            provider.updateSectionStyle(
              section.id,
              section.style.copyWith(paddingRight: value),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Columns', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...section.columns.asMap().entries.map((entry) {
          final column = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Column ${entry.key + 1}',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: 'Flex',
                    value: column.flex.toDouble(),
                    min: 1,
                    max: 3,
                    onChanged: (value) => provider.updateColumnFlex(
                      section.id,
                      column.id,
                      value.toInt(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ColorPickerField(
                    label: 'Background',
                    value: column.style.backgroundColor,
                    onChanged: (color) => provider.updateColumnStyle(
                      section.id,
                      column.id,
                      column.style.copyWith(backgroundColor: color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSlider(
                    label: 'Padding',
                    value: column.style.padding,
                    max: 40,
                    onChanged: (value) => provider.updateColumnStyle(
                      section.id,
                      column.id,
                      column.style.copyWith(padding: value),
                    ),
                  ),
                  _buildSlider(
                    label: 'Border Radius',
                    value: column.style.borderRadius,
                    max: 32,
                    onChanged: (value) => provider.updateColumnStyle(
                      section.id,
                      column.id,
                      column.style.copyWith(borderRadius: value),
                    ),
                  ),
                  _buildSlider(
                    label: 'Border Width',
                    value: column.style.borderWidth,
                    max: 8,
                    onChanged: (value) => provider.updateColumnStyle(
                      section.id,
                      column.id,
                      column.style.copyWith(borderWidth: value),
                    ),
                  ),
                  ColorPickerField(
                    label: 'Border Color',
                    value: column.style.borderColor ?? '#d1d5db',
                    onChanged: (color) => provider.updateColumnStyle(
                      section.id,
                      column.id,
                      column.style.copyWith(borderColor: color),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDocumentProperties(
    BuildContext context,
    EmailBuilderProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Document Settings',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text('Select a section or component to edit its properties'),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TextComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final TextComponent component;

  const _TextComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Text Component', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: component.content,
          decoration: const InputDecoration(
            labelText: 'Content',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(content: value),
            );
          },
        ),
        const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openAIContentAssistant(
              context,
              provider,
              sectionId: sectionId,
              columnId: columnId,
              component: component,
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI Content Assistant'),
          ),
        const SizedBox(height: 16),
        _buildSlider(
          label: 'Font Size',
          value: component.style.fontSize,
          min: 8,
          max: 72,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(fontSize: value),
              ),
            );
          },
        ),
        ColorPickerField(
          label: 'Text Color',
          value: component.style.color,
          onChanged: (color) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(color: color),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Alignment', style: Theme.of(context).textTheme.titleSmall),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
            ButtonSegment(
                value: 'center', icon: Icon(Icons.format_align_center)),
            ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right)),
          ],
          selected: {component.style.alignment},
          onSelectionChanged: (selected) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(alignment: selected.first),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Style', style: Theme.of(context).textTheme.titleSmall),
        CheckboxListTile(
          title: const Text('Bold'),
          value: component.style.bold,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(bold: value ?? false),
              ),
            );
          },
        ),
        CheckboxListTile(
          title: const Text('Italic'),
          value: component.style.italic,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(italic: value ?? false),
              ),
            );
          },
        ),
        CheckboxListTile(
          title: const Text('Underline'),
          value: component.style.underline,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(underline: value ?? false),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ImageComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ImageComponent component;

  const _ImageComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image Component', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showImagePicker(context, provider),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload or Select Image'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Use the library above or paste a direct link to your image.',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.url,
          decoration: const InputDecoration(
            labelText: 'Image URL',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(url: value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.alt,
          decoration: const InputDecoration(
            labelText: 'Alt text',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(alt: value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.link,
          decoration: const InputDecoration(
            labelText: 'Link (optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(link: value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.style.width,
          decoration: const InputDecoration(
            labelText: 'Width (e.g., 100% or 300px)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(style: component.style.copyWith(width: value)),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.style.height,
          decoration: const InputDecoration(
            labelText: 'Height (optional, e.g., 200px)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style
                    .copyWith(height: value.isEmpty ? null : value),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Border Radius',
          value: component.style.borderRadius,
          max: 50,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(borderRadius: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Padding Top',
          value: component.style.paddingTop,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(paddingTop: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Padding Bottom',
          value: component.style.paddingBottom,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(paddingBottom: value),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showImagePicker(BuildContext context, EmailBuilderProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 900,
          child: ImageAssetManager(
            onImageSelected: (imageUrl) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(url: imageUrl),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ButtonComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ButtonComponent component;

  const _ButtonComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Button Component',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: component.text,
          decoration: const InputDecoration(
            labelText: 'Button text',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(text: value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.url,
          decoration: const InputDecoration(
            labelText: 'Link URL',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(url: value),
            );
          },
        ),
        const SizedBox(height: 12),
        ColorPickerField(
          label: 'Background Color',
          value: component.style.backgroundColor,
          onChanged: (color) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(backgroundColor: color),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ColorPickerField(
          label: 'Text Color',
          value: component.style.textColor,
          onChanged: (color) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(textColor: color),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Font Size',
          value: component.style.fontSize,
          min: 8,
          max: 48,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(fontSize: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Border Radius',
          value: component.style.borderRadius,
          max: 30,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(borderRadius: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Padding Vertical',
          value: component.style.paddingVertical,
          max: 40,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(paddingVertical: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Padding Horizontal',
          value: component.style.paddingHorizontal,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(paddingHorizontal: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Margin Top',
          value: component.style.marginTop,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(marginTop: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Margin Bottom',
          value: component.style.marginBottom,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(marginBottom: value),
              ),
            );
          },
        ),
        CheckboxListTile(
          title: const Text('Bold text'),
          value: component.style.bold,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(bold: value ?? false),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DividerComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final DividerComponent component;

  const _DividerComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Divider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ColorPickerField(
          label: 'Color',
          value: component.style.color,
          onChanged: (color) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(color: color),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Thickness',
          value: component.style.thickness,
          max: 10,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(thickness: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Margin Top',
          value: component.style.marginTop,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(marginTop: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Margin Bottom',
          value: component.style.marginBottom,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(marginBottom: value),
              ),
            );
          },
        ),
        DropdownButtonFormField<String>(
          value: component.style.style,
          decoration: const InputDecoration(
            labelText: 'Style',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'solid', child: Text('Solid')),
            DropdownMenuItem(value: 'dashed', child: Text('Dashed')),
            DropdownMenuItem(value: 'dotted', child: Text('Dotted')),
          ],
          onChanged: (value) {
            if (value == null) return;
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(style: component.style.copyWith(style: value)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SpacerComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final SpacerComponent component;

  const _SpacerComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spacer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Height',
          value: component.height,
          max: 200,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(height: value),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SocialComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final SocialComponent component;

  const _SocialComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Social Links', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...component.links.asMap().entries.map((entry) {
          final index = entry.key;
          final link = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link ${index + 1}',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: link.platform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final updatedLinks = [...component.links];
                      updatedLinks[index] = link.copyWith(platform: value);
                      provider.updateComponent(
                        sectionId,
                        columnId,
                        component.copyWith(links: updatedLinks),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: link.url,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final updatedLinks = [...component.links];
                      updatedLinks[index] = link.copyWith(url: value);
                      provider.updateComponent(
                        sectionId,
                        columnId,
                        component.copyWith(links: updatedLinks),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        _buildSlider(
          label: 'Icon Size',
          value: component.style.iconSize,
          min: 16,
          max: 64,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(iconSize: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Spacing',
          value: component.style.spacing,
          max: 40,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(spacing: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Margin Top',
          value: component.style.marginTop,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(marginTop: value),
              ),
            );
          },
        ),
        _buildSlider(
          label: 'Margin Bottom',
          value: component.style.marginBottom,
          max: 60,
          onChanged: (value) {
            provider.updateComponent(
              sectionId,
              columnId,
              component.copyWith(
                style: component.style.copyWith(marginBottom: value),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AvatarComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final AvatarComponent component;

  const _AvatarComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avatar', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.imageUrl,
          decoration: const InputDecoration(
            labelText: 'Image URL',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(imageUrl: value),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.alt,
          decoration: const InputDecoration(
            labelText: 'Alt text',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(alt: value),
          ),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Size',
          value: component.style.size,
          min: 40,
          max: 200,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(size: value)),
          ),
        ),
        SwitchListTile(
          value: component.style.shape,
          title: const Text('Circle avatar'),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(shape: value)),
          ),
        ),
        DropdownButtonFormField<String>(
          value: component.style.alignment,
          decoration: const InputDecoration(labelText: 'Alignment'),
          items: const [
            DropdownMenuItem(value: 'left', child: Text('Left')),
            DropdownMenuItem(value: 'center', child: Text('Center')),
            DropdownMenuItem(value: 'right', child: Text('Right')),
          ],
          onChanged: (value) {
            if (value != null) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(style: component.style.copyWith(alignment: value)),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Border Width',
          value: component.style.borderWidth,
          max: 12,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(borderWidth: value),
            ),
          ),
        ),
        ColorPickerField(
          label: 'Border Color',
          value: component.style.borderColor ?? '#d1d5db',
          onChanged: (color) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(borderColor: color)),
          ),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Padding Top',
          value: component.style.paddingTop,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingTop: value),
            ),
          ),
        ),
        _buildSlider(
          label: 'Padding Bottom',
          value: component.style.paddingBottom,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingBottom: value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _HeadingComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final HeadingComponent component;

  const _HeadingComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Heading', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: component.content,
          decoration: const InputDecoration(
            labelText: 'Content',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(content: value),
          ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openAIContentAssistant(
              context,
              provider,
              sectionId: sectionId,
              columnId: columnId,
              component: component,
              successMessage: 'Heading updated with AI suggestion',
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI Content Assistant'),
          ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Font Size',
          value: component.style.fontSize,
          min: 18,
          max: 64,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(fontSize: value)),
          ),
        ),
        _buildSlider(
          label: 'Line Height',
          value: component.style.lineHeight,
          min: 1,
          max: 2.5,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(lineHeight: value)),
          ),
        ),
        ColorPickerField(
          label: 'Text Color',
          value: component.style.color,
          onChanged: (color) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(color: color)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: component.style.alignment,
          decoration: const InputDecoration(labelText: 'Alignment'),
          items: const [
            DropdownMenuItem(value: 'left', child: Text('Left')),
            DropdownMenuItem(value: 'center', child: Text('Center')),
            DropdownMenuItem(value: 'right', child: Text('Right')),
            DropdownMenuItem(value: 'justify', child: Text('Justify')),
          ],
          onChanged: (value) {
            if (value != null) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(style: component.style.copyWith(alignment: value)),
              );
            }
          },
        ),
        CheckboxListTile(
          value: component.style.bold,
          title: const Text('Bold'),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(bold: value ?? false)),
          ),
        ),
        CheckboxListTile(
          value: component.style.italic,
          title: const Text('Italic'),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(italic: value ?? false)),
          ),
        ),
        CheckboxListTile(
          value: component.style.underline,
          title: const Text('Underline'),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(underline: value ?? false)),
          ),
        ),
        _buildSlider(
          label: 'Padding Top',
          value: component.style.paddingTop,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(paddingTop: value)),
          ),
        ),
        _buildSlider(
          label: 'Padding Bottom',
          value: component.style.paddingBottom,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingBottom: value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _HtmlComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final HtmlComponent component;

  const _HtmlComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HTML', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: component.htmlContent,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'HTML Content',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(htmlContent: value),
          ),
        ),
        const SizedBox(height: 12),
        _buildSlider(
          label: 'Padding Top',
          value: component.style.paddingTop,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(paddingTop: value)),
          ),
        ),
        _buildSlider(
          label: 'Padding Bottom',
          value: component.style.paddingBottom,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingBottom: value),
            ),
          ),
        ),
        _buildSlider(
          label: 'Padding Left',
          value: component.style.paddingLeft,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(paddingLeft: value)),
          ),
        ),
        _buildSlider(
          label: 'Padding Right',
          value: component.style.paddingRight,
          max: 40,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingRight: value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _ContainerComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ContainerComponent component;

  const _ContainerComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Container', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ColorPickerField(
          label: 'Background',
          value: component.style.backgroundColor,
          onChanged: (color) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(backgroundColor: color)),
          ),
        ),
        _buildSlider(
          label: 'Padding Top',
          value: component.style.paddingTop,
          max: 48,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(paddingTop: value)),
          ),
        ),
        _buildSlider(
          label: 'Padding Bottom',
          value: component.style.paddingBottom,
          max: 48,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingBottom: value),
            ),
          ),
        ),
        _buildSlider(
          label: 'Padding Left',
          value: component.style.paddingLeft,
          max: 48,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(paddingLeft: value)),
          ),
        ),
        _buildSlider(
          label: 'Padding Right',
          value: component.style.paddingRight,
          max: 48,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(
              style: component.style.copyWith(paddingRight: value),
            ),
          ),
        ),
        _buildSlider(
          label: 'Border Radius',
          value: component.style.borderRadius,
          max: 36,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(borderRadius: value)),
          ),
        ),
        _buildSlider(
          label: 'Border Width',
          value: component.style.borderWidth,
          max: 12,
          onChanged: (value) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(borderWidth: value)),
          ),
        ),
        ColorPickerField(
          label: 'Border Color',
          value: component.style.borderColor ?? '#d1d5db',
          onChanged: (color) => provider.updateComponent(
            sectionId,
            columnId,
            component.copyWith(style: component.style.copyWith(borderColor: color)),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
