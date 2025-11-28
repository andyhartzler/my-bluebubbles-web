import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import 'color_picker_field.dart';
import '../../widgets/image_asset_manager.dart';
import 'merge_tag_picker_dialog.dart';

class EnhancedPropertiesPanel extends StatelessWidget {
  const EnhancedPropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Properties',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Content based on selection
          Expanded(
            child: _buildContent(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(EmailBuilderProvider provider) {
    if (provider.selectedComponentId != null) {
      return _ComponentPropertiesPanel(
        componentId: provider.selectedComponentId!,
      );
    } else if (provider.selectedSectionId != null) {
      return _SectionPropertiesPanel(
        sectionId: provider.selectedSectionId!,
      );
    } else {
      return const _DocumentPropertiesPanel();
    }
  }
}

class _ComponentPropertiesPanel extends StatelessWidget {
  final String componentId;

  const _ComponentPropertiesPanel({required this.componentId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

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
          );
          if (id == componentId) {
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
      text: (id, content, style) => _TabbedTextComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as TextComponent,
      ),
      image: (id, url, alt, link, style) => _TabbedImageComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as ImageComponent,
      ),
      button: (id, text, url, style) => _TabbedButtonComponentProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as ButtonComponent,
      ),
      divider: (id, style) => _SimpleDividerProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as DividerComponent,
      ),
      spacer: (id, height) => _SimpleSpacerProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as SpacerComponent,
      ),
      social: (id, links, style) => _SimpleSocialProperties(
        sectionId: sectionId!,
        columnId: columnId!,
        component: selectedComponent as SocialComponent,
      ),
    );
  }
}

