import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bill_document.dart';
import '../utils/bill_helpers.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

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
    if (documents.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group documents by type
    final versions = documents.where((d) => d.isVersion).toList();
    final fiscalNotes = documents.where((d) => d.isFiscalNote).toList();
    final committeeReports = documents.where((d) => d.isCommitteeReport).toList();
    final amendments = documents.where((d) => d.isAmendment).toList();
    final other = documents.where((d) =>
        !d.isVersion && !d.isFiscalNote && !d.isCommitteeReport && !d.isAmendment).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Text(
                    'Documents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _unityBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _momentumBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${documents.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (versions.isNotEmpty)
            _buildDocumentSection(context, 'Bill Versions', Icons.description, versions),
          if (amendments.isNotEmpty)
            _buildDocumentSection(context, 'Amendments', Icons.edit_document, amendments),
          if (fiscalNotes.isNotEmpty)
            _buildDocumentSection(context, 'Fiscal Notes', Icons.attach_money, fiscalNotes),
          if (committeeReports.isNotEmpty)
            _buildDocumentSection(context, 'Committee Reports', Icons.summarize, committeeReports),
          if (other.isNotEmpty)
            _buildDocumentSection(context, 'Other Documents', Icons.folder, other),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _unityBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open,
                size: 48,
                color: _unityBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No documents available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Documents will appear here when available',
              style: TextStyle(
                fontSize: 14,
                color: _unityBlue.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection(
    BuildContext context,
    String title,
    IconData icon,
    List<BillDocument> docs,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _momentumBlue),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
          ),
          ...docs.map((doc) => _buildDocumentTile(context, doc)),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext context, BillDocument doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 2,
        color: _unityBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        if (doc.documentDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              BillHelpers.formatDate(doc.documentDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
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
                        color: _momentumBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                  children: doc.links.map((link) => _buildLinkButton(context, link)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkButton(BuildContext context, DocumentLink link) {
    final icon = _getLinkIcon(link.mediaType);

    return ElevatedButton.icon(
      onPressed: () => _openLink(context, link.url),
      icon: Icon(icon, size: 16),
      label: Text(link.mediaType?.toUpperCase() ?? 'VIEW'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _momentumBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    final newCount = documents.where((d) => d.isNew).length;

    return Row(
      children: [
        Icon(
          Icons.description_outlined,
          size: 14,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '${documents.length} docs',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        if (newCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _momentumBlue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$newCount new',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
