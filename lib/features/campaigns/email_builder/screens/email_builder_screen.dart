import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/services/crm/campaign_service.dart';

import '../models/email_document.dart';
import '../providers/email_builder_provider.dart';
import '../services/html_exporter.dart';
import '../widgets/builder_toolbar.dart';
import '../widgets/canvas_area.dart';
import '../widgets/component_palette.dart';
import '../widgets/properties_panel.dart';

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

          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title: const Text('Email Builder'),
              actions: [
                BuilderToolbar(
                  onSave: () => _handleSave(context),
                  onPreview: provider.togglePreviewMode,
                  onUndo: provider.canUndo ? provider.undo : null,
                  onRedo: provider.canRedo ? provider.redo : null,
                ),
              ],
            ),
            body: Row(
              children: [
                if (!provider.isPreviewMode)
                  Container(
                    width: 280,
                    color: Colors.white,
                    child: const ComponentPalette(),
                  ),
                Expanded(
                  child: Container(
                    color: Colors.grey[200],
                    child: const Center(child: CanvasArea()),
                  ),
                ),
                if (!provider.isPreviewMode)
                  Container(
                    width: 320,
                    color: Colors.white,
                    child: const PropertiesPanel(),
                  ),
              ],
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
}
