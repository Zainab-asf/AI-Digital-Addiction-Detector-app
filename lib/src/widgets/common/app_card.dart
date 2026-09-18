import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// The standard LoopAware surface: white (or dark) card, hairline border,
/// 16px radius and a barely-there shadow. Every panel in the app uses this
/// so cards look identical from screen to screen.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child:
          onTap == null
              ? content
              : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onTap,
                  child: content,
                ),
              ),
    );
  }
}

/// Small title row used at the top of a card: bold label, optional caption
/// underneath and an optional trailing widget (link, badge, legend).
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.muted = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Renders the title as a quiet label instead of a heading, for cards
  /// whose main content is a large number.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    muted
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.titleMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
