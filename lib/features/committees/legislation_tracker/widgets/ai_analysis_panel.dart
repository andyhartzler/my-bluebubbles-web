import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import '../services/ai_analysis_service.dart';
import '../utils/bill_helpers.dart';

/// Panel displaying AI analysis results and controls
class AiAnalysisPanel extends StatefulWidget {
  final TrackedBill bill;
  final VoidCallback? onAnalysisComplete;
  final Function(String position)? onApplyPosition;
  final Function(String priority)? onApplyPriority;
  final Function(List<String> categories)? onApplyCategories;

  const AiAnalysisPanel({
    super.key,
    required this.bill,
    this.onAnalysisComplete,
    this.onApplyPosition,
    this.onApplyPriority,
    this.onApplyCategories,
  });

  @override
  State<AiAnalysisPanel> createState() => _AiAnalysisPanelState();
}

class _AiAnalysisPanelState extends State<AiAnalysisPanel> {
  final AiAnalysisService _aiService = AiAnalysisService();
  bool _isAnalyzing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = widget.bill;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (bill.hasAiAnalysis)
                  Text(
                    'Analyzed ${BillHelpers.formatRelativeTime(bill.aiAnalyzedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Analysis pending indicator
                if (bill.aiAnalysisPending || _isAnalyzing)
                  _buildAnalyzingState(theme)
                // Error state
                else if (bill.aiAnalysisError != null || _error != null)
                  _buildErrorState(theme, bill.aiAnalysisError ?? _error!)
                // No analysis yet
                else if (!bill.hasAiAnalysis)
                  _buildNoAnalysisState(theme)
                // Has analysis
                else
                  _buildAnalysisResults(theme, bill),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState(ThemeData theme) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing bill with Claude AI...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'This may take 10-30 seconds',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Analysis failed: $error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _runAnalysis,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry Analysis'),
        ),
      ],
    );
  }

  Widget _buildNoAnalysisState(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.psychology_outlined,
          size: 48,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'No AI analysis yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI will analyze this bill against MOYD\'s policy platform to provide recommendations.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _runAnalysis,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analyze with AI'),
        ),
      ],
    );
  }

  Widget _buildAnalysisResults(ThemeData theme, TrackedBill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Short summary
        if (bill.aiSummaryShort != null) ...[
          Text(
            bill.aiSummaryShort!,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Recommendations row
        _buildRecommendationsRow(theme, bill),
        const SizedBox(height: 16),

        // Detailed summary
        if (bill.aiSummary != null) ...[
          _buildExpandableSection(
            theme,
            title: 'Full Summary',
            icon: Icons.summarize,
            content: bill.aiSummary!,
          ),
          const SizedBox(height: 12),
        ],

        // Rationale
        if (bill.aiRationale != null) ...[
          _buildExpandableSection(
            theme,
            title: 'Position Rationale',
            icon: Icons.balance,
            content: bill.aiRationale!,
          ),
          const SizedBox(height: 12),
        ],

        // Key provisions
        if (bill.aiKeyProvisions != null && bill.aiKeyProvisions!.isNotEmpty) ...[
          _buildKeyProvisions(theme, bill.aiKeyProvisions!),
          const SizedBox(height: 12),
        ],

        // Potential impact
        if (bill.aiPotentialImpact != null) ...[
          _buildExpandableSection(
            theme,
            title: 'Potential Impact',
            icon: Icons.trending_up,
            content: bill.aiPotentialImpact!,
          ),
          const SizedBox(height: 12),
        ],

        // Reanalyze button
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Analysis version: ${bill.aiAnalysisVersion ?? 'unknown'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _runAnalysis(forceReanalyze: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reanalyze'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationsRow(ThemeData theme, TrackedBill bill) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Recommendations',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Position recommendation
              if (bill.aiPositionRecommendation != null)
                Expanded(
                  child: _buildRecommendationChip(
                    theme,
                    label: 'Position',
                    value: bill.aiPositionRecommendation!,
                    currentValue: bill.position,
                    color: BillPosition.fromString(bill.aiPositionRecommendation!).color,
                    emoji: BillPosition.fromString(bill.aiPositionRecommendation!).emoji,
                    onApply: widget.onApplyPosition != null
                        ? () => widget.onApplyPosition!(bill.aiPositionRecommendation!)
                        : null,
                  ),
                ),
              const SizedBox(width: 8),
              // Priority recommendation
              if (bill.aiPriorityRecommendation != null)
                Expanded(
                  child: _buildRecommendationChip(
                    theme,
                    label: 'Priority',
                    value: bill.aiPriorityRecommendation!,
                    currentValue: bill.priority,
                    color: BillPriority.fromString(bill.aiPriorityRecommendation!).color,
                    emoji: BillPriority.fromString(bill.aiPriorityRecommendation!).emoji,
                    onApply: widget.onApplyPriority != null
                        ? () => widget.onApplyPriority!(bill.aiPriorityRecommendation!)
                        : null,
                  ),
                ),
            ],
          ),
          // Categories recommendation
          if (bill.aiCategoriesRecommendation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Categories',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...bill.aiCategoriesRecommendation.map((cat) => Chip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    )),
                if (widget.onApplyCategories != null &&
                    !_listsEqual(bill.categories, bill.aiCategoriesRecommendation))
                  ActionChip(
                    label: const Text('Apply', style: TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.check, size: 14),
                    onPressed: () => widget.onApplyCategories!(bill.aiCategoriesRecommendation),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationChip(
    ThemeData theme, {
    required String label,
    required String value,
    required String currentValue,
    required Color color,
    required String emoji,
    VoidCallback? onApply,
  }) {
    final isDifferent = value != currentValue;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(emoji),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value.substring(0, 1).toUpperCase() + value.substring(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (isDifferent && onApply != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onApply,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: color),
                ),
                child: Text(
                  'Apply',
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandableSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return ExpansionTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: theme.textTheme.titleSmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      initiallyExpanded: false,
      children: [
        Text(
          content,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildKeyProvisions(ThemeData theme, List<Map<String, dynamic>> provisions) {
    return ExpansionTile(
      leading: const Icon(Icons.list, size: 20),
      title: Text('Key Provisions (${provisions.length})', style: theme.textTheme.titleSmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: provisions.map((p) {
        final alignment = p['alignment'] as String? ?? 'neutral';
        Color color;
        IconData icon;
        switch (alignment) {
          case 'aligns':
            color = Colors.green;
            icon = Icons.check_circle_outline;
            break;
          case 'conflicts':
            color = Colors.red;
            icon = Icons.cancel_outlined;
            break;
          default:
            color = Colors.grey;
            icon = Icons.remove_circle_outline;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p['provision'] as String? ?? '',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _runAnalysis({bool forceReanalyze = false}) async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    final result = await _aiService.analyzeBill(
      billId: widget.bill.id,
      forceReanalyze: forceReanalyze,
    );

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      if (!result.success) {
        _error = result.error;
      }
    });

    if (result.success) {
      widget.onAnalysisComplete?.call();
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }
}
