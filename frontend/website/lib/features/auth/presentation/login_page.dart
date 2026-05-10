import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validation/validators.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/auth/auth_buttons.dart';
import '../../../widgets/auth/auth_card.dart';
import '../../../widgets/auth/auth_footer.dart';
import '../../../widgets/auth/auth_header.dart';
import '../../../widgets/auth/auth_scaffold.dart';
import '../../../widgets/auth/auth_text_field.dart';
import '../../../widgets/auth/delayed_reveal.dart';
import '../data/auth_models.dart';
import '../state/auth_controller.dart';
import 'signup_page.dart';
import '../../home/presentation/home_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const routePath = '/login';
  static const routeName = 'login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late final ProviderSubscription<AsyncValue<AuthSession?>> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          if (!mounted) return;
          _showMessage(error.toString(), isError: true);
        },
        data: (session) {
          if (!mounted) return;
          if (session != null && previous?.isLoading == true) {
            _showMessage('Signed in successfully.');
            context.go(HomePage.routePath);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _authSubscription.close();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    ref.read(authControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return AuthScaffold(
      panelTitle: 'Connect your team to Axon',
      panelSubtitle:
          'Create datasets, review labels, and keep competition phases moving.',
      highlights: const [
        'One account for labels, validation, and dashboards',
        'Track progress from signup to leaderboard',
        'Invite collaborators in minutes',
      ],
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DelayedReveal(
              delay: Duration(milliseconds: 80),
              child: AuthHeader(
                title: 'Welcome back',
                subtitle: 'Sign in to continue to Axon.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  DelayedReveal(
                    delay: const Duration(milliseconds: 140),
                    child: AuthTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@axon.ai',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.alternate_email,
                      validator: Validators.email,
                      autofillHints: const [AutofillHints.email],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DelayedReveal(
                    delay: const Duration(milliseconds: 200),
                    child: AuthTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Your secure passphrase',
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      onToggleObscure: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      validator: Validators.password,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DelayedReveal(
              delay: const Duration(milliseconds: 260),
              child: PrimaryButton(
                label: 'Sign in',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DelayedReveal(
              delay: const Duration(milliseconds: 380),
              child: AuthFooter(
                text: 'New to Axon?',
                actionText: 'Create an account',
                onPressed: isLoading
                    ? null
                    : () => context.go(SignupPage.routePath),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
