import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../auth/state/auth_controller.dart';
import '../../auth/presentation/login_page.dart';
import '../data/profile_models.dart';
import '../state/profile_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const routeName = 'profile';
  static const routePath = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return AxonScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          if (profile == null)
            const Center(child: Text('Not signed in'))
          else
            Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    _initials(profile.fullname ?? profile.email),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _infoCard(context, profile),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                      context.go(LoginPage.routePath);
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _infoCard(BuildContext context, ProfileData profile) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).cardTheme.color,
      ),
      child: Column(
        children: [
          _infoRow(Icons.person, 'Name', profile.fullname ?? 'Not set', muted),
          const Divider(),
          _infoRow(Icons.email, 'Email', profile.email, muted),
          const Divider(),
          _infoRow(Icons.phone, 'Phone', profile.phone ?? 'Not set', muted),
          if (profile.createdAt != null) ...[
            const Divider(),
            _infoRow(Icons.calendar_today, 'Member since', profile.createdAt!, muted),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: muted),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: muted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
