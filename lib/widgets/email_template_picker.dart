import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:bluebubbles/models/crm/email_template.dart';

Future<EmailTemplate?> showEmailTemplatePicker({
  required BuildContext context,
  required List<EmailTemplate> templates,
  EmailTemplate? initiallySelected,
}) {
  return showModalBottomSheet<EmailTemplate>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: _EmailTemplatePickerSheet(
          templates: templates,
          initiallySelected: initiallySelected,
        ),
      );
    },
  );
}

class _EmailTemplatePickerSheet extends StatefulWidget {
  const _EmailTemplatePickerSheet({
    required this.templates,
    this.initiallySelected,
  });

  final List<EmailTemplate> templates;
  final EmailTemplate? initiallySelected;

  @override
  State<_EmailTemplatePickerSheet> createState() => _EmailTemplatePickerSheetState();
}

class _EmailTemplatePickerSheetState extends State<_EmailTemplatePickerSheet> {
  late List<EmailTemplate> _filtered;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filtered = widget.templates;
  }

  void _handleSearch(String query) {
    setState(() {
      _query = query.trim();
      if (_query.isEmpty) {
        _filtered = widget.templates;
      } else {
        _filtered = widget.templates
            .where((template) => template.matchesQuery(_query))
            .toList(growable: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search templates',
                border: OutlineInputBorder(),
              ),
              onChanged: _handleSearch,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _query.isEmpty
                            ? 'No email templates are available yet.'
                            : 'No templates matched "$_query".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final template = _filtered[index];
                      final isSelected =
                          widget.initiallySelected?.templateKey == template.templateKey;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(template),
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.article_outlined,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(template.templateName),
                        subtitle: Text(
                          '${template.templateTypeLabel} • ${template.audienceLabel}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          tooltip: 'Preview template',
                          onPressed: () => _showPreview(template),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPreview(EmailTemplate template) {
    final html = md.markdownToHtml(
      template.body,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.templateName),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.subject,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Html(data: html),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pop(template);
            },
            icon: const Icon(Icons.check),
            label: const Text('Use Template'),
          ),
        ],
      ),
    );
  }
}
