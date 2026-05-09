import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../../../features/leaderboard/presentation/leaderboard_page.dart';
import '../../../features/model_submission/presentation/model_submission_page.dart';
import '../../../features/validation/presentation/validation_page.dart';
import '../../../features/evaluation/presentation/evaluation_page.dart';
import '../../../features/data_validation/presentation/data_validation_page.dart';
import '../state/competition_details_controller.dart';
import '../../home/presentation/home_page.dart';
import 'competition_settings_page.dart';
import 'teams_control_page.dart';

class CompetitionDashboardPage extends ConsumerWidget {
  const CompetitionDashboardPage({super.key, required this.competitionId});

  static const routeName = 'competition-dashboard';
  static const routePath = '/competitions/:id';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionState =
        ref.watch(competitionDetailsProvider(competitionId));

    return AxonScaffold(
      child: competitionState.when(
        data: (competition) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PageHeader(
                      title: competition.name,
                      subtitle: 'Competition dashboard',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      TeamsControlPage.routeForId(competition.id),
                    ),
                    icon: const Icon(Icons.group_outlined),
                    label: const Text('Teams'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      CompetitionSettingsPage.routeForId(competition.id),
                    ),
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        competition.description ??
                            'Add a description to tell teams what to expect.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (competition.invitationLink != null &&
                          competition.invitationLink!.trim().isNotEmpty) ...[
                        Text(
                          'Invitation link',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(competition.invitationLink!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Competition Modules',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildModuleGrid(context, competitionId),
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: () => context.go(HomePage.routePath),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to home'),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            color: AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to load competition',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(error.toString()),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () =>
                    ref.refresh(competitionDetailsProvider(competitionId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context, String competitionId) {
    final modules = [
      _ModuleData(
        icon: Icons.emoji_events,
        title: 'Leaderboard',
        subtitle: 'Team rankings',
        color: const Color(0xFFFFD700),
        route: LeaderboardPage.routeForId(competitionId),
      ),
      _ModuleData(
        icon: Icons.cloud_upload_outlined,
        title: 'Model Submission',
        subtitle: 'Submit & manage models',
        color: AppColors.primaryDark,
        route: ModelSubmissionPage.routeForId(competitionId),
      ),
      _ModuleData(
        icon: Icons.how_to_vote,
        title: 'Validation',
        subtitle: 'Vote on image labels',
        color: AppColors.success,
        route: ValidationPage.routeForId(competitionId),
      ),
      _ModuleData(
        icon: Icons.science,
        title: 'Evaluations',
        subtitle: 'Evaluation results',
        color: const Color(0xFFE5A53C),
        route: EvaluationPage.routeForId(competitionId),
      ),
      _ModuleData(
        icon: Icons.verified,
        title: 'Data Validation',
        subtitle: 'Review image labels',
        color: AppColors.primaryDark,
        route: DataValidationPage.routeForId(competitionId),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return _ModuleCard(
          data: module,
          onTap: () => context.go(module.route),
        );
      },
    );
  }
}

class _ModuleData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  const _ModuleData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleData data;
  final VoidCallback onTap;

  const _ModuleCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            color: AppColors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.color, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                data.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                data.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
