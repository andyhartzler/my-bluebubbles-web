import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:bluebubbles/models/crm/candidate.dart';
import 'social_embed_stub.dart'
    if (dart.library.html) 'social_embed_web.dart';

/// The Socials tab on `CandidateDetailScreen`: a vibe check.
///
/// Embeds the candidate's most recent TikTok and Instagram posts (creator /
/// profile embeds, no API keys) side by side on wide screens so a reviewer
/// gets a high-level read on how the candidate presents publicly. Every embed
/// carries a link-out chip; when a platform blocks embedding the chip is the
/// graceful path to the same content.
class CandidateSocialsPanel extends StatelessWidget {
  final Candidate candidate;

  const CandidateSocialsPanel({super.key, required this.candidate});

  /// "@user", "user", or any tiktok.com / instagram.com URL -> bare handle.
  static String? handleFrom(String? raw) {
    if (raw == null) return null;
    var v = raw.trim();
    if (v.isEmpty) return null;
    final url = Uri.tryParse(v);
    if (url != null && url.host.isNotEmpty) {
      final segs = url.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isEmpty) return null;
      v = segs.first;
    }
    v = v.replaceFirst('@', '');
    // Strip query/fragment leftovers from sloppy pastes.
    v = v.split('?').first.split('#').first;
    return v.isEmpty ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final tiktok = handleFrom(candidate.socialTiktok);
    final instagram = handleFrom(candidate.socialInstagram);

    final feeds = <Widget>[
      if (tiktok != null)
        _FeedCard(
          eyebrow: 'TIKTOK',
          handle: '@$tiktok',
          embedUrl: 'https://www.tiktok.com/embed/@$tiktok',
          profileUrl: 'https://www.tiktok.com/@$tiktok',
          icon: Icons.music_note_rounded,
        ),
      if (instagram != null)
        _FeedCard(
          eyebrow: 'INSTAGRAM',
          handle: '@$instagram',
          embedUrl: 'https://www.instagram.com/$instagram/embed/',
          profileUrl: 'https://www.instagram.com/$instagram/',
          icon: Icons.camera_alt_rounded,
        ),
    ];

    if (feeds.isEmpty) return _EmptyState(candidate: candidate);

    final isMobile = MediaQuery.of(context).size.width < 600;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Extra bottom padding on mobile so the profile FAB speed-dial never
      // covers the tail of the last embed.
      padding: EdgeInsets.fromLTRB(16, 16, 16, isMobile ? 96 : 40),
      children: [
        Text(
          'VIBE CHECK',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Most recent posts, straight from their feeds.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 860 && feeds.length > 1) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < feeds.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: feeds[i]),
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < feeds.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  feeds[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FeedCard extends StatelessWidget {
  final String eyebrow;
  final String handle;
  final String embedUrl;
  final String profileUrl;
  final IconData icon;

  const _FeedCard({
    required this.eyebrow,
    required this.handle,
    required this.embedUrl,
    required this.profileUrl,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => launchUrlString(profileUrl),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Open'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          // The embed itself. If the platform refuses to render in-frame the
          // Open chip above is the fallback path.
          SocialFeedEmbed(url: embedUrl, height: 640),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Candidate candidate;
  const _EmptyState({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final website = candidate.campaignWebsite;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off_rounded,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              'No TikTok or Instagram on file',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a handle to this candidate\'s profile and their recent '
              'posts will show up here. The nightly social scan also picks '
              'up handles advertised on campaign websites.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            if (website != null && website.isNotEmpty) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => launchUrlString(website),
                icon: const Icon(Icons.language, size: 16),
                label: const Text('Open campaign website'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
