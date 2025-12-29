import 'package:flutter/material.dart';
import '../models/chat_message.dart';

// Brand colors matching dashboard theme
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _grassrootsGreen = Color(0xFF43A047);
const _actionRed = Color(0xFFE63946);

class FeedbackButtons extends StatelessWidget {
  final FeedbackState currentState;
  final VoidCallback onPositive;
  final VoidCallback onNegative;
  final VoidCallback? onRegenerate;
  final bool showRegenerate;

  const FeedbackButtons({
    super.key,
    required this.currentState,
    required this.onPositive,
    required this.onNegative,
    this.onRegenerate,
    this.showRegenerate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thumbs Up
        _FeedbackButton(
          icon: currentState == FeedbackState.positive
              ? Icons.thumb_up
              : Icons.thumb_up_outlined,
          color: currentState == FeedbackState.positive
              ? _grassrootsGreen
              : Colors.grey,
          onPressed: currentState == FeedbackState.none ? onPositive : null,
          tooltip: 'Good response',
        ),

        const SizedBox(width: 4),

        // Thumbs Down
        _FeedbackButton(
          icon: currentState == FeedbackState.negative
              ? Icons.thumb_down
              : Icons.thumb_down_outlined,
          color: currentState == FeedbackState.negative
              ? _actionRed
              : Colors.grey,
          onPressed: currentState == FeedbackState.none ? onNegative : null,
          tooltip: 'Poor response',
        ),

        // Regenerate button
        if (showRegenerate && onRegenerate != null) ...[
          const SizedBox(width: 8),
          _FeedbackButton(
            icon: Icons.refresh,
            color: _momentumBlue,
            onPressed: onRegenerate,
            tooltip: 'Regenerate response',
          ),
        ],
      ],
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;

  const _FeedbackButton({
    required this.icon,
    required this.color,
    this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: onPressed != null ? color : color.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
