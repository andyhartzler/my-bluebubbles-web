import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/submission_review_model.dart';

/// Renders the applicant's references as a Wrap of ~280px mini-cards. Phone
/// and email values copy to the clipboard on tap.
class ReferencesCard extends StatelessWidget {
  final List<ReferenceEntry> references;

  const ReferencesCard({super.key, required this.references});

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('References',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final ref in references)
                  _RefMiniCard(entry: ref),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RefMiniCard extends StatelessWidget {
  final ReferenceEntry entry;
  const _RefMiniCard({required this.entry});

  static const _copyable = {'Phone', 'Email'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.name ?? 'Reference ${entry.index}',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (entry.relationship != null) ...[
            const SizedBox(height: 2),
            Text(entry.relationship!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          for (final f in entry.fields)
            if (f.key != 'Name' && f.key != 'Relationship')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _copyable.contains(f.key)
                    ? InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: f.value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${f.key} copied'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(
                              f.key == 'Phone'
                                  ? Icons.phone_outlined
                                  : Icons.email_outlined,
                              size: 15,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f.value,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: cs.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.copy, size: 13, color: cs.primary),
                          ],
                        ),
                      )
                    : Text('${f.key}: ${f.value}',
                        style: theme.textTheme.bodyMedium),
              ),
        ],
      ),
    );
  }
}
