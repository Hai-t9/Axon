import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
import '../services/auth_service.dart';
import '../services/competition_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/offline_banner.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'upload_history_screen.dart';
import 'profile_screen.dart';
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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UploadHistoryScreen()),
              );
            },
          ),
          if (queueLength > 0)
            IconButton(
              icon: Badge(
                label: Text('$queueLength'),
                backgroundColor: const Color(0xFFE5A53C),
                child: const Icon(Icons.cloud_off_rounded),
              ),
              onPressed: () {
                ref.read(offlineQueueProvider.notifier).processQueue();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Processing offline queue...')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(selectedCompetition: _selectedCompetition),
                ),
              );
            },
          ),
        ],
      ),
      body: OfflineBanner(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5F75EE), Color(0xFF3F54C6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5F75EE).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.grass_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Collection Setup',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF252536),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3A3A50), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Competition',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      _loadingCompetitions
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5F75EE)))
                          : _competitions.isEmpty
                              ? const Text('No competitions available',
                                  style: TextStyle(color: Colors.white38))
                              : DropdownButtonFormField<CompetitionModel>(
                                  value: _selectedCompetition,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF5F75EE)),
                                  decoration: InputDecoration(
                                    fillColor: const Color(0xFF1C1C28),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  dropdownColor: const Color(0xFF252536),
                                  hint: const Text('Choose a competition'),
                                  isExpanded: true,
                                  items: _competitions
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                      const SizedBox(height: 24),
                      Text(
                        'Select Team',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      _loadingTeams
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5F75EE)))
                          : _teams.isEmpty
                              ? const Text('No teams available',
                                  style: TextStyle(color: Colors.white38))
                              : DropdownButtonFormField<TeamModel>(
                                  value: _selectedTeam,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF5F75EE)),
                                  decoration: InputDecoration(
                                    fillColor: const Color(0xFF1C1C28),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  dropdownColor: const Color(0xFF252536),
                                  hint: const Text('Choose a team'),
                                  isExpanded: true,
                                  items: _teams
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (team) {
                                    setState(() => _selectedTeam = team);
                                  },
                                ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_selectedCompetition != null && _selectedTeam != null)
                            ? _startCapture
                            : null,
                    icon: const Icon(Icons.camera_alt_rounded, size: 24),
                    label: const Text('Start Capturing',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}