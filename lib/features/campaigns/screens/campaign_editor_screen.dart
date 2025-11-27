import 'package:bluebubbles/features/campaigns/screens/campaign_analytics_screen.dart';
import 'package:bluebubbles/features/campaigns/email_builder/models/email_document.dart';
import 'package:bluebubbles/features/campaigns/email_builder/screens/email_builder_screen.dart';
import 'package:bluebubbles/features/campaigns/screens/campaign_preview_screen.dart';
import 'package:bluebubbles/features/campaigns/screens/campaign_recipients_screen.dart';
import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:bluebubbles/features/campaigns/widgets/segment_builder.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CampaignEditorScreen extends StatefulWidget {
  final String? campaignId;
  final Campaign? initialCampaign;

  const CampaignEditorScreen(
      {super.key, this.campaignId, this.initialCampaign});

  @override
  State<CampaignEditorScreen> createState() => _CampaignEditorScreenState();
}

class _CampaignEditorScreenState extends State<CampaignEditorScreen> {
  final CampaignService _campaignService = CampaignService();

  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _previewController = TextEditingController();
  final _htmlController = TextEditingController();

  MessageFilter _segment = MessageFilter();
  Campaign? _campaign;
  DateTime? _scheduledAt;
  bool _loading = true;
  bool _saving = false;
  int? _estimatedRecipients;
  Map<String, dynamic>? _designJson;

  @override
  void initState() {
    super.initState();
    _hydrateFromCampaign(widget.initialCampaign);
    if (widget.campaignId != null) {
      _loadCampaign();
    } else {
      _loading = false;
    }
  }

  void _hydrateFromCampaign(Campaign? campaign) {
    if (campaign == null) return;
    _campaign = campaign;
    _nameController.text = campaign.name;
    _subjectController.text = campaign.subject;
    _previewController.text = campaign.previewText ?? '';
    _htmlController.text = campaign.htmlContent ?? '';
    _designJson = campaign.designJson;
    _segment = campaign.segment ?? MessageFilter();
    _scheduledAt = campaign.scheduledAt;
    _estimatedRecipients = campaign.expectedRecipients;
  }

  Future<void> _loadCampaign() async {
    setState(() => _loading = true);
    final fetched =
        await _campaignService.fetchCampaignById(widget.campaignId ?? '');
    if (!mounted) return;
    if (fetched != null) {
      _hydrateFromCampaign(fetched);
    }
    setState(() => _loading = false);
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final campaign = (_campaign ??
              Campaign(
                  name: _nameController.text, subject: _subjectController.text))
          .copyWith(
        name: _nameController.text.trim().isEmpty
            ? 'Untitled campaign'
            : _nameController.text.trim(),
        subject: _subjectController.text.trim(),
        previewText: _previewController.text.trim().isEmpty
            ? null
            : _previewController.text.trim(),
        htmlContent: _htmlController.text.trim(),
        designJson: _designJson ?? _campaign?.designJson,
        segment: _segment,
        scheduledAt: _scheduledAt,
        expectedRecipients:
            _estimatedRecipients ?? _campaign?.expectedRecipients ?? 0,
      );

      final saved = await _campaignService.saveCampaign(campaign);
      if (!mounted) return;
      _hydrateFromCampaign(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scheduleSend() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()),
    );
    if (time == null) return;

    final scheduledDate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _scheduledAt = scheduledDate);

    if (_campaign?.id != null) {
      final updated = await _campaignService.scheduleCampaign(
          _campaign!.id!, scheduledDate);
      _hydrateFromCampaign(updated);
    }
  }

  Future<void> _sendNow() async {
    if (_campaign?.id == null) return;
    await _campaignService.sendCampaignNow(_campaign!.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Send triggered. Track progress in analytics.')),
    );
    await _loadCampaign();
  }

  Future<void> _estimateRecipients() async {
    final count = await _campaignService.estimateRecipientCount(_segment);
    setState(() => _estimatedRecipients = count);
  }

  void _openPreview() {
    if (_campaign == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignPreviewScreen(
          campaign: _campaign!,
          htmlOverride: _htmlController.text,
        ),
      ),
    );
  }

  void _openRecipients() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignRecipientsScreen(
          filter: _segment,
          campaignId: _campaign?.id,
        ),
      ),
    );
  }

  void _openAnalytics() {
    if (_campaign == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignAnalyticsScreen(campaign: _campaign!),
      ),
    );
  }

  Future<void> _openEmailBuilder() async {
    final initialDocument =
        _designJson != null ? EmailDocument.fromJson(_designJson!) : null;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => EmailBuilderScreen(
          campaignId: _campaign?.id,
          initialDocument: initialDocument,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _htmlController.text = result['html'] as String? ?? _htmlController.text;
      _designJson =
          result['designJson'] as Map<String, dynamic>? ?? _designJson;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_campaign?.name ?? 'Campaign editor'),
        backgroundColor: CampaignBrand.unityBlue,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Campaign name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _subjectController,
                      decoration:
                          const InputDecoration(labelText: 'Subject line'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _previewController,
                decoration: const InputDecoration(labelText: 'Preview text'),
              ),
              const SizedBox(height: 12),
              Chip(
                avatar:
                    const Icon(Icons.schedule, color: Colors.white, size: 18),
                label: Text(
                  _scheduledAt == null
                      ? 'Send immediately'
                      : 'Scheduled ${DateFormat.yMd().add_jm().format(_scheduledAt!)}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: CampaignBrand.momentumBlue,
                deleteIcon:
                    const Icon(Icons.calendar_today, color: Colors.white),
                onDeleted: _scheduleSend,
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
                              Text(
                                'Email content',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _designJson == null
                                    ? 'Build your campaign email with the native Flutter builder.'
                                    : 'Native builder design ready',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _openEmailBuilder,
                            icon: const Icon(Icons.design_services_outlined),
                            label: const Text('Open email builder'),
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recipients', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SegmentBuilder(
                        filter: _segment,
                        estimatedRecipients: _estimatedRecipients,
                        onChanged: (value) => setState(() => _segment = value),
                        onRequestEstimate: _estimateRecipients,
                      ),
                      if (_estimatedRecipients != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              'Estimated ${_estimatedRecipients!} recipients'),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _openRecipients,
                            icon: const Icon(Icons.groups_outlined),
                            label: const Text('Preview recipients'),
                          ),
                          TextButton.icon(
                            onPressed: _openPreview,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Preview email'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveDraft,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save changes'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _campaign?.id == null ? null : _scheduleSend,
                    icon: const Icon(Icons.schedule_send_outlined),
                    label: const Text('Schedule send'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _campaign?.id == null ? null : _sendNow,
                    icon: const Icon(Icons.send),
                    label: const Text('Send now'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _campaign == null ? null : _openAnalytics,
                    child: const Text('View analytics'),
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
