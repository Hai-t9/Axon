import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/competition_model.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  final CompetitionModel? selectedCompetition;
  
  const ProfileScreen({super.key, this.selectedCompetition});

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // TODO: Fetch actual role from backend based on selectedCompetition.id
    // For now, defaulting to 'Participant' if a competition is selected.
    // The user would be a 'Host' if they created the competition.
    final String role = selectedCompetition != null ? 'Participant' : 'No Competition Selected';
    final String compName = selectedCompetition?.name ?? 'None';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Hero(
                tag: 'profile_avatar',
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF252536),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF5F75EE), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5F75EE).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 64,
                    color: Color(0xFF5F75EE),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                user?.fullname ?? 'Unknown User',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'No email provided',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252536),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3A3A50), width: 1.5),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: Color(0xFF5F75EE)),
                      title: const Text('Email'),
                      subtitle: Text(user?.email ?? 'N/A', style: const TextStyle(color: Colors.white70)),
                    ),
                    const Divider(color: Color(0xFF3A3A50), height: 1),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: Color(0xFF5F75EE)),
                      title: const Text('Role'),
                      subtitle: Text(role, style: const TextStyle(color: Colors.white70)),
                    ),
                    const Divider(color: Color(0xFF3A3A50), height: 1),
                    ListTile(
                      leading: const Icon(Icons.emoji_events_outlined, color: Color(0xFF5F75EE)),
                      title: const Text('Active Competition'),
                      subtitle: Text(compName, style: const TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
