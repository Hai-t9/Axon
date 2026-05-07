import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, thickness: 1)),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(child: Divider(height: 1, thickness: 1)),
      ],
    );
  }
}
