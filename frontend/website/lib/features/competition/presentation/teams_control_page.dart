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
import 'image_gallery_page.dart';

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
  bool _loading = true;

  final _teamNameCtl = TextEditingController();
  final _memberEmailCtl = TextEditingController();
  final List<String> _pendingEmails = [];
  final _emailCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _teamNameCtl.dispose();
    _memberEmailCtl.dispose();
    _emailCtl.dispose();
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
      setState(() {
        _teams = items.cast<Map<String, dynamic>>();
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
    if (name.isEmpty || _pendingEmails.isEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.postJson(
        '/competitions/${widget.competitionId}/teams/bulk',
        {'teams': {name: List.from(_pendingEmails)}},
        headers: _authHeaders,
      );
      _teamNameCtl.clear();
      setState(() => _pendingEmails.clear());
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

  void _addEmail() {
    final v = _emailCtl.text.trim().toLowerCase();
    if (v.isNotEmpty && !_pendingEmails.contains(v)) {
      setState(() {
        _pendingEmails.add(v);
        _emailCtl.clear();
      });
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
        '/teams/$teamId/members',
        {'email': email.trim()},
        headers: _authHeaders,
      );
      _showMsg('Member added.');
      await _loadTeams();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _removeMember(String teamId, String email) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/teams/$teamId/members/$email', headers: _authHeaders);
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

          // Create team card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a new team',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _teamNameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                      hintText: 'Team Alpha',
                      prefixIcon: Icon(Icons.group_add_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtl,
                        decoration: const InputDecoration(
                          labelText: 'Member email',
                          hintText: 'alice@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: _addEmail,
                      child: const Text('Add'),
                    ),
                  ]),
                  if (_pendingEmails.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _pendingEmails.map((e) {
                        return Chip(
                          label: Text(e),
                          onDeleted: () => setState(() => _pendingEmails.remove(e)),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: (_pendingEmails.isEmpty || _teamNameCtl.text.trim().isEmpty) ? null : _createTeam,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Create team with ${_pendingEmails.length} member${_pendingEmails.length == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Teams list
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
              final userEmails = (team['user_emails'] as Map<String, dynamic>?) ?? {};

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
                  subtitle: Text('${userEmails.length} member${userEmails.length == 1 ? '' : 's'}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userEmails.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text('No members yet.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            )
                          else
                            ...userEmails.entries.map((entry) {
                              final email = entry.key;
                              final joined = entry.value == 1;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: joined
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                                  child: Icon(
                                    joined ? Icons.check : Icons.hourglass_empty,
                                    size: 16,
                                    color: joined ? AppColors.success : theme.colorScheme.primary,
                                  ),
                                ),
                                title: Text(email, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                  joined ? 'Joined' : 'Invited (not yet joined)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: joined ? AppColors.success : AppColors.textSecondary,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                  tooltip: 'Remove member',
                                  onPressed: () => _removeMember(teamId, email),
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
                            const SizedBox(width: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ImageGalleryPage(
                                      teamId: teamId,
                                      teamName: teamName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.photo_library_outlined, size: 16),
                              label: const Text('Image Gallery'),
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
