import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// One option in a [SegmentedControl].
class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Inset segmented control: a muted track with the selected option raised
/// on a surface-colored thumb. Used for time periods and theme choice.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.semanticLabel,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Stretch segments to fill the available width.
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);

    Widget segment(SegmentOption<T> option) {
      final active = option.value == selected;
      final color = active ? c.textPrimary : c.textSecondary;
      final child = Semantics(
        button: true,
        selected: active,
        label: option.label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            onTap: active ? null : () => onChanged(option.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color:
                    active
                        ? (c.isDark ? c.borderStrong : c.surface)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow:
                    active && !c.isDark
                        ? const [
                          BoxShadow(
                            color: Color(0x14151B19),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (option.icon != null) ...[
                    Icon(option.icon, size: 16, color: color),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.segmentTrack,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              segment(options[i]),
            ],
          ],
        ),
      ),
    );
  }
}
