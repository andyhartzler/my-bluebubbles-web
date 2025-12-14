import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tracked_bill.dart';
import '../models/talking_point.dart';
import '../services/talking_points_service.dart';
import '../services/ai_analysis_service.dart';

/// Panel displaying AI-generated talking points
class TalkingPointsPanel extends StatefulWidget {
  final TrackedBill bill;
  final VoidCallback? onGenerated;

  const TalkingPointsPanel({
    super.key,
    required this.bill,
    this.onGenerated,
  });

  @override
  State<TalkingPointsPanel> createState() => _TalkingPointsPanelState();
}

class _TalkingPointsPanelState extends State<TalkingPointsPanel> {
  final TalkingPointsService _talkingPointsService = TalkingPointsService();
  final AiAnalysisService _aiService = AiAnalysisService();

  bool _isGenerating = false;
  String? _error;
  String _selectedAudience = 'general_public';

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
              color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Talking Points',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (bill.hasTalkingPoints)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _generateTalkingPoints(regenerate: true),
                    tooltip: 'Regenerate',
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(theme, bill),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, TrackedBill bill) {
    if (_isGenerating) {
      return _buildGeneratingState(theme);
    }

    if (_error != null) {
      return _buildErrorState(theme);
    }

    if (!bill.hasAiAnalysis) {
      return _buildNeedsAnalysisState(theme);
    }

    if (!bill.hasTalkingPoints) {
      return _buildNoTalkingPointsState(theme);
    }

    return _buildTalkingPointsContent(theme, bill);
  }

  Widget _buildGeneratingState(ThemeData theme) {
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
            Text('Generating talking points...',
                style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Crafting persuasive messaging aligned with MOYD values',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generateTalkingPoints,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildNeedsAnalysisState(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.psychology_outlined,
          size: 48,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'AI analysis required first',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Talking points need position context from AI analysis',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            setState(() => _isGenerating = true);
            final result =
                await _aiService.analyzeBill(billId: widget.bill.id);
            if (result.success) {
              await _generateTalkingPoints();
            } else {
              setState(() {
                _isGenerating = false;
                _error = result.error;
              });
            }
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analyze & Generate'),
        ),
      ],
    );
  }

  Widget _buildNoTalkingPointsState(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.campaign_outlined,
          size: 48,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'No talking points yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Generate advocacy messaging for this bill',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generateTalkingPoints,
          icon: const Icon(Icons.campaign),
          label: const Text('Generate Talking Points'),
        ),
      ],
    );
  }

  Widget _buildTalkingPointsContent(ThemeData theme, TrackedBill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Call to Action
        if (bill.aiCallToAction != null) ...[
          _buildCallToAction(theme, bill.aiCallToAction!),
          const SizedBox(height: 20),
        ],

        // Main Talking Points
        Text(
          'Key Talking Points',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...bill.aiTalkingPoints!.map((tp) => _buildTalkingPointCard(theme, tp)),

        const SizedBox(height: 20),

        // Social Media Posts
        if (bill.aiTwitterPosts != null && bill.aiTwitterPosts!.isNotEmpty) ...[
          _buildSocialMediaSection(theme, bill),
          const SizedBox(height: 20),
        ],

        // Target Audience Points
        if (bill.aiTargetAudiencePoints != null) ...[
          _buildAudienceSection(theme, bill),
          const SizedBox(height: 20),
        ],

        // Email Snippet
        if (bill.aiEmailSnippet != null) ...[
          _buildEmailSection(theme, bill.aiEmailSnippet!),
          const SizedBox(height: 20),
        ],

        // Testimony Outline
        if (bill.aiTestimonyOutline != null) ...[
          _buildTestimonySection(theme, bill.aiTestimonyOutline!),
        ],
      ],
    );
  }

  Widget _buildCallToAction(ThemeData theme, String callToAction) {
    final position = BillPosition.fromString(widget.bill.position);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: position.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: position.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign, color: position.color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CALL TO ACTION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: position.color,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  callToAction,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalkingPointCard(ThemeData theme, TalkingPoint tp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tp.typeColor.withOpacity(0.2),
          child: Text(tp.typeEmoji),
        ),
        title: Text(tp.point),
        subtitle: tp.supportingDetail != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tp.supportingDetail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () => _copyToClipboard(
            tp.supportingDetail != null
                ? '${tp.point}\n\n${tp.supportingDetail}'
                : tp.point,
          ),
          tooltip: 'Copy',
        ),
        isThreeLine: tp.supportingDetail != null,
      ),
    );
  }

  Widget _buildSocialMediaSection(ThemeData theme, TrackedBill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.share, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Ready-to-Post',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...bill.aiTwitterPosts!.asMap().entries.map((entry) {
          final post = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.text),
                  if (post.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: post.hashtags
                          .map((h) => Chip(
                                label:
                                    Text('#$h', style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${post.characterCount}/280',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: post.isValidLength
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _copyToClipboard(post.fullText),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                      TextButton.icon(
                        onPressed: () => _shareToTwitter(post.fullText),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Tweet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAudienceSection(ThemeData theme, TrackedBill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'By Audience',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: TargetAudience.values.map((audience) {
              final isSelected = _selectedAudience == audience.key;
              final hasPoints =
                  bill.aiTargetAudiencePoints?.containsKey(audience.key) ??
                      false;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(audience.icon, size: 16),
                      const SizedBox(width: 4),
                      Text(audience.label),
                    ],
                  ),
                  onSelected: hasPoints
                      ? (selected) {
                          setState(() => _selectedAudience = audience.key);
                        }
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (bill.aiTargetAudiencePoints?.containsKey(_selectedAudience) ??
            false)
          ...bill.aiTargetAudiencePoints![_selectedAudience]!.map((point) =>
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: Text(point),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(point),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildEmailSection(ThemeData theme, String emailSnippet) {
    return ExpansionTile(
      leading: Icon(Icons.email, color: theme.colorScheme.primary),
      title: const Text('Email Alert Snippet'),
      tilePadding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(emailSnippet),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _copyToClipboard(emailSnippet),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy for Email'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestimonySection(ThemeData theme, String testimonyOutline) {
    return ExpansionTile(
      leading: Icon(Icons.record_voice_over, color: theme.colorScheme.primary),
      title: const Text('Committee Testimony Outline'),
      tilePadding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(testimonyOutline),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _copyToClipboard(testimonyOutline),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Outline'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _generateTalkingPoints({bool regenerate = false}) async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final result = await _talkingPointsService.generateTalkingPoints(
      billId: widget.bill.id,
      regenerate: regenerate,
    );

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      if (!result.success) {
        _error = result.error;
      }
    });

    if (result.success) {
      widget.onGenerated?.call();
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _talkingPointsService.trackCopy(widget.bill.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareToTwitter(String text) async {
    _talkingPointsService.trackShare(widget.bill.id, 'twitter');
    final encodedText = Uri.encodeComponent(text);
    final url = Uri.parse('https://twitter.com/intent/tweet?text=$encodedText');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
