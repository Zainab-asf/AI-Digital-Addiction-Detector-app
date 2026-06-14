import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/formatters.dart';

/// Compact 24-cell strip showing the intensity of phone use across the day.
class HourlyHeatmap extends StatelessWidget {
  const HourlyHeatmap({
    super.key,
    required this.hourlyMinutes,
    this.height = 44,
  });

  final List<int> hourlyMinutes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMinutes = hourlyMinutes.isEmpty
        ? 0
        : hourlyMinutes.reduce((a, b) => a > b ? a : b);
    final base = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var hour = 0; hour < hourlyMinutes.length; hour++)
              Expanded(
                child: Tooltip(
                  message:
                      '${Formatters.hourLabel(hour)} • ${Formatters.duration(hourlyMinutes[hour])}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: maxMinutes == 0
                            ? base
                            : Color.lerp(
                                base,
                                AppTheme.primary,
                                (hourlyMinutes[hour] / maxMinutes)
                                    .clamp(0.0, 1.0),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DefaultTextStyle.merge(
          style: theme.textTheme.bodySmall ?? const TextStyle(),
          child: Row(
            children: [
              const Expanded(child: Text('12am')),
              const Expanded(
                child: Text('6am', textAlign: TextAlign.center),
              ),
              const Expanded(
                child: Text('12pm', textAlign: TextAlign.center),
              ),
              const Expanded(
                child: Text('6pm', textAlign: TextAlign.center),
              ),
              const Expanded(
                child: Text('11pm', textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
