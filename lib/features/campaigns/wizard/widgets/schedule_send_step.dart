import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';

/// Step 4: Schedule & Send
/// Final review and campaign launch
/// Features: Send now/schedule, A/B testing, campaign summary
class ScheduleSendStep extends StatelessWidget {
  const ScheduleSendStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignWizardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Schedule & Send',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: CampaignBuilderTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your campaign and choose when to send it',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CampaignBuilderTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Campaign Summary Card
            _buildSummaryCard(provider),

            const SizedBox(height: 24),

            // Send Options
            _buildSendOptions(provider),

            const SizedBox(height: 24),

            // A/B Testing (Premium Feature)
            _buildABTestingOption(provider),

            const SizedBox(height: 24),

            // Final checklist
            _buildFinalChecklist(provider),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(CampaignWizardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CampaignBuilderTheme.slateLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize, size: 22, color: CampaignBuilderTheme.brightBlue),
              SizedBox(width: 10),
              Text(
                'Campaign Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow('Campaign Name', provider.campaignName),
          _buildSummaryRow('Subject Line', provider.subjectLine),
          if (provider.previewText.isNotEmpty)
            _buildSummaryRow('Preview Text', provider.previewText),
          _buildSummaryRow('From', provider.fromEmail),
          _buildSummaryRow(
            'Recipients',
            '${provider.estimatedRecipients} people',
            color: CampaignBuilderTheme.successGreen,
          ),
          if (provider.deliverabilityScore != null)
            _buildSummaryRow(
              'Deliverability Score',
              '${provider.deliverabilityScore}/100',
              color: _getScoreColor(provider.deliverabilityScore!),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: CampaignBuilderTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? CampaignBuilderTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendOptions(CampaignWizardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CampaignBuilderTheme.slate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CampaignBuilderTheme.slateLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When to Send',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CampaignBuilderTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Send now option
          RadioListTile<bool>(
            value: true,
            groupValue: provider.sendImmediately,
            onChanged: (value) => provider.toggleSendImmediately(value ?? true),
            title: const Text('Send Immediately'),
            subtitle: const Text('Campaign will be sent right after creation'),
            activeColor: CampaignBuilderTheme.moyDBlue,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 12),

          // Schedule option
          RadioListTile<bool>(
            value: false,
            groupValue: provider.sendImmediately,
            onChanged: (value) => provider.toggleSendImmediately(!(value ?? false)),
            title: const Text('Schedule for Later'),
            subtitle: const Text('Choose a specific date and time'),
            activeColor: CampaignBuilderTheme.moyDBlue,
            contentPadding: EdgeInsets.zero,
          ),

          if (!provider.sendImmediately) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CampaignBuilderTheme.darkNavy,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CampaignBuilderTheme.slateLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CampaignBuilderTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _pickDateTime(provider),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      provider.scheduledFor == null
                          ? 'Choose Date & Time'
                          : 'Scheduled: ${provider.scheduledFor.toString().split('.')[0]}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CampaignBuilderTheme.moyDBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CampaignBuilderTheme.brightBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CampaignBuilderTheme.brightBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: CampaignBuilderTheme.brightBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: Best send times are Tuesday-Thursday, 10AM-2PM',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CampaignBuilderTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildABTestingOption(CampaignWizardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CampaignBuilderTheme.brightBlue.withOpacity(0.1),
            CampaignBuilderTheme.moyDBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CampaignBuilderTheme.brightBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CampaignBuilderTheme.brightBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'PREMIUM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'A/B Testing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Test two subject lines and automatically send the winner to the rest',
            style: TextStyle(
              fontSize: 13,
              color: CampaignBuilderTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: provider.enableABTesting,
            onChanged: (value) => provider.toggleABTesting(value),
            title: const Text('Enable A/B Testing'),
            subtitle: const Text('Send to 20% with each variant, winner to remaining 60%'),
            activeColor: CampaignBuilderTheme.brightBlue,
            contentPadding: EdgeInsets.zero,
          ),
          if (provider.enableABTesting) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CampaignBuilderTheme.darkNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Variant A (Current)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CampaignBuilderTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.subjectLine,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CampaignBuilderTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Variant B (Alternative)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CampaignBuilderTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    onChanged: provider.updateVariantBSubject,
                    decoration: const InputDecoration(
                      hintText: 'Enter alternative subject line...',
                      isDense: true,
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

  Widget _buildFinalChecklist(CampaignWizardProvider provider) {
    final checks = [
      _CheckItem(
        label: 'Campaign details filled',
        checked: provider.canProceedFromStep1,
      ),
      _CheckItem(
        label: 'Email content designed',
        checked: provider.canProceedFromStep2,
      ),
      _CheckItem(
        label: 'Recipients selected (${provider.estimatedRecipients})',
        checked: provider.canProceedFromStep3,
      ),
      _CheckItem(
        label: 'Deliverability score good',
        checked: (provider.deliverabilityScore ?? 0) >= 70,
      ),
    ];

    final allChecked = checks.every((check) => check.checked);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: allChecked
            ? CampaignBuilderTheme.successGreen.withOpacity(0.1)
            : CampaignBuilderTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allChecked
              ? CampaignBuilderTheme.successGreen
              : CampaignBuilderTheme.warningOrange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allChecked ? Icons.verified : Icons.checklist,
                color: allChecked
                    ? CampaignBuilderTheme.successGreen
                    : CampaignBuilderTheme.warningOrange,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Pre-Launch Checklist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...checks.map((check) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    check.checked ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: check.checked
                        ? CampaignBuilderTheme.successGreen
                        : CampaignBuilderTheme.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    check.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: check.checked
                          ? CampaignBuilderTheme.textPrimary
                          : CampaignBuilderTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (allChecked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CampaignBuilderTheme.successGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rocket_launch,
                    color: CampaignBuilderTheme.successGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All set! Ready to launch your campaign.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CampaignBuilderTheme.successGreen,
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

  void _pickDateTime(CampaignWizardProvider provider) async {
    // TODO: Implement date/time picker
    // For now, just set a future date
    final now = DateTime.now();
    provider.setScheduledTime(now.add(const Duration(days: 1)));
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return CampaignBuilderTheme.successGreen;
    if (score >= 60) return CampaignBuilderTheme.warningOrange;
    return CampaignBuilderTheme.errorRed;
  }
}

class _CheckItem {
  final String label;
  final bool checked;

  _CheckItem({required this.label, required this.checked});
}
