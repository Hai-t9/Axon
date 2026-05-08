import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
import '../services/auth_service.dart';
import '../services/competition_service.dart';
import '../services/offline_queue_service.dart';
import 'camera_screen.dart';
import '../main.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CompetitionModel? _selectedCompetition;
  TeamModel? _selectedTeam;
  List<CompetitionModel> _competitions = [];
  List<TeamModel> _teams = [];
  bool _loadingCompetitions = true;
  bool _loadingTeams = false;

  @override
  void initState() {
    super.initState();
    _loadCompetitions();
  }

  Future<void> _loadCompetitions() async {
    setState(() => _loadingCompetitions = true);
    try {
      final service = ref.read(competitionServiceProvider);
      final comps = await service.getCompetitions();
      setState(() {
        _competitions = comps;
        _loadingCompetitions = false;
      });
    } catch (e) {
      setState(() => _loadingCompetitions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load competitions: $e')),
        );
      }
    }
  }

  Future<void> _loadTeams(String competitionId) async {
    setState(() => _loadingTeams = true);
    try {
      final service = ref.read(competitionServiceProvider);
      final teams = await service.getTeams(competitionId);
      setState(() {
        _teams = teams;
        _loadingTeams = false;
      });
    } catch (e) {
      setState(() => _loadingTeams = false);
    }
  }

  void _startCapture() {
    if (_selectedCompetition == null || _selectedTeam == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          cameras: cameras,
          teamId: _selectedTeam!.id,
          competitionId: _selectedCompetition!.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueLength = ref.watch(offlineQueueProvider).length;
    final authState = ref.watch(authProvider);
    final userName = authState.user?.fullname ?? authState.user?.email ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Axon'),
        actions: [
          if (queueLength > 0)
            IconButton(
              icon: Badge(
                label: Text('$queueLength'),
                child: const Icon(Icons.cloud_off),
              ),
              onPressed: () {
                ref.read(offlineQueueProvider.notifier).processQueue();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Processing offline queue...')),
                );
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signout') {
                ref.read(authProvider.notifier).logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('Logged out')),
                    ),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text('Signed in as $userName'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'signout',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $userName',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Competition',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _loadingCompetitions
                ? const CircularProgressIndicator()
                : _competitions.isEmpty
                    ? const Text('No competitions available',
                        style: TextStyle(color: Colors.white60))
                    : DropdownButtonFormField<CompetitionModel>(
                        value: _selectedCompetition,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        hint: const Text('Choose a competition'),
                        isExpanded: true,
                        items: _competitions
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (comp) {
                          setState(() {
                            _selectedCompetition = comp;
                            _selectedTeam = null;
                            _teams = [];
                          });
                          if (comp != null) _loadTeams(comp.id);
                        },
                      ),
            const SizedBox(height: 16),
            Text(
              'Select Team',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _loadingTeams
                ? const CircularProgressIndicator()
                : _teams.isEmpty
                    ? const Text('No teams available',
                        style: TextStyle(color: Colors.white60))
                    : DropdownButtonFormField<TeamModel>(
                        value: _selectedTeam,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        hint: const Text('Choose a team'),
                        isExpanded: true,
                        items: _teams
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name),
                              ),
                            )
                            .toList(),
                        onChanged: (team) {
                          setState(() => _selectedTeam = team);
                        },
                      ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    (_selectedCompetition != null && _selectedTeam != null)
                        ? _startCapture
                        : null,
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text('Start Capturing',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
