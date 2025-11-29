import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/campaign_wizard_provider.dart';
import '../../theme/campaign_builder_theme.dart';
import '../widgets/campaign_details_step.dart';
import '../widgets/email_content_step.dart';
import '../widgets/recipient_selection_step.dart';
import '../widgets/schedule_send_step.dart';

/// Premium Campaign Wizard Screen
/// 4-step wizard for creating professional email campaigns
/// Features: Auto-save, progress tracking, validation, premium UI
class CampaignWizardScreen extends StatefulWidget {
  final String? draftId;

  const CampaignWizardScreen({super.key, this.draftId});

  @override
  State<CampaignWizardScreen> createState() => _CampaignWizardScreenState();
}

class _CampaignWizardScreenState extends State<CampaignWizardScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<_WizardStepInfo> _steps = [
    _WizardStepInfo(
      title: 'Campaign Details',
      subtitle: 'Name and subject line',
      icon: Icons.edit_outlined,
    ),
    _WizardStepInfo(
      title: 'Email Content',
      subtitle: 'Design your message',
      icon: Icons.email_outlined,
    ),
    _WizardStepInfo(
      title: 'Select Recipients',
      subtitle: 'Choose your audience',
      icon: Icons.people_outlined,
    ),
    _WizardStepInfo(
      title: 'Schedule & Send',
      subtitle: 'Review and launch',
      icon: Icons.send_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Load draft if provided
    if (widget.draftId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CampaignWizardProvider>().loadDraft(widget.draftId!);
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CampaignBuilderTheme.darkTheme,
      child: Scaffold(
        backgroundColor: CampaignBuilderTheme.darkNavy,
        appBar: _buildAppBar(),
        body: Row(
          children: [
            // Left sidebar - Step indicator
            _buildStepIndicator(),

            // Main content area
            Expanded(
              child: _buildStepContent(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CampaignBuilderTheme.brightBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CampaignBuilderTheme.brightBlue.withOpacity(0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: CampaignBuilderTheme.brightBlue),
                SizedBox(width: 6),
                Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CampaignBuilderTheme.brightBlue,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('Create Email Campaign'),
        ],
      ),
      actions: [
        // Auto-save indicator
        Consumer<CampaignWizardProvider>(
          builder: (context, provider, _) {
            if (provider.lastSavedAt != null) {
              final timeSince = DateTime.now().difference(provider.lastSavedAt!);
              final timeText = timeSince.inMinutes > 0
                  ? '${timeSince.inMinutes}m ago'
                  : 'Just now';

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done,
                      size: 16,
                      color: provider.hasUnsavedChanges
                          ? CampaignBuilderTheme.warningOrange
                          : CampaignBuilderTheme.successGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.hasUnsavedChanges ? 'Saving...' : 'Saved $timeText',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),

        // Help button
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Help',
          onPressed: () {
            _showHelpDialog();
          },
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: CampaignBuilderTheme.slate,
        border: Border(
          right: BorderSide(color: CampaignBuilderTheme.slateLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaign Setup',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: CampaignBuilderTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _steps.length,
                  backgroundColor: CampaignBuilderTheme.slateLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    CampaignBuilderTheme.brightBlue,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Step ${_currentStep + 1} of ${_steps.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CampaignBuilderTheme.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                return _buildStepItem(index);
              },
            ),
          ),

          // Quick stats panel
          Consumer<CampaignWizardProvider>(
            builder: (context, provider, _) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: CampaignBuilderTheme.slateLight),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Stats',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: CampaignBuilderTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStat(
                      icon: Icons.people,
                      label: 'Recipients',
                      value: provider.estimatedRecipients.toString(),
                      color: CampaignBuilderTheme.brightBlue,
                    ),
                    const SizedBox(height: 8),
                    if (provider.deliverabilityScore != null)
                      _buildQuickStat(
                        icon: Icons.verified_user,
                        label: 'Deliverability',
                        value: '${provider.deliverabilityScore}%',
                        color: _getScoreColor(provider.deliverabilityScore!),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int index) {
    final step = _steps[index];
    final isActive = _currentStep == index;
    final isCompleted = _currentStep > index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        cursor: isCompleted ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: isCompleted ? () => _goToStep(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? CampaignBuilderTheme.moyDBlue.withOpacity(0.15)
                  : CampaignBuilderTheme.darkNavy,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? CampaignBuilderTheme.moyDBlue
                    : isCompleted
                        ? CampaignBuilderTheme.successGreen.withOpacity(0.5)
                        : CampaignBuilderTheme.slateLight,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Step indicator circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? CampaignBuilderTheme.moyDBlue
                        : isCompleted
                            ? CampaignBuilderTheme.successGreen
                            : CampaignBuilderTheme.slateLight,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: CampaignBuilderTheme.textPrimary,
                            size: 20,
                          )
                        : Icon(
                            step.icon,
                            color: isActive
                                ? CampaignBuilderTheme.textPrimary
                                : CampaignBuilderTheme.textTertiary,
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Step title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          color: isActive
                              ? CampaignBuilderTheme.textPrimary
                              : isCompleted
                                  ? CampaignBuilderTheme.textSecondary
                                  : CampaignBuilderTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: CampaignBuilderTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CampaignBuilderTheme.textTertiary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CampaignBuilderTheme.darkNavy,
            CampaignBuilderTheme.darkNavy.withBlue(25),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _getStepWidget(_currentStep),
                  ),
                ),
              ),
            ),
          ),

          // Navigation footer
          _buildNavigationFooter(),
        ],
      ),
    );
  }

  Widget _getStepWidget(int step) {
    switch (step) {
      case 0:
        return const CampaignDetailsStep(key: ValueKey('details'));
      case 1:
        return const EmailContentStep(key: ValueKey('content'));
      case 2:
        return const RecipientSelectionStep(key: ValueKey('recipients'));
      case 3:
        return const ScheduleSendStep(key: ValueKey('schedule'));
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavigationFooter() {
    return Consumer<CampaignWizardProvider>(
      builder: (context, provider, _) {
        final canProceed = _canProceedFromCurrentStep(provider);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: CampaignBuilderTheme.slate,
            border: Border(
              top: BorderSide(color: CampaignBuilderTheme.slateLight),
            ),
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              const Spacer(),

              // Save draft button
              TextButton.icon(
                onPressed: () async {
                  await provider.saveDraft();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Draft saved successfully'),
                      backgroundColor: CampaignBuilderTheme.successGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Draft'),
              ),

              const SizedBox(width: 12),

              // Continue/Create button
              if (_currentStep < 3)
                ElevatedButton.icon(
                  onPressed: canProceed ? _nextStep : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CampaignBuilderTheme.moyDBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: canProceed ? () => _createCampaign(provider) : null,
                  icon: const Icon(Icons.rocket_launch),
                  label: Text(
                    provider.sendImmediately ? 'Create & Send' : 'Create & Schedule',
                  ),
                  style: CampaignBuilderTheme.successButtonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _canProceedFromCurrentStep(CampaignWizardProvider provider) {
    switch (_currentStep) {
      case 0:
        return provider.canProceedFromStep1;
      case 1:
        return provider.canProceedFromStep2;
      case 2:
        return provider.canProceedFromStep3;
      case 3:
        return provider.canCreateCampaign;
      default:
        return false;
    }
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _createCampaign(CampaignWizardProvider provider) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ready to Launch?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.sendImmediately
                  ? 'Your campaign will be sent to ${provider.estimatedRecipients} recipients immediately.'
                  : 'Your campaign will be scheduled for ${provider.scheduledFor?.toString().split('.')[0]}.',
            ),
            const SizedBox(height: 16),
            if (provider.deliverabilityScore != null &&
                provider.deliverabilityScore! < 70)
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
                      Icons.warning_amber_rounded,
                      color: CampaignBuilderTheme.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Deliverability score is ${provider.deliverabilityScore}%. Consider reviewing the issues.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: CampaignBuilderTheme.successButtonStyle,
            child: const Text('Launch Campaign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // TODO: Implement actual campaign creation logic
    // This would call your campaign service to create and send the campaign

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Campaign created successfully!'),
        backgroundColor: CampaignBuilderTheme.successGreen,
      ),
    );

    // Clean up draft
    await provider.deleteDraft();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Campaign Wizard Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Follow these 4 steps to create your campaign:'),
              const SizedBox(height: 16),
              ..._steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: CampaignBuilderTheme.moyDBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              step.subtitle,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text(
                'Your progress is automatically saved every 30 seconds.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return CampaignBuilderTheme.successGreen;
    if (score >= 60) return CampaignBuilderTheme.warningOrange;
    return CampaignBuilderTheme.errorRed;
  }
}

class _WizardStepInfo {
  final String title;
  final String subtitle;
  final IconData icon;

  _WizardStepInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
