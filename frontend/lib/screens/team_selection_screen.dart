import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'camera_screen.dart';
import '../main.dart'; // for cameras

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load competitions: $e')),
        );
      }
    }
  }

  void _selectCompetition(Map<String, dynamic> comp) {
    final team = comp['team'];
    if (team != null) {
      // Save selected competition & team to Riverpod state
      ref.read(selectedCompetitionIdProvider.notifier).set(comp['competition_id'] as int);
      ref.read(selectedTeamIdProvider.notifier).set(team['id'] as int);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CameraScreen(cameras: cameras),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not assigned to a team in this competition yet. Ask the organizer to add you to a team.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Competitions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _competitions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No competitions found.\nJoin a competition on the web portal first, then come back here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _competitions.length,
                  itemBuilder: (context, index) {
                    final comp = _competitions[index];
                    final team = comp['team'];
                    return Card(
                      color: const Color(0xFF252536),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          comp['role'] == 'host' ? Icons.admin_panel_settings : Icons.group,
                          color: comp['role'] == 'host' ? Colors.amber : const Color(0xFF5F75EE),
                        ),
                        title: Text(
                          comp['competition_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          team != null
                              ? 'Team: ${team['name']} • Role: ${comp['role']}'
                              : 'Role: ${comp['role']} • No team assigned',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _selectCompetition(comp),
                      ),
                    );
                  },
                ),
    );
  }
}

