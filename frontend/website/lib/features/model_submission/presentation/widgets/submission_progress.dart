import 'package:flutter/material.dart';
import 'package:website/theme/app_spacing.dart';

class SubmissionProgress extends StatelessWidget {
  final double progress;
  final String status;

  const SubmissionProgress({
    super.key,
    required this.progress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.xl),
        Text(status, style: Theme.of(context).textTheme.bodyMedium),
        SizedBox(height: AppSpacing.md),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
        SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(progress * 100).toInt()}%'),
        ),
      ],
    );
  }
}
