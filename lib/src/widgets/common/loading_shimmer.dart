import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Lightweight skeleton placeholder with a slow, subtle pulse. Uses an
/// animated opacity instead of pulling in a shimmer package.
class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = 8,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: 0.55,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceMuted : c.borderSubtle,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton of a standard card: a label, a large value and a detail line,
/// framed like [AppCard] so the layout doesn't jump when data arrives.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 120, this.lines = 2});

  final double height;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingShimmer(height: 12, width: 96),
          const SizedBox(height: 12),
          const LoadingShimmer(height: 26, width: 140),
          const Spacer(),
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            LoadingShimmer(height: 10, width: i.isEven ? double.infinity : 160),
          ],
        ],
      ),
    );
  }
}

/// Convenience: a vertical stack of skeleton list rows.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              LoadingShimmer(height: 36, width: 36, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingShimmer(height: 12, width: 120),
                    SizedBox(height: 8),
                    LoadingShimmer(height: 6),
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
