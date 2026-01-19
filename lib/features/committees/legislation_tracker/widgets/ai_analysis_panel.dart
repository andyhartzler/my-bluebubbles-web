import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import '../services/ai_analysis_service.dart';
import '../utils/bill_helpers.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Panel displaying AI analysis results with navy tile design
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
  bool _recommendationsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = widget.bill;

    // Analysis pending indicator
    if (bill.aiAnalysisPending || _isAnalyzing) {
      return _buildAnalyzingState(theme);
    }
    // Error state
    if (bill.aiAnalysisError != null || _error != null) {
      return _buildErrorState(theme, bill.aiAnalysisError ?? _error!);
    }
    // No analysis yet
    if (!bill.hasAiAnalysis) {
      return _buildNoAnalysisState(theme);
    }
    // Has analysis - show new design
    return _buildAnalysisResults(theme, bill);
  }

  Widget _buildAnalyzingState(ThemeData theme) {
    return _buildNavyTile(
      child: Column(
        children: [
          const LinearProgressIndicator(color: _momentumBlue),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _momentumBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Analyzing bill with Claude AI...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This may take 10-30 seconds',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return _buildNavyTile(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Analysis failed: $error',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _runAnalysis,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Analysis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _momentumBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAnalysisState(ThemeData theme) {
    return _buildNavyTile(
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No AI analysis yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI will analyze this bill against MOYD\'s policy platform to provide recommendations.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _runAnalysis,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _momentumBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults(ThemeData theme, TrackedBill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Short summary - standalone navy tile, center aligned
        if (bill.aiSummaryShort != null)
          _buildNavyTile(
            child: SelectableText(
              bill.aiSummaryShort!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 16),

        // Full Summary section
        if (bill.aiSummary != null)
          _buildSectionTile(
            icon: Icons.summarize,
            title: 'Full Summary',
            content: bill.aiSummary!,
          ),

        // Position Rationale section
        if (bill.aiRationale != null) ...[
          const SizedBox(height: 12),
          _buildSectionTile(
            icon: Icons.balance,
            title: 'Position Rationale',
            content: bill.aiRationale!,
          ),
        ],

        // Key Provisions section
        if (bill.aiKeyProvisions != null && bill.aiKeyProvisions!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildKeyProvisionsSection(bill.aiKeyProvisions!),
        ],

        // Potential Impact section
        if (bill.aiPotentialImpact != null) ...[
          const SizedBox(height: 12),
          _buildSectionTile(
            icon: Icons.trending_up,
            title: 'Potential Impact',
            content: bill.aiPotentialImpact!,
          ),
        ],

        // AI Recommendations - collapsed tile at bottom
        const SizedBox(height: 12),
        _buildRecommendationsTile(bill),
      ],
    );
  }

  Widget _buildNavyTile({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greyish pill header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: _momentumBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyProvisionsSection(List<Map<String, dynamic>> provisions) {
    return Container(
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greyish pill header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.list, color: _momentumBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Key Provisions (${provisions.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Provisions list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
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
                    color = Colors.redAccent;
                    icon = Icons.cancel_outlined;
                    break;
                  default:
                    color = Colors.white54;
                    icon = Icons.remove_circle_outline;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          p['provision'] as String? ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTile(TrackedBill bill) {
    return Container(
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapsible header
          InkWell(
            onTap: () => setState(() => _recommendationsExpanded = !_recommendationsExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: _recommendationsExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: _momentumBlue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Recommendations',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _recommendationsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_recommendationsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Position and Priority recommendations
                  Row(
                    children: [
                      if (bill.aiPositionRecommendation != null)
                        Expanded(
                          child: _buildRecommendationChip(
                            label: 'Position',
                            value: bill.aiPositionRecommendation!,
                            currentValue: bill.position,
                            color: BillPosition.fromString(bill.aiPositionRecommendation!)?.color ?? Colors.grey,
                            emoji: BillPosition.fromString(bill.aiPositionRecommendation!)?.emoji ?? '❓',
                            onApply: widget.onApplyPosition != null
                                ? () => widget.onApplyPosition!(bill.aiPositionRecommendation!)
                                : null,
                          ),
                        ),
                      if (bill.aiPositionRecommendation != null && bill.aiPriorityRecommendation != null)
                        const SizedBox(width: 12),
                      if (bill.aiPriorityRecommendation != null)
                        Expanded(
                          child: _buildRecommendationChip(
                            label: 'Priority',
                            value: bill.aiPriorityRecommendation!,
                            currentValue: bill.priority,
                            color: BillPriority.fromString(bill.aiPriorityRecommendation!)?.color ?? Colors.grey,
                            emoji: BillPriority.fromString(bill.aiPriorityRecommendation!)?.emoji ?? '❓',
                            onApply: widget.onApplyPriority != null
                                ? () => widget.onApplyPriority!(bill.aiPriorityRecommendation!)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  // Categories recommendation
                  if (bill.aiCategoriesRecommendation.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Categories',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...bill.aiCategoriesRecommendation.map((cat) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cat,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            )),
                        if (widget.onApplyCategories != null &&
                            !_listsEqual(bill.categories, bill.aiCategoriesRecommendation))
                          InkWell(
                            onTap: () => widget.onApplyCategories!(bill.aiCategoriesRecommendation),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _momentumBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Apply', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  // Divider
                  const SizedBox(height: 20),
                  Divider(color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  // Analyzed time
                  if (bill.aiAnalyzedAt != null)
                    Text(
                      'Analyzed ${BillHelpers.formatRelativeTime(bill.aiAnalyzedAt)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Analysis version
                  Text(
                    'Analysis version: ${bill.aiAnalysisVersion ?? 'unknown'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Reanalyze button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _runAnalysis(forceReanalyze: true),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reanalyze'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _momentumBlue,
                        side: const BorderSide(color: _momentumBlue),
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

  Widget _buildRecommendationChip({
    required String label,
    required String value,
    required String? currentValue,
    required Color color,
    required String emoji,
    VoidCallback? onApply,
  }) {
    final isDifferent = currentValue == null || value != currentValue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value.substring(0, 1).toUpperCase() + value.substring(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (isDifferent && onApply != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
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
