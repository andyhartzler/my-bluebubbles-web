import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// In-app article reader. Renders the full scraped article body in
/// native typography (paragraph spacing, headings, blockquotes) with
/// AI summary + sentiment at the top, and a "Read original" link to
/// the source at the bottom.
///
/// Loads by news row id so we always get the latest full_content /
/// ai_summary / sentiment even if the list row was rendered from stale
/// cache.
class NewsArticleDetailScreen extends StatefulWidget {
  final String newsId;
  final String? fallbackHeadline;
  final String? fallbackSource;

  const NewsArticleDetailScreen({
    super.key,
    required this.newsId,
    this.fallbackHeadline,
    this.fallbackSource,
  });

  @override
  State<NewsArticleDetailScreen> createState() => _NewsArticleDetailScreenState();
}

class _NewsArticleDetailScreenState extends State<NewsArticleDetailScreen> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  Map<String, dynamic>? _row;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_supabase.isInitialized) {
      setState(() => _loading = false);
      return;
    }
    try {
      final resp = await _supabase.privilegedClient
          .from('candidate_news')
          .select()
          .eq('id', widget.newsId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _row = resp as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ NewsArticleDetailScreen error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _decodeHtml(String s) {
    return s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll(RegExp(r'&#\d+;'), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1E37), BrandColors.unityBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: BrandColors.sunriseGold))
              : _row == null
                  ? _missingState()
                  : _content(),
        ),
      ),
    );
  }

  Widget _missingState() {
    return Column(
      children: [
        _topBar(widget.fallbackHeadline ?? 'Article'),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'This article is no longer in the database.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    final r = _row!;
    final headline = _decodeHtml((r['headline'] as String? ?? widget.fallbackHeadline ?? '').trim());
    final source = (r['source'] as String? ?? widget.fallbackSource ?? '').trim();
    final url = r['url'] as String?;
    final publishedAt = r['published_at'] as String?;
    final aiSummary = (r['ai_summary'] as String? ?? '').trim();
    final label = (r['sentiment_label'] as String? ?? '').toLowerCase();
    final score = r['sentiment_score'];
    final keyQuotes = (r['key_quotes'] as List?) ?? const [];
    final fullContent = (r['full_content'] as String? ?? '').trim();
    final mentions = r['candidate_mentions'];

    final sentimentColor = switch (label) {
      'positive' => BrandColors.success,
      'negative' => BrandColors.republicanRed,
      'mixed' => BrandColors.sunriseGold,
      _ => Colors.grey,
    };
    final sentimentEmoji = switch (label) {
      'positive' => '🟢',
      'negative' => '🔴',
      'mixed' => '🟡',
      'neutral' => '⚪',
      _ => '⚪',
    };

    return Column(
      children: [
        _topBar(source.isNotEmpty ? source : 'Article'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Headline
              Text(
                headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),

              // Source + date row
              Row(children: [
                if (source.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BrandColors.momentumBlue.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BrandColors.momentumBlue.withOpacity(0.4)),
                    ),
                    child: Text(source,
                        style: const TextStyle(
                            color: BrandColors.momentumBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                if (publishedAt != null)
                  Text(_formatDate(publishedAt),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                const Spacer(),
                if (mentions is int && mentions > 0)
                  Text('mentioned ${mentions}×',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ]),
              const SizedBox(height: 20),

              // Sentiment + summary card
              if (aiSummary.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sentimentColor.withOpacity(0.18),
                        sentimentColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sentimentColor.withOpacity(0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(sentimentEmoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          label.isEmpty ? 'AI SUMMARY' : '${label.toUpperCase()}   •   AI SUMMARY',
                          style: TextStyle(
                            color: sentimentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (score is num) ...[
                          const Spacer(),
                          Text(
                            'score ${(score as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _decodeHtml(aiSummary),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

              // Key quotes
              if (keyQuotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._keyQuotes(keyQuotes),
              ],

              const SizedBox(height: 22),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 18),

              // Article body rendered as markdown.
              if (fullContent.isNotEmpty)
                MarkdownBody(
                  data: _decodeHtml(fullContent),
                  selectable: true,
                  styleSheet: _markdownStyle(context),
                )
              else ...[
                // Fallback: render the snippet, then the summary, then
                // offer an explicit "Fetch now" so the user can force a
                // digest without leaving the app.
                if ((r['snippet'] as String? ?? '').trim().isNotEmpty)
                  Text(
                    _decodeHtml((r['snippet'] as String).trim()),
                    style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.55),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BrandColors.sunriseGold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.schedule, color: BrandColors.sunriseGold, size: 16),
                        const SizedBox(width: 8),
                        Text('This article hasn\'t been digested yet',
                            style: TextStyle(
                                color: BrandColors.sunriseGold.withOpacity(0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        'The AI digest pipeline fetches full article text, extracts sentiment, and pulls key quotes. '
                        "New articles get processed in rolling batches — there's nothing for this one yet. Tap 'Read original' "
                        'to see it on the source site.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              if (url != null && url.isNotEmpty)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(url),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Read original'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.momentumBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  List<Widget> _keyQuotes(List quotes) {
    final widgets = <Widget>[];
    for (final q in quotes) {
      if (q is! Map) continue;
      final quote = _decodeHtml((q['quote'] as String? ?? '').trim());
      final speaker = (q['speaker'] as String? ?? '').trim();
      if (quote.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              left: BorderSide(color: BrandColors.sunriseGold, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“$quote”',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  )),
              if (speaker.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('— $speaker',
                    style: TextStyle(
                      color: BrandColors.sunriseGold.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  MarkdownStyleSheet _markdownStyle(BuildContext ctx) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(ctx));
    return base.copyWith(
      p: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.55),
      pPadding: const EdgeInsets.only(bottom: 12),
      h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
      h2: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.3),
      h3: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
      h4: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w600),
      a: const TextStyle(color: BrandColors.momentumBlue, decoration: TextDecoration.underline),
      em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      blockquote: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 15,
        fontStyle: FontStyle.italic,
        height: 1.45,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      blockquoteDecoration: BoxDecoration(
        color: BrandColors.sunriseGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: BrandColors.sunriseGold, width: 3)),
      ),
      listBullet: const TextStyle(color: Colors.white, fontSize: 15),
      listIndent: 20,
      code: TextStyle(
        color: BrandColors.sunriseGold,
        backgroundColor: Colors.white.withOpacity(0.06),
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15))),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
