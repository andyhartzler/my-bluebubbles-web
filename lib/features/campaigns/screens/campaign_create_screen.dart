import 'package:bluebubbles/features/campaigns/screens/campaign_editor_screen.dart';
import 'package:bluebubbles/features/campaigns/screens/campaign_iframe_editor_screen.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/features/campaigns/widgets/segment_builder.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';
import 'package:flutter/material.dart';

class CampaignCreateScreen extends StatefulWidget {
  const CampaignCreateScreen({super.key});

  @override
  State<CampaignCreateScreen> createState() => _CampaignCreateScreenState();
}

class _CampaignCreateScreenState extends State<CampaignCreateScreen> {
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _previewController = TextEditingController();
  final _htmlController = TextEditingController();
  final CampaignService _campaignService = CampaignService();

  MessageFilter _filter = MessageFilter();
  int? _estimatedRecipients;
  bool _saving = false;
  Map<String, dynamic>? _designJson;

  Future<void> _estimate() async {
    final count = await _campaignService.estimateRecipientCount(_filter);
    setState(() => _estimatedRecipients = count);
  }

  Future<void> _openEmailBuilder() async {
    // Validate campaign details
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a campaign name first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subject line first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    setState(() => _saving = true);

    try {
      // Auto-save campaign to get a campaign ID
      final campaign = Campaign(
        name: _nameController.text.trim().isEmpty
            ? 'Untitled campaign'
            : _nameController.text.trim(),
        subject: _subjectController.text.trim(),
        previewText: _previewController.text.trim().isEmpty
            ? null
            : _previewController.text.trim(),
        htmlContent: _htmlController.text.trim(),
        designJson: _designJson,
        segment: _filter,
        expectedRecipients: _estimatedRecipients ?? 0,
      );

      final saved = await _campaignService.saveCampaign(campaign);

      if (!mounted) return;

      // Open iframe builder with the saved campaign ID
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => CampaignIframeEditorScreen(
            campaignId: saved.id!,
            initialCampaign: saved,
          ),
        ),
      );

      if (!mounted || result == null) return;

      final html = result['html'];
      final designJson = result['designJson'];

      if (html is String && designJson is Map<String, dynamic>) {
        setState(() {
          _htmlController.text = html;
          _designJson = designJson;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email builder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final campaign = Campaign(
        name: _nameController.text.trim().isEmpty
            ? 'Untitled campaign'
            : _nameController.text.trim(),
        subject: _subjectController.text.trim(),
        previewText: _previewController.text.trim().isEmpty
            ? null
            : _previewController.text.trim(),
        htmlContent: _htmlController.text.trim(),
        designJson: _designJson,
        segment: _filter,
        expectedRecipients: _estimatedRecipients ?? 0,
      );

      final saved = await _campaignService.saveCampaign(campaign);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CampaignEditorScreen(
              campaignId: saved.id, initialCampaign: saved),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create campaign: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create campaign'),
        backgroundColor: CampaignBrand.unityBlue,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Campaign name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject line'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _previewController,
                decoration:
                    const InputDecoration(labelText: 'Preview text (optional)'),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email content',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                _designJson == null
                                    ? 'Start designing your email with the mail.moyd.app builder.'
                                    : 'Email design ready',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _openEmailBuilder,
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Open Email Builder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _htmlController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Generated HTML (editable)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Build segment', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SegmentBuilder(
                        filter: _filter,
                        estimatedRecipients: _estimatedRecipients,
                        onChanged: (filter) => setState(() => _filter = filter),
                        onRequestEstimate: _estimate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _create,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Create & continue'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
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
