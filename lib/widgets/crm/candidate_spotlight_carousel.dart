import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

// ═══════════════════════════════════════════════════════════════
//  YOUNG DEMOCRAT SPOTLIGHT CAROUSEL
//  Horizontal scroll carousel with photo cards, swipe gestures,
//  and animated transitions for Young Dem candidates
// ═══════════════════════════════════════════════════════════════

class CandidateSpotlightCarousel extends StatefulWidget {
  final List<Candidate> candidates;
  final ValueChanged<Candidate> onCandidateTap;
  final bool showHeader;
  final double height;

  const CandidateSpotlightCarousel({
    super.key,
    required this.candidates,
    required this.onCandidateTap,
    this.showHeader = true,
    this.height = 220,
  });

  @override
  State<CandidateSpotlightCarousel> createState() =>
      _CandidateSpotlightCarouselState();
}

class _CandidateSpotlightCarouselState
    extends State<CandidateSpotlightCarousel> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.42,
      initialPage: 0,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: CurvedAnimation(parent: _animController, curve: Curves.easeIn),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) _buildHeader(),
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.candidates.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = (_pageController.page ?? 0.0) - index;
                      value = (1 - (value.abs() * 0.2)).clamp(0.85, 1.0);
                    }
                    return Center(
                      child: SizedBox(
                        height: Curves.easeInOut.transform(value) * widget.height,
                        child: child,
                      ),
                    );
                  },
                  child: _SpotlightCard(
                    candidate: widget.candidates[index],
                    index: index,
                    onTap: () => widget.onCandidateTap(widget.candidates[index]),
                  ),
                );
              },
            ),
          ),
          // Page indicator dots
          if (widget.candidates.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.candidates.length.clamp(0, 12),
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _currentPage ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? BrandColors.sunriseGold
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.star, color: BrandColors.sunriseGold, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Young Democrat Spotlight',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.candidates.length} candidates',
              style: const TextStyle(
                color: BrandColors.sunriseGold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual Spotlight Card ──

class _SpotlightCard extends StatelessWidget {
  final Candidate candidate;
  final int index;
  final VoidCallback onTap;

  const _SpotlightCard({
    required this.candidate,
    required this.index,
    required this.onTap,
  });

  static const _gradients = [
    [Color(0xFF1E3A5F), Color(0xFF2563EB)],
    [Color(0xFF2B4B8C), Color(0xFF4682B4)],
    [Color(0xFF273351), Color(0xFF3B82F6)],
    [Color(0xFF1E3A5F), Color(0xFF6366F1)],
    [Color(0xFF1A365D), Color(0xFF2DD4BF)],
    [Color(0xFF312E81), Color(0xFF818CF8)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    final c = candidate;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors[1].withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Score badge
              Row(
                children: [
                  Hero(
                    tag: 'spotlight-${c.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: BrandColors.sunriseGold.withOpacity(0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: BrandColors.sunriseGold.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        backgroundImage:
                            c.photoUrl != null && c.photoUrl!.isNotEmpty
                                ? NetworkImage(c.photoUrl!)
                                : null,
                        child: c.photoUrl == null || c.photoUrl!.isEmpty
                            ? Text(
                                c.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BrandColors.sunriseGold.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Match ${c.youngDemScore}%',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Name
              Text(
                c.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Age badge
              if (c.estimatedAge != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Age ${c.estimatedAge}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (c.hasSocialLinks) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.link, color: Colors.white38, size: 12),
                    ],
                  ],
                ),

              const Spacer(),

              // Office / District
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: BrandColors.sunriseGold.withOpacity(0.8),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        c.district != null
                            ? 'District ${c.district}'
                            : c.office,
                        style: TextStyle(
                          color: BrandColors.sunriseGold.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
