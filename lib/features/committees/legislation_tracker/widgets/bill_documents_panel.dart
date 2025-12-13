import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bill_document.dart';
import '../utils/bill_helpers.dart';

/// Panel for displaying bill documents and versions
class BillDocumentsPanel extends StatelessWidget {
  final List<BillDocument> documents;
  final bool showTitle;

  const BillDocumentsPanel({
    super.key,
    required this.documents,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (documents.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    // Group documents by type
    final versions = documents.where((d) => d.isVersion).toList();
    final fiscalNotes = documents.where((d) => d.isFiscalNote).toList();
    final committeeReports = documents.where((d) => d.isCommitteeReport).toList();
    final amendments = documents.where((d) => d.isAmendment).toList();
    final other = documents.where((d) =>
        !d.isVersion && !d.isFiscalNote && !d.isCommitteeReport && !d.isAmendment).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'Documents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${documents.length}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        if (versions.isNotEmpty)
          _buildDocumentSection(context, theme, 'Bill Versions', Icons.description, versions),
        if (amendments.isNotEmpty)
          _buildDocumentSection(context, theme, 'Amendments', Icons.edit_document, amendments),
        if (fiscalNotes.isNotEmpty)
          _buildDocumentSection(context, theme, 'Fiscal Notes', Icons.attach_money, fiscalNotes),
        if (committeeReports.isNotEmpty)
          _buildDocumentSection(context, theme, 'Committee Reports', Icons.summarize, committeeReports),
        if (other.isNotEmpty)
          _buildDocumentSection(context, theme, 'Other Documents', Icons.folder, other),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No documents available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Documents will appear here when available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection(
    BuildContext context,
    ThemeData theme,
    String title,
    IconData icon,
    List<BillDocument> docs,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...docs.map((doc) => _buildDocumentTile(context, theme, doc)),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext context, ThemeData theme, BillDocument doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.note ?? doc.documentType,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (doc.documentDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              BillHelpers.formatDate(doc.documentDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (doc.isNew)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              if (doc.links.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: doc.links.map((link) => _buildLinkButton(context, theme, link)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkButton(BuildContext context, ThemeData theme, DocumentLink link) {
    final icon = _getLinkIcon(link.mediaType);

    return OutlinedButton.icon(
      onPressed: () => _openLink(context, link.url),
      icon: Icon(icon, size: 16),
      label: Text(link.mediaType?.toUpperCase() ?? 'VIEW'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  IconData _getLinkIcon(String? mediaType) {
    switch (mediaType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'html':
        return Icons.language;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.open_in_new;
    }
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }
}

/// Compact document summary for bill cards
class DocumentSummary extends StatelessWidget {
  final List<BillDocument> documents;

  const DocumentSummary({
    super.key,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    final versions = documents.where((d) => d.isVersion).length;
    final other = documents.length - versions;
    final newCount = documents.where((d) => d.isNew).length;

    return Row(
      children: [
        Icon(
          Icons.description_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          '${documents.length} docs',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (newCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$newCount new',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
