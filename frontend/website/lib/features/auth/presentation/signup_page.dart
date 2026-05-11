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
import '../state/auth_controller.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  static const routePath = '/signup';
  static const routeName = 'signup';

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
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
    ref.read(authControllerProvider.notifier).signup(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<String?>(navigateToVerifyProvider, (_, email) {
      if (email != null) {
        ref.read(navigateToVerifyProvider.notifier).state = null;
        context.go('${VerifyEmailPage.routePath}?email=$email');
      }
    });

    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) {
          if (!mounted) return;
          _showMessage(error.toString(), isError: true);
        },
      );
    });

    return AuthScaffold(
      panelTitle: 'Start your Axon workspace',
      panelSubtitle:
          'Collect teams, align datasets, and move from upload to evaluation fast.',
      highlights: const [
        'Signup with email to unlock the full platform',
        'Bring experiments, labels, and models together',
        'Stay aligned with one shared workspace',
      ],
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DelayedReveal(
              delay: Duration(milliseconds: 80),
              child: AuthHeader(
                title: 'Create your account',
                subtitle: 'Join Axon with your team details.',
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
                      controller: _fullNameController,
                      label: 'Full name',
                      hint: 'Ada Lovelace',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline,
                      validator: Validators.fullName,
                      autofillHints: const [AutofillHints.name],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DelayedReveal(
                    delay: const Duration(milliseconds: 200),
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
                    delay: const Duration(milliseconds: 320),
                    child: AuthTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'At least 8 characters',
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      onToggleObscure: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      validator: Validators.password,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DelayedReveal(
              delay: const Duration(milliseconds: 380),
              child: PrimaryButton(
                label: 'Create account',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DelayedReveal(
              delay: const Duration(milliseconds: 440),
              child: AuthFooter(
                text: 'Already have an account?',
                actionText: 'Sign in',
                onPressed: isLoading
                    ? null
                    : () => context.go(LoginPage.routePath),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
