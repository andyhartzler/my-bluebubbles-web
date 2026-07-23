import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Surfaces the researched money-intelligence knowledge base (public.money_profiles)
/// inside the CRM. Fetches a single profile via the RPC
/// get_money_profile(entity_type, entity_key) and renders it as an expandable
/// "Intelligence Profile" card: headline teaser, narrative markdown, structured
/// profile chips, cited sources, a confidence badge, and the research date.
///
/// Designed for the CRM's dark navy branded surfaces (white-on-navy), so it reads
/// identically in light and dark app themes — the card supplies its own dark
/// surface rather than relying on Theme.cardColor.
///
/// entity_type / entity_key contract (see money_profiles.entity_key comment):
///   donor          → mec_donors.id as text
///   committee      → mec_id
///   payee          → normalized payee name (== mec_committee_payee_aggregate.payee_company)
///   fec_committee  → FEC cmte_id
class IntelligenceProfileSection extends StatefulWidget {
  final String entityType;

  /// The entity key. When null/empty the RPC is skipped and the empty state is
  /// shown (or nothing, when [hideWhenEmpty]).
  final String? entityKey;

  /// Accent used for the header icon / border. Defaults to momentum blue.
  final Color accentColor;

  /// Optional label rendered under the section title (e.g. a committee name) —
  /// useful when several profiles are stacked on one screen.
  final String? subtitle;

  /// When true, renders nothing at all if the profile is missing (used where
  /// several optional profiles are stacked, e.g. a candidate's linked committees).
  /// When false (default), shows a graceful "No intelligence profile yet" card.
  final bool hideWhenEmpty;

  /// Whether the card starts expanded.
  final bool initiallyExpanded;

  const IntelligenceProfileSection({
    super.key,
    required this.entityType,
    required this.entityKey,
    this.accentColor = BrandColors.momentumBlue,
    this.subtitle,
    this.hideWhenEmpty = false,
    this.initiallyExpanded = false,
  });

  @override
  State<IntelligenceProfileSection> createState() =>
      _IntelligenceProfileSectionState();
}

