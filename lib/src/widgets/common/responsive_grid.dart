import 'package:flutter/material.dart';

/// Lays [children] out in rows of [columns], with equal-height cells in each
/// row. Heights follow content (no fixed aspect ratio), so large text scales
/// and narrow phones never clip.
///
/// Rows are sized with [IntrinsicHeight], so children must support intrinsic
/// measurement — avoid `LayoutBuilder` inside a cell.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = 16,
    this.runSpacing,
    this.flex,
  });

  final int columns;
  final List<Widget> children;
  final double spacing;
  final double? runSpacing;

  /// Optional per-column flex factors (length must equal [columns]).
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    final cols = columns < 1 ? 1 : columns;
    if (cols == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: runSpacing ?? spacing),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += cols) {
      final cells = <Widget>[];
      for (var col = 0; col < cols; col++) {
        final index = start + col;
        if (col > 0) cells.add(SizedBox(width: spacing));
        cells.add(
          Expanded(
            flex: flex != null && flex!.length == cols ? flex![col] : 1,
            child:
                index < children.length
                    ? children[index]
                    : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing ?? spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
