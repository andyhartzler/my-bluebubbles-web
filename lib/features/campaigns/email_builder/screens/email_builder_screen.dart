import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/services/crm/campaign_service.dart';

import '../models/email_document.dart';
import '../models/email_document_extensions.dart';
import '../providers/email_builder_provider.dart';
import '../widgets/builder_toolbar.dart';
import '../widgets/canvas_area.dart';
import '../widgets/component_palette.dart';
import '../widgets/properties_panel.dart';
import '../widgets/template_manager.dart';
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
                    onTemplates: () => _openTemplates(context),
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
    final html = provider.document.toHtml();
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

  Future<void> _openTemplates(BuildContext context) async {
    final provider = context.read<EmailBuilderProvider>();
    final selected = await showDialog<EmailDocument>(
      context: context,
      builder: (context) => Dialog(
        child: TemplateManager(currentDocument: provider.document),
      ),
    );

    if (selected != null) {
      provider.loadDocument(selected);
    }
  }
}
