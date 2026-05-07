import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validation/validators.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/auth/auth_card.dart';
import '../../../widgets/auth/auth_text_field.dart';
import '../../../widgets/auth/delayed_reveal.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../state/competition_join_controller.dart';
import 'competition_dashboard_page.dart';
import '../../home/presentation/home_page.dart';

class JoinCompetitionPage extends ConsumerStatefulWidget {
  const JoinCompetitionPage({super.key});

  static const routePath = '/competitions/join';
  static const routeName = 'competition-join';

  @override
  ConsumerState<JoinCompetitionPage> createState() =>
      _JoinCompetitionPageState();
}

class _JoinCompetitionPageState extends ConsumerState<JoinCompetitionPage> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  late final ProviderSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      competitionJoinProvider,
      (previous, next) {
        next.whenOrNull(
          error: (error, _) {
            if (!mounted) return;
            _showMessage(error.toString(), isError: true);
          },
          data: (competition) {
            if (!mounted) return;
            if (competition != null && previous?.isLoading == true) {
              _showMessage('Invitation accepted.');
              context.go(CompetitionDashboardPage.routeForId(competition.id));
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription.close();
    _linkController.dispose();
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
    ref
        .read(competitionJoinProvider.notifier)
        .joinWithInvitationLink(_linkController.text);
  }

  @override
  Widget build(BuildContext context) {
    final joinState = ref.watch(competitionJoinProvider);
    final isLoading = joinState.isLoading;

    return AxonScaffold(
      centerContent: true,
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DelayedReveal(
              delay: Duration(milliseconds: 60),
              child: PageHeader(
                title: 'Join a competition',
                subtitle: 'Paste the invitation link you received from the host.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: DelayedReveal(
                delay: const Duration(milliseconds: 120),
                child: AuthTextField(
                  controller: _linkController,
                  label: 'Invitation link',
                  hint: 'https://axon.ai/invite/1234',
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icons.link,
                  validator: Validators.invitationLink,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DelayedReveal(
              delay: const Duration(milliseconds: 180),
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join competition'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => context.go(HomePage.routePath),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
