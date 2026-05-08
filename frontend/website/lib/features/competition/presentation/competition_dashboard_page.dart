import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../state/competition_details_controller.dart';
import '../../home/presentation/home_page.dart';
import 'competition_settings_page.dart';

class CompetitionDashboardPage extends ConsumerWidget {
  const CompetitionDashboardPage({super.key, required this.competitionId});

  static const routeName = 'competition-dashboard';
  static const routePath = '/competitions/:id';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionState = ref.watch(competitionDetailsProvider(competitionId));

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
              Container(
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
                    Text(
                      'Dashboard modules',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Competition analytics and workflows will surface here next.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
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
}
