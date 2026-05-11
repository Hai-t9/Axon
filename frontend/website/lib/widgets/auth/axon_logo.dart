import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AxonLogo extends StatelessWidget {
  const AxonLogo({super.key, this.compact = false, this.size});

  final bool compact;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final logoSize = size ?? (compact ? 10.0 : 12.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Axon',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
        ),
      ],
    );
  }
}