// Tabbed Text Component Properties
class _TabbedTextComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final TextComponent component;

  const _TabbedTextComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Content'),
              Tab(text: 'Style'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TextContentTab(
                  sectionId: sectionId,
                  columnId: columnId,
                  component: component,
                ),
                _TextStyleTab(
                  sectionId: sectionId,
                  columnId: columnId,
                  component: component,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextContentTab extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final TextComponent component;

  const _TextContentTab({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final textController = TextEditingController(text: component.content);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Text Content',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              OutlinedButton.icon(
                onPressed: () => _showMergeTagPicker(context, textController),
                icon: const Icon(Icons.label_outline, size: 18),
                label: const Text('Insert Merge Tag'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Text input
          TextField(
            controller: textController,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter your text...',
            ),
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(content: value),
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick style presets
          Text('Quick Styles', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StylePresetChip(
                label: 'Heading 1',
                onTap: () => _applyPreset(context, 'h1'),
              ),
              _StylePresetChip(
                label: 'Heading 2',
                onTap: () => _applyPreset(context, 'h2'),
              ),
              _StylePresetChip(
                label: 'Paragraph',
                onTap: () => _applyPreset(context, 'p'),
              ),
              _StylePresetChip(
                label: 'Caption',
                onTap: () => _applyPreset(context, 'caption'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyPreset(BuildContext context, String preset) {
    final provider = context.read<EmailBuilderProvider>();
    TextComponentStyle newStyle;

    switch (preset) {
      case 'h1':
        newStyle = component.style.copyWith(
          fontSize: 32,
          bold: true,
          lineHeight: 1.2,
        );
        break;
      case 'h2':
        newStyle = component.style.copyWith(
          fontSize: 24,
          bold: true,
          lineHeight: 1.3,
        );
        break;
      case 'p':
        newStyle = component.style.copyWith(
          fontSize: 16,
          bold: false,
          lineHeight: 1.5,
        );
        break;
      case 'caption':
        newStyle = component.style.copyWith(
          fontSize: 12,
          color: '#666666',
          lineHeight: 1.4,
        );
        break;
      default:
        return;
    }

    provider.updateComponent(
      sectionId,
      columnId,
      component.copyWith(style: newStyle),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied $preset style'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showMergeTagPicker(
      BuildContext context, TextEditingController textController) async {
    final mergeTag = await showDialog<MergeTag>(
      context: context,
      builder: (context) => const MergeTagPickerDialog(),
    );

    if (mergeTag != null) {
      // Insert merge tag at current cursor position
      final currentText = textController.text;
      final cursorPos = textController.selection.baseOffset;

      String newText;
      if (cursorPos == -1) {
        // No cursor position, append to end
        newText = '$currentText ${mergeTag.toMarkup()}';
      } else {
        // Insert at cursor position
        newText = currentText.substring(0, cursorPos) +
            mergeTag.toMarkup() +
            currentText.substring(cursorPos);
      }

      textController.text = newText;

      // Update the component
      final provider = context.read<EmailBuilderProvider>();
      provider.updateComponent(
        sectionId,
        columnId,
        component.copyWith(content: newText),
      );

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inserted ${mergeTag.label} merge tag'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

class _StylePresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StylePresetChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.blue[50],
      labelStyle: TextStyle(color: Colors.blue[700]),
    );
  }
}

class _TextStyleTab extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final TextComponent component;

  const _TextStyleTab({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font Size
          Text('Font Size: ${component.style.fontSize.toInt()}px',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: component.style.fontSize,
            min: 8,
            max: 72,
            divisions: 64,
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

          const SizedBox(height: 16),

          // Color
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

          // Alignment
          Text('Alignment', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'left', icon: Icon(Icons.format_align_left, size: 18)),
              ButtonSegment(
                  value: 'center',
                  icon: Icon(Icons.format_align_center, size: 18)),
              ButtonSegment(
                  value: 'right',
                  icon: Icon(Icons.format_align_right, size: 18)),
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

          // Text Formatting
          Text('Formatting', style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
            title: const Text('Bold'),
            value: component.style.bold,
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(
                  style: component.style.copyWith(bold: value),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Italic'),
            value: component.style.italic,
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(
                  style: component.style.copyWith(italic: value),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Underline'),
            value: component.style.underline,
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(
                  style: component.style.copyWith(underline: value),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Line Height
          Text('Line Height: ${component.style.lineHeight.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: component.style.lineHeight,
            min: 1.0,
            max: 3.0,
            divisions: 20,
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(
                  style: component.style.copyWith(lineHeight: value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Tabbed Image Component Properties
class _TabbedImageComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ImageComponent component;

  const _TabbedImageComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Content'),
              Tab(text: 'Style'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ImageContentTab(
                  sectionId: sectionId,
                  columnId: columnId,
                  component: component,
                ),
                _ImageStyleTab(
                  sectionId: sectionId,
                  columnId: columnId,
                  component: component,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageContentTab extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ImageComponent component;

  const _ImageContentTab({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          // Upload Image Button (NEW!)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showImagePicker(context, provider),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload from Library'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // OR divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),

          const SizedBox(height: 16),

          // Image URL
          TextField(
            controller: TextEditingController(text: component.url),
            decoration: const InputDecoration(
              labelText: 'Image URL',
              border: OutlineInputBorder(),
              hintText: 'https://example.com/image.jpg',
              helperText: 'Enter a direct URL to an image',
            ),
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(url: value),
              );
            },
          ),

          const SizedBox(height: 16),

          // Alt Text
          TextField(
            controller: TextEditingController(text: component.alt ?? ''),
            decoration: const InputDecoration(
              labelText: 'Alt Text',
              border: OutlineInputBorder(),
              hintText: 'Describe the image...',
            ),
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(alt: value),
              );
            },
          ),

          const SizedBox(height: 16),

          // Link
          TextField(
            controller: TextEditingController(text: component.link ?? ''),
            decoration: const InputDecoration(
              labelText: 'Link URL (optional)',
              border: OutlineInputBorder(),
              hintText: 'https://example.com',
            ),
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(link: value.isEmpty ? null : value),
              );
            },
          ),
        ],
      ),
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

class _ImageStyleTab extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ImageComponent component;

  const _ImageStyleTab({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alignment
          Text('Alignment', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'left', label: Text('Left')),
              ButtonSegment(value: 'center', label: Text('Center')),
              ButtonSegment(value: 'right', label: Text('Right')),
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

          // Border Radius
          Text(
              'Border Radius: ${component.style.borderRadius.toInt()}px',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: component.style.borderRadius,
            min: 0,
            max: 50,
            divisions: 50,
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
        ],
      ),
    );
  }
}

// Tabbed Button Component Properties
class _TabbedButtonComponentProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ButtonComponent component;

  const _TabbedButtonComponentProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Content'),
              Tab(text: 'Style'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ButtonContentTab(
                  sectionId: sectionId,
                  columnId: columnId,
                  component: component,
                ),
                _ButtonStyleTab(
                  sectionId: sectionId,
                  columnId: columnId,
                  component: component,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonContentTab extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ButtonComponent component;

  const _ButtonContentTab({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Button Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          // Button Text
          TextField(
            controller: TextEditingController(text: component.text),
            decoration: const InputDecoration(
              labelText: 'Button Text',
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

          const SizedBox(height: 16),

          // Button URL
          TextField(
            controller: TextEditingController(text: component.url),
            decoration: const InputDecoration(
              labelText: 'Link URL',
              border: OutlineInputBorder(),
              hintText: 'https://example.com',
            ),
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(url: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ButtonStyleTab extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final ButtonComponent component;

  const _ButtonStyleTab({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background Color
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

          const SizedBox(height: 16),

          // Text Color
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

          const SizedBox(height: 16),

          // Border Radius
          Text(
              'Border Radius: ${component.style.borderRadius.toInt()}px',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: component.style.borderRadius,
            min: 0,
            max: 50,
            divisions: 50,
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

          const SizedBox(height: 16),

          // Alignment
          Text('Alignment', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'left', label: Text('Left')),
              ButtonSegment(value: 'center', label: Text('Center')),
              ButtonSegment(value: 'right', label: Text('Right')),
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
        ],
      ),
    );
  }
}

// Simple properties for other components (can be enhanced later)
class _SimpleDividerProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final DividerComponent component;

  const _SimpleDividerProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Divider Settings',
              style: Theme.of(context).textTheme.titleMedium),
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
        ],
      ),
    );
  }
}

class _SimpleSpacerProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final SpacerComponent component;

  const _SimpleSpacerProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spacer Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Height: ${component.height.toInt()}px',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: component.height,
            min: 10,
            max: 200,
            divisions: 19,
            onChanged: (value) {
              provider.updateComponent(
                sectionId,
                columnId,
                component.copyWith(height: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SimpleSocialProperties extends StatelessWidget {
  final String sectionId;
  final String columnId;
  final SocialComponent component;

  const _SimpleSocialProperties({
    required this.sectionId,
    required this.columnId,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Social Links Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...component.links.map((link) {
            return ListTile(
              leading: Icon(_getSocialIcon(link.platform)),
              title: Text(link.platform.toUpperCase()),
              subtitle: Text(link.url),
            );
          }).toList(),
        ],
      ),
    );
  }

  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'twitter':
        return Icons.flutter_dash; // Twitter icon placeholder
      case 'instagram':
        return Icons.camera_alt;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.link;
    }
  }
}

class _SectionPropertiesPanel extends StatelessWidget {
  final String sectionId;

  const _SectionPropertiesPanel({required this.sectionId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();
    final section = provider.document.sections
        .firstWhere((s) => s.id == sectionId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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
          _buildPaddingSlider(
            context,
            'Top',
            section.style.paddingTop,
            (value) {
              provider.updateSectionStyle(
                section.id,
                section.style.copyWith(paddingTop: value),
              );
            },
          ),
          _buildPaddingSlider(
            context,
            'Bottom',
            section.style.paddingBottom,
            (value) {
              provider.updateSectionStyle(
                section.id,
                section.style.copyWith(paddingBottom: value),
              );
            },
          ),
          _buildPaddingSlider(
            context,
            'Left',
            section.style.paddingLeft,
            (value) {
              provider.updateSectionStyle(
                section.id,
                section.style.copyWith(paddingLeft: value),
              );
            },
          ),
          _buildPaddingSlider(
            context,
            'Right',
            section.style.paddingRight,
            (value) {
              provider.updateSectionStyle(
                section.id,
                section.style.copyWith(paddingRight: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaddingSlider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}px'),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DocumentPropertiesPanel extends StatelessWidget {
  const _DocumentPropertiesPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmailBuilderProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Document Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ColorPickerField(
            label: 'Background Color',
            value: provider.document.settings.backgroundColor,
            onChanged: (color) {
              provider.loadDocument(
                provider.document.copyWith(
                  settings:
                      provider.document.settings.copyWith(backgroundColor: color),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
