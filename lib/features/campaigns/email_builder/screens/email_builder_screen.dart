import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/services/crm/campaign_service.dart';

import '../models/email_document.dart';
import '../models/email_component.dart';
import '../providers/email_builder_provider.dart';
import '../services/html_exporter.dart';
import '../widgets/builder_toolbar.dart';
import '../widgets/canvas_area.dart';
import '../widgets/component_palette.dart';
import '../widgets/properties_panel.dart';
import '../../theme/campaign_builder_theme.dart';

class EmailBuilderScreen extends StatefulWidget {
  final String? campaignId;
  final EmailDocument? initialDocument;

  const EmailBuilderScreen({super.key, this.campaignId, this.initialDocument});

  @override
  State<EmailBuilderScreen> createState() => _EmailBuilderScreenState();
}

class _EmailBuilderScreenState extends State<EmailBuilderScreen>
    with SingleTickerProviderStateMixin {
  late final EmailBuilderProvider _provider;
  late final TabController _deviceTabController;

  @override
  void initState() {
    super.initState();
    _provider = EmailBuilderProvider(
      initialDocument: widget.initialDocument ?? EmailDocument.empty(),
    );
    _deviceTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _provider.previewDevice == 'mobile' ? 0 : 1,
    );

    _deviceTabController.addListener(() {
      if (_deviceTabController.indexIsChanging) return;
      final device = _deviceTabController.index == 0 ? 'mobile' : 'desktop';
      if (_provider.previewDevice != device) {
        _provider.setPreviewDevice(device);
      }
    });
  }

  @override
  void dispose() {
    _deviceTabController.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Builder(
        builder: (context) {
          final provider = context.watch<EmailBuilderProvider>();

          final desiredIndex = provider.previewDevice == 'mobile' ? 0 : 1;
          if (_deviceTabController.index != desiredIndex &&
              !_deviceTabController.indexIsChanging) {
            _deviceTabController.animateTo(desiredIndex);
          }

          return Theme(
            data: CampaignBuilderTheme.darkTheme,
            child: Scaffold(
              backgroundColor: CampaignBuilderTheme.darkNavy,
              appBar: AppBar(
                backgroundColor: CampaignBuilderTheme.slate,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [CampaignBuilderTheme.moyDBlue, CampaignBuilderTheme.brightBlue],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette_outlined, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text('Visual Email Builder', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                actions: [
                  BuilderToolbar(
                    onSave: () => _handleSave(context),
                    onPreview: provider.togglePreviewMode,
                    onUndo: provider.canUndo ? provider.undo : null,
                    onRedo: provider.canRedo ? provider.redo : null,
                    onExportHtml: () => _handleExport(context),
                    onLoadTemplate: () => _openTemplateLoader(context),
                    onOpenSettings: () => _openSettings(context),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      color: CampaignBuilderTheme.slate,
                      border: Border(
                        bottom: BorderSide(color: CampaignBuilderTheme.slateLight),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TabBar(
                            controller: _deviceTabController,
                            labelColor: Colors.white,
                            indicatorColor: CampaignBuilderTheme.brightBlue,
                            unselectedLabelColor: Colors.white70,
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.phone_android, size: 16),
                                text: 'Mobile',
                              ),
                              Tab(
                                icon: Icon(Icons.desktop_windows, size: 16),
                                text: 'Desktop',
                              ),
                            ],
                            onTap: (index) {
                              final device = index == 0 ? 'mobile' : 'desktop';
                              provider.setPreviewDevice(device);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            provider.isPreviewMode ? Icons.design_services : Icons.remove_red_eye,
                            color: Colors.white,
                          ),
                          tooltip: provider.isPreviewMode ? 'Back to editor' : 'Preview mode',
                          onPressed: provider.togglePreviewMode,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (!provider.isPreviewMode)
                          Container(
                            width: 280,
                            decoration: const BoxDecoration(
                              color: CampaignBuilderTheme.slate,
                              border: Border(right: BorderSide(color: CampaignBuilderTheme.slateLight)),
                            ),
                            child: const ComponentPalette(),
                          ),
                        Expanded(
                          child: Container(
                            color: CampaignBuilderTheme.darkNavy,
                            child: const Center(child: CanvasArea()),
                          ),
                        ),
                        if (!provider.isPreviewMode)
                          Container(
                            width: 320,
                            decoration: const BoxDecoration(
                              color: CampaignBuilderTheme.slate,
                              border: Border(left: BorderSide(color: CampaignBuilderTheme.slateLight)),
                            ),
                            child: const PropertiesPanel(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final provider = context.read<EmailBuilderProvider>();
    final htmlExporter = HtmlExporter();
    final html = htmlExporter.export(provider.document);
    final designJson = provider.document.toJson();

    try {
      if (widget.campaignId != null) {
        final campaignService = CampaignService();
        await campaignService.saveCampaignDesign(
          campaignId: widget.campaignId!,
          htmlContent: html,
          designJson: designJson,
        );
      }

      if (mounted) {
        Navigator.pop(context, {
          'html': html,
          'designJson': designJson,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save design: $e')),
        );
      }
    }
  }

  void _handleExport(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    final htmlExporter = HtmlExporter();
    final html = htmlExporter.export(provider.document);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CampaignBuilderTheme.slate,
        title: const Text('Exported HTML'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(
              html,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openTemplateLoader(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: CampaignBuilderTheme.slate,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Templates',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.note_add_outlined, color: Colors.white),
              title: const Text('Start from blank', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Reset to an empty canvas', style: TextStyle(color: Colors.white70)),
              onTap: () {
                provider.loadDocument(EmailDocument.empty());
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline, color: Colors.white),
              title: const Text('Hero headline', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Prefill with a basic hero section', style: TextStyle(color: Colors.white70)),
              onTap: () {
                provider.loadDocument(_sampleHeroTemplate());
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    final provider = context.read<EmailBuilderProvider>();
    double zoom = provider.zoomLevel;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CampaignBuilderTheme.slate,
        title: const Text('Builder settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Preview device', style: TextStyle(color: Colors.white)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'mobile',
                      icon: Icon(Icons.phone_android, size: 16),
                      label: Text('Mobile'),
                    ),
                    ButtonSegment(
                      value: 'desktop',
                      icon: Icon(Icons.desktop_windows, size: 16),
                      label: Text('Desktop'),
                    ),
                  ],
                  selected: {provider.previewDevice},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      provider.setPreviewDevice(selection.first);
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Zoom', style: TextStyle(color: Colors.white)),
                Text('${(zoom * 100).round()}%', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Slider(
              value: zoom,
              min: 0.5,
              max: 1.5,
              divisions: 10,
              label: '${(zoom * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  zoom = value;
                });
                provider.setZoomLevel(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  EmailDocument _sampleHeroTemplate() {
    final uuid = const Uuid();
    final sectionId = uuid.v4();
    final columnId = uuid.v4();

    return EmailDocument(
      sections: [
        EmailSection(
          id: sectionId,
          columns: [
            EmailColumn(
              id: columnId,
              components: [
                EmailComponent.heading(
                  id: uuid.v4(),
                  content: 'Welcome to the movement',
                  style: const HeadingComponentStyle(
                    fontSize: 32,
                    alignment: 'center',
                  ),
                ),
                EmailComponent.text(
                  id: uuid.v4(),
                  content:
                      'Start customizing this hero block with your campaign story, calls to action, and upcoming events.',
                  style: const TextComponentStyle(alignment: 'center'),
                ),
                EmailComponent.button(
                  id: uuid.v4(),
                  text: 'Get involved',
                  url: 'https://moyd.org',
                  style: const ButtonComponentStyle(
                    backgroundColor: CampaignBuilderTheme.moyDBlue,
                    textColor: '#ffffff',
                    paddingHorizontal: 28,
                    paddingVertical: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      settings: const EmailSettings(),
      lastModified: DateTime.now(),
    );
  }
}
