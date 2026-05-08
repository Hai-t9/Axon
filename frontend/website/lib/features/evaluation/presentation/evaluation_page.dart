import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/evaluation_models.dart';
import '../state/evaluation_controller.dart';

class EvaluationPage extends ConsumerWidget {
  const EvaluationPage({super.key, required this.competitionId});

  static const routeName = 'evaluation';
  static const routePath = '/competitions/:id/evaluation';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/evaluation';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(evaluationListProvider(competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Evaluations', subtitle: 'Model evaluation progress and results'),
          const SizedBox(height: AppSpacing.lg),
          state.when(
            data: (evaluations) {
              final items = evaluations as List<EvaluationResult>;
              if (items.isEmpty) {
                return _emptyState(context);
              }
              return Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _buildEvalCard(context, items[index]);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _errorState(context, err.toString(), ref),
          ),
        ],
      ),
    );
  }

  Widget _buildEvalCard(BuildContext context, EvaluationResult eval) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Evaluation #${eval.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (eval.teamName != null)
                      Text(eval.teamName!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              _statusChip(eval.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _metric('Protocol', eval.protocol.toUpperCase()),
              const SizedBox(width: AppSpacing.lg),
              _metric('Folds', '${eval.completedFolds}/${eval.totalFolds}'),
              if (eval.accuracy != null) ...[
                const SizedBox(width: AppSpacing.lg),
                _metric('Accuracy', eval.accuracy!.toStringAsFixed(4)),
              ],
            ],
          ),
          if (eval.totalFolds > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: eval.progress,
                backgroundColor: AppColors.border,
                color: eval.status == 'completed' ? AppColors.success : AppColors.primaryDark,
                minHeight: 6,
              ),
            ),
          ],
          if (eval.status == 'completed' && eval.accuracy != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _miniMetric('Precision', eval.precision?.toStringAsFixed(3) ?? '-'),
                const SizedBox(width: AppSpacing.md),
                _miniMetric('Recall', eval.recall?.toStringAsFixed(3) ?? '-'),
                const SizedBox(width: AppSpacing.md),
                _miniMetric('F1', eval.f1Score?.toStringAsFixed(3) ?? '-'),
              ],
            ),
          ],
          if (eval.completedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('Completed: ${eval.completedAt}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'completed' => AppColors.success,
      'failed' => AppColors.error,
      'in_progress' || 'evaluating' => const Color(0xFFE5A53C),
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          Icon(Icons.science_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text('No evaluations yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Evaluations will appear here once models are submitted.'),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context, String error, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unable to load evaluations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(error),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => ref.refresh(evaluationListProvider(competitionId)),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
