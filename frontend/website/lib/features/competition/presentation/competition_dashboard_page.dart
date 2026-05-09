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
import '../state/dashboard_controller.dart';
import '../data/dashboard_models.dart';
import '../data/competition_models.dart';
import '../../home/presentation/home_page.dart';
import 'competition_settings_page.dart';

class CompetitionDashboardPage extends ConsumerStatefulWidget {
  const CompetitionDashboardPage({super.key, required this.competitionId});

  static const routeName = 'competition-dashboard';
  static const routePath = '/competitions/:id';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id';

  @override
  ConsumerState<CompetitionDashboardPage> createState() => _CompetitionDashboardPageState();
}

class _CompetitionDashboardPageState extends ConsumerState<CompetitionDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final competitionState = ref.watch(competitionDetailsProvider(widget.competitionId));
    final dashboardState = ref.watch(dashboardProvider(widget.competitionId));

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
              
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Dataset Insights'),
                  Tab(text: 'Team'),
                  Tab(text: 'Modules'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              _buildActiveTab(context, competition, dashboardState),

              const SizedBox(height: AppSpacing.xxl),
              TextButton.icon(
                onPressed: () => context.go(HomePage.routePath),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to home'),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('Unable to load competition: $error'),
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context, Competition competition, AsyncValue<DashboardBase> dashboardState) {
    switch (_tabController.index) {
      case 0:
        return _buildOverviewTab(context, competition, dashboardState);
      case 1:
        return _buildInsightsTab(context, dashboardState);
      case 2:
        return _buildTeamTab(context, dashboardState);
      case 3:
      default:
        return _buildModulesTab(context);
    }
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final errorString = error.toString();
    if (errorString.contains('Phase information not found') || errorString.contains('Competition config not found')) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.pending_actions, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            Text('Pending Initialization', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This competition is still being set up. Dashboard statistics and team info will appear once the host configures the active phase.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        color: AppColors.error.withValues(alpha: 0.1),
      ),
      child: Text(
        'Failed to load dashboard stats: $error',
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }

  // --- TAB 1: OVERVIEW ---
  Widget _buildOverviewTab(BuildContext context, Competition competition, AsyncValue<DashboardBase> dashboardState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (competition.description != null && competition.description!.isNotEmpty) ...[
          _buildSectionHeader(context, 'Description'),
          Text(competition.description!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
        ],
        _buildSectionHeader(context, 'Phase Information'),
        dashboardState.when(
          data: (dashboard) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(
                children: [
                  _buildStatRow('Current Phase', dashboard.phaseInfo.currentPhase),
                ],
              ),
              if (dashboard.isHost && competition.invitationLink != null && competition.invitationLink!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _buildSectionHeader(context, 'Invitation Link'),
                SelectableText(competition.invitationLink!, style: const TextStyle(color: AppColors.primaryDark)),
              ],
            ],
          ),
          loading: () => _buildLoadingState(),
          error: (e, _) => _buildErrorState(context, e),
        ),
      ],
    );
  }

  // --- TAB 2: DATASET INSIGHTS ---
  Widget _buildInsightsTab(BuildContext context, AsyncValue<DashboardBase> dashboardState) {
    return dashboardState.when(
      loading: () => _buildLoadingState(),
      error: (e, _) => _buildErrorState(context, e),
      data: (dashboard) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoCard(
                  title: 'Image Statistics',
                  icon: Icons.image,
                  iconColor: AppColors.primary,
                  children: [
                    _buildStatRow('Total Images', dashboard.imageStats.total.toString()),
                    _buildStatRow('Verified', dashboard.imageStats.verified.toString()),
                    _buildStatRow('On Hold', dashboard.imageStats.onHold.toString()),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildInfoCard(
                  title: 'Location Metadata',
                  icon: Icons.pin_drop,
                  iconColor: AppColors.success,
                  children: [
                    _buildStatRow('Images with GPS', dashboard.locations.length.toString()),
                    const SizedBox(height: AppSpacing.sm),
                    if (dashboard.locations.isNotEmpty)
                      Text(
                        'Includes metadata like GPS coordinates, camera make, and model.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          
          if (dashboard.labelDistribution.isNotEmpty) ...[
            _buildSectionHeader(context, 'Label Distribution'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: dashboard.labelDistribution.entries.map((e) {
                return Chip(
                  label: Text('${e.key}: ${e.value}'),
                  backgroundColor: AppColors.surfaceAlt,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (dashboard.deviceStats.isNotEmpty) ...[
            _buildSectionHeader(context, 'Device Statistics'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: dashboard.deviceStats.entries.map((e) {
                return Chip(
                  avatar: const Icon(Icons.smartphone, size: 16),
                  label: Text('${e.key}: ${e.value}'),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 3: TEAM ---
  Widget _buildTeamTab(BuildContext context, AsyncValue<DashboardBase> dashboardState) {
    return dashboardState.when(
      loading: () => _buildLoadingState(),
      error: (e, _) => _buildErrorState(context, e),
      data: (dashboard) {
        if (dashboard.isHost) {
          final hostDash = dashboard as DashboardHostResponse;
          return _buildInfoCard(
            title: 'Host Overview',
            icon: Icons.admin_panel_settings,
            iconColor: AppColors.primaryDark,
            children: [
              _buildStatRow('Total Enrolled Teams', hostDash.teamInfo.total.toString()),
            ],
          );
        } else {
          final partDash = dashboard as DashboardParticipantResponse;
          return _buildInfoCard(
            title: 'Your Team: ${partDash.teamInfo.name}',
            icon: Icons.groups,
            iconColor: AppColors.success,
            children: [
              _buildStatRow('Current Score', partDash.teamInfo.score.toStringAsFixed(4)),
            ],
          );
        }
      },
    );
  }

  // --- TAB 4: MODULES ---
  Widget _buildModulesTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Active Modules'),
        _buildModuleGrid(context, widget.competitionId),
      ],
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInfoCard({
    String? title,
    IconData? icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: iconColor ?? AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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
                  color: data.color.withValues(alpha: 0.15),
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
                style: const TextStyle(
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
