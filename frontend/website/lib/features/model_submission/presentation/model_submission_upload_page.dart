import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:website/theme/app_spacing.dart';
import 'package:website/widgets/layout/axon_scaffold.dart';
import 'package:website/widgets/layout/page_header.dart';
import 'package:website/features/model_submission/state/model_submission_controller.dart';
import 'package:website/features/model_submission/presentation/widgets/submission_form.dart';
import 'package:website/features/model_submission/presentation/widgets/submission_progress.dart';
import 'package:website/features/model_submission/presentation/widgets/submission_spec_card.dart';
import 'package:website/features/model_submission/presentation/model_submission_page.dart';

class ModelSubmissionUploadPage extends ConsumerWidget {
  final String competitionId;

  const ModelSubmissionUploadPage({
    super.key,
    required this.competitionId,
  });

  static const routeName = 'model_submission_upload';
  static const routePath = '/competitions/:id/models/submit';

  static String routeForId(String id) => '/competitions/$id/models/submit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelSubmissionControllerProvider(competitionId));
    final controller = ref.read(modelSubmissionControllerProvider(competitionId).notifier);
    final specAsync = ref.watch(modelSpecProvider(competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Submit New Model',
            subtitle: 'Upload your model and code for evaluation.',
            backButtonPath: ModelSubmissionPage.routeForId(competitionId),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Requirements Column
              Expanded(
                flex: 2,
                child: specAsync.when(
                  data: (spec) => SubmissionSpecCard(spec: spec),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Card(child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Error loading requirements: $err'),
                  )),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              // Form Column
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Model',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SubmissionForm(competitionId: competitionId),
                        if (state.isSubmitting)
                          SubmissionProgress(
                            progress: state.uploadProgress,
                            status: _getUploadStatus(state.uploadProgress),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: state.isSubmitting ? null : () => context.pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            ElevatedButton(
                              onPressed: state.isSubmitting || !state.isValid
                                  ? null
                                  : () async {
                                      await controller.submit();
                                      if (ref.read(modelSubmissionControllerProvider(competitionId)).error == null) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Model submitted successfully!')),
                                          );
                                          context.pop();
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xl,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                              child: state.isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Submit Model'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getUploadStatus(double progress) {
    if (progress < 0.3) return 'Preparing files...';
    if (progress < 0.9) return 'Uploading zip archive...';
    if (progress < 1.0) return 'Backend validation in progress...';
    return 'Submission complete!';
  }
}
