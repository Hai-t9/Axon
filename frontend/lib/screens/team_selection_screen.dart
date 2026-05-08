import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'camera_screen.dart';
import '../main.dart'; // for cameras
import '../utils/ui_helpers.dart';
import 'profile_screen.dart';

class TeamSelectionScreen extends ConsumerStatefulWidget {
  const TeamSelectionScreen({super.key});

  @override
  ConsumerState<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends ConsumerState<TeamSelectionScreen> {
  bool _isLoading = true;
  List<dynamic> _competitions = [];

  @override
  void initState() {
    super.initState();
    _fetchMyCompetitions();
  }

  Future<void> _fetchMyCompetitions() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/v1/register/me/competitions');
      if (mounted) {
        setState(() {
          _competitions = response.data['items'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopNotification.show(context, 'Failed to load competitions: $e', isError: true);
      }
    }
  }

  void _selectCompetition(Map<String, dynamic> comp) {
    final team = comp['team'];
    if (team != null) {
      // Save selected competition & team to Riverpod state
      ref.read(selectedCompetitionIdProvider.notifier).set(comp['competition_id'] as int);
      ref.read(selectedTeamIdProvider.notifier).set(team['id'] as int);
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CameraScreen(cameras: cameras),
        ),
      );
    } else {
      TopNotification.show(context, 'You are not assigned to a team in this competition yet. Ask the organizer to add you to a team.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F101A),
      appBar: AppBar(
        title: const Text('My Competitions', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F101A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5F75EE)))
          : _competitions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 24),
                        const Text(
                          'No competitions found',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Join a competition on the web portal first, then come back here to start collecting data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: _competitions.length,
                  itemBuilder: (context, index) {
                    final comp = _competitions[index];
                    final team = comp['team'];
                    final isHost = comp['role'] == 'host';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F2E),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _selectCompetition(comp),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isHost 
                                        ? Colors.amber.withOpacity(0.1) 
                                        : const Color(0xFF5F75EE).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isHost ? Icons.admin_panel_settings_rounded : Icons.group_rounded,
                                    color: isHost ? Colors.amber : const Color(0xFF5F75EE),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comp['competition_name'] ?? 'Unknown Competition',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        team != null
                                            ? 'Team: ${team['name']} • Role: ${comp['role']}'
                                            : 'Role: ${comp['role']} • No team assigned',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.white.withOpacity(0.3)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

