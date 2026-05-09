import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../../auth/state/auth_session_provider.dart';
import 'competition_dashboard_page.dart';

class TeamsControlPage extends ConsumerStatefulWidget {
  const TeamsControlPage({super.key, required this.competitionId});

  static const routeName = 'teams-control';
  static const routePath = '/competitions/:id/teams';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/teams';

  @override
  ConsumerState<TeamsControlPage> createState() => _TeamsControlPageState();
}

class _TeamsControlPageState extends ConsumerState<TeamsControlPage> {
  List<Map<String, dynamic>> _teams = [];
  // team_id -> list of {id, fullname, email}
  Map<String, List<Map<String, dynamic>>> _teamMembers = {};
  bool _loading = true;

  // Create team
  final _teamNameCtl = TextEditingController();
  final _teamEmailsCtl = TextEditingController();

  // Add member
  final _memberEmailCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _teamNameCtl.dispose();
    _teamEmailsCtl.dispose();
    _memberEmailCtl.dispose();
    super.dispose();
  }

  String? get _token => ref.read(authSessionProvider)?.accessToken;

  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $_token'};

  Future<void> _loadTeams() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.getJson(
        '/competitions/${widget.competitionId}/teams?page=1&limit=100',
        headers: _authHeaders,
      );
      final items = (resp['items'] as List<dynamic>?) ?? [];
      final teams = items.cast<Map<String, dynamic>>();

      // Fetch member details for each team
      final Map<String, List<Map<String, dynamic>>> members = {};
      for (final team in teams) {
        final teamId = team['id'].toString();
        try {
          final membersResp = await api.getJson(
            '/teams/$teamId/members',
            headers: _authHeaders,
          );
          final memberList = (membersResp['members'] as List<dynamic>?) ?? [];
          members[teamId] = memberList.cast<Map<String, dynamic>>();
        } catch (_) {
          members[teamId] = [];
        }
      }

      setState(() {
        _teams = teams;
        _teamMembers = members;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMsg(e.toString(), isError: true);
      }
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _createTeam() async {
    final name = _teamNameCtl.text.trim();
    final emailsStr = _teamEmailsCtl.text.trim();
    if (name.isEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      if (emailsStr.isNotEmpty) {
        final emails = emailsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        await api.postJson(
          '/competitions/${widget.competitionId}/teams/bulk',
          {'teams': {name: emails}},
          headers: _authHeaders,
        );
      } else {
        await api.postJson(
          '/competitions/${widget.competitionId}/teams',
          {'name': name},
          headers: _authHeaders,
        );
      }
      _teamNameCtl.clear();
      _teamEmailsCtl.clear();
      _showMsg('Team "$name" created.');
      await _loadTeams();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _deleteTeam(String teamId, String teamName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$teamName"?'),
        content: const Text('This will remove the team and all its data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/teams/$teamId', headers: _authHeaders);
      _showMsg('Team deleted.');
      await _loadTeams();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _addMember(String teamId) async {
    _memberEmailCtl.clear();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: _memberEmailCtl,
          decoration: const InputDecoration(
            labelText: 'User email',
            hintText: 'user@example.com',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _memberEmailCtl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.postJson(
        '/teams/$teamId/members/by-email',
        {'email': email.trim()},
        headers: _authHeaders,
      );
      _showMsg('Member added.');
      await _loadTeams();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _removeMember(String teamId, String userId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/teams/$teamId/members/$userId', headers: _authHeaders);
      _showMsg('Member removed.');
      await _loadTeams();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: PageHeader(title: 'Teams Control', subtitle: 'Manage teams and members.')),
            const SizedBox(width: AppSpacing.md),
            TextButton.icon(
              onPressed: () => context.go(CompetitionDashboardPage.routeForId(widget.competitionId)),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Dashboard'),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),

          // ── Create team card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a new team',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _teamNameCtl,
                        decoration: const InputDecoration(
                          labelText: 'Team name',
                          hintText: 'Team Alpha',
                          prefixIcon: Icon(Icons.group_add_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _teamEmailsCtl,
                        decoration: const InputDecoration(
                          labelText: 'Member emails (comma separated, optional)',
                          hintText: 'alice@ex.com, bob@ex.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        onSubmitted: (_) => _createTeam(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: _createTeam,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Teams list ──
          Text('Existing teams',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()))
          else if (_teams.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text('No teams yet. Create one above.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            ..._teams.map((team) {
              final teamId = team['id'].toString();
              final teamName = team['name'] as String;
              final members = _teamMembers[teamId] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ExpansionTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.group, color: theme.colorScheme.primary, size: 18),
                  ),
                  title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${members.length} member${members.length == 1 ? '' : 's'}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (members.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text('No members yet.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            )
                          else
                            ...members.map((member) {
                              final userId = member['id'].toString();
                              final name = member['fullname'] ?? 'Unknown';
                              final email = member['email'] ?? '';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                title: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                subtitle: Text(email, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                  tooltip: 'Remove member',
                                  onPressed: () => _removeMember(teamId, userId),
                                ),
                              );
                            }),
                          const Divider(),
                          Row(children: [
                            TextButton.icon(
                              onPressed: () => _addMember(teamId),
                              icon: const Icon(Icons.person_add_outlined, size: 16),
                              label: const Text('Add member'),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _deleteTeam(teamId, teamName),
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                              label: const Text('Delete team', style: TextStyle(color: AppColors.error)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
