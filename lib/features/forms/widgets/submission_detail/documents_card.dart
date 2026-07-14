import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/submission_review_model.dart';

/// Collects the applicant's headshot, budget file, signature and any other
/// uploads into one card. Headshot opens a fullscreen zoomable viewer; the
/// budget file opens in a new tab via url_launcher; the signature renders on
/// a white container so dark ink stays visible in either theme.
class DocumentsCard extends StatelessWidget {
  final SubmissionReviewModel model;

  const DocumentsCard({super.key, required this.model});

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final children = <Widget>[];

    if (model.headshot != null && model.headshot!.isImage) {
      children.add(_Thumb(
        label: 'Headshot',
        file: model.headshot!,
        onTap: () => _showFullscreen(context, model.headshot!.url),
      ));
    }

    if (model.budgetFile != null) {
      children.add(_FileRow(
        icon: Icons.description_outlined,
        title: model.budgetFile!.name,
        subtitle: model.budgetFile!.prettySize,
        onTap: () => _open(model.budgetFile!.url),
      ));
    }

    for (final doc in model.documentAnswers) {
      final files = ReviewFile.parse(doc.rawValue);
      for (final f in files) {
        if (f.isImage) {
          children.add(_Thumb(
            label: doc.label,
            file: f,
            onTap: () => _showFullscreen(context, f.url),
          ));
        } else {
          children.add(_FileRow(
            icon: Icons.attach_file,
            title: f.name,
            subtitle: f.prettySize,
            onTap: () => _open(f.url),
          ));
        }
      }
    }

    if (model.signatureUrl != null && model.signatureUrl!.isNotEmpty) {
      children.add(_Signature(url: model.signatureUrl!, certified: model.certified));
    } else if (model.certified) {
      children.add(Row(
        children: [
          const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF1B7A3D)),
          const SizedBox(width: 8),
          Text('Certified truthful and complete',
              style: theme.textTheme.bodyMedium),
        ],
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();

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
            Text(
              'Documents',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImage(url: url),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String label;
  final ReviewFile file;
  final VoidCallback onTap;
  const _Thumb({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              file.url,
              width: 140,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 140,
                height: 140,
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined,
                    color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _FileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _Signature extends StatelessWidget {
  final String url;
  final bool certified;
  const _Signature({required this.url, required this.certified});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Signature',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
            if (certified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified_outlined,
                  size: 15, color: Color(0xFF1B7A3D)),
              const SizedBox(width: 3),
              Text('Certified',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: const Color(0xFF1B7A3D))),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline),
          ),
          child: Image.network(
            url,
            height: 110,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, __, ___) => const Text(
              'Signature on file',
              style: TextStyle(
                  color: Colors.black54, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'Could not load image',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
