import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:website/theme/app_spacing.dart';
import 'package:website/widgets/layout/axon_scaffold.dart';
import 'package:website/widgets/layout/page_header.dart';
import 'package:website/features/model_submission/state/model_submission_controller.dart';
import 'package:website/features/model_submission/presentation/model_submission_upload_page.dart';

class ModelSubmissionPage extends ConsumerWidget {
  final String competitionId;

  const ModelSubmissionPage({
    super.key,
    required this.competitionId,
  });

  static const routeName = 'model_submission';
  static const routePath = '/competitions/:id/models';

  static String routeForId(String id) => '/competitions/$id/models';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(modelSubmissionListProvider(competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Model Submissions',
            subtitle: 'Manage and track your model submissions for this competition.',
            actions: [
              ElevatedButton.icon(
                onPressed: () => context.push(ModelSubmissionUploadPage.routeForId(competitionId)),
                icon: const Icon(Icons.upload),
                label: const Text('Submit Model'),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          submissionsAsync.when(
            data: (submissions) {
              if (submissions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                    child: Column(
                      children: [
                        Icon(Icons.model_training, size: 64, color: Colors.grey.shade400),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No models submitted yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        const Text('Start by submitting your first model zip file.'),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: submissions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final submission = submissions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(submission.status).withOpacity(0.1),
                      child: Icon(
                        _getStatusIcon(submission.status),
                        color: _getStatusColor(submission.status),
                      ),
                    ),
                    title: Text('${submission.filename} (v${submission.version})'),
                    subtitle: Text(
                      'Submitted on ${_formatDate(submission.submittedAt)}${submission.description != null ? ' • ${submission.description}' : ''}',
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(submission.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Text(
                        submission.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(submission.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'succeeded':
        return Colors.green;
      case 'failed':
      case 'error':
        return Colors.red;
      case 'processing':
      case 'validating':
      case 'running':
        return Colors.blue;
      case 'pending':
      case 'queued':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'succeeded':
        return Icons.check_circle;
      case 'failed':
      case 'error':
        return Icons.error;
      case 'processing':
      case 'validating':
      case 'running':
        return Icons.sync;
      case 'pending':
      case 'queued':
        return Icons.timer;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
