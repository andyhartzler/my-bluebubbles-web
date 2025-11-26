import 'package:bluebubbles/features/campaigns/widgets/campaign_brand.dart';
import 'package:flutter/material.dart';

class UnlayerEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const UnlayerEditor({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baseGradient = CampaignBrand.primaryGradient();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: baseGradient.colors.map((c) => c.withOpacity(0.08)).toList(),
          begin: baseGradient.begin,
          end: baseGradient.end,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CampaignBrand.momentumBlue.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email_outlined, color: CampaignBrand.unityBlue.withOpacity(0.8)),
                const SizedBox(width: 8),
                Text(
                  'Campaign body (HTML)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  'Add personalization with {{first_name}} and {{county}}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 12,
              minLines: 8,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Paste Unlayer HTML or craft your campaign here...\nUse {{first_name}} to personalize.',
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
