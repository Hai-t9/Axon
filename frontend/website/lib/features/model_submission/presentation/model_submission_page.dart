import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/model_submission_models.dart';
import '../state/model_submission_controller.dart';

class ModelSubmissionPage extends ConsumerWidget {
  const ModelSubmissionPage({super.key, required this.competitionId});

  static const routeName = 'model-submission';
  static const routePath = '/competitions/:id/models';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/models';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsState = ref.watch(modelListProvider(competitionId));
    final specState = ref.watch(modelSpecProvider(competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Model Submission', subtitle: 'Submit and manage models'),
          const SizedBox(height: AppSpacing.lg),
          specState.whenOrNull(
            data: (spec) => _buildSpecCard(context, spec as ModelSpec),
          ) ?? const SizedBox.shrink(),
          const SizedBox(height: AppSpacing.lg),
          Text('Submitted Models',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          modelsState.when(
            data: (models) {
              if (models.isEmpty) {
                return _emptyState(context);
              }
              return _buildModelList(context, models);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _errorState(context, err.toString(), ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCard(BuildContext context, ModelSpec spec) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submission Requirements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text('Max size: ${spec.maxSizeMb}MB'),
          if (spec.supportedFormats.isNotEmpty)
            Text('Supported formats: ${spec.supportedFormats.join(', ')}'),
        ],
      ),
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
          Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text('No models submitted yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Submit a Docker model package to get started.'),
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
          Text('Unable to load models',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(error),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => ref.refresh(modelListProvider(competitionId)),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList(BuildContext context, List<ModelSubmission> models) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              color: AppColors.surfaceAlt,
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Filename',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 2, child: Text('Status',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(flex: 1, child: Text('Version',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                ],
              ),
            ),
            ...(models as List<ModelSubmission>).map((ModelSubmission m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.3))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.filename, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (m.framework != null)
                            Text(m.framework!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: _statusChip(m.status)),
                    Expanded(
                      flex: 1,
                      child: Text('v${m.version}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'completed' => AppColors.success,
      'failed' => AppColors.error,
      'evaluating' || 'queued' => const Color(0xFFE5A53C),
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
