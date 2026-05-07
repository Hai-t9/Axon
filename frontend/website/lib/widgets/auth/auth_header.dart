import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'axon_logo.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AxonLogo(),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: textTheme.bodyMedium),
      ],
    );
  }
}
