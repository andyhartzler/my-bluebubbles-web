import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class _EmailBuilderScreenState extends State<EmailBuilderScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = EmailBuilderProvider();
        if (widget.initialDocument != null) {
          provider.loadDocument(widget.initialDocument!);
        }
        return provider;
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<EmailBuilderProvider>();

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
                  ),
                ],
              ),
              body: Row(
                children: [
                  // Left Panel - Component Palette
                  if (!provider.isPreviewMode)
                    Container(
                      width: 280,
                      decoration: const BoxDecoration(
                        color: CampaignBuilderTheme.slate,
                        border: Border(right: BorderSide(color: CampaignBuilderTheme.slateLight)),
                      ),
                      child: const ComponentPalette(),
                    ),
                  // Center - Canvas Area
                  Expanded(
                    child: Container(
                      color: CampaignBuilderTheme.darkNavy,
                      child: const Center(child: CanvasArea()),
                    ),
                  ),
                  // Right Panel - Properties
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
