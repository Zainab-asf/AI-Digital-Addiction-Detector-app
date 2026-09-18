import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Shared page frame for the four main tabs: a title block with optional
/// overline and actions, then a width-capped, pull-to-refresh content column
/// with responsive gutters.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.builder,
    this.overline,
    this.subtitle,
    this.actions,
    this.onRefresh,
    this.maxWidth = 1200,
  });

  final String title;
  final String? overline;
  final String? subtitle;

  /// Header actions for the resolved layout. On compact widths they stay on
  /// the title row, so keep them small there (icon buttons).
  final List<Widget> Function(PageLayout layout)? actions;

  /// Builds the page body for the available content width.
  final List<Widget> Function(BuildContext context, PageLayout layout) builder;

  final Future<void> Function()? onRefresh;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = PageLayout.forWidth(
              constraints.maxWidth,
              maxWidth: maxWidth,
            );
            final list = ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                layout.gutter,
                layout.compact ? 16 : 32,
                layout.gutter,
                layout.compact ? 24 : 40,
              ),
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(
                          title: title,
                          overline: overline,
                          subtitle: subtitle,
                          actions: actions?.call(layout) ?? const [],
                          compact: layout.compact,
                        ),
                        SizedBox(height: layout.compact ? 16 : 24),
                        ...builder(context, layout),
                      ],
                    ),
                  ),
                ),
              ],
            );
            if (onRefresh == null) return list;
            return RefreshIndicator(onRefresh: onRefresh!, child: list);
          },
        ),
      ),
    );
  }
}

/// Resolved layout facts for a page body.
class PageLayout {
  const PageLayout({
    required this.width,
    required this.gutter,
    required this.compact,
    required this.wide,
  });

  factory PageLayout.forWidth(double available, {double maxWidth = 1200}) {
    final compact = available < AppTheme.compactMax;
    final gutter =
        compact ? 16.0 : (available < AppTheme.sidebarMin ? 24.0 : 40.0);
    final width = (available - gutter * 2).clamp(0.0, maxWidth);
    return PageLayout(
      width: width,
      gutter: gutter,
      compact: compact,
      wide: width >= AppTheme.wideMin,
    );
  }

  /// Width of the content column.
  final double width;
  final double gutter;

  /// Phone-sized: stack everything, tighter spacing.
  final bool compact;

  /// Enough room for multi-column dashboards.
  final bool wide;

  /// Standard gap between cards.
  double get gap => compact ? 12 : 16;
}

/// Page title block. The title wraps rather than truncating, and actions sit
/// on the same row, bottom-aligned with the title.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.actions = const [],
    this.compact = false,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null) ...[
                Text(
                  overline!,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style:
                      compact
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.headlineMedium,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ],
      ],
    );
  }
}
