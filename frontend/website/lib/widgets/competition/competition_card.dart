import 'package:flutter/material.dart';

import '../../features/competition/data/competition_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class CompetitionCard extends StatelessWidget {
  const CompetitionCard({
    super.key,
    required this.competition,
    this.onOpen,
  });

  final Competition competition;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(competition.launchDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    competition.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (dateLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
            if (competition.description != null &&
                competition.description!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                competition.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (competition.invitationLink != null &&
                competition.invitationLink!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Invitation link',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                competition.invitationLink!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                child: const Text('Open dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year}-${_two(date.month)}-${_two(date.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
