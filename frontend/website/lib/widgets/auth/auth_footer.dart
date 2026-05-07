import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.text,
    required this.actionText,
    this.onPressed,
  });

  final String text;
  final String actionText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(actionText),
        ),
      ],
    );
  }
}
