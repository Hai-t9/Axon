import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../../../features/leaderboard/presentation/leaderboard_page.dart';
import '../../../features/model_submission/presentation/model_submission_page.dart';
import '../../../features/validation/presentation/validation_page.dart';
import '../../../features/evaluation/presentation/evaluation_page.dart';
import '../../../features/data_validation/presentation/data_validation_page.dart';
import '../../auth/state/auth_session_provider.dart';
import '../data/competition_repository.dart';
import '../state/competition_details_controller.dart';
import '../state/dashboard_controller.dart';
import '../data/dashboard_models.dart';
import '../data/competition_models.dart';
import '../../home/presentation/home_page.dart';
import '../../gallery/presentation/gallery_page.dart';
import 'competition_settings_page.dart';
import 'image_gallery_page.dart';
import 'phase_control_page.dart';
import 'teams_control_page.dart';

const Map<String, String> _phaseLabels = {
  '0': 'Awaiting Initialisation',
  '1': 'Data Collection',
  '2': 'Data Validation',
  '3': 'Model Submission',
  '4': 'Model Evaluation',
  '5': 'Finale & Leaderboard',
};

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

  Widget _buildActionButtons(
    String competitionId,
    AsyncValue<DashboardBase> dashboardState,
    AsyncValue<String?> roleState,
  ) {
    final role = roleState.asData?.value;
    // Role is loading or unknown → show nothing
    if (role == null) return const SizedBox.shrink();
    // Host or staff → show Teams + Manage
    if (role == 'host' || role == 'staff') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.go(
              TeamsControlPage.routeForId(competitionId),
            ),
            icon: const Icon(Icons.group_outlined),
            label: const Text('Teams'),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.go(
              PhaseControlPage.routeForId(competitionId),
            ),
            icon: const Icon(Icons.lan_outlined),
            label: const Text('Phases'),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.go(
              CompetitionSettingsPage.routeForId(competitionId),
            ),
            icon: const Icon(Icons.settings),
            label: const Text('Manage'),
          ),
        ],
      );
    }
    // Participant → show Leave button
    return OutlinedButton.icon(
      onPressed: () => _leaveCompetition(competitionId),
      icon: const Icon(Icons.exit_to_app),
      label: const Text('Leave'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
      ),
    );
  }

  Future<void> _leaveCompetition(String competitionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave competition'),
        content: const Text(
          'Are you sure you want to leave this competition? '
          'You can rejoin later with the invitation link if invited.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(competitionRepositoryProvider);
      await repo.leaveCompetition(competitionId);
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.showSnackBar(const SnackBar(content: Text('Left competition.')));
      context.go(HomePage.routePath);
    } catch (e) {
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.showSnackBar(SnackBar(content: Text('Failed to leave: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final competitionState = ref.watch(competitionDetailsProvider(widget.competitionId));
    final dashboardState = ref.watch(dashboardProvider(widget.competitionId));
    final roleState = ref.watch(competitionRoleProvider(widget.competitionId));

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
                  // Host/staff see Teams & Manage; participants see Leave
                  _buildActionButtons(competition.id, dashboardState, roleState),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        color: AppColors.error.withValues(alpha: 0.1),
      ),
      child: Text(
        'Failed to load dashboard data: $error',
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }

  /// Inline widget shown inside the Overview tab when the phase is still at "0".
  Widget _buildPendingPhaseCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Icon(Icons.pending_actions, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Awaiting Initialisation',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'The host has not configured an active phase yet. '
                'Phase-dependent features will become available once the competition is initialised.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
          data: (dashboard) {
            final isAwaitingInit = dashboard.phaseInfo.currentPhase == '0';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAwaitingInit)
                  _buildPendingPhaseCard(context)
                else
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
                              _phaseLabels[dashboard.phaseInfo.currentPhase] ?? dashboard.phaseInfo.currentPhase,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phase ${dashboard.phaseInfo.currentPhase}',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (dashboard.phaseInfo.currentPhase != '5') ...[
                              const SizedBox(height: AppSpacing.md),
                              _PhaseCountdown(
                                phaseDates: dashboard.phaseInfo.phaseDates,
                                currentPhase: dashboard.phaseInfo.currentPhase,
                                onExpired: () => ref.invalidate(dashboardProvider(widget.competitionId)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (dashboard.isHost && competition.invitationLink != null && competition.invitationLink!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, 'Invitation Link'),
                  SelectableText(competition.invitationLink!, style: const TextStyle(color: AppColors.primaryDark)),
                ],
              ],
            );
          },
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(
                title: 'Host Overview',
                icon: Icons.admin_panel_settings,
                iconColor: AppColors.primaryDark,
                children: [
                  _buildStatRow('Total Enrolled Teams', hostDash.teamInfo.total.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader(context, 'Per-Team Breakdown'),
              ...hostDash.teamInfo.items.map((team) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildInfoCard(
                  title: team.name,
                  icon: Icons.groups,
                  iconColor: AppColors.primary,
                  children: [
                    _buildStatRow('Images Uploaded', team.imagesUploaded.toString()),
                    if (team.deviceStats.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Devices', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: team.deviceStats.entries.map((e) => Chip(
                          avatar: const Icon(Icons.smartphone, size: 14),
                          label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.background,
                          side: const BorderSide(color: AppColors.border),
                        )).toList(),
                      ),
                    ],
                    if (team.labelDistribution.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Labels', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: team.labelDistribution.entries.map((e) => Chip(
                          label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.surfaceAlt,
                          side: BorderSide.none,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              )),
            ],
          );
        } else {
          final partDash = dashboard as DashboardParticipantResponse;
          return _ParticipantTeamView(
            competitionId: widget.competitionId,
            partDash: partDash,
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
      _ModuleData(
        icon: Icons.photo_library_outlined,
        title: 'Gallery & Stats',
        subtitle: 'Team images & statistics',
        color: AppColors.accent,
        route: GalleryPage.routeForId(competitionId),
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

class _ParticipantTeamView extends ConsumerStatefulWidget {
  final String competitionId;
  final DashboardParticipantResponse partDash;

  const _ParticipantTeamView({
    required this.competitionId,
    required this.partDash,
  });

  @override
  ConsumerState<_ParticipantTeamView> createState() => _ParticipantTeamViewState();
}

class _ParticipantTeamViewState extends ConsumerState<_ParticipantTeamView> {
  List<Map<String, dynamic>>? _members;
  Map<String, dynamic>? _results;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final token = ref.read(authSessionProvider)?.accessToken;
      final headers = <String, String>{'Authorization': 'Bearer $token'};

      final results = await _fetchResults(api, headers);
      final members = await _fetchMembers(api, headers);

      if (mounted) {
        setState(() {
          _members = members;
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchResults(ApiClient api, Map<String, String> headers) async {
    try {
      return await api.getJson('/competitions/${widget.competitionId}/results', headers: headers);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMembers(ApiClient api, Map<String, String> headers) async {
    try {
      final resp = await api.getJson('/teams/${widget.partDash.teamInfo.id}/members', headers: headers);
      return (resp['members'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.partDash.teamInfo;
    if (_loading) return const Center(child: CircularProgressIndicator());

    Map<String, dynamic>? teamResult;
    if (_results != null) {
      final rankings = _results!['final_rankings'] as List<dynamic>? ?? [];
      for (final r in rankings) {
        if (r['team_id'] == team.id) {
          teamResult = r as Map<String, dynamic>;
          break;
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildStatsCard(context, team, teamResult)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            children: [
              _buildTeamCard(context, team),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ImageGalleryPage(
                        teamId: team.id,
                        teamName: team.name,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Image Gallery'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, DashboardParticipantTeam team, Map<String, dynamic>? teamResult) {
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
            Row(
              children: [
                const Icon(Icons.analytics, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Statistics', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _statRow('Images Uploaded', team.imagesUploaded.toString()),
            if (teamResult != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _statRow('Evaluation Score', (teamResult['mean_accuracy'] as num).toStringAsFixed(4)),
            ],
            if (team.labelDistribution.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Labels', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: team.labelDistribution.entries.map((e) => Chip(
                  label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.surfaceAlt,
                  side: BorderSide.none,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, DashboardParticipantTeam team) {
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
            Row(
              children: [
                const Icon(Icons.groups, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text(team.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_members == null || _members!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('No members found', style: const TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...(_members!.map((member) {
                final name = member['fullname'] as String? ?? 'Unknown';
                final email = member['email'] as String? ?? '';
                final joined = member['joined'] == 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(
                        joined ? Icons.check_circle : Icons.hourglass_empty,
                        color: joined ? AppColors.success : Colors.orange,
                        size: 18,
                      ),
                    ],
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
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
            color: AppColors.surfaceAlt,
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

class _PhaseCountdown extends StatefulWidget {
  final Map<String, dynamic> phaseDates;
  final String currentPhase;
  final VoidCallback? onExpired;

  const _PhaseCountdown({
    required this.phaseDates,
    required this.currentPhase,
    this.onExpired,
  });

  @override
  State<_PhaseCountdown> createState() => _PhaseCountdownState();
}

class _PhaseCountdownState extends State<_PhaseCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void didUpdateWidget(_PhaseCountdown old) {
    super.didUpdateWidget(old);
    if (old.currentPhase != widget.currentPhase || old.phaseDates != widget.phaseDates) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final deadlines = widget.phaseDates['deadlines'] as Map<String, dynamic>?;
    final deadlineStr = deadlines?[widget.currentPhase] as String?;
    if (deadlineStr == null) {
      if (_remaining != Duration.zero) setState(() => _remaining = Duration.zero);
      return;
    }
    final dt = DateTime.tryParse(deadlineStr);
    if (dt == null) {
      if (_remaining != Duration.zero) setState(() => _remaining = Duration.zero);
      return;
    }
    final deadline = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
    final remaining = deadline.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      if (_remaining != Duration.zero) {
        setState(() => _remaining = Duration.zero);
        widget.onExpired?.call();
      }
    } else {
      setState(() => _remaining = remaining);
    }
  }

  String _format(Duration d) {
    if (d == Duration.zero) return '';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (days > 0) return '$days days  ${hours.toString().padLeft(2, '0')}h  ${minutes.toString().padLeft(2, '0')}m';
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}h  ${minutes.toString().padLeft(2, '0')}m  ${seconds.toString().padLeft(2, '0')}s';
    if (minutes > 0) return '${minutes.toString().padLeft(2, '0')}m  ${seconds.toString().padLeft(2, '0')}s';
    return '${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Text(
        'No deadline set',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Column(
      children: [
        Text(
          _format(_remaining),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'remaining in this phase',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
