import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/state/auth_controller.dart';
import '../../../features/competition/presentation/host_competition_page.dart';
import '../../../features/competition/presentation/join_competition_page.dart';
import '../../../features/competition/presentation/competition_dashboard_page.dart';
import '../../../features/competition/state/competition_list_controller.dart';
import '../../../features/profile/presentation/profile_page.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/competition/competition_card.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../auth/presentation/login_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routePath = '/';
  static const routeName = 'home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(competitionListProvider);

    return AxonScaffold(
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Profile',
          onPressed: () => context.go(ProfilePage.routePath),
        ),
        TextButton(
          onPressed: () {
            ref.read(authControllerProvider.notifier).signOut();
            context.go(LoginPage.routePath);
          },
          child: const Text('Sign out'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(
            onHost: () => context.go(HostCompetitionPage.routePath),
            onJoin: () => context.go(JoinCompetitionPage.routePath),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your competitions',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Everything you host or join will appear here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(competitionListProvider.notifier).refreshList(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          listState.when(
            data: (list) {
              if (list.items.isEmpty) {
                return const _EmptyCompetitionsCard();
              }
              return Column(
                children: [
                  for (final competition in list.items) ...[
                    CompetitionCard(
                      competition: competition,
                      onOpen: () => context.go(
                        CompetitionDashboardPage.routeForId(competition.id),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => _ErrorCard(
              message: error.toString(),
              onRetry: () =>
                  ref.read(competitionListProvider.notifier).refreshList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onHost, required this.onJoin});

  final VoidCallback onHost;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Axon',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create competitions, distribute invitation links, and keep your\nteams aligned on the dashboard.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              ElevatedButton.icon(
                onPressed: onHost,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Host a competition'),
              ),
              OutlinedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.link),
                label: const Text('Join with invitation link'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCompetitionsCard extends StatelessWidget {
  const _EmptyCompetitionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No competitions yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Host your first competition or join with an invitation link.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Unable to load competitions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
