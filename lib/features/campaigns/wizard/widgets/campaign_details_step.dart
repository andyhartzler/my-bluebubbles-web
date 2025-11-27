import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';

/// Step 1: Campaign Details
/// Name, subject line, preview text, from email
/// Features: AI subject line suggestions, character counters
class CampaignDetailsStep extends StatelessWidget {
  const CampaignDetailsStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignWizardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Campaign Details',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by giving your campaign a name and crafting an engaging subject line',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CampaignBuilderTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Campaign Name Field
            _buildTextField(
              label: 'Campaign Name',
              hint: 'e.g., November Newsletter, Event Invitation, Fundraiser',
              value: provider.campaignName,
              onChanged: provider.updateCampaignName,
              icon: Icons.campaign_outlined,
              helpText: 'Internal name for your campaign (not shown to recipients)',
            ),

            const SizedBox(height: 24),

            // Subject Line Field with AI Suggestions
            _buildSubjectLineField(context, provider),

            const SizedBox(height: 24),

            // Preview Text Field
            _buildTextField(
              label: 'Preview Text (Optional)',
              hint: 'Brief preview shown in email inboxes...',
              value: provider.previewText,
              onChanged: provider.updatePreviewText,
              icon: Icons.preview_outlined,
              maxLines: 2,
              maxLength: 150,
              helpText: 'Appears next to the subject line in most email clients',
            ),

            const SizedBox(height: 24),

            // From Email Dropdown
            _buildFromEmailField(provider),

            const SizedBox(height: 32),

            // Best Practices Card
            _buildBestPracticesCard(),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    required IconData icon,
    String? helpText,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: CampaignBuilderTheme.brightBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
          ],
        ),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            helpText,
            style: const TextStyle(
              fontSize: 12,
              color: CampaignBuilderTheme.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
            fontSize: 15,
            color: CampaignBuilderTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterStyle: const TextStyle(
              fontSize: 11,
              color: CampaignBuilderTheme.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectLineField(
    BuildContext context,
    CampaignWizardProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.subject_outlined,
              size: 20,
              color: CampaignBuilderTheme.brightBlue,
            ),
            const SizedBox(width: 8),
            const Text(
              'Subject Line',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
            const Spacer(),

            // AI Suggestions Button
            OutlinedButton.icon(
              onPressed: provider.loadingSuggestions
                  ? null
                  : () => provider.generateSubjectLineSuggestions(),
              icon: provider.loadingSuggestions
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI Suggestions'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                side: const BorderSide(color: CampaignBuilderTheme.brightBlue),
                foregroundColor: CampaignBuilderTheme.brightBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'The first thing recipients see - make it count!',
          style: TextStyle(
            fontSize: 12,
            color: CampaignBuilderTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: provider.subjectLine,
          onChanged: provider.updateSubjectLine,
          maxLength: 78,
          style: const TextStyle(
            fontSize: 15,
            color: CampaignBuilderTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'e.g., Join us for our annual fundraiser!',
            counterStyle: TextStyle(
              fontSize: 11,
              color: provider.subjectLine.length > 60
                  ? CampaignBuilderTheme.warningOrange
                  : CampaignBuilderTheme.textTertiary,
            ),
            suffixIcon: provider.subjectLine.length > 60
                ? const Tooltip(
                    message: 'Subject line may be truncated on mobile devices',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: CampaignBuilderTheme.warningOrange,
                    ),
                  )
                : null,
          ),
        ),

        // AI Suggestions List
        if (provider.subjectLineSuggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CampaignBuilderTheme.slate,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CampaignBuilderTheme.brightBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: CampaignBuilderTheme.brightBlue,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI-Generated Suggestions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CampaignBuilderTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.subjectLineSuggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(suggestion),
                      labelStyle: const TextStyle(fontSize: 13),
                      onPressed: () => provider.selectSubjectSuggestion(suggestion),
                      avatar: const Icon(Icons.add, size: 16),
                      backgroundColor: CampaignBuilderTheme.darkNavy,
                      side: const BorderSide(color: CampaignBuilderTheme.slateLight),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFromEmailField(CampaignWizardProvider provider) {
    final fromEmails = [
      'info@moyoungdemocrats.org',
      'events@moyoungdemocrats.org',
      'fundraising@moyoungdemocrats.org',
      'president@moyoungdemocrats.org',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.mail_outline,
              size: 20,
              color: CampaignBuilderTheme.brightBlue,
            ),
            SizedBox(width: 8),
            Text(
              'From Email',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'The sender email address recipients will see',
          style: TextStyle(
            fontSize: 12,
            color: CampaignBuilderTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: provider.fromEmail,
          items: fromEmails.map((email) {
            return DropdownMenuItem(
              value: email,
              child: Text(email),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              provider.updateFromEmail(value);
            }
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.alternate_email),
          ),
          style: const TextStyle(
            fontSize: 15,
            color: CampaignBuilderTheme.textPrimary,
          ),
          dropdownColor: CampaignBuilderTheme.darkNavy,
        ),
      ],
    );
  }

  Widget _buildBestPracticesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CampaignBuilderTheme.moyDBlue.withOpacity(0.1),
            CampaignBuilderTheme.brightBlue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CampaignBuilderTheme.moyDBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: CampaignBuilderTheme.brightBlue,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Best Practices for Subject Lines',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBestPracticeItem(
            '📏 Keep it under 60 characters for mobile',
            'Longer subject lines get truncated on phones',
          ),
          _buildBestPracticeItem(
            '🎯 Create urgency or curiosity',
            'Use action words and make them want to open',
          ),
          _buildBestPracticeItem(
            '❌ Avoid spam triggers',
            'Limit ALL CAPS, exclamation marks!!!, and "FREE"',
          ),
          _buildBestPracticeItem(
            '🧪 A/B test your subject lines',
            'Try different approaches and see what works best',
          ),
        ],
      ),
    );
  }

  Widget _buildBestPracticeItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: CampaignBuilderTheme.brightBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CampaignBuilderTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CampaignBuilderTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
