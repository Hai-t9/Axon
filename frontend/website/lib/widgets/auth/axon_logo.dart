import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AxonLogo extends StatelessWidget {
  const AxonLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 10 : 12,
          height: compact ? 10 : 12,
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('Axon', style: textStyle),
      ],
    );
  }
}
