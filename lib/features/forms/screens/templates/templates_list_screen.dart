import 'package:flutter/material.dart';
import '../../models/form_template_db.dart';
import '../../services/form_templates_service.dart';
import 'template_builder_screen.dart';

class TemplatesListScreen extends StatefulWidget {
  /// Callback when a template is selected (for use in form creation flow)
  final void Function(FormTemplateDb template)? onTemplateSelected;

  /// Whether this is being used as a picker (simplified UI)
  final bool pickerMode;

  const TemplatesListScreen({
    Key? key,
    this.onTemplateSelected,
    this.pickerMode = false,
  }) : super(key: key);

  @override
  State<TemplatesListScreen> createState() => _TemplatesListScreenState();
}

class _TemplatesListScreenState extends State<TemplatesListScreen>
    with AutomaticKeepAliveClientMixin {
  final _templatesService = FormTemplatesService();
  String _categoryFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.pickerMode
          ? AppBar(
              title: const Text('Select Template'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search templates...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', isMobile: isMobile),
                      const SizedBox(width: 8),
                      ...TemplateCategories.all.map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterChip(
                              category,
                              category,
                              isMobile: isMobile,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Templates list
          Expanded(
            child: StreamBuilder<List<FormTemplateDb>>(
              stream: _templatesService.watchTemplates(
                category: _categoryFilter == 'all' ? null : _categoryFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                var templates = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  templates = templates.where((t) {
                    return t.name.toLowerCase().contains(query) ||
                        (t.description?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }

                if (templates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.dashboard_customize_outlined,
                            size: isMobile ? 48 : 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No templates found'
                                : 'No templates yet',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (!widget.pickerMode) ...[
                            SizedBox(height: isMobile ? 12 : 16),
                            ElevatedButton.icon(
                              onPressed: _createNewTemplate,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Template'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: GridView.builder(
                    padding: EdgeInsets.all(padding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : (screenWidth < 900 ? 2 : 3),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isMobile ? 2.5 : 1.8,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return _TemplateCard(
                        template: template,
                        onTap: widget.pickerMode
                            ? () {
                                if (widget.onTemplateSelected != null) {
                                  widget.onTemplateSelected!(template);
                                }
                                Navigator.pop(context, template);
                              }
                            : () => _viewTemplate(template),
                        onEdit: widget.pickerMode ? null : () => _editTemplate(template),
                        onDuplicate: widget.pickerMode ? null : () => _duplicateTemplate(template),
                        onDelete: widget.pickerMode || template.isSystem
                            ? null
                            : () => _confirmDeleteTemplate(template),
                        pickerMode: widget.pickerMode,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.pickerMode
          ? null
          : FloatingActionButton(
              onPressed: _createNewTemplate,
              tooltip: 'Create Template',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isMobile = false}) {
    final isSelected = _categoryFilter == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 12 : 14),
      ),
      selected: isSelected,
      visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
      padding: isMobile ? const EdgeInsets.symmetric(horizontal: 4) : null,
      onSelected: (selected) {
        setState(() {
          _categoryFilter = selected ? value : 'all';
        });
      },
    );
  }

  void _createNewTemplate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplateBuilderScreen(),
      ),
    );
  }

  void _viewTemplate(FormTemplateDb template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateBuilderScreen(templateId: template.id),
      ),
    );
  }

  void _editTemplate(FormTemplateDb template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateBuilderScreen(templateId: template.id),
      ),
    );
  }

  Future<void> _duplicateTemplate(FormTemplateDb template) async {
    try {
      await _templatesService.duplicateTemplate(template.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${template.name}" duplicated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteTemplate(FormTemplateDb template) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${template.name}"?'),
            if (template.useCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This template has been used ${template.useCount} time${template.useCount == 1 ? '' : 's'}.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _templatesService.deleteTemplate(template.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Template deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete template: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final FormTemplateDb template;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final bool pickerMode;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.pickerMode = false,
  });

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'group_add':
        return Icons.group_add;
      case 'event':
        return Icons.event;
      case 'feedback':
        return Icons.feedback;
      case 'poll':
        return Icons.poll;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'contact_mail':
        return Icons.contact_mail;
      case 'work':
        return Icons.work;
      case 'email':
        return Icons.email;
      case 'support_agent':
        return Icons.support_agent;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'card_membership':
        return Icons.card_membership;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(template.icon),
                      color: theme.colorScheme.onPrimaryContainer,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                template.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (template.isSystem) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'System',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (template.category != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            template.category!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!pickerMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'duplicate':
                            onDuplicate?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: ListTile(
                            leading: Icon(Icons.copy_outlined),
                            title: Text('Duplicate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (!template.isSystem)
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Delete', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              if (template.description != null && template.description!.isNotEmpty) ...[
                SizedBox(height: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    template.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: isMobile ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${template.useCount} uses',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (template.hasVariables)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code, size: 12, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text(
                            '${template.variables.length} vars',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
