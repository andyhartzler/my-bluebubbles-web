import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tracked_bill.dart';
import '../models/talking_point.dart';
import '../services/talking_points_service.dart';
import '../services/ai_analysis_service.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Panel displaying AI-generated talking points with navy tile design
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
  bool _socialMediaExpanded = false;
  bool _emailExpanded = false;
  bool _testimonyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;

    if (_isGenerating) {
      return _buildGeneratingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (!bill.hasAiAnalysis) {
      return _buildNeedsAnalysisState();
    }

    if (!bill.hasTalkingPoints) {
      return _buildNoTalkingPointsState();
    }

    return _buildTalkingPointsContent(bill);
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

  Widget _buildGeneratingState() {
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
                'Generating talking points...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Crafting persuasive messaging aligned with MOYD values',
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

  Widget _buildErrorState() {
    return _buildNavyTile(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _generateTalkingPoints,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _momentumBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsAnalysisState() {
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
            'AI analysis required first',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Talking points need position context from AI analysis',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
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

  Widget _buildNoTalkingPointsState() {
    return _buildNavyTile(
      child: Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No talking points yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate advocacy messaging for this bill',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _generateTalkingPoints,
            icon: const Icon(Icons.campaign),
            label: const Text('Generate Talking Points'),
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

  Widget _buildTalkingPointsContent(TrackedBill bill) {
    final position = bill.position != null
        ? BillPosition.fromString(bill.position!)
        : null;
    final positionColor = position?.color ?? _momentumBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Call to Action - standalone navy tile
        if (bill.aiCallToAction != null)
          _buildNavyTile(
            child: Row(
              children: [
                Icon(Icons.campaign, color: positionColor, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CALL TO ACTION',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: positionColor,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        bill.aiCallToAction!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Key Talking Points section
        if (bill.aiTalkingPoints != null && bill.aiTalkingPoints!.isNotEmpty)
          _buildSectionTile(
            icon: Icons.chat_bubble_outline,
            title: 'Key Talking Points',
            child: Column(
              children: bill.aiTalkingPoints!
                  .map((tp) => _buildTalkingPointItem(tp))
                  .toList(),
            ),
          ),

        // Social Media Posts section
        if (bill.aiTwitterPosts != null && bill.aiTwitterPosts!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCollapsibleSection(
            icon: Icons.share,
            title: 'Ready-to-Post',
            isExpanded: _socialMediaExpanded,
            onTap: () => setState(() => _socialMediaExpanded = !_socialMediaExpanded),
            child: Column(
              children: bill.aiTwitterPosts!
                  .map((post) => _buildSocialPostItem(post))
                  .toList(),
            ),
          ),
        ],

        // Target Audience section
        if (bill.aiTargetAudiencePoints != null) ...[
          const SizedBox(height: 12),
          _buildAudienceSection(bill),
        ],

        // Email Snippet section
        if (bill.aiEmailSnippet != null) ...[
          const SizedBox(height: 12),
          _buildCollapsibleSection(
            icon: Icons.email_outlined,
            title: 'Email Alert Snippet',
            isExpanded: _emailExpanded,
            onTap: () => setState(() => _emailExpanded = !_emailExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  bill.aiEmailSnippet!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCopyButton('Copy for Email', bill.aiEmailSnippet!),
              ],
            ),
          ),
        ],

        // Testimony Outline section
        if (bill.aiTestimonyOutline != null) ...[
          const SizedBox(height: 12),
          _buildCollapsibleSection(
            icon: Icons.record_voice_over,
            title: 'Committee Testimony Outline',
            isExpanded: _testimonyExpanded,
            onTap: () => setState(() => _testimonyExpanded = !_testimonyExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  bill.aiTestimonyOutline!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCopyButton('Copy Outline', bill.aiTestimonyOutline!),
              ],
            ),
          ),
        ],

        // Regenerate button at bottom
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _generateTalkingPoints(regenerate: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Regenerate Talking Points'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _momentumBlue,
              side: const BorderSide(color: _momentumBlue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required String title,
    required Widget child,
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
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
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
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(icon, color: _momentumBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildTalkingPointItem(TalkingPoint tp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tp.typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tp.typeEmoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  tp.point,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                if (tp.supportingDetail != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    tp.supportingDetail!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: Colors.white.withOpacity(0.6)),
            onPressed: () => _copyToClipboard(
              tp.supportingDetail != null
                  ? '${tp.point}\n\n${tp.supportingDetail}'
                  : tp.point,
            ),
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialPostItem(dynamic post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            post.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.hashtags.map<Widget>((h) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$h',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  )).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${post.characterCount}/280',
                style: TextStyle(
                  color: post.isValidLength
                      ? Colors.white.withOpacity(0.5)
                      : Colors.redAccent,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _copyToClipboard(post.fullText),
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _momentumBlue),
              ),
              TextButton.icon(
                onPressed: () => _shareToTwitter(post.fullText),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Tweet', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _momentumBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceSection(TrackedBill bill) {
    return _buildSectionTile(
      icon: Icons.groups,
      title: 'By Audience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audience selector
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
                  child: GestureDetector(
                    onTap: hasPoints
                        ? () => setState(() => _selectedAudience = audience.key)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _momentumBlue
                            : Colors.white.withOpacity(hasPoints ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            audience.icon,
                            size: 16,
                            color: hasPoints ? Colors.white : Colors.white38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            audience.label,
                            style: TextStyle(
                              color: hasPoints ? Colors.white : Colors.white38,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Points for selected audience
          if (bill.aiTargetAudiencePoints?.containsKey(_selectedAudience) ?? false)
            ...bill.aiTargetAudiencePoints![_selectedAudience]!.map((point) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right, size: 20, color: _momentumBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          point,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: Colors.white.withOpacity(0.5)),
                        onPressed: () => _copyToClipboard(point),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildCopyButton(String label, String text) {
    return ElevatedButton.icon(
      onPressed: () => _copyToClipboard(text),
      icon: const Icon(Icons.copy, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _momentumBlue,
        foregroundColor: Colors.white,
      ),
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
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: _unityBlue,
        duration: const Duration(seconds: 2),
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
