import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
    this.backButtonPath,
    @Deprecated('Use actions instead') this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final Widget? trailing;
  final String? backButtonPath;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (backButtonPath != null) ...[
          TextButton.icon(
            onPressed: () => context.go(backButtonPath!),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 40),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: textTheme.bodyMedium),
                ],
              ),
            ),
            if (actions != null || trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              Row(
                children: actions ?? [trailing!],
              ),
            ],
          ],
        ),
      ],
    );
  }
}
