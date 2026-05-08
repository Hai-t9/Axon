import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../utils/ui_helpers.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<dynamic> _competitions = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final dio = ref.read(dioProvider);
      final profileRes = await dio.get('/api/v1/register/me');
      final compRes = await dio.get('/api/v1/register/me/competitions');
      
      if (mounted) {
        setState(() {
          _profileData = profileRes.data;
          _competitions = compRes.data['items'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopNotification.show(context, 'Failed to load profile: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F101A),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Log Out',
            onPressed: () {
              // Clear Riverpod auth token
              ref.read(authProvider.notifier).setToken(null);
              
              // Clear navigation stack and go to Login Screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5F75EE)))
          : _profileData == null
              ? const Center(child: Text('Profile not found', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF5F75EE), Color(0xFF9068FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF5F75EE).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, size: 64, color: Colors.white),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _profileData!['fullname'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _profileData!['email'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      const Text(
                        'My Teams & Teammates',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_competitions.isEmpty)
                        Text(
                          'You are not part of any teams yet.',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        )
                      else
                        ..._competitions.map((comp) {
                          final team = comp['team'];
                          final members = team != null ? team['members'] as List<dynamic>? ?? [] : [];
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1F2E),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF3A3A50).withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        comp['competition_name'] ?? 'Competition',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (team == null)
                                  Text('No team assigned.', style: TextStyle(color: Colors.white.withOpacity(0.5)))
                                else ...[
                                  Text(
                                    'Team: ${team['name']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5F75EE),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Teammates:', style: TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 8),
                                  ...members.map((m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: Colors.white54),
                                        const SizedBox(width: 8),
                                        Text(
                                          m['name'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  )),
                                ]
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
    );
  }
}
