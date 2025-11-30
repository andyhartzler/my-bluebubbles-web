import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/send_test_dialog.dart';

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
                    onSendTest: widget.campaignId != null
                        ? () => _openSendTest(context)
                        : null,
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

  Future<void> _handleExport(BuildContext context) async {
    final provider = context.read<EmailBuilderProvider>();
    final html = provider.document.toHtml();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Export HTML'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Copy and paste this HTML into your email service.'),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: SelectableText(html),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: html));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('HTML copied to clipboard')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy HTML'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTemplateLoader(BuildContext context) async {
    await _openTemplates(context);
  }

  Future<void> _openSettings(BuildContext context) async {
    final provider = context.read<EmailBuilderProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        double zoom = provider.zoomLevel;
        String device = provider.previewDevice;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Builder Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Device:'),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Mobile'),
                        selected: device == 'mobile',
                        onSelected: (_) {
                          setState(() => device = 'mobile');
                          provider.setPreviewDevice('mobile');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Desktop'),
                        selected: device == 'desktop',
                        onSelected: (_) {
                          setState(() => device = 'desktop');
                          provider.setPreviewDevice('desktop');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zoom'),
                      Slider(
                        value: zoom,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: '${(zoom * 100).round()}%',
                        onChanged: (value) {
                          setState(() => zoom = value);
                          provider.setZoomLevel(value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSendTest(BuildContext context) async {
    if (widget.campaignId == null) return;

    final provider = context.read<EmailBuilderProvider>();
    final html = provider.document.toHtml();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SendTestDialog(
          campaignId: widget.campaignId!,
          htmlContent: html,
        );
      },
    );
  }
}
