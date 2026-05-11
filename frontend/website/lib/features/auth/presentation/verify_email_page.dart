import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/auth/auth_card.dart';
import '../../../widgets/auth/auth_scaffold.dart';
import '../../../widgets/auth/delayed_reveal.dart';
import '../state/auth_controller.dart';
import 'login_page.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  static const routePath = '/verify-email';
  static const routeName = 'verify-email';

  final String email;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _isResending = false;
  bool _isVerifying = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkForToken();
  }

  void _checkForToken() {
    final hash = html.window.location.hash;
    if (hash.isEmpty) return;

    final params = Uri.splitQueryString(hash.replaceFirst('#', ''));
    final token = params['access_token'];
    if (token == null || token.isEmpty) return;

    setState(() => _isVerifying = true);
    _callVerifyEndpoint(token);
  }

  Future<void> _callVerifyEndpoint(String token) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.postJson('/register/verify', {'access_token': token});
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _statusMessage = 'Email verified! You can now sign in.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _statusMessage = 'Verification failed. The link may have expired.';
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authControllerProvider.notifier).resendVerification(widget.email);
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage('Verification email sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(e.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      panelTitle: 'One last step',
      panelSubtitle: 'Verify your email to start collaborating on Axon.',
      highlights: const [
        'Check your inbox (and spam folder) for the verification email',
        'Click the link to confirm your address',
        'Come back here and sign in to get started',
      ],
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DelayedReveal(
              delay: Duration(milliseconds: 80),
              child: Center(
                child: Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const DelayedReveal(
              delay: Duration(milliseconds: 140),
              child: Center(
                child: Text(
                  'Verify your email',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DelayedReveal(
              delay: const Duration(milliseconds: 200),
              child: Center(
                child: Text(
                  'We sent a verification email to\n${widget.email.isNotEmpty ? widget.email : 'your email'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DelayedReveal(
              delay: const Duration(milliseconds: 260),
              child: const Center(
                child: Text(
                  'Click the link in the email to verify your account,\nthen sign in below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ),
            ),
            if (_isVerifying) ...[
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusMessage!.contains('verified') ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            DelayedReveal(
              delay: const Duration(milliseconds: 320),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isResending ? null : _resend,
                  icon: _isResending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Resend verification email'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DelayedReveal(
              delay: const Duration(milliseconds: 380),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(LoginPage.routePath),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Go to sign in'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
