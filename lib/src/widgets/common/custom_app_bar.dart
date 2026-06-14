import 'package:flutter/material.dart';

/// Dashboard-style app bar with a greeting line and an avatar action.
class GreetingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GreetingAppBar({
    super.key,
    required this.greeting,
    required this.name,
    this.actions,
  });

  final String greeting;
  final String name;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: 72,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
      actions: actions,
    );
  }
}
