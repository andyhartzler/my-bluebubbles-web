import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';
import '../../screens/campaign_iframe_editor_screen.dart';
import '../../widgets/ai_content_assistant.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';

/// Step 2: Email Content
/// Design email with visual builder
/// Features: Prominent builder CTA, HTML preview, deliverability scoring
class EmailContentStep extends StatelessWidget {
  const EmailContentStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignWizardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Design Your Email',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a beautiful, professional email using our drag-and-drop builder',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CampaignBuilderTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Main content card
            provider.hasEmailContent
                ? _buildPreviewCard(context, provider)
                : _buildEmptyStateCard(context, provider),

            // Deliverability Score Card
            if (provider.hasEmailContent) ...[
              const SizedBox(height: 24),
              _buildDeliverabilityCard(provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context,
    CampaignWizardProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CampaignBuilderTheme.slateLight,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          CampaignBuilderTheme.moyDBlue,
                          CampaignBuilderTheme.brightBlue,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CampaignBuilderTheme.moyDBlue.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Prompt text
            Text(
              'Design Your Email Content',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Use our powerful visual builder to create beautiful email designs',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: CampaignBuilderTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Primary CTA - Open Visual Builder
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: () => _openVisualBuilder(context, provider),
                icon: const Icon(Icons.auto_awesome, size: 22),
                label: const Text(
                  'Open the Visual Builder',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CampaignBuilderTheme.moyDBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  shadowColor: CampaignBuilderTheme.moyDBlue.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    CampaignWizardProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CampaignBuilderTheme.successGreen.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CampaignBuilderTheme.successGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: CampaignBuilderTheme.successGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Content Ready',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CampaignBuilderTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your email design looks great!',
                        style: TextStyle(
                          fontSize: 14,
                          color: CampaignBuilderTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Preview with side-by-side desktop/mobile
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Desktop Preview
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.desktop_windows,
                            size: 16,
                            color: CampaignBuilderTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Desktop Preview',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CampaignBuilderTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 400,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CampaignBuilderTheme.slateLight),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SingleChildScrollView(
                            child: Html(
                              data: provider.htmlContent ?? '',
                              style: {
                                'body': Style(
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Mobile Preview
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_iphone,
                          size: 16,
                          color: CampaignBuilderTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Mobile Preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CampaignBuilderTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 200,
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CampaignBuilderTheme.slateLight, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SingleChildScrollView(
                          child: Html(
                            data: provider.htmlContent ?? '',
                            style: {
                              'body': Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.all(4),
                                fontSize: FontSize(10),
                              ),
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openVisualBuilder(context, provider),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Design'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: CampaignBuilderTheme.moyDBlue),
                      foregroundColor: CampaignBuilderTheme.moyDBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showResetConfirmation(context, provider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Start Over'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverabilityCard(CampaignWizardProvider provider) {
    if (provider.deliverabilityScore == null) {
      return const SizedBox();
    }

    final score = provider.deliverabilityScore!;
    final color = _getScoreColor(score);
    final rating = _getScoreRating(score);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.verified_user,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deliverability Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CampaignBuilderTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your email is $rating',
                      style: TextStyle(
                        fontSize: 14,
                        color: CampaignBuilderTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    score.toString(),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 14,
                      color: CampaignBuilderTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (provider.deliverabilityIssues.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            const Text(
              'Issues to Fix:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...provider.deliverabilityIssues.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: CampaignBuilderTheme.warningOrange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        issue,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CampaignBuilderTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Spam score
          if (provider.spamScore != null && provider.spamScore! > 20) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CampaignBuilderTheme.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CampaignBuilderTheme.warningOrange),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.security,
                    color: CampaignBuilderTheme.warningOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Spam score: ${provider.spamScore}% - Consider revising content',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CampaignBuilderTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return CampaignBuilderTheme.successGreen;
    if (score >= 60) return CampaignBuilderTheme.warningOrange;
    return CampaignBuilderTheme.errorRed;
  }

  String _getScoreRating(int score) {
    if (score >= 90) return 'excellent';
    if (score >= 80) return 'very good';
    if (score >= 70) return 'good';
    if (score >= 60) return 'fair';
    return 'needs improvement';
  }

  Future<void> _openVisualBuilder(
    BuildContext context,
    CampaignWizardProvider provider,
  ) async {
    // Validate campaign details
    if (provider.campaignName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a campaign name first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (provider.subject.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subject line first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Create/save campaign to get a campaign ID
      final campaignService = CampaignService();
      final campaign = Campaign(
        name: provider.campaignName,
        subject: provider.subject,
        previewText: provider.previewText.isEmpty ? null : provider.previewText,
        htmlContent: provider.htmlContent,
        designJson: provider.designJson,
        segment: provider.buildMessageFilter(),
      );

      final savedCampaign = await campaignService.saveCampaign(campaign);

      // Dismiss loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Open iframe builder with the saved campaign ID
      if (!context.mounted) return;
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => CampaignIframeEditorScreen(
            campaignId: savedCampaign.id!,
            initialCampaign: savedCampaign,
          ),
        ),
      );

      if (result == null) return;

      final html = result['html'];
      final designJson = result['designJson'];

      if (html is String && designJson is Map<String, dynamic>) {
        provider.updateEmailContent(
          htmlContent: html,
          designJson: designJson,
        );
        return;
      }
    } catch (e) {
      // Dismiss loading indicator if still showing
      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email builder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAIAssistant(
    BuildContext context,
    CampaignWizardProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 900,
          height: 700,
          child: AIContentAssistant(
            campaignName: provider.campaignName,
            subject: provider.subject,
            onContentGenerated: (htmlContent) {
              provider.updateEmailContent(
                htmlContent: htmlContent,
                designJson: {}, // Template HTML doesn't need design JSON
              );
            },
          ),
        ),
      ),
    );
  }

  void _importHTML(
    BuildContext context,
    CampaignWizardProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import HTML'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Paste your HTML code here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement HTML import
              Navigator.pop(context);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(
    BuildContext context,
    CampaignWizardProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Over?'),
        content: const Text(
          'Are you sure you want to discard your current design and start over?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearEmailContent();
              Navigator.pop(context);
            },
            style: CampaignBuilderTheme.dangerButtonStyle,
            child: const Text('Start Over'),
          ),
        ],
      ),
    );
  }
}
