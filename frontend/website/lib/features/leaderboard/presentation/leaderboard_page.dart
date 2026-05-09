import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../data/leaderboard_models.dart';
import '../state/leaderboard_controller.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key, required this.competitionId});

  static const routeName = 'leaderboard';
  static const routePath = '/competitions/:id/leaderboard';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/leaderboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider(competitionId));

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Leaderboard', 
            subtitle: 'Team rankings',
            trailing: IconButton.filledTonal(
              onPressed: () => ref.refresh(leaderboardProvider(competitionId)),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          state.when(
            data: (raw) {
              final data = raw;
              if (data.entries.isEmpty) {
                return _emptyState(context);
              }
              return Column(
                children: [
                  if (data.lastUpdated != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        'Last updated: ${data.lastUpdated}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  _buildTrophyRow(context, data.entries),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTable(context, data.entries),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _errorState(context, err.toString(), ref),
          ),
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
          Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text('No rankings yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Leaderboard will populate once evaluations complete.'),
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
          Text('Unable to load leaderboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(error),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => ref.refresh(leaderboardProvider(competitionId)),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyRow(BuildContext context, List<LeaderboardEntry> entries) {
    final top3 = entries.take(3).toList();
    final icons = [Icons.emoji_events, Icons.looks_two, Icons.looks_3];
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];

    return Row(
      children: List.generate(top3.length, (i) {
        final entry = top3[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? AppSpacing.sm : 0),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              color: colors[i].withValues(alpha: 0.1),
            ),
            child: Column(
              children: [
                Icon(icons[i], color: colors[i], size: 32),
                const SizedBox(height: AppSpacing.xs),
                Text(entry.teamName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Text(entry.score.toStringAsFixed(4),
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTable(BuildContext context, List<LeaderboardEntry> entries) {
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
                  SizedBox(width: 40, child: Text('Rank',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  Expanded(child: Text('Team',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  SizedBox(width: 100, child: Text('Score',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                ],
              ),
            ),
            ...List.generate(entries.length, (i) {
              final entry = entries[i];
              final isEven = i.isEven;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                color: isEven ? Colors.transparent : AppColors.surfaceAlt.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('${entry.rank}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text(entry.teamName)),
                    SizedBox(
                      width: 100,
                      child: Text(entry.score.toStringAsFixed(4),
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
}
