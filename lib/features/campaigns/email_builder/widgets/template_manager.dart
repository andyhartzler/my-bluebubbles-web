import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';
import '../models/email_document_extensions.dart';
import '../models/email_template.dart';
import '../services/template_storage_service.dart';
import '../../theme/campaign_builder_theme.dart';

class TemplateManager extends StatefulWidget {
  final EmailDocument currentDocument;

  const TemplateManager({super.key, required this.currentDocument});

  @override
  State<TemplateManager> createState() => _TemplateManagerState();
}

class _TemplateManagerState extends State<TemplateManager>
    with SingleTickerProviderStateMixin {
  final _storageService = TemplateStorageService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;
  bool _loading = true;
  List<EmailTemplate> _templates = [];
  late final List<EmailTemplate> _brandTemplates;

  @override
  void initState() {
    super.initState();
    _brandTemplates = _buildBrandTemplates();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    final results = await _storageService.fetchTemplates();
    setState(() {
      _templates = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        width: 960,
        height: 620,
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: CampaignBuilderTheme.slateLight),
            const TabBar(
              tabs: [
                Tab(text: 'Saved Templates'),
                Tab(text: 'Brand Defaults'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSavedTemplates(context),
                  _buildBrandTemplatesList(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: CampaignBuilderTheme.slate,
      child: Row(
        children: [
          const Icon(Icons.layers, color: CampaignBuilderTheme.brightBlue),
          const SizedBox(width: 12),
          const Text(
            'Templates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CampaignBuilderTheme.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _saving ? null : () => _saveCurrentTemplate(context),
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save Current Design'),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTemplates(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_off,
        title: 'No templates saved yet',
        message: 'Save your current design or load a Missouri Young Democrats starter.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        return _TemplateCard(
          template: template,
          onLoad: () {
            final doc = EmailDocument.fromJson(template.designJson);
            Navigator.pop(context, doc);
          },
          onDelete: null,
        );
      },
    );
  }

  Widget _buildBrandTemplatesList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _brandTemplates.length,
      itemBuilder: (context, index) {
        final template = _brandTemplates[index];
        return _TemplateCard(
          template: template,
          onLoad: () {
            final doc = EmailDocument.fromJson(template.designJson);
            Navigator.pop(context, doc);
          },
          accentColor: template.accentColor,
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: CampaignBuilderTheme.brightBlue),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CampaignBuilderTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentTemplate(BuildContext context) async {
    _nameController.text = 'MYD Template ${DateTime.now().month}/${DateTime.now().day}';
    _descriptionController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Template name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Short description (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    final saved = await _storageService.saveTemplate(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      document: widget.currentDocument,
      accentColor: CampaignBuilderTheme.moyDBlue,
    );

    setState(() => _saving = false);

    if (saved != null) {
      setState(() {
        _templates = [saved, ..._templates];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved to Supabase')), // ignore: use_build_context_synchronously
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save template right now.')), // ignore: use_build_context_synchronously
        );
      }
    }
  }

  List<EmailTemplate> _buildBrandTemplates() {
    final uuid = const Uuid();

    EmailDocument buildHeroLayout({
      required String headline,
      required String body,
      required String buttonColor,
      required String accent,
      required String background,
    }) {
      return EmailDocument(
        sections: [
          EmailSection(
            id: uuid.v4(),
            style: SectionStyle(
              backgroundColor: background,
              paddingTop: 32,
              paddingBottom: 24,
              paddingLeft: 28,
              paddingRight: 28,
            ),
            columns: [
              EmailColumn(
                id: uuid.v4(),
                components: [
                  EmailComponent.heading(
                    id: uuid.v4(),
                    content: headline,
                    style: const HeadingComponentStyle(
                      fontSize: 30,
                      color: '#ffffff',
                      bold: true,
                    ),
                  ),
                  EmailComponent.text(
                    id: uuid.v4(),
                    content: body,
                    style: const TextComponentStyle(
                      color: '#e5e7eb',
                      lineHeight: 1.6,
                    ),
                  ),
                  EmailComponent.button(
                    id: uuid.v4(),
                    text: 'Take Action',
                    url: 'https://moyd.org',
                    style: ButtonComponentStyle(
                      backgroundColor: buttonColor,
                      textColor: '#ffffff',
                      borderRadius: 10,
                      width: '200px',
                      paddingVertical: 14,
                      paddingHorizontal: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          EmailSection(
            id: uuid.v4(),
            style: SectionStyle(
              backgroundColor: '#ffffff',
              paddingTop: 28,
              paddingBottom: 28,
              paddingLeft: 28,
              paddingRight: 28,
            ),
            columns: [
              EmailColumn(
                id: uuid.v4(),
                components: [
                  EmailComponent.heading(
                    id: uuid.v4(),
                    content: 'Our Priorities',
                    style: HeadingComponentStyle(
                      fontSize: 22,
                      color: accent,
                      bold: true,
                    ),
                  ),
                  EmailComponent.text(
                    id: uuid.v4(),
                    content:
                        '• Register new voters across Missouri\n• Build diverse, youth-led coalitions\n• Train the next generation of candidates',
                    style: TextComponentStyle(
                      fontSize: 16,
                      lineHeight: 1.6,
                      color: '#111827',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    EmailDocument buildEventLayout() {
      return EmailDocument(
        sections: [
          EmailSection(
            id: uuid.v4(),
            style: const SectionStyle(
              backgroundColor: '#273351',
              paddingTop: 36,
              paddingBottom: 36,
              paddingLeft: 28,
              paddingRight: 28,
            ),
            columns: [
              EmailColumn(
                id: uuid.v4(),
                components: [
                  EmailComponent.text(
                    id: uuid.v4(),
                    content: 'Upcoming Event',
                    style: const TextComponentStyle(
                      color: '#FDB813',
                      fontSize: 14,
                      bold: true,
                    ),
                  ),
                  EmailComponent.heading(
                    id: uuid.v4(),
                    content: 'Meetup & Mobilize',
                    style: const HeadingComponentStyle(
                      fontSize: 28,
                      color: '#ffffff',
                      bold: true,
                    ),
                  ),
                  EmailComponent.text(
                    id: uuid.v4(),
                    content:
                        'Join the Missouri Young Democrats for a night of organizing, training, and community building. Food and drinks provided!',
                    style: const TextComponentStyle(
                      color: '#e5e7eb',
                      lineHeight: 1.6,
                    ),
                  ),
                  EmailComponent.button(
                    id: uuid.v4(),
                    text: 'RSVP Now',
                    url: 'https://moyd.org/rsvp',
                    style: const ButtonComponentStyle(
                      backgroundColor: '#32A6DE',
                      textColor: '#ffffff',
                      width: '200px',
                    ),
                  ),
                ],
              ),
            ],
          ),
          EmailSection(
            id: uuid.v4(),
            style: const SectionStyle(
              backgroundColor: '#ffffff',
              paddingTop: 24,
              paddingBottom: 24,
              paddingLeft: 28,
              paddingRight: 28,
            ),
            columns: [
              EmailColumn(
                id: uuid.v4(),
                components: [
                  EmailComponent.text(
                    id: uuid.v4(),
                    content: 'Speakers',
                    style: const TextComponentStyle(
                      color: '#273351',
                      fontSize: 16,
                      bold: true,
                    ),
                  ),
                  EmailComponent.text(
                    id: uuid.v4(),
                    content:
                        '• Local organizers on 2024 priorities\n• Campaign managers on winning field programs\n• Digital experts on mobilizing online',
                    style: const TextComponentStyle(
                      color: '#4b5563',
                      lineHeight: 1.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    final unityHero = buildHeroLayout(
      headline: 'We win together.',
      body: 'Grassroots power, bold organizing, and unapologetic youth leadership.',
      buttonColor: '#32A6DE',
      accent: '#273351',
      background: '#273351',
    );

    final sunrise = buildHeroLayout(
      headline: 'Show up. Speak out.',
      body: 'Your voice moves Missouri forward. Share your story and mobilize your community.',
      buttonColor: '#E63946',
      accent: '#FDB813',
      background: '#273351',
    );

    final mobilize = buildEventLayout();

    return [
      EmailTemplate.newTemplate(
        name: 'Unity Hero',
        description: 'Bold hero with MYD blues and clear CTA.',
        designJson: unityHero.toJson(),
        htmlContent: unityHero.toHtml(),
        accentColor: '#273351',
      ),
      EmailTemplate.newTemplate(
        name: 'Sunrise Rally',
        description: 'Optimistic layout using Sunrise Gold for highlight moments.',
        designJson: sunrise.toJson(),
        htmlContent: sunrise.toHtml(),
        accentColor: '#FDB813',
      ),
      EmailTemplate.newTemplate(
        name: 'Mobilize Event',
        description: 'Two-section announcement with RSVP CTA and speaker lineup.',
        designJson: mobilize.toJson(),
        htmlContent: mobilize.toHtml(),
        accentColor: '#32A6DE',
      ),
    ];
  }
}

class _TemplateCard extends StatelessWidget {
  final EmailTemplate template;
  final VoidCallback onLoad;
  final VoidCallback? onDelete;
  final String? accentColor;

  const _TemplateCard({
    required this.template,
    required this.onLoad,
    this.onDelete,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: CampaignBuilderTheme.slate,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 64,
              decoration: BoxDecoration(
                color: Color(_hexToColorInt(accentColor ?? template.accentColor ?? '#273351')),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CampaignBuilderTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template.description,
                    style: const TextStyle(color: CampaignBuilderTheme.textSecondary),
                  ),
                  if (template.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Updated ${template.updatedAt}',
                      style: const TextStyle(color: CampaignBuilderTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ElevatedButton.icon(
              onPressed: onLoad,
              icon: const Icon(Icons.download),
              label: const Text('Load'),
            ),
          ],
        ),
      ),
    );
  }

  int _hexToColorInt(String hex) {
    final sanitized = hex.replaceAll('#', '');
    return int.parse('FF$sanitized', radix: 16);
  }
}
