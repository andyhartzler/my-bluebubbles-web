import 'package:flutter/material.dart';

import '../../theme/moyd_brand.dart';

/// One scroll target for the review's section navigator.
class ReviewNavTarget {
  final String id;
  final String label;
  const ReviewNavTarget({required this.id, required this.label});
}

/// Horizontal pill row navigating the review's sections. One widget, two
/// mounts: the body renders it in-flow under the hero AND as a pinned
/// duplicate in an overlay once scrolled past — both instances stay in sync
/// through the shared [activeId] notifier, so no per-frame setState touches
/// the body's widget tree.
///
/// Pills self-center when they activate (critical on phones where the row
/// overflows), and a 16px surface fade at each end signals overflow.
class ReviewSectionNav extends StatefulWidget {
  final List<ReviewNavTarget> targets;
  final ValueNotifier<String?> activeId;
  final ValueChanged<String> onTap;

  const ReviewSectionNav({
    super.key,
    required this.targets,
    required this.activeId,
    required this.onTap,
  });

  /// Fixed row height (36px pills + 8px vertical padding); the pinned bar
  /// never reflows.
  static const double height = 52;

  @override
  State<ReviewSectionNav> createState() => _ReviewSectionNavState();
}

class _ReviewSectionNavState extends State<ReviewSectionNav> {
  final ScrollController _controller = ScrollController();
  final Map<String, GlobalKey> _pillKeys = {};
  bool _fadeLeft = false;
  bool _fadeRight = false;

  @override
  void initState() {
    super.initState();
    widget.activeId.addListener(_onActiveChanged);
    _controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateFades();
      _centerActive();
    });
  }

  @override
  void didUpdateWidget(covariant ReviewSectionNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.activeId, widget.activeId)) {
      oldWidget.activeId.removeListener(_onActiveChanged);
      widget.activeId.addListener(_onActiveChanged);
    }
  }

  @override
  void dispose() {
    widget.activeId.removeListener(_onActiveChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerActive();
    });
  }

  /// Scroll the active pill toward the center of THIS row's own horizontal
  /// viewport (position-scoped, so it never disturbs ancestor scrollables).
  void _centerActive() {
    final key = _pillKeys[widget.activeId.value];
    final ctx = key?.currentContext;
    if (ctx == null || !_controller.hasClients) return;
    final ro = ctx.findRenderObject();
    if (ro == null || !ro.attached) return;
    _controller.position.ensureVisible(
      ro,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _updateFades() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final left = pos.pixels > 1;
    final right = pos.pixels < pos.maxScrollExtent - 1;
    if (left != _fadeLeft || right != _fadeRight) {
      setState(() {
        _fadeLeft = left;
        _fadeRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    for (final t in widget.targets) {
      _pillKeys.putIfAbsent(t.id, () => GlobalKey());
    }

    return SizedBox(
      height: ReviewSectionNav.height,
      child: Stack(
        children: [
          FocusTraversalGroup(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _updateFades();
                return false;
              },
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ValueListenableBuilder<String?>(
                  valueListenable: widget.activeId,
                  builder: (context, active, _) => Row(
                    children: [
                      for (int i = 0; i < widget.targets.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _NavPill(
                          key: _pillKeys[widget.targets[i].id],
                          label: widget.targets[i].label,
                          active: widget.targets[i].id == active,
                          onTap: () => widget.onTap(widget.targets[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_fadeLeft) _edgeFade(cs, alignLeft: true),
          if (_fadeRight) _edgeFade(cs, alignLeft: false),
        ],
      ),
    );
  }

  Widget _edgeFade(ColorScheme cs, {required bool alignLeft}) {
    return Positioned(
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
              end: alignLeft ? Alignment.centerRight : Alignment.centerLeft,
              colors: [cs.surface, cs.surface.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: '$label section',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: cs.onSurface.withOpacity(0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Active: white on the fixed navy fill (> 8:1 in both themes);
              // the gold hairline separates the pill from dark surfaces.
              // Inactive: onSurfaceVariant on the ambient surface (AA in
              // both M3 themes).
              color: active ? MoydBrand.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? MoydBrand.gold : cs.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
