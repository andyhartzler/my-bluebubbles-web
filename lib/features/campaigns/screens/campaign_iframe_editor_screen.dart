import 'package:flutter/material.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';
import '../widgets/email_builder_iframe.dart';
import 'dart:convert';

/// Screen for editing campaign email content using the mail.moyd.app iframe builder
class CampaignIframeEditorScreen extends StatefulWidget {
  final String campaignId;
  final Campaign? initialCampaign;

  const CampaignIframeEditorScreen({
    super.key,
    required this.campaignId,
    this.initialCampaign,
  });

  @override
  State<CampaignIframeEditorScreen> createState() =>
      _CampaignIframeEditorScreenState();
}

class _CampaignIframeEditorScreenState
    extends State<CampaignIframeEditorScreen> {
  final CampaignService _campaignService = CampaignService();
  Campaign? _campaign;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCampaign();
  }

  Future<void> _loadCampaign() async {
    setState(() => _isLoading = true);

    try {
      Campaign? campaign = widget.initialCampaign;

      if (campaign == null) {
        campaign = await _campaignService.fetchCampaignById(widget.campaignId);
      }

      if (mounted) {
        setState(() {
          _campaign = campaign;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading campaign: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSave(String html, String designJson) async {
    setState(() => _isSaving = true);

    try {
      // Parse designJson string to Map
      final Map<String, dynamic> designMap = jsonDecode(designJson);

      await _campaignService.saveCampaignDesign(
        campaignId: widget.campaignId,
        htmlContent: html,
        designJson: designMap,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign design saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {
          'html': html,
          'designJson': designMap,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving design: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_campaign == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Campaign not found'),
        ),
      );
    }

    // Convert designJson Map to JSON string for the iframe
    final String? initialDesign = _campaign!.designJson != null
        ? jsonEncode(_campaign!.designJson)
        : null;

    return EmailBuilderIframe(
      initialDesign: initialDesign,
      onSave: _handleSave,
      onCancel: () => Navigator.pop(context),
    );
  }
}
