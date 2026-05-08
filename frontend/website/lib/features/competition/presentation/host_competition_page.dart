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
import '../state/competition_create_controller.dart';
import '../state/competition_list_controller.dart';
import 'competition_dashboard_page.dart';
import '../../home/presentation/home_page.dart';

class HostCompetitionPage extends ConsumerStatefulWidget {
  const HostCompetitionPage({super.key});

  static const routePath = '/competitions/host';
  static const routeName = 'competition-host';

  @override
  ConsumerState<HostCompetitionPage> createState() =>
      _HostCompetitionPageState();
}

class _HostCompetitionPageState extends ConsumerState<HostCompetitionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _launchDate;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
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

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _launchDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null) {
      setState(() {
        _launchDate = selected;
        _dateController.text =
            '${selected.year}-${_two(selected.month)}-${_two(selected.day)}';
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    try {
      final competition =
          await ref.read(competitionCreateProvider.notifier).createCompetition(
                name: _nameController.text,
                description: _descriptionController.text,
                launchDate: _launchDate,
              );
      if (!mounted) return;
      if (competition == null) return;
      _showMessage('Competition created.');
      context.go(CompetitionDashboardPage.routeForId(competition.id));
      Future.microtask(() async {
        try {
          await ref.read(competitionListProvider.notifier).refreshList();
        } catch (_) {}
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(competitionCreateProvider);
    final isLoading = createState.isLoading;

    return AxonScaffold(
      centerContent: true,
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DelayedReveal(
              delay: Duration(milliseconds: 60),
              child: PageHeader(
                title: 'Host a competition',
                subtitle: 'Share a few details to set up your competition.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  DelayedReveal(
                    delay: const Duration(milliseconds: 120),
                    child: AuthTextField(
                      controller: _nameController,
                      label: 'Competition name',
                      hint: 'Axon Label Sprint',
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.emoji_events_outlined,
                      validator: Validators.competitionName,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DelayedReveal(
                    delay: const Duration(milliseconds: 180),
                    child: TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Tell participants what success looks like.',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DelayedReveal(
                    delay: const Duration(milliseconds: 240),
                    child: TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Launch date (optional)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DelayedReveal(
              delay: const Duration(milliseconds: 300),
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create competition'),
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

  String _two(int value) => value.toString().padLeft(2, '0');
}
