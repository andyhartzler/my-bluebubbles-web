import 'package:flutter/material.dart';
import '../services/ai_analysis_service.dart';

/// Button for triggering batch AI analysis of multiple bills
class BatchAnalysisButton extends StatefulWidget {
  final String? session;
  final VoidCallback? onComplete;

  const BatchAnalysisButton({
    super.key,
    this.session,
    this.onComplete,
  });

  @override
  State<BatchAnalysisButton> createState() => _BatchAnalysisButtonState();
}

class _BatchAnalysisButtonState extends State<BatchAnalysisButton> {
  final AiAnalysisService _aiService = AiAnalysisService();
  bool _isAnalyzing = false;
  int _unanalyzedCount = 0;
  int _analyzedCount = 0;
  String? _statusMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void didUpdateWidget(BatchAnalysisButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _aiService.getUnanalyzedBillCount(session: widget.session),
        _aiService.getAnalyzedBillCount(session: widget.session),
      ]);
      if (mounted) {
        setState(() {
          _unanalyzedCount = results[0];
          _analyzedCount = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Analysis',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_analyzedCount analyzed, $_unanalyzedCount pending',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAnalyzing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_unanalyzedCount > 0)
                  FilledButton.icon(
                    onPressed: _runBatchAnalysis,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text('Analyze ${_unanalyzedCount > 5 ? '5' : _unanalyzedCount}'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'All analyzed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // Progress indicator
            if (_isAnalyzing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runBatchAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Starting batch analysis...';
    });

    try {
      final result = await _aiService.analyzeBillsBatch(
        batchSize: 5,
        session: widget.session,
      );

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Completed: ${result.successful} analyzed, ${result.failed} failed';
        _isAnalyzing = false;
      });

      await _loadCounts();
      widget.onComplete?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: $e';
        _isAnalyzing = false;
      });
    }
  }
}

/// Compact version of the batch analysis button for use in app bars or smaller spaces
class BatchAnalysisIconButton extends StatefulWidget {
  final String? session;
  final VoidCallback? onComplete;

  const BatchAnalysisIconButton({
    super.key,
    this.session,
    this.onComplete,
  });

  @override
  State<BatchAnalysisIconButton> createState() => _BatchAnalysisIconButtonState();
}

class _BatchAnalysisIconButtonState extends State<BatchAnalysisIconButton> {
  final AiAnalysisService _aiService = AiAnalysisService();
  bool _isAnalyzing = false;
  int _unanalyzedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnanalyzedCount();
  }

  Future<void> _loadUnanalyzedCount() async {
    final count = await _aiService.getUnanalyzedBillCount(session: widget.session);
    if (mounted) {
      setState(() => _unanalyzedCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_unanalyzedCount == 0 && !_isAnalyzing) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        IconButton(
          icon: _isAnalyzing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          onPressed: _isAnalyzing ? null : _runBatchAnalysis,
          tooltip: _isAnalyzing
              ? 'Analyzing...'
              : 'Analyze $_unanalyzedCount bills with AI',
        ),
        if (_unanalyzedCount > 0 && !_isAnalyzing)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$_unanalyzedCount',
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _runBatchAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      await _aiService.analyzeBillsBatch(
        batchSize: 5,
        session: widget.session,
      );

      await _loadUnanalyzedCount();
      widget.onComplete?.call();
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }
}