class _IntelligenceProfileSectionState
    extends State<IntelligenceProfileSection> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _load();
  }

  @override
  void didUpdateWidget(covariant IntelligenceProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityKey != widget.entityKey ||
        oldWidget.entityType != widget.entityType) {
      _load();
    }
  }

  Future<void> _load() async {
    final key = widget.entityKey?.trim();
    if (key == null || key.isEmpty || !_supabase.isInitialized) {
      if (mounted) {
        setState(() {
          _profile = null;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await _supabase.client.rpc(
        'get_money_profile',
        params: {
          'p_entity_type': widget.entityType,
          'p_entity_key': key,
        },
      );
      if (mounted) {
        setState(() {
          _profile = resp is Map<String, dynamic> ? resp : null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('IntelligenceProfileSection load error: $e');
      if (mounted) {
        setState(() {
          _profile = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _shell(child: _loadingBody());
    if (_profile == null) {
      if (widget.hideWhenEmpty) return const SizedBox.shrink();
      return _shell(child: _emptyBody());
    }
    return _shell(child: _profileBody(_profile!));
  }

  // ── Outer card shell (dark navy branded surface) ──
  Widget _shell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accentColor.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: widget.accentColor.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _titleRow({Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.auto_awesome,
              color: widget.accentColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Intelligence Profile',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3)),
              if ((widget.subtitle ?? '').trim().isNotEmpty)
                Text(widget.subtitle!.trim(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _loadingBody() {
    return Row(
      children: [
        Expanded(child: _titleRow()),
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: BrandColors.momentumBlue),
        ),
      ],
    );
  }

  Widget _emptyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.search_off,
                color: Colors.white.withOpacity(0.4), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('No intelligence profile yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      height: 1.4)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _profileBody(Map<String, dynamic> p) {
    final headline = (p['headline'] as String? ?? '').trim();
    final confidence = (p['confidence'] as String? ?? '').trim();
    final narrative = (p['narrative_md'] as String? ?? '').trim();
    final profile = p['profile'];
    final sources = (p['sources'] as List?) ?? const [];
    final researchedAt = p['researched_at'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — tappable to expand/collapse.
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: _titleRow(
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (confidence.isNotEmpty) _confidenceBadge(confidence),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more,
                      color: Colors.white.withOpacity(0.7), size: 22),
                ),
              ],
            ),
          ),
        ),

        // Headline teaser — always visible.
        if (headline.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            headline,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500),
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ],

        // Expanded detail.
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrative.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),
                MarkdownBody(
                  data: narrative,
                  selectable: true,
                  styleSheet: _markdownStyle(context),
                  onTapLink: (text, href, title) {
                    if (href != null) _openUrl(href);
                  },
                ),
              ],
              ..._profileChips(profile),
              ..._sourcesBlock(sources),
              if (researchedAt != null) ...[
                const SizedBox(height: 14),
                Text('Researched ${_formatDate(researchedAt)}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),

        // Collapsed hint.
        if (!_expanded) ...[
          const SizedBox(height: 8),
          Text('Tap to read the full profile',
              style: TextStyle(
                  color: widget.accentColor.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _confidenceBadge(String confidence) {
    final c = confidence.toLowerCase();
    Color color;
    switch (c) {
      case 'high':
        color = BrandColors.success;
        break;
      case 'medium':
        color = BrandColors.sunriseGold;
        break;
      default:
        color = BrandColors.slateBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text('${confidence[0].toUpperCase()}${confidence.substring(1)} confidence',
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  // ── Structured profile chips ──
  List<Widget> _profileChips(dynamic profile) {
    if (profile is! Map || profile.isEmpty) return const [];
    final chips = <Widget>[];
    profile.forEach((key, value) {
      final label = _humanize(key.toString());
      if (value == null) return;
      if (value is List) {
        for (final item in value) {
          if (item == null) continue;
          if (item is Map || item is List) continue; // skip nested structures
          chips.add(_chip(label, item.toString()));
        }
      } else if (value is Map) {
        return; // skip nested objects — handled elsewhere
      } else {
        final s = value.toString().trim();
        if (s.isEmpty) return;
        chips.add(_chip(label, s));
      }
    });
    if (chips.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      const Divider(color: Colors.white12, height: 1),
      const SizedBox(height: 14),
      Text('KEY FACTS',
          style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: chips),
    ];
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: widget.accentColor.withOpacity(0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Sources ──
  List<Widget> _sourcesBlock(List<dynamic> sources) {
    if (sources.isEmpty) return const [];
    final rows = <Widget>[];
    for (var i = 0; i < sources.length; i++) {
      final src = sources[i];
      if (src is! Map) continue;
      final url = (src['url'] as String? ?? '').trim();
      final claim =
          (src['claim'] as String? ?? src['title'] as String? ?? '').trim();
      final isLink = url.startsWith('http://') || url.startsWith('https://');
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: isLink ? () => _openUrl(url) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (claim.isNotEmpty)
                        Text(claim,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                height: 1.35)),
                      if (isLink)
                        Text(_prettyHost(url),
                            style: const TextStyle(
                                color: BrandColors.momentumBlue,
                                fontSize: 11,
                                decoration: TextDecoration.underline))
                      else if (url.isNotEmpty)
                        Text(url,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                if (isLink)
                  Icon(Icons.open_in_new,
                      color: Colors.white.withOpacity(0.35), size: 14),
              ],
            ),
          ),
        ),
      );
    }
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      const Divider(color: Colors.white12, height: 1),
      const SizedBox(height: 14),
      Text('SOURCES',
          style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0)),
      const SizedBox(height: 10),
      ...rows,
    ];
  }

  MarkdownStyleSheet _markdownStyle(BuildContext ctx) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(ctx));
    return base.copyWith(
      p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.55),
      pPadding: const EdgeInsets.only(bottom: 10),
      h1: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.25),
      h2: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.3),
      h3: const TextStyle(
          color: Colors.white,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          height: 1.3),
      a: const TextStyle(
          color: BrandColors.momentumBlue,
          decoration: TextDecoration.underline),
      em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
      strong:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      blockquote: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
          height: 1.45),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      blockquoteDecoration: BoxDecoration(
        color: BrandColors.sunriseGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
            left: BorderSide(color: BrandColors.sunriseGold, width: 3)),
      ),
      listBullet: const TextStyle(color: Colors.white, fontSize: 14),
      listIndent: 20,
      code: TextStyle(
        color: BrandColors.sunriseGold,
        backgroundColor: Colors.white.withOpacity(0.06),
        fontFamily: 'monospace',
        fontSize: 12.5,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15))),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('IntelligenceProfileSection openUrl error: $e');
    }
  }

  String _humanize(String key) {
    final cleaned = key.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _prettyHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.host.replaceFirst('www.', '');
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
